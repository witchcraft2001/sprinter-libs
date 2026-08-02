; WIN320 stage 4: single-line editing and declarative keyboard focus.
; Firmware calls are made only after the drawing mappings have been restored.

S4_SCAN_DELETE         equ #4f
S4_SCAN_END            equ #51
S4_SCAN_LEFT           equ #54
S4_SCAN_RIGHT          equ #56
S4_SCAN_HOME           equ #57
S4_CARET_TICKS         equ 14

; ---- public edit entries -------------------------------------------------

win_edit_draw:
        push bc
        push de
        push hl
        push ix
        push iy
        ld (s4_edit_ptr),de
        call s4_edit_draw_ptr
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        or a
        ret

; DE=&WinEdit, IX=&WinTrack or zero.  A=status, E=WIN_ED_* reason.
win_edit:
        push bc
        push de
        push hl
        push ix
        push iy
        ld (s4_edit_ptr),de
        ld (s4_track_ptr),ix
        call s4_edit_run
        ld (s4_result),a
        ld a,e
        ld (s4_reason),a
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        ld a,(s4_reason)
        ld e,a
        ld a,(s4_result)
        or a
        ret

s4_edit_draw_ptr:
        call s4_load_edit
        ret nz
        jp s4_render_loaded_edit

; ---- descriptor validation and rendering --------------------------------

s4_load_edit:
        ld de,(s4_edit_ptr)
        ld bc,WIN_EDIT_SIZE
        ld hl,s4_edit_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and #f8
        jp nz,.unsupported
        ld a,(s4_edit_scratch+WIN_ED_MAXLEN)
        or a
        jp z,.bad
        cp 64
        jp nc,.bad
        ld (s4_maxlen),a

        ld hl,(s4_edit_scratch+WIN_ED_WIDTH)
        ld a,h
        or l
        jp z,.bad
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_FRAME
        jr z,.plain_size
        ld hl,(s4_edit_scratch+WIN_ED_WIDTH)
        ld de,5
        or a
        sbc hl,de
        jp c,.bad
        ld hl,(s4_edit_scratch+WIN_ED_HEIGHT)
        ld de,12
        or a
        sbc hl,de
        jp c,.bad
        jr .geometry
.plain_size:
        ld hl,(s4_edit_scratch+WIN_ED_HEIGHT)
        ld de,8
        or a
        sbc hl,de
        jp c,.bad
.geometry:
        ld hl,s4_edit_scratch
        xor a
        ld (rect_scratch+WIN_RC_FLAGS),a
        ld a,#ff
        ld (rect_scratch+WIN_RC_COLOR),a
        call s1_load_control_rect
        ret nz
        ld hl,(rect_x)
        ld (s4_content_x),hl
        ld hl,(rect_w)
        ld (s4_content_w),hl
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_FRAME
        jr z,.plain_content
        ld hl,(s4_content_x)
        inc hl
        inc hl
        ld (s4_content_x),hl
        ld hl,(s4_content_w)
        ld de,4
        or a
        sbc hl,de
        ld (s4_content_w),hl
.plain_content:
        ld de,8
        ld hl,(rect_h)
        or a
        sbc hl,de
        srl h
        rr l
        ld de,(rect_y)
        add hl,de
        ld (s4_text_y),hl

        ld hl,(s4_edit_scratch+WIN_ED_BUFFER)
        ld a,h
        or l
        jr z,.bad
        ld (s4_buffer_ptr),hl
        ld a,(s4_maxlen)
        inc a
        ld c,a
        ld b,0
        call s1_validate_caller_range
        jr c,.bad
        call s4_recount_buffer
        ret nz
        ld a,(s4_len)
        ld (s4_edit_scratch+WIN_ED_LEN),a
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        cp b
        jr c,.cursor_ok
        ld a,b
.cursor_ok:
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        cp b
        jr c,.scroll_ok
        ld a,b
.scroll_ok:
        ld (s4_edit_scratch+WIN_ED_SCROLL),a
        call s4_update_scroll
        xor a
        ret
.unsupported:
        jp win_reserved
.bad:
        jp win_error_argument

; Recompute s4_len and s4_data_ptr from the selected public string format.
s4_recount_buffer:
        ld hl,(s4_buffer_ptr)
        ld a,(text_format)
        or a
        jr nz,.pascal
        ld (s4_data_ptr),hl
        ld a,(s4_maxlen)
        inc a
        ld b,a
        ld c,0
.asciiz:
        ld a,(hl)
        or a
        jr z,.store
        inc hl
        inc c
        djnz .asciiz
        jr .bad
.pascal:
        ld a,(hl)
        ld b,a
        ld a,(s4_maxlen)
        cp b
        jr c,.bad
        ld c,b
        inc hl
        ld (s4_data_ptr),hl
.store:
        ld a,c
        ld (s4_len),a
        xor a
        ret
.bad:
        jp win_error_argument

; Keep the cursor cell visible when possible, but never render a partial glyph.
s4_update_scroll:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        cp b
        jr c,.again
        jr z,.again
        ld a,b
        ld (s4_edit_scratch+WIN_ED_SCROLL),a
.again:
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld (s4_measure_index),a
        ld hl,0
        ld (s4_measure_width),hl
.measure:
        ld a,(s4_measure_index)
        call s4_char_width_at
        ld e,a
        ld d,0
        ld hl,(s4_measure_width)
        add hl,de
        ld (s4_measure_width),hl
        ld a,(s4_measure_index)
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        cp b
        jr z,.compare
        ld hl,s4_measure_index
        inc (hl)
        jr .measure
