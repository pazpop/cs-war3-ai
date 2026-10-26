// The AI: bots that talk back, a Game Master, and a coach. This plugin sends the chat, the kills between bots and
// humans, every few minutes the state of the game, a player's numbers for the coach, and the Game Master's
// announcements (for the nightly journal) to the AI relay (ai/relay.py), which asks Claude. The relay answers with
// actions; this plugin checks each one (the players must still be here) and does only what it knows. Relay down, or no
// API key: no answer, and the game is unchanged. At each map's end, the Game Master names the map's MVP.
#include <amxmodx>
#include <cstrike>
#include <csx>  // get_user_wstats(): each player's numbers on this map, for the coach
#include <fun>  // set_user_health(), set_user_rendering()
#include <json>
#include <sockets>
#include "common.inc"
#include "kills.inc"

// The relay's fixed address on the "ai" network (compose.yml): a name would be looked up at each request, and a
// lookup can block the server.
#define RELAY_IP "10.27.15.10"
#define RELAY_PORT 27100
#define TIMEOUT 20.0          // seconds to wait for an answer: two requests to Claude (the line, then its check)
#define MAX_PENDING 16        // requests waiting at once: the map's summary goes to every human together
#define STATE_EVERY 600.0     // seconds between two looks of the Game Master
#define EVENT_TIME 180.0      // seconds a bounty, a duel or a boss lasts
#define CHALLENGE_TIME 120.0  // seconds to meet a challenge
#define REWARD 3000           // the prize of a bounty, a duel, a challenge or a boss, in dollars
#define XP_REWARD 200         // and the same prize in War3FT XP (saved, unlike money): about 13 kills
#define XP_RAIN 100           // xp_rain: War3FT XP for every human
#define BOSS_HEALTH 500
#define GOLD 1500             // gold_rain: for everyone
#define LOW_GRAVITY 300       // sv_gravity during low_gravity (the game's own is 800)
#define GREET_AFTER 10.0      // seconds after a human enters, before a bot says hello
#define COACH_AFTER 5         // deaths in a row before the coach gives a tip on its own, once per map
#define SUMMARY_AT 60         // seconds left in the map when the coach sends each human their summary
#define TASK_GRAVITY 1        // the task that ends low_gravity
#define TASK_EVENT 2          // the task that ends a bounty, a duel, a challenge or a boss
#define TASK_RED 3            // the task that keeps the boss red
#define TASK_JOIN 100         // + the player's slot: the task that greets them

// item_gift: War3FT's shop items that help at once (its numbers, items.h): boots, claws, cloak, mask, frost, periapt,
// amulet, sock, gloves, ring. Not the ankh, tome, scroll, mole and protectant, chameleon; not the necklace (no
// ultimate would work on anyone) nor the helm (no more headshots for anyone).
new const GIFTS[] = { 1, 2, 3, 4, 6, 7, 12, 13, 14, 15 }

new g_socket[MAX_PENDING]
new bool:g_sent[MAX_PENDING]
new Float:g_deadline[MAX_PENDING]
new g_out[MAX_PENDING][4096]  // a full server's state (16 players) is about 2 KB

// The event running, one at a time: the bounty, the two duelists, the boss (their userids: a userid, unlike a slot, is
// never given to the next player), or the challenge (its kind, how many, each player's count).
new g_bounty, g_duel[2], g_boss
new g_challenge[16], g_goal, g_progress[33]
new g_gravity

// For the coach: deaths in a row, whether the tip after them was given on this map, and how often each weapon killed
// the player; whether the map's summary was sent.
new g_streak[33], bool:g_coached[33], g_killed_by[33][CSW_P90 + 1]
new bool:g_summary_sent

