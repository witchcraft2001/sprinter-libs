#!/usr/bin/env python3
"""Convert the compact gfxview font to accelerator-friendly columns."""

from pathlib import Path
import argparse


def convert_font(source: bytes) -> tuple[bytes, int]:
    if len(source) != 256 + 8 * 256:
        raise SystemExit(f"expected a 2304-byte gfxview font, got {len(source)}")

    widths = source[:256]
    if any(width < 1 or width > 8 for width in widths):
        raise SystemExit("every glyph width must be in the range 1..8")

    offsets: list[int] = []
    column_maps = bytearray()
    bitmap = bytearray()
    bitmap_base = 4 * 256
    blank_columns = 0

    for char, width in enumerate(widths):
        offsets.append(bitmap_base + len(bitmap))
        column_map = 0
        for column in range(width):
            mask = 0x80 >> column
            pixels = bytearray()
            for row in range(8):
                packed = source[256 + row * 256 + char]
                pixels.append(0xFF if packed & mask else 0x00)
            if any(pixels):
                column_map |= mask
                bitmap.extend(pixels)
            else:
                blank_columns += 1
        column_maps.append(column_map)

    if bitmap_base + len(bitmap) >= 0x10000:
        raise SystemExit("converted font offsets do not fit in 16 bits")

    result = bytearray(widths)
    result.extend(offset & 0xFF for offset in offsets)
    result.extend(offset >> 8 for offset in offsets)
    result.extend(column_maps)
    result.extend(bitmap)
    return bytes(result), blank_columns


def wrap_wf32(data: bytes) -> bytes:
    if len(data) > 0x3FF8:
        raise SystemExit("WF32 data does not fit in one 16K page")
    return b"WF32" + bytes((1, 8)) + len(data).to_bytes(2, "little") + data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wf32", action="store_true")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    data, blank_columns = convert_font(args.input.read_bytes())
    result = wrap_wf32(data) if args.wf32 else data
    args.output.write_bytes(result)
    print(
        f"created {args.output}: {len(result)} bytes, "
        f"{len(data) - 1024} bytes of column masks, "
        f"{blank_columns} blank columns elided"
    )


if __name__ == "__main__":
    main()