.compare:
        ld hl,(s4_content_w)
        ld de,(s4_measure_width)
        or a
        sbc hl,de
        ret nc
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        cp b
        ret z
        ld hl,s4_edit_scratch+WIN_ED_SCROLL
        inc (hl)
        jr .again

; A=character index, returns A=glyph width. The end cursor uses a space.
s4_char_width_at:
        ld b,a
        ld a,(s4_len)
        cp b
        jr z,.space
        jr c,.space
        ld a,b
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
        ld a,(hl)
        ld c,a
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_PASSWORD
        ld a,c
        jr z,.width
        ld a,'*'
        jr .width
.space:
        ld a,' '
.width:
        jp s1_cached_width

s4_render_loaded_edit:
        ifdef WIN320_TEST_BUILD
        ld hl,s4_test_full_edit_renders
        inc (hl)
        endif
        call s4_prepare_edit_render
        ret nz
        call s1_map_pair
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_FRAME
        jr z,.plain
        ld a,1
        ld (panel_sunken),a
        call s1_panel_mapped
        jr .text
.plain:
        call s1_copy_rect_to_fill
        ld a,(s4_background_color)
        ld (fill_color),a
        call s1_fill_mapped
.text:
        call s4_render_edit_content_mapped_fresh
        call s1_unmap_pair
        call s4_publish_edit
        xor a
        ret

; Repaint only the content rectangle. The frame is deliberately left alone:
; modal typing must not flash the bevel on every key, matching FN InputLine.
s4_render_edit_content:
        call s4_prepare_edit_render
        ret nz
        call s1_map_pair
        call s4_render_edit_content_mapped
        call s1_unmap_pair
        call s4_publish_edit
        xor a
        ret

s4_prepare_edit_render:
        ld a,(font_page)
        cp #ff
        jr z,.font
        ld a,(s4_edit_scratch+WIN_ED_ATTR)
        ld b,WIN_TH_FIELD_BG
        ld c,WIN_TH_FIELD_FG
        call s1_resolve_text_attr
        ld a,(fill_color)
        ld (s4_background_color),a
        jp s1_resolve_pair
.font:
        jp win_error_font

s4_render_edit_content_mapped:
        ld a,(s4_draw_index)
        add a,a
        call c,s4_caret_toggle_mapped
s4_render_edit_content_mapped_fresh:
        ; Glyph backgrounds overwrite the old line in-place; only the unused
        ; tail is cleared afterwards. There is no blank-field phase between
        ; keypress and text, which keeps the modal editor visually stable.
        ld hl,(s4_text_y)
        ld (fill_y),hl
        ld hl,8
        ld (fill_h),hl
        ld a,(s4_background_color)
        ld (fill_color),a

        ld hl,(s4_content_x)
        ld (s4_draw_x),hl
        ld hl,(s4_content_w)
        ld (s4_draw_left),hl
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld (s4_draw_index),a
.glyph:
        ld a,(s4_draw_index)
        ld b,a
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        cp b
        jr nz,.cursor_ready
        ld hl,(s4_draw_x)
        ld (s4_caret_x),hl
.cursor_ready:
        ld a,(s4_len)
        cp b
        jr c,.done
        jr z,.done
        ld a,b
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
        ld a,(hl)
        ld c,a
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_PASSWORD
        ld a,c
        jr z,.character
        ld a,'*'
.character:
        ld (s4_draw_char),a
        call s1_cached_width
        ld (s4_draw_char_width),a
        ld e,a
        ld d,0
        ld hl,(s4_draw_left)
        or a
        sbc hl,de
        jr c,.done
        ld (s4_draw_left),hl
        ld a,(s4_draw_char)
        ld (text_scratch),a
        xor a
        ld (text_scratch+1),a
        ld a,(text_attr)
        ld hl,text_scratch
        ld de,(s4_draw_x)
        ld bc,(s4_text_y)
        call textcore_draw_mapped
        ld a,(s4_draw_char_width)
        ld e,a
        ld d,0
        ld hl,(s4_draw_x)
        add hl,de
        ld (s4_draw_x),hl
        ld hl,s4_draw_index
        inc (hl)
        jr .glyph
.done:
        ld hl,(s4_draw_x)
        ld (fill_x),hl
        ld hl,(s4_draw_left)
        ld (fill_w),hl
        ld a,h
        or l
        call nz,s1_fill_mapped
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_FOCUS
        ret z
        ld hl,s4_draw_index
        bit 7,(hl)
        ret nz
        jp s4_caret_toggle_mapped

; Draw a solid foreground-colour caret and restore its saved background on
; the next toggle. A modal content redraw restores the complete old caret
; first, including the two pixels outside the 8-pixel framed text band.
s4_caret_toggle_mapped:
        ifdef WIN320_TEST_BUILD
        ld hl,s4_test_caret_toggles
        inc (hl)
        endif
        ld hl,(s4_caret_x)
        call s1_make_dest
        ld de,xor_scratch
        ld a,(s4_text_y)
        ld c,a
        ld b,8
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and WIN_ED_FRAME
        jr z,.height_ready
        dec c
        ld b,10
