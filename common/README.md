# Shared graphics assembly

These include files hold the byte-identical Sprinter accelerator, window,
palette, fade and libman-loader paths used by GFX320 and GFX640. Pixel layout,
geometry, validation and tile loops remain in each library's own assembly
core.

Changes here affect both modes and must be followed by each module's `all`,
`verify`, `host-test` and `z80-test` targets.
