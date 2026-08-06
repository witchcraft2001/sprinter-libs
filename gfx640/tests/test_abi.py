from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def equates() -> dict[str, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^([A-Z0-9_]+)\s+equ\s+([#0-9a-fA-F]+)")
    for line in (ROOT / "gfx640.inc").read_text().splitlines():
        match = pattern.match(line)
        if not match:
            continue
        token = match.group(2)
        values[match.group(1)] = int(token[1:], 16) if token.startswith("#") else int(token)
    return values


class AbiTests(unittest.TestCase):
    def test_fill_size_uses_operand_fetch(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        horizontal = source.split("hfill_chunk:", 1)[1].split(
            "vfill_chunk:", 1
        )[0]
        sequence = [
            "ld (hfill_size+1),a",
            "ld d,d",
            "hfill_size:",
            "ld a,0",
            "ld c,c",
            "ld a,c",
            "ld (hl),a",
            "ld b,b",
        ]
        position = 0
        for instruction in sequence:
            next_position = horizontal.find(instruction, position)
            self.assertNotEqual(-1, next_position, instruction)
            position = next_position + len(instruction)

        vertical = source.split("vfill_chunk:", 1)[1].split(
            "gfx_clear:", 1
        )[0]
        self.assertIn("ld (vfill_size+1),a", vertical)
        self.assertIn("vfill_size:", vertical)
        self.assertIn("ld a,0", vertical)

        clear = source.split("clear_mapped:", 1)[1].split(
            "gfx_clear_key:", 1
        )[0]
        self.assertIn("ld d,d", clear)
        self.assertIn("ld a,0", clear)
        self.assertNotIn("xor a                     ; count=0", clear)

    def test_copy_and_tile_sizes_use_immediate_operands(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        direct = source.split("copy_direct_chunk:", 1)[1].split(
            "copy_cpu_row:", 1
        )[0]
        self.assertIn("ld (copy_direct_size+1),a", direct)
        self.assertRegex(
            direct,
            r"ACC_SET_SIZE\s+copy_direct_size:\s+ld a,0\s+ACC_COPY_H",
        )

        cpu = source.split("copy_cpu_chunk:", 1)[1].split(
            "; ---- additional primitives", 1
        )[0]
        self.assertIn("ld (copy_cpu_size+1),a", cpu)
        self.assertRegex(
            cpu,
            r"ACC_SET_SIZE\s+copy_cpu_size:\s+ld a,0\s+ACC_COPY_H",
        )

        tile = source.split("draw_tile_sized_target_ready:", 1)[1].split(
            "; Span descriptor:", 1
        )[0]
        self.assertIn("ld (.copy_size+1),a", tile)
        self.assertRegex(
            tile,
            r"ld d,d\s+\.copy_size:\s+ld a,8\s+ld l,l",
        )

    def test_config_is_mode_82_packed_4bpp(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        payload = source.split("config_payload:", 1)[1]
        self.assertRegex(payload, r"db #82[^\n]*\n\s*dw 640,256")
        self.assertRegex(payload, r"db 16,32")
        self.assertIn("row_buffer:     ds 320", source)
        self.assertLessEqual((ROOT / "GFX640.DLL").stat().st_size, 16384)
        runtime_tool = (ROOT / "tools" / "prepare_runtime_image.py").read_text()
        self.assertIn("code_size > 16 * 1024", runtime_tool)

    def test_length_flags_use_low_10_bits(self) -> None:
        values = equates()
        self.assertEqual(0x03FF, values["GFX_LENGTH_MASK"])
        self.assertEqual(0x3C00, values["GFX_LENGTH_FLAGS_MASK"])
        self.assertEqual(10, values["GFX_LENGTH_FLAGS_SHIFT"])
        for length in (0, 1, 639, 640, 1023):
            for flags in range(16):
                packed = length | (flags << values["GFX_LENGTH_FLAGS_SHIFT"])
                self.assertEqual(length, packed & values["GFX_LENGTH_MASK"])
                self.assertEqual(flags, (packed & values["GFX_LENGTH_FLAGS_MASK"]) >> 10)

    def test_nibble_and_alignment_paths_are_explicit(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        pixel = source.split("pixel_write_mapped:", 1)[1].split(
            "; A=0 when either extent", 1
        )[0]
        self.assertIn("and #0f", pixel)
        self.assertIn("and #f0", pixel)
        self.assertIn("srl h\n        rr l", pixel)
        self.assertIn("validate_rect_alignment:", source)
        self.assertIn("validate_copy_alignment:", source)
        self.assertIn("bit 0,a", source)

    def test_keyed_colour_15_pixel_returns_success(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        pixel = source.split("gfx_put_pixel:", 1)[1].split(
            "; IX=x, IYH=0, IYL=y, E=source", 1
        )[0]
        self.assertRegex(
            pixel,
            r"bit 3,a\s+jr z,\.map\s+ld a,\(pixel_color\)\s+cp 15\s+"
            r"jr nz,\.map\s+xor a\s+; KEY_FF colour 15 is a successful no-op\s+ret",
        )

    def test_window_restore_sequence_is_shared_and_complete(self) -> None:
        source = (ROOT.parent / "common" / "winmgr.inc").read_text()
        unmap = source.split("unmap_vram:", 1)[1]
        self.assertRegex(
            unmap,
            r"ld a,\(saved_vram_page\)\s+out \(c\),a\s+"
            r"ld a,#c0\s+out \(YPORT\),a",
        )
        tile = (ROOT / "gfx640.asm").read_text().split(
            "draw_tile_sized_target_ready:", 1
        )[1].split("; Span descriptor:", 1)[0]
        self.assertRegex(
            tile,
            r"call unmap_vram\s+ld a,\(saved_win0_page\)\s+"
            r"out \(PAGEPORT0\),a\s+call leave_di",
        )

    def test_tile_geometry_and_page_layout(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        tile = source.split("draw_tile_sized_target_ready:", 1)[1].split(
            "; Span descriptor:", 1
        )[0]
        self.assertIn("ld a,8", tile)
        self.assertIn("add a,8", tile)
        self.assertIn("ld a,32", source.split("draw_tile_target_ready:", 1)[1][:160])
        self.assertIn("ld de,625", source)
        self.assertIn("add a,32", source)

    def test_entry_numbers_are_frozen(self) -> None:
        values = equates()
        expected = {
            "GFX_INIT": 0,
            "GFX_COPY_RECT": 10,
            "GFX_PALETTE_LOAD256": 13,
            "GFX_FADE_BEGIN": 16,
            "GFX_SWAP_BUFFERS": 21,
            "GFX_DRAW_TILEMAP": 26,
            "GFX_SCROLL_RECT": 33,
            "GFX_DRAW_TILE_LIST": 34,
            "GFX_DRAW_TILE_CLIP": 35,
        }
        self.assertEqual(expected, {name: values[name] for name in expected})

    def test_descriptor_sizes(self) -> None:
        values = equates()
        self.assertEqual(12, values["GFX_FILL_RECT_SIZE"])
        self.assertEqual(12, values["GFX_COPY_RECT_SIZE"])
        self.assertEqual(8, values["GFX_RESTORE_RECT_SIZE"])
        self.assertEqual(8, values["GFX_TILE_SPAN_SIZE"])
        self.assertEqual(8, values["GFX_TILE_LIST_SIZE"])
        self.assertEqual(20, values["GFX_TILEMAP_SIZE"])
        self.assertEqual(8, values["GFX_METATILE_SIZE"])
        self.assertEqual(8, values["GFX_LINE_SIZE"])
        self.assertEqual(16, values["GFX_SCROLL_RECT_SIZE"])

    def test_dispatch_table_has_all_entries(self) -> None:
        source = (ROOT / "gfx640.asm").read_text()
        dispatch = re.findall(r"^\s+jp\s+([a-zA-Z0-9_]+)\s+;\s*(\d+)", source, re.MULTILINE)
        self.assertEqual(list(range(36)), [int(number) for _, number in dispatch[:36]])
        reserved = {int(number) for label, number in dispatch[:36] if label == "gfx_reserved"}
        self.assertEqual({3, 19, 20}, reserved)

    def test_fade_accumulator_reaches_exact_endpoints(self) -> None:
        for duration in range(1, 256):
            accumulator = 0
            progress = 0
            for _ in range(duration):
                accumulator += 32
                while accumulator >= duration:
                    accumulator -= duration
                    progress += 1
            self.assertEqual(32, progress, duration)
            self.assertEqual(0, accumulator, duration)

    def test_fade_lut_rounding(self) -> None:
        for level in range(33):
            quotient = 0
            remainder = 16
            actual: list[int] = []
            for _ in range(256):
                actual.append(quotient)
                remainder += level
                if remainder >= 32:
                    remainder -= 32
                    quotient += 1
            expected = [(component * level + 16) // 32 for component in range(256)]
            self.assertEqual(expected, actual)


if __name__ == "__main__":
    unittest.main()