.height_ready:
        ld a,(s4_draw_index)
        add a,a                       ; CF = current visibility bit
        jr c,.restore

        ifdef WIN320_TEST_BUILD
        ld a,(s4_test_caret_saves)
        inc a
        ld (s4_test_caret_saves),a
        endif
        ld a,(text_attr)
        and #0f
        or #f0                         ; solid text-foreground colour
        ex af,af'
.draw_row:
        ld a,c
        out (YPORT),a
        ld a,(hl)
        ld (de),a
        ex af,af'
        ld (hl),a
        ex af,af'
        inc de
        inc c
        djnz .draw_row
        jr .toggle_state

.restore:
        ifdef WIN320_TEST_BUILD
        ld a,(s4_test_caret_restores)
        inc a
        ld (s4_test_caret_restores),a
        endif
.restore_row:
        ld a,c
        out (YPORT),a
        ld a,(de)
        ld (hl),a
        inc de
        inc c
        djnz .restore_row
.toggle_state:
        ld hl,s4_draw_index
        ld a,(hl)
        xor #80
        ld (hl),a
        ret

s4_publish_edit:
        ld hl,(s4_edit_ptr)
        ld de,WIN_ED_FLAGS
        add hl,de
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        ld (hl),a
        inc hl
        inc hl                         ; maxlen is caller-owned
        ld a,(s4_edit_scratch+WIN_ED_LEN)
        ld (hl),a
        inc hl
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld (hl),a
        inc hl
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld (hl),a
        ret

; ---- Stage-2 focus integration ------------------------------------------

; Validate WinWindow.focus and the range-only last_focus field.
s4_validate_window_focus:
        ld a,(window_scratch+WIN_WND_COUNT)
        ld b,a
        or a
        jr nz,.last
        ld a,(window_scratch+WIN_WND_FOCUS)
        inc a
        jr nz,.bad
        ld a,(window_scratch+WIN_WND_LAST_FOCUS)
        inc a
        jr nz,.bad
        xor a
        ret
.last:
        ld a,(window_scratch+WIN_WND_LAST_FOCUS)
        cp #ff
        jr z,.focus
        cp b
        jr nc,.bad
.focus:
        ld a,(window_scratch+WIN_WND_FOCUS)
        cp #ff
        jr nz,.check_focus
        xor a
        ret
.check_focus:
        cp b
        jr nc,.bad
        call s2_load_item_index
        call s2_validate_item
        ret nz
        call s6_validate_choice_item
        ret nz
        call s4_item_focusable
        jr nz,.bad
        xor a
        ret
.bad:
        jp win_error_argument

; Synchronize the derived focus flag of the current built-in control.
s4_sync_item_focus:
        xor a
        ld (s4_focus_sync_valid),a
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIDDEN
        jr nz,s4_clear_hidden_focus
.visible:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        call s4_is_focus_visual
        jr z,s4_sync_builtin
        xor a
        ret

; A hidden built-in control is not rendered, but its public derived flag must
; still follow WinWindow.focus.  Validate the complete descriptor before the
; one-byte publication so a bad hidden pointer cannot become a write target.
s4_clear_hidden_focus:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_BUTTON
        jr z,.button
        cp WIN_T_CHECKBOX
        jr z,.choice
        cp WIN_T_RADIOBUTTON
        jr z,.choice
        cp WIN_T_EDIT
        jr nz,.other
        ld bc,WIN_EDIT_SIZE
        ld hl,s4_edit_scratch
        jr .copy
.button:
        ld bc,WIN_BUTTON_SIZE
        ld hl,button_scratch
        jr .copy
.choice:
        ld bc,WIN_CHOICE_SIZE
        ld hl,s4_edit_scratch
.copy:
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        call s1_copy_caller_block
        ret nz
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld de,WIN_ED_FLAGS           ; same offset as WIN_BTN_FLAGS
        add hl,de
        res 1,(hl)
.other:
        xor a
        ret
s4_sync_builtin:
        ld a,1
        ld (s4_focus_sync_valid),a
        xor a
        ld (s4_focus_sync_value),a
        ld a,(s2_current_index)
        ld c,a
        ld a,(window_scratch+WIN_WND_FOCUS)
        cp c
        jr nz,.done
        ld a,1
        ld (s4_focus_sync_value),a
.done:
        xor a
        ret

s4_apply_button_focus_scratch:
        ld hl,button_scratch+WIN_BTN_FLAGS
        jr s4_apply_focus_scratch

s4_apply_focus_scratch:
        ld a,(s4_focus_sync_valid)
        or a
        ret z
        ld b,(hl)
        xor a
        ld (s4_focus_sync_valid),a
        ld a,(s4_focus_sync_value)
        or a
        jr z,.clear
        set 1,b
        jr .store
.clear:
        res 1,b
.store:
        ld (hl),b
        ret

s4_publish_button_focus:
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld de,WIN_BTN_FLAGS
        add hl,de
        ld a,(hl)
        and #ff-WIN_BTN_FOCUS
        ld b,a
        ld a,(button_scratch+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        or b
        ld (hl),a
        ret

s4_edit_draw_item:
        call s4_prepare_edit_item
        ret nz
        ld a,(s2_item_rendered)
        add a,a
        jp c,s4_render_edit_content
        jp s4_render_loaded_edit

s4_prepare_edit_item:
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s4_edit_ptr),hl
        call s4_load_edit
        ret nz
        ld hl,s4_edit_scratch+WIN_ED_FLAGS
        call s4_apply_focus_scratch
        xor a
        ret

