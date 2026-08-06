#ifndef GFX640_H
#define GFX640_H

typedef unsigned char gfx_u8;
typedef signed char gfx_i8;
typedef unsigned int gfx_u16;
typedef signed int gfx_i16;

enum {
    GFX_INIT = 0, GFX_FREE = 1, GFX_SET_VRAM_WINDOW = 2,
    GFX_GET_VERSION = 4, GFX_GET_CONFIG = 5,
    GFX_CLEAR = 6, GFX_FILL_RECT = 7, GFX_HLINE = 8, GFX_VLINE = 9,
    GFX_COPY_RECT = 10, GFX_COPY_BUFFER = 11, GFX_RESTORE_RECT = 12,
    GFX_PALETTE_LOAD256 = 13, GFX_PALETTE_LOAD_RANGE = 14,
    GFX_PALETTE_SET = 15, GFX_FADE_BEGIN = 16, GFX_FADE_STEP = 17,
    GFX_FADE_CANCEL = 18, GFX_SWAP_BUFFERS = 21,
    GFX_SET_PAGE_TABLE = 22, GFX_DRAW_TILE = 23,
    GFX_DRAW_TILE_FAST = 24, GFX_DRAW_TILE_SPAN = 25,
    GFX_DRAW_TILEMAP = 26, GFX_DRAW_METATILE = 27,
    GFX_DRAW_RECT = 28, GFX_PUT_PIXEL = 29, GFX_GET_PIXEL = 30,
    GFX_LINE = 31, GFX_MOVE_RECT = 32, GFX_SCROLL_RECT = 33,
    GFX_DRAW_TILE_LIST = 34, GFX_DRAW_TILE_CLIP = 35
};

enum {
    GFX_ERR_ARGUMENT = 0x10, GFX_ERR_VIDEO_MODE, GFX_ERR_WINDOW,
    GFX_ERR_PAGE, GFX_ERR_TILE, GFX_ERR_PALETTE, GFX_ERR_BUSY,
    GFX_ERR_UNSUPPORTED
};

enum {
    GFX_TARGET_BUF0 = 0, GFX_TARGET_BUF1 = 1,
    GFX_TARGET_FRONT = 2, GFX_TARGET_BACK = 3,
    GFX_VRAM_ONLY = 4, GFX_KEY_FF = 8,
    GFX_PAL_BUFFER0 = 1, GFX_PAL_BUFFER1 = 2, GFX_PAL_BOTH = 3,
    GFX_FADE_OUT = 0, GFX_FADE_IN = 1
};

enum {
    GFX_SCREEN_WIDTH = 640, GFX_SCREEN_HEIGHT = 256,
    GFX_TILE_WIDTH = 16, GFX_TILE_HEIGHT = 32,
    GFX_COLOR_MASK = 0x0f,
    GFX_LENGTH_MASK = 0x03ff,
    GFX_LENGTH_FLAGS_MASK = 0x3c00,
    GFX_LENGTH_FLAGS_SHIFT = 10
};

typedef struct {
    gfx_u8 a;
    gfx_u16 de;
    gfx_u16 ix;
    gfx_u16 iy;
} gfx640_regs_t;

typedef struct {
    gfx_u8 struct_size, required_mode;
    gfx_u16 width, height;
    gfx_u8 vram_window, source_window, code_window, mapping_flags;
    gfx_u16 capabilities;
    gfx_u8 tile_width, tile_height, tile_layout, reserved;
} gfx640_config_t;

typedef struct {
    gfx_u16 x;
    gfx_u8 y;
    gfx_u16 width, height;
    gfx_u8 color, flags, reserved[3];
} gfx640_rect_t;

typedef struct {
    gfx_u8 source, flags;
    gfx_u16 source_x;
    gfx_u8 source_y;
    gfx_u16 destination_x;
    gfx_u8 destination_y;
    gfx_u16 width, height;
} gfx640_copy_rect_t;

typedef struct {
    gfx_u16 x;
    gfx_u8 y;
    gfx_u16 width, height;
    gfx_u8 target;
} gfx640_restore_rect_t;

typedef struct {
    const gfx_u16 *refs;
    gfx_u16 count, x;
    gfx_u8 y, flags;
} gfx640_tile_span_t;

typedef struct {
    gfx_u16 ref, x;
    gfx_u8 y;
} gfx640_tile_item_t;

typedef struct {
    const gfx640_tile_item_t *items;
    gfx_u16 count;
    gfx_u8 flags, reserved[3];
} gfx640_tile_list_t;

