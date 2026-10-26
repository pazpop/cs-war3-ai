// Kicks a player whose ping stays too high: it makes them jump around and hard to hit, for everyone else.
// Checked every 10 seconds, from 30 seconds after arrival; kicked after 5 checks in a row over the limit.
// Admins (immunity) and bots are never checked.
#include <amxmodx>

#define MAX_PING 300    // in milliseconds: from North America, Europe and South America stay below
#define STRIKES 5       // checks in a row over the limit before the kick (50 seconds)
#define GRACE 30.0      // seconds after arrival: the ping is high while the map loads

new g_strikes[33]
new Float:g_arrival[33]

public plugin_init()
{
	register_plugin("High ping kicker", "1.0", "cs-war3-ai")
	set_task(10.0, "check_pings", .flags = "b")
}

public client_putinserver(id)
{
	g_strikes[id] = 0
	g_arrival[id] = get_gametime()
}

public check_pings()
{
	new players[32], count, ping, loss
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
	{
		new id = players[i]
		if ((get_user_flags(id) & ADMIN_IMMUNITY) || get_gametime() - g_arrival[id] < GRACE)
			continue

		get_user_ping(id, ping, loss)
		if (ping <= MAX_PING)
		{
			g_strikes[id] = 0
			continue
		}
		if (++g_strikes[id] < STRIKES)
		{
			client_print(id, print_chat, "[Ping] Your ping is %d (limit %d): you will be kicked if it stays this high.", ping, MAX_PING)
			continue
		}
		server_cmd("kick #%d ^"Ping too high (over %d ms)^"", get_user_userid(id), MAX_PING)
	}
}
