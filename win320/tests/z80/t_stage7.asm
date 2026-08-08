        define WIN320_STAGE7_TEST
        include "t_stage6.asm"

; Stage 7 exercises the window title bar and optional close button: static
; validation, draw-time geometry at boundary widths, theme following, and
; the tracker's chrome hit-test / WIN_EV_CLOSE press-release lifecycle.

title_text:      db "Dialog",0
close_ok_text:   db "OK",0

custom_theme:
        db 15,7,8,1,0,7,15,0
        db 1,15,7,1,7,1,#0f,3,12,0

page_list_title: db #30,#31,#32,#33

; A window with a title and a close button, no items.
title_window:
        dw 10,10,100,60
        db #ff,WIN_WND_CLOSE,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; A title strip without a close button: chrome must absorb clicks silently.
title_strip_only_window:
        dw 10,10,100,60
        db #ff,0,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; Minimum accepted width: the title text has no room (skipped), but the
; strip and close button still render and hit-test.
title_min_window:
        dw 0,0,20,18
        db #ff,WIN_WND_CLOSE,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; Maximum screen width, close button flush against the right edge.
title_max_window:
        dw 0,0,320,40
        db #ff,WIN_WND_CLOSE,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; A title bar coexists with an ordinary declarative item.
close_ok_button:
        dw 10,30,60,20
        db #ff,0
        dw close_ok_text
title_with_item_items:
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,5,0
        dw close_ok_button,0
title_with_item_window:
        dw 10,10,140,90
        db #ff,WIN_WND_CLOSE,1,#ff
        dw title_with_item_items
        dw title_text
        db #ff,#ff
        dw 0

; Invalid combinations: title text with WIN_WND_NOPANEL.
title_bad_nopanel:
        dw 10,10,100,60
        db #ff,WIN_WND_NOPANEL,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; WIN_WND_CLOSE without a title.
title_bad_close_no_title:
        dw 10,10,100,60
        db #ff,WIN_WND_CLOSE,0,#ff
        dw 0
        dw 0
        db #ff,#ff
        dw 0

; Below the minimum width (20).
title_bad_width:
        dw 10,10,19,60
        db #ff,0,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

; Below the minimum height (18).
title_bad_height:
        dw 10,10,100,17
        db #ff,0,0,#ff
        dw 0
        dw title_text
        db #ff,#ff
        dw 0

title_track:
        dw 0,0
        db 0,0
        ds WIN_TRACK_SIZE-6,0

; HL=&window, A=WinTrack options.
title_bind_track:
        ld (title_track+WIN_TRK_WINDOW),hl
        ld (title_track+WIN_TRK_OPTIONS),a
        ret

title_clear_track:
        ld hl,title_track+WIN_TRK_EVENT
        ld b,WIN_TRACK_SIZE-WIN_TRK_EVENT
        xor a
.loop:
        ld (hl),a
        inc hl
        djnz .loop
        xor a
        ld (mock_mouse_buttons),a
        ret

; HL=screen x, A=screen y; mouse button reported up. Returns win_poll's A/DE.
title_at_up:
        ld (mock_mouse_x),hl
        ld (mock_mouse_y),a
        xor a
        ld (mock_mouse_buttons),a
        ld de,title_track
        jp win_poll

; HL=screen x, A=screen y; mouse button reported down. Returns win_poll's A/DE.
title_at_down:
        ld (mock_mouse_x),hl
        ld (mock_mouse_y),a
        push hl
        ld a,1
        ld (mock_mouse_buttons),a
        pop hl
        ld de,title_track
        jp win_poll

