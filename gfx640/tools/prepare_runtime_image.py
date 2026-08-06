#!/usr/bin/env python3
"""Decode and relocate a release L0 DLL into a Z80 harness memory image."""

from __future__ import annotations

import argparse
from pathlib import Path


def decompress_zero_rle(payload: bytes, expected: int) -> bytes:
    result = bytearray()
    position = 0
    while position < len(payload):
        value = payload[position]
        position += 1
        if value:
            result.append(value)
            continue
        if position >= len(payload):
            raise ValueError("truncated zero-RLE sequence")
        count = payload[position] or 256
        position += 1
        result.extend(b"\0" * count)
        if len(result) > expected:
            raise ValueError("zero-RLE expands past the declared DLL size")
    if len(result) != expected:
        raise ValueError(
            f"zero-RLE produced {len(result)} bytes, expected {expected}"
        )
    return bytes(result)


def decode_l0(path: Path) -> tuple[bytearray, bytes]:
    raw = path.read_bytes()
    if len(raw) < 32 or raw[:2] != b"L0":
        raise ValueError(f"{path}: not an L0 library")
    file_size = int.from_bytes(raw[2:4], "little")
    code_size = int.from_bytes(raw[4:6], "little")
    reloc_size = int.from_bytes(raw[6:8], "little")
    if code_size > 16 * 1024:
        raise ValueError(f"{path}: L0 code size {code_size} exceeds one 16-KiB window")
    expected = code_size + reloc_size
    if file_size != len(raw):
        raise ValueError(
            f"{path}: header file size {file_size} differs from {len(raw)}"
        )
    if file_size == expected:
        image = raw
    else:
        image = raw[:16] + decompress_zero_rle(raw[16:], expected - 16)
    checksum = int.from_bytes(image[8:10], "little")
    actual = sum(image[16:]) & 0xFFFF
    if checksum != actual:
        raise ValueError(
            f"{path}: checksum {checksum:04X} differs from {actual:04X}"
        )
    expected_reloc = (code_size + 7) // 8
    if reloc_size != expected_reloc:
        raise ValueError(
            f"{path}: relocation size {reloc_size}, expected {expected_reloc}"
        )
    return bytearray(image[:code_size]), image[code_size:]


def relocate(code: bytearray, bitmap: bytes, base: int) -> None:
    page = base >> 8
    for position in range(len(code)):
        if bitmap[position >> 3] & (0x80 >> (position & 7)):
            code[position] = (code[position] + page) & 0xFF


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dll", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--base", type=lambda value: int(value, 0), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    code, bitmap = decode_l0(args.dll)
    relocate(code, bitmap, args.base)
    template = args.template.read_bytes()
    if len(template) < args.base:
        raise ValueError("harness template ends before the DLL base")

    # Header metadata is intentionally rewritten by sprinter-mkdll. Everything
    # after it must match a direct link at the target address byte-for-byte.
    linked = template[args.base + 32 : min(len(template), args.base + len(code))]
    if code[32 : 32 + len(linked)] != linked:
        raise ValueError("relocated release DLL differs from direct-link harness")

    runtime = template[: args.base] + code
    args.output.write_bytes(runtime)


if __name__ == "__main__":
    main()
