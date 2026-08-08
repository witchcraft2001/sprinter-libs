#include "win320.h"
#include <stddef.h>

typedef char assert_regs_size[(sizeof(win320_regs_t) == 7) ? 1 : -1];
typedef char assert_theme_size[(sizeof(win_theme_t) == 18) ? 1 : -1];
typedef char assert_rect_size[(sizeof(win_rect_t) == 10) ? 1 : -1];
typedef char assert_label_size[(sizeof(win_label_t) == 12) ? 1 : -1];
typedef char assert_button_size[(sizeof(win_button_t) == 12) ? 1 : -1];
typedef char assert_window_size[(sizeof(win_window_t) == 20) ? 1 : -1];
typedef char assert_item_size[(sizeof(win_item_t) == 8) ? 1 : -1];
typedef char assert_key_size[(sizeof(win_key_t) == 4) ? 1 : -1];
typedef char assert_track_size[(sizeof(win_track_t) == 32) ? 1 : -1];
typedef char assert_cursor_size[(sizeof(win_cursor_t) == 4) ? 1 : -1];
typedef char assert_edit_size[(sizeof(win_edit_t) == 16) ? 1 : -1];
typedef char assert_choice_size[(sizeof(win_choice_t) == 14) ? 1 : -1];
typedef char assert_icon_size[(sizeof(win_icon_t) == 12) ? 1 : -1];
typedef char assert_progress_size[(sizeof(win_progress_t) == 12) ? 1 : -1];
typedef char assert_scrollbar_size[(sizeof(win_scrollbar_t) == 22) ? 1 : -1];
typedef char assert_text_ref_size[(sizeof(win_text_ref_t) == 3) ? 1 : -1];
typedef char assert_listbox_size[(sizeof(win_listbox_t) == 28) ? 1 : -1];
typedef char assert_config_size[(sizeof(win_config_t) == 20) ? 1 : -1];
typedef char assert_rect_color_offset[(offsetof(win_rect_t, color) == 8) ? 1 : -1];
typedef char assert_label_text_offset[(offsetof(win_label_t, text) == 10) ? 1 : -1];
typedef char assert_window_items_offset[(offsetof(win_window_t, items) == 12) ? 1 : -1];
typedef char assert_window_title_offset[(offsetof(win_window_t, title) == 14) ? 1 : -1];
typedef char assert_window_title_attr_offset[(offsetof(win_window_t, title_attr) == 16) ? 1 : -1];
typedef char assert_window_last_focus_offset[(offsetof(win_window_t, last_focus) == 17) ? 1 : -1];
typedef char assert_item_control_offset[(offsetof(win_item_t, control) == 4) ? 1 : -1];
typedef char assert_track_mouse_x_offset[(offsetof(win_track_t, mouse_x) == 10) ? 1 : -1];
typedef char assert_track_item_offset[(offsetof(win_track_t, item) == 18) ? 1 : -1];
typedef char assert_track_state_offset[(offsetof(win_track_t, state) == 24) ? 1 : -1];
typedef char assert_edit_buffer_offset[(offsetof(win_edit_t, buffer) == 14) ? 1 : -1];
typedef char assert_choice_text_offset[(offsetof(win_choice_t, text) == 12) ? 1 : -1];
typedef char assert_progress_last_offset[(offsetof(win_progress_t, last_px) == 10) ? 1 : -1];
typedef char assert_scrollbar_thumb_offset[(offsetof(win_scrollbar_t, thumb_pos) == 16) ? 1 : -1];
typedef char assert_text_ref_offset[(offsetof(win_text_ref_t, offset) == 1) ? 1 : -1];
typedef char assert_listbox_scrollbar_offset[(offsetof(win_listbox_t, scrollbar) == 22) ? 1 : -1];
typedef char assert_config_caps_offset[(offsetof(win_config_t, capabilities) == 12) ? 1 : -1];
typedef char assert_config_origin_offset[(offsetof(win_config_t, origin_x) == 16) ? 1 : -1];

static win_u8 bound_handle;

void win320_bind(win_u8 handle) { bound_handle = handle; }

win_u8 win320_call(win_u8 entry, win320_regs_t *regs) {
    win_u8 manager_error = win320_libman_call(bound_handle, entry, regs);
    return manager_error ? manager_error : regs->a;
}

static win_u8 simple_call(win_u8 entry) {
    win320_regs_t regs = {0, 0, 0, 0};
    return win320_call(entry, &regs);
}

static win_u8 descriptor_call(win_u8 entry, const void *descriptor) {
    win320_regs_t regs = {0, (win_u16)descriptor, 0, 0};
    return win320_call(entry, &regs);
}

win_u8 win320_set_work_windows(win_u8 data_window, win_u8 vram_window) {
    win320_regs_t regs = {0, (win_u16)(((win_u16)data_window << 8) | vram_window), 0, 0};
    return win320_call(WIN_SET_WORK_WINDOWS, &regs);
}

win_u8 win320_set_screen(win_u8 screen) {
    win320_regs_t regs = {0, screen, 0, 0};
    return win320_call(WIN_SET_SCREEN, &regs);
}

