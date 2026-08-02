        define WIN320_STAGE6_TEST
        include "t_stage5.asm"

; Stage 6 exercises the complete WinChoice path in the same full-library
; image as Stage 5.  Control coordinates are relative to choice_window.

choice_text_checkbox:   db "Enable sound",0
choice_text_disabled:   db "Unavailable",0
choice_text_g1a:        db "Mode A",0
choice_text_g1b:        db "Mode B",0
choice_text_g1c:        db "Mode C",0
choice_text_g2a:        db "Colour",0
choice_text_g2b:        db "Mono",0
choice_text_button:     db "Continue",0
choice_text_pascal:     db 6,"Pascal"

choice_checkbox:
        dw 2,4,108,12
        db #ff,0,0,0
        dw choice_text_checkbox
choice_disabled:
        dw 2,18,108,12
        db #ff,WIN_CH_DISABLED,0,0
        dw choice_text_disabled
choice_radio_a:
        dw 2,34,88,12
        db #ff,WIN_CH_CHECKED,1,0
        dw choice_text_g1a
choice_radio_b:
        dw 2,48,88,12
        db #ff,0,1,0
        dw choice_text_g1b
choice_radio_hidden:
        dw 2,62,88,12
        db #ff,0,1,0
        dw choice_text_g1c
choice_radio_disabled:
        dw 2,76,88,12
        db #ff,0,1,0
        dw choice_text_g1c
choice_radio_c:
        dw 2,90,88,12
        db #ff,0,1,0
        dw choice_text_g1c
choice_radio_g2a:
        dw 132,34,88,12
        db #ff,WIN_CH_CHECKED,2,0
        dw choice_text_g2a
choice_radio_g2b:
        dw 132,48,88,12
        db #ff,0,2,0
        dw choice_text_g2b
choice_button:
        dw 132,70,72,16
        db #ff,0
        dw choice_text_button
choice_item_disabled:
        dw 132,92,108,12
        db #ff,0,0,0
        dw choice_text_disabled

choice_items:
        db WIN_T_CHECKBOX,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,60,0
        dw choice_checkbox,#6100
        db WIN_T_CHECKBOX,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,61,0
        dw choice_disabled,#6101
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,62,0
        dw choice_radio_a,#6200
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,63,0
        dw choice_radio_b,#6300
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIDDEN|WIN_IT_HIT|WIN_IT_FOCUSABLE,64,0
        dw choice_radio_hidden,#6400
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_DISABLED|WIN_IT_HIT|WIN_IT_FOCUSABLE,65,0
        dw choice_radio_disabled,#6500
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,66,0
        dw choice_radio_c,#6600
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,67,0
        dw choice_radio_g2a,#6700
        db WIN_T_RADIOBUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,68,0
        dw choice_radio_g2b,#6800
        db WIN_T_BUTTON,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE,69,0
        dw choice_button,#6900
        db WIN_T_CHECKBOX,WIN_IT_DIRTY|WIN_IT_DISABLED|WIN_IT_HIT|WIN_IT_FOCUSABLE,70,0
        dw choice_item_disabled,#7000
CHOICE_ITEM_COUNT equ 11

choice_window:
        dw 8,8,224,124
        db #ff,WIN_WND_NOPANEL,CHOICE_ITEM_COUNT,0
        dw choice_items
        db #ff,0

choice_track:
        dw choice_window,0
        db 0,WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

choice_pascal:
        dw 8,140,100,12
        db #ff,0,0,0
        dw choice_text_pascal
choice_bad_flags:
        dw 8,156,100,12
        db #ff,WIN_CH_CHECKED|#08,0,0
        dw choice_text_checkbox
choice_bad_group:
        dw 8,172,100,12
        db #ff,WIN_CH_CHECKED,1,0
        dw choice_text_checkbox
choice_bad_reserved:
        dw 8,188,100,12
        db #ff,WIN_CH_CHECKED,0,1
        dw choice_text_checkbox
choice_bad_geometry:
        dw 8,204,12,10
        db #ff,WIN_CH_CHECKED,0,0
        dw choice_text_checkbox
choice_bad_pointer:
        dw 8,220,100,12
        db #ff,WIN_CH_CHECKED,0,0
        dw win_init

keys_choice_right:      db 0,#56,0
keys_choice_left:       db 0,#54,0

