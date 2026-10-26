// "votekick" in chat: a menu of the other humans; a player is kicked for 10 minutes once 60 % of the other humans chose them.
// Counted against all the humans on the server, not only those who answer: one player alone never decides.
// Admins are not in the menu (immunity).
#include <amxmodx>
#include "common.inc"

#define SHARE 0.6           // share of the other humans needed
#define KICK_MIN_HUMANS 3   // with 2, one player could kick the other alone
#define BAN_MINUTES 10      // how long a player kicked by vote cannot come back

new g_wants_kick[33]        // the userid each player wants to kick (0: nobody)

public plugin_init()
{
	register_plugin("Votekick", "1.0", "cs-war3-ai")
	register_clcmd("say votekick", "cmd_votekick")
	register_clcmd("say /votekick", "cmd_votekick")
}

public client_disconnected(id)
{
	g_wants_kick[id] = 0
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
	client_print(0, print_chat, "[Votekick] %s wants to kick %s (%d/%d). Type votekick to agree.", name, target_name, votes, goal)
	if (votes >= goal)
	{
		// Kept out for a while, by SteamID: otherwise they could come back at once. Only a real SteamID: banning
		// STEAM_ID_PENDING would keep out everyone who has it. Not saved (no writeid): a restart lifts it.
		new authid[35]
		get_user_authid(target, authid, charsmax(authid))
		server_cmd("kick #%d ^"Kicked by vote for %d minutes^"", userid, BAN_MINUTES)
		if (is_real_steamid(authid))
			server_cmd("banid %d %s", BAN_MINUTES, authid)
		for (new i = 1; i <= MaxClients; i++)
			if (g_wants_kick[i] == userid)
				g_wants_kick[i] = 0
	}
	return PLUGIN_HANDLED
}
