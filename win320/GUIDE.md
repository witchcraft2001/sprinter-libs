# WIN320.DLL — Developer Guide

Русская версия этого документа: [GUIDE.ru.md](GUIDE.ru.md).

`WIN320.DLL` is a lightweight windowed-GUI library for the Sprinter in DSS
mode `#81` (320×256, 256 colours). It is not a framework: the library
provides ready-made building blocks — panels, buttons, edit fields,
listboxes, scrollbars, progress bars, icons, checkboxes and radio
buttons — from which an application written in assembly, C (SDCC) or
Turbo Pascal assembles a GFX Viewer / Flex Navigator style interface.
Internally it drives the Sprinter hardware accelerator, but that is an
implementation detail, not part of the ABI.

Two equally supported usage styles:

- **declarative** — controls are described by packed structures,
  references are collected into a `WinItem[]` array and the array into a
  `WinWindow`; the window is painted by a single `win_draw` and updated
  selectively through dirty flags and `win_update`;
- **imperative** — the same descriptors are passed directly to
  `win_button`, `win_panel`, `win_label` and friends, with no window and
  no arrays.

Descriptors are identical on both paths: the structure referenced from a
window's item list works unchanged in a direct call.

## 1. Deliverables

| File | Purpose |
|---|---|
| `WIN320.DLL` | the library — the only file an application needs (the font is embedded in the file tail) |
| `win320.inc` | public constants and field offsets for sjasmplus |
| `bind/win320.h`, `bind/win320.lib` | C header and ABI wrappers for SDCC |
| `bind/WIN320.INC` | Turbo Pascal records and `LibCall` helpers |
| `examples/dialog.asm`, `dialog.c`, `DIALOG.PAS` | the same dialog in three languages |
| `tools/winiconpack.py` | icon packer, PNG/BMP → `WIP1` |
| `WIN320.EXE` | visual test of the library; applications do **not** need it |

## 2. Functionality (ABI 1.1)

- **Primitives** — fill, raised/sunken 3D frame, panel, separator, XOR
  invert, dashed focus indicator.
- **Text** — proportional 8-pixel font (CP866, embedded in the DLL,
  replaceable with a `WF32` file via `win_load_font` without a rebuild);
  label with alignment, field fill and ".." tail clipping.
- **Controls** — button (normal/pressed/disabled/focused, pseudographic
  glyphs), edit field with modal editing, listbox (plain pointers or
  paged strings in EMM pages), scrollbar with end arrows, progress bar
  (percent), 8×8/16×16 icons from EMM pages with hardware `#FF`
  transparency, checkbox and radio button with groups.
- **Windows** — a declarative object list, redraw of changed objects only
  (`WIN_IT_DIRTY` + `win_update`), a LIFO stack of modal windows with
  background save/restore (backstore in application-owned EMM pages).
- **Events** — non-blocking `win_poll` and blocking `win_track`: clicks,
  auto-repeat, hover/leave, hotkeys, raw codes of any key, scrollbar
  sub-areas and listbox rows.
- **Keyboard focus** — Tab/Shift+Tab traversal, Enter activates the
  focused button, Space toggles checkbox/radio, arrows move inside a
  radio group; the focus indicator is drawn by the library.
- **Theme** — 16 colour roles set by one `win_set_theme` call; `#FF` in
  any descriptor colour field means "take it from the theme".
- **Strings** — a global format: ASCIIZ (C/asm) or length-prefixed
  (Turbo Pascal `string`).
- **Screens** — drawing to screen 0 or 1 (`win_set_screen`); switching
  the visible screen remains the application's job.

Deliberately out of scope: overlapping non-modal windows, z-order,
clipping, window dragging, an own mouse driver.

## 3. Quick start (assembly)

The library is loaded by the libman loader
(`sources/libman/libman/libman.asm`); the recommended layout keeps the
DLL in **WIN3** and application code, data and stack in WIN0..WIN2. The
loader finds the DLL beside the EXE by itself:

```asm
        include "win320.inc"

        ld  bc,#0050            ; DSS SETVMOD
        ld  a,#81               ; 320x256x256 mode
        rst #10

        ld  hl,dll_name         ; "WIN320.DLL",0
        ld  a,3                 ; window for the DLL (WIN3)
        call LIBMAN.l_load
        jp  c,load_error        ; reason in LIBMAN.l_reason / l_dss_error
        ld  (dll_handle),hl     ; the font is already loaded by win_init

        ld  e,WIN_STYLE_PALETTE|WIN_STYLE_CLEAR
        ld  d,#FF               ; 0..15, or #FF = theme desktop colour
        ld  b,WIN_STYLE         ; entry number from win320.inc
        call api
        jr  nz,win_error        ; A: 0 = success, #20..#28 = WIN_ERR_*
        ...
api:    ld  hl,(dll_handle)
        call LIBMAN.l_call      ; arguments: A, DE, IX, IY
        ret c                   ; CF = libman dispatcher error
        or  a                   ; ZF reflects the WIN320 status
        ret
```

A complete scenario: [examples/dialog.asm](examples/dialog.asm).

## 4. Calling convention

- Only `A`, `DE`, `IX`, `IY` reach an entry; `HL`/`BC` belong to the
  `l_call` dispatcher. Larger arguments travel as a packed descriptor
  pointed to by `DE` (field offsets are in `win320.inc`).
- The status returns in `A`: `0` — success, `#20..#28` — a `WIN_ERR_*`
  code. The CF flag belongs to the libman dispatcher and is not part of
  the library ABI for entries `>=1`.
- Entries 0/1 (`win_init`/`win_free`) are called only by the manager
  inside `l_load`/`l_free`; applications never call them.
- Every function preserves the registers it does not declare as input or
  output.
- The library is non-reentrant: never call it from an ISR/NMI or again
  before the previous operation finished.

### Data placement

For the duration of `l_call` the DLL page is mapped into its window,
displacing the application page there, so **no call data may live in the
DLL's window**. The top-level descriptor is copied to scratch before VRAM
is mapped; everything read during the call (strings, `WinItem[]`, listbox
arrays, key tables, the edit buffer) must stay reachable for the whole
call. Some structures are written by the library (`WinWindow.focus`,
`WinItem.flags`, control flags and internal fields, `WinTrack` outputs,
the edit buffer) — they must be in writable RAM; in C they must not be
declared `const`.

### Error codes

| Code | Name | Meaning |
|---:|---|---|
| `#20` | `WIN_ERR_ARGUMENT` | invalid parameter/structure |
| `#21` | `WIN_ERR_VIDEO_MODE` | active mode is not `#81` |
| `#22` | `WIN_ERR_WINDOW` | CPU-window conflict (DLL/`SP`/work windows) |
| `#23` | `WIN_ERR_BACKSTORE` | backstore missing or out of room |
| `#24` | `WIN_ERR_DEPTH` | window stack overflow/underflow |
| `#25` | `WIN_ERR_UNSUPPORTED` | function/flag not supported |
| `#26` | `WIN_ERR_BUSY` | conflicting unfinished operation |
| `#27` | `WIN_ERR_FONT` | font not loaded / font file error |
| `#28` | `WIN_ERR_MEMORY` | EMM allocation failed |

## 5. Entry table

Numbers are the `WIN_*` constants in [win320.inc](win320.inc).

| # | Function | Input | Result |
|---:|---|---|---|
| 0 | `win_init` | `l_load` only | — |
| 1 | `win_free` | `l_free` only | — |
| 2 | `win_set_work_windows` | `D`=data window, `E`=VRAM window; `0..3` or `WIN_WORK_AUTO=#FF` | |
| 3 | `win_set_screen` | `E`=0/1 | |
| 4 | `win_get_version` | — | `D`=major(1), `E`=minor(1), `IX`=capabilities |
| 5 | `win_get_config` | `DE`=&WinConfig | filled structure |
| 6 | `win_load_font` | `DE`=ASCIIZ path to a `WF32` file | |
| 7 | `win_set_theme` | `DE`=&WinTheme or 0 (default theme) | |
| 8 | `win_set_text_format` | `E`=0 ASCIIZ / 1 Pascal | |
| 9 | `win_set_origin` | `IX`=x, `E`=y | |
| 10 | `win_style` | `E`=flags, `D`=desktop colour | |
| 11–16 | `win_fill_rect`, `win_frame`, `win_panel`, `win_separator`, `win_invert_rect`, `win_focus_rect` | `DE`=&WinRect | |
| 17 | `win_label` | `DE`=&WinLabel | |
| 18 | `win_button` | `DE`=&WinButton | |
| 19 | `win_draw` | `DE`=&WinWindow | full window render |
| 20 | `win_draw_item` | `DE`=&WinWindow, `IX`=index | full render of one object |
| 21 | `win_update` | `DE`=&WinWindow | `E`=number of objects redrawn |
| 22 | `win_set_backstore` | `DE`=&page list, `IX`=count 1..4 | |
| 23 | `win_open` | `DE`=&WinWindow | background save + render |
| 24 | `win_close` | — | background restore (LIFO) |
| 25 | `win_poll` | `DE`=&WinTrack | `D`=event, `E`=id (non-blocking) |
| 26 | `win_track` | `DE`=&WinTrack | `D`=event, `E`=id (blocking) |
| 27 | `win_wait_release` | — | waits for mouse buttons release |
| 28 | `win_set_cursor` | `E`=0 arrow / 1 wait / `#FF`+`IX`=&WinCursor | |
| 29 | `win_edit_draw` | `DE`=&WinEdit | |
| 30 | `win_edit` | `DE`=&WinEdit, `IX`=&WinTrack or 0 | `E`=exit reason |
| 31 | `win_icon` | `DE`=&WinIcon | |
| 32/33 | `win_progress_init` / `win_progress_draw` | `DE`=&WinProgress | |
| 34/35 | `win_scrollbar_init` / `win_scrollbar_draw` | `DE`=&WinScrollbar | |
| 36 | `win_listbox_draw` | `DE`=&WinListbox | |
| 37 | `win_checkbox` | `DE`=&WinChoice | |
| 38 | `win_radiobutton` | `DE`=&WinChoice | |