public plugin_init()
{
	register_plugin("AI", "1.0", "cs-war3-ai")
	register_clcmd("say", "on_say")
	// Not say_team: a bot's answer shows to everyone, and a team's chat must stay within the team.
	register_kills()
	// A new round: in Respawn mode, only a restart (fresh_start.sma, sv_restart) or a new map.
	register_event("HLTV", "on_new_round", "a", "1=0", "2=0")
	// The map's end (the intermission: the scores show for a few seconds).
	register_event("30", "announce_mvp", "a")
	register_clcmd("say /coach", "cmd_coach")
	register_clcmd("say_team /coach", "cmd_coach")
	set_task(0.1, "poll", _, _, _, "b")
	set_task(STATE_EVERY, "send_state", _, _, _, "b")
	set_task(10.0, "check_summary", _, _, _, "b")
}

// A human arrives (or comes back with the next map: the relay greets only real arrivals). A few seconds later, when
// they see the game.
public client_putinserver(id)
{
	g_progress[id] = 0
	g_streak[id] = 0
	g_coached[id] = false
	arrayset(g_killed_by[id], 0, sizeof g_killed_by[])
	if (!is_user_bot(id) && !is_user_hltv(id))
		set_task(GREET_AFTER, "send_join", TASK_JOIN + id)
}

// drop: the player left or was kicked (YaPB kicks a bot to make room for a human); not a map's end.
public client_disconnected(id, bool:drop)
{
	remove_task(TASK_JOIN + id)
	// A player in the event running leaves: it ends with them (and the boss's glow must not stay on its slot).
	new userid = get_user_userid(id)
	if (userid && (userid == g_boss || userid == g_bounty || userid == g_duel[0] || userid == g_duel[1]))
	{
		if (drop)
			announce("The event is over: a player in it left.")
		end_event()
	}
}

// Everyone starts again: the event running ends too (a boss would be back at 100 health, still red).
public on_new_round()
{
	end_event()
}

public send_join(task)
{
	new id = task - TASK_JOIN
	if (!is_user_connected(id))
		return
	new JSON:event = player(id)
	json_object_set_string(event, "type", "join")
	// The bots remember the last map they played with each human.
	new map[32]
	get_mapname(map, charsmax(map))
	json_object_set_string(event, "map", map)
	add_bots(event)
	send(event)
}

public plugin_end()
{
	for (new i = 0; i < MAX_PENDING; i++)
		if (g_socket[i] > 0)
			socket_close(g_socket[i])
	// The gravity stays from one map to the next: never leave it low. (The event ended when its players left.)
	if (g_gravity)
		set_cvar_num("sv_gravity", g_gravity)
}

// ---- To the relay ----

send(JSON:event)
{
	for (new i = 0; i < MAX_PENDING; i++)
	{
		if (g_socket[i] > 0)
			continue
		json_serial_to_string(event, g_out[i], charsmax(g_out[]) - 1)
		add(g_out[i], charsmax(g_out[]), "^n")
		// Non-blocking: if the relay is down, the connection fails later in poll(), and the server never waits.
		new error
		g_socket[i] = socket_open(RELAY_IP, RELAY_PORT, SOCKET_TCP, error, SOCK_NON_BLOCKING)
		g_sent[i] = false
		g_deadline[i] = get_gametime() + TIMEOUT
		break
	}
	// All slots busy: the relay is slow, this event is dropped.
	json_free(event)
}

public poll()
{
	static answer[2048]
	for (new i = 0; i < MAX_PENDING; i++)
	{
		new sock = g_socket[i]
		if (sock <= 0)
			continue
		if (get_gametime() > g_deadline[i])
		{
			close_slot(i)
			continue
		}
		if (!g_sent[i])
		{
			// One send is enough: an event is a few KB at most, on the local network.
			if (socket_is_writable(sock, 0))
			{
				if (socket_send(sock, g_out[i], strlen(g_out[i])) <= 0)
					close_slot(i)
				else
					g_sent[i] = true
			}
			continue
		}
		if (socket_is_readable(sock, 0))
		{
			// One read is enough: the relay writes its whole answer (under 2 KB) at once.
			new length = socket_recv(sock, answer, charsmax(answer))
			close_slot(i)
			if (length > 0)
				do_actions(answer)
		}
	}
}

