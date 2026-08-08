; WIN320 stage 3: mouse/keyboard tracking and BIOS cursor helpers.
; Firmware calls below are made with the normal application mapping restored;
; no mouse or DSS entry is ever issued from a drawing DI section.

S3_ST_INIT_XH          equ 0       ; bit 7 = initialized, bit 0 = X bit 8
S3_ST_XL               equ 1
S3_ST_Y                equ 2
S3_ST_BUTTONS          equ 3
S3_ST_HIT              equ 4
S3_ST_HOVER            equ 5
S3_ST_CAPTURE          equ 6
S3_ST_REPEAT           equ 7

; ---- public entries -------------------------------------------------------

win_poll:
        push bc
        push hl
        push ix
        push iy
        call s3_poll
        pop iy
        pop ix
        pop hl
        pop bc
        ret

win_track:
        push bc
        push hl
        push ix
        push iy
        ld (s3_track_ptr),de
        xor a
        ld (s3_track_cursor),a
        call s1_copy_track_block
        jr nz,.setup_done
        call s3_preflight
        jr nz,.setup_done
        ld hl,s3_track_scratch+WIN_TRK_OPTIONS
        bit 3,(hl)
        jr z,.loop
        ld c,1
        call win_mouse_call
        jr c,.bios_error
        ld a,1
        ld (s3_track_cursor),a
.loop:
        ld de,(s3_track_ptr)
        call s3_poll
        ld (s3_return_a),a          ; D below is the event, not status
        jr c,.finish
        ld a,d
        or a
        jr nz,.finish
        ld hl,(s3_track_ptr)
        ld de,WIN_TRK_OPTIONS
        add hl,de
        bit 2,(hl)
        call nz,win_halt_call
        jr .loop
.bios_error:
        ld a,WIN_ERR_UNSUPPORTED
        ld (s3_return_a),a
        jr .finish
.setup_done:
        ld (s3_return_a),a
.finish:
        ld (s3_return_de),de
        ld a,(s3_track_cursor)
        or a
        jr z,.restore
        ld c,2
        call win_mouse_call
        jr nc,.restore
        ld a,WIN_ERR_UNSUPPORTED
        ld (s3_return_a),a
.restore:
        pop iy
        pop ix
        pop hl
        pop bc
        ld de,(s3_return_de)
        ld a,(s3_return_a)
        ret

; Wait until all mouse buttons are released, draining SCANKEY on every pass.
win_wait_release:
        push af
        push bc
        push de
        push hl
.again:
        ld c,3
        call win_mouse_call
        jr c,.unsupported
        ld (s3_wait_buttons),a
.drain:
        ld c,#31
        call win_scankey_call
        jr z,.keys_empty
        jr .drain
.keys_empty:
        ld a,(s3_wait_buttons)
        or a
        jr nz,.again
        xor a
        ld (s3_result),a
        jr .done
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        ld (s3_result),a
.done:
        pop hl
        pop de
        pop bc
        pop af
        ld a,(s3_result)
        or a
        ret z
        scf
        ret

; E=0 arrow, 1 wait, #ff custom (IX=&WinCursor).  LOAD only: no HALT and no
; cursor visibility change are hidden in this entry.
win_set_cursor:
        push bc
        push de
        push hl
        push ix
        ld a,e
        or a
        jr z,.arrow
        cp 1
        jr z,.wait
        cp #ff
        jp nz,.argument
        push ix
        pop de
        ld bc,WIN_CURSOR_SIZE
        ld hl,s3_cursor_scratch
        call s1_copy_caller_block
        jp nz,.argument
        ld a,(s3_cursor_scratch+WIN_CUR_WIDTH)
        or a
        jr z,.argument
        cp 33
        jr nc,.argument
        ld b,a
        ld a,(s3_cursor_scratch+WIN_CUR_HEIGHT)
        or a
        jr z,.argument
        cp 33
        jr nc,.argument
        ld c,a
        ld a,(s3_cursor_scratch+WIN_CUR_HOT_X)
        cp b
        jr nc,.argument
        ld a,(s3_cursor_scratch+WIN_CUR_HOT_Y)
        cp c
        jr nc,.argument
        ; width*height is at most 1024 here; BIOS accepts at most 256.
        ld a,b
        ld e,c
        call s3_mul8
        ld a,h
        or a
        jr nz,.argument
        ld a,l
        or a
        jr z,.argument
        ld b,h                      ; exact byte count for s1_validate_caller_range
        ld c,l
        ; IX still points at the caller header.  Pixel range starts at +4.
        push ix
        pop hl
        ld de,WIN_CURSOR_SIZE
        add hl,de
        call s1_validate_caller_range
        jr c,.argument
        ld a,(s3_cursor_scratch+WIN_CUR_HEIGHT)
        ld h,a
        ld a,(s3_cursor_scratch+WIN_CUR_WIDTH)
        ld l,a
        ld a,(s3_cursor_scratch+WIN_CUR_HOT_X)
        ld e,a
        ld a,(s3_cursor_scratch+WIN_CUR_HOT_Y)
        ld d,a
        jr .load
