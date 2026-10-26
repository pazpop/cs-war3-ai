// The damage you deal, under the crosshair, at each hit: you see at once that your shots land.
#include <amxmodx>
#include <csx>

new g_hud

public plugin_init()
{
	register_plugin("Damage dealt", "1.0", "cs-war3-ai")
	// A HUD channel picked by AMX Mod X: it does not cover the other plugins' messages.
	g_hud = CreateHudSyncObj()
}

// From CSX, for each hit between players.
public client_damage(attacker, victim, damage)
{
	if (!attacker || attacker == victim || is_user_bot(attacker))
		return
	set_hudmessage(0, 180, 255, -1.0, 0.55, 0, 0.0, 1.0, 0.0, 0.2)
	ShowSyncHudMsg(attacker, g_hud, "%d", damage)
}
