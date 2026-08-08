; WIN320 ABI 1.1: checkbox and radio button controls.
; Choice paths share the Stage-5 workspace; none is re-entrant with another
; renderer, font load, tracking iteration, or modal editor operation.

s6_control_ptr          equ s5_control_ptr
s6_choice_scratch       equ s5_progress_scratch
s6_type                 equ path_scratch+156
s6_publish_flags        equ path_scratch+157
s6_indicator_x          equ path_scratch+158
s6_indicator_y          equ path_scratch+160
s6_saved_index          equ path_scratch+162
s6_scan_index           equ path_scratch+163
s6_target_index         equ path_scratch+164
s6_old_checked          equ path_scratch+165
s6_group                equ path_scratch+166
s6_direction            equ path_scratch+167
s6_changed              equ path_scratch+168
s6_old_flags            equ path_scratch+169
s6_result               equ path_scratch+170
s6_old_focus            equ path_scratch+171
s6_first_enabled        equ path_scratch+172
s6_scan_left            equ path_scratch+173
s6_candidate            equ path_scratch+174

; ---- public and declarative renderers ------------------------------------

win_checkbox:
        ld a,WIN_T_CHECKBOX
        jr s6_choice_direct

win_radiobutton:
        ld a,WIN_T_RADIOBUTTON
s6_choice_direct:
        ld (s6_type),a
        ld (s6_control_ptr),de
        call s6_load_choice
        ret nz
        jp s6_render_choice

; Draw item_scratch with item-derived disabled and focus state.
s6_choice_item:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        ld (s6_type),a
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s6_control_ptr),hl
        call s6_load_choice
        ret nz
        ld hl,s6_choice_scratch+WIN_CH_FLAGS
        call s4_apply_focus_scratch
        ld a,(hl)
        ld hl,(s6_control_ptr)
        ld de,WIN_CH_FLAGS
        add hl,de
        ld (hl),a
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_DISABLED
        jp z,s6_render_choice
        set 2,(hl)
        jp s6_render_choice

; Validate the current declarative choice. Non-choice items are a no-op.
s6_validate_choice_item:
        call s6_is_choice
        jr c,.choice
        xor a
        ret
.choice:
        call s6_load_choice_for_item
        ret nz
        ld hl,(s6_choice_scratch+WIN_CH_TEXT)
        jp s1_copy_public_string

; A=0 means enabled/non-choice, A=WIN_CH_DISABLED means descriptor-disabled,
; and a WIN_ERR_*
; value reports malformed choice input. Callers that already ran preflight may
; simply treat NZ as ineligible.
s6_choice_enabled:
        call s6_is_choice
        jr c,.choice
        xor a
        ret
.choice:
        call s6_load_choice_for_item
        ret nz
.flags:
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_DISABLED
        ret

; Copy and fully validate the descriptor and caption.  Geometry becomes
; absolute only in s6_render_choice, after declarative origin is installed.
s6_load_choice:
        ld de,(s6_control_ptr)
        ld bc,WIN_CHOICE_SIZE
        ld hl,s6_choice_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and #f8
        jr nz,.unsupported
        ld a,(s6_choice_scratch+WIN_CH_RESERVED)
        or a
        jr nz,.bad
        ld a,(s6_type)
        cp WIN_T_CHECKBOX
        jr nz,.geometry
        ld a,(s6_choice_scratch+WIN_CH_GROUP)
        or a
        jr nz,.bad
.geometry:
        ld hl,(s6_choice_scratch+WIN_CH_WIDTH)
        ld a,13
        call s1_hl_minus_a
        jr c,.bad
.height:
        ld hl,(s6_choice_scratch+WIN_CH_HEIGHT)
        ld a,10
        call s1_hl_minus_a
        jr c,.bad
.ok:
        xor a
        ret
.unsupported:
        jp win_reserved
.bad:
        jp win_error_argument

s6_render_choice:
        ld hl,s6_choice_scratch
        call s1_load_control_rect
        ret nz
        ld hl,(s6_choice_scratch+WIN_CH_TEXT)
        call s1_copy_public_string
        ret nz
        ld a,(font_page)
        inc a
        jp z,win_error_font
        ld a,(s6_choice_scratch+WIN_CH_ATTR)
        ld b,WIN_TH_FACE
        ld c,WIN_TH_TEXT
        call s1_resolve_text_attr
        ld hl,(rect_x)
        ld de,13
        add hl,de
        ld (text_x),hl
        ld hl,(rect_h)
        ld de,-8
        add hl,de
        srl h
        rr l
        ld de,(rect_y)
        add hl,de
        ld (text_y),hl
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_DISABLED
        jr z,.colors_ready
        ld a,(text_attr)
        and #f0
        ld b,a
        ld a,(current_theme+WIN_TH_TEXT_DISABLED)
        or b
        ld (text_attr),a
