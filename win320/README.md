# WIN320.DLL

Stage 3 of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The release keeps public ABI 1.0 and implements entries
0–28: lifecycle, fonts, accelerated primitives, declarative windows, dirty
updates, modal backstore, and `win_poll`, `win_track`, `win_wait_release`, and
`win_set_cursor`. `WIN_CAP_CORE` is set. Entries 29–36 remain reserved and
return `WIN_ERR_UNSUPPORTED`; keyboard focus and `WIN_TRK_TAB_FOCUS` are Stage 4.

The recommended layout is to load the DLL into WIN3 and keep application code,
stack, and descriptors in WIN0–WIN2. The library does not select DSS mode
`#81` or switch the visible screen. `win_style` can install the GUI palette at
`#F0..#FF` and clear either or both drawing buffers.

The default font is already stored as the first trailing payload of
`WIN320.DLL`. No separate font file is required.

Before the first `win_poll` or `win_track`, the application must initialize
the BIOS mouse driver itself (`RST #30`, `C=0`). The library never does mouse
INIT. With `WIN_TRK_SHOW_CUR`, `win_track` owns cursor visibility for its
blocking loop; a `win_poll` client shows and hides it around its own loop.

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
