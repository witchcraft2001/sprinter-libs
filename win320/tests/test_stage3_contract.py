from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "win320.asm").read_text()
STAGE3 = (ROOT / "stage3.inc").read_text()


class Stage3ContractTests(unittest.TestCase):
    def test_entries_use_the_stage3_implementations(self) -> None:
        for name in ("win_poll:", "win_track:", "win_wait_release:", "win_set_cursor:"):
            self.assertIn(name, STAGE3)
        self.assertIn('include "stage3.inc"', SOURCE)

    def test_tracking_state_and_reverse_half_open_hit_test(self) -> None:
        for token in ("S3_ST_INIT_XH", "S3_ST_XL", "S3_ST_Y", "S3_ST_BUTTONS",
                      "S3_ST_HIT", "S3_ST_HOVER", "S3_ST_CAPTURE", "S3_ST_REPEAT"):
            self.assertIn(token, STAGE3)
        hit = STAGE3.split("s3_find_hit:", 1)[1].split("s3_point_in_geometry:", 1)[0]
        self.assertIn("dec a", hit)
        self.assertIn("WIN_IT_HIDDEN|WIN_IT_DISABLED|WIN_IT_HIT", hit)
        point = STAGE3.split("s3_point_in_geometry:", 1)[1].split("s3_left_action:", 1)[0]
        self.assertGreaterEqual(point.count("ret nc"), 2)
        self.assertIn("jr c,.outside", point)
        self.assertNotIn("ret c", point)

    def test_actions_precede_hover_then_keyboard_and_key_scan_is_raw(self) -> None:
        poll = STAGE3.split("s3_poll:", 1)[1].split("s3_preflight:", 1)[0]
        self.assertLess(poll.find("call s3_mouse_iteration"), poll.find("call s3_keyboard_iteration"))
        mouse = STAGE3.split("s3_mouse_iteration:", 1)[1].split("s3_find_hit:", 1)[0]
        self.assertLess(mouse.find("call s3_left_action"), mouse.find("call s3_right_action"))
        self.assertLess(mouse.find("call s3_right_action"), mouse.find("call s3_hover_action"))
        keys = STAGE3.split("s3_find_key:", 1)[1].split("; ---- event helpers", 1)[0]
        self.assertIn("and #7f", keys)
        self.assertIn("WIN_TRK_ANY_KEY", keys)

    def test_cursor_and_firmware_calls_are_isolated_from_mapping(self) -> None:
        self.assertIn("call win_mouse_call", STAGE3)
        self.assertIn("call win_scankey_call", STAGE3)
        self.assertIn("win_halt_call", STAGE3)
        cursor = STAGE3.split("win_set_cursor:", 1)[1].split("s3_poll:", 1)[0]
        self.assertIn("cp 33", cursor)
        self.assertIn("call s3_mul8", cursor)
        self.assertNotIn("halt", cursor.lower())


if __name__ == "__main__":
    unittest.main()
