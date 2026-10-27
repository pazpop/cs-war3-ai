// The ranking of the month, for the web page: each human's kills, deaths and headshots, per month (in
// data/sqlite3/war3ft.sq3, table "cs_war3_ai_monthly"). A new month starts from zero: newcomers have a chance too.
// Saved when a player leaves and at each map's end (every 20 minutes). Humans only (by SteamID): not the bots.
// At each map start, each player sees the top 5 and their own place, in one [STATS] line; at its end, their map
// (kills, deaths, best streak, headshots) and their place before and after it.
// Also each human's map MVPs per month (table "cs_war3_ai_mvp"): on top of the scoreboard, bots included, at a
// map's end.
#include <amxmodx>
#include <sqlx>
#include "common.inc"
#include "database.inc"
#include "kills.inc"

new g_month[8]  // the month this map started in, "2026-10" (the VPS's time): its kills count for it, even after midnight
new g_kills[33]
new g_deaths[33]
new g_headshots[33]
new g_streak[33], g_best_streak[33]  // kills without dying on this map: now, and the best
new g_place_start[33]                // the player's place this month when this map started for them (0: none)

public plugin_init()
{
	register_plugin("Ranking of the month", "1.0", "cs-war3-ai")
	get_time("%Y-%m", g_month, charsmax(g_month))
	register_kills()
	// The map's end (the intermission).
	register_event("30", "count_mvp", "a")
	connect_db()
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_monthly (month TEXT, steamid TEXT, kills INTEGER, deaths INTEGER, \
		headshots INTEGER, PRIMARY KEY (month, steamid))")
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_mvp (month TEXT, steamid TEXT, count INTEGER, \
		PRIMARY KEY (month, steamid))")
}

// The map's MVP (common.inc), if it is a human with a SteamID who beat at least one other human who scored: one more
// this month. Not the best human when a bot is on top, nor a player alone with the bots: they would be it every map.
public count_mvp()
{
	new best = map_mvp()
	new bool:counted = best && g_steamid[best][0] && humans_who_scored() >= 2
	// Each human's line first (it saves their map), then the MVP.
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
		show_map(players[i])
	if (counted)
		run("INSERT INTO cs_war3_ai_mvp VALUES ('%s', '%s', 1) \
			ON CONFLICT (month, steamid) DO UPDATE SET count = count + 1", g_month, g_steamid[best])
}

// The humans in a team who killed on this map.
humans_who_scored()
{
	new players[32], count = humans_playing(players), scored
	for (new i = 0; i < count; i++)
		if (get_user_frags(players[i]) > 0)
			scored++
	return scored
}

public client_connect(id)
{
	remove_task(id)
	g_steamid[id][0] = 0
	g_kills[id] = 0
	g_deaths[id] = 0
	g_headshots[id] = 0
	g_streak[id] = 0
	g_best_streak[id] = 0
	g_place_start[id] = 0
}

public client_authorized(id, const authid[])
{
	keep_steamid(id, authid)
}

// At arrival and at each map start (every 20 minutes), in one line: the month's top 5 and the player's place.
public client_putinserver(id)
{
	set_task(10.0, "show_top", id)
}

public show_top(id)
{
	if (!is_user_connected(id))
		return
	// The same order as the web page: kills - deaths, then kills. The names the stats page knows (web_stats.sma).
	new line[192], name[32], length = formatex(line, charsmax(line), "Top 5 this month:")
	new Handle:query = SQL_PrepareQuery(g_db, "SELECT COALESCE(n.name, '?'), m.kills - m.deaths \
		FROM cs_war3_ai_monthly m LEFT JOIN cs_war3_ai_names n ON n.steamid = m.steamid \
		WHERE m.month = '%s' \
		ORDER BY m.kills - m.deaths DESC, m.kills DESC LIMIT 5", g_month)
	new place = 0
	if (SQL_Execute(query))
	{
		while (SQL_MoreResults(query))
		{
			SQL_ReadResult(query, 0, name, charsmax(name))
			// Short names, so that the whole line fits; not cut inside a letter (UTF-8).
			if (strlen(name) > 15)
			{
				new cut = 15
				while (cut > 0 && (name[cut] & 0xC0) == 0x80)
					cut--
				name[cut] = 0
			}
			length += formatex(line[length], charsmax(line) - length, "%s %d. %s %+d", place ? "," : "", place + 1, name,
				SQL_ReadResult(query, 1))
			place++
			SQL_NextRow(query)
		}
	}
	SQL_FreeHandle(query)
	if (!place)
	{
		client_print_color(id, print_team_default, "^4[STATS]^1 The ranking of the month starts: your kills count from now.")
		return
	}
	if (g_steamid[id][0])
	{
		new total
		g_place_start[id] = month_place(id, total)
		if (g_place_start[id])
			formatex(line[length], charsmax(line) - length, " | You: #%d of %d", g_place_start[id], total)
		else
			formatex(line[length], charsmax(line) - length, " | You: not ranked yet")
	}
	client_print_color(id, print_team_default, "^4[STATS]^1 %s", line)
}

