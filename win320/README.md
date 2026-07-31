# WIN320.DLL

Stage 4 of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The release keeps public ABI 1.0 and implements entries
0–30: lifecycle, fonts, accelerated primitives, declarative windows, dirty
updates, modal backstore, and `win_poll`, `win_track`, `win_wait_release`, and
`win_set_cursor`, plus `win_edit_draw` and `win_edit`. Keyboard focus,
Tab/Shift+Tab traversal, mouse focus, and Enter/Space button activation are
enabled. `WIN_CAP_CORE`, `WIN_CAP_EDIT`, `WIN_CAP_FOCUS`, and
`WIN_CAP_PASCAL_STR` are set. Entries 31–36 remain reserved and return
`WIN_ERR_UNSUPPORTED`; listbox focus rendering arrives with Stage 5.

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
both buffers, Stage-3 event tracking, and Stage-4 ASCIIZ/Pascal editing and
keyboard focus on both screens.

On each Stage-4 screen, edit the field and use Enter to accept or Esc to
restore it. Tab moves focus to `Continue`; Enter or Space must animate and
activate the button, while another Tab returns to the field. The label reports
which exit path was received before the test advances. A click inside the
active field moves the insertion cursor to the clicked proportional glyph;
clicks on other controls still finish with `WIN_ED_MOUSE`. While editing, the
solid vertical caret blinks every 14 frames. It is `1×10` in a framed field,
extending one pixel above and below the glyph, and `1×8` in a minimal unframed
field. Its colour is the text foreground, and every covered pixel is restored
before blinking or redrawing, so it remains distinct beside tall glyphs and
across password `*` without leaving edge trails. Typing updates only the text
content and must not flash the field frame or briefly blank the whole string.

Build prerequisites are `sjasmplus`, Python 3, `z88dk-ticks`, and the sibling
`sources/libman` checkout. Override `LIBMAN_MKDLL`, `LIBMAN_DIR`, or `TICKS`
when the tools are installed elsewhere.
