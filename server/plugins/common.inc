// Shared by our plugins: #include "common.inc".

// A real SteamID (STEAM_0:1:...): not STEAM_ID_PENDING or STEAM_ID_LAN, which many players share.
stock bool:is_real_steamid(const authid[])
{
	return equal(authid, "STEAM_", 6) && isdigit(authid[6]) && authid[7] == ':'
}