`win_get_version` reports the ABI version (not the build) plus the
`WIN_CAP_*` capability mask — check it before using optional controls.

## 6. Coordinates, geometry, origin

Every drawable descriptor starts with the same 8-byte header: `x`, `y`,
`width`, `height` — all `u16` little-endian (`y` 0..255, `y+height` ≤ 256,
`x+width` ≤ 320). Thanks to the shared header the hit-test reads the
first eight bytes of any control without knowing its type, and an
object's geometry is stored in exactly one place.

Descriptor coordinates are relative to the current **origin** (default
`0,0`, i.e. screen coordinates). The one exception is `WinWindow`: its
`x,y` are absolute, because the window is what defines the origin.
`win_draw`/`win_update`/`win_poll` set the origin from the window for the
duration of the call; `win_open` keeps it until the matching `win_close`;
`win_set_origin` sets it explicitly for imperative drawing. Consequence:
a dialog is moved by editing the two `WinWindow.x/y` fields — no object
coordinates need recalculating.

Zero `width`/`height` is a successful no-op; exceeding the screen returns
`WIN_ERR_ARGUMENT` without touching it.

## 7. Colour and theme

Two distinct notions:

- **`color`** — a single index `0..15`; used by geometric primitives
  (fill colour, panel body);
- **`attr`** — a byte, `d7..d4` background, `d3..d0` foreground; used by
  text only.

The value `#FF` in any `color`/`attr` field means "take it from the
theme" and is the default, so a typical interface contains no explicit
colours and is recoloured by a single `win_set_theme`. Indices map to the
top 16 palette entries (`#F0|color`); the lower 240 belong to the
application.

`WinTheme` — 16 one-byte roles:

| Role | Default | Purpose |
|---|---:|---|
| `WIN_TH_LIGHT` / `WIN_TH_SHADOW` | 15 / 7 | 3D bevel light and shadow |
| `WIN_TH_FACE` | 8 | body of panels, buttons, windows |
| `WIN_TH_DESKTOP` | 1 | desktop background |
| `WIN_TH_TEXT` / `WIN_TH_TEXT_DISABLED` | 0 / 7 | text / disabled text |
| `WIN_TH_FIELD_BG` / `WIN_TH_FIELD_FG` | 15 / 0 | edit field and listbox |
| `WIN_TH_CURSOR_BG` / `WIN_TH_CURSOR_FG` | 1 / 15 | selected row |
| `WIN_TH_PROGRESS` / `WIN_TH_PROGRESS_FILL` | 7 / 1 | progress bar |
| `WIN_TH_SCROLL_TRACK` / `WIN_TH_SCROLL_THUMB` | 7 / 8 | scrollbar |
| `WIN_TH_FOCUS_MASK` | `#0F` | XOR mask of the focus dashes |

`win_style` is a screen-setup service: load the standard EGA palette into
`#F0..#FF` (`WIN_STYLE_PALETTE`), clear the screen (`WIN_STYLE_CLEAR`),
apply to both screens (`WIN_STYLE_BOTH`).

