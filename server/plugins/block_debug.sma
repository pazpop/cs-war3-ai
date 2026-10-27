// War3FT's debug commands "test" and "test2" are open to every player: "test" writes several lines per player
// into two log files, so a player repeating it could fill the disk. Blocked here, before any plugin's command.
#include <amxmodx>

public plugin_init()
{
	register_plugin("Block War3FT debug", "1.0", "cs-war3-ai")
}

public client_command(id)
{
	new command[8]
	read_argv(0, command, charsmax(command))
	if (equali(command, "test") || equali(command, "test2"))
		return PLUGIN_HANDLED
	return PLUGIN_CONTINUE
}
