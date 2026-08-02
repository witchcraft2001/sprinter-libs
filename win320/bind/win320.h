#ifndef WIN320_H
#define WIN320_H

typedef unsigned char win_u8;
typedef unsigned int win_u16;
typedef win_u16 win_ptr_t;

enum {
    WIN_SET_WORK_WINDOWS = 2, WIN_SET_SCREEN, WIN_GET_VERSION,
    WIN_GET_CONFIG, WIN_LOAD_FONT, WIN_SET_THEME, WIN_SET_TEXT_FORMAT,
    WIN_SET_ORIGIN, WIN_STYLE, WIN_FILL_RECT, WIN_FRAME, WIN_PANEL,
    WIN_SEPARATOR, WIN_INVERT_RECT, WIN_FOCUS_RECT, WIN_LABEL, WIN_BUTTON,
    WIN_DRAW, WIN_DRAW_ITEM, WIN_UPDATE, WIN_SET_BACKSTORE, WIN_OPEN,
    WIN_CLOSE, WIN_POLL, WIN_TRACK, WIN_WAIT_RELEASE, WIN_SET_CURSOR,
    WIN_EDIT_DRAW, WIN_EDIT, WIN_ICON, WIN_PROGRESS_INIT,
    WIN_PROGRESS_DRAW, WIN_SCROLLBAR_INIT, WIN_SCROLLBAR_DRAW,
    WIN_LISTBOX_DRAW, WIN_CHECKBOX, WIN_RADIOBUTTON,
    WIN_ENTRY_COUNT
};

enum {
    WIN_ERR_ARGUMENT = 0x20, WIN_ERR_VIDEO_MODE, WIN_ERR_WINDOW,
    WIN_ERR_BACKSTORE, WIN_ERR_DEPTH, WIN_ERR_UNSUPPORTED, WIN_ERR_BUSY,
    WIN_ERR_FONT, WIN_ERR_MEMORY
};

enum {
    WIN_WORK_AUTO = 0xff,
    WIN_TXT_ASCIIZ = 0, WIN_TXT_PASCAL = 1,
    WIN_RC_SUNKEN = 0x01, WIN_RC_VERTICAL = 0x02,
    WIN_LABEL_LEFT = 0, WIN_LABEL_CENTER = 1, WIN_LABEL_RIGHT = 2,
    WIN_LABEL_ALIGN_MASK = 0x03, WIN_LABEL_FILL = 0x04,
    WIN_LABEL_CLIP = 0x08,
    WIN_BTN_GLYPH = 0x01, WIN_BTN_FOCUS = 0x02,
    WIN_BTN_PRESSED = 0x04, WIN_BTN_DISABLED = 0x08,
    WIN_WND_NOPANEL = 0x01, WIN_WND_SUNKEN = 0x02,
    WIN_IT_DIRTY = 0x01, WIN_IT_HIDDEN = 0x02,
    WIN_IT_DISABLED = 0x04, WIN_IT_HIT = 0x08,
    WIN_IT_FOCUSABLE = 0x10, WIN_IT_PRESS = 0x20,
    WIN_IT_REPEAT = 0x40, WIN_IT_HOVER = 0x80,
    WIN_TRK_ANY_KEY = 0x01, WIN_TRK_OUTSIDE = 0x02,
    WIN_TRK_HALT = 0x04, WIN_TRK_SHOW_CUR = 0x08,
    WIN_TRK_TAB_FOCUS = 0x10,
    WIN_ED_FRAME = 0x01, WIN_ED_FOCUS = 0x02,
    WIN_ED_PASSWORD = 0x04,
    WIN_CH_CHECKED = 0x01, WIN_CH_FOCUS = 0x02,
    WIN_CH_DISABLED = 0x04,
    WIN_ICO_KEYED = 0x01, WIN_PG_FRAME = 0x01,
    WIN_SB_HORIZONTAL = 0x01, WIN_SB_ARROWS = 0x02,
    WIN_LB_FRAME = 0x01, WIN_LB_NOCURSOR = 0x02,
    WIN_LB_FOCUS = 0x04, WIN_LB_PAGED = 0x08,
    WIN_STYLE_PALETTE = 0x01, WIN_STYLE_CLEAR = 0x02,
    WIN_STYLE_BOTH = 0x04
};

