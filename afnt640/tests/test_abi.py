from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def equates() -> dict[str, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^([A-Z0-9_]+)\s+equ\s+([#0-9a-fA-F]+)", re.I)
    for line in (ROOT / "afnt640.inc").read_text().splitlines():
        match = pattern.match(line)
        if match:
            token = match.group(2)
            values[match.group(1)] = int(token[1:], 16) if token.startswith("#") else int(token)
    return values


def decode_code(path: Path) -> bytes:
    raw = path.read_bytes()
    code_size = int.from_bytes(raw[4:6], "little")
    reloc_size = int.from_bytes(raw[6:8], "little")
    expected = code_size + reloc_size
    if len(raw) == expected:
        return raw[:code_size]
    image = bytearray(raw[:16])
    pos = 16
    while pos < len(raw):
        value = raw[pos]
        pos += 1
        if value:
            image.append(value)
        else:
            count = raw[pos] or 256
            pos += 1
            image.extend(bytes(count))
    if len(image) != expected:
        raise AssertionError((len(image), expected))
    return bytes(image[:code_size])


class AbiTests(unittest.TestCase):
    def test_public_constants(self) -> None:
        values = equates()
        self.assertEqual([0, 1, 2, 3, 4, 5], [values[f"AFNT640_{name}"] for name in (
            "INIT", "FREE", "FNSTYLE", "APRINT", "SET_WINDOW", "SET_TARGET")])
        self.assertEqual([0, 1, 2, 3], [values[f"AFNT640_TARGET_{name}"] for name in (
            "BUF0", "BUF1", "FRONT", "BACK")])
        self.assertEqual(0x10, values["AFNT640_ERR_ARGUMENT"])
        self.assertEqual(0x12, values["AFNT640_ERR_WINDOW"])

    def test_l0_version_and_entry_offsets(self) -> None:
        raw = (ROOT / "build/AFNT640.DLL").read_bytes()
        self.assertEqual(b"L0", raw[:2])
        self.assertEqual(0x0105, int.from_bytes(raw[14:16], "little"))
        code = decode_code(ROOT / "build/AFNT640.DLL")
        self.assertEqual(bytes([0xC3]) * 6, bytes(code[32 + 3 * i] for i in range(6)))

    def test_shared_target_and_runtime_are_used(self) -> None:
        source = (ROOT / "afnt640.asm").read_text()
        self.assertIn('INCLUDE\t"../common/afnt_target.inc"', source)
        self.assertIn('INCLUDE\t"../common/afnt_runtime.inc"', source)
        self.assertRegex(source, r"LD\s+A,B\s+AND\s+1\s+LD\s+\(screen_id\),A")
        self.assertNotRegex(source, r"(?m)^\s*EI\s*$")
        self.assertIn("CALL\tafnt_leave_di", source)
        self.assertGreaterEqual(source.count("LD\tA,0xC0\n\t\t\tOUT\t(YPORT),A"), 2)


if __name__ == "__main__":
    unittest.main()
