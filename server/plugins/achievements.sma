// Achievements: goals to reach over time (kills, headshots, weapons, streaks...), announced when unlocked.
// "/ach" in chat shows yours; the web page shows them too, from these tables (in War3FT's database,
// data/sqlite3/war3ft.sq3):
// - ach_list: the achievements below, written at each map start, so the web page has the same list;
// - ach_progress: each human's counters, added up over every map;
// - ach_unlocked: what each human unlocked, and when.
// Humans only (by SteamID): bots are not counted.
#include <amxmodx>
#include <engine>  // entity_get_int()
#include <sqlx>
#include "common.inc"
#include "database.inc"

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
	"Get 10 kills with 10 HP or less", "Play 10 hours on the server"
}
new const ACH_COUNTER[ACHIEVEMENTS] = {
	KILLS, KILLS, KILLS, KILLS, HEADSHOTS, HEADSHOTS, KNIFE, DEAGLE, AWP, BEST_STREAK, BEST_STREAK, AIR, LOW_HP, SECONDS
}
new const ACH_GOAL[ACHIEVEMENTS] = { 1, 100, 1000, 10000, 100, 1000, 10, 100, 100, 10, 20, 25, 10, 36000 }

new g_steamid[33][35]             // empty: not counted (bot, or no SteamID)
new g_saved[33][COUNTERS]          // what the database had when the player arrived on this map
new g_new[33][COUNTERS]            // what they did since (best_streak: their best on this map)
new bool:g_unlocked[33][ACHIEVEMENTS]
new g_streak[33]
new g_arrival[33]

public plugin_init()
{
	register_plugin("Achievements", "1.0", "cs-war3-ai")
	register_event("DeathMsg", "on_death", "a")
	register_clcmd("say /ach", "cmd_achievements")
	register_clcmd("say /achievements", "cmd_achievements")

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

public plugin_end()
{
	SQL_FreeHandle(g_db)
}

// Arrival, also at each map change: a clean slate until Steam confirms who the player is.
public client_connect(id)
{
	remove_task(id)
	g_steamid[id][0] = 0
	g_streak[id] = 0
	arrayset(g_saved[id], 0, COUNTERS)
	arrayset(g_new[id], 0, COUNTERS)
	arrayset(g_unlocked[id], false, ACHIEVEMENTS)
}

// Steam has confirmed the SteamID: loads the counters and the unlocked achievements.
public client_authorized(id, const authid[])
{
	if (is_user_bot(id) || !is_real_steamid(authid))
		return
	// Nothing to escape in a real SteamID, but it still goes through SQL_QuoteString.
	SQL_QuoteString(Empty_Handle, g_steamid[id], charsmax(g_steamid[]), authid)
	g_arrival[id] = get_systime()

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

// At arrival and at each map start: the closest goal, just after the place of the month (monthly.sma).
public client_putinserver(id)
{
	set_task(12.0, "show_closest", id)
}

public show_closest(id)
{
	if (!g_steamid[id][0])
		return
	// The locked achievement with the biggest share done.
	new best = -1, Float:best_share = -1.0
	for (new i = 0; i < ACHIEVEMENTS; i++)
	{
		new Float:share = float(value(id, ACH_COUNTER[i])) / float(ACH_GOAL[i])
		if (!g_unlocked[id][i] && share > best_share)
		{
			best = i
			best_share = share
		}
	}
	if (best == -1)
		client_print(id, print_chat, "[Achievement] You have them all. Respect!")
	else
		client_print(id, print_chat, "[Achievement] Closest: %s (%s), %d to go. /ach for the list.",
			ACH_NAME[best], ACH_DESCRIPTION[best], to_go(id, best))
}

// What is left to reach an achievement; the time in hours, rounded up.
to_go(id, achievement)
{
	new left = ACH_GOAL[achievement] - value(id, ACH_COUNTER[achievement])
	return ACH_COUNTER[achievement] == SECONDS ? (left + 3599) / 3600 : left
}

// When a player leaves, and for every player at each map's end (every 30 minutes) and when the server stops:
// AMX Mod X calls it then too.
public client_disconnected(id)
{
	remove_task(id)
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
	g_new[id][SECONDS] = get_systime() - g_arrival[id]
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
	if (counter == SECONDS)
		return g_saved[id][counter] + get_systime() - g_arrival[id]
	return g_saved[id][counter] + g_new[id][counter]
}

public on_death()
{
	new killer = read_data(1)
	new victim = read_data(2)
	g_streak[victim] = 0
	if (!killer || killer == victim || !g_steamid[killer][0])
		return

	new weapon[16]
	read_data(4, weapon, charsmax(weapon))
	// The counters before this kill: only those it raises can come close to a goal.
	new before[COUNTERS]
	before = g_new[killer]
	g_new[killer][KILLS]++
	if (read_data(3))
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
	// Close to a goal: a word when 10 % is left, once: only when this kill raised that counter. Not the streak
	// (it starts again, and its best on this map may still be below the saved one).
	for (new i = 0; i < ACHIEVEMENTS; i++)
	{
		new counter = ACH_COUNTER[i]
		if (!g_unlocked[killer][i] && counter != BEST_STREAK && g_new[killer][counter] != before[counter]
			&& to_go(killer, i) == max(1, ACH_GOAL[i] / 10))
			client_print(killer, print_chat, "[Achievement] %d more for %s: %s!", to_go(killer, i), ACH_NAME[i],
				ACH_DESCRIPTION[i])
	}
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
		client_print(0, print_chat, "[Achievement] %s unlocked %s: %s!", name, ACH_NAME[i], ACH_DESCRIPTION[i])
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