s4_preflight_edit_item:
        call s2_set_window_origin
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s4_edit_ptr),hl
        call s4_load_edit
        ld (s4_result),a
        call s2_restore_origin
        ld a,(s4_result)
        or a
        ret

s4_publish_last_focus:
        ld a,(window_scratch+WIN_WND_FOCUS)
        ld (window_scratch+WIN_WND_LAST_FOCUS),a
        ld hl,(s2_window_ptr)
        ld de,WIN_WND_LAST_FOCUS
        add hl,de
        ld (hl),a
        ret

; C=set if the current update item is the old or new focus and they differ.
s4_item_needs_focus_redraw:
        ld a,(window_scratch+WIN_WND_FOCUS)
        ld b,a
        ld a,(window_scratch+WIN_WND_LAST_FOCUS)
        cp b
        ret z
        ld a,(s2_current_index)
        cp b
        jr z,.yes
        ld b,a
        ld a,(window_scratch+WIN_WND_LAST_FOCUS)
        xor b                         ; mismatch must return with CF clear
        ret nz
.yes:
        ld a,(s2_current_index)
        call s2_load_item_index
        ld a,(item_scratch+WIN_ITEM_TYPE)
        call s4_is_focus_visual
        jr z,.visual
        or a
        ret
.visual:
        scf
        ret

; ---- Stage-3 focus and button-key integration ----------------------------

; Called after SCANKEY filled the raw key fields. C=set consumes the key.
s4_keyboard_focus:
        ld hl,(s3_track_scratch+WIN_TRK_WINDOW)
        ld a,h
        or l
        ret z
        ld a,(s3_track_scratch+WIN_TRK_KEY_ASCII)
        cp #09
        jr nz,.activate
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and WIN_TRK_TAB_FOCUS
        ret z
        call s4_tab_focus
        jr z,.consumed
        ld (s3_runtime_error),a
.consumed:
        scf
        ret
.activate:
        cp #0d
        jr z,.button
        call s6_choice_key
        ret nc
        cp WIN_EV_CHANGE
        jr z,.choice_changed
        or a
        jr z,.activated
        ld (s3_runtime_error),a
        jr .activated
.choice_changed:
        ld a,WIN_EV_CHANGE
        call s3_emit_index
.activated:
        scf
        ret
        ; Enter remains the button activation key.
.button:
        call s4_activate_focused_button
        ret nc
        or a
        jr z,.button_activated
        ld (s3_runtime_error),a
.button_activated:
        scf
        ret

s4_tab_focus:
        ld a,(window_scratch+WIN_WND_COUNT)
        or a
        ret z
        ld (s4_focus_limit),a
        ld a,(window_scratch+WIN_WND_FOCUS)
        ld (s4_old_focus),a
        ld a,(s3_track_scratch+WIN_TRK_KEY_MODS)
        and #c0
        jr nz,.reverse_start
        ld a,(s4_old_focus)
        cp #ff
        jr z,.forward_zero
        inc a
        ld b,a
        ld a,(s4_focus_limit)
        cp b
        ld a,b
        jr nz,.candidate
.forward_zero:
        xor a
        jr .candidate
.reverse_start:
        ld a,(s4_old_focus)
        or a
        jr z,.reverse_wrap
        cp #ff
        jr z,.reverse_wrap
        dec a
        jr .candidate
.reverse_wrap:
        ld a,(s4_focus_limit)
        dec a
.candidate:
        ld (s4_focus_candidate),a
        ld a,(s4_focus_limit)
        ld (s4_focus_left),a
.scan:
        ld a,(s4_focus_candidate)
        call s2_load_item_index
        call s4_item_focusable
        jr nz,.not_found
        call s6_tab_accept
        jr z,.found
.not_found:
        ld a,(s3_track_scratch+WIN_TRK_KEY_MODS)
        and #c0
        jr nz,.previous
        ld a,(s4_focus_candidate)
        inc a
        ld b,a
        ld a,(s4_focus_limit)
        cp b
        ld a,b
        jr nz,.next_ready
        xor a
        jr .next_ready
.previous:
        ld a,(s4_focus_candidate)
        or a
        jr z,.previous_wrap
        dec a
        jr .next_ready
.previous_wrap:
        ld a,(s4_focus_limit)
        dec a
.next_ready:
        ld (s4_focus_candidate),a
        ld hl,s4_focus_left
        dec (hl)
        jr nz,.scan
        xor a                           ; Tab consumed, no candidate/event
        ret
.found:
        ld a,(s4_focus_candidate)
        ld b,a
        ld a,(s4_old_focus)
        cp b
        jr nz,.move
        xor a                           ; sole eligible item: consume only
        ret
.move:
        ld a,b
        call s4_apply_focus
        ret nz
        ld a,(s4_focus_candidate)
        ld (s3_event_index),a
        ld a,WIN_EV_FOCUS
        call s3_emit_index
        xor a
        ld (s3_track_scratch+WIN_TRK_BUTTONS),a
        ret

; Mouse LCLICK moves focus before the click is published.
s4_focus_click:
        ld a,(s3_event_index)
        call s2_load_item_index
        call s4_item_focusable
        jr z,.eligible
        xor a
        ret
.eligible:
        ld a,(s3_event_index)
        ld b,a
        ld a,(window_scratch+WIN_WND_FOCUS)
        cp b
        jr nz,.move
        xor a
        ret
.move:
        ld a,b
        jp s4_apply_focus

