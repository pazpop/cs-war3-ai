// Our bots' identity, from server/bots.txt: each one plays its own War3FT race (War3FT still gives a bot a random race
// at one respawn in four; back to its own at the next), wears its own skin on each team, and gets a level of 1 to 5
// at each map, so that its XP never makes it stronger than the humans. And only the bots wear "[AI]".
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>

#define LEVEL_MIN 1
#define LEVEL_MAX 5      // under 6: no ultimate; a new human starts at 3 (wc3_start_level)
#define AFTER_WAR3FT 0.5 // seconds after a spawn: War3FT has given the bot its race and XP for this life
#define MAX_BOTS 32

// War3FT's races, in its order (race 1 to 8), as written in bots.txt.
new const RACES[][] = { "Undead Scourge", "Human Alliance", "Orcish Horde", "Night Elves", "Blood Mage",
	"Shadow Hunter", "Warden", "Crypt Lord" }
// Taken out of a human's name: the tags only the AI, the rankings and the server give ([AI] Zed, [AI Game Master],
// [AI Coach], [Champion], [#3], [INFO], [STATS], [HELP]; the relay's name check catches other look-alikes), and < and
// >, which War3FT's /playerskills page would read as HTML.
new const NAME_BANNED[][] = { "[AI]", "[AI ", "Game Master", "Coach]", "[Champion]", "[#", "[INFO]", "[STATS]",
	"[HELP]", "<", ">" }
new const T_SKINS[][] = { "terror", "leet", "arctic", "guerilla" }
new const CT_SKINS[][] = { "urban", "gsg9", "sas", "gign" }

new g_names[MAX_BOTS][32], g_races[MAX_BOTS], g_count
new g_bot[33] = { -1, ... }  // each player's line in bots.txt; -1: a human, or a bot not in the list
new g_level[33]

public plugin_init()
{
	register_plugin("Bots", "1.0", "cs-war3-ai")
	RegisterHam(Ham_Spawn, "player", "on_spawn", 1)
	load_bots()
}

// bots.txt: "name | race | character" per line, ";" starts a comment.
load_bots()
{
	new path[128], line[256], name[32], rest[224], race[32], ignored[192]
	get_configsdir(path, charsmax(path))
	add(path, charsmax(path), "/bots.txt")
	new file = fopen(path, "rt")
	if (!file)
	{
		log_amx("%s not found: the bots keep War3FT's random races", path)
		return
	}
	while (g_count < MAX_BOTS && fgets(file, line, charsmax(line)))
	{
		trim(line)
		if (!line[0] || line[0] == ';')
			continue
		strtok2(line, name, charsmax(name), rest, charsmax(rest), '|', TRIM_FULL)
		strtok2(rest, race, charsmax(race), ignored, charsmax(ignored), '|', TRIM_FULL)
		g_races[g_count] = 0
		for (new i = 0; i < sizeof RACES; i++)
			if (equal(race, RACES[i]))
				g_races[g_count] = i + 1
		if (!g_races[g_count])
			log_amx("bots.txt: unknown race ^"%s^" for %s", race, name)
		copy(g_names[g_count++], charsmax(g_names[]), name)
	}
	fclose(file)
}

public client_putinserver(id)
{
	g_bot[id] = -1
	if (!is_user_bot(id))
	{
		clean_name(id)
		return
	}
	new name[32]
	get_user_name(id, name, charsmax(name))
	// YaPB adds "[AI] " (yb_name_prefix).
	new start = equal(name, "[AI] ", 5) ? 5 : 0
	for (new i = 0; i < g_count; i++)
		if (equal(name[start], g_names[i]))
			g_bot[id] = i
	// A bot joins again at each map: a new level each time.
	g_level[id] = random_num(LEVEL_MIN, LEVEL_MAX)
}

public client_disconnected(id)
{
	remove_task(id)
	g_bot[id] = -1
}

// A human changes their name: the new one too.
public client_infochanged(id)
{
	if (is_user_connected(id) && !is_user_bot(id))
		clean_name(id)
}

// A human's name without NAME_BANNED: nobody passes for a bot or the Game Master in the chat (or the daily chat
// report), and no name becomes HTML.
clean_name(id)
{
	new name[32], bool:changed, bool:again = true
	get_user_info(id, "name", name, charsmax(name))
	// Again until nothing is left: taking a word out can make another one ([A[AI]I] gives [AI]).
	while (again)
	{
		again = false
		for (new i = 0; i < sizeof NAME_BANNED; i++)
			if (replace_string(name, charsmax(name), NAME_BANNED[i], "", false))
				changed = again = true
	}
	if (!changed)
		return
	trim(name)
	if (!name[0])
		copy(name, charsmax(name), "Player")
	set_user_info(id, "name", name)
}

public on_spawn(id)
{
	new bot = g_bot[id]
	if (bot < 0 || !is_user_alive(id))
		return
	// The same skin for a bot on each team: one of the 4, by its place in the list.
	switch (cs_get_user_team(id))
	{
		case CS_TEAM_T: cs_set_user_model(id, T_SKINS[bot % sizeof T_SKINS])
		case CS_TEAM_CT: cs_set_user_model(id, CT_SKINS[bot / sizeof T_SKINS % sizeof CT_SKINS])
	}
	set_task(AFTER_WAR3FT, "set_race_and_level", id)
}

public set_race_and_level(id)
{
	new bot = g_bot[id]
	if (bot < 0 || !is_user_alive(id))
		return
	// As if the bot chose its race in War3FT's menu (key = race - 1): the same race, nothing happens; another one,
	// it changes at its next spawn.
	if (g_races[bot] && callfunc_begin("_MENU_ChangeRace", "war3ft.amxx") == 1)
	{
		callfunc_push_int(id)
		callfunc_push_int(g_races[bot] - 1)
		callfunc_end()
	}
	// Back to its level of this map: the XP of its kills, of a new race or of an event does not add up.
	// wc3_setlevel finds a player by name: only if that name is this bot's (a human could copy it).
	new name[32]
	get_user_name(id, name, charsmax(name))
	if (find_player("a", name) == id)
		server_cmd("wc3_setlevel ^"%s^" %d", name, g_level[id])
}