close_slot(i)
{
	socket_close(g_socket[i])
	g_socket[i] = 0
}

add_steamid(JSON:object, id)
{
	new authid[35]
	get_user_authid(id, authid, charsmax(authid))
	if (is_real_steamid(authid))
		json_object_set_string(object, "steamid", authid)
}

JSON:player(id)
{
	new JSON:object = json_init_object()
	new name[32]
	get_user_name(id, name, charsmax(name))
	json_object_set_number(object, "id", get_user_userid(id))
	json_object_set_string(object, "name", name)
	json_object_set_bool(object, "bot", bool:is_user_bot(id))
	if (!is_user_bot(id))
		add_steamid(object, id)
	return object
}

public on_say(id)
{
	if (is_user_bot(id))
		return PLUGIN_CONTINUE
	new message[192]
	read_args(message, charsmax(message))
	remove_quotes(message)
	trim(message)
	// "/coach <question>": the coach answers it in private, from the player's numbers; not shown in the chat.
	if (equali(message, "/coach ", 7))
	{
		ask_coach(id, message[7])
		return PLUGIN_HANDLED
	}
	if (!message[0] || message[0] == '/' || message[0] == '!' || is_command(message))
		return PLUGIN_CONTINUE

	new JSON:event = player(id)
	json_object_set_string(event, "type", "chat")
	json_object_set_string(event, "text", message)
	add_bots(event)
	send(event)
	return PLUGIN_CONTINUE
}

// The bots in the game: the ones who can answer.
add_bots(JSON:event)
{
	new JSON:bots = json_init_array()
	new players[32], count
	get_players(players, count, "d")
	for (new i = 0; i < count; i++)
	{
		new JSON:bot = player(players[i])
		json_array_append_value(bots, bot)
		json_free(bot)
	}
	json_object_set_value(event, "bots", bots)
	json_free(bots)
}

// Every kill, War3FT's spells included (kills.inc).
public on_kill(killer, victim, bool:headshot, const weapon[])
{
	check_events(killer, victim, headshot, weapon)
	count_for_coach(killer, victim, weapon)
	// Only a bot against a human: the bots talk to the humans.
	if (!killer || killer == victim || !is_user_connected(killer) || is_user_bot(killer) == is_user_bot(victim))
		return

	new JSON:event = json_init_object()
	new JSON:who = player(killer)
	json_object_set_string(event, "type", "kill")
	json_object_set_value(event, "killer", who)
	json_free(who)
	who = player(victim)
	json_object_set_value(event, "victim", who)
	json_free(who)
	json_object_set_string(event, "weapon", weapon)
	json_object_set_bool(event, "headshot", headshot)
	send(event)
}

public send_state()
{
	new players[32], count
	get_players(players, count, "ch")
	if (!count)
		return
	get_players(players, count, "h")
	new JSON:list = json_init_array()
	for (new i = 0; i < count; i++)
	{
		new id = players[i]
		new team[16]
		get_user_team(id, team, charsmax(team))
		if (team[0] != 'C' && team[0] != 'T')
			continue
		new JSON:object = player(id)
		json_object_set_string(object, "team", team)
		json_object_set_number(object, "kills", get_user_frags(id))
		json_object_set_number(object, "deaths", get_user_deaths(id))
		json_array_append_value(list, object)
		json_free(object)
	}
	new JSON:event = json_init_object()
	json_object_set_string(event, "type", "state")
	json_object_set_value(event, "players", list)
	json_free(list)
	send(event)
}

// ---- From the relay ----

