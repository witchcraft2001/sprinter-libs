# WIN320.DLL

Stage 5 development build of the lightweight 320×256 GUI library described in
[`specs.md`](specs.md). The release keeps public ABI 1.0 and implements entries
0–36: lifecycle, fonts, accelerated primitives, declarative windows, dirty
updates, modal backstore, and `win_poll`, `win_track`, `win_wait_release`, and
`win_set_cursor`, plus `win_edit_draw` and `win_edit`. Keyboard focus,
Tab/Shift+Tab traversal, mouse focus, and Enter/Space button activation are
enabled. Stage-5 entries add 8×8/16×16 opaque or keyed icons, progress bars,
horizontal/vertical scrollbars, and direct or paged listboxes; all declared
capability bits are set. The new controls also participate in declarative
`win_draw`/`win_update`, and listbox focus follows `WinWindow.focus`.

The libman 1.2 L0 prefix has a hard 16-KiB code-plus-relocation limit. Stage 5
therefore ships as a fixed overlay after the embedded font. `win_init` selects
one of four pre-relocated images and installs it over the relocation bitmap
that libman has already consumed; the public entry table and ABI remain a
single `WIN320.DLL`.

The recommended layout is to load the DLL into WIN3 and keep application code,
stack, and descriptors in WIN0–WIN2. The library does not select DSS mode
`#81` or switch the visible screen. `win_style` can install the GUI palette at
`#F0..#FF` and clear either or both drawing buffers.

The default font is already stored as the first trailing payload of
`WIN320.DLL`. No separate font file is required.

## Icon packs

`tools/winiconpack.py` accepts indexed PNG/BMP files and row-major sprite
sheets. Each input declares its cell size explicitly, so a 16×16 image is
never ambiguously interpreted as four 8×8 icons:

```sh
python3 tools/winiconpack.py build/icons.wip \
    open:16=assets/open.png markers:8=assets/markers.png
```

The command writes `icons.wip` plus matching `.inc`, `.h`, `.pas`, and JSON
manifests. Multi-cell sheets receive deterministic `_000`, `_001`, … names.
Inputs must use an indexed palette; `--index-map map.json` applies an explicit
256-entry/list or partial object remapping, and `--transparent-index N` maps
the chosen source index to the hardware transparency value `#FF`.

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

`release` updates the tracked `WIN320.DLL`, visual `WIN320.EXE`, and its
`ICONS.WIP` asset. Copy all three files into the same target directory.
`WIN320.EXE` enters mode `#81` and walks through the primitive screens plus
Stage-2 declarative drawing, dirty updates, and nested modal restoration on
both buffers, Stage-3 event tracking, and Stage-4 ASCIIZ/Pascal editing and
keyboard focus on both screens. Its final Stage-5 screen loads `ICONS.WIP`
from beside the EXE into application-owned EMM pages, draws keyed 8×8/16×16
icons, animates progress in both directions, moves the listbox cursor, and
scrolls the linked scrollbar without reinitializing it.

On each Stage-4 screen, edit the field and use Enter to accept or Esc to
restore it. Ctrl+Left/Right moves between words using the same separators as
FlexNavigator (space, comma, period, and backslash). Tab moves focus to
`Continue`; Enter or Space must animate and activate the button, while another
Tab returns to the field. Tab/mouse and programmatic `win_update` focus changes
repaint only the edit content, leaving its frame and field background stable.
The label reports
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
`sources/libman` checkout. `winiconpack` additionally uses Pillow from
`requirements-dev.txt`. Override `LIBMAN_MKDLL`, `LIBMAN_DIR`, or `TICKS` when
the tools are installed elsewhere.