.colors_ready:
        call s1_resolve_pair
        ret nz
        call s1_map_pair

        ; The renderer owns every pixel in the declared rectangle.
        call s1_copy_rect_to_fill
        call s1_fill_mapped

        ld hl,(rect_h)
        ld de,-10
        add hl,de
        srl h
        rr l
        ld de,(rect_y)
        add hl,de
        ld (rect_y),hl
        ld hl,10
        ld (rect_w),hl
        ld (rect_h),hl
        ld a,(current_theme+WIN_TH_FIELD_BG)
        or #f0
        ld (fill_color),a
        ld a,1
        ld (panel_sunken),a
        call s1_panel_mapped
        ld a,(s6_type)
        cp WIN_T_CHECKBOX
        jr z,.mark
        call s6_round_radio_corners
.mark:
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        call nz,s6_draw_choice_mark

        ld hl,text_scratch
        ld de,(text_x)
        ld bc,(text_y)
        ld a,(text_attr)
        call textcore_draw_mapped
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_FOCUS
        call nz,s6_draw_choice_focus
        call s1_unmap_pair
        xor a
        ret

; Keep the symmetric 10x10 circle mask and apply the rotated shadow pixels.
s6_round_radio_corners:
        ld a,(bevel_top_color)       ; SHADOW for the sunken radio bevel
        ld (fill_color),a
        ld hl,s6_radio_shadow
        ld b,4
        call s6_plot_table
        ld a,(current_theme+WIN_TH_FACE)
        or #f0
        ld (fill_color),a
        ; HL now points immediately past s6_radio_shadow.
        ld b,24
        jr s6_plot_table

; Both marks are compact pixel glyphs in the 10x10 indicator.
s6_draw_choice_mark:
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_DISABLED
        ld a,(current_theme+WIN_TH_TEXT)
        jr z,.mark_color
        ld a,(current_theme+WIN_TH_TEXT_DISABLED)
.mark_color:
        or #f0
        ld (fill_color),a
        ld a,(s6_type)
        cp WIN_T_RADIOBUTTON
        ld hl,s6_check_pixels
        ld b,10
        jr nz,s6_plot_table
        ld hl,s6_radio_dot
s6_plot12:
        ld b,12
s6_plot_table:
        ld c,(hl)
        inc hl
        push hl
        ld a,c
        and #0f
        ld e,a
        ld a,(rect_y)
        add a,e
        out (YPORT),a
        ld a,c
        and #f0
        rrca
        rrca
        rrca
        rrca
        ld e,a
        ld d,0
        ld hl,(rect_x)
        add hl,de
        call s1_make_dest
        ld a,(fill_color)
        ld (hl),a
        pop hl
        djnz s6_plot_table
        ret

s6_draw_choice_focus:
        ld hl,(s6_choice_scratch+WIN_CH_WIDTH)
        ld de,-12
        add hl,de
        ld (rect_w),hl
        ld hl,(text_x)
        dec hl
        ld (rect_x),hl
        ld a,(current_theme+WIN_TH_FOCUS_MASK)
        ld (xor_mask),a
        jp s1_focus_mapped

s6_radio_shadow:
        db #17,#12,#71,#21
s6_radio_corners:
        db #00,#10,#20,#70,#80,#90,#01,#91
        db #11,#81,#02,#92,#07,#97,#18,#88
        db #08,#98,#09,#19,#29,#79,#89,#99
s6_radio_dot:
        db #43,#53,#34,#44,#54,#64,#35,#45,#55,#65,#46,#56
s6_check_pixels:
        db #73,#64,#74,#25,#55,#65,#36,#46,#56,#47

; ---- interaction ---------------------------------------------------------

; Mouse LCLICK hook. C is set when the current event item is a choice.
; A=WIN_EV_CHANGE when state changed, zero for a selected radio, or WIN_ERR_*.
s6_choice_click:
        ld a,(s3_event_index)
        call s2_load_item_index
        call s6_is_choice
        ret nc
        call s6_load_choice_for_item
        call z,s6_activate_loaded
        scf
        ret

; Keyboard hook. Space toggles/selects the focused choice. Arrow scans select
; the previous/next enabled radio in the same group with wrap.
s6_choice_key:
        ld a,(window_scratch+WIN_WND_FOCUS)
        cp #ff
        ret z
        ld (s3_event_index),a
        call s2_load_item_index
        call s6_is_choice
        ret nc
        call s6_load_choice_for_item
        ld a,(s3_track_scratch+WIN_TRK_KEY_ASCII)
        cp #20
        jr z,.activate
        or a
        ret nz
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_RADIOBUTTON
        ret nz
        ld a,(s3_track_scratch+WIN_TRK_KEY_SCAN)
        and #7f
        sub #52
        cp 7
        ret nc
        bit 0,a
        ret nz
        and 2                         ; zero=next, two=previous
.direction:
        ld (s6_direction),a
        ld a,(s6_choice_scratch+WIN_CH_GROUP)
        ld (s6_group),a
        ld a,(window_scratch+WIN_WND_COUNT)
        ld (s6_scan_left),a
        ld a,(s3_event_index)
