from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.tilepack import (
    IndexedImage,
    extract_tiles,
    make_metatile_groups,
    make_nonempty_rows,
    make_refs,
    pack_pages,
    write_package,
)


def fixture(width: int, height: int, *, keyed: bool = False) -> IndexedImage:
    pixels = bytes((x + y * width) & 0x0F for y in range(height) for x in range(width))
    palette = bytes(index & 0xFF for index in range(768))
    return IndexedImage(width, height, pixels, palette, keyed)


class TilepackTests(unittest.TestCase):
    def test_high_low_nibble_and_row_major_tile_order(self) -> None:
        image = fixture(64, 16)
        tiles = extract_tiles(image)
        self.assertEqual(2, len(tiles))
        self.assertEqual(0x01, tiles[0][0])
        self.assertEqual(0xEF, tiles[0][15])
        self.assertEqual(0x01, tiles[1][0])
        self.assertEqual(0x01, tiles[0][16])
        self.assertEqual(256, len(tiles[0]))

    def test_vertical_tile_order(self) -> None:
        pixels = bytearray(32 * 32)
        pixels[16 * 32 :] = bytes([3]) * (16 * 32)
        image = IndexedImage(32, 32, bytes(pixels), bytes(768))
        tiles = extract_tiles(image)
        self.assertEqual(2, len(tiles))
        self.assertEqual(bytes([0x00]) * 256, tiles[0])
        self.assertEqual(bytes([0x33]) * 256, tiles[1])

    def test_pages_and_refs_are_exact(self) -> None:
        tiles = [bytes([index]) * 256 for index in range(65)]
        pages = pack_pages(tiles, 0xFF)
        self.assertEqual([16384, 16384], [len(page) for page in pages])
        self.assertEqual(bytes([64]) * 256, pages[1][:256])
        self.assertEqual(bytes([0xFF]) * 256, pages[1][256:512])
        refs = make_refs(65)
        self.assertEqual(b"\x00\x00", refs[:2])
        self.assertEqual(b"\x3f\x00", refs[126:128])
        self.assertEqual(b"\x00\x01", refs[128:130])

    def test_nonempty_row_mask_is_16_bit(self) -> None:
        tile = bytearray([0xFF] * 256)
        tile[0] = 1
        tile[15 * 16] = 2
        self.assertEqual(b"\x01\x80", make_nonempty_rows([bytes(tile)]))
        self.assertEqual(b"\xff\xff", make_nonempty_rows([bytes(tile)], None))

    def test_keyed_pairs_accept_single_pixel_transparency(self) -> None:
        pixels = bytearray([1] * (32 * 16))
        pixels[0:2] = b"\x0f\x0f"
        pixels[2:4] = b"\x0f\x01"
        pixels[4:6] = b"\x02\x0f"
        image = IndexedImage(32, 16, bytes(pixels), bytes(768), True)
        self.assertEqual(0xFF, extract_tiles(image)[0][0])
        self.assertEqual(0xF1, extract_tiles(image)[0][1])
        self.assertEqual(0x2F, extract_tiles(image)[0][2])
        opaque = IndexedImage(32, 16, bytes(pixels), bytes(768), False)
        self.assertEqual(bytes([0xFF, 0xF1, 0x2F]), extract_tiles(opaque)[0][:3])

    def test_rejects_indices_above_15(self) -> None:
        pixels = bytearray([0] * (32 * 16))
        pixels[-1] = 16
        with self.assertRaisesRegex(ValueError, "0..15"):
            extract_tiles(IndexedImage(32, 16, bytes(pixels), bytes(768)))

    def test_package_manifest_and_metatiles(self) -> None:
        image = fixture(64, 32)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            manifest = write_package(
                image,
                output,
                keyed=False,
                emit_masks=True,
                metatile_width=2,
                metatile_height=2,
            )
            self.assertEqual(4, manifest["tile_count"])
            self.assertEqual(32, manifest["tile_width"])
            self.assertEqual(16, manifest["tile_height"])
            self.assertEqual(16384, (output / "page00.bin").stat().st_size)
            self.assertEqual(768, (output / "palette.rgb").stat().st_size)
            self.assertEqual(8, (output / "nonempty_rows.bin").stat().st_size)
            self.assertEqual([[0, 1, 2, 3]], json.loads((output / "metatiles.json").read_text()))

    def test_rejects_non_tile_dimensions(self) -> None:
        with self.assertRaises(ValueError):
            extract_tiles(fixture(32, 8))
        with self.assertRaises(ValueError):
            extract_tiles(fixture(33, 16))

    def test_metatile_divisibility(self) -> None:
        with self.assertRaises(ValueError):
            make_metatile_groups(make_refs(6), 3, 2, 2, 2)
        with self.assertRaises(ValueError):
            make_metatile_groups(make_refs(4), 2, 2, 2, 0)


if __name__ == "__main__":
    unittest.main()