.arrow:
        ld hl,s3_cursor_arrow_packed
        ld b,30
        call s3_unpack_cursor
        ld hl,#0d09
        ld de,0
        jr .load
.wait:
        ld hl,s3_cursor_wait_packed
        ld b,32
        call s3_unpack_cursor
        ld hl,#0e09
        ld de,#0704
.load:
        ld c,9
        call win_mouse_call
        jr c,.bios_error
        pop ix
        pop hl
        pop de
        pop bc
        xor a
        ret
.bios_error:
        pop ix
        pop hl
        pop de
        pop bc
        ld a,WIN_ERR_UNSUPPORTED
        scf
        ret
.argument:
        pop ix
        pop hl
        pop de
        pop bc
        ld a,WIN_ERR_ARGUMENT
        scf
        ret

; ---- one fully atomic tracking iteration ---------------------------------

; DE=&WinTrack.  Success returns A=0,D=event,E=id.  On error output fields
; and state were never copied back to the caller.
s3_poll:
        ld (s3_track_ptr),de
        call s1_copy_track_block
        jr nz,.argument
        call s3_preflight
        jr nz,.return_error
        call s3_clear_output
        ld hl,(s3_track_scratch+WIN_TRK_WINDOW)
        ld a,h
        or l
        jr z,.keyboard
        ld c,3
        call win_mouse_call
        jr c,.unsupported
        ld (s3_mouse_buttons),a
        ld (s3_mouse_x),hl
        ld a,e
        ld (s3_mouse_y),a
        call s3_store_mouse_output
        call s3_mouse_iteration
        jr nc,.keyboard
        ld a,(s3_runtime_error)
        or a
        jr nz,.runtime_error
        jr .commit                    ; a mouse event has priority over key
.keyboard:
        call s3_keyboard_iteration
        ld a,(s3_runtime_error)
        or a
        jr nz,.runtime_error
.commit:
        call s3_commit
        xor a
        ret
.argument:
        ld a,WIN_ERR_ARGUMENT
        scf
        ret
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        scf
        ret
.runtime_error:
        scf
        ret
.return_error:
        scf
        ret

; Validate writable WinTrack, options, key table, window and the complete
; item/control range before a single result/state byte is changed.
s3_preflight:
        ld a,(s3_track_scratch+WIN_TRK_RESERVED)
        or a
        jr nz,.bad
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and #e0
        jr nz,.bad
        call s3_validate_keys
        ret nz
        ld de,(s3_track_scratch+WIN_TRK_WINDOW)
        ld a,d
        or e
        ret z
        call s2_load_window
        ret nz
        jp s3_validate_items
.bad:
        jp win_error_argument

s3_validate_keys:
        ld a,(s3_track_scratch+WIN_TRK_KEY_COUNT)
        or a
        ret z
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d
        ld b,d
        ld c,e
        ld hl,(s3_track_scratch+WIN_TRK_KEYS)
        ld a,h
        or l
        jr z,.bad
        call s1_validate_caller_range
        jr c,.bad
        xor a
        ret
.bad:
        jp win_error_argument

s3_validate_items:
        xor a
        ld (s3_scan_index),a
.loop:
        ld a,(s3_scan_index)
        ld b,a
        ld a,(window_scratch+WIN_WND_COUNT)
        cp b
        jr z,.ok
        ld a,b
        call s2_load_item_index
        call s3_validate_item
        ret nz
        ld hl,s3_scan_index
        inc (hl)
        jr .loop
