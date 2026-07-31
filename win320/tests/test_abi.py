from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def equates() -> dict[str, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^([A-Z0-9_]+)\s+equ\s+([#0-9a-fA-F]+)")
    for line in (ROOT / "win320.inc").read_text().splitlines():
        match = pattern.match(line)
        if not match:
            continue
        token = match.group(2)
        values[match.group(1)] = (
            int(token[1:], 16) if token.startswith("#") else int(token)
        )
    return values


class AbiTests(unittest.TestCase):
    def test_stage3_entries_and_frozen_table(self) -> None:
        values = equates()
        self.assertEqual(0, values["WIN_INIT"])
        self.assertEqual(5, values["WIN_GET_CONFIG"])
        self.assertEqual(17, values["WIN_LABEL"])
        self.assertEqual(36, values["WIN_LISTBOX_DRAW"])
        self.assertEqual(37, values["WIN_ENTRY_COUNT"])

        source = (ROOT / "win320.asm").read_text()
        dispatch = re.findall(
            r"^\s+jp\s+([a-zA-Z0-9_]+)\s+;\s*(\d+)", source, re.MULTILINE
        )
        self.assertEqual(list(range(37)), [int(number) for _, number in dispatch])
        expected_stage1 = [
            "win_load_font",
            "win_set_theme",
            "win_set_text_format",
            "win_set_origin",
            "win_style",
            "win_fill_rect",
            "win_frame",
            "win_panel",
            "win_separator",
            "win_invert_rect",
            "win_focus_rect",
            "win_label",
            "win_button",
        ]
        self.assertEqual(expected_stage1, [label for label, _ in dispatch[6:19]])
        expected_stage2 = [
            "win_draw",
            "win_draw_item",
            "win_update",
            "win_set_backstore",
            "win_open",
            "win_close",
        ]
        self.assertEqual(expected_stage2, [label for label, _ in dispatch[19:25]])
        self.assertEqual(
            ["win_poll", "win_track", "win_wait_release", "win_set_cursor"],
            [label for label, _ in dispatch[25:29]],
        )
        self.assertTrue(all(label == "win_reserved" for label, _ in dispatch[29:]))

    def test_error_and_config_layout(self) -> None:
        values = equates()
        self.assertEqual(0x20, values["WIN_ERR_ARGUMENT"])
        self.assertEqual(0x25, values["WIN_ERR_UNSUPPORTED"])
        self.assertEqual(0x28, values["WIN_ERR_MEMORY"])
        self.assertEqual(20, values["WIN_CONFIG_SIZE"])
        self.assertEqual(0, values["WIN_CFG_STRUCT_SIZE"])
        self.assertEqual(14, values["WIN_CFG_FONT_PAGE"])
        self.assertEqual(19, values["WIN_CFG_TEXT_FORMAT"])

    def test_stage1_structure_layout_and_flags(self) -> None:
        values = equates()
        self.assertEqual(16, values["WIN_THEME_SIZE"])
        self.assertEqual(14, values["WIN_TH_FOCUS_MASK"])
        self.assertEqual(15, values["WIN_TH_RESERVED"])

        self.assertEqual(10, values["WIN_RECT_SIZE"])
        self.assertEqual(0, values["WIN_RC_X"])
        self.assertEqual(8, values["WIN_RC_COLOR"])
        self.assertEqual(9, values["WIN_RC_FLAGS"])
        self.assertEqual(0x01, values["WIN_RC_SUNKEN"])
        self.assertEqual(0x02, values["WIN_RC_VERTICAL"])

        self.assertEqual(12, values["WIN_LABEL_SIZE"])
        self.assertEqual(10, values["WIN_LBL_TEXT"])
        self.assertEqual(0x03, values["WIN_LABEL_ALIGN_MASK"])
        self.assertEqual(0x04, values["WIN_LABEL_FILL"])
        self.assertEqual(0x08, values["WIN_LABEL_CLIP"])

        self.assertEqual(12, values["WIN_BUTTON_SIZE"])
        self.assertEqual(10, values["WIN_BTN_TEXT"])
        self.assertEqual(0x01, values["WIN_BTN_GLYPH"])
        self.assertEqual(0x02, values["WIN_BTN_FOCUS"])
        self.assertEqual(0x04, values["WIN_BTN_PRESSED"])
        self.assertEqual(0x08, values["WIN_BTN_DISABLED"])

        self.assertEqual(0x01, values["WIN_STYLE_PALETTE"])
        self.assertEqual(0x02, values["WIN_STYLE_CLEAR"])
        self.assertEqual(0x04, values["WIN_STYLE_BOTH"])

    def test_stage2_structure_layout_types_flags_and_limits(self) -> None:
        values = equates()
        self.assertEqual(16, values["WIN_WINDOW_SIZE"])
        self.assertEqual(0, values["WIN_WND_X"])
        self.assertEqual(8, values["WIN_WND_COLOR"])
        self.assertEqual(10, values["WIN_WND_COUNT"])
        self.assertEqual(12, values["WIN_WND_ITEMS"])
        self.assertEqual(14, values["WIN_WND_LAST_FOCUS"])
        self.assertEqual(15, values["WIN_WND_RESERVED"])
        self.assertEqual(0x01, values["WIN_WND_NOPANEL"])
        self.assertEqual(0x02, values["WIN_WND_SUNKEN"])

        self.assertEqual(8, values["WIN_ITEM_SIZE"])
        self.assertEqual(0, values["WIN_ITEM_TYPE"])
        self.assertEqual(1, values["WIN_ITEM_FLAGS"])
        self.assertEqual(4, values["WIN_ITEM_CONTROL"])
        self.assertEqual(6, values["WIN_ITEM_USER_DATA"])
        self.assertEqual(list(range(13)), [
            values[name] for name in (
                "WIN_T_NONE", "WIN_T_LABEL", "WIN_T_FILL", "WIN_T_FRAME",
                "WIN_T_PANEL", "WIN_T_SEPARATOR", "WIN_T_BUTTON", "WIN_T_ICON",
                "WIN_T_PROGRESS", "WIN_T_SCROLLBAR", "WIN_T_LISTBOX",
                "WIN_T_EDIT", "WIN_T_ZONE",
            )
        ])
        self.assertEqual(
            [1 << bit for bit in range(8)],
            [values[name] for name in (
                "WIN_IT_DIRTY", "WIN_IT_HIDDEN", "WIN_IT_DISABLED",
                "WIN_IT_HIT", "WIN_IT_FOCUSABLE", "WIN_IT_PRESS",
                "WIN_IT_REPEAT", "WIN_IT_HOVER",
            )],
        )
        self.assertEqual(4, values["WIN_BACKSTORE_MAX_PAGES"])
        self.assertEqual(4, values["WIN_BACKSTORE_MAX_DEPTH"])
        self.assertEqual(256, values["WIN_BACKSTORE_CHUNK"])

    def test_window_detection_masks_address(self) -> None:
        source = (ROOT / "win320.asm").read_text()
        init = source.split("win_init:", 1)[1].split("win_free:", 1)[0]
        sequence = ["ld hl,win_init", "and #c0", "rlca", "rlca", "ld (code_window),a"]
        position = 0
        for text in sequence:
            found = init.find(text, position)
            self.assertNotEqual(-1, found, text)
            position = found + len(text)

    def test_mapping_does_not_wrap_dss_calls(self) -> None:
        source = (ROOT / "win320.asm").read_text()
        copy = source.split("copy_scratch_to_font:", 1)[1].split(
            "validate_loaded_font:", 1
        )[0]
        self.assertNotIn("win_dss_call", copy)
        sequence = [
            "ld d,d",
            "copy_stage_size:",
            "ld a,0",
            "ld b,b",
            "ld l,l",
            "ld a,(hl)",
            "ld (de),a",
            "ld b,b",
        ]
        position = 0
        for text in sequence:
            found = copy.find(text, position)
            self.assertNotEqual(-1, found, text)
            position = found + len(text)

    def test_afnt_uses_shared_core(self) -> None:
        source = (REPO / "afnt320" / "afnt320.asm").read_text()
        self.assertIn('INCLUDE\t"../common/textcore320.inc"', source)
        self.assertIn("CALL\ttextcore_draw_mapped", source)
        self.assertIn("LD\t(textcore_font_base),HL", source)

        core = (REPO / "common" / "textcore320.inc").read_text()
        self.assertIn("textcore_palette_base:", core)
        self.assertIn("or (hl)", core)

    def test_stage3_keeps_implementation_version_and_claims_core(self) -> None:
        source = (ROOT / "win320.asm").read_text()
        self.assertIn(
            "dw #0001                    ; implementation 0.1",
            source,
        )
        version = source.split("win_get_version:", 1)[1].split(
            "win_get_config:", 1
        )[0]
        self.assertIn("ld ix,WIN_CAP_CORE|WIN_CAP_PASCAL_STR", version)

    def test_stage3_event_abi_layout_and_constants(self) -> None:
        values = equates()
        self.assertEqual(4, values["WIN_KEY_SIZE"])
        self.assertEqual(32, values["WIN_TRACK_SIZE"])
        self.assertEqual(24, values["WIN_TRK_STATE"])
        self.assertEqual(4, values["WIN_CURSOR_SIZE"])
        self.assertEqual(12, values["WIN_REPEAT_DELAY"])
        self.assertEqual(3, values["WIN_REPEAT_RATE"])
        self.assertEqual(
            list(range(10)),
            [values[name] for name in (
                "WIN_EV_NONE", "WIN_EV_LCLICK", "WIN_EV_RCLICK",
                "WIN_EV_REPEAT", "WIN_EV_HOTKEY", "WIN_EV_KEY",
                "WIN_EV_HOVER", "WIN_EV_LEAVE", "WIN_EV_OUTSIDE",
                "WIN_EV_FOCUS",
            )],
        )


if __name__ == "__main__":
    unittest.main()
