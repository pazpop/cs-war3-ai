// Players away from their keyboard are free kills for everyone: after 60 seconds without a key or a mouse move,
// they are moved to spectator, and a bot takes their place.
// Keys and view, not position: in deathmatch, a player away keeps dying and respawning elsewhere.
// Admins (immunity) and bots are never moved.
#include <amxmodx>
#include <engine>  // get_user_button(), entity_get_vector()
#include <reapi>

#define AFK_TIME 60  // seconds without a key or a mouse move

new g_idle[33]
new Float:g_view[33][3]  // where the player looked at the last check
new g_buttons[33]        // the keys held at the last check
new bool:g_spawned[33]   // respawned since the last check

public plugin_init()
{
	register_plugin("AFK manager", "1.0", "cs-war3-ai")
	RegisterHookChain(RG_CBasePlayer_Spawn, "on_spawn", true)
	set_task(1.0, "check_players", .flags = "b")
}

public client_putinserver(id)
{
	g_idle[id] = 0
}

public on_spawn(id)
{
	g_spawned[id] = true
}

// The mouse moved since the last check. A respawn turns the view by itself: it does not count.
bool:mouse_moved(id)
{
	new Float:view[3]
	entity_get_vector(id, EV_VEC_v_angle, view)
	new bool:moved = !g_spawned[id] && (view[0] != g_view[id][0] || view[1] != g_view[id][1])
	g_view[id] = view
	g_spawned[id] = false
	return moved
}

public check_players()
{
	new players[32], count
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
	{
		new id = players[i]
		if (get_user_flags(id) & ADMIN_IMMUNITY)
			continue

		new TeamName:team = get_member(id, m_iTeam)
		new bool:moved = mouse_moved(id)
		// A key pressed or released since the last check: a key held down (crouching...) does not keep a player in.
		new buttons = get_user_button(id)
		new bool:pressed = buttons != g_buttons[id]
		g_buttons[id] = buttons
		// Already out of the game, a key pressed or released, or the mouse moved: nothing to do.
		if (team == TEAM_SPECTATOR || team == TEAM_UNASSIGNED || pressed || moved)
		{
			g_idle[id] = 0
			continue
		}
		if (++g_idle[id] >= AFK_TIME)
		{
			rg_join_team(id, TEAM_SPECTATOR)
			client_print(id, print_chat, "[AFK] Moved to spectator: away for %d seconds. Choose a team to play again.", AFK_TIME)
			g_idle[id] = 0
		}
	}
}