; A=new focus. Redraw old/new derived indicators, then publish both fields.
s4_apply_focus:
        ld (s4_focus_candidate),a
        call s4_cursor_hide
        ret nz
        ld a,(s4_focus_candidate)
        call s4_apply_focus_hidden
        ld (s4_result),a
        call s4_cursor_show
        ld b,a
        ld a,(s4_result)
        or a
        ret nz
        ld a,b
        or a
        ret

; A=new focus, with cursor visibility already owned by the caller.
s4_apply_focus_hidden:
        ld (s4_focus_candidate),a
        ld a,(window_scratch+WIN_WND_FOCUS)
        ld (s4_old_focus),a
        ld a,(s4_focus_candidate)
        ld (window_scratch+WIN_WND_FOCUS),a
        call s2_set_window_origin
        ld a,(s4_old_focus)
        call s4_redraw_focus_index
        jr nz,.draw_failed
        ld a,(s4_focus_candidate)
        call s4_redraw_focus_index
        jr nz,.draw_failed
        call s2_restore_origin
        ld a,(s4_focus_candidate)
        ld (window_scratch+WIN_WND_LAST_FOCUS),a
        ld hl,(s2_window_ptr)
        ld de,WIN_WND_FOCUS
        add hl,de
        ld (hl),a
        inc hl
        inc hl
        inc hl
        ld (hl),a
        xor a
        ret
.draw_failed:
        ld (s4_result),a
        ; The old derived flag may already have been cleared.  Restore the
        ; logical source and redraw it while the cursor is still hidden.
        ld a,(s4_old_focus)
        ld (window_scratch+WIN_WND_FOCUS),a
        call s4_redraw_focus_index
        call s2_restore_origin
        ld a,(s4_result)
        or a
        ret

s4_redraw_focus_index:
        cp #ff
        jr nz,.draw
        xor a
        ret
.draw:
        call s2_load_item_index
        ld a,(item_scratch+WIN_ITEM_TYPE)
        call s4_is_focus_visual
        jr z,.visual
        xor a
        ret
.visual:
        ld a,#80                     ; focus-only dispatch marker
        jp s2_process_item_marked

s4_is_focus_visual:
        cp WIN_T_BUTTON
        ret z
        cp WIN_T_EDIT
        ret z
        cp WIN_T_LISTBOX
        ret z
        cp WIN_T_CHECKBOX
        ret z
        cp WIN_T_RADIOBUTTON
        ret

s4_cursor_hide:
        xor a
        ld (s4_cursor_hidden),a
        ld a,(s3_track_scratch+WIN_TRK_OPTIONS)
        and WIN_TRK_SHOW_CUR
        ret z
        ld c,2
        call win_mouse_call
        jr c,.unsupported
        ld a,1
        ld (s4_cursor_hidden),a
        xor a
        ret
.unsupported:
        jp win_reserved

s4_cursor_show:
        ld a,(s4_cursor_hidden)
        or a
        ret z
        xor a
        ld (s4_cursor_hidden),a
        ld c,1
        call win_mouse_call
        ret nc
        jp win_reserved

; C=set when Enter/Space targeted a focused button; A is status.
s4_activate_focused_button:
        ld a,(window_scratch+WIN_WND_FOCUS)
        cp #ff
        jr z,.no
        ld (s4_focus_candidate),a
        call s2_load_item_index
        call s4_item_focusable
        jr nz,.no
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_BUTTON
        jr nz,.no
        ld a,(s4_focus_candidate)
        ld b,1
        call s4_draw_button_state
        jr nz,.error
        call win_halt_call
        call win_halt_call
        call win_halt_call
        ld a,(s4_focus_candidate)
        ld b,0
        call s4_draw_button_state
        jr nz,.error
        ld a,(s4_focus_candidate)
        ld (s3_event_index),a
        ld a,WIN_EV_LCLICK
        call s3_emit_index
        xor a
        ld (s3_track_scratch+WIN_TRK_BUTTONS),a
        scf
        ret
.error:
        scf
        ret
.no:
        xor a
        ret

; Z iff the current item participates in focus, including descriptor-level
; disabled state for ABI 1.1 choices.
s4_item_focusable:
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIDDEN|WIN_IT_DISABLED|WIN_IT_FOCUSABLE
        cp WIN_IT_FOCUSABLE
        ret nz
        call s6_choice_enabled
        or a
        ret

; A=item index, B=pressed. Draw first, then publish the derived button flags.
s4_draw_button_state:
        ld (s4_focus_candidate),a
        ld a,b
        ld (s4_press_value),a
        ld a,(s4_focus_candidate)
        call s2_load_item_index
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        ld (s4_control_ptr),de
        ld bc,WIN_BUTTON_SIZE
        ld hl,button_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(button_scratch+WIN_BTN_FLAGS)
        ld b,a
        set 1,b
        ld a,(s4_press_value)
        or a
        jr z,.released
        set 2,b
        jr .flags
.released:
        res 2,b
.flags:
        ld a,b
        ld (button_scratch+WIN_BTN_FLAGS),a
        call s4_cursor_hide
        ret nz
        call s2_set_window_origin
        call s1_button_loaded
        ld (s4_result),a
        call s2_restore_origin
        ld a,(s4_result)
        or a
        jr nz,.show
        ld hl,(s4_control_ptr)
        ld de,WIN_BTN_FLAGS
        add hl,de
        ld a,(button_scratch+WIN_BTN_FLAGS)
        ld (hl),a
