// Shared by our plugins: #include "common.inc".

// A real SteamID (STEAM_0:1:...): not STEAM_ID_PENDING or STEAM_ID_LAN, which many players share.
stock bool:is_real_steamid(const authid[])
{
	return equal(authid, "STEAM_", 6) && isdigit(authid[6]) && authid[7] == ':'
}

// In client_infochanged: true when the name the player is getting is not the one they have.
stock bool:name_changed(id)
{
	new old[32], name[32]
	get_user_name(id, old, charsmax(old))
	get_user_info(id, "name", name, charsmax(name))
	return !equal(old, name)
}

// Kicks a player and keeps them out for a while, by SteamID: otherwise they could come back at once. Only a real
// SteamID: banning STEAM_ID_PENDING would keep out everyone who has it. Not saved (no writeid): a restart lifts it.
stock kick_and_ban(id, minutes, const reason[])
{
	new authid[35]
	get_user_authid(id, authid, charsmax(authid))
	server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason)
	if (is_real_steamid(authid))
		server_cmd("banid %d %s", minutes, authid)
}

// A chat line in the game's log, as the game writes them (the daily chat report reads them). Quotes become ': a name
// or a message cannot end the line early and fake another one.
stock log_say(const who[], const text[])
{
	new who_clean[96], text_clean[192]
	copy(who_clean, charsmax(who_clean), who)
	copy(text_clean, charsmax(text_clean), text)
	replace_string(who_clean, charsmax(who_clean), "^"", "'")
	replace_string(text_clean, charsmax(text_clean), "^"", "'")
	log_message("^"%s^" say ^"%s^"", who_clean, text_clean)
}

// A chat command typed without / or !: not a chat line. Ours, then War3FT's (it reads them with or without /, and
// its item names buy the item).
stock const COMMANDS[][] = { "help", "votekick", "rtv", "nextmap", "currentmap", "timeleft", "thetime",
	"changerace", "selectskill", "selectskills", "skillsinfo", "resetskills", "resetxp", "playerskills", "level",
	"shopmenu", "shopmenu2", "itemsinfo", "itemsinfo2", "war3menu", "war3help", "war3_version", "savexp", "icons",
	"ms", "movespeed", "levitation", "debug", "devs", "developers", "ability", "ankh", "amulet", "boots", "claws",
	"cloak", "chameleon", "frost", "gloves", "health", "helm", "mask", "mole", "necklace", "rings", "socks", "scroll",
	"tome" }

stock bool:is_command(const message[])
{
	for (new i = 0; i < sizeof COMMANDS; i++)
		if (equali(message, COMMANDS[i]))
			return true
	return false
}

// The map's MVP (ai.sma names it at the map's end, monthly.sma counts it): the top of the scoreboard, kills then fewer
// deaths, among the players in a team who scored, bots included; with humans_only, the best human. 0: nobody.
stock map_mvp(bool:humans_only = false)
{
	new players[32], count, best
	get_players(players, count, "h")  // h: no HLTV
	for (new i = 0; i < count; i++)
	{
		new id = players[i], team = get_user_team(id)  // 1: T, 2: CT
		if (team != 1 && team != 2 || get_user_frags(id) <= 0 || humans_only && is_user_bot(id))
			continue
		new kills = get_user_frags(id), best_kills = best ? get_user_frags(best) : 0
		if (!best || kills > best_kills || kills == best_kills && get_user_deaths(id) < get_user_deaths(best))
			best = id
	}
	return best
}
