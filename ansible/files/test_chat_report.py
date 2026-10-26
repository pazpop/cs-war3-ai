# The chat report's checks, on lines in the game's log format: python3 -m unittest discover ansible/files
import unittest

from chat_report import report

LOG = [
    'L 10/26/2026 - 07:58:08: "Ann<42><STEAM_0:1:123456><>" entered the game\n',
    'L 10/26/2026 - 07:58:16: "Ann<42><STEAM_0:1:123456><TERRORIST>" say "hey guys!"\n',
    'L 10/26/2026 - 07:58:20: "[AI] Zed<5><BOT><CT>" say "Welcome back from the dead, Ann."\n',
    'L 10/26/2026 - 07:59:00: "[AI] Kai<6><BOT><CT>" entered the game\n',
    'L 10/26/2026 - 08:00:01: "Ann<42><STEAM_0:1:123456><TERRORIST>" say_team "cover me"\n',
    'L 10/26/2026 - 08:10:00: "Game Master" say "Bounty on Zed!"\n',
    'L 10/26/2026 - 08:11:00: "Coach to Ann" say "Aim at the head."\n',
    'L 10/26/2026 - 08:32:17: "Ann<-1><><TERRORIST>" disconnected\r\n',
    'L 10/27/2026 - 00:00:01: "Ann<42><STEAM_0:1:123456><CT>" say "another day"\n',
]


class ChatReport(unittest.TestCase):
    def test_report(self):
        self.assertEqual(report(LOG, "2026-10-26"), [
            "07:58:08 -- Ann entered the game",
            "07:58:16 Ann: hey guys!",
            "07:58:20 [AI] Zed: Welcome back from the dead, Ann.",
            "08:00:01 Ann (team): cover me",
            "08:10:00 Game Master: Bounty on Zed!",
            "08:11:00 Coach to Ann: Aim at the head.",
            "08:32:17 -- Ann disconnected",
        ])

    def test_no_ids(self):
        # Never a SteamID in the report.
        self.assertNotIn("STEAM", "".join(report(LOG, "2026-10-26")))


if __name__ == "__main__":
    unittest.main()
