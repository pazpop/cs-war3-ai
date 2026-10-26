// Shared by our plugins: #include "common.inc".

// A real SteamID (STEAM_0:1:...): not STEAM_ID_PENDING or STEAM_ID_LAN, which many players share.
stock bool:is_real_steamid(const authid[])
{
	return equal(authid, "STEAM_", 6) && isdigit(authid[6]) && authid[7] == ':'
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
