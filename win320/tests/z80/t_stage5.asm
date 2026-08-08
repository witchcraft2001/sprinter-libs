        define WIN320_STAGE5_TEST
        include "t_stage4.asm"

T_S5_RESULT equ path_scratch+183
T_S5_CONTENT_H equ path_scratch+176

test_stage5:
        ld de,s5_progress
        call win_progress_init
        or a
        ld a,200
        call t_expect_z
        ld hl,(s5_progress+WIN_PG_LAST_PX)
        inc hl
        ld a,h
        or l
        ld a,201
        call t_expect_z
        ld de,s5_progress
        call win_progress_draw
        or a
        ld a,202
        call t_expect_z
        ld hl,(s5_progress+WIN_PG_LAST_PX)
        ld de,10
        or a
        sbc hl,de
        ld a,203
        call t_expect_z

        ld de,s5_scroll
        call win_scrollbar_init
        or a
        ld a,204
        call t_expect_z
        ld de,s5_scroll
        call win_scrollbar_draw
        or a
        ld a,205
        call t_expect_z
        ld hl,(s5_scroll+WIN_SB_THUMB_LEN)
        ld de,20
        or a
        sbc hl,de
        ld a,206
        call t_expect_z
        ld hl,5
        ld (s5_scroll+WIN_SB_FIRST),hl
        ld de,s5_scroll
        call win_scrollbar_draw
        ld hl,(s5_scroll+WIN_SB_THUMB_POS)
        ld de,20
        or a
        sbc hl,de
        ld a,207
        call t_expect_z

        ld de,s5_list
        call win_listbox_draw
        or a
        ld a,208
        call t_expect_z
        ld hl,(s5_list+WIN_LB_LAST_FIRST)
        ld a,h
        or l
        ld a,209
        call t_expect_z
        ld hl,(s5_list+WIN_LB_LAST_CURSOR)
        ld de,1
        or a
        sbc hl,de
        ld a,210
        call t_expect_z
        ld hl,2
        ld (s5_list+WIN_LB_CURSOR),hl
        ld de,s5_list
        call win_listbox_draw
        ld a,(T_S5_RESULT)
        or a                            ; cursor-only path skips full background
        ld a,221
        call t_expect_z

        ld hl,#1234
        ld (fill_x),hl
        ld hl,#5678
        ld (fill_y),hl
        ld hl,#9abc
        ld (fill_h),hl
        ld de,s5_progress_frame
        call win_progress_init
        ld de,s5_progress_frame
        call win_progress_draw
        or a
        ld a,222
        call t_expect_z
        ld hl,(fill_x)
        ld de,3
        or a
        sbc hl,de
        ld a,223
        call t_expect_z
        ld hl,(fill_y)
        ld de,201
        or a
        sbc hl,de
        ld a,224
        call t_expect_z
        ld hl,(fill_h)
        ld de,3
        or a
        sbc hl,de
        ld a,225
        call t_expect_z

        ; The showcase uses an empty vertical scrollbar.  Its computed thumb
        ; must retain the 84-pixel track length; a zero height is especially
        ; dangerous because the hardware accelerator interprets zero as 256.
        ld hl,16
        ld (window_scratch+WIN_WND_X),hl
        ld (window_scratch+WIN_WND_Y),hl
        ld de,s5_scroll_empty_vertical
        call win_scrollbar_init
        or a
        ld a,226
        call t_expect_z
        ld de,s5_scroll_empty_vertical
        call win_scrollbar_draw
        or a
        ld a,227
        call t_expect_z
        ld hl,(s5_scroll_empty_vertical+WIN_SB_THUMB_LEN)
        ld de,84
        or a
        sbc hl,de
        ld a,228
        call t_expect_z
        ld hl,(s5_scroll_empty_vertical+WIN_SB_THUMB_POS)
        ld a,h
        or l
        ld a,229
        call t_expect_z

        ; Same descriptor after listbox synchronization (12 total, 8 visible).
        ld hl,8
        ld (s5_scroll_empty_vertical+WIN_SB_VISIBLE),hl
        ld hl,12
        ld (s5_scroll_empty_vertical+WIN_SB_TOTAL),hl
        ld de,s5_scroll_empty_vertical
        call win_scrollbar_draw
        or a
        ld a,230
        call t_expect_z
        ld hl,(s5_scroll_empty_vertical+WIN_SB_THUMB_LEN)
        ld de,56
        or a
        sbc hl,de
        ld a,231
        call t_expect_z
        ld hl,4
        ld (s5_scroll_empty_vertical+WIN_SB_FIRST),hl
        ld de,s5_scroll_empty_vertical
        call win_scrollbar_draw
        or a
        ld a,232
        call t_expect_z
        ld hl,(s5_scroll_empty_vertical+WIN_SB_THUMB_POS)
        ld de,28
        or a
        sbc hl,de
        ld a,233
        call t_expect_z
        ld hl,(s5_scroll_empty_vertical+WIN_SB_THUMB_LEN)
        ld de,56
        or a
        sbc hl,de
        ld a,234
        call t_expect_z

        ; Match the declarative showcase order: the linked listbox is drawn
        ; immediately before its scrollbar.
        ld de,s5_scroll_showcase
        call win_scrollbar_init
        ld de,s5_list_showcase
        call win_listbox_draw
        or a
        ld a,235
        call t_expect_z
        ld hl,(T_S5_CONTENT_H)
        ld de,96
        or a
        sbc hl,de
        ld a,247
        call t_expect_z
        ld de,s5_scroll_showcase
        call win_scrollbar_draw
        or a
        ld a,236
        call t_expect_z
        ld hl,(s5_scroll_showcase+WIN_SB_THUMB_LEN)
        ld de,56
        or a
        sbc hl,de
        ld a,237
        call t_expect_z

        ; A one-row viewport move takes the accelerator scroll path in both
        ; directions and still publishes the exact first row.
        ld hl,1
        ld (s5_list_showcase+WIN_LB_FIRST),hl
        ld hl,8
        ld (s5_list_showcase+WIN_LB_CURSOR),hl
        ld de,s5_list_showcase
        call win_listbox_draw
        or a
        ld a,241
        call t_expect_z
        ld hl,(s5_list_showcase+WIN_LB_LAST_FIRST)
        dec hl
        ld a,h
        or l
        ld a,242
        call t_expect_z
        ld hl,0
        ld (s5_list_showcase+WIN_LB_FIRST),hl
        ld (s5_list_showcase+WIN_LB_CURSOR),hl
        ld de,s5_list_showcase
        call win_listbox_draw
        or a
        ld a,243
        call t_expect_z
        ld hl,(s5_list_showcase+WIN_LB_LAST_FIRST)
        ld a,h
        or l
        ld a,244
        call t_expect_z

        ; Tab must redraw the listbox that loses focus, not leave its selected
        ; row in the focused colour until some unrelated dirty update.
        ld ix,0
        ld e,0
        call win_set_origin
        ld de,s5_focus_window
        call win_draw
        ld a,(s5_focus_list+WIN_LB_FLAGS)
        and WIN_LB_FOCUS
        ld a,238
        call t_expect_nz
        ld hl,s5_focus_track+WIN_TRK_STATE
        ld b,8
        xor a
