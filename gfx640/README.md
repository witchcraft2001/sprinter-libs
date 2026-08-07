# GFX640

Русская версия: [README.ru.md](README.ru.md).

`GFX640.DLL` is an accelerated 2D library for Sprinter DSS mode `#82`
(640×256, packed 4bpp). Public coordinates are pixels, colours are `0..15`,
and the two screen buffers still occupy 320 bytes per scanline at offsets
`#000` and `#140`.

The ABI deliberately mirrors GFX320 for entries `0..35`, register assignments,
descriptor sizes, target/source flags, page table, palette and fade interfaces.
Entries `36..41` add exact per-pixel tile transparency. It is a separate
implementation; GFX320 remains an 8bpp mode-`#81` library.

## Deliverables

| File | Purpose |
|---|---|
| `GFX640.DLL` | release L0 library |
| `GFX640.EXE` | visual hardware test |
| `gfx640.inc` | sjasmplus ABI constants and descriptor offsets |
| `bindings/sdcc/gfx640.h`, `gfx640.lib` | SDCC binding |
| `bindings/tpascal/GFX640.INC` | Turbo Pascal constants/helpers |
| `tools/tilepack.py` | indexed PNG/BMP → packed tile pages |
| `specs.md` | complete ABI and hardware contract |
| `BENCHMARK.md` | on-machine timing harness |

## Packed-pixel rules

- A byte stores two pixels: high nibble is the even/left pixel, low nibble is
  the odd/right pixel.
- `fill_rect`, `draw_rect` and `hline` require even `x` and width/length.
  Copy/move/restore require even source X, destination X and width. Scroll
  requires even X, width and `dx`. Every safe tile entry requires even
  destination X. Misalignment returns `GFX_ERR_ARGUMENT`.
- `put_pixel`, `get_pixel`, `vline` and arbitrary Bresenham lines accept any
  X, including `638` and `639`, and use nibble read-modify-write.
- Colours above 15 return `GFX_ERR_ARGUMENT`.
- `GFX_KEY_FF` keeps its hardware byte meaning: `#FF` skips a pair of colour-15
  pixels. Solid primitives reject KEY. `put_pixel(KEY_FF, color=15)` is a
  successful no-op.
- The `*_TRANSPARENT` tile entries extend KEY to individual nibbles: `#F?` and
  `#?F` preserve the corresponding destination pixel from the DRAM mirror,
  while `#FF` still uses the hardware key. Without KEY they use the ordinary
  accelerated path and colour 15 is opaque.
- A partial `GFX_VRAM_ONLY` write gets the untouched neighbour nibble from the
  DRAM mirror. Consequently, a neighbour previously changed only in VRAM can
  be restored from the mirror. This is intentional ABI behaviour.

`hline` and `vline` pack a 10-bit length and four flags into `DE`:

```text
DE = (length & #03FF) | ((flags & #0F) << 10)
```

The SDCC wrapper performs this packing. Assembly constants
`GFX_LENGTH_MASK`, `GFX_LENGTH_FLAGS_MASK` and `GFX_LENGTH_FLAGS_SHIFT` are
provided in `gfx640.inc`.

## Tiles

A tile is 32×16 pixels, or 16 rows of sixteen packed bytes, always 256 bytes.
There are 64 tile slots in a 16-KB page and `TileRef` remains `(slot,page)`.
The full screen grid is 20×16 tiles. Safe full-tile drawing accepts
`x<=608`, `y<=240` and even X; clipped entries clip only the right and bottom
edges while retaining a sixteen-byte source stride.

The packer accepts indexed PNG/BMP input whose pixel indices are all `0..15`:

```sh
python3 gfx640/tools/tilepack.py assets.png build/tiles \
  --keyed --transparent-index 0 --nonempty-rows \
  --metatile-width 2 --metatile-height 2
```

For keyed output each colour-15 pixel is transparent, including only one half
of a packed pair. Nonempty-row masks are little-endian 16-bit values, and each
emitted page is exactly 16 KB.

## Calling and building

The application selects DSS mode `#82`; the DLL never switches video mode.
Calls use libman with arguments in `A`, `DE`, `IX`, `IY`. After a successful
dispatcher call, `A=0` means success and `A=#10..#17` is a GFX status.
See [specs.md](specs.md) and [examples](examples/README.md).

```sh
make -C gfx640 all
make -C gfx640 verify
make -C gfx640 host-test
make -C gfx640 z80-test
make -C gfx640 benchmark
make -C gfx640 release BUILD_DATE=YYYY-MM-DD
```

The L0 image is asserted to fit one 16-KB mapping window. Build products stay
under `build/`; `release` refreshes the tracked DLL, EXE and SDCC library.
Tile operations temporarily map their source into WIN0 under `DI`, so code
and stack must remain outside WIN0. All drawing restores the selected page,
`PORT_Y=#C0`, and the caller's interrupt state.

GFX640 is non-reentrant and no entry may be called directly from an ISR. A
frame ISR should only update a flag/counter; call `gfx_swap_buffers` and
`gfx_fade_step` from the main loop after observing that frame event.

## Hardware verification

Run `GFX640.EXE` beside the matching DLL. It selects `#82` and covers packed
nibbles at X=`638/639`, primitives, opaque/hardware-keyed/exact-transparent and
clipped tiles, span/list/map/metatile drawing, copy/move/scroll, both buffers and
palette/fade. Rendering changes still require a real Sprinter check; use
[BENCHMARK.md](BENCHMARK.md) for the DI-budget measurement.
