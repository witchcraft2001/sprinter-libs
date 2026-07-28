# GFX320

Русская версия этого документа: [README.ru.md](README.ru.md).

`GFX320.DLL` is a 2D graphics library for the Sprinter in DSS mode `#81`
(320×256, 256 colours). It provides ready-made graphics services to programs
written in assembly, C, Pascal and any other language that can call DLLs
through libman: the application does not program the video controller, VRAM
pages, palette or blitter itself — it calls library functions by entry
number. Internally the library uses the Sprinter hardware accelerator, but
that is an implementation detail, not part of the ABI.

## Deliverables

| File | Purpose |
|---|---|
| `GFX320.DLL` | the library — the only file an application needs |
| `gfx320.inc` | public constants and descriptor offsets for sjasmplus |
| `bindings/sdcc/` | C header and library (SDCC) |
| `bindings/tpascal/` | Turbo Pascal include |
| `examples/` | C and Pascal call examples, see `examples/README.md` |
| `GFX320.EXE` | visual test of the library; applications do **not** need it |
| `specs.md` | full specification: register ABI and hardware contracts (Russian) |

## Functionality (ABI 1.0)

Entry numbers are in [gfx320.inc](gfx320.inc); complete signatures are in
[specs.md](specs.md) §7.

- **Init and configuration** — `gfx_init`/`gfx_free` (invoked by libman
  automatically), `gfx_set_vram_window` (2), `gfx_get_version` (4),
  `gfx_get_config` (5).
- **Fills and lines** — `gfx_clear` (6), `gfx_fill_rect` (7), `gfx_hline`
  (8), `gfx_vline` (9), `gfx_draw_rect` (28), `gfx_line` (31, Bresenham).
- **Pixels** — `gfx_put_pixel` (29), `gfx_get_pixel` (30).
- **Double buffering and copying** — `gfx_copy_rect` (10),
  `gfx_copy_buffer` (11), `gfx_restore_rect` (12, background restore from
  the DRAM mirror), `gfx_swap_buffers` (21), `gfx_move_rect` (32),
  `gfx_scroll_rect` (33).
- **RGB8 palette** — `gfx_palette_load256` (13), `gfx_palette_load_range`
  (14), `gfx_palette_set` (15).
- **Fade** — `gfx_fade_begin` (16), `gfx_fade_step` (17), `gfx_fade_cancel`
  (18): stepwise fade over 33 brightness levels; steps are driven by the
  application's frame ISR, the library never owns interrupts.
- **16×16 row-major tiles** — `gfx_set_page_table` (22), `gfx_draw_tile`
  (23), `gfx_draw_tile_fast` (24), `gfx_draw_tile_clip` (35), batched
  `gfx_draw_tile_span` (25), `gfx_draw_tile_list` (34), `gfx_draw_tilemap`
  (26), `gfx_draw_metatile` (27).
- **Transparency and mirror control** — `GFX_KEY_FF` (hardware skip of `#FF`
  bytes) and `GFX_VRAM_ONLY` (write past the DRAM mirror) flags on tiles and
  copies.

## Calling convention (ABI in brief)

The library is loaded by the libman loader
(`sources/libman/libman/libman.asm`; the `libman13.asm` name is a compatible
alias). The loader searches for the DLL beside the EXE by itself:

```asm
        ld hl,libname        ; "GFX320.DLL",0
        ld a,3               ; window for the DLL (WIN3)
        call LIBMAN.l_load
        jp c,load_error      ; reason in LIBMAN.l_reason / l_dss_error
        ld (handle),hl

        ld hl,(handle)
        ld a,0               ; function arguments: A, DE, IX, IY
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR       ; entry number from gfx320.inc
        call LIBMAN.l_call
        jp c,dispatch_error  ; libman dispatcher error
        or a
        jp nz,gfx_error      ; GFX320 status: 0 = success, #10..#17 = error
```

Rules:

- arguments travel in `A`, `DE`, `IX`, `IY`; larger structures go as a packed
  descriptor pointed to by `DE` (field offsets in `gfx320.inc`);
- function status returns in `A` (`0` success, `GFX_ERR_*` codes `#10..#17`);
  the CF flag belongs to the libman dispatcher — for entries `>=1` it is not
  part of the public ABI;
- the application selects mode `#81` before drawing; the library never
  changes the video mode;
- for tiles the application allocates DSS pages (`DSS #3D`), obtains their
  physical numbers (BIOS `#C5`) and passes the table to `gfx_set_page_table`.

Working examples: [examples/sdcc/example.c](examples/sdcc/example.c),
[examples/tpascal/example.pas](examples/tpascal/example.pas) and the complete
assembly scenario [test.asm](test.asm).

## Constraints and safety

- Tile calls temporarily map the source page into WIN0 under `DI`: the DLL
  and the current stack must live outside WIN0, and the application excludes
  NMI for the duration of the atomic tile operation.
- `GFX_VRAM_ONLY` drawing never reaches the DRAM mirror, so it is invisible
  to `get_pixel` and to copy/move/scroll sources.
- Do not print through the DSS console while mode `#81` is active: the text
  screen and font generator live in the same VRAM field, so console output
  corrupts the picture. Wait for keys silently (`DSS #30`) and print only
  after restoring the text mode.
- Full hardware contracts: [specs.md](specs.md) §15.

## Build and verification

```sh
make -C gfx320 all        # DLL, visual test, SDCC library
make -C gfx320 verify     # L0 container check
make -C gfx320 host-test  # python ABI and tile-packer tests
make -C gfx320 z80-test   # executes the DLL in an emulator at WIN1..WIN3
make -C gfx320 benchmark  # build/GFXBENCH.EXE
make -C gfx320 release    # verify + tests + refresh GFX320.DLL/EXE
```

The build requires `sjasmplus`, SDCC tools (`sdcc`, `sdar`),
`sprinter-mkdll` and the libman loader sources. By default the Makefile takes
the loader from the sibling `sources/libman` repository
(`../../libman/libman`); override with `LIBMAN_MKDLL=...` and
`LIBMAN_DIR=...`. Build output stays under `gfx320/build/`.

## Visual test

`GFX320.EXE` exists only to verify the library on hardware or in an
emulator: place it beside `GFX320.DLL` and run it. The test enables mode
`#81`, loads a palette, draws every primitive and tile path, exercises
buffer copying, background restore and fade, then waits for a key silently
and restores the original mode. Failures are printed with diagnostic codes
(`l_reason`/`l_dss_error`/GFX status/test stage) after returning to the text
mode.

## Benchmark

`build/GFXBENCH.EXE` is a separate build of the same test used **only for
timing**: the visual demo is skipped, the screen is cleared and four result
bars are drawn. Details and interpretation: [BENCHMARK.md](BENCHMARK.md).
Hardware measurements are required before enabling further rendering
optimizations.

## Tile packer

Install `requirements-dev.txt`, then convert an indexed PNG/BMP into tile
pages:

```sh
python3 gfx320/tools/tilepack.py assets.png build/tiles \
  --keyed --transparent-index 0 --nonempty-rows \
  --metatile-width 2 --metatile-height 2
```

The tool emits exact 16-KB `pageNN.bin` files, little-endian TileRefs,
row-major tilemap data, a 768-byte RGB palette and a JSON manifest.