.show:
        call s4_cursor_show
        ld b,a
        ld a,(s4_result)
        or a
        ret nz
        ld a,b
        or a
        ret nz
        xor a
        ret

; ---- modal editing -------------------------------------------------------

s4_edit_run:
        ld hl,(s4_edit_ptr)
        ld (s4_active_edit_ptr),hl
        call s4_validate_edit_track
        jp nz,.early
        call s4_load_edit
        jp nz,.early
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld (s4_original_cursor),a
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld (s4_original_scroll),a
        ld hl,(s4_buffer_ptr)
        ld de,s4_original_buffer
        ld a,(s4_maxlen)
        inc a
        ld c,a
        ld b,0
        ldir
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        or WIN_ED_FOCUS
        ld (s4_edit_scratch+WIN_ED_FLAGS),a
        call s4_render_modal_edit
        jp nz,.late
        ld a,S4_CARET_TICKS
        ld (s4_caret_ticks),a
.loop:
        call s4_edit_next_input
        jp nz,.late
        ld a,(s4_input_kind)
        or a
        jr nz,.have_input
        call s4_tick_caret
        jp nz,.late
        jr .loop
.have_input:
        cp 2
        jp z,.mouse
        ld a,(s4_key_ascii)
        cp #0d
        jp z,.enter
        cp #1b
        jp z,.escape
        cp #09
        jp z,.tab
        cp #08
        jr z,.backspace
        ld a,(s4_key_scan)
        and #7f
        cp S4_SCAN_DELETE
        jr z,.delete
        cp S4_SCAN_LEFT
        jr z,.left
        cp S4_SCAN_RIGHT
        jr z,.right
        cp S4_SCAN_HOME
        jr z,.home
        cp S4_SCAN_END
        jr z,.end
        ld a,(s4_key_ascii)
        cp #20
        jr c,.loop
        call s4_insert_char
        jr nc,.loop
        jr .redraw
.backspace:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        or a
        jr z,.loop
        dec a
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        call s4_delete_at_cursor
        jr .redraw
.delete:
        call s4_delete_at_cursor
        jr nc,.loop
        jr .redraw
.left:
        ld a,(s4_key_mods)
        bit 5,a
        jr nz,.word_left
        ld hl,s4_edit_scratch+WIN_ED_CURSOR
        ld a,(hl)
        or a
        jr z,.loop
        dec (hl)
        jr .redraw
.right:
        ld a,(s4_key_mods)
        bit 5,a
        jr nz,.word_right
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld b,a
        ld a,(s4_len)
        cp b
        jp z,.loop
        ld hl,s4_edit_scratch+WIN_ED_CURSOR
        inc (hl)
        jr .redraw
.home:
        xor a
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        jr .redraw
.end:
        ld a,(s4_len)
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
.redraw:
        ld a,(s4_len)
        ld (s4_edit_scratch+WIN_ED_LEN),a
        call s4_update_scroll
        call s4_render_modal_content
        jp nz,.late
        ld a,S4_CARET_TICKS
        ld (s4_caret_ticks),a
        jp .loop
.word_right:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld c,a
        ld a,(s4_len)
        sub c
        jp z,.loop
        ld b,a
        ld e,c
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
.word_right_chars:
        ld a,(hl)
        call s4_is_word_separator
        jr z,.word_right_spaces
        inc hl
        inc c
        djnz .word_right_chars
        jr .word_store
.word_right_spaces:
        ld a,(hl)
        call s4_is_word_separator
        jr nz,.word_store
        inc hl
        inc c
        djnz .word_right_spaces
        jr .word_store
.word_left:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        or a
        jp z,.loop
        ld c,a
        ld b,a
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
.word_left_spaces:
        dec hl
        ld a,(hl)
        call s4_is_word_separator
        jr nz,.word_left_chars
        dec c
        djnz .word_left_spaces
        jr .word_store
.word_left_chars:
        dec c
        djnz .word_left_more
        jr .word_store
.word_left_more:
        dec hl
        ld a,(hl)
        call s4_is_word_separator
        jr z,.word_store
        dec c
        djnz .word_left_more
.word_store:
        ld a,c
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        jp .redraw
.escape:
        ld hl,s4_original_buffer
        ld de,(s4_buffer_ptr)
        ld a,(s4_maxlen)
        inc a
        ld c,a
        ld b,0
        ldir
        call s4_recount_buffer
        jr nz,.late
        ld a,(s4_len)
        ld (s4_edit_scratch+WIN_ED_LEN),a
        ld a,(s4_original_cursor)
        ld b,a
        ld a,(s4_len)
        cp b
        ld a,b
        jr nc,.esc_cursor
        ld a,(s4_len)
.esc_cursor:
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        ld a,(s4_original_scroll)
        ld (s4_edit_scratch+WIN_ED_SCROLL),a
        call s4_update_scroll
        ld e,WIN_ED_ESC
        jr .finish
.enter:
        ld e,WIN_ED_ENTER
        jr .finish
.tab:
        ld e,WIN_ED_TAB
        jr .finish
.mouse:
        ld a,(s3_track_scratch+WIN_TRK_EVENT)
        cp WIN_EV_LCLICK
        jr nz,.mouse_exit
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld de,(s4_active_edit_ptr)
        or a
        sbc hl,de
        jr nz,.mouse_exit
        ifdef WIN320_TEST_BUILD
        ld hl,s4_test_mouse_hits
        inc (hl)
        endif
        call s4_cursor_from_mouse_x
        call s4_update_scroll
        call s4_render_modal_content
        jr nz,.late
        ld a,S4_CARET_TICKS
        ld (s4_caret_ticks),a
        jp .loop