do_actions(const answer[])
{
	new JSON:root = json_parse(answer)
	if (!json_is_object(root))
	{
		free(root)
		return
	}
	new JSON:lines = json_object_get_value(root, "say")
	if (json_is_array(lines))
	{
		for (new i = 0; i < json_array_get_count(lines); i++)
		{
			new JSON:line = json_array_get_value(lines, i)
			new text[160]  // the relay sends at most 150 bytes (an answer to a question)
			if (json_object_has_value(line, "text", JSONString))
			{
				json_object_get_string(line, "text", text, charsmax(text))
				bot_say(json_object_get_number(line, "id"), text)
			}
			free(line)
		}
	}
	free(lines)
	new JSON:gm = json_object_get_value(root, "gm")
	if (json_is_object(gm) && json_object_has_value(gm, "event", JSONString) && json_object_has_value(gm, "text", JSONString))
		game_master(gm)
	free(gm)
	new JSON:coach = json_object_get_value(root, "coach")
	if (json_is_object(coach) && json_object_has_value(coach, "text", JSONString))
	{
		new text[160]
		json_object_get_string(coach, "text", text, charsmax(text))
		new id = find_player("k", json_object_get_number(coach, "id"))
		// In private: only the player sees it (and the game's log, for the daily chat report).
		if (id && text[0])
		{
			client_print_color(id, print_team_default, "^4[AI Coach]^1 %s", text)
			new name[32]
			get_user_name(id, name, charsmax(name))
			log_message("^"Coach to %s^" say ^"%s^"", name, text)
		}
	}
	free(coach)
	// Humans whose name the AI found offensive: they play as "Player".
	new JSON:renames = json_object_get_value(root, "rename")
	if (json_is_array(renames))
		for (new i = 0; i < json_array_get_count(renames); i++)
			rename_player(json_array_get_number(renames, i))
	free(renames)
	free(root)
}

// The new name goes everywhere the old one would: the chat, the Game Master's announcements, the stats site.
rename_player(userid)
{
	new id = find_player("k", userid)
	if (!id || is_user_bot(id))
		return
	set_user_info(id, "name", "Player")
	client_print_color(id, print_team_default, "^4[AI Game Master]^1 Your name is not allowed here: you play as Player.")
}

// json_free refuses a value that does not exist (a missing key, a line that is not JSON).
free(&JSON:value)
{
	if (value != Invalid_JSON)
		json_free(value)
}

// A chat line from a bot, shown as the game shows a player's (rank_tag.sma does the same).
bot_say(userid, const text[])
{
	new bot = find_player("k", userid)
	if (!bot || !is_user_bot(bot) || !text[0])
		return
	new name[32]
	get_user_name(bot, name, charsmax(name))
	// "%s": the text is never read as a format; the relay has removed the color bytes from it.
	client_print_color(0, bot, "^3%s^1 :  %s", name, text)
	// In the game's log too, as a player's chat line: the daily chat report reads it (ansible/files/chat_report.py).
	new team[16]
	get_user_team(bot, team, charsmax(team))
	log_message("^"%s<%d><BOT><%s>^" say ^"%s^"", name, userid, team, text)
}

game_master(JSON:gm)
{
	new event[16], text[128]
	json_object_get_string(gm, "event", event, charsmax(event))
	json_object_get_string(gm, "text", text, charsmax(text))
	new target = find_player("k", json_object_get_number(gm, "target"))
	new target2 = find_player("k", json_object_get_number(gm, "target2"))

	if (equal(event, "bounty") || equal(event, "duel") || equal(event, "challenge") || equal(event, "boss"))
	{
		if (!start_event(gm, event, target, target2))
			return
	}
	else if (equal(event, "low_gravity"))
	{
		if (!g_gravity)
			g_gravity = get_cvar_num("sv_gravity")
		set_cvar_num("sv_gravity", LOW_GRAVITY)
		remove_task(TASK_GRAVITY)
		set_task(30.0, "end_low_gravity", TASK_GRAVITY)
	}
	else if (equal(event, "gold_rain"))
	{
		// Everyone, the dead too: a player respawning at that moment gets it as well.
		new players[32], count
		get_players(players, count, "h")
		for (new i = 0; i < count; i++)
			give_money(players[i], GOLD)
	}
	else if (equal(event, "xp_rain"))
	{
		new players[32], count
		get_players(players, count, "ch")
		for (new i = 0; i < count; i++)
			if (in_team(players[i]))
				give_xp(players[i], XP_RAIN)
	}
	else if (equal(event, "item_gift"))
		server_cmd("wc3_giveitem @ALL %d", GIFTS[random(sizeof GIFTS)])
	else if (!equal(event, "none"))
		return
	if (text[0])
		announce(text)
}

