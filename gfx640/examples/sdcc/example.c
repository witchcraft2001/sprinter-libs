#include "../../bindings/sdcc/gfx640.h"

/* Loader-specific code supplies gfx640_libman_call and the loaded handle. */
gfx_u8 draw_gfx640_example(gfx_u8 handle) {
    gfx640_config_t config;
    gfx640_rect_t panel = {
        16, 16, 608, 48, 4, GFX_TARGET_FRONT, {0, 0, 0}
    };
    gfx_u8 status;

    gfx640_bind(handle);
    status = gfx640_get_config(&config);
    if (status) return status;
    if (config.required_mode != 0x82 || config.width != 640 ||
        config.tile_width != 16 || config.tile_height != 32)
        return GFX_ERR_ARGUMENT;
    status = gfx640_clear(0, GFX_TARGET_FRONT);
    if (status) return status;
    status = gfx640_fill_rect(&panel);
    if (status) return status;
    return gfx640_hline(16, 80, 608, 15, GFX_TARGET_FRONT);
}
