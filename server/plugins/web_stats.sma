// For the stats page, in War3FT's database (data/sqlite3/war3ft.sq3), in our own tables:
// - cs_war3_ai_names: each human's name (in SQLite, War3FT only keeps the SteamID);
// - cs_war3_ai_combat: the top 100 of CS's combat ranking (/rank, /top15), copied again at each map start.
#include <amxmodx>
#include <sqlx>
#include <csstats>
#include "common.inc"

#define COMBAT_TOP 100

new Handle:g_db
new g_domain[64]  // the stats site, from the entrypoint (+localinfo stats_domain)

public plugin_init()
{
	register_plugin("Stats for the web", "1.0", "cs-war3-ai")
	SQL_SetAffinity("sqlite")
	g_db = SQL_MakeDbTuple("", "", "", "war3ft")
	SQL_ThreadQuery(g_db, "on_query_done",
		"CREATE TABLE IF NOT EXISTS cs_war3_ai_names (steamid TEXT PRIMARY KEY, name TEXT NOT NULL, seen INTEGER NOT NULL)")
	get_localinfo("stats_domain", g_domain, charsmax(g_domain))
	register_clcmd("say /mystats", "cmd_mystats")
}

// The link to the player's own page, in the chat and in the console (to copy it).
public cmd_mystats(id)
{
	new steamid[35], steamid_sql[72], query[128], data[2]
	get_user_authid(id, steamid, charsmax(steamid))
	if (!is_real_steamid(steamid))
	{
		client_print(id, print_chat, "[Stats] Needs a Steam account.")
		return PLUGIN_HANDLED
	}
	SQL_QuoteString(Empty_Handle, steamid_sql, charsmax(steamid_sql), steamid)
	formatex(query, charsmax(query), "SELECT player_id FROM wc3_player WHERE player_steamid = '%s'", steamid_sql)
	// The answer comes later: the userid tells whether the same player is still there.
	data[0] = id
	data[1] = get_user_userid(id)
	SQL_ThreadQuery(g_db, "on_mystats", query, data, sizeof data)
	return PLUGIN_HANDLED
}

public on_mystats(fail_state, Handle:query, error[], errnum, data[], size)
{
	new id = data[0]
	if (fail_state != TQUERY_SUCCESS)
	{
		log_amx("web stats: %s", error)
		return
	}
	if (!is_user_connected(id) || get_user_userid(id) != data[1])
		return
	if (!SQL_MoreResults(query))
	{
		client_print(id, print_chat, "[Stats] Your page is not ready yet: try again in a minute.")
		return
	}
	client_print(id, print_chat, "[Stats] Your page: https://%s/player.php?id=%d", g_domain, SQL_ReadResult(query, 0))
	client_print(id, print_console, "https://%s/player.php?id=%d", g_domain, SQL_ReadResult(query, 0))
}

// After plugin_init: queries run in order. CSX saves its ranking at the end of a map (every 30 minutes, see
// game.cfg in server/Dockerfile): copying it at the start of the next one is enough.
public plugin_cfg()
{
	export_combat_ranking()
}

public plugin_end()
{
	SQL_FreeHandle(g_db)
}

// When Steam confirms who the player is, and on leaving: the name may have changed during the game.
public client_authorized(id)
{
	save_name(id)
}

public client_disconnected(id)
{
	save_name(id)
}

save_name(id)
{
	if (is_user_bot(id) || is_user_hltv(id))
		return

	new steamid[35], steamid_sql[72], name[64], name_sql[132], query[320]
	get_user_authid(id, steamid, charsmax(steamid))
	if (!is_real_steamid(steamid))
		return

	// The name comes from the player: SQL_QuoteString escapes it for SQLite (' becomes ''). The SteamID too, like
	// everywhere else.
	get_user_name(id, name, charsmax(name))
	SQL_QuoteString(Empty_Handle, name_sql, charsmax(name_sql), name)
	SQL_QuoteString(Empty_Handle, steamid_sql, charsmax(steamid_sql), steamid)
	formatex(query, charsmax(query),
		"INSERT INTO cs_war3_ai_names VALUES ('%s', '%s', strftime('%%s', 'now')) ON CONFLICT (steamid) DO UPDATE SET name = excluded.name, seen = excluded.seen", steamid_sql, name_sql)
	SQL_ThreadQuery(g_db, "on_query_done", query)
}

// The ranking is by SteamID (csstats_rank 1): every bot shares the SteamID "BOT", left out below.
export_combat_ranking()
{
	// Emptied, not dropped: the stats page always finds the table. For a moment it is empty or partial, then full.
	SQL_ThreadQuery(g_db, "on_query_done",
		"CREATE TABLE IF NOT EXISTS cs_war3_ai_combat (position INTEGER PRIMARY KEY, steamid TEXT NOT NULL, name TEXT NOT NULL, kills INTEGER, deaths INTEGER, headshots INTEGER, shots INTEGER, hits INTEGER, damage INTEGER)")
	SQL_ThreadQuery(g_db, "on_query_done", "DELETE FROM cs_war3_ai_combat")
	if (get_statsnum() == 0)
		return

	new stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS], name[64], name_sql[132], steamid[35], steamid_sql[72], query[512]
	new index = 0, count = 0
	do
	{
		// CSX's own place, as in /rank and /top15 (the skipped rows below keep theirs).
		new place = index + 1
		index = get_stats(index, stats, bodyhits, name, charsmax(name), steamid, charsmax(steamid))
		if (!is_real_steamid(steamid))
			continue
		count++
		// Both end up in a query: both are escaped.
		SQL_QuoteString(Empty_Handle, name_sql, charsmax(name_sql), name)
		SQL_QuoteString(Empty_Handle, steamid_sql, charsmax(steamid_sql), steamid)
		// stats[]: 0 kills, 1 deaths, 2 headshots, 3 team kills, 4 shots, 5 hits, 6 damage.
		formatex(query, charsmax(query),
			"INSERT INTO cs_war3_ai_combat VALUES (%d, '%s', '%s', %d, %d, %d, %d, %d, %d)",
			place, steamid_sql, name_sql, stats[0], stats[1], stats[2], stats[4], stats[5], stats[6])
		SQL_ThreadQuery(g_db, "on_query_done", query)
	}
	while (index && count < COMBAT_TOP)
}

public on_query_done(fail_state, Handle:query, error[], errnum, data[], size)
{
	if (fail_state != TQUERY_SUCCESS)
		log_amx("web stats: %s", error)
}
