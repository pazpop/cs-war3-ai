// Achievements: goals to reach over time (kills, headshots, weapons, streaks...), announced when unlocked.
// "/ach" in chat shows yours; the web page shows them too, from these tables (in War3FT's database,
// data/sqlite3/war3ft.sq3):
// - ach_list: the achievements below, written at each map start, so the web page has the same list;
// - ach_progress: each human's counters, added up over every map;
// - ach_unlocked: what each human unlocked, and when.
// Humans only (by SteamID): bots are not counted. (The ach_ tables are ours too, despite their names.)
#include <amxmodx>
#include <engine>  // entity_get_int()
#include <sqlx>
#include "common.inc"
#include "database.inc"
#include "kills.inc"

// The counters, and their columns in ach_progress.
enum { KILLS, HEADSHOTS, KNIFE, DEAGLE, AWP, AIR, LOW_HP, SECONDS, BEST_STREAK, COUNTERS }
new const COLUMNS[COUNTERS][] = { "kills", "headshots", "knife", "deagle", "awp", "air", "low_hp", "seconds", "best_streak" }

// Each achievement: id, name, description, counter, goal.
#define ACHIEVEMENTS 14
new const ACH_ID[ACHIEVEMENTS][] = {
	"first_kill", "centurion", "veteran", "god_of_war", "headhunter", "boom_headshot", "knife_party",
	"desert_eagle", "sniper", "unstoppable", "godlike", "fly_away", "last_breath", "regular"
}
new const ACH_NAME[ACHIEVEMENTS][] = {
	"First Kill", "Centurion", "Veteran", "God of War", "Headhunter", "Boom Headshot", "Knife Party",
	"Desert Eagle", "Sniper", "Unstoppable", "Godlike", "Fly Away", "Last Breath", "Regular"
}
new const ACH_DESCRIPTION[ACHIEVEMENTS][] = {
	"Get your first kill", "Get 100 kills", "Get 1,000 kills", "Get 10,000 kills", "Get 100 headshots",
	"Get 1,000 headshots", "Get 10 knife kills", "Get 100 kills with the Desert Eagle", "Get 100 kills with the AWP",
	"Get 10 kills without dying", "Get 20 kills without dying", "Kill 25 enemies in the air",
	"Get 10 kills with 10 HP or less", "Play 10 hours in a team"
}
new const ACH_COUNTER[ACHIEVEMENTS] = {
	KILLS, KILLS, KILLS, KILLS, HEADSHOTS, HEADSHOTS, KNIFE, DEAGLE, AWP, BEST_STREAK, BEST_STREAK, AIR, LOW_HP, SECONDS
}
new const ACH_GOAL[ACHIEVEMENTS] = { 1, 100, 1000, 10000, 100, 1000, 10, 100, 100, 10, 20, 25, 10, 36000 }

new g_saved[33][COUNTERS]          // what the database had when the player arrived on this map
new g_new[33][COUNTERS]            // what they did since (best_streak: their best on this map)
new bool:g_unlocked[33][ACHIEVEMENTS]
new g_streak[33]

#define TIME_STEP 60  // seconds: the time played ("Regular") goes up by a minute for each minute in a team

public plugin_init()
{
	register_plugin("Achievements", "1.0", "cs-war3-ai")
	register_kills()
	register_clcmd("say /ach", "cmd_achievements")
	register_clcmd("say /achievements", "cmd_achievements")
	set_task(float(TIME_STEP), "count_time", .flags = "b")

	connect_db()
	run("CREATE TABLE IF NOT EXISTS ach_progress (steamid TEXT PRIMARY KEY, kills INTEGER DEFAULT 0, \
		headshots INTEGER DEFAULT 0, knife INTEGER DEFAULT 0, deagle INTEGER DEFAULT 0, awp INTEGER DEFAULT 0, \
		air INTEGER DEFAULT 0, low_hp INTEGER DEFAULT 0, seconds INTEGER DEFAULT 0, best_streak INTEGER DEFAULT 0)")
	run("CREATE TABLE IF NOT EXISTS ach_unlocked (steamid TEXT, achievement TEXT, unlocked INTEGER, \
		PRIMARY KEY (steamid, achievement))")
	// In one transaction: the web page never sees the list half written.
	run("BEGIN")
	run("DROP TABLE IF EXISTS ach_list")
	run("CREATE TABLE ach_list (position INTEGER PRIMARY KEY, id TEXT, name TEXT, description TEXT, \
		counter TEXT, goal INTEGER)")
	for (new i = 0; i < ACHIEVEMENTS; i++)
		run("INSERT INTO ach_list VALUES (%d, '%s', '%s', '%s', '%s', %d)",
			i + 1, ACH_ID[i], ACH_NAME[i], ACH_DESCRIPTION[i], COLUMNS[ACH_COUNTER[i]], ACH_GOAL[i])
	run("COMMIT")
}

// Arrival, also at each map change: a clean slate until Steam confirms who the player is.
public client_connect(id)
{
	g_steamid[id][0] = 0
	g_streak[id] = 0
	arrayset(g_saved[id], 0, COUNTERS)
	arrayset(g_new[id], 0, COUNTERS)
	arrayset(g_unlocked[id], false, ACHIEVEMENTS)
}

