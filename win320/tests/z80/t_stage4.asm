        device noslot64k

        org 0
        jp start

        include "harness.inc"

mock_file_ptr:          dw mock_payload
mock_read_count:        dw 0
mock_pages:             db #10,#11,#12,#13
mock_key_ptr:           dw key_queue
mock_key_count:         db 0
mock_key_delay:         db 0
mock_key_after_click:   db 0
mock_halt_count:        db 0
mock_click_phase:       db 0
mock_show_count:        db 0
mock_hide_count:        db 0
mock_show_error:        db 0
mock_hide_fail_from:    db 0
mock_mouse_x:           dw 300
mock_mouse_y:           db 200
mock_mouse_buttons:     db 0
saved_page:             db 0
saved_edit:             ds WIN_EDIT_SIZE,0

edit_buffer:            db "abc",0,#a1,#a2,#a3,#a4,#a5
edit_buffer_original:   db "abc",0,#a1,#a2,#a3,#a4,#a5
edit_bad_buffer:        db "123456789"
pascal_buffer:          db 3,"xyz",#b1,#b2,#b3,#b4,#b5
edit_nav_buffer:        db "abcd",0,#c1,#c2,#c3,#c4
edit_full_buffer:       db "abc",0
edit_scroll_buffer:     db "abcdefgh",0
edit_words_buffer:      db "one, two.three\four",0

edit_a:
        dw 8,24,72,12
        db #ff,WIN_ED_FRAME|WIN_ED_FOCUS,8,#ee,9,9
        dw edit_buffer
edit_bad:
        dw 8,40,72,8
        db #ff,0,8,#55,2,1
        dw edit_bad_buffer
edit_pascal:
        dw 8,56,72,12
        db #ff,WIN_ED_FRAME|WIN_ED_PASSWORD,8,#ee,2,0
        dw pascal_buffer
edit_nav:
        dw 8,72,72,12
        db #ff,WIN_ED_FRAME,8,0,2,0
        dw edit_nav_buffer
edit_full:
        dw 8,88,72,12
        db #ff,WIN_ED_FRAME,3,0,3,0
        dw edit_full_buffer
edit_scroll:
        dw 8,104,10,12
        db #ff,WIN_ED_FRAME,8,0,8,0
        dw edit_scroll_buffer
edit_words:
        dw 8,120,112,12
        db #ff,WIN_ED_FRAME,24,0,0,0
        dw edit_words_buffer

focus_button:
        dw 8,8,64,14
        db #ff,0
        dw focus_button_text
focus_edit:
        dw 8,28,72,12
        db #ff,WIN_ED_FRAME,8,0,0,0
        dw edit_buffer
focus_zone:
        dw 88,8,24,20
        db 0,0
focus_button_text:      db "Accept",0

focus_items:
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,10,0
        dw focus_button,#1111
        db WIN_T_EDIT,WIN_IT_HIT|WIN_IT_FOCUSABLE,11,0
        dw focus_edit,#2222
        db WIN_T_ZONE,WIN_IT_HIT|WIN_IT_FOCUSABLE,12,0
        dw focus_zone,#3333
focus_window:
        dw 20,20,140,70
        db #ff,WIN_WND_NOPANEL,3,0
        dw focus_items
        db #ff,0

focus_track:
        dw focus_window,0
        db 0,WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

key_queue:
        ds 32*3,0

reset_mock:
        ld hl,mock_payload
        ld (mock_file_ptr),hl
        ld hl,#1110
        ld (mock_pages),hl
        ld hl,#1312
        ld (mock_pages+2),hl
        xor a
        ld (mock_key_count),a
        ld (mock_key_delay),a
        ld (mock_key_after_click),a
        ld (mock_halt_count),a
        ld (mock_click_phase),a
        ld (mock_show_count),a
        ld (mock_hide_count),a
        ld (mock_show_error),a
        ld (mock_hide_fail_from),a
        ld (mock_mouse_buttons),a
        ld hl,300
        ld (mock_mouse_x),hl
        ld a,200
        ld (mock_mouse_y),a
        ret