.ok:
        xor a
        ret

s3_validate_item:
        call s2_validate_item
        ret nz
        call s6_validate_choice_item
        ret nz
        ld a,(item_scratch+WIN_ITEM_TYPE)
        or a
        jr nz,.control
        xor a
        ret
.control:
        call s2_check_control_geometry
        ret nz
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT
        ret z
        jp s2_require_nonempty_geometry

s3_clear_output:
        xor a
        ld (s3_runtime_error),a
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        ld (s3_track_scratch+WIN_TRK_ID),a
        ld a,#ff
        ld (s3_track_scratch+WIN_TRK_INDEX),a
        xor a
        ld (s3_track_scratch+WIN_TRK_PART),a
        ld (s3_track_scratch+WIN_TRK_KEY_ASCII),a
        ld (s3_track_scratch+WIN_TRK_KEY_SCAN),a
        ld (s3_track_scratch+WIN_TRK_KEY_MODS),a
        ld (s3_track_scratch+WIN_TRK_ITEM),a
        ld (s3_track_scratch+WIN_TRK_ITEM+1),a
        ld (s3_track_scratch+WIN_TRK_USER_DATA),a
        ld (s3_track_scratch+WIN_TRK_USER_DATA+1),a
        ret

s3_store_mouse_output:
        ld hl,(s3_mouse_x)
        ld (s3_track_scratch+WIN_TRK_MOUSE_X),hl
        ld a,(s3_mouse_y)
        ld (s3_track_scratch+WIN_TRK_MOUSE_Y),a
        ld a,(s3_mouse_buttons)
        ld (s3_track_scratch+WIN_TRK_BUTTONS),a
        ret

; C set means a mouse event was selected, so SCANKEY must not be consumed.
s3_mouse_iteration:
        call s3_find_hit
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_INIT_XH)
        bit 7,a
        jr nz,.initialized
        call s3_store_state_pos
        ld a,(s3_mouse_buttons)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS),a
        ld a,(s3_current_hit)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_HIT),a
        ld a,#ff
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_HOVER),a
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE),a
        xor a
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_REPEAT),a
        or a
        ret
.initialized:
        ; Coordinates and cached hit are owned by this WinTrack only.
        ld a,(s3_mouse_x+1)
        and 1
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_INIT_XH)
        and 1
        cp b
        jr nz,.rehit
        ld a,(s3_mouse_x)
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_XL)
        cp b
        jr nz,.rehit
        ld a,(s3_mouse_y)
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_Y)
        cp b
        jr nz,.rehit
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_HIT)
        ld (s3_current_hit),a
        jr .actions
.rehit:
        call s3_find_hit
.actions:
        call s3_store_state_pos
        ld a,(s3_current_hit)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_HIT),a
        call s3_left_action
        ret c
        call s3_right_action
        ret c
        call s3_hover_action
        ret c
        ld a,(s3_mouse_buttons)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS),a
        or a
        ret

; Store the current mouse x/y into WinTrack state (INIT_XH/XL/Y fields).
s3_store_state_pos:
        ld a,(s3_mouse_x+1)
        and 1
        or #80
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_INIT_XH),a
        ld a,(s3_mouse_x)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_XL),a
        ld a,(s3_mouse_y)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_Y),a
        ret

; A full reverse-order common-header hit test.  Half-open edges mean the
; right/bottom border belongs to the next object, never both.
s3_find_hit:
        call s7_chrome_hit
        jr nc,.scan
        ld (s3_current_hit),a
        ret
.scan:
        ld a,#ff
        ld (s3_current_hit),a
        ld a,(window_scratch+WIN_WND_COUNT)
        or a
        ret z
        dec a
        ld (s3_scan_index),a
.loop:
        ld a,(s3_scan_index)
        call s2_load_item_index
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIDDEN|WIN_IT_DISABLED|WIN_IT_HIT
        cp WIN_IT_HIT
        jr nz,.next
        call s6_choice_enabled
        jr nz,.next
        call s2_load_control_geometry
        jr nz,.next
        call s3_point_in_geometry
        jr nc,.next
        ld a,(s3_scan_index)
        ld (s3_current_hit),a
        ret
.next:
        ld hl,s3_scan_index
        ld a,(hl)
        or a
        ret z
        dec (hl)
        jr .loop