## 8. Declarative windows

`WinWindow` (16 bytes): geometry, `color`, flags (`WIN_WND_NOPANEL` —
skip the body panel, `WIN_WND_SUNKEN`), `count`, `focus` (index of the
focused item, `#FF` — none), the `items` pointer, internal `last_focus`.

`WinItem` (8 bytes per record, no terminator — `count` gives the length):

```text
type      WIN_T_*: label, fill, frame, panel, separator, button, icon,
          progress, scrollbar, listbox, edit, zone, checkbox, radiobutton
flags     WIN_IT_*
id        identifier reported in events (#FF is reserved)
control   pointer to the control descriptor
user_data returned with the event
```

Item flags:

| Flag | Meaning |
|---|---|
| `WIN_IT_DIRTY` | redraw on `win_update`; cleared by the library |
| `WIN_IT_HIDDEN` | neither drawn nor tested |
| `WIN_IT_DISABLED` | drawn disabled, excluded from input and Tab |
| `WIN_IT_HIT` | takes part in the mouse hit-test (positive flag!) |
| `WIN_IT_FOCUSABLE` | takes part in Tab traversal |
| `WIN_IT_PRESS` | animate the press |
| `WIN_IT_REPEAT` | auto-repeat while LMB is held |
| `WIN_IT_HOVER` | `WIN_EV_HOVER`/`WIN_EV_LEAVE` events |

Interactive objects get `WIN_IT_HIT` explicitly; a decorative label
becomes clickable with the same flag. `WIN_T_ZONE` is an invisible zone
(geometry from a `WinRect`) for areas the application paints itself.

Rendering:

- `win_draw` — full render: window body, objects in ascending index
  order, focus-indicator synchronisation, all dirty flags cleared;
- `win_draw_item` — full render of a single object in `O(1)`;
- `win_update` — differential pass: repaints only records with
  `WIN_IT_DIRTY` (controls with internal `last_*` fields repaint only the
  difference), clears the flags, returns the count.

The typical loop: handle an event → change control state → set
`WIN_IT_DIRTY` → `win_update`.

### Modal windows (backstore)

The application allocates 1..4 EMM pages (`DSS GETMEM #3D` →
`BIOS EMM_FN5 #C5`) and hands them to `win_set_backstore`. `win_open`
always saves the background under the window, paints it and remembers the
origin; `win_close` restores strictly LIFO (depth up to 4). The save is
bound to a screen: `win_set_screen` between open and close cannot
misdirect the restore. If the object list fails, `win_open` rolls back
atomically — no partially painted dialog remains. The pages are freed by
the application after `l_free`.

## 9. Events: `win_poll` and `win_track`

The `WinTrack` descriptor (32 bytes) belongs to the application and
holds: a `WinWindow` pointer (objects + origin; 0 — keyboard only), the
`WinKey[]` hotkey table, options, event output fields and 8 bytes of
tracking state (zero it before the first call). The state lives with the
caller: two dialogs with two `WinTrack`s are fully independent.

- `win_poll` — one non-blocking iteration; with no event it returns
  `WIN_EV_NONE`. For applications with background work.
- `win_track` — blocks until an event; with `WIN_TRK_HALT` it executes
  `HALT` between iterations.

Options: `WIN_TRK_ANY_KEY` (report any key), `WIN_TRK_OUTSIDE` (click
outside all objects), `WIN_TRK_HALT`, `WIN_TRK_SHOW_CUR`,
`WIN_TRK_TAB_FOCUS`.

Events:

| Code | Name | When |
|---:|---|---|
| 0 | `WIN_EV_NONE` | `win_poll` only: nothing happened |
| 1 | `WIN_EV_LCLICK` | click (press+release inside the object); with `WIN_IT_REPEAT` — immediately on press |
| 2 | `WIN_EV_RCLICK` | right button over an object |
| 3 | `WIN_EV_REPEAT` | auto-repeat tick (pace: `repeat_delay`/`repeat_rate` in iterations) |
| 4 | `WIN_EV_HOTKEY` | key matched a `WinKey` record |
| 5 | `WIN_EV_KEY` | any key with `WIN_TRK_ANY_KEY`; raw ASCII/scan/modifiers |
| 6 | `WIN_EV_HOVER` | cursor entered an object with `WIN_IT_HOVER` |
| 7 | `WIN_EV_LEAVE` | cursor left such an object |
| 8 | `WIN_EV_OUTSIDE` | click outside all hit-objects (`id=#FF`) |
| 9 | `WIN_EV_FOCUS` | focus moved by Tab/Shift+Tab |
| 10 | `WIN_EV_CHANGE` | the library changed a checkbox/radio (already repainted) |

