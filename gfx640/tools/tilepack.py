#!/usr/bin/env python3
"""Pack an indexed PNG/BMP into GFX640 packed-4bpp 16x32 tile pages."""

from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

TILE_WIDTH = 16
TILE_HEIGHT = 32
TILE_ROW_BYTES = TILE_WIDTH // 2
TILE_BYTES = TILE_ROW_BYTES * TILE_HEIGHT
PAGE_BYTES = 16 * 1024
TILES_PER_PAGE = PAGE_BYTES // TILE_BYTES
PALETTE_BYTES = 768
TRANSPARENT_COLOR = 15
TRANSPARENT_BYTE = 0xFF


@dataclass(frozen=True)
class IndexedImage:
    width: int
    height: int
    pixels: bytes
    palette: bytes
    keyed: bool = False


def _validate_indices(pixels: bytes) -> None:
    invalid = next((value for value in pixels if value > 15), None)
    if invalid is not None:
        raise ValueError(f"GFX640 pixels must use palette indices 0..15 (found {invalid})")


def load_indexed_image(path: Path, transparent_index: int | None) -> IndexedImage:
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError(
            "tilepack requires Pillow; install requirements-dev.txt"
        ) from exc

    with Image.open(path) as image:
        if image.mode != "P":
            raise ValueError("input must be an 8-bit indexed PNG/BMP (mode P)")
        width, height = image.size
        pixels = bytearray(image.tobytes())
        palette_list = image.getpalette() or []
        palette = bytearray(palette_list[:PALETTE_BYTES])
        palette.extend(b"\0" * (PALETTE_BYTES - len(palette)))
        source_transparency = image.info.get("transparency")

    if transparent_index is None and isinstance(source_transparency, int):
        transparent_index = source_transparency
    if transparent_index is not None:
        if not 0 <= transparent_index <= 15:
            raise ValueError("transparent index must be in range 0..15")
        if transparent_index != TRANSPARENT_COLOR:
            if TRANSPARENT_COLOR in pixels:
                raise ValueError(
                    "cannot remap transparency to color 15: input also uses index 15"
                )
            pixels = bytearray(
                TRANSPARENT_COLOR if value == transparent_index else value
                for value in pixels
            )
            source = transparent_index * 3
            palette[45:48] = palette[source : source + 3]

    _validate_indices(bytes(pixels))
    return IndexedImage(
        width, height, bytes(pixels), bytes(palette), transparent_index is not None
    )


def extract_tiles(image: IndexedImage, *, keyed: bool | None = None) -> list[bytes]:
    if image.width <= 0 or image.height <= 0:
        raise ValueError("image dimensions must be non-zero")
    if image.width % TILE_WIDTH or image.height % TILE_HEIGHT:
        raise ValueError("image dimensions must be multiples of 16x32")
    if len(image.pixels) != image.width * image.height:
        raise ValueError("pixel payload size does not match image dimensions")
    if len(image.palette) != PALETTE_BYTES:
        raise ValueError("palette must contain exactly 768 RGB8 bytes")
    _validate_indices(image.pixels)

    use_key = image.keyed if keyed is None else keyed
    tiles: list[bytes] = []
    for tile_y in range(0, image.height, TILE_HEIGHT):
        for tile_x in range(0, image.width, TILE_WIDTH):
            payload = bytearray()
            for row in range(TILE_HEIGHT):
                start = (tile_y + row) * image.width + tile_x
                source = image.pixels[start : start + TILE_WIDTH]
                for column in range(0, TILE_WIDTH, 2):
                    left, right = source[column], source[column + 1]
                    if use_key and ((left == TRANSPARENT_COLOR) != (right == TRANSPARENT_COLOR)):
                        raise ValueError(
                            "keyed assets cannot contain a single transparent pixel "
                            "inside a packed pair"
                        )
                    payload.append((left << 4) | right)
            assert len(payload) == TILE_BYTES
            tiles.append(bytes(payload))
    return tiles


def make_refs(tile_count: int) -> bytes:
    if tile_count > 256 * TILES_PER_PAGE:
        raise ValueError("GFX640 TileRef supports at most 256 logical pages")
    refs = bytearray()
    for tile_number in range(tile_count):
        page, slot = divmod(tile_number, TILES_PER_PAGE)
        refs.extend(struct.pack("<BB", slot, page))
    return bytes(refs)


