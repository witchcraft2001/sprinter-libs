# WIN320.DLL

Stage 1 of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The current release keeps public ABI 1.0 and implements
entry 0–18: lifecycle and work-window configuration, embedded/external WF32
fonts, themes and EGA palette setup, accelerated GUI primitives, labels, and
buttons. Entry 19–36 remain reserved and return `WIN_ERR_UNSUPPORTED`.

The recommended layout is to load the DLL into WIN3 and keep application code,
stack, and descriptors in WIN0–WIN2. The library does not select DSS mode
`#81` or switch the visible screen. `win_style` can install the GUI palette at
`#F0..#FF` and clear either or both drawing buffers.

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

`release` updates the tracked `WIN320.DLL` and visual `WIN320.EXE`.
`WIN320.EXE` enters mode `#81` and draws Stage-1 panels, frames, separators,
labels, XOR/focus rectangles, and all button states on both screens. Screen 0
uses ASCIIZ strings and the default theme; screen 1 uses Pascal strings and an
alternate theme.

Build prerequisites are `sjasmplus`, Python 3, `z88dk-ticks`, and the sibling
`sources/libman` checkout. Override `LIBMAN_MKDLL`, `LIBMAN_DIR`, or `TICKS`
when the tools are installed elsewhere.
