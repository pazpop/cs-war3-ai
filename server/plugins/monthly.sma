// The ranking of the month, for the web page: each human's kills, deaths and headshots, per month (in
// data/sqlite3/war3ft.sq3, table "cs_war3_ai_monthly"). A new month starts from zero: newcomers have a chance too.
// Saved when a player leaves and at each map's end (every 30 minutes). Humans only (by SteamID): not the bots.
#include <amxmodx>
#include <sqlx>
#include "common.inc"
#include "database.inc"

new g_steamid[33][35]  // empty: not counted (bot, or no SteamID)
new g_kills[33]
new g_deaths[33]
new g_headshots[33]

public plugin_init()
{
	register_plugin("Ranking of the month", "1.0", "cs-war3-ai")
	register_event("DeathMsg", "on_death", "a")
	connect_db()
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_monthly (month TEXT, steamid TEXT, kills INTEGER, deaths INTEGER, \
		headshots INTEGER, PRIMARY KEY (month, steamid))")
}

public plugin_end()
{
	SQL_FreeHandle(g_db)
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
	if (!is_user_bot(id) && is_real_steamid(authid))
		SQL_QuoteString(Empty_Handle, g_steamid[id], charsmax(g_steamid[]), authid)
}

// At arrival and at each map start (every 30 minutes): the player's place this month, once the chat is in view.
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
		WHERE m.month = strftime('%%Y-%%m', 'now') AND m.steamid = '%s'", g_steamid[id])
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

// Adds what the player did since the last save to the current month (UTC).
save(id)
{
	if (!g_steamid[id][0] || g_kills[id] + g_deaths[id] == 0)
		return
	run("INSERT INTO cs_war3_ai_monthly VALUES (strftime('%%Y-%%m', 'now'), '%s', %d, %d, %d) ON CONFLICT (month, steamid) \
		DO UPDATE SET kills = kills + excluded.kills, deaths = deaths + excluded.deaths, \
		headshots = headshots + excluded.headshots",
		g_steamid[id], g_kills[id], g_deaths[id], g_headshots[id])
	g_kills[id] = 0
	g_deaths[id] = 0
	g_headshots[id] = 0
}

public on_death()
{
	new killer = read_data(1)
	new victim = read_data(2)
	g_deaths[victim]++
	if (killer && killer != victim)
	{
		g_kills[killer]++
		if (read_data(3))
			g_headshots[killer]++
	}
}
