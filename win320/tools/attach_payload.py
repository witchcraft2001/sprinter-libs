#!/usr/bin/env python3
"""Append a WF32 block to a completed L0 prefix without changing its header."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def overlay_image_size(root: Path) -> int:
    pattern = re.compile(r"^S5_OVERLAY_CODE_SIZE\s+equ\s+#([0-9a-fA-F]+)$")
    for line in (root / "win320_layout.inc").read_text().splitlines():
        match = pattern.match(line)
        if match:
            return int(match.group(1), 16)
    raise ValueError("invalid WIN320 overlay layout")


def attach(prefix: bytes, payload: bytes) -> bytes:
    if len(prefix) < 16 or prefix[:2] != b"L0":
        raise ValueError("prefix is not an L0 library")
    declared_size = int.from_bytes(prefix[2:4], "little")
    if declared_size != len(prefix):
        raise ValueError(
            f"L0 prefix declares {declared_size} bytes, got {len(prefix)}"
        )
    if len(payload) < 8 or payload[:4] != b"WF32":
        raise ValueError("payload is not WF32")
    data_size = int.from_bytes(payload[6:8], "little")
    if len(payload) != 8 + data_size:
        raise ValueError("WF32 data_size does not match the physical payload")
    return prefix + payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("prefix", type=Path)
    parser.add_argument("payload", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("overlay", type=Path, nargs="?")
    args = parser.parse_args()
    payload = args.payload.read_bytes()
    result = attach(args.prefix.read_bytes(), payload)
    if args.overlay is not None:
        overlay = args.overlay.read_bytes()
        image_size = overlay_image_size(args.prefix.resolve().parent.parent)
        if len(overlay) != 4 * image_size:
            raise ValueError(
                f"WIN320 overlay must contain four {image_size}-byte images"
            )
        result += overlay
    args.output.write_bytes(result)
    print(
        f"created {args.output}: {len(result)} bytes "
        f"({len(result) - len(args.prefix.read_bytes())} trailing)"
    )


if __name__ == "__main__":
    main()
