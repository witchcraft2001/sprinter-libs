from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
STAGE1 = (ROOT / "stage1.inc").read_text()
ASM = (ROOT / "win320.asm").read_text()
HARNESS = (ROOT / "tests" / "z80" / "t_stage1.asm").read_text()


class Stage1ContractTests(unittest.TestCase):
    def test_default_theme_and_ega_palette_are_complete(self) -> None:
        match = re.search(
            r"default_theme:\s*db\s+([^\n]+)\s*db\s+([^\n]+)", STAGE1
        )
        self.assertIsNotNone(match)
        tokens = ",".join(match.groups()).replace(" ", "").split(",")
        values = [int(token[1:], 16) if token.startswith("#") else int(token)
                  for token in tokens]
        self.assertEqual([15, 7, 8, 1, 0, 7, 15, 0,
                          1, 15, 7, 1, 7, 1, 15, 0], values)

        palette = STAGE1.split("s1_style_palette_mapped:", 1)[1].split(
            "; A=EGA colour index", 1
        )[0]
        for component in ("ld e,4", "ld e,2", "ld e,1"):
            self.assertIn(component, palette)
        self.assertEqual(3, palette.count("call s1_palette_component"))
        component = STAGE1.split("s1_palette_component:", 1)[1].split(
            "s1_style_clear_mapped:", 1
        )[0]
        for intensity in ("ld a,#80", "ld a,#c0", "ld a,#ff"):
            self.assertIn(intensity, component)

    def test_origin_bounds_use_full_width_arithmetic(self) -> None:
        rect = STAGE1.split("s1_load_rect:", 1)[1].split(
            "s1_require_frame_size:", 1
        )[0]
        for token in (
            "ld de,(origin_x)",
            "ld de,(rect_w)",
            "ld bc,320",
            "ld a,(origin_y)",
            "ld de,(rect_h)",
            "ld bc,256",
        ):
            self.assertIn(token, rect)
        self.assertEqual(2, rect.count("call s1_validate_axis_window"))
        self.assertGreaterEqual(rect.count("jr c,s1_rect_bad"), 4)

    def test_font_replacement_is_published_after_validation_and_close(self) -> None:
        loader = STAGE1.split("win_load_font:", 1)[1].split(
            "s1_read_wf32:", 1
        )[0]
        order = [
            "call s1_read_wf32",
            "ld c,DSS_CLOSE",
            "ld (font_page),a",
            "ld (font_block),a",
        ]
        position = 0
        for token in order:
            found = loader.find(token, position)
            self.assertNotEqual(-1, found, token)
            position = found + len(token)
        self.assertIn("call s1_release_temp_font", loader)

    def test_text_widths_are_read_from_the_mapped_wf32(self) -> None:
        self.assertNotIn("font_width_cache", ASM)
        cached = STAGE1.split("s1_cached_width:", 1)[1].split(
            "; Clip text_scratch", 1
        )[0]
        self.assertIn("WF32_HEADER_SIZE+FONT320_WIDTHS", cached)
        self.assertIn("ld bc,(work_base)", cached)

    def test_string_formats_share_one_bounded_scratch_path(self) -> None:
        copier = STAGE1.split("s1_copy_public_string:", 1)[1].split(
            "s1_validate_optional_range:", 1
        )[0]
        self.assertIn("ld b,#ff", copier)
        self.assertIn(".pascal:", copier)
        self.assertIn("ld de,text_scratch", copier)
        self.assertIn("ld (de),a", copier)

    def test_text_palette_rebuild_preserves_source_and_clip_stays_bounded(self) -> None:
        core = (REPO / "common" / "textcore320.inc").read_text()
        prepare = core.split("textcore_prepare_colors:", 1)[1].split(
            "textcore_fill_colour_buffer:", 1
        )[0]
        rebuild = prepare.split(".rebuild:", 1)[1]
        self.assertIn("push hl", rebuild)
        self.assertIn("pop hl", rebuild)

        clip = STAGE1.split("s1_clip_text:", 1)[1].split(
            "s1_resolve_text_attr:", 1
        )[0]
        self.assertIn("ld (text_scratch+253),a", clip)

    def test_clip_and_button_minimums_are_locked_by_z80_tests(self) -> None:
        self.assertIn("dw 1,255,256,257,320", HARNESS)
        self.assertIn("call win_invert_rect", HARNESS)
        self.assertGreaterEqual(HARNESS.count("call win_invert_rect"), 2)
        self.assertIn("ld de,6", STAGE1)
        self.assertIn("ld de,10", STAGE1)
        self.assertIn("call s1_clip_text", STAGE1)
        self.assertIn("are adjacent at y=20 and y=21", HARNESS)

    def test_fill_row_cursor_does_not_modify_line_helper_coordinates(self) -> None:
        fill = STAGE1.split("s1_fill_mapped:", 1)[1].split(
            "; Draw one horizontal line", 1
        )[0]
        self.assertIn("fill_current_y", fill)
        self.assertNotIn("ld (line_y),a", fill)
        choose = fill.split(".choose:", 1)[1].split(".vertical:", 1)[0]
        self.assertIn("ld hl,(fill_w)\n        dec hl", choose)
        self.assertNotIn("ld de,(fill_h)", choose)

    def test_mapping_restores_vram_then_data_and_port_y(self) -> None:
        unmap = STAGE1.split("s1_unmap_pair:", 1)[1].split(
            "; ---- geometry validation", 1
        )[0]
        sequence = [
            "ld a,#c0",
            "out (YPORT),a",
            "ld a,(saved_vram_page)",
            "ld a,(saved_data_page)",
            "jp s1_restore_iff",
        ]
        position = 0
        for token in sequence:
            found = unmap.find(token, position)
            self.assertNotEqual(-1, found, token)
            position = found + len(token)

    def test_production_accelerator_sequences_end_idle(self) -> None:
        hfill = STAGE1.split("s1_hfill_chunk:", 1)[1].split(
            "; HL=x address", 1
        )[0]
        self.assertRegex(
            hfill,
            r"ld d,d\s+s1_hfill_size:\s+ld a,0\s+ld c,c"
            r"\s+ld a,c\s+ld \(hl\),a\s+ld b,b",
        )

        xor = STAGE1.split("s1_xor_chunk:", 1)[1].split(
            "s1_invert_mapped:", 1
        )[0]
        self.assertRegex(
            xor,
            r"ld l,l\s+ld a,\(de\)\s+xor \(hl\)"
            r"\s+ld \(hl\),a\s+ld b,b",
        )


if __name__ == "__main__":
    unittest.main()