test_stage7:
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format

        ; ---- static validation: WIN_ERR_ARGUMENT, no screen touched -------
        ld de,title_bad_nopanel
        call win_draw
        cp WIN_ERR_ARGUMENT
        ld a,1
        call t_expect_z
        ld de,title_bad_close_no_title
        call win_draw
        cp WIN_ERR_ARGUMENT
        ld a,2
        call t_expect_z
        ld de,title_bad_width
        call win_draw
        cp WIN_ERR_ARGUMENT
        ld a,3
        call t_expect_z
        ld de,title_bad_height
        call win_draw
        cp WIN_ERR_ARGUMENT
        ld a,4
        call t_expect_z

        ; The same rejection happens before win_open ever maps a backstore
        ; row: the structural check runs inside s2_load_window, ahead of
        ; the allocator and s7_preflight_title.
        ld de,page_list_title
        ld ix,4
        call win_set_backstore
        or a
        ld a,5
        call t_expect_z
        xor a
        ld (s2_test_map_count),a
        ld (s2_test_unmap_count),a
        ld de,title_bad_width
        call win_open
        cp WIN_ERR_ARGUMENT
        ld a,6
        call t_expect_z
        ld a,(s2_test_map_count)
        or a
        ld a,7
        call t_expect_z
        ld a,(s2_test_unmap_count)
        or a
        ld a,8
        call t_expect_z

        ; A well-formed title+close window opens and closes normally.
        xor a
        ld (s2_test_map_count),a
        ld (s2_test_unmap_count),a
        ld de,title_window
        call win_open
        or a
        ld a,9
        call t_expect_z
        ; s2_map_backstore_row/unmap fire once per pixel row (height=60).
        ld a,(s2_test_map_count)
        cp 60
        ld a,10
        call t_expect_z
        call win_close
        or a
        ld a,11
        call t_expect_z
        ld a,(s2_test_unmap_count)
        cp 120
        ld a,12
        call t_expect_z

        ; ---- theme: title_attr=#FF follows WIN_TH_TITLE_BG/FG -------------
        ; Uses the no-close window: a close button resolves its own FACE/TEXT
        ; attr afterward and would overwrite the shared text_attr scratch.
        ld de,0
        call win_set_theme
        or a
        ld a,13
        call t_expect_z
        ld de,title_strip_only_window
        call win_draw
        or a
        ld a,14
        call t_expect_z
        ld a,(text_attr)
        cp (1<<4)|15
        ld a,15
        call t_expect_z
        ld de,custom_theme
        call win_set_theme
        or a
        ld a,16
        call t_expect_z
        ld de,title_strip_only_window
        call win_draw
        or a
        ld a,17
        call t_expect_z
        ld a,(text_attr)
        cp (3<<4)|12
        ld a,18
        call t_expect_z
        ld de,0
        call win_set_theme

        ; ---- close button press/release lifecycle -------------------------
        ld hl,title_window
        ld a,WIN_TRK_OUTSIDE
        call title_bind_track
        call title_clear_track
        ld hl,101
        ld a,19
        call title_at_up            ; seed
        ld hl,101
        ld a,19
        call title_at_down          ; press: no event yet
        ld a,d
        or a
        ld a,20
        call t_expect_z
        ld hl,101
        ld a,19
        call title_at_up            ; release inside the button: WIN_EV_CLOSE
        ld a,d
        cp WIN_EV_CLOSE
        ld a,21
        call t_expect_z
        ld a,e
        cp #ff
        ld a,22
        call t_expect_z
        ld a,(title_track+WIN_TRK_INDEX)
        cp #ff
        ld a,23
        call t_expect_z
        ld a,(title_track+WIN_TRK_PART)
        or a
        ld a,24
        call t_expect_z

        ; Releasing outside the button after a press cancels: no event.
        call title_clear_track
        ld hl,101
        ld a,19
        call title_at_up
        ld hl,101
        ld a,19
        call title_at_down          ; press on the button
        ld hl,20
        ld a,18
        call title_at_down          ; drag onto the strip, still held
        ld hl,20
        ld a,18
        call title_at_up            ; release off the button: cancelled
        ld a,d
        or a
        ld a,25
        call t_expect_z

        ; ---- strip without a close button absorbs clicks silently ---------
        ld hl,title_strip_only_window
        ld a,WIN_TRK_OUTSIDE
        call title_bind_track
        call title_clear_track
        ld hl,20
        ld a,18
        call title_at_up
        ld hl,20
        ld a,18
        call title_at_down
        ld a,d
        or a
        ld a,26
        call t_expect_z
        ld hl,20
        ld a,18
        call title_at_up
        ld a,d
        or a
        ld a,27
        call t_expect_z

        ; ---- WIN_EV_OUTSIDE regression: LMB press outside all objects/chrome
        ld hl,title_window
        ld a,WIN_TRK_OUTSIDE
        call title_bind_track
        call title_clear_track
        ld hl,20
        ld a,50
        call title_at_up
        ld hl,20
        ld a,50
        call title_at_down
        ld a,d
        cp WIN_EV_OUTSIDE
        ld a,28
        call t_expect_z
        ld a,e
        cp #ff
        ld a,29
        call t_expect_z
        ld a,(title_track+WIN_TRK_INDEX)
        cp #ff
        ld a,30
        call t_expect_z

        ; ---- boundary widths: 20 (minimum) and 320 (maximum) --------------
        ld de,title_min_window
        call win_draw
        or a
        ld a,31
        call t_expect_z
        ld hl,title_min_window
        xor a
        call title_bind_track
        call title_clear_track
        ld hl,11
        ld a,9
        call title_at_up
        ld hl,11
        ld a,9
        call title_at_down
        ld hl,11
        ld a,9
        call title_at_up
        ld a,d
        cp WIN_EV_CLOSE
        ld a,32
        call t_expect_z

        ld de,title_max_window
        call win_draw
        or a
        ld a,33
        call t_expect_z
        ld hl,title_max_window
        xor a
        call title_bind_track
        call title_clear_track
        ld hl,311
        ld a,9
        call title_at_up
        ld hl,311
        ld a,9
        call title_at_down
        ld hl,311
        ld a,9
        call title_at_up
        ld a,d
        cp WIN_EV_CLOSE
        ld a,34
        call t_expect_z

        ; ---- title chrome coexists with an ordinary declarative item -------
        ld de,title_with_item_window
        call win_draw
        or a
        ld a,35
        call t_expect_z
        ld hl,title_with_item_window
        xor a
        call title_bind_track
        call title_clear_track
        ld hl,50
        ld a,50
        call title_at_up
        ld hl,50
        ld a,50
        call title_at_down
        ld hl,50
        ld a,50
        call title_at_up
        ld a,d
        cp WIN_EV_LCLICK
        ld a,36
        call t_expect_z
        ld a,e
        cp 5
        ld a,37
        call t_expect_z
        call title_clear_track
        ld hl,141
        ld a,19
        call title_at_up
        ld hl,141
        ld a,19
        call title_at_down
        ld hl,141
        ld a,19
        call title_at_up
        ld a,d
        cp WIN_EV_CLOSE
        ld a,38
        call t_expect_z
        ret

        assert $ < TEST_RESULT
