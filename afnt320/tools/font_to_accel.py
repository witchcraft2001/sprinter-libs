#!/usr/bin/env python3
"""Convert the compact gfxview font to accelerator-friendly columns."""

from pathlib import Path
import sys


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: font_to_accel.py INPUT OUTPUT")

    source = Path(sys.argv[1]).read_bytes()
    if len(source) != 256 + 8 * 256:
        raise SystemExit(f"expected a 2304-byte gfxview font, got {len(source)}")

    widths = source[:256]
    if any(width < 1 or width > 8 for width in widths):
        raise SystemExit("every glyph width must be in the range 1..8")

    offsets: list[int] = []
    bitmap = bytearray()
    bitmap_base = 3 * 256

    for char, width in enumerate(widths):
        offsets.append(bitmap_base + len(bitmap))
        for column in range(width):
            mask = 0x80 >> column
            for row in range(8):
                packed = source[256 + row * 256 + char]
                bitmap.append(0xFF if packed & mask else 0x00)

    if bitmap_base + len(bitmap) >= 0x10000:
        raise SystemExit("converted font offsets do not fit in 16 bits")

    result = bytearray(widths)
    result.extend(offset & 0xFF for offset in offsets)
    result.extend(offset >> 8 for offset in offsets)
    result.extend(bitmap)
    Path(sys.argv[2]).write_bytes(result)

    print(
        f"created {sys.argv[2]}: {len(result)} bytes, "
        f"{len(bitmap)} bytes of column masks"
    )


if __name__ == "__main__":
    main()
