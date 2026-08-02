from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INC = (ROOT / "win320.inc").read_text()
ASM = (ROOT / "win320.asm").read_text()
STAGE2 = (ROOT / "stage2.inc").read_text()
STAGE3 = (ROOT / "stage3.inc").read_text()
STAGE4 = (ROOT / "stage4.inc").read_text()
STAGE6 = (ROOT / "stage6.inc").read_text()
HARNESS = (ROOT / "tests" / "z80" / "t_stage6.asm").read_text()


def equates(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^([A-Z0-9_]+)\s+equ\s+([#0-9a-fA-F]+)")
    for line in path.read_text().splitlines():
        match = pattern.match(line)
        if match is None:
            continue
        token = match.group(2)
        values[match.group(1)] = (
            int(token[1:], 16) if token.startswith("#") else int(token)
        )
    return values


class Stage6ContractTests(unittest.TestCase):
    def test_choice_abi_layout_entries_events_and_capabilities(self) -> None:
        values = equates(ROOT / "win320.inc")
        self.assertEqual(14, values["WIN_CHOICE_SIZE"])
        self.assertEqual(
            [0, 2, 4, 6, 8, 9, 10, 11, 12],
            [
                values["WIN_CH_X"], values["WIN_CH_Y"],
                values["WIN_CH_WIDTH"], values["WIN_CH_HEIGHT"],
                values["WIN_CH_ATTR"], values["WIN_CH_FLAGS"],
                values["WIN_CH_GROUP"], values["WIN_CH_RESERVED"],
                values["WIN_CH_TEXT"],
            ],
        )
        self.assertEqual(
            [1, 2, 4],
            [values["WIN_CH_CHECKED"], values["WIN_CH_FOCUS"],
             values["WIN_CH_DISABLED"]],
        )
        self.assertEqual((13, 14),
                         (values["WIN_T_CHECKBOX"], values["WIN_T_RADIOBUTTON"]))
        self.assertEqual((37, 38, 39),
                         (values["WIN_CHECKBOX"], values["WIN_RADIOBUTTON"],
                          values["WIN_ENTRY_COUNT"]))
        self.assertEqual(10, values["WIN_EV_CHANGE"])
        self.assertEqual((0x100, 0x200),
                         (values["WIN_CAP_CHECKBOX"],
                          values["WIN_CAP_RADIOBUTTON"]))

    def test_validation_and_shared_renderer_follow_choice_contract(self) -> None:
        load = STAGE6.split("s6_load_choice:", 1)[1].split(
            "s6_render_choice:", 1
        )[0]
        self.assertIn("and #f8", load)
        self.assertIn("WIN_CH_RESERVED", load)
        self.assertIn("WIN_T_CHECKBOX", load)
        self.assertIn("WIN_CH_GROUP", load)
        self.assertIn("ld de,13", load)
        self.assertIn("ld de,10", load)
        self.assertEqual(2, load.count("sbc hl,de"))

        render = STAGE6.split("s6_render_choice:", 1)[1].split(
            "; Remove the four square", 1
        )[0]
        self.assertIn("call s1_copy_rect_to_fill", render)
        self.assertIn("ld de,13", render)
        self.assertIn("ld hl,10", render)
        self.assertIn(
            "ld a,1\n        ld (panel_sunken),a\n"
            "        call s1_panel_mapped",
            render,
        )
        self.assertIn("call s1_panel_mapped", render)
        self.assertIn("WIN_TH_TEXT_DISABLED", render)
        self.assertIn("WIN_CH_FOCUS", render)
        self.assertIn("call nz,s6_draw_choice_focus", render)
        self.assertIn("s6_check_pixels:", STAGE6)
        self.assertIn("s6_radio_dot:", STAGE6)
        self.assertIn("s6_radio_corners:", STAGE6)
        self.assertIn("s6_radio_shadow:", STAGE6)
        self.assertIn("db #17,#12,#71,#21", STAGE6)
        self.assertIn("ld a,(bevel_top_color)", STAGE6)
        self.assertIn(
            "db #00,#10,#20,#70,#80,#90,#01,#91",
            STAGE6,
        )
        self.assertIn(
            "db #11,#81,#02,#92,#07,#97,#18,#88",
            STAGE6,
        )
        self.assertIn(
            "db #08,#98,#09,#19,#29,#79,#89,#99",
            STAGE6,
        )
        self.assertIn(
            "db #43,#53,#34,#44,#54,#64,#35,#45,#55,#65,#46,#56",
            STAGE6,
        )
        self.assertIn(
            "db #73,#64,#74,#25,#55,#65,#36,#46,#56,#47",
            STAGE6,
        )

    def test_mouse_keyboard_group_focus_and_dirty_paths_are_integrated(self) -> None:
        self.assertIn("call s6_validate_choice_item", STAGE3)
        self.assertIn("call s6_choice_enabled", STAGE3)
        self.assertIn("call s6_choice_click", STAGE3)
        self.assertIn("call s6_choice_key", STAGE4)
        self.assertIn("call s6_tab_accept", STAGE4)
        self.assertIn("xor b                         ; mismatch must return with CF clear", STAGE4)
        self.assertIn("WIN_T_CHECKBOX", STAGE2)
        self.assertIn("WIN_T_RADIOBUTTON", STAGE2)

        activation = STAGE6.split("s6_activate_loaded:", 1)[1].split(
            "s6_mark_item_dirty:", 1
        )[0]
        self.assertIn("xor WIN_CH_CHECKED", activation)
        self.assertIn("res 0,(hl)", activation)
        self.assertIn("set 0,(hl)", activation)
        self.assertIn("call s2_win_update", activation)
        self.assertIn("call s4_cursor_hide", activation)
        self.assertIn("call s4_cursor_show", activation)
        self.assertIn("WIN_EV_CHANGE", activation)

        key = STAGE6.split("s6_choice_key:", 1)[1].split(
            "; Tab hook", 1
        )[0]
        for scan in ("sub #52", "bit 0,a", "and 2"):
            self.assertIn(scan, key)
        tab = STAGE6.split("s6_tab_accept:", 1)[1].split(
            "s6_is_choice:", 1
        )[0]
        self.assertIn("s6_first_enabled", tab)
        self.assertIn("WIN_CH_CHECKED", tab)

    def test_overlay_has_four_images_and_hard_16k_assertion(self) -> None:
        layout = equates(ROOT / "win320_layout.inc")
        base = layout["S5_OVERLAY_OFFSET"]
        size = layout["S5_OVERLAY_CODE_SIZE"]
        self.assertEqual(0x4000, base + size)
        overlay = (ROOT / "build" / "stage5.overlay").read_bytes()
        self.assertEqual(4 * size, len(overlay))
        images = [overlay[index:index + size]
                  for index in range(0, len(overlay), size)]
        self.assertEqual(4, len(images))
        self.assertEqual(4, len(set(images)))
        overlay_source = (ROOT / "stage5_overlay.asm").read_text()
        self.assertIn(
            "assert S5_OVERLAY_OFFSET+S5_OVERLAY_CODE_SIZE == #4000",
            overlay_source,
        )
        self.assertIn(
            "assert $-(S5_OVERLAY_OFFSET+RELOC_DELTA) <= S5_OVERLAY_CODE_SIZE",
            overlay_source,
        )

    def test_stage6_z80_harness_covers_state_and_error_cases(self) -> None:
        for token in (
            "call win_checkbox", "call win_radiobutton", "call win_draw",
            "WIN_TXT_ASCIIZ", "WIN_TXT_PASCAL", "WIN_CH_DISABLED",
            "WIN_EV_CHANGE", "keys_space", "keys_choice_right",
            "keys_choice_left", "keys_tab", "keys_shift_tab",
            "WIN_IT_HIDDEN", "WIN_IT_DISABLED", "WIN_IT_DIRTY",
            "s2_update_count", "cp 2",
            "mock_hide_count", "mock_show_count", "choice_bad_flags",
            "choice_bad_group", "choice_bad_reserved", "choice_bad_geometry",
            "choice_bad_pointer",
        ):
            self.assertIn(token, HARNESS)
        runner = (ROOT / "tools" / "run_z80_tests.sh").read_text()
        self.assertIn("stage4 stage5 stage6", runner)

    def test_version_path_advertises_abi_11(self) -> None:
        version = ASM.split("win_get_version:", 1)[1].split(
            "win_get_config:", 1
        )[0]
        self.assertIn("ld d,1", version)
        self.assertIn("ld e,1", version)
        self.assertIn("WIN_CAP_CHECKBOX|WIN_CAP_RADIOBUTTON", version)

    def test_visual_showcase_has_two_groups_disabled_and_live_state(self) -> None:
        visual = (ROOT / "test.asm").read_text()
        stage6_calls = visual.split("run_stage6_showcase:", 1)[0]
        self.assertIn(
            "xor a\n        call run_stage6_showcase", stage6_calls
        )
        self.assertIn(
            "ld a,1\n        call run_stage6_showcase", stage6_calls
        )
        showcase = visual.split("run_stage6_showcase:", 1)[1].split(
            "; Load the two payload pages", 1
        )[0]
        for token in (
            "WIN_EV_CHANGE", "stage6_write_status",
            "WIN_UPDATE", "WIN_TRACK", "WIN_CH_DISABLED",
            "ld (stage6_screen),a", "ld a,(stage6_screen)",
        ):
            self.assertIn(token, showcase)
        self.assertIn(
            "ld a,1\n        ld (stage6_window+WIN_WND_FOCUS),a",
            showcase,
        )
        data = visual.split("; ---- Stage-6 checkbox/radio showcase", 1)[1]
        self.assertEqual(2, data.count("db WIN_T_CHECKBOX"))
        self.assertEqual(4, data.count("db WIN_T_RADIOBUTTON"))
        self.assertIn("db #ff,WIN_CH_CHECKED,1,0", data)
        self.assertIn("db #ff,WIN_CH_CHECKED,2,0", data)
        self.assertIn("WIN_TRK_TAB_FOCUS", data)
        self.assertIn('str_stage6_status: db "Check=0  Audio=A  View=1",0', data)


if __name__ == "__main__":
    unittest.main()
