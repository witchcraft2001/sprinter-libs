from __future__ import annotations

import hashlib
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FONT_TOOL = load_module(
    "font_to_accel", REPO / "afnt320" / "tools" / "font_to_accel.py"
)
ATTACH_TOOL = load_module("attach_payload", ROOT / "tools" / "attach_payload.py")


class FontPayloadTests(unittest.TestCase):
    def test_raw_converter_stays_byte_exact(self) -> None:
        source = (REPO / "afnt320" / "font.bin").read_bytes()
        raw, blank = FONT_TOOL.convert_font(source)
        self.assertEqual(10608, len(raw))
        self.assertEqual(308, blank)
        self.assertEqual(
            "6d28682e1920f19f109d4cc50dfbc8b4c656da6f6d08e1f7d6abcf77b63a7c52",
            hashlib.sha256(raw).hexdigest(),
        )

    def test_wf32_header_and_tables(self) -> None:
        source = (REPO / "afnt320" / "font.bin").read_bytes()
        raw, _ = FONT_TOOL.convert_font(source)
        wrapped = FONT_TOOL.wrap_wf32(raw)
        self.assertEqual(b"WF32", wrapped[:4])
        self.assertEqual((1, 8), tuple(wrapped[4:6]))
        self.assertEqual(len(raw), int.from_bytes(wrapped[6:8], "little"))
        self.assertEqual(raw, wrapped[8:])

        expected = 1024
        for glyph in range(256):
            width = raw[glyph]
            offset = raw[256 + glyph] | raw[512 + glyph] << 8
            columns = raw[768 + glyph]
            self.assertIn(width, range(1, 9))
            self.assertEqual(expected, offset)
            valid_mask = (0xFF << (8 - width)) & 0xFF
            self.assertEqual(0, columns & ~valid_mask)
            expected += columns.bit_count() * 8
        self.assertEqual(len(raw), expected)

    def test_release_has_exactly_one_embedded_payload(self) -> None:
        library = (ROOT / "build" / "WIN320.DLL").read_bytes()
        prefix_size = int.from_bytes(library[2:4], "little")
        payload = library[prefix_size:]
        self.assertEqual(b"WF32", payload[:4])
        self.assertEqual(8 + int.from_bytes(payload[6:8], "little"), len(payload))
        self.assertFalse((ROOT / "WIN320.FNT").exists())

    def test_attach_rejects_malformed_input(self) -> None:
        prefix = bytearray(16)
        prefix[:2] = b"L0"
        prefix[2:4] = (16).to_bytes(2, "little")
        with self.assertRaises(ValueError):
            ATTACH_TOOL.attach(bytes(prefix), b"bad")


if __name__ == "__main__":
    unittest.main()
