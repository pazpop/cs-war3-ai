// War3FT's deathmatch mode: with the cvar csdm_active at 1, it starts a new session at every respawn (ultimate
// cooldown, skills), since rounds never end. The respawns come from ReDeathmatch, which does not create that cvar
// (it comes from the old CSDM plugin): we do. War3FT reads it 1.5 s after loading, so the plugins' order does not
// matter.
#include <amxmodx>

public plugin_init()
{
	register_plugin("CSDM active for War3FT", "1.0", "cs-war3-ai")
	register_cvar("csdm_active", "1")
}
