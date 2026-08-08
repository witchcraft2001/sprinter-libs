; WIN320 stage 2: declarative windows, dirty updates and modal backstore.
; Public descriptors are never accessed while an application window is
; remapped. A backstore row is kept inside one EMM page and one DI section.

S2_STACK_X             equ 0
S2_STACK_Y             equ 2
S2_STACK_WIDTH         equ 4
S2_STACK_HEIGHT        equ 6
S2_STACK_SCREEN        equ 8
S2_STACK_ALLOC_PAGE    equ 9
S2_STACK_ALLOC_OFFSET  equ 10
S2_STACK_PREV_X        equ 12
S2_STACK_PREV_Y        equ 14
S2_STACK_RESERVED      equ 15
S2_STACK_SIZE          equ 16

; ---- public declarative drawing entry points -------------------------------

win_draw:
        push bc
        push hl
        push ix
        push iy
        call s2_win_draw
        pop iy
        pop ix
        pop hl
        pop bc
        ret

s2_win_draw:
        call s2_load_window
        ret nz
s2_draw_loaded_window:
        call s2_draw_window_body
        ret nz
        call s2_set_window_origin
        call s7_draw_title
        jr nz,.failed
        call s2_begin_item_walk
.loop:
        ld a,(s2_items_left)
        or a
        jr z,.done
        call s2_load_current_item
        call s2_process_item
        jr nz,.failed
        call s2_clear_item_dirty
        call s2_advance_item
        jr .loop
.done:
        call s2_restore_origin
        call s4_publish_last_focus
        xor a
        ret
.failed:
        jp s2_restore_origin_keep_a

win_draw_item:
        push bc
        push hl
        push iy
        call s2_win_draw_item
        pop iy
        pop hl
        pop bc
        ret

s2_win_draw_item:
        push ix
        call s2_load_window
        pop ix
        or a
        ret nz
        ld a,ixh
        or a
        jr nz,.bad
        ld a,ixl
        ld b,a
        ld a,(window_scratch+WIN_WND_COUNT)
        cp b
        jr c,.bad
        jr z,.bad
        call s2_set_window_origin
        ld a,b
        call s2_load_item_index
        or a
        jr nz,.failed
        call s2_process_item
        jr nz,.failed
        call s2_clear_item_dirty
        call s2_restore_origin
        xor a
        ret
.failed:
        jp s2_restore_origin_keep_a
.bad:
        jp win_error_argument

win_update:
        push bc
        push hl
        push ix
        push iy
        call s2_win_update
        pop iy
        pop ix
        pop hl
        pop bc
        ret

s2_win_update:
        call s2_load_window
        jr z,.loaded
        ld e,0                       ; no item was redrawn on header failure
        ret
.loaded:
        call s2_set_window_origin
        xor a
        ld (s2_update_count),a
        call s2_begin_item_walk
.loop:
        ld a,(s2_items_left)
        or a
        jr z,.done
        ; The complete item range was validated with WinWindow. Avoid an
        ; 8-byte copy for the overwhelmingly common clean-item case.
        ld hl,(s2_item_ptr)
        inc hl
        bit 0,(hl)
        jr nz,.dirty
        call s4_item_needs_focus_redraw
        jr nc,.next
        ld a,#80                     ; focus-only dispatch marker
        jr .redraw
.dirty:
        xor a
.redraw:
        call s2_load_current_item
        call s2_process_item_marked
        jr nz,.failed
        call s2_clear_item_dirty
        ld a,(s2_item_rendered)
        and 1
        jr z,.next
        ld hl,s2_update_count
        inc (hl)
.next:
        call s2_advance_item
        jr .loop
.done:
        call s2_restore_origin
        call s4_publish_last_focus
        ld a,(s2_update_count)
        ld e,a
        xor a
        ret
.failed:
        call s2_restore_origin_keep_a
        ld hl,s2_update_count
        ld e,(hl)
        ret