; C=set if mouse is inside control_geometry relative to window_scratch.
s3_point_in_geometry:
        ld hl,(s3_mouse_x)
        ld de,(window_scratch+WIN_WND_X)
        or a
        sbc hl,de
        jr c,.outside
        ld de,(control_geometry+0)
        or a
        sbc hl,de
        jr c,.outside
        ld de,(control_geometry+4)
        or a
        sbc hl,de
        ret nc
        ld a,(s3_mouse_y)
        ld l,a
        ld h,0
        ld de,(window_scratch+WIN_WND_Y)
        or a
        sbc hl,de
        jr c,.outside
        ld de,(control_geometry+2)
        or a
        sbc hl,de
        jr c,.outside
        ld de,(control_geometry+6)
        or a
        sbc hl,de
        ret nc
        scf
        ret
.outside:
        or a
        ret

s3_left_action:
        ld a,(s3_mouse_buttons)
        bit 0,a
        jp z,.released
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS)
        bit 0,a
        jr nz,.held
        xor a
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_REPEAT),a
        ld a,(s3_current_hit)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE),a
        cp #ff
        jr nz,.press_item
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and WIN_TRK_OUTSIDE
        ret z
        ld a,WIN_EV_OUTSIDE
        jp s3_emit_outside
.press_item:
        ld a,(s3_current_hit)
        ld b,1
        call s3_set_pressed_index
        call s3_current_is_repeat
        ret nc
        ld a,WIN_EV_LCLICK
        jp s3_emit_current
.held:
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE)
        cp #ff
        ret z
        ld (s3_capture_index),a
        ld b,0
        ld a,(s3_current_hit)
        ld c,a
        ld a,(s3_capture_index)
        cp c
        jr nz,.paint
        ld b,1
.paint:
        ; Redraw (and the SHOW_CUR hide/show pair inside it) only on an actual
        ; press/release transition, not every idle tick while simply held:
        ; repeated same-state hide/show at a stationary position was found to
        ; corrupt the focus ring. s3_press_value already tracks what was last
        ; drawn (set by s3_set_pressed_index on every call, B is always 0/1).
        ld a,(s3_press_value)
        cp b
        jr z,.skip_paint
        ld a,(s3_capture_index)
        call s3_set_pressed_index
.skip_paint:
        ld a,(s3_capture_index)
        call s3_index_is_repeat
        ret nc
        ld a,(s3_current_hit)
        ld b,a
        ld a,(s3_capture_index)
        cp b
        jr nz,.reset
        ld hl,s3_track_scratch+WIN_TRK_STATE+S3_ST_REPEAT
        inc (hl)
        ld a,(hl)
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_REPEAT_DELAY)
        or a
        jr nz,.delay
        ld a,WIN_REPEAT_DELAY
.delay:
        cp b
        ret nz
        ld (s3_repeat_delay_value),a
        ld a,(s3_track_scratch+WIN_TRK_REPEAT_RATE)
        or a
        jr nz,.rate
        ld a,WIN_REPEAT_RATE
.rate:
        ld b,a
        ld a,(s3_repeat_delay_value)
        sub b
        jr nc,.store_repeat
        xor a
.store_repeat:
        ld (hl),a
        ld a,WIN_EV_REPEAT
        jp s3_emit_capture
.reset:
        xor a
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_REPEAT),a
        ret
.released:
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS)
        bit 0,a
        ret z
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE)
        cp #ff
        jr z,.clear
        cp #fd
        jr nc,.chrome_release
        ld (s3_capture_index),a
        ld b,0
        call s3_set_pressed_index
        ld a,(s3_capture_index)
        call s3_index_is_repeat
        jr c,.clear
        ld a,(s3_current_hit)
        ld b,a
        ld a,(s3_capture_index)
        cp b
        jr nz,.clear
        ld a,WIN_EV_LCLICK
        call s3_emit_capture
.clear:
        jp s3_clear_capture
.chrome_release:
        cp #fe
        jr nz,.clear                 ; strip: absorb without an event
        ld b,0
        call s3_set_pressed_index    ; unpress the close button visual
        ld a,(s3_current_hit)
        cp #fe
        jr nz,.clear                 ; released outside the button: cancel
        call s3_clear_capture
        ld a,WIN_EV_CLOSE
        jp s3_emit_outside