Additional event context is in `WinTrack` fields: the record `index`,
`part` (sub-area: scrollbar arrows/pages/thumb, listbox row), `item`
(listbox row index), mouse coordinates and buttons, `user_data`.

Zones are half-open (`x <= mx < x+width`); the hit-test walks items in
descending index order — the object drawn last receives the event first.

### Mouse and cursor

The mouse driver is initialised by the **application** (BIOS `RST #30`,
`C=0`) before the first poll; the library only calls
READ/SHOW/HIDE/LOAD CURSOR. `WIN_TRK_SHOW_CUR` makes `win_track` show the
cursor on entering its blocking loop and hide it before returning; a
`win_poll` client manages permanent visibility itself, and the flag
merely permits the library a paired HIDE/SHOW around its own repaints.
`win_set_cursor` switches arrow/wait or loads a custom sprite (up to
32×32, BIOS format).

### Keyboard focus

The source of truth is `WinWindow.focus`. Tab/Shift+Tab (with
`WIN_TRK_TAB_FOCUS`) cycle through records with `WIN_IT_FOCUSABLE`; the
indicator (dashes on a button and on a checkbox/radio caption, the cursor
row of a listbox, the text caret of an edit field) is drawn by the
library. Enter activates the focused button, Space toggles a
checkbox/radio, arrows move the selection inside a radio group. To move
focus programmatically, write `focus` and call `win_update`. A mouse
click on a `WIN_IT_FOCUSABLE` object moves focus as well.

## 10. Controls

### Edit field (`WinEdit`, 16 bytes)

The buffer is the source of truth (the library derives `len` itself); its
format follows `win_set_text_format` — ASCIIZ or a Pascal string, so the
buffer is directly compatible with a TPC `string[maxlen]`.
`win_edit_draw` paints the field (the caret is visible only with
`WIN_ED_FOCUS`); `win_edit` is modal editing: printable characters,
Backspace/Delete, Left/Right, Home/End, Ctrl+Left/Right by words, a
blinking caret, Esc rollback, and a click inside the field repositions
the caret. Exit codes: `WIN_ED_ENTER`, `WIN_ED_ESC`, `WIN_ED_TAB` (with a
`WinTrack` supplied, focus has already been moved), `WIN_ED_MOUSE` (the
mouse event is filled into the `WinTrack`). `WIN_ED_PASSWORD` renders
`*`.

### Listbox (`WinListbox`, 28 bytes)

Two storage modes: a plain array of `u16` string pointers (best for small
in-memory lists) or `WIN_LB_PAGED` — a table of 3-byte `WinTextRef`
records (`page`,`offset`) in an EMM page, with strings in any EMM pages
(up to 5461 entries). The number of visible rows derives from
`height/item_height`; with `WIN_LB_FRAME` the content is inset by 2 px.
Rendering is differential: moving the cursor repaints two rows, moving
`first` by one row scrolls the content with an accelerator copy. A linked
`scrollbar` is only synchronised field-wise — the scrollbar itself is a
separate `WIN_T_SCROLLBAR` record (recommended right after the listbox).
Navigation belongs to the application: events deliver the row index, the
application changes `first/cursor`, sets dirty, calls `win_update`.

### Scrollbar (`WinScrollbar`, 22 bytes)

`init` is called once (validation + full-render sentinel); `draw`
recomputes the thumb from `first/visible/total` itself and repaints only
the difference. `WIN_SB_ARROWS` adds end buttons serviced by the control
itself; the hit-test reports the sub-area in `WinTrack.part` (arrows,
pages, thumb). Orientation: `WIN_SB_HORIZONTAL`.

### Progress bar (`WinProgress`, 12 bytes)

The unit is a percentage `0..100` (the `percent` field); scaling its own
counter is the application's job. `init` once; `draw` incrementally
paints only the strip between the previous and the new boundary.

### Icons (`WinIcon`, 12 bytes)