.clear_focus_track:
        ld (hl),a
        inc hl
        djnz .clear_focus_track
        ld hl,keys_tab
        ld a,1
        call set_keys
        ld de,s5_focus_track
        call win_poll
        ld a,(s5_focus_window+WIN_WND_FOCUS)
        cp 1
        ld a,239
        call t_expect_z
        ld a,(s5_focus_list+WIN_LB_FLAGS)
        and WIN_LB_FOCUS
        ld a,240
        call t_expect_z
        ld hl,1
        ld (s5_focus_list+WIN_LB_CURSOR),hl
        ld de,s5_focus_list
        call win_listbox_draw
        or a
        ld a,245
        call t_expect_z
        ld a,(label_scratch+WIN_LBL_ATTR)
        cp #80
        ld a,246
        call t_expect_z

        ld de,s5_bad_icon
        call win_icon
        cp WIN_ERR_ARGUMENT
        ld a,211
        call t_expect_z

        ld hl,0
        ld (window_scratch+WIN_WND_X),hl
        ld (window_scratch+WIN_WND_Y),hl
        ld a,WIN_EV_LCLICK
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        ld a,WIN_T_SCROLLBAR
        ld (item_scratch+WIN_ITEM_TYPE),a
        ld hl,s5_scroll_arrows
        ld (item_scratch+WIN_ITEM_CONTROL),hl
        ld de,s5_scroll_arrows
        call win_scrollbar_init
        ld hl,8
        ld (s5_scroll_arrows+WIN_SB_THUMB_POS),hl
        ld (s5_scroll_arrows+WIN_SB_THUMB_LEN),hl

        ld hl,10
        call s5_test_scroll_part
        cp WIN_SB_PART_BACK
        ld a,212
        call t_expect_z
        ld hl,18
        call s5_test_scroll_part
        cp WIN_SB_PART_PAGE_BACK
        ld a,213
        call t_expect_z
        ld hl,26
        call s5_test_scroll_part
        cp WIN_SB_PART_THUMB
        ld a,214
        call t_expect_z
        ld hl,34
        call s5_test_scroll_part
        cp WIN_SB_PART_PAGE_FORWARD
        ld a,215
        call t_expect_z
        ld hl,42
        call s5_test_scroll_part
        cp WIN_SB_PART_FORWARD
        ld a,216
        call t_expect_z

        ld a,WIN_T_LISTBOX
        ld (item_scratch+WIN_ITEM_TYPE),a
        ld hl,s5_list_frame
        ld (item_scratch+WIN_ITEM_CONTROL),hl
        ld a,200
        call s5_test_list_item
        ld a,(s3_track_scratch+WIN_TRK_PART)
        or a
        ld a,217
        call t_expect_z
        ld hl,(s3_track_scratch+WIN_TRK_ITEM)
        inc hl
        ld a,h
        or l
        ld a,218
        call t_expect_z
        ld a,202
        call s5_test_list_item
        ld a,(s3_track_scratch+WIN_TRK_PART)
        cp WIN_LB_PART_ROW
        ld a,219
        call t_expect_z
        ld hl,(s3_track_scratch+WIN_TRK_ITEM)
        ld a,h
        or l
        ld a,220
        call t_expect_z
        ret