typedef struct {
    const gfx_u16 *refs;
    gfx_u16 map_width, map_height, source_x, source_y;
    gfx_u16 draw_width, draw_height, destination_x;
    gfx_u8 destination_y, flags, reserved[2];
} gfx640_tilemap_t;

typedef struct {
    const gfx_u16 *refs;
    gfx_u8 width, height;
    gfx_u16 x;
    gfx_u8 y, flags;
} gfx640_metatile_t;

typedef struct {
    gfx_u16 x0;
    gfx_u8 y0;
    gfx_u16 x1;
    gfx_u8 y1, color, flags;
} gfx640_line_t;

typedef struct {
    gfx_u16 x;
    gfx_u8 y;
    gfx_u16 width, height;
    gfx_i16 dx, dy;
    gfx_u8 fill_color, flags, reserved[3];
} gfx640_scroll_rect_t;

/*
 * Platform shim supplied by the application/libman port. It returns a
 * manager error (0 for dispatched) and marshals A/DE/IX/IY through regs.
 */
gfx_u8 gfx640_libman_call(gfx_u8 handle, gfx_u8 entry, gfx640_regs_t *regs);

void gfx640_bind(gfx_u8 handle);
gfx_u8 gfx640_call(gfx_u8 entry, gfx640_regs_t *regs);
gfx_u8 gfx640_set_vram_window(gfx_u8 window);
gfx_u8 gfx640_get_version(gfx_u16 *version, gfx_u16 *capabilities);
gfx_u8 gfx640_get_config(gfx640_config_t *config);
gfx_u8 gfx640_clear(gfx_u8 color, gfx_u8 flags);
gfx_u8 gfx640_fill_rect(const gfx640_rect_t *rect);
gfx_u8 gfx640_hline(gfx_u16 x, gfx_u8 y, gfx_u16 length, gfx_u8 color, gfx_u8 flags);
gfx_u8 gfx640_vline(gfx_u16 x, gfx_u8 y, gfx_u16 length, gfx_u8 color, gfx_u8 flags);
gfx_u8 gfx640_copy_rect(const gfx640_copy_rect_t *rect);
gfx_u8 gfx640_copy_buffer(gfx_u8 source, gfx_u8 destination_flags);
gfx_u8 gfx640_restore_rect(const gfx640_restore_rect_t *rect);
gfx_u8 gfx640_palette_load256(const gfx_u8 *rgb, gfx_u8 mask);
gfx_u8 gfx640_palette_load_range(gfx_u8 first, gfx_u16 count, const gfx_u8 *rgb, gfx_u8 mask);
gfx_u8 gfx640_palette_set(gfx_u8 index, gfx_u8 r, gfx_u8 g, gfx_u8 b, gfx_u8 mask);
gfx_u8 gfx640_fade_begin(gfx_u8 direction, gfx_u8 duration, gfx_u8 mask);
gfx_u8 gfx640_fade_step(gfx_u8 *active);
gfx_u8 gfx640_fade_cancel(void);
gfx_u8 gfx640_swap_buffers(void);
gfx_u8 gfx640_set_page_table(const gfx_u8 *pages, gfx_u16 count);
gfx_u8 gfx640_draw_tile(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags);
gfx_u8 gfx640_draw_tile_fast(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags);
gfx_u8 gfx640_draw_tile_clip(gfx_u16 ref, gfx_u16 x, gfx_u8 y, gfx_u8 flags);
gfx_u8 gfx640_draw_tile_span(const gfx640_tile_span_t *span);
gfx_u8 gfx640_draw_tile_list(const gfx640_tile_list_t *list);
gfx_u8 gfx640_draw_tilemap(const gfx640_tilemap_t *map);
gfx_u8 gfx640_draw_metatile(const gfx640_metatile_t *metatile);
gfx_u8 gfx640_draw_rect(const gfx640_rect_t *rect);
gfx_u8 gfx640_put_pixel(gfx_u16 x, gfx_u8 y, gfx_u8 color, gfx_u8 flags);
gfx_u8 gfx640_get_pixel(gfx_u16 x, gfx_u8 y, gfx_u8 source, gfx_u8 *color);
gfx_u8 gfx640_line(const gfx640_line_t *line);
gfx_u8 gfx640_move_rect(const gfx640_copy_rect_t *rect);
gfx_u8 gfx640_scroll_rect(const gfx640_scroll_rect_t *rect);

#endif