Cells of 8×8 (64 bytes, 256 slots/page) or 16×16 (256 bytes, 64 slots)
live in application-owned EMM pages; the descriptor addresses them by
`page`+`slot`. Pixels are full 8-bit palette indices; with
`WIN_ICO_KEYED` the byte `#FF` is transparent (in hardware, via VRAM
alias `#58`; the DRAM mirror stays correct for backstore). The packer
`tools/winiconpack.py` builds a `WIP1` file plus asm/C/Pascal manifests;
the application's loader allocates the pages, copies the payload and
patches physical page numbers into descriptors.

### Checkbox and radio button (`WinChoice`, 14 bytes)

A shared structure: geometry (13×10 minimum), `attr`, flags
(`WIN_CH_CHECKED`, `WIN_CH_DISABLED`), `group` (0 for a checkbox; for a
radio — the group number scoped to one window), caption text. Click and
Space toggle the state; a radio clears the other members of its group;
arrows move the selection within the group; a group is one Tab stop.
After an actual change the library repaints the affected records itself
and returns `WIN_EV_CHANGE`. Programmatic change: write
`WIN_CH_CHECKED`, set `WIN_IT_DIRTY`, call `win_update` (group
exclusivity is then the application's responsibility).

## 11. Examples

Complete, buildable examples of one dialog — a panel, labels, an edit
field, a listbox with a scrollbar, OK/Cancel buttons, event polling:

- assembly — [examples/dialog.asm](examples/dialog.asm);
- SDCC — [examples/dialog.c](examples/dialog.c);
- Turbo Pascal — [examples/DIALOG.PAS](examples/DIALOG.PAS).

C (wrappers from `bind/win320.h`; `win320_bind(handle)` attaches them to
the loaded DLL, the `win320_libman_call` shim is supplied by the
application):

```c
static win_button_t ok = {40, 154, 72, 20, 0xff, 0, 0}; /* x,y,w,h,attr,flags,text */
static win_item_t items[7];
static win_window_t window = {32, 20, 256, 216, 0xff, 0, 7, 2, 0, 0xff, 0};
static win_track_t track;

win320_bind(handle);
win320_set_text_format(WIN_TXT_ASCIIZ);
win320_draw(&window);
for (;;) {
    if (win320_poll(&track)) break;          /* ABI error */
    if (track.event == WIN_EV_NONE) continue;/* background work goes here */
    if (track.id == ID_CANCEL) break;
    items[STATUS_INDEX].flags |= WIN_IT_DIRTY;
    win320_update(&window, &drawn);
}
```

Turbo Pascal (records from `bind/WIN320.INC`, calls through `LibCall`):

```pascal
OkButton.X := 40; OkButton.Y := 154; OkButton.Width := 72;
OkButton.Height := 20; OkButton.Attr := $FF; OkButton.Flags := 0;
OkButton.Text := addr(OkText);
{ EditBuffer : string[31] — the WIN_TXT_PASCAL format uses the length byte }
```

## 12. Constraints and safety

- The application selects mode `#81` itself; the library never changes
  the video mode or the visible screen.
- Recommended layout: the DLL in WIN3, the application in WIN0..WIN2.
  Work windows for temporary VRAM/font/backstore/icon mapping are chosen
  automatically (`WIN_WORK_AUTO`), excluding the DLL window and the
  current `SP` window; `win_set_work_windows` sets them explicitly.
- NMI must be excluded during the short DI mapping sections; the stack
  and the DLL must not live in WIN0 while it is being used.
- Do not print through the DSS console while mode `#81` is active: the
  text screen and font generator live in the same VRAM field, so console
  output corrupts the picture. Wait for keys silently (`DSS #30`) and
  print only after restoring the text mode.
- Hide the BIOS cursor before drawing over its area with direct calls
  (or keep it hidden while building the screen).

## 13. Build and verification

```sh
make -C win320 all        # DLL, visual test, bindings
make -C win320 verify     # L0 container check (with the font tail)
make -C win320 host-test  # python ABI and tooling tests
make -C win320 z80-test   # executes the DLL in an emulator
make -C win320 bindings   # SDCC wrapper
make -C win320 examples   # builds the examples
make -C win320 benchmark  # build/WINBENCH.EXE — hardware timing runs
make -C win320 release    # verify + tests + refresh WIN320.DLL/EXE
```

The build requires `sjasmplus`, Python 3, `z88dk-ticks`, SDCC for the
bindings, and the sibling `sources/libman` checkout. `WIN320.EXE` goes
next to `WIN320.DLL` and `ICONS.WIP` and walks every control screen on
both video buffers.
