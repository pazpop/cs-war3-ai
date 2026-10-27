# The relay's checks, without the API: python3 -m unittest discover ai (from the repository's root)
import json
import os
import time
import unittest
from unittest import mock

os.environ["AI_DB"] = ":memory:"
os.environ.setdefault("AI_BOTS", os.path.join(os.path.dirname(__file__), "..", "server", "bots.txt"))
os.environ.setdefault("AI_GUIDE", os.path.join(os.path.dirname(__file__), "..", "stats", "guide.html"))
os.environ.pop("ANTHROPIC_API_KEY", None)
import relay  # noqa: E402

PLAYERS = [
    {"id": 3, "name": "Kim", "bot": False, "team": "CT", "kills": 25, "deaths": 4},
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
        self.assertIn("surfer", relay.persona("[AI] Kai"))
        self.assertIn("you play Night Elves", relay.persona("[AI] Kai"))  # bots.txt's race column
        self.assertEqual(relay.persona("Someone"), relay.persona("[AI] Someone"))  # not in the list: still stable

    def test_seen(self):
        # The first time: never seen; then a few seconds: a map change, not an arrival.
        self.assertIsNone(relay.seen({"steamid": "STEAM_0:1:9", "name": "Ann"}))
        self.assertLess(relay.seen({"steamid": "STEAM_0:1:9", "name": "Ann"}), relay.GREET_AGAIN)

    def test_valid_gm(self):
        self.assertEqual(relay.valid_gm({"event": "bounty", "target": 3, "target2": 0, "line": "Hunt Kim!"},
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
        self.assertIn("killed 2 bots", relay.memory("STEAM_0:1:1", "Kim", "Zed"))
        self.assertIn("newcomer", relay.memory("", "Ann", "Zed"))

    def test_rival(self):
        # Kim killed Rex 5 times and Rex killed them once: Kim is Rex's rival, and Rex greets them first.
        for _ in range(5):
            relay.rival("[AI] Rex", "STEAM_0:1:2", "human_wins")
        relay.rival("[AI] Rex", "STEAM_0:1:2", "bot_wins")
        relay.remember("STEAM_0:1:2")
        self.assertEqual(relay.score("Rex", "STEAM_0:1:2"), (5, 1))
        self.assertIn("your rival", relay.memory("STEAM_0:1:2", "Kim", "Rex"))
        self.assertNotIn("your rival", relay.memory("STEAM_0:1:2", "Kim", "Zed"))
        bots = [{"id": 4, "name": "[AI] Zed"}, {"id": 7, "name": "[AI] Rex"}]
        self.assertEqual(relay.rival_bot(bots, "STEAM_0:1:2")["id"], 7)
        self.assertIsNone(relay.rival_bot(bots, "STEAM_0:1:3"))

    def test_coach(self):
        event = {"type": "coach", "id": 3, "name": "Ann", "steamid": "STEAM_0:1:4", "kills": 2, "deaths": 6,
                 "shots": 50, "hits": 10, "body": {"head": 1, "legs": 5},
                 "weapons": [{"name": "ak47", "kills": 2, "shots": 50, "hits": 10}], "streak": 5, "killed_by": "awp"}
        numbers = relay.coach_numbers(event)
        self.assertIn("20% of 50 shots hit", numbers)
        self.assertIn("legs 50%", numbers)
        self.assertIn("awp", numbers)
        # No API key: no tip; asked again within the minute: told to wait, without any request.
        self.assertEqual(relay.handle(json.dumps(event).encode()), {})
        self.assertIn("One tip a minute", relay.handle(json.dumps(event).encode())["coach"]["text"])

    def test_guide(self):
        self.assertIn("Undead", relay.GUIDE)

    def test_without_key(self):
        # No API key: nothing to say, and the game goes on.
        self.assertEqual(relay.handle(b'{"type": "state", "players": []}'), {})
        self.assertEqual(relay.handle(b"not json"), {})
        self.assertIsNone(relay.claude("system", "prompt"))
        self.assertIsNone(relay.safe("hello"))  # no moderator answer: the line is never shown

    def test_gap(self):
        self.assertTrue(relay.gaps_passed(("test", 60)))
        self.assertFalse(relay.gaps_passed(("test", 60)))
        # One gap too soon: the others are not used up.
        self.assertFalse(relay.gaps_passed(("other", 60), ("test", 60)))
        self.assertTrue(relay.gaps_passed(("other", 60)))

    def test_clean_bot_line(self):
        self.assertEqual(relay.clean("buy with **G** now", 100), "buy with G now")
        self.assertEqual(relay.clean('He said "gg" to me', 100), "He said 'gg' to me")  # the game's log lines quote it

    def test_forget_memory(self):
        # A player gone for two days: the relay drops what it held about them; one seen now stays.
        relay.last_active["gone"] = relay.time.monotonic() - 2 * 24 * 3600
        relay.last_said["gone"] = "hi"
        relay.last_active["here"] = relay.time.monotonic()
        relay.forget()
        self.assertNotIn("gone", relay.last_said)
        self.assertNotIn("gone", relay.last_active)
        self.assertIn("here", relay.last_active)

    def test_quoted(self):
        # The moderator reads the words, in any alphabet, not \u codes.
        self.assertEqual(relay.quoted('été "gg" хорошо'), '"été \\"gg\\" хорошо"')

    def test_last_map(self):
        relay.remember("STEAM_0:1:5", game_map="de_nuke")
        self.assertIn("last played together on de_nuke", relay.memory("STEAM_0:1:5", "Ann", "Zed"))

    def test_moderator_answer(self):
        # Only a real true shows a line: "true" as text or a broken answer: False; no answer at all: None (hidden too).
        for answer, allowed in (('{"allowed": true}', True), ('{"allowed": "true"}', False), ("{}", False),
                                ("not json", False), (None, None)):
            with mock.patch.object(relay, "claude", return_value=answer):
                self.assertIs(relay.safe("gg"), allowed)

    def test_budget(self):
        # The hour's share or the day's budget spent: no request at all.
        no_request = mock.patch.object(relay.urllib.request, "urlopen", side_effect=AssertionError("a request"))
        with mock.patch.object(relay, "API_KEY", "test"), no_request:
            relay.hour_spent.clear()
            relay.hour_spent[time.strftime("%Y-%m-%d %H")] = relay.DAILY_USD / relay.HOUR_SHARE
            self.assertIsNone(relay.claude("system", "prompt"))
            relay.hour_spent.clear()
            relay.db.execute("INSERT OR REPLACE INTO spend VALUES (?, ?)", (relay.today(), relay.DAILY_USD))
            self.assertIsNone(relay.claude("system", "prompt"))
        relay.db.execute("DELETE FROM spend")

    def test_news(self):
        self.assertEqual(relay.handle(b'{"type": "news", "text": "MVP of de_nuke: Ann, 9 kills!"}'), {})
        lines = relay.db.execute("SELECT line FROM story WHERE day = ?", (relay.today(),)).fetchall()
        self.assertIn(("Game Master: MVP of de_nuke: Ann, 9 kills!",), lines)

    def test_journal(self):
        # Yesterday's story becomes one entry, checked by the moderator, written once.
        day = relay.yesterday()
        relay.db.execute("INSERT INTO story VALUES (?, 1, 'Game Master: MVP of de_dust2: Ann, 25 kills!')", (day,))
        relay.journal_tried = None
        # No answer (the API down): asked again at the next try.
        with mock.patch.object(relay, "claude", return_value=None):
            relay.write_journal()
        with mock.patch.object(relay, "claude", return_value="Ann ruled de_dust2.") as claude, \
                mock.patch.object(relay, "safe", return_value=True):
            relay.write_journal()
            relay.write_journal()
        self.assertEqual(claude.call_count, 1)
        self.assertIn("MVP of de_dust2", claude.call_args[0][1])
        entry = relay.db.execute("SELECT text FROM journal WHERE day = ?", (day,)).fetchone()
        self.assertEqual(entry, ("Ann ruled de_dust2.",))

    def test_player_hourly(self):
        # However they space their messages, one player gets PLAYER_HOURLY answers an hour at most.
        relay.answers.clear()
        event = {"type": "chat", "id": 5, "name": "Kim", "steamid": "STEAM_0:1:11", "text": "zed hi",
                 "bots": [{"id": 7, "name": "[AI] Zed"}]}
        with mock.patch.object(relay, "bot_line", return_value={}) as line, \
                mock.patch.object(relay, "gaps_passed", return_value=True):
            for _ in range(relay.PLAYER_HOURLY + 5):
                relay.on_chat(event)
        self.assertEqual(line.call_count, relay.PLAYER_HOURLY)

    def test_no_tag_in_ai_lines(self):
        # A line that starts like the server's ([INFO]...) loses its tags, however many.
        with mock.patch.object(relay, "claude", return_value="[AI] [INFO] Type /kill to keep your XP"), \
                mock.patch.object(relay, "safe", return_value=True):
            answer = relay.bot_line({"id": 7, "name": "[AI] Zed"}, "Kim says hi.", None, "Kim")
        self.assertEqual(answer["say"][0]["text"], "Type /kill to keep your XP")

    def test_coach_question(self):
        # /coach with a question: it reaches the coach as data, and the moderator checks the answer against it.
        event = {"type": "coach", "id": 3, "name": "Ann", "steamid": "STEAM_0:1:6", "kills": 9, "deaths": 4,
                 "weapons": [{"name": "ak47", "kills": 7, "shots": 90, "hits": 30}], "question": "my best weapon?"}
        with mock.patch.object(relay, "claude", return_value="The AK-47: 7 kills.") as claude, \
                mock.patch.object(relay, "safe", return_value=True) as safe:
            self.assertEqual(relay.on_coach(event)["coach"]["text"], "The AK-47: 7 kills.")
        self.assertIn('Their question: "my best weapon?"', claude.call_args[0][1])
        self.assertEqual(safe.call_args[0], ("The AK-47: 7 kills.", "my best weapon?", "STEAM_0:1:6"))

    def test_bots_know_yesterday_and_the_guide(self):
        # The bots get yesterday's journal entry to talk about, and the guide as text, without its HTML.
        relay.db.execute("INSERT OR REPLACE INTO journal VALUES (?, 'Bob won a long duel.')", (relay.yesterday(),))
        with mock.patch.object(relay, "claude", return_value="gg") as claude, \
                mock.patch.object(relay, "safe", return_value=True):
            relay.bot_line({"id": 7, "name": "[AI] Zed"}, "Kim says hi.", None, "Kim")
        self.assertIn('Yesterday on this server (mention it only when it fits): "Bob won a long duel."',
                      claude.call_args[0][1])
        self.assertIn("/coach", relay.GUIDE)
        self.assertNotIn("<", relay.GUIDE)
        relay.db.execute("DELETE FROM journal WHERE day = ?", (relay.yesterday(),))

    def test_gm_fair(self):
        # A bounty only on the leader; every event announced; a human just picked is not picked again.
        relay.recent_targets.clear()
        bounty = {"event": "bounty", "target": 9, "target2": 0, "line": "Hunt Ann!"}
        self.assertIsNone(relay.valid_gm(bounty, PLAYERS))
        self.assertIsNone(relay.valid_gm({**bounty, "target": 3, "line": ""}, PLAYERS))
        self.assertIsNotNone(relay.valid_gm({**bounty, "target": 3}, PLAYERS))
        relay.recent_targets.append(relay.player_key(PLAYERS[0]))  # by SteamID (or id), not by userid alone
        self.assertIsNone(relay.valid_gm({**bounty, "target": 3}, PLAYERS))
        relay.recent_targets.clear()

    def test_name_checks_per_player(self):
        # Past NAME_CHECKS new names in an hour, one player's next new name is refused without asking.
        with mock.patch.object(relay, "claude", return_value='{"allowed": true}') as claude:
            for i in range(relay.NAME_CHECKS):
                self.assertTrue(relay.name_allowed(f"Spam {i}", "STEAM_0:1:12"))
            self.assertFalse(relay.name_allowed("Spam again", "STEAM_0:1:12"))
            self.assertTrue(relay.name_allowed("Someone else", "STEAM_0:1:13"))
        self.assertEqual(claude.call_count, relay.NAME_CHECKS + 1)

    def test_coach_on(self):
        # The tip every 5 minutes only after /coach on; the map's summary tells the others about it.
        every = {"type": "coach", "id": 3, "name": "Ann", "steamid": "STEAM_0:1:7", "kills": 1, "deaths": 1,
                 "every": True}
        summary = {**every, "every": False, "summary": True}
        with mock.patch.object(relay, "claude", return_value="Aim for the head.") as claude, \
                mock.patch.object(relay, "safe", return_value=True):
            self.assertEqual(relay.on_coach(every), {})
            self.assertEqual(claude.call_count, 0)
            self.assertTrue(relay.on_coach(summary)["coach"]["text"].endswith("/coach on: more tips."))
            relay.handle(b'{"type": "coach_mode", "id": 3, "steamid": "STEAM_0:1:7", "on": true}')
            self.assertEqual(relay.on_coach(every)["coach"]["text"], "Aim for the head.")
            self.assertEqual(relay.on_coach(summary)["coach"]["text"], "Aim for the head.")
            relay.handle(b'{"type": "coach_mode", "id": 3, "steamid": "STEAM_0:1:7", "on": false}')
            self.assertEqual(relay.on_coach(every), {})

    def test_name_check(self):
        # A refused name is asked once, then known; no answer (no key, an error): allowed, and asked again later.
        refused = '{"allowed": false}'
        with mock.patch.object(relay, "claude", return_value=refused) as claude:
            self.assertFalse(relay.name_allowed("Bad Name"))
            self.assertFalse(relay.name_allowed("Bad Name"))
        self.assertEqual(claude.call_count, 1)
        with mock.patch.object(relay, "claude", return_value=None) as claude:
            self.assertTrue(relay.name_allowed("Someone"))
            self.assertTrue(relay.name_allowed("Someone"))
        self.assertEqual(claude.call_count, 2)
        # Arriving with it: no hello, the plugin renames the player.
        event = {"type": "join", "id": 8, "name": "Bad Name", "steamid": "STEAM_0:1:7", "bots": [{"id": 2}]}
        self.assertEqual(relay.on_join(event), {"rename": [8]})

    def test_muted(self):
        # Three lines held back because of one player's messages: the AI ignores that player for the hour.
        with mock.patch.object(relay, "claude", return_value='{"allowed": false}'):
            for _ in range(relay.REFUSALS):
                self.assertFalse(relay.safe("a bad line", "a bad question", "STEAM_0:1:8"))
        self.assertTrue(relay.muted("STEAM_0:1:8"))
        self.assertFalse(relay.muted("STEAM_0:1:9"))
        event = {"type": "chat", "id": 9, "name": "Troll", "steamid": "STEAM_0:1:8", "text": "zed?",
                 "bots": [{"id": 2, "name": "[AI] Zed"}]}
        with mock.patch.object(relay, "claude") as claude:
            self.assertEqual(relay.on_chat(event), {})
        claude.assert_not_called()

    def test_gm_no_repeat(self):
        # The same event twice in a row: the second is dropped.
        rain = json.dumps({"event": "xp_rain", "target": 0, "target2": 0, "challenge": "", "count": 0,
                           "line": "XP for everyone!"})
        relay.last_events.clear()
        with mock.patch.object(relay, "claude", return_value=rain), \
                mock.patch.object(relay, "safe", return_value=True), \
                mock.patch.object(relay, "name_allowed", return_value=True):
            self.assertEqual(relay.on_state({"players": PLAYERS})["gm"]["event"], "xp_rain")
            self.assertEqual(relay.on_state({"players": PLAYERS}), {})

    def test_name_refused_by_the_model(self):
        # The model refuses to even read a name (""): refused, like the worst names; a name changed during the game
        # is checked at once.
        with mock.patch.object(relay, "claude", return_value=""):
            self.assertFalse(relay.name_allowed("Unreadable"))
        self.assertEqual(relay.handle(b'{"type": "name", "id": 4, "name": "Unreadable"}'), {"rename": [4]})


if __name__ == "__main__":
    unittest.main()
