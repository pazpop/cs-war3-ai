# The relay's checks, without the API: python3 -m unittest discover ai (from the repository's root)
import os
import unittest

os.environ["AI_DB"] = ":memory:"
os.environ.setdefault("AI_BOTS", os.path.join(os.path.dirname(__file__), "..", "server", "bots.txt"))
os.environ.setdefault("AI_GUIDE", os.path.join(os.path.dirname(__file__), "..", "docs", "war3ft.md"))
os.environ.pop("ANTHROPIC_API_KEY", None)
import relay  # noqa: E402

PLAYERS = [
    {"id": 3, "name": "Pierre", "bot": False, "team": "CT", "kills": 25, "deaths": 4},
    {"id": 7, "name": "Grim", "bot": True, "team": "TERRORIST", "kills": 5, "deaths": 20},
    {"id": 9, "name": "Ann", "bot": False, "team": "CT", "kills": 2, "deaths": 9},
]


class Relay(unittest.TestCase):
    def test_clean(self):
        self.assertEqual(relay.clean('"\x04Hello\x01  there\n"', 100), "Hello there")
        self.assertEqual(relay.clean("one two three", 9), "one two")
        self.assertEqual(relay.clean("été été été", 11), "été été")  # bytes, not letters: "été" is 5
        self.assertEqual(relay.clean("été été été", 10), "été")
        self.assertEqual(relay.clean("abcdefghijkl", 5), "abcde")  # one long word: cut

    def test_named_bot(self):
        bots = [{"id": 7, "name": "Grim"}, {"id": 8, "name": "Al"}]
        self.assertEqual(relay.named_bot("hey GRIM, nice shot", bots)["id"], 7)
        self.assertIsNone(relay.named_bot("all good", bots))  # "Al" is too short to match
        self.assertIsNone(relay.named_bot("Grimace is a race", bots))  # a word, not a part of one
        self.assertEqual(relay.named_bot("@grim: gg", bots)["id"], 7)

    def test_names(self):
        bots = [{"id": 4, "name": "[AI] Zed"}]
        self.assertEqual(relay.named_bot("zed, where are you?", bots)["id"], 4)  # players write it without [AI]
        self.assertIn("Undead", relay.persona("[AI] Zed"))
        self.assertEqual(relay.persona("Someone"), relay.persona("[AI] Someone"))  # not in the list: still stable

    def test_seen(self):
        # The first time: never seen; then a few seconds: a map change, not an arrival.
        self.assertIsNone(relay.seen({"steamid": "STEAM_0:1:9", "name": "Ann"}))
        self.assertLess(relay.seen({"steamid": "STEAM_0:1:9", "name": "Ann"}), relay.GREET_AGAIN)

    def test_valid_gm(self):
        self.assertEqual(relay.valid_gm({"event": "bounty", "target": 3, "target2": 0, "line": "Hunt Pierre!"},
                                        PLAYERS)["target"], 3)
        self.assertIsNone(relay.valid_gm({"event": "bounty", "target": 42, "target2": 0, "line": "x"}, PLAYERS))
        self.assertIsNone(relay.valid_gm({"event": "duel", "target": 3, "target2": 9, "line": "x"}, PLAYERS))
        self.assertIsNotNone(relay.valid_gm({"event": "duel", "target": 3, "target2": 7, "line": "x"}, PLAYERS))
        self.assertIsNone(relay.valid_gm({"event": "kick_all", "target": 0, "target2": 0, "line": "x"}, PLAYERS))
        # A boss is a bot facing humans; a duel has a human; a challenge's count stays within its bounds.
        self.assertIsNone(relay.valid_gm({"event": "boss", "target": 3, "target2": 0, "line": "x"}, PLAYERS))
        self.assertEqual(relay.valid_gm({"event": "boss", "target": 7, "target2": 0, "line": "x"}, PLAYERS)["target"], 7)
        teammate = PLAYERS + [{"id": 8, "name": "Leo", "bot": True, "team": "CT", "kills": 9, "deaths": 9}]
        self.assertIsNone(relay.valid_gm({"event": "boss", "target": 8, "target2": 0, "line": "x"}, teammate))
        bots = teammate + [{"id": 4, "name": "Zed", "bot": True, "team": "TERRORIST", "kills": 1, "deaths": 1}]
        self.assertIsNone(relay.valid_gm({"event": "duel", "target": 4, "target2": 8, "line": "x"}, bots))
        challenge = {"event": "challenge", "target": 0, "target2": 0, "challenge": "kills", "count": 50, "line": "x"}
        self.assertEqual(relay.valid_gm(challenge, PLAYERS)["count"], 6)
        self.assertIsNone(relay.valid_gm(dict(challenge, challenge="suicide"), PLAYERS))

    def test_memory(self):
        self.assertTrue(relay.is_new("STEAM_0:1:1"))
        relay.remember("STEAM_0:1:1", "bot_kills")
        relay.remember("STEAM_0:1:1", "bot_kills")
        self.assertFalse(relay.is_new("STEAM_0:1:1"))
        self.assertIn("killed 2 bots", relay.memory("STEAM_0:1:1", "Pierre", "Zed"))
        self.assertIn("newcomer", relay.memory("", "Ann", "Zed"))

    def test_grudge(self):
        # Pierre killed Rex 5 times and Rex killed him once: Rex holds a grudge, and greets him first.
        for _ in range(5):
            relay.rival("[AI] Rex", "STEAM_0:1:2", "human_wins")
        relay.rival("[AI] Rex", "STEAM_0:1:2", "bot_wins")
        relay.remember("STEAM_0:1:2")
        self.assertEqual(relay.score("Rex", "STEAM_0:1:2"), (5, 1))
        self.assertIn("grudge", relay.memory("STEAM_0:1:2", "Pierre", "Rex"))
        self.assertNotIn("grudge", relay.memory("STEAM_0:1:2", "Pierre", "Zed"))
        bots = [{"id": 4, "name": "[AI] Zed"}, {"id": 7, "name": "[AI] Rex"}]
        self.assertEqual(relay.grudge_bot(bots, "STEAM_0:1:2")["id"], 7)
        self.assertIsNone(relay.grudge_bot(bots, "STEAM_0:1:3"))

    def test_guide(self):
        self.assertIn("Undead", relay.GUIDE)

    def test_without_key(self):
        # No API key: nothing to say, and the game goes on.
        self.assertEqual(relay.handle(b'{"type": "state", "players": []}'), {})
        self.assertEqual(relay.handle(b"not json"), {})
        self.assertIsNone(relay.claude("system", "prompt"))
        self.assertFalse(relay.safe("hello"))  # no moderator answer: the line is never shown

    def test_gap(self):
        self.assertTrue(relay.gap_passed("test", 60))
        self.assertFalse(relay.gap_passed("test", 60))


if __name__ == "__main__":
    unittest.main()