; Copy and validate WinWindow, including its complete WinItem array range.
s2_load_window:
        ld (s2_window_ptr),de
        ld bc,WIN_WINDOW_SIZE
        ld hl,window_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(window_scratch+WIN_WND_FLAGS)
        and #f8
        jr nz,.unsupported
        ld hl,(window_scratch+WIN_WND_RESERVED)
        ld a,h
        or l
        jr nz,.bad
        call s7_validate_title
        jr nz,.bad
        ; WinWindow and WinRect share the first eight bytes. Reuse the exact
        ; non-wrapping screen validator with a temporary zero origin.
        ld hl,(origin_x)
        ld (s2_saved_origin_x),hl
        ld a,(origin_y)
        ld (s2_saved_origin_y),a
        xor a
        ld (origin_x),a
        ld (origin_x+1),a
        ld (origin_y),a
        ld hl,window_scratch
        call s1_load_control_rect
        call s2_restore_origin_keep_a
        jr nz,.bad
        ld a,(rect_empty)
        or a
        jr nz,.bad

        ld a,(window_scratch+WIN_WND_COUNT)
        or a
        jr z,.no_items
        ld hl,(window_scratch+WIN_WND_ITEMS)
        ld a,h
        or l
        jr z,.bad
        ld a,(window_scratch+WIN_WND_COUNT)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        ld hl,(window_scratch+WIN_WND_ITEMS)
        call s1_validate_caller_range
        jr c,.bad
.no_items:
        jp s4_validate_window_focus
.unsupported:
        jp win_reserved
.bad:
        jp win_error_argument

; A=index. The full array range was checked by s2_load_window.
s2_load_item_index:
        ld (s2_current_index),a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(window_scratch+WIN_WND_ITEMS)
        add hl,de
        ld (s2_item_ptr),hl
        jr s2_load_current_item

; Sequential aggregate paths walk the already validated array directly.
s2_begin_item_walk:
        ld hl,(window_scratch+WIN_WND_ITEMS)
        ld (s2_item_ptr),hl
        ld a,(window_scratch+WIN_WND_COUNT)
        ld (s2_items_left),a
        xor a
        ld (s2_current_index),a
        ret

s2_load_current_item:
        ld hl,(s2_item_ptr)
        ld de,item_scratch
        ld bc,WIN_ITEM_SIZE
        ldir
        ret

s2_advance_item:
        ld hl,(s2_item_ptr)
        ld de,WIN_ITEM_SIZE
        add hl,de
        ld (s2_item_ptr),hl
        ld hl,s2_items_left
        dec (hl)
        ld hl,s2_current_index
        inc (hl)
        ret

s2_validate_item:
        ld a,(item_scratch+WIN_ITEM_RESERVED)
        or a
        jr nz,.bad
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_RADIOBUTTON+1
        jr nc,.unsupported
.type_supported:
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_PRESS|WIN_IT_REPEAT|WIN_IT_HOVER
        jr z,.id
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT
        jr z,.bad
.id:
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT|WIN_IT_HOVER|WIN_IT_FOCUSABLE
        jr z,.type
        ld a,(item_scratch+WIN_ITEM_ID)
        inc a
        jr z,.bad
.type:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        or a
        jr nz,.control
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld a,h
        or l
        jr nz,.bad
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_DISABLED|WIN_IT_HIT|WIN_IT_FOCUSABLE|WIN_IT_PRESS|WIN_IT_REPEAT|WIN_IT_HOVER
        jr nz,.bad
        xor a
        ret
.control:
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld a,h
        or l
        jr z,.bad
        xor a
        ret
.unsupported:
        jp win_reserved
.bad:
        jp win_error_argument

; Validate then draw item_scratch. s2_item_rendered is true only when a
; visual control was actually dispatched.
s2_process_item:
        xor a
s2_process_item_marked:
        ld (s2_item_rendered),a
        call s2_validate_item
        ret nz
        call s4_sync_item_focus
        ret nz
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIDDEN
        jr z,.visible
        xor a
        ret
.visible:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        or a
        ret z
        cp WIN_T_ZONE
        jr z,s2_process_zone
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT
        jr z,.dispatch
        ; Label and button already load their full descriptor and require
        ; non-empty on-screen geometry. Do not copy their common header twice.
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_LABEL
        jr z,.dispatch
        cp WIN_T_BUTTON
        jr z,.dispatch
        call s2_validate_hit_geometry
        ret nz
