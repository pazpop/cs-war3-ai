// "/help" in chat, or "help" in the console: opens the guide again (the same page as the MOTD on connect).
#include <amxmodx>

public plugin_init()
{
	register_plugin("Help", "1.0", "cs-war3-ai")
	register_clcmd("say /help", "cmd_help")
	register_clcmd("say help", "cmd_help")
	register_clcmd("say_team /help", "cmd_help")
	register_clcmd("help", "cmd_help")
}

// motd.txt holds the guide's address: the game opens it as a web page.
public cmd_help(id)
{
	show_motd(id, "motd.txt", "Help")
	return PLUGIN_HANDLED
}