// Steam has confirmed the SteamID: loads the counters and the unlocked achievements.
public client_authorized(id, const authid[])
{
	if (!keep_steamid(id, authid))
		return

	new Handle:query = SQL_PrepareQuery(g_db,
		"SELECT kills, headshots, knife, deagle, awp, air, low_hp, seconds, best_streak FROM ach_progress \
		WHERE steamid = '%s'", g_steamid[id])
	if (SQL_Execute(query) && SQL_MoreResults(query))
		for (new c = 0; c < COUNTERS; c++)
			g_saved[id][c] = SQL_ReadResult(query, c)
	SQL_FreeHandle(query)

	new achievement[32]
	query = SQL_PrepareQuery(g_db, "SELECT achievement FROM ach_unlocked WHERE steamid = '%s'", g_steamid[id])
	if (SQL_Execute(query))
	{
		while (SQL_MoreResults(query))
		{
			SQL_ReadResult(query, 0, achievement, charsmax(achievement))
			for (new i = 0; i < ACHIEVEMENTS; i++)
				if (equal(achievement, ACH_ID[i]))
					g_unlocked[id][i] = true
			SQL_NextRow(query)
		}
	}
	SQL_FreeHandle(query)
}

// When a player leaves, and for every player at each map's end (every 20 minutes) and when the server stops:
// AMX Mod X calls it then too.
public client_disconnected(id)
{
	save(id)
	g_steamid[id][0] = 0
}

// Adds this map's counters to the database (the best streak is kept if higher).
save(id)
{
	if (!g_steamid[id][0])
		return
	// The time ("Regular") grows without any kill: check it now too.
	check_unlocks(id)
	run("INSERT INTO ach_progress (steamid) VALUES ('%s') ON CONFLICT (steamid) DO NOTHING", g_steamid[id])
	run("UPDATE ach_progress SET kills = kills + %d, headshots = headshots + %d, knife = knife + %d, \
		deagle = deagle + %d, awp = awp + %d, air = air + %d, low_hp = low_hp + %d, seconds = seconds + %d, \
		best_streak = max(best_streak, %d) WHERE steamid = '%s'",
		g_new[id][KILLS], g_new[id][HEADSHOTS], g_new[id][KNIFE], g_new[id][DEAGLE], g_new[id][AWP],
		g_new[id][AIR], g_new[id][LOW_HP], g_new[id][SECONDS], g_new[id][BEST_STREAK], g_steamid[id])
}

value(id, counter)
{
	if (counter == BEST_STREAK)
		return max(g_saved[id][counter], g_new[id][counter])
	return g_saved[id][counter] + g_new[id][counter]
}

// The time played, only in a team (T or CT): a player left as a spectator (afk.sma) earns no "Regular".
public count_time()
{
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
	{
		new team = get_user_team(players[i])
		if (g_steamid[players[i]][0] && (team == 1 || team == 2))
			g_new[players[i]][SECONDS] += TIME_STEP
	}
}

// Every kill, War3FT's spells included (kills.inc).
public on_kill(killer, victim, bool:headshot, const weapon[])
{
	g_streak[victim] = 0
	if (!killer || killer == victim || !g_steamid[killer][0])
		return

	g_new[killer][KILLS]++
	if (headshot)
		g_new[killer][HEADSHOTS]++
	if (equal(weapon, "knife"))
		g_new[killer][KNIFE]++
	else if (equal(weapon, "deagle"))
		g_new[killer][DEAGLE]++
	else if (equal(weapon, "awp"))
		g_new[killer][AWP]++
	if (!(entity_get_int(victim, EV_INT_flags) & FL_ONGROUND))
		g_new[killer][AIR]++
	if (is_user_alive(killer) && get_user_health(killer) <= 10)
		g_new[killer][LOW_HP]++
	g_new[killer][BEST_STREAK] = max(g_new[killer][BEST_STREAK], ++g_streak[killer])

	check_unlocks(killer)
}

check_unlocks(id)
{
	new name[32]
	for (new i = 0; i < ACHIEVEMENTS; i++)
	{
		if (g_unlocked[id][i] || value(id, ACH_COUNTER[i]) < ACH_GOAL[i])
			continue
		g_unlocked[id][i] = true
		run("INSERT OR IGNORE INTO ach_unlocked VALUES ('%s', '%s', strftime('%%s', 'now'))", g_steamid[id], ACH_ID[i])
		get_user_name(id, name, charsmax(name))
		client_print_color(0, print_team_default, "^4[STATS]^1 %s unlocked %s: %s!", name, ACH_NAME[i], ACH_DESCRIPTION[i])
	}
}

// The list, with each one's progress, in the same window as the guide. The in-game browser reads it as HTML:
// <pre> keeps the lines (names and descriptions are ours: no HTML in them).
public cmd_achievements(id)
{
	if (!g_steamid[id][0])
	{
		client_print(id, print_chat, "[Achievement] Needs a Steam account.")
		return PLUGIN_HANDLED
	}
	// The time ("Regular") counts on its own: check it now.
	check_unlocks(id)

	new text[1536], length, count
	for (new i = 0; i < ACHIEVEMENTS; i++)
		if (g_unlocked[id][i])
			count++
	length = formatex(text, charsmax(text),
		"<html><body style=^"background:#14161a;color:#e4e4e4^"><pre style=^"font-size:16px^">\
		Your achievements: %d of %d.^n^n", count, ACHIEVEMENTS)
	for (new i = 0; i < ACHIEVEMENTS; i++)
	{
		new progress = min(value(id, ACH_COUNTER[i]), ACH_GOAL[i]), goal = ACH_GOAL[i]
		// The time is counted in seconds: shown in hours.
		if (ACH_COUNTER[i] == SECONDS)
		{
			progress /= 3600
			goal /= 3600
		}
		length += formatex(text[length], charsmax(text) - length, "%s %s: %s (%d/%d)^n",
			g_unlocked[id][i] ? "[x]" : "[ ]", ACH_NAME[i], ACH_DESCRIPTION[i], progress, goal)
	}
	formatex(text[length], charsmax(text) - length, "</pre></body></html>")
	show_motd(id, text, "Achievements")
	return PLUGIN_HANDLED
}
