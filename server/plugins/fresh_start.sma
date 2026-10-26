// A fresh start: when the first human joins a server of bots only, the game starts again, so every score (kills,
// deaths, money) is back to zero for everyone. War3FT's XP, the ranking of the month and the achievements are
// counted apart: they stay.
#include <amxmodx>

#define DELAY 5.0       // seconds after the human enters: they see it happen
#define MAP_START 30.0  // a map that just started has its scores at zero already

public plugin_init()
{
	register_plugin("Fresh start", "1.0", "cs-war3-ai")
}

public client_putinserver(id)
{
	if (is_user_bot(id) || is_user_hltv(id) || get_gametime() < MAP_START)
		return
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	// Only this one: everyone else is a bot.
	if (count == 1)
		set_task(DELAY, "restart")
}

public restart()
{
	client_print_color(0, print_team_default, "^4[Info]^1 A human joined: everyone starts again from zero. Good luck!")
	server_cmd("sv_restart 1")
}
