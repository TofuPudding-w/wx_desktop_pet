"""A stale report or a clean early exit must never pass real-duration acceptance."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from soak_desktop import completion_failures

class SoakGateTests(unittest.TestCase):
    def snapshot(self):
        return {'elapsed_seconds': 7200.1, 'completed': 180,
                'pets': [{'id': 'A'}, {'id': 'B'}]}

    def test_complete_run_passes(self):
        self.assertEqual(completion_failures(self.snapshot(), 0, 7201, 7200, ''), [])

    def test_clean_early_exit_fails(self):
        snapshot = self.snapshot()
        snapshot['elapsed_seconds'] = 2132
        self.assertTrue(completion_failures(snapshot, 0, 2161, 7200, ''))

    def test_stale_application_report_cannot_replace_wall_time(self):
        self.assertTrue(completion_failures(self.snapshot(), 0, 30, 7200, ''))

    def test_missing_pet_fails(self):
        snapshot = self.snapshot()
        snapshot['pets'].pop()
        self.assertTrue(completion_failures(snapshot, 0, 7201, 7200, ''))

    def test_script_error_fails(self):
        self.assertTrue(completion_failures(self.snapshot(), 0, 7201, 7200, 'SCRIPT ERROR: broken'))

    def test_stalled_interactions_fail(self):
        snapshot = self.snapshot()
        snapshot['completed'] = 10
        self.assertTrue(completion_failures(snapshot, 0, 7201, 7200, ''))

    def test_crash_fails(self):
        self.assertTrue(completion_failures(self.snapshot(), -11, 7201, 7200, ''))

if __name__ == '__main__':
    unittest.main()
