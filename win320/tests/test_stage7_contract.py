from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INC = (ROOT / "win320.inc").read_text()
ASM = (ROOT / "win320.asm").read_text()
MAKEFILE = (ROOT / "Makefile").read_text()
STAGE2 = (ROOT / "stage2.inc").read_text()
STAGE3 = (ROOT / "stage3.inc").read_text()
STAGE4 = (ROOT / "stage4.inc").read_text()
STAGE7 = (ROOT / "stage7.inc").read_text()
VISUAL = (ROOT / "test.asm").read_text()
C_IMPL = (ROOT / "bind" / "win320.c").read_text()


def equates(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^([A-Z0-9_]+)\s+equ\s+(#[0-9a-fA-F]+|'.'|[0-9]+)")
    for line in path.read_text().splitlines():
        match = pattern.match(line)
        if match is None:
            continue
        token = match.group(2)
        if token.startswith("#"):
            value = int(token[1:], 16)
        elif token.startswith("'") and token.endswith("'"):
            value = ord(token[1])
        else:
            value = int(token)
        values[match.group(1)] = value
    return values


class Stage7ContractTests(unittest.TestCase):
    def test_title_and_close_button_constants(self) -> None:
        values = equates(ROOT / "win320.inc")
        self.assertEqual(20, values["WIN_WINDOW_SIZE"])
        self.assertEqual(
            [14, 16, 17, 18],
            [
                values["WIN_WND_TITLE"], values["WIN_WND_TITLE_ATTR"],
                values["WIN_WND_LAST_FOCUS"], values["WIN_WND_RESERVED"],
            ],
        )
        self.assertEqual(0x04, values["WIN_WND_CLOSE"])
        self.assertEqual(18, values["WIN_THEME_SIZE"])
        self.assertEqual(15, values["WIN_TH_TITLE_BG"])
        self.assertEqual(16, values["WIN_TH_TITLE_FG"])
        self.assertEqual(11, values["WIN_EV_CLOSE"])
        self.assertEqual(14, values["WIN_TITLE_H"])
        self.assertEqual(ord("X"), values["WIN_TITLE_CLOSE_GLYPH"])

    def test_stage7_is_built_into_the_prefix(self) -> None:
        self.assertIn('include "stage7.inc"', ASM)
        prefix_rule = MAKEFILE.split("$(PREFIX):", 1)[1].splitlines()[0]
        self.assertIn("stage7.inc", prefix_rule)

    def test_version_advertises_abi_20(self) -> None:
        self.assertIn("ld d,2", ASM)
        self.assertIn("ld e,0", ASM)

    def test_load_window_accepts_close_flag_and_16bit_reserved(self) -> None:
        self.assertIn("and #f8", STAGE2)
        self.assertIn("ld hl,(window_scratch+WIN_WND_RESERVED)", STAGE2)
        self.assertIn("call s7_validate_title", STAGE2)

    def test_stage4_focus_publish_uses_symbolic_title_offset(self) -> None:
        self.assertIn("ld de,WIN_WND_LAST_FOCUS-WIN_WND_FOCUS", STAGE4)
        self.assertNotIn("inc hl\n        inc hl\n        inc hl", STAGE4)

    def test_draw_hook_runs_between_origin_and_item_walk(self) -> None:
        window = STAGE2.split("s2_win_draw:", 1)[1].split("win_draw_item:", 1)[0]
        origin_pos = window.index("call s2_set_window_origin")
        title_pos = window.index("call s7_draw_title")
        walk_pos = window.index("call s2_begin_item_walk")
        self.assertTrue(origin_pos < title_pos < walk_pos)

    def test_open_preflights_title_before_backstore_is_touched(self) -> None:
        window = STAGE2.split("s2_win_open:", 1)[1]
        items_pos = window.index("call s2_preflight_items")
        title_pos = window.index("call s7_preflight_title")
        backstore_pos = window.index("backstore_pages")
        self.assertTrue(items_pos < title_pos < backstore_pos)

    def test_draw_sequences_fill_then_label_then_close_button(self) -> None:
        fill_pos = STAGE7.index("s1_fill_mapped")
        label_pos = STAGE7.index("call s1_label_loaded")
        button_pos = STAGE7.index("call s7_stage_close_button")
        self.assertTrue(fill_pos < label_pos < button_pos)
        # button_scratch aliases label_scratch: staging the button must never
        # happen before the label render call has already run.
        self.assertNotIn("s7_stage_close_button\n        call s1_label_loaded", STAGE7)

    def test_chrome_hit_test_runs_before_the_item_scan(self) -> None:
        find_hit = STAGE3.split("s3_find_hit:", 1)[1].split("s3_point_in_geometry:", 1)[0]
        self.assertTrue(find_hit.index("call s7_chrome_hit") < find_hit.index(".scan:"))

    def test_sentinel_indices_guard_item_array_access(self) -> None:
        self.assertIn("cp #fd", STAGE3)
        self.assertIn("cp #fe", STAGE3)
        load_item = STAGE3.split("s3_load_event_item:", 1)[1].split("\n\n", 1)[0]
        self.assertIn("cp #fd", load_item)

    def test_close_button_release_emits_close_event(self) -> None:
        released = STAGE3.split(".chrome_release:", 1)[1].split("s3_clear_capture:", 1)[0]
        self.assertIn("ld a,WIN_EV_CLOSE", released)
        self.assertIn("jp s3_emit_outside", released)

    def test_c_binding_locks_title_offsets(self) -> None:
        self.assertIn("sizeof(win_theme_t) == 18", C_IMPL)
        self.assertIn("sizeof(win_window_t) == 20", C_IMPL)
        self.assertIn("offsetof(win_window_t, title) == 14", C_IMPL)
        self.assertIn("offsetof(win_window_t, title_attr) == 16", C_IMPL)
        self.assertIn("offsetof(win_window_t, last_focus) == 17", C_IMPL)

    def test_visual_window_literals_carry_a_title_field(self) -> None:
        # Every window literal grew a trailing (title, title_attr, reserved)
        # tail; count it so a literal accidentally left at the old 16-byte
        # shape does not silently pass window validation with garbage data.
        # 8 pre-existing windows plus the stage7 showcase's titled window and
        # its no-title companion.
        self.assertEqual(10, VISUAL.count("db #ff,#ff\n        dw 0\n"))


if __name__ == "__main__":
    unittest.main()
