#!/usr/bin/env python3
"""Pack indexed 8x8/16x16 icons and sprite sheets into a WIP1 file."""

from __future__ import annotations

import argparse
import json
import re
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

WIP_MAGIC = b"WIP1"
WIP_VERSION = 1
PAGE_BYTES = 16 * 1024
VALID_SIZES = (8, 16)
SYMBOL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclass(frozen=True)
class IndexedImage:
    width: int
    height: int
    pixels: bytes


@dataclass(frozen=True)
class IconCell:
    name: str
    size: int
    pixels: bytes


@dataclass(frozen=True)
class IconRef:
    pack_page: int
    slot: int
    size: int


def load_index_map(path: Path | None) -> tuple[int, ...]:
    values = list(range(256))
    if path is None:
        return tuple(values)
    source = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(source, list):
        if len(source) != 256:
            raise ValueError("index-map list must contain exactly 256 values")
        entries = enumerate(source)
    elif isinstance(source, dict):
        entries = ((int(key), value) for key, value in source.items())
    else:
        raise ValueError("index-map must be a JSON object or 256-value list")
    for source_index, target_index in entries:
        if not 0 <= source_index <= 255 or not isinstance(target_index, int):
            raise ValueError("index-map keys and values must be byte indices")
        if not 0 <= target_index <= 255:
            raise ValueError("index-map keys and values must be byte indices")
        values[source_index] = target_index
    return tuple(values)


def load_indexed_image(
    path: Path,
    *,
    index_map: Sequence[int] | None = None,
    transparent_index: int | None = None,
) -> IndexedImage:
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError(
            "winiconpack requires Pillow; install win320/requirements-dev.txt"
        ) from exc

    with Image.open(path) as image:
        if image.mode != "P":
            raise ValueError(f"{path}: input must be an 8-bit indexed PNG/BMP")
        width, height = image.size
        pixels = image.tobytes()
        source_transparency = image.info.get("transparency")

    if transparent_index is None and isinstance(source_transparency, int):
        transparent_index = source_transparency
    if transparent_index is not None and not 0 <= transparent_index <= 255:
        raise ValueError("transparent index must be in range 0..255")
    mapping = list(index_map if index_map is not None else range(256))
    if len(mapping) != 256 or any(not 0 <= value <= 255 for value in mapping):
        raise ValueError("index map must contain exactly 256 byte values")
    if transparent_index is not None:
        if index_map is None and transparent_index != 255 and 255 in pixels:
            raise ValueError(
                f"{path}: cannot remap transparency to #FF while index #FF is used"
            )
        mapping[transparent_index] = 255
    return IndexedImage(width, height, bytes(mapping[value] for value in pixels))


