// A fresh start: when the first human joins a server of bots only, the game starts again, so every score (kills,
// deaths) is back to zero for everyone, and the money back to the start's. War3FT's XP, the ranking of the month and
// the achievements are counted apart: they stay.
#include <amxmodx>

#define DELAY 5.0       // seconds after the human enters: they see it happen
#define MAP_START 30.0  // a map that just started has its scores at zero already

new bool:g_done  // once a map at most: a human who reconnects again and again does not restart it each time

public plugin_init()
{
	register_plugin("Fresh start", "1.0", "cs-war3-ai")
}

public client_putinserver(id)
{
	// Not in a map's last 10 minutes either: it ends soon, and a restart could start its clock again.
	if (is_user_bot(id) || is_user_hltv(id) || get_gametime() < MAP_START || get_timeleft() < 600)
		return
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	// Only this one: everyone else is a bot.
	if (count == 1 && !g_done)
	{
		g_done = true
		set_task(DELAY, "restart")
	}
}

public restart()
{
	client_print_color(0, print_team_default, "^4[INFO]^1 A human joined: everyone starts again from zero. Good luck!")
	server_cmd("sv_restart 1")
}