win_u8 win320_get_version(win_u16 *abi, win_u16 *capabilities) {
    win320_regs_t regs = {0, 0, 0, 0};
    win_u8 status = win320_call(WIN_GET_VERSION, &regs);
    if (!status) {
        if (abi) *abi = regs.de;
        if (capabilities) *capabilities = regs.ix;
    }
    return status;
}

win_u8 win320_get_config(win_config_t *config) {
    config->struct_size = sizeof(*config);
    return descriptor_call(WIN_GET_CONFIG, config);
}

win_u8 win320_load_font(const char *path) { return descriptor_call(WIN_LOAD_FONT, path); }
win_u8 win320_set_theme(const win_theme_t *theme) { return descriptor_call(WIN_SET_THEME, theme); }

win_u8 win320_set_text_format(win_u8 format) {
    win320_regs_t regs = {0, format, 0, 0};
    return win320_call(WIN_SET_TEXT_FORMAT, &regs);
}

win_u8 win320_set_origin(win_u16 x, win_u8 y) {
    win320_regs_t regs = {0, y, x, 0};
    return win320_call(WIN_SET_ORIGIN, &regs);
}

win_u8 win320_style(win_u8 desktop_color, win_u8 flags) {
    win320_regs_t regs = {0, (win_u16)(((win_u16)desktop_color << 8) | flags), 0, 0};
    return win320_call(WIN_STYLE, &regs);
}

#define DESC_WRAPPER(name, entry, type) \
    win_u8 name(const type *value) { return descriptor_call(entry, value); }

DESC_WRAPPER(win320_fill_rect, WIN_FILL_RECT, win_rect_t)
DESC_WRAPPER(win320_frame, WIN_FRAME, win_rect_t)
DESC_WRAPPER(win320_panel, WIN_PANEL, win_rect_t)
DESC_WRAPPER(win320_separator, WIN_SEPARATOR, win_rect_t)
DESC_WRAPPER(win320_invert_rect, WIN_INVERT_RECT, win_rect_t)
DESC_WRAPPER(win320_focus_rect, WIN_FOCUS_RECT, win_rect_t)
DESC_WRAPPER(win320_label, WIN_LABEL, win_label_t)
DESC_WRAPPER(win320_button, WIN_BUTTON, win_button_t)
DESC_WRAPPER(win320_icon, WIN_ICON, win_icon_t)

win_u8 win320_draw(win_window_t *window) { return descriptor_call(WIN_DRAW, window); }

win_u8 win320_draw_item(win_window_t *window, win_u16 index) {
    win320_regs_t regs = {0, (win_u16)window, index, 0};
    return win320_call(WIN_DRAW_ITEM, &regs);
}

win_u8 win320_update(win_window_t *window, win_u8 *drawn) {
    win320_regs_t regs = {0, (win_u16)window, 0, 0};
    win_u8 status = win320_call(WIN_UPDATE, &regs);
    if (!status && drawn) *drawn = (win_u8)regs.de;
    return status;
}

win_u8 win320_set_backstore(const win_u8 *pages, win_u16 count) {
    win320_regs_t regs = {0, (win_u16)pages, count, 0};
    return win320_call(WIN_SET_BACKSTORE, &regs);
}

win_u8 win320_open(win_window_t *window) { return descriptor_call(WIN_OPEN, window); }
win_u8 win320_close(void) { return simple_call(WIN_CLOSE); }
win_u8 win320_poll(win_track_t *track) { return descriptor_call(WIN_POLL, track); }
win_u8 win320_track(win_track_t *track) { return descriptor_call(WIN_TRACK, track); }
win_u8 win320_wait_release(void) { return simple_call(WIN_WAIT_RELEASE); }

win_u8 win320_set_cursor(win_u8 kind, const win_cursor_t *cursor) {
    win320_regs_t regs = {0, kind, (win_u16)cursor, 0};
    return win320_call(WIN_SET_CURSOR, &regs);
}

win_u8 win320_edit_draw(win_edit_t *edit) { return descriptor_call(WIN_EDIT_DRAW, edit); }

win_u8 win320_edit(win_edit_t *edit, win_track_t *track, win_u8 *reason) {
    win320_regs_t regs = {0, (win_u16)edit, (win_u16)track, 0};
    win_u8 status = win320_call(WIN_EDIT, &regs);
    if (!status && reason) *reason = (win_u8)regs.de;
    return status;
}

#define MUTABLE_DESC_WRAPPER(name, entry, type) \
    win_u8 name(type *value) { return descriptor_call(entry, value); }

MUTABLE_DESC_WRAPPER(win320_progress_init, WIN_PROGRESS_INIT, win_progress_t)
MUTABLE_DESC_WRAPPER(win320_progress_draw, WIN_PROGRESS_DRAW, win_progress_t)
MUTABLE_DESC_WRAPPER(win320_scrollbar_init, WIN_SCROLLBAR_INIT, win_scrollbar_t)
MUTABLE_DESC_WRAPPER(win320_scrollbar_draw, WIN_SCROLLBAR_DRAW, win_scrollbar_t)
MUTABLE_DESC_WRAPPER(win320_listbox_draw, WIN_LISTBOX_DRAW, win_listbox_t)
MUTABLE_DESC_WRAPPER(win320_checkbox, WIN_CHECKBOX, win_choice_t)
MUTABLE_DESC_WRAPPER(win320_radiobutton, WIN_RADIOBUTTON, win_choice_t)
