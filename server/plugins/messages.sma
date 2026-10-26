// Messages in the chat, one every 5 minutes, in turn: from configs/messages.txt (one per line, with its tag, [HELP] or
// [INFO]; the entrypoint puts the server's address in it). And one minute before the map's end: the next map.
#include <amxmodx>
#include <amxmisc>

#define INTERVAL 300.0  // seconds between two messages
#define MAX_MESSAGES 16

new g_messages[MAX_MESSAGES][160]
new g_count
new g_next
new bool:g_last_minute_said

public plugin_init()
{
	register_plugin("Messages", "1.0", "cs-war3-ai")
	set_task(5.0, "check_last_minute", .flags = "b")

	new path[96], line[160]
	get_configsdir(path, charsmax(path))
	add(path, charsmax(path), "/messages.txt")
	new file = fopen(path, "rt")
	if (!file)
		return
	while (!feof(file) && g_count < MAX_MESSAGES)
	{
		fgets(file, line, charsmax(line))
		trim(line)
		if (line[0] && line[0] != ';')
			copy(g_messages[g_count++], charsmax(g_messages[]), line)
	}
	fclose(file)

	if (g_count)
		set_task(INTERVAL, "show_next", .flags = "b")
}

public show_next()
{
	say(g_messages[g_next])
	g_next = (g_next + 1) % g_count
}

// After the end vote (mapchooser votes 2 minutes before the end): the next map is known.
public check_last_minute()
{
	new left = get_timeleft()
	if (g_last_minute_said || left <= 0 || left > 60)
		return
	g_last_minute_said = true
	new next[32], text[96]
	get_cvar_string("amx_nextmap", next, charsmax(next))
	formatex(text, charsmax(text), "[INFO] 1 minute left. Next map: %s.", next)
	say(text)
}

// The tag in green (^4), the rest in the normal chat color (^1).
say(const message[])
{
	new tag[16], end = contain(message, "]")
	if (message[0] != '[' || end < 0 || end >= charsmax(tag))
	{
		client_print_color(0, print_team_default, "%s", message)
		return
	}
	copy(tag, end + 1, message)
	client_print_color(0, print_team_default, "^4%s^1%s", tag, message[end + 1])
}