s3_clear_capture:
        ld a,#ff
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE),a
        xor a
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_REPEAT),a
        ret

s3_right_action:
        ld a,(s3_mouse_buttons)
        bit 1,a
        ret z
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS)
        bit 1,a
        ret nz
        ld a,(s3_current_hit)
        cp #ff
        jr nz,.item
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and WIN_TRK_OUTSIDE
        ret z
        ld a,WIN_EV_OUTSIDE
        jp s3_emit_outside
.item:
        ld a,WIN_EV_RCLICK
        jp s3_emit_current

; A mouse action wins this iteration.  We deliberately leave the old hover
; state intact in that case, making a collision a deferred, not lost, event.
s3_hover_action:
        ld a,(s3_current_hit)
        ld (s3_hover_candidate),a
        cp #ff
        jr z,.compare
        call s3_current_has_hover
        jr c,.compare
        ld a,#ff
        ld (s3_hover_candidate),a
.compare:
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_HOVER)
        ld b,a
        ld a,(s3_hover_candidate)
        cp b
        ret z
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_HOVER),a
        ld a,b
        cp #ff
        jr z,.enter
        ld (s3_event_index),a
        ld a,WIN_EV_LEAVE
        jp s3_emit_index
.enter:
        ld a,(s3_hover_candidate)
        ld (s3_event_index),a
        ld a,WIN_EV_HOVER
        jp s3_emit_index

s3_keyboard_iteration:
        ; SCANKEY leaves Z set both for an empty buffer and for non-ASCII
        ; navigation keys (E=0).  CTRLKEY distinguishes the two cases.
        ld c,#33
        call win_scankey_call
        ret z
        ld c,#31
        call win_scankey_call
        ld a,e
        ld (s3_track_scratch+WIN_TRK_KEY_ASCII),a
        ld a,d
        ld (s3_track_scratch+WIN_TRK_KEY_SCAN),a
        ld a,b
        ld (s3_track_scratch+WIN_TRK_KEY_MODS),a
        call s4_keyboard_focus
        ret c
        jr s3_find_key

; C=set on a selected hotkey/any-key event.
s3_find_key:
        ld a,(s3_track_scratch+WIN_TRK_KEY_COUNT)
        ld (s3_keys_left),a
        ld hl,(s3_track_scratch+WIN_TRK_KEYS)
        ld (s3_key_ptr),hl
.loop:
        ld a,(s3_keys_left)
        or a
        jr z,.any
        ld hl,(s3_key_ptr)
        ld a,(hl)
        ld (s3_key_ascii),a
        inc hl
        ld a,(hl)
        ld (s3_key_scan),a
        inc hl
        ld a,(hl)
        ld (s3_key_mods),a
        inc hl
        ld a,(hl)
        ld (s3_key_id),a
        inc hl
        ld (s3_key_ptr),hl
        ld a,(s3_track_scratch+WIN_TRK_KEY_MODS)
        ld b,a
        ld a,(s3_key_mods)
        cp b
        jr nz,.next
        ld a,(s3_key_ascii)
        or a
        jr z,.scan
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_KEY_ASCII)
        cp b
        jr nz,.next
.scan:
        ld a,(s3_key_scan)
        or a
        jr z,.match
        ld b,a
        ld a,(s3_track_scratch+WIN_TRK_KEY_SCAN)
        and #7f
        cp b
        jr nz,.next
.match:
        ld a,WIN_EV_HOTKEY
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        ld a,(s3_key_id)
        ld (s3_track_scratch+WIN_TRK_ID),a
        scf
        ret
.next:
        ld hl,s3_keys_left
        dec (hl)
        jr .loop
.any:
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and WIN_TRK_ANY_KEY
        ret z
        ld a,WIN_EV_KEY
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        xor a
        ld (s3_track_scratch+WIN_TRK_ID),a
        scf
        ret

; ---- event helpers --------------------------------------------------------

s3_current_is_repeat:
        ld a,(s3_current_hit)
s3_index_is_repeat:
        ld (s3_event_index),a
        call s3_load_event_item
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_REPEAT
        ret z
        scf
        ret

s3_current_has_hover:
        ld a,(s3_current_hit)
        ld (s3_event_index),a
        call s3_load_event_item
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HOVER
        ret z
        scf
        ret