.mouse_exit:
        ld e,WIN_ED_MOUSE
.finish:
        ld a,e
        ld (s4_reason),a
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and #ff-WIN_ED_FOCUS
        ld (s4_edit_scratch+WIN_ED_FLAGS),a
        call s4_render_modal_content
        jr nz,.late
        ld a,(s4_reason)
        ld e,a
        xor a
        ret
.late:
        ld (s4_saved_error),a
        ld a,(s4_edit_scratch+WIN_ED_FLAGS)
        and #ff-WIN_ED_FOCUS
        ld (s4_edit_scratch+WIN_ED_FLAGS),a
        call s4_render_modal_content         ; best-effort focus cleanup
        call nz,s4_publish_edit              ; keep logical state consistent
        ld a,(s4_saved_error)
        ld e,0
        or a
        ret
.early:
        ld e,0
        or a
        ret

s4_validate_edit_track:
        ld hl,(s4_track_ptr)
        ld a,h
        or l
        ret z
        ex de,hl
        ld bc,WIN_TRACK_SIZE
        ld hl,s3_track_scratch
        call s1_copy_caller_block
        ret nz
        jp s3_preflight

; Select the insertion boundary at the clicked proportional glyph. Coordinates
; in WinTrack and s4_content_x are both absolute screen pixels.
s4_cursor_from_mouse_x:
        ld a,(s4_edit_scratch+WIN_ED_SCROLL)
        ld (s4_edit_scratch+WIN_ED_CURSOR),a
        ld hl,(s3_track_scratch+WIN_TRK_MOUSE_X)
        ld de,(s4_content_x)
        or a
        sbc hl,de
        ret c
.next:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld b,a
        ld a,(s4_len)
        cp b
        ret z
        ld a,b
        push hl
        call s4_char_width_at
        ld e,a
        ld d,0
        pop hl
        or a
        sbc hl,de
        ret c                           ; click inside this glyph
        push hl
        ld hl,s4_edit_scratch+WIN_ED_CURSOR
        inc (hl)
        pop hl
        jr .next

; win_edit never owns permanent mouse-cursor visibility. If its validated
; WinTrack says the application cursor is visible, hide only for VRAM writes.
s4_render_modal_edit:
        call s4_modal_pointer_hide
        ret nz
        call s4_render_loaded_edit
        jr s4_modal_render_done

s4_render_modal_content:
        call s4_modal_pointer_hide
        ret nz
        call s4_render_edit_content
s4_modal_render_done:
        ld (s4_result),a
s4_finish_cursor_write:
        call s4_cursor_show
        ld b,a
        ld a,(s4_result)
        or a
        ret nz
        ld a,b
        or a
        ret

s4_modal_pointer_hide:
        xor a
        ld (s4_cursor_hidden),a
        ld hl,(s4_track_ptr)
        ld a,h
        or l
        ret z
        ld hl,(s3_track_scratch+WIN_TRK_WINDOW)
        ld a,h
        or l
        ret z
        jp s4_cursor_hide

s4_toggle_modal_caret:
        call s4_modal_pointer_hide
        ret nz
        call s1_resolve_vram
        jr nz,.done
        call s1_map_vram
        call s4_caret_toggle_mapped
        call s1_unmap_vram
        xor a
.done:
        ld (s4_result),a
        jp s4_finish_cursor_write

s4_tick_caret:
        ld hl,s4_caret_ticks
        dec (hl)
        jr z,.toggle
        xor a
        ret
.toggle:
        ld (hl),S4_CARET_TICKS
        jp s4_toggle_modal_caret

; s4_input_kind: 0 none, 1 keyboard, 2 mouse event.
s4_edit_next_input:
        xor a
        ld (s4_input_kind),a
        ld hl,(s4_track_ptr)
        ld a,h
        or l
        jr z,.keyboard_only
        ex de,hl
        call s3_poll
        ld (s4_result),a
        ld hl,(s4_active_edit_ptr)
        ld (s4_edit_ptr),hl
        ld a,(s4_result)
        or a
        ret nz
        ; Focus repaint may use the same Stage-4 scratch globals for another
        ; edit control. Reload the active descriptor before interpreting the
        ; track result; successful edits were already published after redraw.
        call s4_load_edit
        ret nz
        ld a,(s3_track_scratch+WIN_TRK_KEY_ASCII)
        ld (s4_key_ascii),a
        ld a,(s3_track_scratch+WIN_TRK_KEY_SCAN)
        ld (s4_key_scan),a
        ld a,(s3_track_scratch+WIN_TRK_KEY_MODS)
        ld (s4_key_mods),a
        ld a,(s3_track_scratch+WIN_TRK_EVENT)
        or a
        jr z,.maybe_key
        cp WIN_EV_HOTKEY
        jr z,.maybe_key
        cp WIN_EV_KEY
        jr z,.maybe_key
        cp WIN_EV_FOCUS
        jr nz,.mouse
        ld a,(s4_key_ascii)
        cp #09
        jr z,.key
.mouse:
        ld a,2
        ld (s4_input_kind),a
        xor a
        ret
