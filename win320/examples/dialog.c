#include "../bind/win320.h"

/* Application-specific libman/DSS shim. The loader must place WIN320 in WIN3. */
extern win_u8 app_lib_load(const char *name, win_u8 window, win_u8 *handle);
extern void app_lib_free(win_u8 handle);
extern void app_mouse_init(void);

static char title_text[] = "WIN320 C dialog";
static char status_ready[] = "Ready";
static char status_changed[] = "Selection changed";
static char edit_buffer[32] = "edit me";
static char ok_text[] = "OK";
static char cancel_text[] = "Cancel";
static char row0[] = "First row";
static char row1[] = "Second row";
static char row2[] = "Third row";
static win_ptr_t rows[3];

static win_label_t title = {12, 10, 232, 8, 0xff, WIN_LABEL_CENTER, 0};
static win_label_t status = {12, 184, 232, 8, 0xff, WIN_LABEL_CENTER, 0};
static win_edit_t edit = {12, 32, 232, 18, 0xff, WIN_ED_FRAME,
                          31, 7, 7, 0, 0};
static win_button_t ok = {40, 154, 72, 20, 0xff, 0, 0};
static win_button_t cancel = {132, 154, 72, 20, 0xff, 0, 0};
static win_scrollbar_t scrollbar = {
    232, 60, 12, 80, 3, 3, 0, WIN_SB_ARROWS, 0, 0, 0, 0xffff
};
static win_listbox_t listbox = {
    12, 60, 220, 80, 12, 0xff, 0xff, WIN_LB_FRAME,
    3, 0, 0, 0, 0, 0, 0, 0xffff, 0xffff
};
static win_rect_t direct_marker = {22, 222, 16, 8, 10, 0};

static win_item_t items[7];
static win_window_t window = {
    32, 20, 256, 216, 0xff, 0, 7, 2, 0, 0xff, 0
};
static win_track_t track;

static void set_item(win_u8 index, win_u8 type, win_u8 flags, win_u8 id,
                     win_ptr_t control) {
    items[index].type = type;
    items[index].flags = flags;
    items[index].id = id;
    items[index].reserved = 0;
    items[index].control = control;
    items[index].user_data = 0;
}

static void init_dialog(void) {
    title.text = (win_ptr_t)title_text;
    status.text = (win_ptr_t)status_ready;
    edit.buffer = (win_ptr_t)edit_buffer;
    ok.text = (win_ptr_t)ok_text;
    cancel.text = (win_ptr_t)cancel_text;
    rows[0] = (win_ptr_t)row0;
    rows[1] = (win_ptr_t)row1;
    rows[2] = (win_ptr_t)row2;
    listbox.items = (win_ptr_t)rows;
    listbox.scrollbar = (win_ptr_t)&scrollbar;

    set_item(0, WIN_T_LABEL, 0, 0xff, (win_ptr_t)&title);
    set_item(1, WIN_T_EDIT, WIN_IT_HIT | WIN_IT_FOCUSABLE, 10,
             (win_ptr_t)&edit);
    set_item(2, WIN_T_LISTBOX, WIN_IT_HIT | WIN_IT_FOCUSABLE, 11,
             (win_ptr_t)&listbox);
    set_item(3, WIN_T_SCROLLBAR, WIN_IT_HIT | WIN_IT_REPEAT, 12,
             (win_ptr_t)&scrollbar);
    set_item(4, WIN_T_BUTTON, WIN_IT_HIT | WIN_IT_FOCUSABLE, 1,
             (win_ptr_t)&ok);
    set_item(5, WIN_T_BUTTON, WIN_IT_HIT | WIN_IT_FOCUSABLE, 2,
             (win_ptr_t)&cancel);
    set_item(6, WIN_T_LABEL, 0, 0xff, (win_ptr_t)&status);
    window.items = (win_ptr_t)items;

    track.window = (win_ptr_t)&window;
    track.options = WIN_TRK_ANY_KEY | WIN_TRK_HALT | WIN_TRK_SHOW_CUR |
                    WIN_TRK_TAB_FOCUS;
    track.repeat_delay = WIN_REPEAT_DELAY;
    track.repeat_rate = WIN_REPEAT_RATE;
}

int main(void) {
    win_u8 handle, drawn;
    if (app_lib_load("WIN320.DLL", 3, &handle)) return 1;
    win320_bind(handle);
    init_dialog();
    if (win320_set_text_format(WIN_TXT_ASCIIZ) ||
        win320_scrollbar_init(&scrollbar) || win320_draw(&window)) {
        app_lib_free(handle);
        return 2;
    }

    /* A direct call outside the declarative list. */
    win320_fill_rect(&direct_marker);
    app_mouse_init();
    for (;;) {
        if (win320_poll(&track)) break;
        if (track.event == WIN_EV_NONE) continue;
        if (track.id == 2 || (track.event == WIN_EV_KEY && track.key_ascii == 27))
            break;
        if (track.id == 1 || track.id == 11) {
            status.text = (win_ptr_t)status_changed;
            items[6].flags |= WIN_IT_DIRTY;
            if (win320_update(&window, &drawn)) break;
        }
    }
    app_lib_free(handle);
    return 0;
}
