# The relay's checks, without the API: python3 -m unittest discover ai
import os
import unittest

os.environ["AI_DB"] = ":memory:"
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

    def test_named_bot(self):
        bots = [{"id": 7, "name": "Grim"}, {"id": 8, "name": "Al"}]
        self.assertEqual(relay.named_bot("hey GRIM, nice shot", bots)["id"], 7)
        self.assertIsNone(relay.named_bot("all good", bots))  # "Al" is too short to match

    def test_valid_gm(self):
        self.assertEqual(relay.valid_gm({"event": "bounty", "target": 3, "target2": 0, "line": "Hunt Pierre!"},
                                        PLAYERS)["target"], 3)
        self.assertIsNone(relay.valid_gm({"event": "bounty", "target": 42, "target2": 0, "line": "x"}, PLAYERS))
        self.assertIsNone(relay.valid_gm({"event": "duel", "target": 3, "target2": 9, "line": "x"}, PLAYERS))
        self.assertIsNotNone(relay.valid_gm({"event": "duel", "target": 3, "target2": 7, "line": "x"}, PLAYERS))
        self.assertIsNone(relay.valid_gm({"event": "kick_all", "target": 0, "target2": 0, "line": "x"}, PLAYERS))

    def test_memory(self):
        relay.remember("STEAM_0:1:1", "bot_kills")
        relay.remember("STEAM_0:1:1", "bot_kills")
        self.assertIn("killed 2 bots", relay.memory("STEAM_0:1:1", "Pierre"))
        self.assertIn("newcomer", relay.memory("", "Ann"))

    def test_without_key(self):
        # No API key: nothing to say, and the game goes on.
        self.assertEqual(relay.handle(b'{"type": "state", "players": []}'), {})
        self.assertEqual(relay.handle(b"not json"), {})
        self.assertIsNone(relay.claude("system", "prompt"))


if __name__ == "__main__":
    unittest.main()
