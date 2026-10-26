// "/nextmap", "/timeleft"...: AMX Mod X only knows these commands without the slash.
// War3FT, the stats (/rank, /top15) and our votes already accept it: with this plugin, these four do too.
#include <amxmodx>

public plugin_init()
{
	register_plugin("Slash commands", "1.0", "cs-war3-ai")
	register_clcmd("say /nextmap", "cmd_without_slash")
	register_clcmd("say /currentmap", "cmd_without_slash")
	register_clcmd("say /timeleft", "cmd_without_slash")
	register_clcmd("say /thetime", "cmd_without_slash")
}

// Runs the command without the slash, as if the player had typed it.
public cmd_without_slash(id)
{
	new said[32]
	read_argv(1, said, charsmax(said))
	amxclient_cmd(id, "say", said[1])
	return PLUGIN_HANDLED
}