.dispatch:
        ld hl,s2_item_rendered
        set 0,(hl)
        ld a,(item_scratch+WIN_ITEM_TYPE)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,s2_type_dispatch
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ex de,hl
        jp (hl)

; The only remaining Stage-2 visual type is WIN_T_BUTTON.
s2_dispatch_button:
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        call s1_copy_button_block
        ret nz
        call s4_apply_button_focus_scratch
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_DISABLED
        jr z,.button
        ld a,(button_scratch+WIN_BTN_FLAGS)
        or WIN_BTN_DISABLED
        ld (button_scratch+WIN_BTN_FLAGS),a
.button:
        call s1_button_loaded
        ret nz
        call s4_publish_button_focus
        xor a
        ret

; Indexed by WIN_T_* - 1 (WIN_T_ZONE is intercepted earlier and never
; reaches this table).
s2_type_dispatch:
        dw s2_process_label      ; WIN_T_LABEL
        dw win_fill_rect         ; WIN_T_FILL
        dw win_frame             ; WIN_T_FRAME
        dw win_panel             ; WIN_T_PANEL
        dw win_separator         ; WIN_T_SEPARATOR
        dw s2_dispatch_button    ; WIN_T_BUTTON
        dw win_icon              ; WIN_T_ICON
        dw win_progress_draw     ; WIN_T_PROGRESS
        dw win_scrollbar_draw    ; WIN_T_SCROLLBAR
        dw win_listbox_draw      ; WIN_T_LISTBOX
        dw s4_edit_draw_item     ; WIN_T_EDIT
        dw win_reserved          ; WIN_T_ZONE (unreachable placeholder)
        dw s6_choice_item        ; WIN_T_CHECKBOX
        dw s6_choice_item        ; WIN_T_RADIOBUTTON

s2_process_label:
        call s1_copy_label_block
        ret nz
        call s2_require_label_geometry
        ret nz
        jp s1_label_loaded

s2_process_zone:
        call s2_check_control_geometry
        ret nz
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT
        jr nz,s2_require_nonempty_geometry
        xor a
        ret

s2_validate_hit_geometry:
        call s2_check_control_geometry
        ret nz
s2_require_nonempty_geometry:
        ld hl,(control_geometry+4)
        ld a,h
        or l
        jr z,.bad
        ld hl,(control_geometry+6)
        ld a,h
        or l
        jr z,.bad
        xor a
        ret
.bad:
        jp win_error_argument

s2_clear_item_dirty:
        ld hl,(s2_item_ptr)
        inc hl
        res 0,(hl)
        ret

s2_set_window_origin:
        ld hl,(origin_x)
        ld (s2_saved_origin_x),hl
        ld a,(origin_y)
        ld (s2_saved_origin_y),a
        ld hl,(window_scratch+WIN_WND_X)
        ld (origin_x),hl
        ld a,(window_scratch+WIN_WND_Y)
        ld (origin_y),a
        ret

s2_restore_origin:
        ld hl,(s2_saved_origin_x)
        ld (origin_x),hl
        ld a,(s2_saved_origin_y)
        ld (origin_y),a
        ret

; A=status to preserve across s2_restore_origin. Returns A/flags unchanged.
s2_restore_origin_keep_a:
        ld (s2_error),a
        call s2_restore_origin
        ld a,(s2_error)
        or a
        ret

s2_draw_window_body:
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_NOPANEL
        jr z,.draw
        xor a
        ret
.draw:
        ld hl,window_scratch
        ld de,rect_x
        ld bc,8
        ldir
        call s1_require_frame_size
        ret nz
        ld a,(window_scratch+WIN_WND_COLOR)
        call s1_resolve_fill_color
        jr c,.bad
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_SUNKEN
        ld (panel_sunken),a
        ld hl,s1_panel_mapped
        jp s1_draw_mapped_hl
.bad:
        or a
        ret

; ---- public backstore and modal entry points -------------------------------

win_set_backstore:
        push bc
        push hl
        push iy
        call s2_win_set_backstore
        pop iy
        pop hl
        pop bc
        ret

