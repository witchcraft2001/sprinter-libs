# Shared graphics assembly

These include files hold the byte-identical Sprinter accelerator, window,
palette, fade and libman-loader paths used by GFX320 and GFX640. Pixel layout,
geometry, validation and tile loops remain in each library's own assembly
core.

`afnt_target.inc` implements the shared AFNT320/AFNT640 symbolic
`BUF0`/`BUF1`/`FRONT`/`BACK` target state machine. `afnt_runtime.inc` provides
their common current-stack-window check and caller-IFF preservation helpers.

Changes here affect both modes and must be followed by each module's `all`,
`verify`, `host-test` and `z80-test` targets.