; A=count, HL=three-byte records (ASCII, scan, modifiers).
set_keys:
        ld (mock_key_ptr),hl
        ld (mock_key_count),a
        ret

win_test_read_page:
        ld a,c
        sub #82
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,mock_pages
        add hl,de
        ld a,(hl)
        ret

win_test_write_page:
        push af
        ld b,a
        ld a,c
        sub #82
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,mock_pages
        add hl,de
        ld (hl),b
        ld a,c
        cp #82
        jr z,.software_only
        ld a,b
        out (c),a
.software_only:
        pop af
        ret

win_test_dss_call:
        ld a,c
        cp DSS_READ
        jr z,.read
        cp DSS_GETMEM
        jr z,.getmem
        cp DSS_FREEMEM
        jr z,.freemem
        cp #33
        jr z,.ctrlkey
        cp #31
        jr z,.scankey
        xor a
        ret
.read:
        ld (mock_read_count),de
        push hl
        ld hl,(mock_file_ptr)
        pop de
        ld bc,(mock_read_count)
        ldir
        ld (mock_file_ptr),hl
        ld de,(mock_read_count)
        xor a
        ret
.getmem:
        ld a,#41
        or a
        ret
.freemem:
        xor a
        ret
.ctrlkey:
        ld a,(mock_key_after_click)
        or a
        jr z,.ctrl_delay
        ld a,(s4_test_mouse_hits)
        or a
        ret z
.ctrl_delay:
        ld hl,mock_key_delay
        ld a,(hl)
        or a
        jr z,.ctrl_ready
        dec (hl)
        xor a
        ret
.ctrl_ready:
        ld a,(mock_key_count)
        or a
        ret z
        ld a,#ff
        or a
        ret
.scankey:
        ld a,(mock_key_after_click)
        or a
        jr z,.key_delay
        ld a,(s4_test_mouse_hits)
        or a
        ret z
.key_delay:
        ld hl,mock_key_delay
        ld a,(hl)
        or a
        jr z,.key_ready
        dec (hl)
        xor a
        ret