s5_clear_hit:
        xor a
        ld (s3_track_scratch+WIN_TRK_PART),a
        ld (s3_track_scratch+WIN_TRK_ITEM),a
        ld (s3_track_scratch+WIN_TRK_ITEM+1),a
        ret

; HL=mouse x, return A=part.
s5_test_scroll_part:
        ld (s3_mouse_x),hl
        call s5_clear_hit
        call s5_hit_detail
        ld a,(s3_track_scratch+WIN_TRK_PART)
        ret

; A=mouse y.
s5_test_list_item:
        ld (s3_mouse_y),a
        call s5_clear_hit
        jp s5_hit_detail

s5_progress:
        dw 2,200,20,3
        db 0,50
        dw 0
s5_progress_frame:
        dw 2,200,20,5
        db WIN_PG_FRAME,50
        dw 0
s5_scroll:
        dw 2,204,40,8
        dw 5,10,0
        db WIN_SB_HORIZONTAL,0
        dw 0,0,0
s5_scroll_arrows:
        dw 10,100,40,8
        dw 5,10,0
        db WIN_SB_HORIZONTAL|WIN_SB_ARROWS,0
        dw 0,0,0
s5_scroll_empty_vertical:
        dw 220,32,10,104
        dw 0,0,0
        db WIN_SB_ARROWS,0
        dw 0,0,#ffff
s5_scroll_showcase:
        dw 220,32,10,104
        dw 0,0,0
        db WIN_SB_ARROWS,0
        dw 0,0,#ffff
s5_list_showcase:
        dw 16,32,200,104
        db 12,#ff,#ff,WIN_LB_FRAME
        dw 12,0,0,s5_showcase_items
        db 0,0
        dw s5_scroll_showcase,#ffff,#ffff
s5_showcase_items:
        dw s5_text0,s5_text1,s5_text2,s5_text0
        dw s5_text1,s5_text2,s5_text0,s5_text1
        dw s5_text2,s5_text0,s5_text1,s5_text2
s5_list:
        dw 48,200,48,24
        db 8,#ff,#ff,WIN_LB_FOCUS
        dw 3,0,1,s5_items
        db 0,0
        dw 0,#ffff,#ffff
s5_list_frame:
        dw 48,200,48,24
        db 8,#ff,#ff,WIN_LB_FRAME|WIN_LB_FOCUS
        dw 3,0,1,s5_items
        db 0,0
        dw 0,#ffff,#ffff
s5_items:
        dw s5_text0,s5_text1,s5_text2
s5_text0: db "one",0
s5_text1: db "two",0
s5_text2: db "three",0
s5_focus_items:
        db WIN_T_LISTBOX,WIN_IT_HIT|WIN_IT_FOCUSABLE,50,0
        dw s5_focus_list,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,51,0
        dw s5_focus_button,0
s5_focus_window:
        dw 4,4,100,48
        db #ff,WIN_WND_NOPANEL,2,0
        dw s5_focus_items
        dw 0
        db #ff,#ff
        dw 0
s5_focus_list:
        dw 2,2,56,24
        db 8,#ff,#ff,WIN_LB_FRAME
        dw 3,0,0,s5_items
        db 0,0
        dw 0,#ffff,#ffff
s5_focus_button:
        dw 62,2,32,16
        db #ff,0
        dw s5_focus_button_text
s5_focus_button_text: db "Exit",0
s5_focus_track:
        dw s5_focus_window,0
        db 0,WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0
s5_bad_icon:
        dw 0,0,12,12
        db 0,1,0,0
