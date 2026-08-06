# SDCC binding

`gfx640.h` exposes flat C wrappers while `gfx640.c` marshals the GFX640
register ABI. Build it with the same SDCC memory model as the application.

The application supplies one platform hook:

```c
gfx_u8 gfx640_libman_call(gfx_u8 handle, gfx_u8 entry, gfx640_regs_t *regs);
```

It must dispatch through the application's libman loader and preserve the four
register groups `A/DE/IX/IY`. Its return value is the manager error (`0` when
the DLL was dispatched); the DLL status remains in `regs->a`. This separation
matches libman 1.2/1.3. Descriptor arrays and tile lists must live in writable
`_DATA`/`_BSS`, not paged `const` storage or WIN0.

The DLL is non-reentrant. Do not call these wrappers from an ISR; let the ISR
update a frame flag/counter and call `gfx640_fade_step` or
`gfx640_swap_buffers` from the main loop.

The repository Makefile builds `gfx640.lib`; the loader hook remains
application-specific because the SDK has no canonical libman runtime.