// The player's place this month (0: not ranked yet), and how many are ranked. The same order as the web page.
month_place(id, &total)
{
	new place = 0
	new Handle:query = SQL_PrepareQuery(g_db,
		"SELECT (SELECT COUNT(*) FROM cs_war3_ai_monthly o WHERE o.month = m.month \
		AND (o.kills - o.deaths > m.kills - m.deaths \
		OR (o.kills - o.deaths = m.kills - m.deaths AND o.kills > m.kills))) + 1, \
		(SELECT COUNT(*) FROM cs_war3_ai_monthly o WHERE o.month = m.month) FROM cs_war3_ai_monthly m \
		WHERE m.month = '%s' AND m.steamid = '%s'", g_month, g_steamid[id])
	if (SQL_Execute(query) && SQL_MoreResults(query))
	{
		place = SQL_ReadResult(query, 0)
		total = SQL_ReadResult(query, 1)
	}
	SQL_FreeHandle(query)
	return place
}

// At the map's end, each human's map in one [STATS] line: kills, deaths, best streak, headshots, and their place this
// month before and after it (saved here, so that the place counts this map).
show_map(id)
{
	new kills = g_kills[id], deaths = g_deaths[id], headshots = g_headshots[id]
	if (!g_steamid[id][0] || kills + deaths == 0)
		return
	save(id)
	new line[160], total, place = month_place(id, total)
	new length = formatex(line, charsmax(line), "Your map: %d kills, %d deaths, best streak %d, %d%% headshots.",
		kills, deaths, g_best_streak[id], kills ? headshots * 100 / kills : 0)
	if (place && g_place_start[id] && place != g_place_start[id])
		formatex(line[length], charsmax(line) - length, " Month: #%d -> #%d", g_place_start[id], place)
	else if (place)
		formatex(line[length], charsmax(line) - length, " Month: #%d", place)
	client_print_color(id, print_team_default, "^4[STATS]^1 %s", line)
}

// When a player leaves, and for every player at each map's end and when the server stops: AMX Mod X calls it then
// too.
public client_disconnected(id)
{
	remove_task(id)
	save(id)
	g_steamid[id][0] = 0
}

// Adds what the player did since the last save to the current month (the VPS's time).
save(id)
{
	if (!g_steamid[id][0] || g_kills[id] + g_deaths[id] == 0)
		return
	run("INSERT INTO cs_war3_ai_monthly VALUES ('%s', '%s', %d, %d, %d) ON CONFLICT (month, steamid) \
		DO UPDATE SET kills = kills + excluded.kills, deaths = deaths + excluded.deaths, \
		headshots = headshots + excluded.headshots",
		g_month, g_steamid[id], g_kills[id], g_deaths[id], g_headshots[id])
	g_kills[id] = 0
	g_deaths[id] = 0
	g_headshots[id] = 0
}

// Every kill, War3FT's spells included (kills.inc).
public on_kill(killer, victim, bool:headshot, const weapon[])
{
	g_deaths[victim]++
	g_streak[victim] = 0
	if (killer && killer != victim)
	{
		g_kills[killer]++
		if (headshot)
			g_headshots[killer]++
		g_best_streak[killer] = max(g_best_streak[killer], ++g_streak[killer])
	}
}
