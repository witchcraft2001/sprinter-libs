#!/usr/bin/env python3
"""Generate overlay imports and four pre-relocated fixed-size images."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

BASE = 0x351E
CODE_SIZE = 0x4000 - BASE


def symbols(source: Path, destination: Path) -> None:
    entries: list[str] = []
    pattern = re.compile(r"^([a-z][A-Za-z0-9_]*): EQU 0x([0-9A-Fa-f]+)$")
    for line in source.read_text().splitlines():
        match = pattern.match(line)
        if not match:
            continue
        name, value = match.groups()
        if name.startswith("s5_") or name in {
            "win_icon", "win_progress_init", "win_progress_draw",
            "win_scrollbar_init", "win_scrollbar_draw", "win_listbox_draw",
        }:
            continue
        entries.append(f"{name} equ #{int(value, 16):04x}+RELOC_DELTA")
    destination.write_text("\n".join(entries) + "\n")


def assemble(root: Path, delta: int, output: Path) -> bytes:
    subprocess.run(
        ["sjasmplus", f"--raw={output}", f"-DRELOC_DELTA={delta}",
         "stage5_overlay.asm"],
        cwd=root,
        check=True,
    )
    raw = output.read_bytes()
    if len(raw) < BASE + delta:
        raise SystemExit("overlay assembler output is shorter than its origin")
    return raw[BASE + delta:]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--symbols", type=Path, required=True)
    parser.add_argument("--imports", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    imports = args.imports.resolve()
    symbols(args.symbols.resolve(), imports)
    images: list[bytes] = []
    size = None
    for delta in (0xC000, 0, 0x4000, 0x8000):
        window = delta // 0x4000
        raw = assemble(root, delta, root / f"build/stage5.window{window}.bin")
        size = len(raw) if size is None else size
        if len(raw) != size:
            raise SystemExit("overlay passes have different sizes")
        if len(raw) > CODE_SIZE:
            raise SystemExit(
                f"Stage-5 overlay is {len(raw)} bytes; limit is {CODE_SIZE}"
            )
        images.append(raw + bytes(CODE_SIZE - len(raw)))
    args.output.write_bytes(b"".join(images))
    print(
        f"created {args.output}: four {CODE_SIZE}-byte relocated images, WIN3 first"
    )


if __name__ == "__main__":
    main()