.maybe_key:
        ld a,(s4_key_ascii)
        ld b,a
        ld a,(s4_key_scan)
        or b
        jr nz,.key
        ; The modal editor has a frame-based caret even when win_track itself
        ; was configured for busy polling, so an empty iteration always yields.
        call win_halt_call
        xor a
        ret
.keyboard_only:
        ld c,#31
        call win_scankey_call
        jr z,.empty
        ld a,e
        ld (s4_key_ascii),a
        ld a,d
        ld (s4_key_scan),a
        ld a,b
        ld (s4_key_mods),a
.key:
        ld a,1
        ld (s4_input_kind),a
        xor a
        ret
.empty:
        call win_halt_call
        xor a
        ret

; FlexNavigator word boundaries: space, comma, period and backslash.
s4_is_word_separator:
        cp ' '
        ret z
        cp ','
        ret z
        cp '.'
        ret z
        cp '\'
        ret

; Insert s4_key_ascii at cursor. C=set if the buffer changed.
s4_insert_char:
        ld a,(s4_len)
        ld b,a
        ld a,(s4_maxlen)
        cp b
        ret z
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld (s4_work_cursor),a
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
        ld (s4_insert_ptr),hl
        ld a,(s4_len)
        ld b,a
        ld a,(s4_work_cursor)
        ld c,a
        ld a,b
        sub c
        ld c,a
        ld a,(text_format)
        or a
        jr nz,.count_ready
        inc c                           ; move the ASCIIZ terminator too
.count_ready:
        ld a,c
        or a
        jr z,.write
        ld b,0
        ld hl,(s4_insert_ptr)
        add hl,bc
        dec hl                          ; last source byte
        push hl
        pop de
        inc de
        lddr
.write:
        ld hl,(s4_insert_ptr)
        ld a,(s4_key_ascii)
        ld (hl),a
        ld hl,s4_len
        inc (hl)
        ld hl,s4_edit_scratch+WIN_ED_CURSOR
        inc (hl)
        call s4_store_public_length
        scf
        ret

; Delete at cursor. C=set if the buffer changed.
s4_delete_at_cursor:
        ld a,(s4_edit_scratch+WIN_ED_CURSOR)
        ld b,a
        ld a,(s4_len)
        cp b
        ret z
        jr c,.none
        ld a,b
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
        push hl
        pop de
        inc hl
        ld a,(s4_len)
        sub b
        ld c,a
        ld a,(text_format)
        or a
        jr z,.shift
        dec c
        jr z,.shift_done
.shift:
        ld b,0
        ldir
.shift_done:
        ld hl,s4_len
        dec (hl)
        call s4_store_public_length
        scf
        ret
.none:
        or a
        ret

s4_store_public_length:
        ld a,(text_format)
        or a
        jr z,.asciiz
        ld hl,(s4_buffer_ptr)
        ld a,(s4_len)
        ld (hl),a
        ret
.asciiz:
        ld a,(s4_len)
        ld e,a
        ld d,0
        ld hl,(s4_data_ptr)
        add hl,de
        xor a
        ld (hl),a
        ret

; ---- Stage-4 internal state ---------------------------------------------

; Font loading is not re-entrant with editing or tracking, so Stage 4 reuses
; the otherwise idle path_scratch area instead of growing the L0 image.
s4_edit_ptr             equ path_scratch+0
s4_active_edit_ptr      equ path_scratch+2
s4_track_ptr            equ path_scratch+4
s4_control_ptr          equ path_scratch+6
s4_buffer_ptr           equ path_scratch+8
s4_data_ptr             equ path_scratch+10
s4_insert_ptr           equ path_scratch+12
s4_content_x            equ path_scratch+14
s4_content_w            equ path_scratch+16
s4_caret_x              equ path_scratch+18
s4_text_y               equ path_scratch+20
s4_draw_x               equ path_scratch+22
s4_draw_left            equ path_scratch+24
s4_measure_width        equ path_scratch+26
s4_result               equ path_scratch+28
s4_saved_error          equ path_scratch+29
s4_reason               equ path_scratch+30
s4_maxlen               equ path_scratch+31
s4_len                  equ path_scratch+32
s4_original_cursor      equ path_scratch+33
s4_original_scroll      equ path_scratch+34
s4_measure_index        equ path_scratch+35
s4_draw_index           equ path_scratch+36
s4_draw_char            equ path_scratch+37
s4_draw_char_width      equ path_scratch+38
s4_background_color     equ path_scratch+39
s4_caret_ticks          equ path_scratch+40
s4_focus_limit          equ path_scratch+41
s4_focus_left           equ path_scratch+42
s4_focus_candidate      equ path_scratch+43
s4_old_focus            equ path_scratch+44
s4_cursor_hidden        equ path_scratch+45
s4_press_value          equ path_scratch+46
s4_focus_sync_valid     equ path_scratch+47
s4_focus_sync_value     equ path_scratch+48
s4_input_kind           equ path_scratch+49
s4_key_ascii            equ path_scratch+50
s4_key_scan             equ path_scratch+51
s4_key_mods             equ path_scratch+52
s4_work_cursor          equ s4_key_mods
s4_edit_scratch         equ path_scratch+53
s4_original_buffer      equ path_scratch+69
        ifdef WIN320_TEST_BUILD
s4_test_caret_toggles   equ path_scratch+133
s4_test_caret_saves     equ path_scratch+134
s4_test_caret_restores  equ path_scratch+135
s4_test_mouse_hits      equ path_scratch+136
s4_test_full_edit_renders equ path_scratch+137
        endif
