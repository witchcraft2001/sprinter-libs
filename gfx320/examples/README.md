# GFX320 examples

- `../test.asm` is the complete sjasmplus/DSS visual example and hardware
  benchmark source.
- `sdcc/example.c` shows the flat C binding after the application has loaded
  the DLL and supplied `gfx320_libman_call`.
- `tpascal/example.pas` shows descriptor construction through byte offsets,
  avoiding Turbo Pascal record-layout assumptions.

All examples select DSS mode `#81` before drawing. Tile examples must allocate
DSS pages, obtain their physical page list through BIOS function `#C5`, and
pass that list to `gfx_set_page_table`.