s3_emit_current:
        ld (s3_pending_event),a
        ld a,(s3_current_hit)
        ld (s3_event_index),a
        ld a,(s3_pending_event)
        jr s3_emit_index

s3_emit_capture:
        ld (s3_pending_event),a
        ld a,(s3_track_scratch+WIN_TRK_STATE+S3_ST_CAPTURE)
        ld (s3_event_index),a
        ld a,(s3_pending_event)
        ; fall through
s3_emit_index:
        ld (s3_pending_event),a
        cp WIN_EV_LCLICK
        jr nz,.focused
        call s6_choice_click
        jr nc,.normal_click
        cp WIN_EV_CHANGE
        jr z,.choice_changed
        or a
        ret z                         ; selected radio: absorb the activation
        ld (s3_runtime_error),a
        scf
        ret
.choice_changed:
        ld (s3_pending_event),a
        jr .focused
.normal_click:
        call s4_focus_click
        jr z,.focused
        ld (s3_runtime_error),a
        scf
        ret
.focused:
        ld a,(s3_pending_event)
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        call s3_load_event_item
        ifdef WIN320_TEST_BUILD
        call s5_hit_detail
        else
        call s5_overlay_base+18
        endif
        ld a,(s3_event_index)
        ld (s3_track_scratch+WIN_TRK_INDEX),a
        ld a,(item_scratch+WIN_ITEM_ID)
        ld (s3_track_scratch+WIN_TRK_ID),a
        ld hl,(item_scratch+WIN_ITEM_USER_DATA)
        ld (s3_track_scratch+WIN_TRK_USER_DATA),hl
        ld a,(s3_mouse_buttons)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS),a
        scf
        ret

s3_emit_outside:
        ld (s3_track_scratch+WIN_TRK_EVENT),a
        ld a,#ff
        ld (s3_track_scratch+WIN_TRK_ID),a
        ld (s3_track_scratch+WIN_TRK_INDEX),a
        ld a,(s3_mouse_buttons)
        ld (s3_track_scratch+WIN_TRK_STATE+S3_ST_BUTTONS),a
        scf
        ret