s2_win_set_backstore:
        ld a,(backstore_depth)
        or a
        jp nz,.busy
        ld a,ixh
        or a
        jp nz,.bad
        ld a,ixl
        or a
        jr z,.bad
        cp WIN_BACKSTORE_MAX_PAGES+1
        jr nc,.bad
        ld (s2_page_count),a
        ld c,a
        ld b,0
        ex de,hl
        push hl
        call s1_validate_caller_range
        pop hl
        jr c,.bad
        ld de,s2_page_scratch
        xor a
        ld (s2_page_scratch+0),a
        ld (s2_page_scratch+1),a
        ld (s2_page_scratch+2),a
        ld (s2_page_scratch+3),a
        ld a,(s2_page_count)
        ld c,a
        ld b,0
        ldir
        xor a
        ld (s2_page_index),a
.validate:
        ld a,(s2_page_index)
        ld e,a
        ld d,0
        ld hl,s2_page_scratch
        add hl,de
        ld a,(hl)
        ld b,a
        ld a,(font_page)
        cp b
        jr z,.bad
        ld a,(s2_page_index)
        or a
        jr z,.next
        ld c,a
        ld hl,s2_page_scratch
.duplicate:
        ld a,(hl)
        cp b
        jr z,.bad
        inc hl
        dec c
        jr nz,.duplicate
.next:
        ld hl,s2_page_index
        inc (hl)
        ld a,(hl)
        ld b,a
        ld a,(s2_page_count)
        cp b
        jr nz,.validate
        ld hl,s2_page_scratch
        ld de,backstore_page_list
        ld bc,WIN_BACKSTORE_MAX_PAGES
        ldir
        ld a,(s2_page_count)
        ld (backstore_pages),a
        xor a
        ld (backstore_alloc_page),a
        ld (backstore_alloc_offset),a
        ld (backstore_alloc_offset+1),a
        ret
.busy:
        ld a,WIN_ERR_BUSY
        or a
        ret
.bad:
        jp win_error_argument

win_open:
        push bc
        push hl
        push ix
        push iy
        call s2_win_open
        pop iy
        pop ix
        pop hl
        pop bc
        ret

s2_win_open:
        call s2_load_window
        ret nz
        call s2_preflight_window_body
        ret nz
        call s2_set_window_origin
        call s2_preflight_items
        jr nz,.preflight_done
        call s7_preflight_title
.preflight_done:
        call s2_restore_origin_keep_a
        ret nz
        ld a,(backstore_pages)
        or a
        jr z,.backstore
        ld a,(backstore_depth)
        cp WIN_BACKSTORE_MAX_DEPTH
        jr nc,.depth
        call s2_allocator_preflight
        ret nz
        ; Window choice is also preflight: no screen or stack state changed.
        call s1_resolve_pair
        ret nz
        call s2_push_stack_record
        xor a
        ld (s2_copy_restore),a
        call s2_copy_stack_rect
        ld hl,(s2_alloc_final_offset)
        ld (backstore_alloc_offset),hl
        ld a,(s2_alloc_final_page)
        ld (backstore_alloc_page),a
        ld hl,backstore_depth
        inc (hl)
        ld hl,(window_scratch+WIN_WND_X)
        ld (origin_x),hl
        ld a,(window_scratch+WIN_WND_Y)
        ld (origin_y),a
        call s2_draw_loaded_window
        ret z
        ld (s2_open_error),a
        call s2_close_top
        ld a,(s2_open_error)
        or a
        ret
.backstore:
        ld a,WIN_ERR_BACKSTORE
        or a
        ret
.depth:
        ld a,WIN_ERR_DEPTH
        or a
        ret

win_close:
        push bc
        push de
        push hl
        push ix
        push iy
        call s2_win_close
        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        ret

s2_win_close:
        ld a,(backstore_depth)
        or a
        jr z,.depth
        jr s2_close_top
.depth:
        ld a,WIN_ERR_DEPTH
        or a
        ret

