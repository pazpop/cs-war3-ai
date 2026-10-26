// War3FT in Respawn mode.
// With the cvar csdm_active at 1, War3FT starts a new session at every respawn (ultimate cooldown, skills), since
// rounds never end. The respawns come from ReDeathmatch, which does not create that cvar (it comes from the old CSDM
// plugin): we do. War3FT reads it 1.5 s after loading, so the plugins' order does not matter.
// War3FT saves the XP when a player leaves, at a map's end, and at a round's end, which never comes here: it also
// saves everyone's every 5 minutes, so a crash loses 5 minutes of XP at most, not a whole map.
#include <amxmodx>

#define SAVE_EVERY 300.0  // seconds

public plugin_init()
{
	register_plugin("CSDM active for War3FT", "1.0", "cs-war3-ai")
	register_cvar("csdm_active", "1")
	set_task(SAVE_EVERY, "save_xp", _, _, _, "b")
}

// War3FT's own function (public): every player's XP, in a background query (threaded: the game does not wait).
public save_xp()
{
	if (callfunc_begin("DB_SaveAll", "war3ft.amxx") == 1)
	{
		callfunc_push_int(true)
		callfunc_end()
	}
}
