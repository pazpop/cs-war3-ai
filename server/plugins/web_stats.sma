// For the stats page, in War3FT's database (data/sqlite3/war3ft.sq3), in our own tables:
// - cs_war3_ai_names: each human's name (in SQLite, War3FT only keeps the SteamID);
// - cs_war3_ai_combat: the top 100 of CS's combat ranking (/rank, /top15), copied again at each map start.
#include <amxmodx>
#include <sqlx>
#include <csstats>
#include "common.inc"
#include "database.inc"

#define COMBAT_TOP 100

new g_domain[64]  // the stats site, from the entrypoint (+localinfo stats_domain)

public plugin_init()
{
	register_plugin("Stats for the web", "1.0", "cs-war3-ai")
	connect_db()
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_names (steamid TEXT PRIMARY KEY, name TEXT NOT NULL, seen INTEGER NOT NULL)")
	get_localinfo("stats_domain", g_domain, charsmax(g_domain))
	register_clcmd("say /mystats", "cmd_mystats")
}

// The link to the player's own page, in the chat and in the console (to copy it).
public cmd_mystats(id)
{
	if (!g_steamid[id][0])
	{
		client_print(id, print_chat, "[Stats] Needs a Steam account.")
		return PLUGIN_HANDLED
	}
	new Handle:query = SQL_PrepareQuery(g_db, "SELECT player_id FROM wc3_player WHERE player_steamid = '%s'",
		g_steamid[id])
	if (SQL_Execute(query) && SQL_MoreResults(query))
	{
		client_print(id, print_chat, "[Stats] Your page: https://%s/player.php?id=%d", g_domain, SQL_ReadResult(query, 0))
		client_print(id, print_console, "https://%s/player.php?id=%d", g_domain, SQL_ReadResult(query, 0))
	}
	else
		client_print(id, print_chat, "[Stats] Your page is not ready yet: try again in a minute.")
	SQL_FreeHandle(query)
	return PLUGIN_HANDLED
}

// CSX saves its ranking at the end of a map (every 20 minutes, see game.cfg in server/Dockerfile): copying it at the
// start of the next one is enough.
public plugin_cfg()
{
	export_combat_ranking()
}

// When Steam confirms who the player is, and on leaving: the name may have changed during the game.
public client_authorized(id, const authid[])
{
	if (keep_steamid(id, authid))
		save_name(id)
}

public client_disconnected(id)
{
	remove_task(id)
	save_name(id)
	g_steamid[id][0] = 0
}

// A new name during the game (or "Player", for a name the AI found offensive): on the stats page at once, not only
// when the player leaves. Half a second later: the game applies it after this.
public client_infochanged(id)
{
	new old[32], name[32]
	get_user_name(id, old, charsmax(old))
	get_user_info(id, "name", name, charsmax(name))
	if (!is_user_connected(id) || equal(old, name))
		return
	remove_task(id)
	set_task(0.5, "save_name", id)
}

public save_name(id)
{
	if (!g_steamid[id][0])
		return
	// The name comes from the player: SQL_QuoteString escapes it for SQLite (' becomes '').
	new name[64], name_sql[132]
	get_user_name(id, name, charsmax(name))
	SQL_QuoteString(Empty_Handle, name_sql, charsmax(name_sql), name)
	run("INSERT INTO cs_war3_ai_names VALUES ('%s', '%s', strftime('%%s', 'now')) \
		ON CONFLICT (steamid) DO UPDATE SET name = excluded.name, seen = excluded.seen", g_steamid[id], name_sql)
}

// The ranking is by SteamID (csstats_rank 1): every bot shares the SteamID "BOT", left out below. In one transaction:
// the stats page never sees the table half written.
export_combat_ranking()
{
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_combat (position INTEGER PRIMARY KEY, steamid TEXT NOT NULL, \
		name TEXT NOT NULL, kills INTEGER, deaths INTEGER, headshots INTEGER, shots INTEGER, hits INTEGER, damage INTEGER)")
	run("BEGIN")
	run("DELETE FROM cs_war3_ai_combat")
	new stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS], name[64], name_sql[132], steamid[35], steamid_sql[72]
	new index = 0, count = 0
	if (get_statsnum())
	{
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
			run("INSERT INTO cs_war3_ai_combat VALUES (%d, '%s', '%s', %d, %d, %d, %d, %d, %d)",
				place, steamid_sql, name_sql, stats[0], stats[1], stats[2], stats[4], stats[5], stats[6])
		}
		while (index && count < COMBAT_TOP)
	}
	run("COMMIT")
}
