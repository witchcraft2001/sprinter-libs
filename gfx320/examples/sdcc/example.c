#include "../../bindings/sdcc/gfx320.h"

/* Loader-specific code supplies gfx320_libman_call and the loaded handle. */
gfx_u8 draw_gfx320_example(gfx_u8 handle) {
    gfx320_config_t config;
    gfx320_rect_t panel = {
        16, 16, 288, 48, 4, GFX_TARGET_FRONT, {0, 0, 0}
    };
    gfx_u8 status;

    gfx320_bind(handle);
    status = gfx320_get_config(&config);
    if (status) return status;
    status = gfx320_clear(0, GFX_TARGET_FRONT);
    if (status) return status;
    status = gfx320_fill_rect(&panel);
    if (status) return status;
    return gfx320_hline(16, 80, 288, 15, GFX_TARGET_FRONT);
}