public end_low_gravity()
{
	set_cvar_num("sv_gravity", g_gravity)
	g_gravity = 0
	announce("Gravity is back.")
}

// A bounty, a duel, a challenge or a boss: one at a time, so it ends the one running. False when it cannot start.
bool:start_event(JSON:gm, const event[], target, target2)
{
	new challenge[16]
	json_object_get_string(gm, "challenge", challenge, charsmax(challenge))
	if (equal(event, "bounty") && !target
		|| equal(event, "duel") && (!target || !target2 || target == target2)
		|| equal(event, "boss") && (!target || !is_user_bot(target) || !is_user_alive(target))
		|| equal(event, "challenge") && !equal(challenge, "kills") && !equal(challenge, "headshots")
			&& !equal(challenge, "knife"))
		return false
	end_event()

	if (equal(event, "bounty"))
		g_bounty = get_user_userid(target)
	else if (equal(event, "duel"))
	{
		g_duel[0] = get_user_userid(target)
		g_duel[1] = get_user_userid(target2)
	}
	else if (equal(event, "boss"))
	{
		g_boss = get_user_userid(target)
		set_user_health(target, BOSS_HEALTH)
		keep_boss_red()
		set_task(1.0, "keep_boss_red", TASK_RED, _, _, "b")
	}
	else
	{
		copy(g_challenge, charsmax(g_challenge), challenge)
		g_goal = clamp(json_object_get_number(gm, "count"), 1, 6)
		arrayset(g_progress, 0, sizeof g_progress)
	}
	set_task(equal(event, "challenge") ? CHALLENGE_TIME : EVENT_TIME, "time_up", TASK_EVENT)
	return true
}