.key_ready:
        ld a,(mock_key_count)
        or a
        ret z
        dec a
        ld (mock_key_count),a
        ld hl,(mock_key_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (mock_key_ptr),hl
        ld a,1                       ; SCANKEY flags say a record was removed
        or a
        ret

win_test_bios_call:
        ld a,c
        cp #c5
        jr z,.pages
        cp 3
        jr z,.mouse_read
        cp 1
        jr z,.show
        cp 2
        jr z,.hide
        xor a                         ; cursor LOAD
        ret
.pages:
        ld (hl),#77
        xor a
        ret
.mouse_read:
        ld hl,(mock_mouse_x)
        ld a,(mock_mouse_y)
        ld e,a
        ld a,(mock_mouse_buttons)
        ret
.show:
        ld hl,mock_show_count
        inc (hl)
        ld a,(mock_show_error)
        or a
        jr nz,.bios_error
        xor a
        ret
.hide:
        ld hl,mock_hide_count
        inc (hl)
        ld a,(mock_hide_fail_from)
        or a
        jr z,.bios_ok
        ld b,a
        ld a,(mock_hide_count)
        cp b
        jr nc,.bios_error
.bios_ok:
        xor a
        ret
.bios_error:
        ld a,1
        scf
        ret

win_test_halt_call:
        ld hl,mock_halt_count
        inc (hl)
        ld hl,mock_click_phase
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr z,.release
        ld a,1
        ld (mock_mouse_buttons),a
        ret
.release:
        xor a
        ld (mock_mouse_buttons),a
        ret

start:
        ld sp,#bff0
        call t_begin
        call reset_mock
        ld a,#33
        call win_init
        or a
        ld a,1
        call t_expect_z
        ld d,0
        ld e,1
        call win_set_work_windows
        or a
        ld a,2
        call t_expect_z

        call test_edit_draw
        call test_focus
        call test_edit_keys
        call test_word_navigation
        call test_modal_cursor_pair
        call test_caret_blink
        call test_mouse_cursor
        call test_error_consistency
        ifdef WIN320_STAGE5_TEST
        call test_stage5
        endif
        call t_end
        halt

test_edit_draw:
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld de,edit_a
        call win_edit_draw
        or a
        ld a,10
        call t_expect_z
        ld a,(edit_a+WIN_ED_LEN)
        cp 3
        ld a,11
        call t_expect_z
        ld a,(edit_a+WIN_ED_CURSOR)
        cp 3
        ld a,12
        call t_expect_z
        ld a,(edit_a+WIN_ED_SCROLL)
        cp 4
        ld a,13
        call t_expect_c

        ld hl,edit_bad
        ld de,saved_edit
        ld bc,WIN_EDIT_SIZE
        ldir
        ld de,edit_bad
        call win_edit_draw
        cp WIN_ERR_ARGUMENT
        ld a,14
        call t_expect_z
        ld hl,edit_bad
        ld de,saved_edit
        ld b,WIN_EDIT_SIZE
.bad_same:
        ld a,(de)
        cp (hl)
        jr nz,.bad_changed
        inc hl
        inc de
        djnz .bad_same
        jr .bad_ok
.bad_changed:
        ld a,15
        call t_fail
.bad_ok:
        ld e,WIN_TXT_PASCAL
        call win_set_text_format
        ld de,edit_pascal
        call win_edit_draw
        or a
        ld a,16
        call t_expect_z
        ld a,(edit_pascal+WIN_ED_LEN)
        cp 3
        ld a,17
        call t_expect_z
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ret

test_focus:
        xor a
        ld (s4_test_full_edit_renders),a
        ld de,focus_window
        call win_draw
        or a
        ld a,30
        call t_expect_z
        ld a,(focus_window+WIN_WND_LAST_FOCUS)
        or a
        ld a,31
        call t_expect_z
        ld a,(focus_button+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        ld a,32
        call t_expect_nz
        ld a,(s4_test_full_edit_renders)
        cp 1                         ; initial draw still includes edit frame
        ld a,124
        call t_expect_z

        ; A full draw must clear the derived flag of an old focus control even
        ; when that item has become hidden and therefore is not rendered.
        ld a,(focus_items+WIN_ITEM_FLAGS)
        or WIN_IT_HIDDEN
        ld (focus_items+WIN_ITEM_FLAGS),a
        ld a,1
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_draw
        or a
        ld a,80
        call t_expect_z
        ld a,(focus_button+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        ld a,81
        call t_expect_z
        ld a,(focus_edit+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ld a,82
        call t_expect_nz
        ld a,(focus_items+WIN_ITEM_FLAGS)
        and #ff-WIN_IT_HIDDEN
        ld (focus_items+WIN_ITEM_FLAGS),a
        xor a
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_draw
        or a
        ld a,83
        call t_expect_z

        ld a,1
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update
        or a
        ld a,33
        call t_expect_z
        ld a,e
        cp 2
        ld a,34
        call t_expect_z
        ld a,(focus_button+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        ld a,35
        call t_expect_z
        ld a,(focus_edit+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ld a,36
        call t_expect_nz

        ; Programmatic edit-to-button focus changes use the same content-only
        ; edit path as Tab/mouse and must not rebuild the complete field.
        xor a
        ld (s4_test_full_edit_renders),a
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update
        or a
        ld a,125
        call t_expect_z
        ld a,(s4_test_full_edit_renders)
        or a
        ld a,126
        call t_expect_z
        ld a,1
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update

        ld hl,keys_tab
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        or a
        ld a,37
        call t_expect_z
        ld a,d
        cp WIN_EV_FOCUS
        ld a,38
        call t_expect_z
        ld a,e
        cp 12
        ld a,39
        call t_expect_z
        ld a,(focus_window+WIN_WND_FOCUS)
        cp 2
        ld a,40
        call t_expect_z
        ld hl,(focus_track+WIN_TRK_ITEM)
        ld a,h
        or l
        ld a,41
        call t_expect_z

        ; Navigation keys have ASCII=0.  They are not button activations and
        ; must survive the focus layer as ordinary WIN_EV_KEY events.
        ld a,WIN_TRK_ANY_KEY|WIN_TRK_TAB_FOCUS
        ld (focus_track+WIN_TRK_OPTIONS),a
        ld hl,keys_arrow_up
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        ld a,d
        cp WIN_EV_KEY
        ld a,127
        call t_expect_z
        ld a,(focus_track+WIN_TRK_KEY_ASCII)
        or a
        ld a,128
        call t_expect_z
        ld a,(focus_track+WIN_TRK_KEY_SCAN)
        and #7f
        cp #58
        ld a,129
        call t_expect_z
        ld a,WIN_TRK_TAB_FOCUS
        ld (focus_track+WIN_TRK_OPTIONS),a

        ld hl,keys_shift_tab
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        ld a,(focus_window+WIN_WND_FOCUS)
        cp 1
        ld a,42
        call t_expect_z

        ; Moving focus from edit to button repaints only the edit content.
        xor a
        ld (s4_test_full_edit_renders),a
        ld hl,keys_shift_tab
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        ld a,(focus_window+WIN_WND_FOCUS)
        or a
        ld a,118
        call t_expect_z
        ld a,(s4_test_full_edit_renders)
        or a
        ld a,119
        call t_expect_z

        xor a
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update
        ld hl,keys_enter
        ld a,1
        call set_keys
        xor a
        ld (mock_halt_count),a
        ld de,focus_track
        call win_poll
        or a
        ld a,43
        call t_expect_z
        ld a,d
        cp WIN_EV_LCLICK
        ld a,44
        call t_expect_z
        ld a,e
        cp 10
        ld a,45
        call t_expect_z
        ld a,(mock_halt_count)
        cp 3
        ld a,46
        call t_expect_z
        ld a,(focus_button+WIN_BTN_FLAGS)
        and WIN_BTN_PRESSED
        ld a,47
        call t_expect_z

        ; Space has exactly the same activation contract as Enter.
        ld hl,keys_space
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        or a
        ld a,84
        call t_expect_z
        ld a,d
        cp WIN_EV_LCLICK
        ld a,85
        call t_expect_z
        ld a,e
        cp 10
        ld a,86
        call t_expect_z

        ; Exercise the real Stage-3 press/release path and mouse-driven focus.
        ld hl,focus_track+WIN_TRK_STATE
        ld b,8
.clear_mouse_state:
        ld (hl),0
        inc hl
        djnz .clear_mouse_state
        ld hl,30
        ld (mock_mouse_x),hl
        ld a,50
        ld (mock_mouse_y),a
        xor a
        ld (mock_mouse_buttons),a
        ld de,focus_track
        call win_poll                  ; initial synchronization
        ld a,1
        ld (mock_mouse_buttons),a
        ld de,focus_track
        call win_poll                  ; capture on press
        xor a
        ld (mock_mouse_buttons),a
        ld de,focus_track
        call win_poll                  ; click on edit release
        or a
        ld a,87
        call t_expect_z
        ld a,d
        cp WIN_EV_LCLICK
        ld a,88
        call t_expect_z
        ld a,e
        cp 11
        ld a,89
        call t_expect_z
        ld a,(focus_window+WIN_WND_FOCUS)
        cp 1
        ld a,90
        call t_expect_z
        ret

test_edit_keys:
        ld hl,edit_buffer_original
        ld de,edit_buffer
        ld bc,9
        ldir
        ld a,3
        ld (edit_a+WIN_ED_CURSOR),a
        xor a
        ld (edit_a+WIN_ED_SCROLL),a
        ld hl,keys_edit_accept
        ld a,3
        call set_keys
        ld de,edit_a
        ld ix,0
        call win_edit
        or a
        ld a,60
        call t_expect_z
        ld a,e
        cp WIN_ED_ENTER
        ld a,61
        call t_expect_z
        ld hl,expect_insert
        ld de,edit_buffer
        ld b,5
        call compare_bytes
        ld a,62
        call t_expect_z
        ld a,(edit_a+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ld a,63
        call t_expect_z

        ld hl,edit_buffer_original
        ld de,edit_buffer
        ld bc,9
        ldir
        ld a,3
        ld (edit_a+WIN_ED_CURSOR),a
        ld hl,keys_edit_escape
        ld a,2
        call set_keys
        ld de,edit_a
        ld ix,0
        call win_edit
        or a
        ld a,64
        call t_expect_z
        ld a,e
        cp WIN_ED_ESC
        ld a,65
        call t_expect_z
        ld hl,edit_buffer_original
        ld de,edit_buffer
        ld b,9
        call compare_bytes
        ld a,66
        call t_expect_z

        ld hl,keys_tab
        ld a,1
        call set_keys
        ld de,edit_a
        ld ix,0
        call win_edit
        or a
        ld a,67
        call t_expect_z
        ld a,e
        cp WIN_ED_TAB
        ld a,68
        call t_expect_z

        ; Home, Right, Delete, End and Backspace are executed, not merely
        ; mentioned by a host-side source contract.
        ld hl,keys_edit_navigation
        ld a,6
        call set_keys
        ld de,edit_nav
        ld ix,0
        call win_edit
        or a
        ld a,91
        call t_expect_z
        ld a,e
        cp WIN_ED_ENTER
        ld a,92
        call t_expect_z
        ld hl,expect_navigation
        ld de,edit_nav_buffer
        ld b,3
        call compare_bytes
        ld a,93
        call t_expect_z
        ld a,(edit_nav+WIN_ED_CURSOR)
        cp 2
        ld a,94
        call t_expect_z

        ; Insertion at maxlen is a no-op and still permits a later Enter.
        ld hl,keys_full
        ld a,2
        call set_keys
        ld de,edit_full
        ld ix,0
        call win_edit
        or a
        ld a,95
        call t_expect_z
        ld hl,expect_full
        ld de,edit_full_buffer
        ld b,4
        call compare_bytes
        ld a,96
        call t_expect_z

        ; A cursor beyond the narrow content area forces horizontal scrolling.
        ld de,edit_scroll
        call win_edit_draw
        or a
        ld a,97
        call t_expect_z
        ld a,(edit_scroll+WIN_ED_SCROLL)
        or a
        ld a,98
        call t_expect_nz

        ; Modal editing must mutate the Pascal length byte and payload together.
        ld e,WIN_TXT_PASCAL
        call win_set_text_format
        ld a,1
        ld (edit_pascal+WIN_ED_CURSOR),a
        ld hl,keys_pascal_edit
        ld a,3
        call set_keys
        ld de,edit_pascal
        ld ix,0
        call win_edit
        or a
        ld a,99
        call t_expect_z
        ld hl,expect_pascal_edit
        ld de,pascal_buffer
        ld b,4
        call compare_bytes
        ld a,100
        call t_expect_z
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ret

test_word_navigation:
        ; Ctrl+Right skips a word and its separators; Ctrl+Left returns to
        ; the previous word start. Exercise direct BIOS and WinTrack input.
        xor a
        ld (edit_words+WIN_ED_CURSOR),a
        ld (edit_words+WIN_ED_SCROLL),a
        ld hl,keys_word_navigation
        ld a,4
        call set_keys
        ld de,edit_words
        ld ix,0
        call win_edit
        or a
        ld a,120
        call t_expect_z
        ld a,(edit_words+WIN_ED_CURSOR)
        cp 5
        ld a,121
        call t_expect_z

        xor a
        ld (edit_words+WIN_ED_CURSOR),a
        ld (edit_words+WIN_ED_SCROLL),a
        ld hl,focus_track+WIN_TRK_STATE
        ld b,8
.clear_track_state:
        ld (hl),a
        inc hl
        djnz .clear_track_state
        ld hl,300
        ld (mock_mouse_x),hl
        ld a,200
        ld (mock_mouse_y),a
        ld hl,keys_word_navigation
        ld a,4
        call set_keys
        ld de,edit_words
        ld ix,focus_track
        call win_edit
        or a
        ld a,122
        call t_expect_z
        ld a,(edit_words+WIN_ED_CURSOR)
        cp 5
        ld a,123
        call t_expect_z
        ret

test_modal_cursor_pair:
        ld a,1
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update
        ld a,WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ld (focus_track+WIN_TRK_OPTIONS),a
        xor a
        ld (mock_show_count),a
        ld (mock_hide_count),a
        ld hl,keys_enter
        ld a,1
        call set_keys
        ld ix,20
        ld e,20
        call win_set_origin
        ld de,focus_edit
        ld ix,focus_track
        call win_edit
        push af
        push de
        ld ix,0
        ld e,0
        call win_set_origin
        pop de
        pop af
        or a
        ld a,70
        call t_expect_z
        ld a,e
        cp WIN_ED_ENTER
        ld a,71
        call t_expect_z
        ld a,(mock_hide_count)
        ld b,a
        ld a,(mock_show_count)
        cp b
        ld a,72
        call t_expect_z
        ld a,(mock_hide_count)
        cp 2
        ld a,73
        call t_expect_z
        ret

test_caret_blink:
        ; The focused caret blinks after fourteen empty iterations. A later
        ; cursor move restores the complete old 1x10 line before redrawing.
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld hl,keys_blink_redraw
        ld a,2
        call set_keys
        ld a,S4_CARET_TICKS
        ld (mock_key_delay),a
        xor a
        ld (mock_halt_count),a
        ld (s4_test_caret_toggles),a
        ld (s4_test_caret_saves),a
        ld (s4_test_caret_restores),a
        ld de,edit_a
        ld ix,0
        call win_edit
        or a
        ld a,108
        call t_expect_z
        ld a,e
        cp WIN_ED_ENTER
        ld a,109
        call t_expect_z
        ld a,(mock_halt_count)
        cp S4_CARET_TICKS
        ld a,110
        call t_expect_z
        ld a,(s4_test_caret_toggles)
        cp 4                         ; show, blink, redraw show, final restore
        ld a,111
        call t_expect_z
        ld a,(s4_test_caret_saves)
        cp 2                         ; initial and post-movement caret images
        ld a,116
        call t_expect_z
        ld a,(s4_test_caret_restores)
        cp 2                         ; blink and redraw restore all ten pixels
        ld a,117
        call t_expect_z
        ret

test_mouse_cursor:
        ; A release click on the active WinEdit is consumed and selects the
        ; proportional glyph boundary instead of returning WIN_ED_MOUSE.
        ld hl,edit_buffer_original
        ld de,edit_buffer
        ld bc,9
        ldir
        ld a,WIN_ED_FRAME
        ld (focus_edit+WIN_ED_FLAGS),a
        xor a
        ld (focus_edit+WIN_ED_CURSOR),a
        ld (focus_edit+WIN_ED_SCROLL),a
        ld (s4_test_mouse_hits),a
        ld hl,focus_track+WIN_TRK_STATE
        ld b,8
.clear_state:
        ld (hl),a
        inc hl
        djnz .clear_state
        ld a,1
        ld (focus_window+WIN_WND_FOCUS),a
        ld (focus_window+WIN_WND_LAST_FOCUS),a

        ; window.x 20 + edit.x 8 + framed content inset 2, then the full
        ; proportional width of 'a': the exact boundary before 'b'.
        ld a,'a'
        call s1_cached_width
        ld l,a
        ld h,0
        ld de,30
        add hl,de
        ld (mock_mouse_x),hl
        ld a,52
        ld (mock_mouse_y),a
        xor a
        ld (mock_mouse_buttons),a
        ld a,2
        ld (mock_click_phase),a
        ld a,1
        ld (mock_key_after_click),a
        ld hl,keys_enter
        call set_keys

        ld ix,20
        ld e,20
        call win_set_origin
        ld de,focus_edit
        ld ix,focus_track
        call win_edit
        push af
        push de
        xor a
        ld (mock_key_after_click),a
        ld ix,0
        ld e,0
        call win_set_origin
        pop de
        pop af
        or a
        ld a,112
        call t_expect_z
        ld a,e
        cp WIN_ED_ENTER
        ld a,113
        call t_expect_z
        ld a,(focus_edit+WIN_ED_CURSOR)
        cp 1
        ld a,114
        call t_expect_z
        ld a,(mock_click_phase)
        or a
        ld a,115
        call t_expect_z
        ret

test_error_consistency:
        ; A late SHOW failure happens after both focus indicators were drawn.
        ; The public window and derived flags must describe that completed move.
        xor a
        ld (focus_window+WIN_WND_FOCUS),a
        ld de,focus_window
        call win_update
        ld a,WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ld (focus_track+WIN_TRK_OPTIONS),a
        ld a,1
        ld (mock_show_error),a
        ld hl,keys_tab
        ld a,1
        call set_keys
        ld de,focus_track
        call win_poll
        cp WIN_ERR_UNSUPPORTED
        ld a,101
        call t_expect_z
        ld a,(focus_window+WIN_WND_FOCUS)
        cp 1
        ld a,102
        call t_expect_z
        ld a,(focus_window+WIN_WND_LAST_FOCUS)
        cp 1
        ld a,103
        call t_expect_z
        ld a,(focus_button+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        ld a,104
        call t_expect_z
        ld a,(focus_edit+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ld a,105
        call t_expect_nz
        xor a
        ld (mock_show_error),a

        ; Once modal focus was published, persistent repaint HIDE failures must
        ; still clear the public WIN_ED_FOCUS flag before returning the error.
        ld (mock_hide_count),a
        ld a,2
        ld (mock_hide_fail_from),a
        ld hl,keys_one_char
        ld a,1
        call set_keys
        ld ix,20
        ld e,20
        call win_set_origin
        ld de,focus_edit
        ld ix,focus_track
        call win_edit
        push af
        ld ix,0
        ld e,0
        call win_set_origin
        pop af
        cp WIN_ERR_UNSUPPORTED
        ld a,106
        call t_expect_z
        ld a,(focus_edit+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ld a,107
        call t_expect_z
        xor a
        ld (mock_hide_fail_from),a
        ld a,WIN_TRK_TAB_FOCUS
        ld (focus_track+WIN_TRK_OPTIONS),a
        ret

compare_bytes:
.loop:
        ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        djnz .loop
        xor a
        ret

keys_tab:               db #09,#0f,0
keys_shift_tab:         db #09,#0f,#80
keys_enter:             db #0d,#28,0
keys_arrow_up:          db 0,#58,0
keys_space:             db #20,#39,0
keys_edit_accept:       db 0,S4_SCAN_LEFT,0, 'X',#2d,0, #0d,#28,0
keys_edit_escape:       db 'Z',#2a,0, #1b,#01,0
keys_edit_navigation:   db 0,S4_SCAN_HOME,0, 0,S4_SCAN_RIGHT,0
                        db 0,S4_SCAN_DELETE,0, 0,S4_SCAN_END,0
                        db #08,#0e,0, #0d,#28,0
keys_full:              db 'Z',#2c,0, #0d,#28,0
keys_pascal_edit:       db #08,#0e,0, 'Q',#10,0, #0d,#28,0
keys_one_char:          db 'X',#2d,0
keys_blink_redraw:      db 0,S4_SCAN_LEFT,0, #0d,#28,0
keys_word_navigation:   db 0,S4_SCAN_RIGHT,#20, 0,S4_SCAN_RIGHT,#20
                        db 0,S4_SCAN_LEFT,#20, #0d,#28,0
expect_insert:          db "abXc",0
expect_navigation:      db "ac",0
expect_full:            db "abc",0
expect_pascal_edit:     db 3,"Qyz"

        ds #2000-$,0
        assert $ == #2000
win_test_font_memory:
        ds #4000,0

        assert $ == #6000
mock_payload:
        incbin "build/font.wf32"

        ds #c000-$,0
        assert $ == #c000
        define WIN320_TEST_BUILD
        define WIN320_TEST_HALT_HOOK
        include "../../win320.asm"
        assert $ < TEST_RESULT
