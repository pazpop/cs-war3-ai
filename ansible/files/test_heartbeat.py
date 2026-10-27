# The heartbeat's checks, without a server: python3 -m unittest discover ansible/files (from the repository's root)
import collections
import unittest
from unittest import mock

import heartbeat

Usage = collections.namedtuple("Usage", "total used free")


class Heartbeat(unittest.TestCase):
    def test_disk(self):
        # All well, but the disk nearly full: the one problem.
        with mock.patch.object(heartbeat, "game_answers", return_value=True), \
                mock.patch.object(heartbeat, "page_loads", return_value=True):
            with mock.patch.object(heartbeat.shutil, "disk_usage", return_value=Usage(100, 95, 5)):
                self.assertEqual(heartbeat.problems_now("example.com"), ["the disk is 95% full"])
            with mock.patch.object(heartbeat.shutil, "disk_usage", return_value=Usage(100, 50, 50)):
                self.assertEqual(heartbeat.problems_now("example.com"), [])


if __name__ == "__main__":
    unittest.main()
