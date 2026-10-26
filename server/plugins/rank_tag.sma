// The top 10 of the ranking (/rank) show their place in the chat: "[#3] name: message", and last month's top 3
// (monthly.sma) a "[Champion]" tag. A status everyone sees.
// Only the public chat, and not the commands (/help, !guns, votekick...): those go on to their plugins as usual.
#include <amxmodx>
#include <csstats>
#include <sqlx>
#include "common.inc"
#include "database.inc"

#define TAGGED 10  // the places that get a tag

new g_champions[3][35]  // last month's top 3, by SteamID

public plugin_init()
{
	register_plugin("Rank tag", "1.0", "cs-war3-ai")
	register_clcmd("say", "on_say")
	connect_db()
	load_champions()
}

// Read again at each map start: a new month changes them.
load_champions()
{
	// The same order as the web page's hall of fame.
	new Handle:query = SQL_PrepareQuery(g_db, "SELECT steamid FROM cs_war3_ai_monthly \
		WHERE month = strftime('%%Y-%%m', 'now', 'localtime', 'start of month', '-1 month') \
		ORDER BY kills - deaths DESC, kills DESC LIMIT 3")
	if (SQL_Execute(query))
	{
		for (new i = 0; i < sizeof g_champions && SQL_MoreResults(query); i++)
		{
			SQL_ReadResult(query, 0, g_champions[i], charsmax(g_champions[]))
			SQL_NextRow(query)
		}
	}
	SQL_FreeHandle(query)
}

bool:is_champion(id)
{
	new steamid[35]
	get_user_authid(id, steamid, charsmax(steamid))
	for (new i = 0; i < sizeof g_champions; i++)
		if (g_champions[i][0] && equal(steamid, g_champions[i]))
			return true
	return false
}

public on_say(id)
{
	new message[192]
	read_args(message, charsmax(message))
	remove_quotes(message)
	trim(message)
	// Dead players and spectators: the game's own chat, which only they see.
	if (!is_user_alive(id) || !message[0] || message[0] == '/' || message[0] == '!' || is_command(message))
		return PLUGIN_CONTINUE

	// The place in the ranking, updated by CSX at each respawn (0: not ranked yet).
	new stats[STATSX_MAX_STATS], bodyhits[MAX_BODYHITS]
	new place = get_user_stats(id, stats, bodyhits)
	// All the bots share one row of the ranking (SteamID "BOT"): above this player, it is not a place a human lost.
	new bots[32], bot_count
	get_players(bots, bot_count, "d")  // d: bots only
	if (place > 0 && bot_count)
	{
		new bot_place = get_user_stats(bots[0], stats, bodyhits)
		if (bot_place > 0 && bot_place < place)
			place--
	}
	new tag[16]
	if (is_champion(id))
		copy(tag, charsmax(tag), "[Champion]")
	else if (place >= 1 && place <= TAGGED)
		formatex(tag, charsmax(tag), "[#%d]", place)
	else
		return PLUGIN_CONTINUE

	// ^4: green, ^3: the player's team color, ^1: the normal chat color. "%s": the message is never read as a format.
	new name[32]
	get_user_name(id, name, charsmax(name))
	client_print_color(0, id, "^4%s ^3%s^1 :  %s", tag, name, message)
	// The game's own chat line is skipped, and with it its log line: written here, as the game does.
	new authid[35], team[16]
	get_user_authid(id, authid, charsmax(authid))
	get_user_team(id, team, charsmax(team))
	log_message("^"%s<%d><%s><%s>^" say ^"%s^"", name, get_user_userid(id), authid, team, message)
	// The plugins after this one still see the message; only the game's own copy is not shown.
	return PLUGIN_HANDLED_MAIN
}
