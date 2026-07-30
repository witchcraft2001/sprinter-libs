# WIN320.DLL

Stage 0 of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The current release establishes ABI 1.0, window
configuration, lifecycle handling, and loading of the embedded accelerator font.
Drawing and control entry points are reserved for later stages and currently
return `WIN_ERR_UNSUPPORTED`.

The recommended layout is to load the DLL into WIN3 and keep application code,
stack, and descriptors in WIN0–WIN2. The library does not select DSS mode
`#81`, change the palette, or switch the visible screen.

The default font is already stored as the first trailing payload of
`WIN320.DLL`. No separate font file is required.

## Build and verify

```sh
make all
make host-test
make z80-test
make verify
make inspect
make release
```

`release` updates the tracked `WIN320.DLL` and diagnostic `WIN320.EXE`.
`WIN320.EXE` loads the adjacent DLL through the current libman, reports ABI and
configuration values, verifies a reserved entry, and unloads the library.

Build prerequisites are `sjasmplus`, Python 3, `z88dk-ticks`, and the sibling
`sources/libman` checkout. Override `LIBMAN_MKDLL`, `LIBMAN_DIR`, or `TICKS`
when the tools are installed elsewhere.
