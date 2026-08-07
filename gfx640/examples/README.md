# GFX640 examples

- `../test.asm` is the complete sjasmplus/DSS visual example and hardware
  benchmark source.
- `sdcc/example.c` shows the flat C binding after the application has loaded
  the DLL and supplied `gfx640_libman_call`.
- `tpascal/example.pas` shows descriptor construction through byte offsets,
  avoiding Turbo Pascal record-layout assumptions.

All examples select DSS mode `#82` before drawing. Tile examples must allocate
DSS pages, obtain their physical page list through BIOS function `#C5`, and
pass that list to `gfx_set_page_table`.

GFX640 coordinates are pixels. Byte-oriented primitives use even X/width,
while pixels, vertical lines and arbitrary lines may use any X. Tile images
are indexed 0..15, packed high-nibble first into 32×16/256-byte payloads.
Use the `*_transparent` entry with `GFX_KEY_FF` when only one pixel of a
packed pair may be transparent.