def extract_cells(name: str, size: int, image: IndexedImage) -> list[IconCell]:
    if not SYMBOL_RE.fullmatch(name):
        raise ValueError(f"invalid asset name: {name!r}")
    if size not in VALID_SIZES:
        raise ValueError("cell size must be 8 or 16")
    if image.width <= 0 or image.height <= 0:
        raise ValueError("image dimensions must be non-zero")
    if image.width % size or image.height % size:
        raise ValueError(f"{name}: dimensions must be multiples of {size}")
    if len(image.pixels) != image.width * image.height:
        raise ValueError(f"{name}: pixel payload does not match image dimensions")

    count = (image.width // size) * (image.height // size)
    cells: list[IconCell] = []
    index = 0
    for cell_y in range(0, image.height, size):
        for cell_x in range(0, image.width, size):
            payload = bytearray()
            for row in range(size):
                start = (cell_y + row) * image.width + cell_x
                payload.extend(image.pixels[start : start + size])
            cell_name = name if count == 1 else f"{name}_{index:03d}"
            cells.append(IconCell(cell_name, size, bytes(payload)))
            index += 1
    return cells


def symbol_name(name: str) -> str:
    symbol = name.upper()
    if not SYMBOL_RE.fullmatch(symbol):
        raise ValueError(f"asset name cannot be represented in manifests: {name!r}")
    return symbol


def pack_wip(cells: Sequence[IconCell]) -> tuple[bytes, dict[str, IconRef]]:
    if not cells:
        raise ValueError("at least one icon cell is required")
    by_size: dict[int, list[IconCell]] = {8: [], 16: []}
    symbols: set[str] = set()
    for cell in cells:
        if cell.size not in VALID_SIZES:
            raise ValueError("cell size must be 8 or 16")
        if len(cell.pixels) != cell.size * cell.size:
            raise ValueError(f"{cell.name}: cell payload has the wrong size")
        symbol = symbol_name(cell.name)
        if symbol in symbols:
            raise ValueError(f"duplicate manifest symbol: {symbol}")
        symbols.add(symbol)
        by_size[cell.size].append(cell)

    pages: list[tuple[int, list[IconCell]]] = []
    for size in VALID_SIZES:
        capacity = PAGE_BYTES // (size * size)
        sized_cells = by_size[size]
        for start in range(0, len(sized_cells), capacity):
            pages.append((size, sized_cells[start : start + capacity]))
    if len(pages) > 255:
        raise ValueError("WIP1 supports at most 255 pages")

    refs: dict[str, IconRef] = {}
    descriptors = bytearray()
    payload = bytearray()
    for page_index, (size, page_cells) in enumerate(pages):
        capacity = PAGE_BYTES // (size * size)
        used = len(page_cells)
        encoded_used = 0 if size == 8 and used == capacity else used
        descriptors.extend((size, encoded_used))
        page = bytearray()
        for slot, cell in enumerate(page_cells):
            page.extend(cell.pixels)
            refs[cell.name] = IconRef(page_index, slot, size)
        page.extend(b"\xff" * (PAGE_BYTES - len(page)))
        payload.extend(page)

    header_size = 8 + len(pages) * 2
    header = struct.pack(
        "<4sBBH", WIP_MAGIC, WIP_VERSION, len(pages), header_size
    )
    return header + descriptors + payload, refs


def manifest_data(refs: Mapping[str, IconRef]) -> dict[str, object]:
    return {
        "format": "WIP1",
        "version": WIP_VERSION,
        "assets": {
            name: {
                "pack_page": ref.pack_page,
                "slot": ref.slot,
                "size": ref.size,
            }
            for name, ref in refs.items()
        },
    }


def render_asm(refs: Mapping[str, IconRef], prefix: str) -> str:
    lines = ["; Generated by winiconpack.py. Do not edit."]
    for name, ref in refs.items():
        symbol = f"{prefix}_{symbol_name(name)}"
        lines.extend(
            (
                f"{symbol}_PAGE equ {ref.pack_page}",
                f"{symbol}_SLOT equ {ref.slot}",
                f"{symbol}_SIZE equ {ref.size}",
            )
        )
    return "\n".join(lines) + "\n"


def render_c(refs: Mapping[str, IconRef], prefix: str) -> str:
    guard = f"{prefix}_WIP_H"
    lines = [
        "/* Generated by winiconpack.py. Do not edit. */",
        f"#ifndef {guard}",
        f"#define {guard}",
        "#include <stdint.h>",
        "typedef struct { uint8_t pack_page, slot, size; } WinIconAsset;",
    ]
    for name, ref in refs.items():
        symbol = f"{prefix}_{symbol_name(name)}"
        lines.append(
            f"static const WinIconAsset {symbol} = "
            f"{{ {ref.pack_page}, {ref.slot}, {ref.size} }};"
        )
    lines.extend((f"#endif /* {guard} */", ""))
    return "\n".join(lines)


def render_pascal(refs: Mapping[str, IconRef], prefix: str) -> str:
    lines = ["{ Generated by winiconpack.py. Do not edit. }", "const"]
    for name, ref in refs.items():
        symbol = f"{prefix}_{symbol_name(name)}"
        lines.extend(
            (
                f"  {symbol}_PAGE = {ref.pack_page};",
                f"  {symbol}_SLOT = {ref.slot};",
                f"  {symbol}_SIZE = {ref.size};",
            )
        )
    return "\n".join(lines) + "\n"


def write_package(
    cells: Sequence[IconCell], output: Path, *, prefix: str = "WIN_ICON"
) -> dict[str, IconRef]:
    if not SYMBOL_RE.fullmatch(prefix):
        raise ValueError("manifest prefix must be an identifier")
    package, refs = pack_wip(cells)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(package)
    stem = output.with_suffix("")
    stem.with_suffix(".json").write_text(
        json.dumps(manifest_data(refs), indent=2) + "\n", encoding="utf-8"
    )
    stem.with_suffix(".inc").write_text(render_asm(refs, prefix), encoding="utf-8")
    stem.with_suffix(".h").write_text(render_c(refs, prefix), encoding="utf-8")
    stem.with_suffix(".pas").write_text(
        render_pascal(refs, prefix), encoding="utf-8"
    )
    return refs


def parse_asset(value: str) -> tuple[str, int, Path]:
    try:
        declaration, filename = value.split("=", 1)
        name, size_text = declaration.rsplit(":", 1)
        size = int(size_text)
    except (ValueError, TypeError) as exc:
        raise argparse.ArgumentTypeError(
            "asset must use NAME:SIZE=IMAGE syntax"
        ) from exc
    if not name or size not in VALID_SIZES or not filename:
        raise argparse.ArgumentTypeError("asset must use NAME:8|16=IMAGE syntax")
    return name, size, Path(filename)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="output .wip file")
    parser.add_argument(
        "assets", nargs="+", type=parse_asset, metavar="NAME:SIZE=IMAGE"
    )
    parser.add_argument("--prefix", default="WIN_ICON", help="manifest symbol prefix")
    parser.add_argument("--index-map", type=Path, help="JSON index remapping table")
    parser.add_argument("--transparent-index", type=int)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    index_map = load_index_map(args.index_map)
    cells: list[IconCell] = []
    for name, size, path in args.assets:
        image = load_indexed_image(
            path,
            index_map=index_map,
            transparent_index=args.transparent_index,
        )
        cells.extend(extract_cells(name, size, image))
    refs = write_package(cells, args.output, prefix=args.prefix)
    page_count = args.output.read_bytes()[5]
    print(f"packed {len(refs)} icon(s) into {page_count} WIP1 page(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
