# SDCC binding

`gfx320.h` exposes flat C wrappers while `gfx320.c` marshals the GFX320
register ABI. Build it with the same SDCC memory model as the application.

The application supplies one platform hook:

```c
gfx_u8 gfx320_libman_call(gfx_u8 handle, gfx_u8 entry, gfx320_regs_t *regs);
```

It must dispatch through the application's libman loader and preserve the four
register groups `A/DE/IX/IY`. Its return value is the manager error (`0` when
the DLL was dispatched); the DLL status remains in `regs->a`. This separation
matches libman 1.2/1.3. Descriptor arrays and tile lists must live in writable
`_DATA`/`_BSS`, not paged `const` storage or WIN0.

The repository Makefile builds `gfx320.lib`; the loader hook remains
application-specific because the SDK has no canonical libman runtime.