def pack_pages(tiles: Sequence[bytes], pad_value: int) -> list[bytes]:
    if not 0 <= pad_value <= 255:
        raise ValueError("padding byte must be in range 0..255")
    for tile in tiles:
        if len(tile) != TILE_BYTES:
            raise ValueError("every tile must contain exactly 256 bytes")
    page_count = max(1, (len(tiles) + TILES_PER_PAGE - 1) // TILES_PER_PAGE)
    pages: list[bytes] = []
    pad_tile = bytes([pad_value]) * TILE_BYTES
    for page_index in range(page_count):
        first = page_index * TILES_PER_PAGE
        page_tiles = list(tiles[first : first + TILES_PER_PAGE])
        page_tiles.extend([pad_tile] * (TILES_PER_PAGE - len(page_tiles)))
        page = b"".join(page_tiles)
        assert len(page) == PAGE_BYTES
        pages.append(page)
    return pages


def make_nonempty_rows(
    tiles: Iterable[bytes], transparent: int | None = TRANSPARENT_BYTE
) -> bytes:
    result = bytearray()
    empty_row = (
        bytes([transparent]) * TILE_ROW_BYTES if transparent is not None else None
    )
    for tile in tiles:
        if len(tile) != TILE_BYTES:
            raise ValueError("every tile must contain exactly 256 bytes")
        mask = 0
        for row in range(TILE_HEIGHT):
            start = row * TILE_ROW_BYTES
            if empty_row is None or tile[start : start + TILE_ROW_BYTES] != empty_row:
                mask |= 1 << (31 - row)
        result.extend(struct.pack("<I", mask))
    return bytes(result)


def make_metatile_groups(
    refs: bytes, grid_width: int, grid_height: int, width: int, height: int
) -> list[list[int]]:
    if width == 0 and height == 0:
        return []
    if width <= 0 or height <= 0:
        raise ValueError("metatile width and height must both be positive")
    if grid_width % width or grid_height % height:
        raise ValueError("metatile dimensions must divide the source tile grid")
    values = [refs[index] | (refs[index + 1] << 8) for index in range(0, len(refs), 2)]
    groups: list[list[int]] = []
    for base_y in range(0, grid_height, height):
        for base_x in range(0, grid_width, width):
            group: list[int] = []
            for y in range(height):
                start = (base_y + y) * grid_width + base_x
                group.extend(values[start : start + width])
            groups.append(group)
    return groups


def write_package(
    image: IndexedImage,
    output: Path,
    *,
    keyed: bool,
    emit_masks: bool,
    metatile_width: int,
    metatile_height: int,
) -> dict[str, object]:
    use_key = keyed or image.keyed
    tiles = extract_tiles(image, keyed=use_key)
    refs = make_refs(len(tiles))
    pages = pack_pages(tiles, TRANSPARENT_BYTE if use_key else 0)
    output.mkdir(parents=True, exist_ok=True)
    for index, page in enumerate(pages):
        (output / f"page{index:02d}.bin").write_bytes(page)
    (output / "tiles.refs").write_bytes(refs)
    (output / "tilemap.bin").write_bytes(refs)
    (output / "palette.rgb").write_bytes(image.palette)
    if emit_masks:
        transparent = TRANSPARENT_BYTE if use_key else None
        (output / "nonempty_rows.bin").write_bytes(
            make_nonempty_rows(tiles, transparent)
        )

    grid_width = image.width // TILE_WIDTH
    grid_height = image.height // TILE_HEIGHT
    metatiles = make_metatile_groups(
        refs, grid_width, grid_height, metatile_width, metatile_height
    )
    if metatiles:
        (output / "metatiles.json").write_text(
            json.dumps(metatiles, indent=2) + "\n", encoding="utf-8"
        )

    manifest: dict[str, object] = {
        "format": "gfx640-tilepack-v1",
        "tile_width": TILE_WIDTH,
        "tile_height": TILE_HEIGHT,
        "tile_bytes": TILE_BYTES,
        "layout": "row-major-packed-4bpp-high-nibble-left",
        "grid_width": grid_width,
        "grid_height": grid_height,
        "tile_count": len(tiles),
        "logical_page_count": len(pages),
        "tiles_per_page": TILES_PER_PAGE,
        "padding": TRANSPARENT_BYTE if use_key else 0,
        "keyed": use_key,
        "tile_refs": "tiles.refs",
        "tilemap": "tilemap.bin",
        "palette": "palette.rgb",
        "nonempty_rows": "nonempty_rows.bin" if emit_masks else None,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="indexed PNG or BMP")
    parser.add_argument("output", type=Path, help="output directory")
    parser.add_argument("--transparent-index", type=int)
    parser.add_argument("--keyed", action="store_true", help="use #FF transparent pairs")
    parser.add_argument("--nonempty-rows", action="store_true")
    parser.add_argument("--metatile-width", type=int, default=0)
    parser.add_argument("--metatile-height", type=int, default=0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    image = load_indexed_image(args.input, args.transparent_index)
    manifest = write_package(
        image,
        args.output,
        keyed=args.keyed,
        emit_masks=args.nonempty_rows,
        metatile_width=args.metatile_width,
        metatile_height=args.metatile_height,
    )
    print(
        f"packed {manifest['tile_count']} tiles into "
        f"{manifest['logical_page_count']} page(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