s2_close_top:
        call s1_resolve_pair
        ret nz
        ld a,(backstore_depth)
        dec a
        call s2_stack_pointer
        ld (s2_stack_ptr),hl
        ld a,1
        ld (s2_copy_restore),a
        call s2_copy_stack_rect
        ; ALLOC_PAGE..PREV_Y are contiguous (9..14): walk them in one pass.
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_ALLOC_PAGE
        add hl,de
        ld a,(hl)
        ld (backstore_alloc_page),a
        inc hl
        ld a,(hl)
        ld (backstore_alloc_offset),a
        inc hl
        ld a,(hl)
        ld (backstore_alloc_offset+1),a
        inc hl
        ld a,(hl)
        ld (origin_x),a
        inc hl
        ld a,(hl)
        ld (origin_x+1),a
        inc hl
        ld a,(hl)
        ld (origin_y),a
        ld hl,backstore_depth
        dec (hl)
        xor a
        ret

s2_close_all:
        ; fini must close windows even if the application changed a fixed
        ; work-window selection so that it now conflicts with SP.
        ld a,(data_window)
        ld (s2_cleanup_data_window),a
        ld a,(vram_window)
        ld (s2_cleanup_vram_window),a
        ld a,WIN_WORK_AUTO
        ld (data_window),a
        ld (vram_window),a
.loop:
        ld a,(backstore_depth)
        or a
        jr z,.restore
        call s2_close_top
        jr z,.loop
        ; AUTO always has two candidates on a four-window machine, but keep
        ; fini bounded if corrupted state makes close fail.
.restore:
        ld a,(s2_cleanup_data_window)
        ld (data_window),a
        ld a,(s2_cleanup_vram_window)
        ld (vram_window),a
        ret

; ---- modal preflight -------------------------------------------------------

s2_preflight_window_body:
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_NOPANEL
        jr nz,.ok
        ld hl,(window_scratch+WIN_WND_WIDTH)
        call s1_hl_minus_2
        jr c,.bad
        ld hl,(window_scratch+WIN_WND_HEIGHT)
        call s1_hl_minus_2
        jr c,.bad
.ok:
        xor a
        ret
.bad:
        jp win_error_argument

s2_preflight_items:
        call s2_begin_item_walk
.loop:
        ld a,(s2_items_left)
        or a
        jr z,.ok
        call s2_load_current_item
        call s2_validate_item
        ret nz
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIDDEN
        jr nz,.next
        ld a,(item_scratch+WIN_ITEM_TYPE)
        or a
        jr z,.next
        call s2_check_control_geometry
        ret nz
        ld a,(item_scratch+WIN_ITEM_FLAGS)
        and WIN_IT_HIT
        jr z,.containment
        ld hl,(control_geometry+4)
        ld a,h
        or l
        jr z,.bad
        ld hl,(control_geometry+6)
        ld a,h
        or l
        jr z,.bad
.containment:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_ZONE
        jr z,.next
        call s2_validate_geometry_window
        ret nz
        call s2_preflight_type_geometry
        ret nz
.next:
        call s2_advance_item
        jr .loop
.ok:
        xor a
        ret
.bad:
        jp win_error_argument

; Geometry rules that the individual Stage-1 renderers would otherwise
; discover only after the background had already been saved.
s2_preflight_type_geometry:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_LABEL
        jr z,.label
        cp WIN_T_FRAME
        jr z,.frame
        cp WIN_T_PANEL
        jr z,.frame
        cp WIN_T_SEPARATOR
        jr z,.separator
        cp WIN_T_BUTTON
        jr z,.button
        cp WIN_T_EDIT
        jp z,s4_preflight_edit_item
        cp WIN_T_CHECKBOX
        jp z,s6_validate_choice_item
        cp WIN_T_RADIOBUTTON
        jp z,s6_validate_choice_item
        xor a
        ret
.label:
        jp s2_preflight_label
.frame:
        ld hl,(control_geometry+4)
        ld a,h
        or l
        jr z,.ok
        ld hl,(control_geometry+6)
        ld a,h
        or l
        jr z,.ok
        ld hl,(control_geometry+4)
        call s1_hl_minus_2
        jr c,.bad
        ld hl,(control_geometry+6)
        call s1_hl_minus_2
        jr c,.bad
        jr .ok