; Chrome sentinels (#fd strip, #fe close button) have no backing WinItem;
; report a type/flags that never match REPEAT or HOVER instead of indexing
; the array with a wild offset.
s3_load_event_item:
        ld a,(s3_event_index)
        cp #fd
        jr c,.item
        xor a
        ld (item_scratch+WIN_ITEM_TYPE),a
        ld (item_scratch+WIN_ITEM_FLAGS),a
        ret
.item:
        jp s2_load_item_index

; WIN_IT_PRESS has an intrinsic visual effect only for WIN_T_BUTTON.  The
; caller's button flag changes after its replacement image was drawn; item
; DIRTY is intentionally untouched.  Other current control types keep the
; flag as a behavioural marker without a built-in picture.
; A=item index, B=0 released / non-zero pressed.
s3_set_pressed_index:
        ld (s3_event_index),a
        ld c,a
        ld a,b
        ld (s3_press_value),a
        ld a,c
        cp #fe
        jr z,.chrome_button
        cp #fd
        jr nc,.done                  ; strip (or any other sentinel): no visual
        call s3_load_event_item
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_PRESS
        jr z,.done
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_BUTTON
        jr nz,.done
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        ld (s3_button_ptr),de
        call s1_copy_button_block
        jr nz,.done
        jr .flags
.chrome_button:
        call s7_stage_close_button
.flags:
        ld a,(button_scratch+WIN_BTN_FLAGS)
        ld b,a
        ld a,(s3_press_value)
        or a
        jr z,.release
        set 2,b
        jr .draw
.release:
        res 2,b
.draw:
        ld a,b
        ld (button_scratch+WIN_BTN_FLAGS),a
        xor a
        ld (s3_cursor_hidden),a
        ld hl,s3_track_scratch+WIN_TRK_OPTIONS
        bit 3,(hl)
        jr z,.origin
        ld c,2
        call win_mouse_call
        jr c,.origin
        ld a,1
        ld (s3_cursor_hidden),a
.origin:
        call s2_set_window_origin
        call s1_button_loaded
        ld (s3_button_draw_error),a
        call s2_restore_origin
        ld a,(s3_cursor_hidden)
        or a
        jr z,.publish
        ld c,1
        call win_mouse_call
.publish:
        ld a,(s3_event_index)
        cp #fe
        jr z,.done                   ; chrome: no caller descriptor to update
        ld a,(s3_button_draw_error)
        or a
        jr nz,.done
        ld hl,(s3_button_ptr)
        ld de,WIN_BTN_FLAGS
        add hl,de
        ld a,(button_scratch+WIN_BTN_FLAGS)
        ld (hl),a
.done:
        or a
        ret

; Copy all fields that may change (6..31) only after the iteration has
; completed successfully.  This is the error atomicity boundary.
s3_commit:
        ld hl,s3_track_scratch+WIN_TRK_EVENT
        ld de,(s3_track_ptr)
        ld bc,WIN_TRK_EVENT
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,WIN_TRACK_SIZE-WIN_TRK_EVENT
        ldir
        ld a,(s3_track_scratch+WIN_TRK_EVENT)
        ld d,a
        ld a,(s3_track_scratch+WIN_TRK_ID)
        ld e,a
        xor a                       ; ABI: A=0, D=event, E=id
        ret

; A*E -> HL, used only for custom cursor size validation.
s3_mul8:
        ld h,0
        ld l,0
        ld c,a
        ld b,0
        ld a,e
.mul_loop:
        add hl,bc
        dec a
        jr nz,.mul_loop
        ret

; ---- stage-3 internal state ----------------------------------------------

s3_track_ptr:          dw 0
s3_mouse_x:            dw 0
s3_mouse_y:            db 0
s3_mouse_buttons:      db 0
s3_wait_buttons:       db 0
s3_result:             db 0
s3_track_cursor:       db 0
s3_return_a:           db 0
s3_return_de:          dw 0
s3_scan_index:         db 0
s3_current_hit:        db #ff
s3_hover_candidate:    db #ff
s3_event_index:        db #ff
s3_pending_event:      db 0
s3_keys_left:          db 0
s3_key_ascii:          db 0
s3_key_scan:           db 0
s3_key_mods:           db 0
s3_key_id:             db 0
s3_key_ptr:            dw 0
s3_capture_index:      db #ff
s3_repeat_delay_value: db 0
s3_press_value:        db 0
s3_button_ptr:         dw 0
s3_button_draw_error:  db 0
s3_cursor_hidden:      db 0
s3_runtime_error:      db 0
s3_cursor_scratch      equ path_scratch
s3_track_scratch:      ds WIN_TRACK_SIZE,0

; Exact gfxview BIOS cursor payloads: arrow 9x13, wait 9x14.
; Built-in cursors use a compact 2-bit stream (0, #fe, #ff, #f0).  Expanding
; into the shared graphics workspace saves 136 bytes in the L0 prefix.
s3_unpack_cursor:
        ld de,xor_scratch
s3_unpack_byte:
        ld a,(hl)
        inc hl
        ld (s3_unpack_cursor_shift+1),a
        ld c,4
s3_unpack_pixel:
s3_unpack_cursor_shift:
        ld a,0
        rlca
        rlca
        ld (s3_unpack_cursor_shift+1),a
        and 3
        jr z,s3_unpack_store
        cp 1
        jr nz,s3_unpack_opaque
        ld a,#fe
        jr s3_unpack_store
s3_unpack_opaque:
        cp 2
        ld a,#ff
        jr z,s3_unpack_store
        ld a,#f0
s3_unpack_store:
        ld (de),a
        inc de
        dec c
        jr nz,s3_unpack_pixel
        djnz s3_unpack_byte
        ld ix,xor_scratch
        ret

s3_cursor_arrow_packed:
        db #0a,#aa,#84,#aa,#a1,#4a,#a8,#54,#aa,#15
        db #4a,#85,#54,#a1,#55,#48,#55,#00,#14,#4a
        db #84,#14,#a0,#a1,#28,#a8,#52,#aa,#82,#80
s3_cursor_wait_packed:
        db #00,#00,#05,#55,#40,#00,#02,#15,#52,#85,#44
        db #a8,#74,#aa,#84,#aa,#a1,#2a,#a1,#d2,#a1,#51
        db #28,#55,#48,#00,#00,#15,#55,#00,#00,#00