test_stage6:
        call choice_reset_state

        ; Direct ASCIIZ and Pascal rendering, then a complete declarative draw.
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld de,choice_checkbox
        call win_checkbox
        or a
        ld a,130
        call t_expect_z
        ld de,choice_radio_a
        call win_radiobutton
        or a
        ld a,131
        call t_expect_z
        ld e,WIN_TXT_PASCAL
        call win_set_text_format
        ld de,choice_pascal
        call win_checkbox
        or a
        ld a,132
        call t_expect_z
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld de,choice_window
        call win_draw
        or a
        ld a,133
        call t_expect_z
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        and WIN_CH_FOCUS
        ld a,134
        call t_expect_nz

        ; Validation differentiates unsupported flags from malformed input.
        ld de,choice_bad_flags
        call win_checkbox
        cp WIN_ERR_UNSUPPORTED
        ld a,135
        call t_expect_z
        ld de,choice_bad_group
        call win_checkbox
        cp WIN_ERR_ARGUMENT
        ld a,136
        call t_expect_z
        ld de,choice_bad_reserved
        call win_checkbox
        cp WIN_ERR_ARGUMENT
        ld a,137
        call t_expect_z
        ld de,choice_bad_geometry
        call win_checkbox
        cp WIN_ERR_ARGUMENT
        ld a,138
        call t_expect_z
        ld de,choice_bad_pointer
        call win_checkbox
        cp WIN_ERR_ARGUMENT
        ld a,139
        call t_expect_z
        ld a,(choice_bad_flags+WIN_CH_FLAGS)
        cp WIN_CH_CHECKED|#08
        ld a,140
        call t_expect_z

        ; A caption click toggles the checkbox, moves focus, returns CHANGE,
        ; and publishes the changed item's identity.
        xor a
        ld (mock_show_count),a
        ld (mock_hide_count),a
        ld hl,80
        ld a,17
        call choice_click
        or a
        ld a,141
        call t_expect_z
        ld a,d
        cp WIN_EV_CHANGE
        ld a,142
        call t_expect_z
        ld a,e
        cp 60
        ld a,143
        call t_expect_z
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,144
        call t_expect_nz
        ld a,(choice_track+WIN_TRK_INDEX)
        or a
        ld a,145
        call t_expect_z
        ld hl,(choice_track+WIN_TRK_USER_DATA)
        ld de,#6100
        or a
        sbc hl,de
        ld a,146
        call t_expect_z
        ld a,(mock_hide_count)
        cp 1
        ld a,147
        call t_expect_z
        ld a,(mock_show_count)
        cp 1
        ld a,148
        call t_expect_z

        ; Space toggles the focused checkbox back without becoming Enter's
        ; button path.
        ld hl,keys_space
        call choice_key
        ld a,d
        cp WIN_EV_CHANGE
        ld a,149
        call t_expect_z
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,150
        call t_expect_z

        ; Put focus on the selected member first.  Switching within the group
        ; must then redraw exactly the old and new radio, not later focusable
        ; items whose index happens to affect CP's carry flag.
        ld a,2
        ld (choice_window+WIN_WND_FOCUS),a
        ld de,choice_window
        call win_update
        or a
        ld a,177
        call t_expect_z

        ; Selecting a radio clears only its own group and leaves group 2.
        ld hl,70
        ld a,61
        call choice_click
        ld a,d
        cp WIN_EV_CHANGE
        ld a,151
        call t_expect_z
        ld a,(choice_radio_a+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,152
        call t_expect_z
        ld a,(choice_radio_b+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,153
        call t_expect_nz
        ld a,(choice_radio_g2a+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,154
        call t_expect_nz
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 3
        ld a,155
        call t_expect_z
        ld a,(s2_update_count)
        cp 2
        ld a,178
        call t_expect_z

        ; Re-selecting an already checked radio is consumed without CHANGE.
        ld hl,keys_space
        call choice_key
        ld a,d
        or a
        ld a,156
        call t_expect_z
        ld a,(choice_radio_b+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,157
        call t_expect_nz

        ; Right skips hidden/disabled group members; another Right wraps.
        ld hl,keys_choice_right
        call choice_key
        ld a,d
        cp WIN_EV_CHANGE
        ld a,158
        call t_expect_z
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 6
        ld a,159
        call t_expect_z
        ld a,(choice_radio_c+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,160
        call t_expect_nz
        ld hl,keys_choice_right
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 2
        ld a,161
        call t_expect_z
        ld a,(choice_radio_a+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,162
        call t_expect_nz
        ld hl,keys_choice_left
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 6
        ld a,163
        call t_expect_z

        ; Each radio group contributes one Tab stop.  The checked member wins;
        ; with no selection the first available member wins in both directions.
        xor a
        ld (choice_window+WIN_WND_FOCUS),a
        ld de,choice_window
        call win_update
        ld hl,keys_tab
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 6
        ld a,164
        call t_expect_z
        ld hl,keys_tab
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 7
        ld a,165
        call t_expect_z
        ld a,(choice_radio_g2a+WIN_CH_FLAGS)
        and #ff-WIN_CH_CHECKED
        ld (choice_radio_g2a+WIN_CH_FLAGS),a
        ld a,(choice_radio_g2b+WIN_CH_FLAGS)
        and #ff-WIN_CH_CHECKED
        ld (choice_radio_g2b+WIN_CH_FLAGS),a
        ld a,6
        ld (choice_window+WIN_WND_FOCUS),a
        ld de,choice_window
        call win_update
        ld hl,keys_tab
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 7
        ld a,166
        call t_expect_z
        ld hl,keys_shift_tab
        call choice_key
        ld a,(choice_window+WIN_WND_FOCUS)
        cp 6
        ld a,167
        call t_expect_z

        ; Descriptor- and item-disabled choices neither click nor enter the
        ; focus ring.
        ld a,(choice_disabled+WIN_CH_FLAGS)
        ld (saved_page),a
        ld hl,70
        ld a,31
        call choice_click
        ld a,d
        or a
        ld a,168
        call t_expect_z
        ld a,(choice_disabled+WIN_CH_FLAGS)
        ld b,a
        ld a,(saved_page)
        cp b
        ld a,169
        call t_expect_z

        ; Programmatic CHECKED+DIRTY is rendered without changing state.
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        or WIN_CH_CHECKED
        ld (choice_checkbox+WIN_CH_FLAGS),a
        ld hl,choice_items+WIN_ITEM_FLAGS
        set 0,(hl)
        ld de,choice_window
        call win_update
        or a
        ld a,170
        call t_expect_z
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        ld a,171
        call t_expect_nz
        ld a,(choice_items+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,172
        call t_expect_z

        ; A malformed descriptor aborts preflight before state or cursor
        ; changes, even when Space is already queued.
        xor a
        ld (choice_checkbox+WIN_CH_RESERVED),a
        inc a
        ld (choice_checkbox+WIN_CH_RESERVED),a
        xor a
        ld (mock_hide_count),a
        ld (mock_show_count),a
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        ld (saved_page),a
        ld hl,keys_space
        call choice_key
        cp WIN_ERR_ARGUMENT
        ld a,173
        call t_expect_z
        ld a,(choice_checkbox+WIN_CH_FLAGS)
        ld b,a
        ld a,(saved_page)
        cp b
        ld a,174
        call t_expect_z
        ld a,(mock_hide_count)
        or a
        ld a,175
        call t_expect_z
        ld a,(mock_show_count)
        or a
        ld a,176
        call t_expect_z
        xor a
        ld (choice_checkbox+WIN_CH_RESERVED),a
        ld (mock_key_count),a
        ret

; Restore all mutable descriptors/items so Stage 6 is deterministic even
; after the Stage 4/5 focus and cursor suites.
choice_reset_state:
        xor a
        ld (choice_checkbox+WIN_CH_FLAGS),a
        ld a,WIN_CH_DISABLED
        ld (choice_disabled+WIN_CH_FLAGS),a
        ld a,WIN_CH_CHECKED
        ld (choice_radio_a+WIN_CH_FLAGS),a
        xor a
        ld (choice_radio_b+WIN_CH_FLAGS),a
        ld (choice_radio_hidden+WIN_CH_FLAGS),a
        ld (choice_radio_disabled+WIN_CH_FLAGS),a
        ld (choice_radio_c+WIN_CH_FLAGS),a
        ld (choice_radio_g2b+WIN_CH_FLAGS),a
        ld (choice_item_disabled+WIN_CH_FLAGS),a
        ld a,WIN_CH_CHECKED
        ld (choice_radio_g2a+WIN_CH_FLAGS),a
        xor a
        ld (choice_window+WIN_WND_FOCUS),a
        ld a,#ff
        ld (choice_window+WIN_WND_LAST_FOCUS),a
        ld hl,choice_items
        ld b,CHOICE_ITEM_COUNT
.items:
        inc hl
        set 0,(hl)
        ld de,WIN_ITEM_SIZE-1
        add hl,de
        djnz .items
        call choice_clear_track
        ret

choice_clear_track:
        ld hl,choice_track+WIN_TRK_EVENT
        ld b,WIN_TRACK_SIZE-WIN_TRK_EVENT
        xor a
.track:
        ld (hl),a
        inc hl
        djnz .track
        ld a,WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ld (choice_track+WIN_TRK_OPTIONS),a
        xor a
        ld (mock_mouse_buttons),a
        ret

; HL=screen x, A=screen y. Return the release iteration's A/DE.
choice_click:
        ld (mock_mouse_x),hl
        ld (mock_mouse_y),a
        call choice_clear_track
        ld de,choice_track
        call win_poll
        ld a,1
        ld (mock_mouse_buttons),a
        ld de,choice_track
        call win_poll
        xor a
        ld (mock_mouse_buttons),a
        ld de,choice_track
        jp win_poll

; HL points to one three-byte keyboard record. Return A/DE from win_poll.
choice_key:
        ld a,1
        call set_keys
        ld de,choice_track
        jp win_poll

        assert $ < TEST_RESULT
