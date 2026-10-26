// "rtv" in chat: once 60 % of all the humans on the server ask for it (not only those who answer), adminvote's map
// vote (amx_votemap) starts on 4 random maps. The end-of-map vote stays mapchooser's.
#include <amxmodx>
#include <amxmisc>

#define SHARE 0.6           // share of humans needed
#define MAX_MAPS 64

new bool:g_wants_rtv[33]
new bool:g_rtv_done
new g_maps[MAX_MAPS][32]
new g_map_count

public plugin_init()
{
	register_plugin("Rock the vote", "1.0", "cs-war3-ai")
	register_clcmd("say rtv", "cmd_rtv")
	register_clcmd("say /rtv", "cmd_rtv")
	load_maps()
}

// The maps from maps.ini (the same list as mapcycle.txt), without the current one.
load_maps()
{
	new path[96], line[64], map[32], current[32]
	get_configsdir(path, charsmax(path))
	add(path, charsmax(path), "/maps.ini")
	get_mapname(current, charsmax(current))

	new file = fopen(path, "rt")
	if (!file)
		return
	while (g_map_count < MAX_MAPS && fgets(file, line, charsmax(line)))
	{
		trim(line)
		if (!line[0] || line[0] == ';')
			continue
		parse(line, map, charsmax(map))
		if (!equali(map, current) && is_map_valid(map))
			copy(g_maps[g_map_count++], charsmax(g_maps[]), map)
	}
	fclose(file)
}

public client_disconnected(id)
{
	g_wants_rtv[id] = false
}

public cmd_rtv(id)
{
	if (g_rtv_done)
	{
		client_print(id, print_chat, "[RTV] A map vote already ran on this map.")
		return PLUGIN_HANDLED
	}
	// Typed again: counted again (players may have left), but told to everyone only the first time.
	new bool:already = g_wants_rtv[id]
	g_wants_rtv[id] = true

	new players[32], count, votes
	get_players(players, count, "ch")  // c: no bots; h: no HLTV
	for (new i = 0; i < count; i++)
		if (g_wants_rtv[players[i]])
			votes++

	// The share of humans, rounded up: with 5 humans and 60 %, 3.
	new needed = floatround(SHARE * float(count), floatround_ceil)
	if (!already)
	{
		new name[32]
		get_user_name(id, name, charsmax(name))
		client_print(0, print_chat, "[RTV] %s wants a new map (%d/%d). Type rtv in chat to agree.", name, votes, needed)
	}
	if (votes >= needed)
		start_map_vote(id)
	return PLUGIN_CONTINUE
}

// 4 random maps (Fisher-Yates shuffle), then adminvote's vote. id: the player whose rtv reached the share.
start_map_vote(id)
{
	if (g_map_count == 0)
		return
	// adminvote refuses a vote during another one, or too soon after it; mapchooser runs its own vote in the last
	// 2 minutes and some (129 s) of the map. In both cases rtv stays available.
	if (get_cvar_float("amx_last_voting") + get_cvar_float("amx_vote_delay") > get_gametime() || get_timeleft() < 130)
	{
		client_print(id, print_chat, "[RTV] Not now: a vote is running or just ran, or the map ends soon. Try again later.")
		return
	}
	g_rtv_done = true

	new swap[32]
	for (new i = g_map_count - 1; i > 0; i--)
	{
		new j = random_num(0, i)
		copy(swap, charsmax(swap), g_maps[i])
		copy(g_maps[i], charsmax(g_maps[]), g_maps[j])
		copy(g_maps[j], charsmax(g_maps[]), swap)
	}

	new command[160] = "amx_votemap"
	for (new i = 0; i < min(4, g_map_count); i++)
	{
		add(command, charsmax(command), " ")
		add(command, charsmax(command), g_maps[i])
	}
	server_cmd("%s", command)
}
