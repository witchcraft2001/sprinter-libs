# WIN320.DLL

Stage 2 of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The current release keeps public ABI 1.0 and implements
entry 0–24: lifecycle and work-window configuration, embedded/external WF32
fonts, themes and EGA palette setup, accelerated GUI primitives, labels,
buttons, declarative windows, dirty updates, and LIFO modal backstore.
Entry 25–36 remain reserved and return `WIN_ERR_UNSUPPORTED`.
Keyboard focus remains deferred: `focus` and `last_focus` must be `#FF`,
`WIN_IT_FOCUSABLE` is rejected, and `WIN_CAP_CORE` is still clear.

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
`WIN320.EXE` enters mode `#81` and walks through the primitive screens plus
Stage-2 declarative drawing, dirty updates, and nested modal restoration on
both buffers.

Build prerequisites are `sjasmplus`, Python 3, `z88dk-ticks`, and the sibling
`sources/libman` checkout. Override `LIBMAN_MKDLL`, `LIBMAN_DIR`, or `TICKS`
when the tools are installed elsewhere.
