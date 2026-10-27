// "votekick" in chat: a menu of the other humans; a player is kicked once 60 % of the other humans chose them.
// Counted against all the humans on the server, not only those who answer: one player alone never decides.
// Admins are not in the menu (immunity). The first time in a day: kicked; the second: banned 5 minutes; then 30
// (counted by SteamID in War3FT's database, table cs_war3_ai_votekicks, so that a map change does not forget it).
#include <amxmodx>
#include <sqlx>
#include "common.inc"
#include "database.inc"

#define SHARE 0.6           // share of the other humans needed
#define KICK_MIN_HUMANS 3   // with 2, one player could kick the other alone
#define KICKS_KEPT 86400    // seconds a kick by vote counts for the next one: a day

new g_wants_kick[33]        // the userid each player wants to kick (0: nobody)
new bool:g_told[33]         // whether everyone already saw this player's vote on this map

public plugin_init()
{
	register_plugin("Votekick", "1.0", "cs-war3-ai")
	register_clcmd("say votekick", "cmd_votekick")
	register_clcmd("say /votekick", "cmd_votekick")
	connect_db()
	run("CREATE TABLE IF NOT EXISTS cs_war3_ai_votekicks (steamid TEXT PRIMARY KEY, count INTEGER, last INTEGER)")
	// A kick older than a day no longer counts: its SteamID is not kept.
	run("DELETE FROM cs_war3_ai_votekicks WHERE last < strftime('%%s', 'now') - %d", KICKS_KEPT)
}

public client_disconnected(id)
{
	g_wants_kick[id] = 0
	g_told[id] = false
}

public cmd_votekick(id)
{
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	if (count < KICK_MIN_HUMANS)
	{
		client_print(id, print_chat, "[Votekick] Needs at least %d human players.", KICK_MIN_HUMANS)
		return PLUGIN_HANDLED
	}

	new menu = menu_create("Vote to kick:", "on_votekick_choice")
	new name[32], userid[12]
	for (new i = 0; i < count; i++)
	{
		if (players[i] == id || (get_user_flags(players[i]) & ADMIN_IMMUNITY))
			continue
		get_user_name(players[i], name, charsmax(name))
		num_to_str(get_user_userid(players[i]), userid, charsmax(userid))
		menu_additem(menu, name, userid)
	}
	// Every other human is an admin: an empty menu would not show.
	if (!menu_items(menu))
	{
		menu_destroy(menu)
		client_print(id, print_chat, "[Votekick] Nobody to vote against.")
		return PLUGIN_HANDLED
	}
	menu_display(id, menu)
	return PLUGIN_HANDLED
}

// One more player wants this target out: kicked once 60 % of the other humans agree.
public on_votekick_choice(id, menu, item)
{
	if (item < 0)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	new userid_text[12], item_access, callback
	menu_item_getinfo(menu, item, item_access, userid_text, charsmax(userid_text), "", 0, callback)
	menu_destroy(menu)

	new userid = str_to_num(userid_text)
	new target = find_player("k", userid)
	// Gone, or the same choice again (no chat flood).
	if (!target || g_wants_kick[id] == userid)
		return PLUGIN_HANDLED
	g_wants_kick[id] = userid

	// Counted again: players may have left while the menu was open.
	new players[32], count, votes
	get_players(players, count, "ch")
	if (count < KICK_MIN_HUMANS)
		return PLUGIN_HANDLED
	for (new i = 0; i < count; i++)
		if (players[i] != target && g_wants_kick[players[i]] == userid)
			votes++
	// The share of the other humans (the target does not vote), rounded up: with 5 others, 3.
	new goal = floatround(SHARE * float(count - 1), floatround_ceil)

	new name[32], target_name[32]
	get_user_name(id, name, charsmax(name))
	get_user_name(target, target_name, charsmax(target_name))
	// Told to everyone once a map; then to the voter only: switching between two players cannot flood the chat.
	client_print(g_told[id] ? id : 0, print_chat, "[Votekick] %s wants to kick %s (%d/%d). Type votekick to agree.", name,
		target_name, votes, goal)
	g_told[id] = true
	if (votes >= goal)
	{
		punish(target)
		for (new i = 1; i <= MaxClients; i++)
			if (g_wants_kick[i] == userid)
				g_wants_kick[i] = 0
	}
	return PLUGIN_HANDLED
}

// Kicked; banned 5 minutes the second time within a day, 30 the next times. Without a real SteamID: kicked only.
punish(target)
{
	new authid[35], times = 1
	get_user_authid(target, authid, charsmax(authid))
	if (keep_steamid(target, authid))
	{
		run("INSERT INTO cs_war3_ai_votekicks VALUES ('%s', 1, strftime('%%s', 'now')) ON CONFLICT (steamid) DO UPDATE \
			SET count = CASE WHEN last < strftime('%%s', 'now') - %d THEN 1 ELSE count + 1 END, last = excluded.last",
			g_steamid[target], KICKS_KEPT)
		new Handle:query = SQL_PrepareQuery(g_db, "SELECT count FROM cs_war3_ai_votekicks WHERE steamid = '%s'",
			g_steamid[target])
		if (SQL_Execute(query) && SQL_MoreResults(query))
			times = SQL_ReadResult(query, 0)
		SQL_FreeHandle(query)
	}
	if (times == 1)
		server_cmd("kick #%d ^"Kicked by vote^"", get_user_userid(target))
	else
	{
		new minutes = times == 2 ? 5 : 30, reason[48]
		formatex(reason, charsmax(reason), "Kicked by vote: banned %d minutes", minutes)
		kick_and_ban(target, minutes, reason)
	}
}