// The red glow, again every second: a War3FT skill (invisibility...) may change how the boss looks.
public keep_boss_red()
{
	new boss = find_player("k", g_boss)
	if (boss && is_user_alive(boss))
		set_user_rendering(boss, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
}

public time_up()
{
	if (g_boss)
		announce("The boss survived. Too strong for you all!")
	else if (g_goal)
		announce("Time is up: nobody met the challenge.")
	else if (g_bounty)
		announce("Time is up: nobody claimed the bounty.")
	else if (g_duel[0])
		announce("Time is up: the duel ends with no winner.")
	end_event()
}

end_event()
{
	remove_task(TASK_EVENT)
	remove_task(TASK_RED)
	new boss = find_player("k", g_boss)
	if (g_boss && boss)
	{
		set_user_rendering(boss)
		// Back to a normal bot: no more than 100 HP.
		if (is_user_alive(boss) && get_user_health(boss) > 100)
			set_user_health(boss, 100)
	}
	g_bounty = g_duel[0] = g_duel[1] = g_boss = g_goal = 0
	g_challenge[0] = 0
}

// A kill that wins the event running.
check_events(killer, victim, bool:headshot, const weapon[])
{
	new victim_id = get_user_userid(victim)
	if (!killer || killer == victim || !is_user_connected(killer))
	{
		// A boss that dies on its own (a fall...): nobody wins.
		if (g_boss && victim_id == g_boss)
			end_event()
		return
	}
	new killer_id = get_user_userid(killer)
	if (g_bounty && victim_id == g_bounty)
		win(killer, victim, "claims the bounty on")
	else if (g_duel[0] && (killer_id == g_duel[0] && victim_id == g_duel[1] || killer_id == g_duel[1] && victim_id == g_duel[0]))
		win(killer, victim, "wins the duel against")
	else if (g_boss && victim_id == g_boss)
		win(killer, victim, "takes down the boss")
	// A challenge: humans only, and only the kills it asks for.
	else if (g_goal && !is_user_bot(killer) && (equal(g_challenge, "kills") || equal(g_challenge, "headshots") && headshot
		|| equal(g_challenge, weapon)))
	{
		if (++g_progress[killer] >= g_goal)
			win(killer, 0, "meets the challenge")
		else
			client_print(killer, print_chat, "[Challenge] %d / %d", g_progress[killer], g_goal)
	}
}

// victim 0: a challenge, nobody to name.
win(winner, victim, const what[])
{
	new name[32], prey[32], prize[32], text[128]
	get_user_name(winner, name, charsmax(name))
	// A bot gets the money, not the XP (see give_xp).
	if (is_user_bot(winner))
		formatex(prize, charsmax(prize), "$%d", REWARD)
	else
		formatex(prize, charsmax(prize), "$%d and %d XP", REWARD, XP_REWARD)
	if (victim)
	{
		get_user_name(victim, prey, charsmax(prey))
		formatex(text, charsmax(text), "%s %s %s: %s!", name, what, prey, prize)
	}
	else
		formatex(text, charsmax(text), "%s %s: %s!", name, what, prize)
	give_money(winner, REWARD)
	give_xp(winner, XP_REWARD)
	end_event()
	announce(text)
}

// ---- The coach ----

// /coach: a tip in private, from the player's numbers on this map. The relay allows one a minute.
public cmd_coach(id)
{
	ask_coach(id, "")
	return PLUGIN_HANDLED
}

// /coach, with or without a question: a word at once (the answer takes a few seconds), then the relay's answer.
ask_coach(id, const question[])
{
	client_print_color(id, print_team_default, "^4[AI Coach]^1 Looking at your game...")
	send_coach(id, "", question)
}

// Deaths in a row, and what killed the player; after COACH_AFTER deaths in a row, a tip on its own, once per map.
count_for_coach(killer, victim, const weapon[])
{
	if (killer && killer != victim && !is_user_bot(killer))
		g_streak[killer] = 0
	if (is_user_bot(victim))
		return
	g_streak[victim]++
	// The death notice says "grenade"; the weapon is called "hegrenade".
	new full[32]
	formatex(full, charsmax(full), "weapon_%s", equal(weapon, "grenade") ? "hegrenade" : weapon)
	new weapon_id = get_weaponid(full)
	if (weapon_id > 0 && weapon_id <= CSW_P90)
		g_killed_by[victim][weapon_id]++
	if (g_streak[victim] >= COACH_AFTER && !g_coached[victim])
	{
		g_coached[victim] = true
		send_coach(victim, "auto")
	}
}

// Near the map's end, each human who played gets their summary: one strength, one thing to work on.
public check_summary()
{
	new left = get_timeleft()
	if (g_summary_sent || left <= 0 || left > SUMMARY_AT)
		return
	g_summary_sent = true
	new players[32], count, stats[STATSX_MAX_STATS], body[MAX_BODYHITS]
	get_players(players, count, "ch")
	for (new i = 0; i < count; i++)
		if (get_user_wstats(players[i], 0, stats, body) && stats[0] + stats[1] > 0)
			send_coach(players[i], "summary")
}

// The player's numbers on this map: kills, deaths, headshots, shots and hits, where the hits landed, each weapon used,
// deaths in a row, and the weapon that killed them most. kind: "" (asked), "auto" or "summary"; question: the
// player's, if any.
send_coach(id, const kind[], const question[] = "")
{
	new JSON:event = player(id)
	json_object_set_string(event, "type", "coach")
	if (kind[0])
		json_object_set_bool(event, kind, true)
	if (question[0])
		json_object_set_string(event, "question", question)

	new stats[STATSX_MAX_STATS], body[MAX_BODYHITS]
	get_user_wstats(id, 0, stats, body)
	// stats[]: 0 kills, 1 deaths, 2 headshots, 3 team kills, 4 shots, 5 hits, 6 damage.
	json_object_set_number(event, "kills", stats[0])
	json_object_set_number(event, "deaths", stats[1])
	json_object_set_number(event, "headshots", stats[2])
	json_object_set_number(event, "shots", stats[4])
	json_object_set_number(event, "hits", stats[5])
	new JSON:parts = json_init_object()
	json_object_set_number(parts, "head", body[HIT_HEAD])
	json_object_set_number(parts, "chest", body[HIT_CHEST])
	json_object_set_number(parts, "stomach", body[HIT_STOMACH])
	json_object_set_number(parts, "arms", body[HIT_LEFTARM] + body[HIT_RIGHTARM])
	json_object_set_number(parts, "legs", body[HIT_LEFTLEG] + body[HIT_RIGHTLEG])
	json_object_set_value(event, "body", parts)
	json_free(parts)

	new JSON:weapons = json_init_array(), name[32], worst, worst_count
	for (new w = 1; w <= CSW_P90; w++)
	{
		if (g_killed_by[id][w] > worst_count)
		{
			worst = w
			worst_count = g_killed_by[id][w]
		}
		if (!get_user_wstats(id, w, stats, body) || !stats[4])
			continue
		get_weaponname(w, name, charsmax(name))
		new JSON:weapon = json_init_object()
		json_object_set_string(weapon, "name", name[7])  // after "weapon_"
		json_object_set_number(weapon, "kills", stats[0])
		json_object_set_number(weapon, "shots", stats[4])
		json_object_set_number(weapon, "hits", stats[5])
		json_array_append_value(weapons, weapon)
		json_free(weapon)
	}
	json_object_set_value(event, "weapons", weapons)
	json_free(weapons)
	if (worst)
	{
		get_weaponname(worst, name, charsmax(name))
		json_object_set_string(event, "killed_by", name[7])
	}
	json_object_set_number(event, "streak", g_streak[id])
	send(event)
}

give_money(id, amount)
{
	cs_set_user_money(id, min(cs_get_user_money(id) + amount, 16000))
}

// War3FT XP for the player's race, through War3FT's own server command (changexp <slot> <xp>). Humans only: a bot's
// XP serves nothing.
give_xp(id, xp)
{
	if (!is_user_bot(id))
		server_cmd("changexp %d %d", id, xp)
}

// T or CT: not a spectator (an AFK player is moved there).
bool:in_team(id)
{
	new CsTeams:team = cs_get_user_team(id)
	return team == CS_TEAM_T || team == CS_TEAM_CT
}

// The map's MVP (common.inc), bot or human; and the best human, if a bot is on top. Only when a human played this map.
public announce_mvp()
{
	new best = map_mvp(), best_human = map_mvp(true)
	if (!best_human)
		return
	new map[32], name[32], text[192]
	get_mapname(map, charsmax(map))
	get_user_name(best, name, charsmax(name))
	formatex(text, charsmax(text), "MVP of %s: %s, %d kills, %d deaths!", map, name, get_user_frags(best),
		get_user_deaths(best))
	if (best != best_human)
	{
		get_user_name(best_human, name, charsmax(name))
		format(text, charsmax(text), "%s Best human: %s, %d kills.", text, name, get_user_frags(best_human))
	}
	announce(text)
}

announce(const text[])
{
	client_print_color(0, print_team_default, "^4[AI Game Master]^1 %s", text)
	set_hudmessage(255, 80, 0, -1.0, 0.18, 0, 0.0, 5.0, 0.1, 0.5, -1)
	show_hudmessage(0, "%s", text)
	log_message("^"Game Master^" say ^"%s^"", text)
	// For the server's journal, written each night by the relay.
	new JSON:event = json_init_object()
	json_object_set_string(event, "type", "news")
	json_object_set_string(event, "text", text)
	send(event)
}
