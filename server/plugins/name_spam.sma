// Name spam: a human who changes their name 10 times within 10 minutes is kicked and kept out for an hour, by SteamID
// like votekick.sma (not saved: a restart lifts it). Admins (immunity) and bots are never counted.
#include <amxmodx>
#include "common.inc"

#define CHANGES 10      // name changes...
#define WINDOW 600      // ...within this many seconds: kicked
#define BAN_MINUTES 60

new g_times[33][CHANGES]  // when the player's last CHANGES name changes happened (get_systime), in turn
new g_next[33]            // where the next change goes in g_times

public plugin_init()
{
	register_plugin("Name spam", "1.0", "cs-war3-ai")
}

// A new player in this slot (or a new map): counted from zero.
public client_connect(id)
{
	arrayset(g_times[id], 0, CHANGES)
	g_next[id] = 0
}

public client_infochanged(id)
{
	if (!is_user_connected(id) || is_user_bot(id) || !name_changed(id) || (get_user_flags(id) & ADMIN_IMMUNITY))
		return
	new now = get_systime()
	g_times[id][g_next[id]] = now
	g_next[id] = (g_next[id] + 1) % CHANGES
	// The next place holds the oldest of the last CHANGES changes (0: fewer changes so far).
	new oldest = g_times[id][g_next[id]]
	if (oldest && now - oldest < WINDOW)
		kick_and_ban(id, BAN_MINUTES, "Too many name changes: come back in an hour")
}