.separator:
        ld hl,(control_geometry+4)
        ld a,h
        or l
        jr z,.ok
        ld hl,(control_geometry+6)
        ld a,h
        or l
        jr z,.ok
        ld a,(control_geometry+WIN_RC_FLAGS)
        and WIN_RC_VERTICAL
        jr nz,.separator_vertical
        ld hl,(control_geometry+6)
        call s1_hl_minus_2
        jr nz,.bad
        jr .ok
.separator_vertical:
        ld hl,(control_geometry+4)
        call s1_hl_minus_2
        jr nz,.bad
        jr .ok
.button:
        ld hl,(control_geometry+4)
        call s1_hl_minus_2
        jr c,.bad
        ld hl,(control_geometry+6)
        ld a,10
        call s1_hl_minus_a
        jr c,.bad
        ld a,(control_geometry+WIN_BTN_FLAGS)
        and WIN_BTN_FOCUS
        jr z,.ok
        ld hl,(control_geometry+4)
        ld a,6
        call s1_hl_minus_a
        jr c,.bad
.ok:
        xor a
        ret
.bad:
        jp win_error_argument

; A modal label is prepared exactly as it will be rendered. This proves that
; its text pixels, not merely the declared fill rectangle, fit the saved
; window rectangle before the first backstore byte is touched.
s2_preflight_label:
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        call s1_copy_label_block
        ret nz
        call s2_require_label_geometry
        ret nz
        call s1_label_prepare_loaded
        ret nz

        ld hl,(text_pixel_width)
        ld a,h
        or l
        ret z                       ; empty text only has the contained fill
        ld de,(text_x)
        add hl,de
        jr c,.bad
        ex de,hl                    ; DE = text right edge
        ld hl,(window_scratch+WIN_WND_X)
        ld bc,(window_scratch+WIN_WND_WIDTH)
        add hl,bc
        or a
        sbc hl,de
        jr c,.bad

        ld hl,(text_y)
        ld de,8
        add hl,de
        jr c,.bad
        ex de,hl                    ; DE = text bottom edge
        ld hl,(window_scratch+WIN_WND_Y)
        ld bc,(window_scratch+WIN_WND_HEIGHT)
        add hl,bc
        or a
        sbc hl,de
        jr c,.bad
        xor a
        ret
.bad:
        jp win_error_argument

s2_require_label_geometry:
        ld hl,(label_scratch+WIN_LBL_WIDTH)
        ld a,h
        or l
        jr z,.bad
        ld hl,(label_scratch+WIN_LBL_HEIGHT)
        ld a,h
        or l
        jr z,.bad
        xor a
        ret
.bad:
        jp win_error_argument

s2_load_control_geometry:
        ld de,(item_scratch+WIN_ITEM_CONTROL)
        ld bc,WIN_RECT_SIZE
        ld hl,control_geometry
        jp s1_copy_caller_block

; Geometry uses relative control x/y. Zero width/height are allowed here;
; descriptor-specific renderers decide whether that is meaningful.
s2_validate_geometry_screen:
        ld hl,control_geometry
        jp s1_normalize_rect_from_hl

; Load then screen-validate the current item's control geometry.
s2_check_control_geometry:
        call s2_load_control_geometry
        ret nz
        jp s2_validate_geometry_screen

s2_validate_geometry_window:
        ld hl,(control_geometry+0)
        ld de,(control_geometry+4)
        ld bc,(window_scratch+WIN_WND_WIDTH)
        call s1_validate_axis_window
        jr c,.bad
        ld hl,(control_geometry+2)
        ld de,(control_geometry+6)
        ld bc,(window_scratch+WIN_WND_HEIGHT)
        call s1_validate_axis_window
        jr c,.bad
        xor a
        ret
.bad:
        jp win_error_argument

; HL=start, DE=size, BC=exclusive container limit. C=set on overflow/outside.
s1_validate_axis_window:
        or a
        sbc hl,bc
        jr nc,.bad
        add hl,bc
        add hl,de
        jr c,.bad
        or a
        sbc hl,bc
        jr c,.ok
        jr z,.ok
.bad:
        scf
        ret
.ok:
        or a
        ret

s2_allocator_preflight:
        ld a,(backstore_alloc_page)
        ld (s2_alloc_final_page),a
        ld hl,(backstore_alloc_offset)
        ld (s2_alloc_final_offset),hl
        ld hl,(window_scratch+WIN_WND_HEIGHT)
        ld (s2_rows_left),hl
