#!/usr/bin/env python3
"""Generate overlay imports and four pre-relocated fixed-size images."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

LAYOUT = Path("win320_layout.inc")


def layout(root: Path) -> tuple[int, int]:
    values: dict[str, int] = {}
    pattern = re.compile(r"^(S5_OVERLAY_(?:OFFSET|CODE_SIZE))\s+equ\s+#([0-9a-fA-F]+)$")
    for line in (root / LAYOUT).read_text().splitlines():
        match = pattern.match(line)
        if match:
            values[match.group(1)] = int(match.group(2), 16)
    base = values.get("S5_OVERLAY_OFFSET")
    size = values.get("S5_OVERLAY_CODE_SIZE")
    if base is None or size is None or base + size != 0x4000:
        raise SystemExit("invalid WIN320 overlay layout")
    return base, size


def symbols(source: Path, destination: Path) -> None:
    entries: list[str] = []
    pattern = re.compile(r"^([a-z][A-Za-z0-9_]*): EQU 0x([0-9A-Fa-f]+)$")
    for line in source.read_text().splitlines():
        match = pattern.match(line)
        if not match:
            continue
        name, value = match.groups()
        if name.startswith(("s5_", "s6_")) or name in {
            "win_icon", "win_progress_init", "win_progress_draw",
            "win_scrollbar_init", "win_scrollbar_draw", "win_listbox_draw",
            "win_checkbox", "win_radiobutton",
        }:
            continue
        entries.append(f"{name} equ #{int(value, 16):04x}+RELOC_DELTA")
    destination.write_text("\n".join(entries) + "\n")


def assemble(root: Path, base: int, delta: int, output: Path) -> bytes:
    subprocess.run(
        ["sjasmplus", f"--raw={output}", f"-DRELOC_DELTA={delta}",
         "stage5_overlay.asm"],
        cwd=root,
        check=True,
    )
    raw = output.read_bytes()
    if len(raw) < base + delta:
        raise SystemExit("overlay assembler output is shorter than its origin")
    return raw[base + delta:]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--symbols", type=Path, required=True)
    parser.add_argument("--imports", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    base, code_size = layout(root)
    imports = args.imports.resolve()
    symbols(args.symbols.resolve(), imports)
    images: list[bytes] = []
    size = None
    for delta in (0xC000, 0, 0x4000, 0x8000):
        window = delta // 0x4000
        raw = assemble(root, base, delta, root / f"build/stage5.window{window}.bin")
        size = len(raw) if size is None else size
        if len(raw) != size:
            raise SystemExit("overlay passes have different sizes")
        if len(raw) > code_size:
            raise SystemExit(
                f"WIN320 overlay is {len(raw)} bytes; limit is {code_size}"
            )
        images.append(raw + bytes(code_size - len(raw)))
    args.output.write_bytes(b"".join(images))
    print(
        f"created {args.output}: four {code_size}-byte relocated images, WIN3 first"
    )


if __name__ == "__main__":
    main()
