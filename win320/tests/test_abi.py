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
    def test_stage0_entries_and_frozen_table(self) -> None:
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
        self.assertTrue(all(label == "win_reserved" for label, _ in dispatch[6:]))

    def test_error_and_config_layout(self) -> None:
        values = equates()
        self.assertEqual(0x20, values["WIN_ERR_ARGUMENT"])
        self.assertEqual(0x25, values["WIN_ERR_UNSUPPORTED"])
        self.assertEqual(0x28, values["WIN_ERR_MEMORY"])
        self.assertEqual(20, values["WIN_CONFIG_SIZE"])
        self.assertEqual(0, values["WIN_CFG_STRUCT_SIZE"])
        self.assertEqual(14, values["WIN_CFG_FONT_PAGE"])
        self.assertEqual(19, values["WIN_CFG_TEXT_FORMAT"])

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


if __name__ == "__main__":
    unittest.main()
