// Shared by our plugins: #include "common.inc".

// A real SteamID (STEAM_0:1:...): not STEAM_ID_PENDING or STEAM_ID_LAN, which many players share.
stock bool:is_real_steamid(const authid[])
{
	return equal(authid, "STEAM_", 6) && isdigit(authid[6]) && authid[7] == ':'
}

// A chat command typed without / or !: not a chat line.
stock const COMMANDS[][] = { "help", "votekick", "rtv", "nextmap", "currentmap", "timeleft", "thetime" }

stock bool:is_command(const message[])
{
	for (new i = 0; i < sizeof COMMANDS; i++)
		if (equali(message, COMMANDS[i]))
			return true
	return false
}
