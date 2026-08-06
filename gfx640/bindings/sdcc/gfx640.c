#include "gfx640.h"

typedef char assert_config_size[(sizeof(gfx640_config_t) == 16) ? 1 : -1];
typedef char assert_rect_size[(sizeof(gfx640_rect_t) == 12) ? 1 : -1];
typedef char assert_copy_size[(sizeof(gfx640_copy_rect_t) == 12) ? 1 : -1];
typedef char assert_restore_size[(sizeof(gfx640_restore_rect_t) == 8) ? 1 : -1];
typedef char assert_span_size[(sizeof(gfx640_tile_span_t) == 8) ? 1 : -1];
typedef char assert_item_size[(sizeof(gfx640_tile_item_t) == 5) ? 1 : -1];
typedef char assert_list_size[(sizeof(gfx640_tile_list_t) == 8) ? 1 : -1];
typedef char assert_tilemap_size[(sizeof(gfx640_tilemap_t) == 20) ? 1 : -1];
typedef char assert_metatile_size[(sizeof(gfx640_metatile_t) == 8) ? 1 : -1];
typedef char assert_line_size[(sizeof(gfx640_line_t) == 8) ? 1 : -1];
typedef char assert_scroll_size[(sizeof(gfx640_scroll_rect_t) == 16) ? 1 : -1];

static gfx_u8 bound_handle;

void gfx640_bind(gfx_u8 handle) { bound_handle = handle; }

gfx_u8 gfx640_call(gfx_u8 entry, gfx640_regs_t *regs) {
    gfx_u8 manager_error = gfx640_libman_call(bound_handle, entry, regs);
    return manager_error ? manager_error : regs->a;
}

static gfx_u8 descriptor_call(gfx_u8 entry, const void *descriptor) {
    gfx640_regs_t regs = {0, (gfx_u16)descriptor, 0, 0};
    return gfx640_call(entry, &regs);
}

gfx_u8 gfx640_set_vram_window(gfx_u8 window) {
    gfx640_regs_t regs = {0, window, 0, 0};
    return gfx640_call(GFX_SET_VRAM_WINDOW, &regs);
}

gfx_u8 gfx640_get_version(gfx_u16 *version, gfx_u16 *capabilities) {
    gfx640_regs_t regs = {0, 0, 0, 0};
    gfx_u8 status = gfx640_call(GFX_GET_VERSION, &regs);
    if (!status) {
        if (version) *version = regs.de;
        if (capabilities) *capabilities = regs.ix;
    }
    return status;
}

gfx_u8 gfx640_get_config(gfx640_config_t *config) {
    gfx640_regs_t regs = {0, (gfx_u16)config, 0, 0};
    config->struct_size = sizeof(*config);
    return gfx640_call(GFX_GET_CONFIG, &regs);
}

gfx_u8 gfx640_clear(gfx_u8 color, gfx_u8 flags) {
    gfx640_regs_t regs = {color, flags, 0, 0};
    return gfx640_call(GFX_CLEAR, &regs);
}

gfx_u8 gfx640_fill_rect(const gfx640_rect_t *rect) {
    return descriptor_call(GFX_FILL_RECT, rect);
}

static gfx_u8 line_axis(gfx_u8 entry, gfx_u16 x, gfx_u8 y, gfx_u16 length,
                        gfx_u8 color, gfx_u8 flags) {
    gfx640_regs_t regs;
    if (length > GFX_LENGTH_MASK || flags > 0x0f) return GFX_ERR_ARGUMENT;
    regs.a = color;
    regs.de = (gfx_u16)(length | ((gfx_u16)flags << GFX_LENGTH_FLAGS_SHIFT));
    regs.ix = x;
    regs.iy = y;
    return gfx640_call(entry, &regs);
}

gfx_u8 gfx640_hline(gfx_u16 x, gfx_u8 y, gfx_u16 length, gfx_u8 color, gfx_u8 flags) {
    return line_axis(GFX_HLINE, x, y, length, color, flags);
}

gfx_u8 gfx640_vline(gfx_u16 x, gfx_u8 y, gfx_u16 length, gfx_u8 color, gfx_u8 flags) {
    return line_axis(GFX_VLINE, x, y, length, color, flags);
}

