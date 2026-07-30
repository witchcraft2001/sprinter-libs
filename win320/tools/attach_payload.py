#!/usr/bin/env python3
"""Append a WF32 block to a completed L0 prefix without changing its header."""

from __future__ import annotations

import argparse
from pathlib import Path


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
    args = parser.parse_args()
    payload = args.payload.read_bytes()
    result = attach(args.prefix.read_bytes(), payload)
    args.output.write_bytes(result)
    print(
        f"created {args.output}: {len(result)} bytes "
        f"({len(payload)} trailing)"
    )


if __name__ == "__main__":
    main()
