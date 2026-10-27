// The goal of the week: the same for everyone, a new one every Monday (the VPS's time). Each human's count is saved in
// data/sqlite3/war3ft.sq3 (tables cs_war3_ai_weekly_goal and cs_war3_ai_weekly) when they leave and at each map's end;
// the stats page shows it. /goal in the chat: this week's goal and your count. Humans only (by SteamID); no prize.
#include <amxmodx>
#include <sqlx>
#include "common.inc"
#include "database.inc"
#include "kills.inc"

// One goal a week, in turn: the death notice's weapon ("" = any), headshots only or not, how many, and its text.
enum _:Goal { WEAPON[16], bool:HEADSHOTS, TARGET, TEXT[48] }
new const GOALS[][Goal] = {
	{ "ak47", true, 50, "50 headshots with the AK-47" },
	{ "m4a1", false, 100, "100 kills with the M4A1" },
	{ "deagle", true, 25, "25 headshots with the Desert Eagle" },
	{ "knife", false, 15, "15 knife kills" },
	{ "awp", false, 40, "40 kills with the AWP" },
	{ "", true, 100, "100 headshots, any weapon" },
	{ "mp5navy", false, 60, "60 kills with the MP5" },
	{ "", false, 250, "250 kills, any weapon" }
}

new g_week[11]         // the week's Monday, "2026-10-26", as the stats page counts it (SQLite, the VPS's time)
new g_goal             // this week's goal, in GOALS
new g_count[33]        // the player's count this week
new g_unsaved[33]      // the part of it not saved yet

public plugin_init()
{
	register_plugin("Goal of the week", "1.0", "cs-war3-ai")
	register_kills()
	register_clcmd("say /goal", "cmd_goal")
	register_clcmd("say_team /goal", "cmd_goal")
	connect_db()
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_weekly_goal (week TEXT PRIMARY KEY, goal TEXT, target INTEGER)")
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_weekly (week TEXT, steamid TEXT, count INTEGER, \
		PRIMARY KEY (week, steamid))")
	// The week this map started in (its Monday): its kills count for it, even after Sunday midnight. Its goal: the
	// weeks since a fixed day, in turn.
	new Handle:query = SQL_PrepareQuery(g_db, "SELECT date('now', 'localtime', 'weekday 0', '-6 days'), \
		CAST(julianday(date('now', 'localtime', 'weekday 0', '-6 days')) / 7 AS INTEGER)")
	if (SQL_Execute(query) && SQL_MoreResults(query))
	{
		SQL_ReadResult(query, 0, g_week, charsmax(g_week))
		g_goal = SQL_ReadResult(query, 1) % sizeof GOALS
	}
	SQL_FreeHandle(query)
	// For the stats page: this week's goal, written by the first map of the week.
	run("INSERT OR IGNORE INTO cs_war3_ai_weekly_goal VALUES ('%s', '%s', %d)",
		g_week, GOALS[g_goal][TEXT], GOALS[g_goal][TARGET])
}

public client_connect(id)
{
	g_steamid[id][0] = 0
	g_count[id] = 0
	g_unsaved[id] = 0
}

public client_authorized(id, const authid[])
{
	if (!keep_steamid(id, authid))
		return
	new Handle:query = SQL_PrepareQuery(g_db, "SELECT count FROM cs_war3_ai_weekly WHERE week = '%s' AND steamid = '%s'",
		g_week, g_steamid[id])
	if (SQL_Execute(query) && SQL_MoreResults(query))
		g_count[id] = SQL_ReadResult(query, 0)
	SQL_FreeHandle(query)
}

// When a player leaves, and for every player at each map's end: AMX Mod X calls it then too.
public client_disconnected(id)
{
	if (g_steamid[id][0] && g_unsaved[id])
		run("INSERT INTO cs_war3_ai_weekly VALUES ('%s', '%s', %d) ON CONFLICT (week, steamid) \
			DO UPDATE SET count = count + excluded.count", g_week, g_steamid[id], g_unsaved[id])
	g_steamid[id][0] = 0
}

// Every kill, War3FT's spells included (kills.inc).
public on_kill(killer, victim, bool:headshot, const weapon[])
{
	if (!killer || killer == victim || !g_steamid[killer][0]
		|| GOALS[g_goal][WEAPON][0] && !equal(weapon, GOALS[g_goal][WEAPON])
		|| GOALS[g_goal][HEADSHOTS] && !headshot)
		return
	g_unsaved[killer]++
	// Once: the kill that reaches the goal.
	if (++g_count[killer] == GOALS[g_goal][TARGET])
	{
		new name[32]
		get_user_name(killer, name, charsmax(name))
		client_print_color(0, print_team_default, "^4[STATS]^1 %s reached this week's goal: %s!", name, GOALS[g_goal][TEXT])
	}
}

public cmd_goal(id)
{
	new target = GOALS[g_goal][TARGET]
	if (g_steamid[id][0])
		client_print_color(id, print_team_default, "^4[STATS]^1 This week: %s. You: %d / %d. A new goal every Monday.",
			GOALS[g_goal][TEXT], min(g_count[id], target), target)
	else
		client_print_color(id, print_team_default, "^4[STATS]^1 This week: %s. A new goal every Monday.", GOALS[g_goal][TEXT])
	return PLUGIN_HANDLED
}
