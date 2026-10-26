// Every kill, for our plugins that count them: #include "kills.inc", call register_kills() in plugin_init, and write
// public on_kill(killer, victim, bool:headshot, const weapon[]). killer is 0 for a death by the world (a fall...).
// War3FT kills with its spells, wards and item bonuses through its own death notice, which other plugins never see
// (message_begin, not emessage_begin): it reports these kills through its forward wc3_reportkill instead.

new Float:g_war3ft_kill[33]  // when War3FT last reported killing this player

stock register_kills()
{
	register_event("DeathMsg", "kills_death_notice", "a")
}

public kills_death_notice()
{
	new victim = read_data(2)
	// A kill War3FT has just reported: counted once, whatever notice the game also sends for it.
	if (get_gametime() - g_war3ft_kill[victim] < 0.1)
		return
	new weapon[32]
	read_data(4, weapon, charsmax(weapon))
	on_kill(read_data(1), victim, bool:read_data(3), weapon)
}

// weapon: War3FT's number for it (a CS weapon's, or one of its spells'); name: as the death notice shows it.
public wc3_reportkill(killer, victim, weapon, const name[])
{
	g_war3ft_kill[victim] = get_gametime()
	on_kill(killer, victim, false, name)
}