gfx_u8 gfx640_copy_rect(const gfx640_copy_rect_t *rect) { return descriptor_call(GFX_COPY_RECT, rect); }
gfx_u8 gfx640_restore_rect(const gfx640_restore_rect_t *rect) { return descriptor_call(GFX_RESTORE_RECT, rect); }
gfx_u8 gfx640_draw_tile_span(const gfx640_tile_span_t *span) { return descriptor_call(GFX_DRAW_TILE_SPAN, span); }
gfx_u8 gfx640_draw_tile_list(const gfx640_tile_list_t *list) { return descriptor_call(GFX_DRAW_TILE_LIST, list); }
gfx_u8 gfx640_draw_tilemap(const gfx640_tilemap_t *map) { return descriptor_call(GFX_DRAW_TILEMAP, map); }
gfx_u8 gfx640_draw_metatile(const gfx640_metatile_t *metatile) { return descriptor_call(GFX_DRAW_METATILE, metatile); }
gfx_u8 gfx640_draw_rect(const gfx640_rect_t *rect) { return descriptor_call(GFX_DRAW_RECT, rect); }
gfx_u8 gfx640_line(const gfx640_line_t *line) { return descriptor_call(GFX_LINE, line); }
gfx_u8 gfx640_move_rect(const gfx640_copy_rect_t *rect) { return descriptor_call(GFX_MOVE_RECT, rect); }
gfx_u8 gfx640_scroll_rect(const gfx640_scroll_rect_t *rect) { return descriptor_call(GFX_SCROLL_RECT, rect); }

gfx_u8 gfx640_copy_buffer(gfx_u8 source, gfx_u8 flags) {
    gfx640_regs_t regs = {0, (gfx_u16)(((gfx_u16)source << 8) | flags), 0, 0};
    return gfx640_call(GFX_COPY_BUFFER, &regs);
}

gfx_u8 gfx640_palette_load256(const gfx_u8 *rgb, gfx_u8 mask) {
    gfx640_regs_t regs = {mask, (gfx_u16)rgb, 0, 0};
    return gfx640_call(GFX_PALETTE_LOAD256, &regs);
}

gfx_u8 gfx640_palette_load_range(gfx_u8 first, gfx_u16 count, const gfx_u8 *rgb, gfx_u8 mask) {
    if (count > 256 || (gfx_u16)first + count > 256) return GFX_ERR_ARGUMENT;
    gfx640_regs_t regs = {first, (gfx_u16)rgb,
        (gfx_u16)((count & 0x1ff) | ((gfx_u16)(mask & 3) << 9)), 0};
    return gfx640_call(GFX_PALETTE_LOAD_RANGE, &regs);
}

gfx_u8 gfx640_palette_set(gfx_u8 index, gfx_u8 r, gfx_u8 g, gfx_u8 b, gfx_u8 mask) {
    gfx640_regs_t regs = {index, (gfx_u16)(((gfx_u16)r << 8) | g),
        (gfx_u16)(((gfx_u16)mask << 8) | b), 0};
    return gfx640_call(GFX_PALETTE_SET, &regs);
}

gfx_u8 gfx640_fade_begin(gfx_u8 direction, gfx_u8 duration, gfx_u8 mask) {
    gfx640_regs_t regs = {direction, (gfx_u16)(((gfx_u16)duration << 8) | mask), 0, 0};
    return gfx640_call(GFX_FADE_BEGIN, &regs);
}

gfx_u8 gfx640_fade_step(gfx_u8 *active) {
    gfx640_regs_t regs = {0, 0, 0, 0};
    gfx_u8 status = gfx640_call(GFX_FADE_STEP, &regs);
    if (!status && active) *active = (gfx_u8)regs.de;
    return status;
}

gfx_u8 gfx640_fade_cancel(void) {
    gfx640_regs_t regs = {0, 0, 0, 0};
    return gfx640_call(GFX_FADE_CANCEL, &regs);
}

gfx_u8 gfx640_swap_buffers(void) {
    gfx640_regs_t regs = {0, 0, 0, 0};
    return gfx640_call(GFX_SWAP_BUFFERS, &regs);
}

gfx_u8 gfx640_set_page_table(const gfx_u8 *pages, gfx_u16 count) {
    gfx640_regs_t regs = {0, (gfx_u16)pages, count, 0};
    return gfx640_call(GFX_SET_PAGE_TABLE, &regs);
}

static gfx_u8 tile_call(gfx_u8 entry, gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags) {
    gfx640_regs_t regs = {flags, ref, x, y};
    return gfx640_call(entry, &regs);
}

gfx_u8 gfx640_draw_tile(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags) {
    return tile_call(GFX_DRAW_TILE, ref, x, y, flags);
}

gfx_u8 gfx640_draw_tile_fast(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags) {
    return tile_call(GFX_DRAW_TILE_FAST, ref, x, y, flags);
}

gfx_u8 gfx640_draw_tile_clip(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags) {
    return tile_call(GFX_DRAW_TILE_CLIP, ref, x, y, flags);
}

gfx_u8 gfx640_put_pixel(gfx_u16 x, gfx_u8 y, gfx_u8 color, gfx_u8 flags) {
    gfx640_regs_t regs = {color, flags, x, y};
    return gfx640_call(GFX_PUT_PIXEL, &regs);
}

gfx_u8 gfx640_get_pixel(gfx_u16 x, gfx_u8 y, gfx_u8 source, gfx_u8 *color) {
    gfx640_regs_t regs = {0, source, x, y};
    gfx_u8 status = gfx640_call(GFX_GET_PIXEL, &regs);
    if (!status && color) *color = (gfx_u8)regs.de;
    return status;
}
