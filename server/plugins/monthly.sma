// The ranking of the month, for the web page: each human's kills, deaths and headshots, per month (in
// data/sqlite3/war3ft.sq3, table "cs_war3_ai_monthly"). A new month starts from zero: newcomers have a chance too.
// Saved when a player leaves and at each map's end (every 20 minutes). Humans only (by SteamID): not the bots.
// Also each human's map MVPs per month (table "cs_war3_ai_mvp"): on top of the scoreboard, bots included, at a
// map's end.
#include <amxmodx>
#include <sqlx>
#include "common.inc"
#include "database.inc"
#include "kills.inc"

new g_kills[33]
new g_deaths[33]
new g_headshots[33]

public plugin_init()
{
	register_plugin("Ranking of the month", "1.0", "cs-war3-ai")
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
	if (best && g_steamid[best][0] && humans_who_scored() >= 2)
		run("INSERT INTO cs_war3_ai_mvp VALUES (strftime('%%Y-%%m', 'now', 'localtime'), '%s', 1) \
			ON CONFLICT (month, steamid) DO UPDATE SET count = count + 1", g_steamid[best])
}

// The humans in a team who killed on this map.
humans_who_scored()
{
	new players[32], count, scored
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
	{
		new team = get_user_team(players[i])  // 1: T, 2: CT
		if ((team == 1 || team == 2) && get_user_frags(players[i]) > 0)
			scored++
	}
	return scored
}

public client_connect(id)
{
	remove_task(id)
	g_steamid[id][0] = 0
	g_kills[id] = 0
	g_deaths[id] = 0
	g_headshots[id] = 0
}

public client_authorized(id, const authid[])
{
	keep_steamid(id, authid)
}

// At arrival and at each map start (every 20 minutes): the player's place this month, once the chat is in view.
public client_putinserver(id)
{
	set_task(10.0, "show_place", id)
}

public show_place(id)
{
	if (!g_steamid[id][0])
		return
	// The same order as the web page: kills - deaths, then kills.
	new Handle:query = SQL_PrepareQuery(g_db,
		"SELECT (SELECT COUNT(*) FROM cs_war3_ai_monthly o WHERE o.month = m.month AND (o.kills - o.deaths > m.kills - m.deaths \
		OR (o.kills - o.deaths = m.kills - m.deaths AND o.kills > m.kills))) + 1, \
		(SELECT COUNT(*) FROM cs_war3_ai_monthly o WHERE o.month = m.month) FROM cs_war3_ai_monthly m \
		WHERE m.month = strftime('%%Y-%%m', 'now', 'localtime') AND m.steamid = '%s'", g_steamid[id])
	if (SQL_Execute(query) && SQL_MoreResults(query))
		client_print(id, print_chat, "[Month] You are #%d of %d this month (kills - deaths). Your page: /mystats",
			SQL_ReadResult(query, 0), SQL_ReadResult(query, 1))
	else
		client_print(id, print_chat, "[Month] The ranking of the month counts your kills from now. Your page: /mystats")
	SQL_FreeHandle(query)
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
	run("INSERT INTO cs_war3_ai_monthly VALUES (strftime('%%Y-%%m', 'now', 'localtime'), '%s', %d, %d, %d) ON CONFLICT (month, steamid) \
		DO UPDATE SET kills = kills + excluded.kills, deaths = deaths + excluded.deaths, \
		headshots = headshots + excluded.headshots",
		g_steamid[id], g_kills[id], g_deaths[id], g_headshots[id])
	g_kills[id] = 0
	g_deaths[id] = 0
	g_headshots[id] = 0
}

// Every kill, War3FT's spells included (kills.inc).
public on_kill(killer, victim, bool:headshot, const weapon[])
{
	g_deaths[victim]++
	if (killer && killer != victim)
	{
		g_kills[killer]++
		if (headshot)
			g_headshots[killer]++
	}
}