enum {
    WIN_T_NONE = 0, WIN_T_LABEL, WIN_T_FILL, WIN_T_FRAME, WIN_T_PANEL,
    WIN_T_SEPARATOR, WIN_T_BUTTON, WIN_T_ICON, WIN_T_PROGRESS,
    WIN_T_SCROLLBAR, WIN_T_LISTBOX, WIN_T_EDIT, WIN_T_ZONE,
    WIN_T_CHECKBOX, WIN_T_RADIOBUTTON
};

enum {
    WIN_EV_NONE = 0, WIN_EV_LCLICK, WIN_EV_RCLICK, WIN_EV_REPEAT,
    WIN_EV_HOTKEY, WIN_EV_KEY, WIN_EV_HOVER, WIN_EV_LEAVE,
    WIN_EV_OUTSIDE, WIN_EV_FOCUS, WIN_EV_CHANGE
};

enum {
    WIN_ED_ENTER = 0, WIN_ED_ESC, WIN_ED_TAB, WIN_ED_MOUSE,
    WIN_SB_PART_BACK = 1, WIN_SB_PART_FORWARD, WIN_SB_PART_PAGE_BACK,
    WIN_SB_PART_PAGE_FORWARD, WIN_SB_PART_THUMB,
    WIN_LB_PART_ROW = 1
};

enum {
    WIN_CAP_CORE = 0x0001, WIN_CAP_EDIT = 0x0002,
    WIN_CAP_LISTBOX = 0x0004, WIN_CAP_SCROLLBAR = 0x0008,
    WIN_CAP_PROGRESS = 0x0010, WIN_CAP_ICON = 0x0020,
    WIN_CAP_FOCUS = 0x0040, WIN_CAP_PASCAL_STR = 0x0080,
    WIN_CAP_CHECKBOX = 0x0100, WIN_CAP_RADIOBUTTON = 0x0200
};

#define WIN_REPEAT_DELAY 12
#define WIN_REPEAT_RATE 3
#ifndef WIN_DI_BUDGET_US
#define WIN_DI_BUDGET_US 200
#endif
#define WIN_BACKSTORE_MAX_PAGES 4
#define WIN_BACKSTORE_MAX_DEPTH 4
#define WIN_BACKSTORE_CHUNK 256

typedef struct { win_u8 a; win_u16 de, ix, iy; } win320_regs_t;

typedef struct {
    win_u8 light, shadow, face, desktop, text, text_disabled;
    win_u8 field_bg, field_fg, cursor_bg, cursor_fg;
    win_u8 progress, progress_fill, scroll_track, scroll_thumb;
    win_u8 focus_mask, reserved;
} win_theme_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 color, flags;
} win_rect_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 attr, flags;
    win_ptr_t text;
} win_label_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 attr, flags;
    win_ptr_t text;
} win_button_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 color, flags, count, focus;
    win_ptr_t items;
    win_u8 last_focus, reserved;
} win_window_t;

typedef struct {
    win_u8 type, flags, id, reserved;
    win_ptr_t control, user_data;
} win_item_t;

typedef struct { win_u8 ascii, scan, mods, id; } win_key_t;

typedef struct {
    win_ptr_t window, keys;
    win_u8 key_count, options, event, id, index, part;
    win_u16 mouse_x;
    win_u8 mouse_y, buttons, key_ascii, key_scan, key_mods, reserved;
    win_ptr_t item, user_data;
    win_u8 repeat_delay, repeat_rate, state[8];
} win_track_t;

