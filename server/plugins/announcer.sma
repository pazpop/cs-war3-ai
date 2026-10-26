// The announcer: a voice and a message for everyone at first blood, multi-kills and kill streaks.
// The voices are in sound/announcer/ (CC-BY 3.0, see CREDITS.txt there); players download them over HTTP (FastDL).
#include <amxmodx>

#define MULTI_KILL_TIME 3.0   // seconds between two kills of the same multi-kill

// Kills in a few seconds: 2, 3, 4, then 5 and more.
new const MULTI_SOUNDS[][] = { "doublekill", "triplekill", "megakill", "ownage" }
new const MULTI_NAMES[][] = { "DOUBLE KILL", "TRIPLE KILL", "MEGA KILL", "OWNAGE" }

// Kills without dying: one voice at each of these counts.
new const STREAK_KILLS[] = { 3, 5, 7, 10, 13, 16, 20 }
new const STREAK_SOUNDS[][] = { "killingspree", "rampage", "dominating", "massacre", "mayhem", "carnage", "godlike" }
new const STREAK_NAMES[][] = { "KILLING SPREE", "RAMPAGE", "DOMINATING", "MASSACRE", "MAYHEM", "CARNAGE", "GODLIKE" }

new g_streak[33]
new g_multi[33]
new Float:g_last_kill[33]
new bool:g_first_blood_done

public plugin_precache()
{
	precache_sound("announcer/firstblood.wav")
	for (new i = 0; i < sizeof MULTI_SOUNDS; i++)
		precache_announcer(MULTI_SOUNDS[i])
	for (new i = 0; i < sizeof STREAK_SOUNDS; i++)
		precache_announcer(STREAK_SOUNDS[i])
}

precache_announcer(const sound[])
{
	new path[64]
	formatex(path, charsmax(path), "announcer/%s.wav", sound)
	precache_sound(path)
}

public plugin_init()
{
	register_plugin("Announcer", "1.0", "cs-war3-ai")
	register_event("DeathMsg", "on_death", "a")
}

public client_putinserver(id)
{
	g_streak[id] = 0
	g_multi[id] = 0
	g_last_kill[id] = 0.0
}

public on_death()
{
	new killer = read_data(1)
	new victim = read_data(2)
	g_streak[victim] = 0
	g_multi[victim] = 0
	if (!killer || killer == victim)
		return

	g_streak[killer]++
	new Float:now = get_gametime()
	g_multi[killer] = (now - g_last_kill[killer] <= MULTI_KILL_TIME) ? g_multi[killer] + 1 : 1
	g_last_kill[killer] = now

	if (!g_first_blood_done)
	{
		g_first_blood_done = true
		announce(killer, "firstblood", "FIRST BLOOD")
		return
	}
	// A multi-kill is the most exciting news: it wins over the streak of the same kill.
	if (g_multi[killer] >= 2)
	{
		new level = min(g_multi[killer] - 2, sizeof MULTI_SOUNDS - 1)
		announce(killer, MULTI_SOUNDS[level], MULTI_NAMES[level])
		return
	}
	for (new i = 0; i < sizeof STREAK_KILLS; i++)
	{
		if (g_streak[killer] == STREAK_KILLS[i])
			announce(killer, STREAK_SOUNDS[i], STREAK_NAMES[i])
	}
}

announce(killer, const sound[], const title[])
{
	new name[32]
	get_user_name(killer, name, charsmax(name))
	client_cmd(0, "spk announcer/%s", sound)
	set_hudmessage(255, 176, 0, -1.0, 0.25, 0, 0.0, 2.5, 0.1, 0.3, -1)
	show_hudmessage(0, "%s: %s", name, title)
}
