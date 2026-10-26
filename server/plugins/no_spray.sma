// No sprays: the spray key (impulse 201, T by default) does nothing. sv_allowupload 0 (server.cfg) already keeps a
// player's own image off the others' screens; this stops the default ones too. The bots: yb_spraypaints 0 (Dockerfile).
#include <amxmodx>
#include <engine>  // register_impulse()

public plugin_init()
{
	register_plugin("No sprays", "1.0", "cs-war3-ai")
	register_impulse(201, "no_spray")
}

public no_spray(id)
{
	return PLUGIN_HANDLED
}