typedef struct { win_u8 width, height, hot_x, hot_y; } win_cursor_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 attr, flags, maxlen, len, cursor, scroll;
    win_ptr_t buffer;
} win_edit_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 attr, flags, group, reserved;
    win_ptr_t text;
} win_choice_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 flags, page, slot, reserved;
} win_icon_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 flags, percent;
    win_u16 last_px;
} win_progress_t;

typedef struct {
    win_u16 x, y, width, height, visible, total, first;
    win_u8 flags, reserved;
    win_u16 thumb_pos, thumb_len, last_pos;
} win_scrollbar_t;

typedef struct { win_u8 page; win_u16 offset; } win_text_ref_t;

typedef struct {
    win_u16 x, y, width, height;
    win_u8 item_height, attr_normal, attr_cursor, flags;
    win_u16 total, first, cursor;
    win_ptr_t items;
    win_u8 items_page, reserved;
    win_ptr_t scrollbar;
    win_u16 last_first, last_cursor;
} win_listbox_t;

typedef struct {
    win_u8 struct_size, dss_mode;
    win_u16 width, height;
    win_u8 vram_window, code_window, screen, backstore_pages;
    win_u8 backstore_depth, font_height;
    win_u16 capabilities;
    win_u8 font_page, data_window;
    win_u16 origin_x;
    win_u8 origin_y, text_format;
} win_config_t;

/* Platform shim supplied by the application/libman port. */
win_u8 win320_libman_call(win_u8 handle, win_u8 entry, win320_regs_t *regs);

void win320_bind(win_u8 handle);
win_u8 win320_call(win_u8 entry, win320_regs_t *regs);
win_u8 win320_set_work_windows(win_u8 data_window, win_u8 vram_window);
win_u8 win320_set_screen(win_u8 screen);
win_u8 win320_get_version(win_u16 *abi, win_u16 *capabilities);
win_u8 win320_get_config(win_config_t *config);
win_u8 win320_load_font(const char *path);
win_u8 win320_set_theme(const win_theme_t *theme);
win_u8 win320_set_text_format(win_u8 format);
win_u8 win320_set_origin(win_u16 x, win_u8 y);
win_u8 win320_style(win_u8 desktop_color, win_u8 flags);
win_u8 win320_fill_rect(const win_rect_t *rect);
win_u8 win320_frame(const win_rect_t *rect);
win_u8 win320_panel(const win_rect_t *rect);
win_u8 win320_separator(const win_rect_t *rect);
win_u8 win320_invert_rect(const win_rect_t *rect);
win_u8 win320_focus_rect(const win_rect_t *rect);
win_u8 win320_label(const win_label_t *label);
win_u8 win320_button(const win_button_t *button);
win_u8 win320_draw(win_window_t *window);
win_u8 win320_draw_item(win_window_t *window, win_u16 index);
win_u8 win320_update(win_window_t *window, win_u8 *drawn);
win_u8 win320_set_backstore(const win_u8 *pages, win_u16 count);
win_u8 win320_open(win_window_t *window);
win_u8 win320_close(void);
win_u8 win320_poll(win_track_t *track);
win_u8 win320_track(win_track_t *track);
win_u8 win320_wait_release(void);
win_u8 win320_set_cursor(win_u8 kind, const win_cursor_t *cursor);
win_u8 win320_edit_draw(win_edit_t *edit);
win_u8 win320_edit(win_edit_t *edit, win_track_t *track, win_u8 *reason);
win_u8 win320_icon(const win_icon_t *icon);
win_u8 win320_progress_init(win_progress_t *progress);
win_u8 win320_progress_draw(win_progress_t *progress);
win_u8 win320_scrollbar_init(win_scrollbar_t *scrollbar);
win_u8 win320_scrollbar_draw(win_scrollbar_t *scrollbar);
win_u8 win320_listbox_draw(win_listbox_t *listbox);
win_u8 win320_checkbox(win_choice_t *choice);
win_u8 win320_radiobutton(win_choice_t *choice);

#endif
