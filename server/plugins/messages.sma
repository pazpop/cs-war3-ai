// Messages in the chat, one every 2 minutes, in turn: from configs/messages.txt (one per line; the entrypoint puts
// the server's address in it). For the players who stay: add the server to their favorites, the stats page.
#include <amxmodx>
#include <amxmisc>

#define INTERVAL 120.0  // seconds between two messages
#define MAX_MESSAGES 16

new g_messages[MAX_MESSAGES][160]
new g_count
new g_next

public plugin_init()
{
	register_plugin("Messages", "1.0", "cs-war3-ai")

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
	// ^4: green, ^1: the normal chat color.
	client_print_color(0, print_team_default, "^4[Info]^1 %s", g_messages[g_next])
	g_next = (g_next + 1) % g_count
}