.row:
        ld a,(s2_alloc_final_page)
        ld b,a
        ld a,(backstore_pages)
        cp b
        jr c,.bad
        jr z,.bad
        ld hl,(s2_alloc_final_offset)
        ld de,(window_scratch+WIN_WND_WIDTH)
        add hl,de
        ld a,h
        cp #40
        jr c,.store
        jr nz,.new_page
        ld a,l
        or a
        jr z,.store
.new_page:
        ld a,(s2_alloc_final_page)
        inc a
        ld (s2_alloc_final_page),a
        ld hl,(window_scratch+WIN_WND_WIDTH)
.store:
        ld (s2_alloc_final_offset),hl
        ld a,(s2_alloc_final_page)
        ld b,a
        ld a,(backstore_pages)
        cp b
        jr c,.bad
        jr z,.bad
        ld hl,(s2_rows_left)
        dec hl
        ld (s2_rows_left),hl
        ld a,h
        or l
        jr nz,.row
        xor a
        ret
.bad:
        ld a,WIN_ERR_BACKSTORE
        or a
        ret

s2_push_stack_record:
        ld a,(backstore_depth)
        call s2_stack_pointer
        ld (s2_stack_ptr),hl
        ex de,hl
        ld hl,window_scratch
        ld bc,8
        ldir
        ld a,(screen_id)
        ld (de),a
        inc de
        ld a,(backstore_alloc_page)
        ld (de),a
        inc de
        ld hl,(backstore_alloc_offset)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld hl,(origin_x)
        ld a,l
        ld (de),a
        inc de
        ld a,h
        ld (de),a
        inc de
        ld a,(origin_y)
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret

; A=stack index 0..3 -> HL.
s2_stack_pointer:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,window_stack
        add hl,de
        ret

; ---- one-map-per-row backstore transfer -----------------------------------

; s2_stack_ptr and s2_copy_restore select the rectangle and direction.
s2_copy_stack_rect:
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_ALLOC_PAGE
        add hl,de
        ld a,(hl)
        ld (s2_row_page),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s2_row_offset),hl
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_X
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s2_copy_x),hl
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_Y
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s2_copy_y),hl
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_WIDTH
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s2_copy_width),hl
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_HEIGHT
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s2_rows_left),hl
        ld hl,(s2_stack_ptr)
        ld de,S2_STACK_SCREEN
        add hl,de
        ld a,(hl)
        ld (s2_copy_screen),a
.row:
        call s2_advance_row_page
        call s2_prepare_row_addresses
        call s2_map_backstore_row
        call s2_copy_row_mapped
        call s2_unmap_backstore_row
        ld hl,(s2_row_offset)
        ld de,(s2_copy_width)
        add hl,de
        ld (s2_row_offset),hl
        ld hl,(s2_copy_y)
        inc hl
        ld (s2_copy_y),hl
        ld hl,(s2_rows_left)
        dec hl
        ld (s2_rows_left),hl
        ld a,h
        or l
        jr nz,.row
        ret

s2_advance_row_page:
        ld hl,(s2_row_offset)
        ld de,(s2_copy_width)
        add hl,de
        ld a,h
        cp #40
        ret c
        jr nz,.next
        ld a,l
        or a
        ret z
.next:
        ld hl,0
        ld (s2_row_offset),hl
        ld hl,s2_row_page
        inc (hl)
        ret

s2_prepare_row_addresses:
        ifdef WIN320_TEST_BUILD
        ; Test-only stand-in for the backstore's data-window base. Kept well
        ; above win320.asm's own compiled size plus every t_stageN.asm test's
        ; appended code/data in the flat noslot64k image, so a multi-row
        ; backstore copy never overwrites test code (see t_stage0.asm's
        ; auto_stack_values for the same class of collision).
        ld hl,#e000
        else
        ld hl,(resolved_data_base)
        endif
        ld de,(s2_row_offset)
        add hl,de
        ld (s2_data_address),hl
        ld hl,(resolved_vram_base)
        ld a,(s2_copy_screen)
        or a
        jr z,.screen
        ld de,SCREEN_STRIDE
        add hl,de