.next:
        ld hl,s6_direction
        bit 1,(hl)
        jr nz,.previous
        inc a
        ld hl,window_scratch+WIN_WND_COUNT
        cp (hl)
        jr c,.candidate
        xor a
        jr .candidate
.previous:
        or a
        jr nz,.decrement
        ld a,(window_scratch+WIN_WND_COUNT)
.decrement:
        dec a
.candidate:
        ld (s6_candidate),a
        call s2_load_item_index
        call s6_match_group
        jr z,.select
.skip:
        ld hl,s6_scan_left
        dec (hl)
        ld a,(s6_candidate)
        jr nz,.next
.consume_none:
        xor a
        scf
        ret
.select:
        ld a,(s6_candidate)
        ld (s3_event_index),a
.activate:
        call s6_activate_loaded
        scf
        ret

; Tab hook for a common-header-eligible candidate. Z accepts it. A radio group
; contributes only its checked enabled member, or its first enabled member.
s6_tab_accept:
        ld a,(s4_focus_candidate)
        ld (s6_candidate),a
        call s2_load_item_index
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_RADIOBUTTON
        jr z,.radio
        xor a
        ret
.radio:
        call s6_load_choice_for_item
        ret nz
        ld a,(s6_choice_scratch+WIN_CH_GROUP)
        ld (s6_group),a

.representative:
        ld a,#ff
        ld (s6_first_enabled),a
        call s2_begin_item_walk
.scan:
        call s2_load_current_item
        call s6_match_group
        jr nz,.advance
        ld a,(s6_first_enabled)
        cp #ff
        jr nz,.checked
        ld a,(s2_current_index)
        ld (s6_first_enabled),a
.checked:
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        jr z,.advance
        ld a,(s2_current_index)
        jr .compare
.advance:
        call s2_advance_item
        ld a,(s2_items_left)
        or a
        jr nz,.scan
        ld a,(s6_first_enabled)
.compare:
        ld b,a
        ld a,(s6_candidate)
        cp b
        ret z
.reject:
        or #ff
        ret

; C=set if item_scratch is checkbox/radio.
s6_is_choice:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        sub WIN_T_CHECKBOX
        cp 2
        ret

s6_load_choice_for_item:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        ld (s6_type),a
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s6_control_ptr),hl
        jp s6_load_choice

s6_match_group:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_RADIOBUTTON
        ret nz
        call s4_item_focusable
        ret nz
        ld a,(s6_group)
        ld hl,s6_choice_scratch+WIN_CH_GROUP
        cp (hl)
        ret

; item_scratch and s6_choice_scratch identify s3_event_index. The cursor is
; hidden once while focus, state and all affected images are changed.
s6_activate_loaded:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        ld (s6_type),a
        xor a
        ld (s6_changed),a
        ld a,(s6_type)
        cp WIN_T_CHECKBOX
        jr z,.will_change
        ld a,(s6_choice_scratch+WIN_CH_FLAGS)
        and WIN_CH_CHECKED
        jr nz,.hide
        ld a,(s6_choice_scratch+WIN_CH_GROUP)
        ld (s6_group),a
.will_change:
        ld hl,s6_changed
        inc (hl)
.hide:
        call s4_cursor_hide
        ret nz

        ld a,(s6_changed)
        or a
        jr z,.focus
        ld a,(s6_type)
        cp WIN_T_CHECKBOX
        jr nz,.clear_group
        ld hl,(s6_control_ptr)
        ld de,WIN_CH_FLAGS
        add hl,de
        ld a,(hl)
        xor WIN_CH_CHECKED
        ld (hl),a
        call s6_mark_item_dirty
        jr .focus

.clear_group:
        call s2_begin_item_walk
.clear_loop:
        call s2_load_current_item
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_RADIOBUTTON
        jr nz,.clear_next
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld de,WIN_CH_GROUP
        add hl,de
        ld a,(hl)
        ld b,a
        ld a,(s6_group)
        cp b
        jr nz,.clear_next
        dec hl
        bit 0,(hl)
        jr z,.clear_next
        res 0,(hl)
        call s6_mark_item_dirty
.clear_next:
        call s2_advance_item
        ld a,(s2_items_left)
        or a
        jr nz,.clear_loop
        ld a,(s3_event_index)
        call s2_load_item_index
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld de,WIN_CH_FLAGS
        add hl,de
        set 0,(hl)
        call s6_mark_item_dirty

.focus:
        ld a,(s3_event_index)
        ld (window_scratch+WIN_WND_FOCUS),a
        ld hl,(s2_window_ptr)
        ld de,WIN_WND_FOCUS
        add hl,de
        ld (hl),a
        ld de,(s2_window_ptr)
        call s2_win_update
        push af
.show:
        call s4_cursor_show
        ld b,a
        pop af
        or b
        ret nz
        ld a,(s6_changed)
        or a
        ret z
        ld a,WIN_EV_CHANGE
        ret

; item_scratch belongs to the item currently loaded by s2_load_item_index.
s6_mark_item_dirty:
        ld hl,(s2_item_ptr)
        inc hl
        set 0,(hl)
        ret
