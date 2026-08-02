from __future__ import annotations

import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.winiconpack import (
    IconCell,
    IndexedImage,
    extract_cells,
    load_index_map,
    pack_wip,
    parse_asset,
    write_package,
)


class WinIconPackTests(unittest.TestCase):
    def test_tracked_showcase_pack_matches_wip1_contract(self) -> None:
        package = (Path(__file__).parents[1] / "examples" / "icons.wip").read_bytes()
        magic, version, page_count, header_size = struct.unpack("<4sBBH", package[:8])
        self.assertEqual((b"WIP1", 1, 2, 12), (
            magic, version, page_count, header_size
        ))
        self.assertEqual(bytes((8, 2, 16, 2)), package[8:12])
        self.assertEqual(12 + 2 * 16384, len(package))
        self.assertTrue(all(value == 0xFF for value in package[12 + 128:12 + 16384]))

    def test_sprite_sheet_is_cut_row_major(self) -> None:
        pixels = bytes(range(16 * 8))
        cells = extract_cells("marker", 8, IndexedImage(16, 8, pixels))
        self.assertEqual(["marker_000", "marker_001"], [cell.name for cell in cells])
        self.assertEqual(pixels[:8], cells[0].pixels[:8])
        self.assertEqual(pixels[8:16], cells[1].pixels[:8])
        self.assertEqual(pixels[16:24], cells[0].pixels[8:16])

    def test_wip_header_pages_padding_and_refs_are_exact(self) -> None:
        cells = [IconCell(f"small_{index}", 8, bytes([index & 0xFF]) * 64)
                 for index in range(257)]
        cells.append(IconCell("large", 16, bytes([0x55]) * 256))
        package, refs = pack_wip(cells)
        magic, version, page_count, header_size = struct.unpack("<4sBBH", package[:8])
        self.assertEqual(b"WIP1", magic)
        self.assertEqual(1, version)
        self.assertEqual(3, page_count)
        self.assertEqual(14, header_size)
        self.assertEqual(bytes((8, 0, 8, 1, 16, 1)), package[8:14])
        self.assertEqual((0, 255, 8), (
            refs["small_255"].pack_page,
            refs["small_255"].slot,
            refs["small_255"].size,
        ))
        self.assertEqual((1, 0, 8), (
            refs["small_256"].pack_page,
            refs["small_256"].slot,
            refs["small_256"].size,
        ))
        self.assertEqual((2, 0, 16), (
            refs["large"].pack_page,
            refs["large"].slot,
            refs["large"].size,
        ))
        second_page = header_size + 16384
        self.assertEqual(bytes([0]) * 64, package[second_page:second_page + 64])
        self.assertEqual(0xFF, package[second_page + 64])

    def test_manifests_share_the_same_triplets(self) -> None:
        cells = [IconCell("open", 16, bytes(range(256)))]
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "icons.wip"
            refs = write_package(cells, output, prefix="APP_ICON")
            manifest = json.loads(output.with_suffix(".json").read_text())
            self.assertEqual(
                {"pack_page": 0, "slot": 0, "size": 16},
                manifest["assets"]["open"],
            )
            self.assertIn("APP_ICON_OPEN_PAGE equ 0", output.with_suffix(".inc").read_text())
            self.assertIn("{ 0, 0, 16 }", output.with_suffix(".h").read_text())
            self.assertIn("APP_ICON_OPEN_SIZE = 16", output.with_suffix(".pas").read_text())
            self.assertEqual(0, refs["open"].pack_page)

    def test_rejects_ambiguous_or_malformed_inputs(self) -> None:
        with self.assertRaises(ValueError):
            extract_cells("bad", 8, IndexedImage(9, 8, bytes(72)))
        with self.assertRaises(ValueError):
            pack_wip([
                IconCell("same", 8, bytes(64)),
                IconCell("SAME", 8, bytes(64)),
            ])
        with tempfile.TemporaryDirectory() as directory:
            index_map = Path(directory) / "bad.json"
            index_map.write_text("[0, 1]")
            with self.assertRaises(ValueError):
                load_index_map(index_map)
        with self.assertRaises(Exception):
            parse_asset("broken")


if __name__ == "__main__":
    unittest.main()