.screen:
        ld de,(s2_copy_x)
        add hl,de
        ld (s2_vram_address),hl
        ret

s2_map_backstore_row:
        ifdef WIN320_TEST_BUILD
        ld hl,s2_test_map_count
        inc (hl)
        endif
        call s1_save_pair_pages
        ld a,(s2_row_page)
        ld e,a
        ld d,0
        ld hl,backstore_page_list
        add hl,de
        ld a,(hl)
        ld b,a
        ld a,(resolved_data_port)
        ld c,a
        ld a,b
        call s1_write_page_c
        ld a,(resolved_vram_port)
        ld c,a
        ld a,VIDEO_PAGE
        jp s1_write_page_c

s2_unmap_backstore_row:
        call s1_unmap_vram_core
        ld a,(resolved_data_port)
        ld c,a
        ld a,(saved_data_page)
        call s1_write_page_c
        ifdef WIN320_TEST_BUILD
        ld hl,s2_test_unmap_count
        inc (hl)
        endif
        jp s1_restore_iff

s2_copy_row_mapped:
        ld hl,(s2_vram_address)
        ld de,(s2_data_address)
        ld a,(s2_copy_restore)
        or a
        jr z,.addresses
        ex de,hl
.addresses:
        ld a,(s2_copy_y)
        out (YPORT),a
        ld a,(s2_copy_width+1)
        or a
        jr z,.short
        xor a                       ; first 256-byte command
        call s2_copy_chunk
        ld bc,256
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld a,(s2_copy_width)
        or a
        ret z
        jr s2_copy_chunk
.short:
        ld a,(s2_copy_width)

; HL=source, DE=destination, A=count (0 means WIN_BACKSTORE_CHUNK=256).
s2_copy_chunk:
        ifdef WIN320_TEST_BUILD
        push hl
        ld hl,s2_test_command_count
        inc (hl)
        pop hl
        push bc
        push de
        push hl
        or a
        jr nz,.test_short
        ld bc,WIN_BACKSTORE_CHUNK
        jr .test_copy
.test_short:
        ld c,a
        ld b,0
.test_copy:
        ldir
        pop hl
        pop de
        pop bc
        ret
        else
        ld (s2_copy_size+1),a
        ld d,d
s2_copy_size:
        ld a,0
        ld l,l
        ld a,(hl)
        ld (de),a
        ld b,b
        ret
        endif

; ---- stage-2 internal state ------------------------------------------------

s2_item_ptr:            dw 0
s2_window_ptr:          dw 0
s2_stack_ptr:           dw 0
s2_saved_origin_x:      dw 0
s2_saved_origin_y:      db 0
s2_items_left:          db 0
s2_current_index:       db 0
s2_item_rendered:       db 0
s2_update_count:        db 0
s2_error:               db 0
s2_open_error:          db 0

s2_page_count:          db 0
s2_page_index:          db 0
s2_cleanup_data_window: db WIN_WORK_AUTO
s2_cleanup_vram_window: db WIN_WORK_AUTO
s2_page_scratch:        ds WIN_BACKSTORE_MAX_PAGES,0
backstore_page_list:    ds WIN_BACKSTORE_MAX_PAGES,0
backstore_alloc_page:   db 0
backstore_alloc_offset: dw 0

s2_alloc_final_page:    db 0
s2_alloc_final_offset:  dw 0
s2_rows_left:           dw 0
s2_copy_restore:        db 0
s2_copy_screen:         db 0
s2_copy_x:              dw 0
s2_copy_y:              dw 0
s2_copy_width:          dw 0
s2_row_page:            db 0
s2_row_offset:          dw 0
s2_data_address:        dw 0
s2_vram_address:        dw 0

window_scratch:         ds WIN_WINDOW_SIZE,0
item_scratch:           ds WIN_ITEM_SIZE,0
control_geometry:       ds WIN_RECT_SIZE,0
window_stack:           ds S2_STACK_SIZE*WIN_BACKSTORE_MAX_DEPTH,0

        ifdef WIN320_TEST_BUILD
s2_test_map_count:      db 0
s2_test_unmap_count:    db 0
s2_test_command_count:  db 0
        endif
