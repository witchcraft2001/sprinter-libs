; WIN320 Stage 5: icon, progress, scrollbar, and listbox controls.

; Stage 5 shares the path buffer with the non-reentrant font/edit paths.
s5_control_ptr          equ path_scratch+140
s5_progress_scratch     equ path_scratch+142
s5_new_px               equ path_scratch+154
s5_inner_x              equ path_scratch+158
s5_inner_y              equ path_scratch+160
s5_inner_w              equ path_scratch+162
s5_inner_h              equ path_scratch+164
s5_result               equ path_scratch+166
s5_icon_scratch         equ s5_progress_scratch
s5_icon_source          equ path_scratch+168
s5_icon_dest            equ path_scratch+170
s5_icon_y               equ path_scratch+172
s5_icon_rows            equ path_scratch+173
s5_scroll_scratch       equ s5_progress_scratch
s5_track_x              equ path_scratch+174
s5_track_y              equ path_scratch+176
s5_track_w              equ path_scratch+178
s5_track_h              equ path_scratch+180
s5_track_len            equ path_scratch+182
s5_thickness            equ path_scratch+184
s5_new_pos              equ path_scratch+186
s5_new_len              equ path_scratch+188
s5_scale_pixels         equ path_scratch+194
s5_scale_numerator      equ path_scratch+196
s5_scale_denominator    equ path_scratch+198
s5_scroll_edge          equ s5_scale_pixels
s5_list_scratch         equ s5_progress_scratch
s5_content_x            equ s5_track_x
s5_content_y            equ s5_track_y
s5_content_w            equ s5_track_w
s5_content_h            equ s5_track_h
s5_visible              equ path_scratch+200
s5_row_index            equ path_scratch+202
s5_row_y                equ path_scratch+204
s5_row_attr              equ path_scratch+206
s5_text_page             equ path_scratch+207
s5_text_offset           equ path_scratch+208

; ---- progress bar ---------------------------------------------------------

win_progress_init:
        ld (s5_control_ptr),de
        call s5_load_progress
        ret nz
        ld hl,(s5_control_ptr)
        ld de,WIN_PG_LAST_PX
        add hl,de
        ld (hl),#ff
        inc hl
        ld (hl),#ff
        xor a
        ret

win_progress_draw:
        ld (s5_control_ptr),de
        jp s5_progress_draw_ptr

s5_progress_draw_ptr:
        call s5_load_progress
        ret nz
        call s5_progress_boundary
        ld (s5_new_px),hl
        ld hl,(s5_progress_scratch+WIN_PG_LAST_PX)
        ld de,(s5_new_px)
        or a
        sbc hl,de
        jr z,.publish
.full:
        call s1_resolve_vram
        ret nz
        call s1_map_vram
        ld a,(s5_progress_scratch+WIN_PG_FLAGS)
        and WIN_PG_FRAME
        jr z,.plain
        ld a,(current_theme+WIN_TH_PROGRESS)
        or #f0
        ld (fill_color),a
        ld a,1
        ld (panel_sunken),a
        call s1_panel_mapped
        call s5_set_inner_fill
        jr .filled_bg
.plain:
        call s5_set_inner_fill
        ld a,(current_theme+WIN_TH_PROGRESS)
        or #f0
        ld (fill_color),a
        call s1_fill_mapped
.filled_bg:
        ld hl,(s5_new_px)
        ld a,h
        or l
        jr z,.unmap
        ld (fill_w),hl
        ld a,(current_theme+WIN_TH_PROGRESS_FILL)
        or #f0
        ld (fill_color),a
        call s1_fill_mapped
.unmap:
        call s1_unmap_vram
.publish:
        ld hl,(s5_control_ptr)
        ld de,WIN_PG_LAST_PX
        add hl,de
        ld de,(s5_new_px)
        ld (hl),e
        inc hl
        ld (hl),d
        xor a
        ret

; Validate and prepare full/inner geometry in the shared primitive state.
s5_load_progress:
        ld de,(s5_control_ptr)
        ld bc,WIN_PROGRESS_SIZE
        ld hl,s5_progress_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s5_progress_scratch+WIN_PG_FLAGS)
        and #fe
        jp nz,s5_unsupported
        ld a,(s5_progress_scratch+WIN_PG_PERCENT)
        cp 101
        jp nc,s5_bad
        ld hl,(s5_progress_scratch+WIN_PG_WIDTH)
        ld a,h
        or l
        jp z,s5_bad
        ld hl,(s5_progress_scratch+WIN_PG_HEIGHT)
        ld de,3
        or a
        sbc hl,de
        jp c,s5_bad
        ld a,(s5_progress_scratch+WIN_PG_FLAGS)
        and WIN_PG_FRAME
        jr z,.geometry
        ld hl,(s5_progress_scratch+WIN_PG_WIDTH)
        ld de,3
        or a
        sbc hl,de
        jp c,s5_bad
.geometry:
        ld hl,(s5_progress_scratch+WIN_PG_X)
        ld (rect_scratch+WIN_RC_X),hl
        ld hl,(s5_progress_scratch+WIN_PG_Y)
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(s5_progress_scratch+WIN_PG_WIDTH)
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld hl,(s5_progress_scratch+WIN_PG_HEIGHT)
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        call s1_load_rect_internal
        ret nz
        ld hl,(rect_x)
        ld (s5_inner_x),hl
        ld hl,(rect_y)
        ld (s5_inner_y),hl
        ld hl,(rect_w)
        ld (s5_inner_w),hl
        ld hl,(rect_h)
        ld (s5_inner_h),hl
        ld a,(s5_progress_scratch+WIN_PG_FLAGS)
        and WIN_PG_FRAME
        ret z
        ld hl,(s5_inner_x)
        inc hl
        ld (s5_inner_x),hl
        ld hl,(s5_inner_y)
        inc hl
        ld (s5_inner_y),hl
        ld hl,(s5_inner_w)
        dec hl
        dec hl
        ld (s5_inner_w),hl
        ld hl,(s5_inner_h)
        dec hl
        dec hl
        ld (s5_inner_h),hl
        xor a
        ret

; floor(inner_width * percent / 100), with a bounded 16-bit product.
s5_progress_boundary:
        ld hl,(s5_inner_w)
        ld (s5_scale_pixels),hl
        ld a,(s5_progress_scratch+WIN_PG_PERCENT)
        ld l,a
        ld h,0
        ld (s5_scale_numerator),hl
        ld hl,100
        ld (s5_scale_denominator),hl
        jp s5_scale_ratio

s5_set_inner_fill:
        ld hl,(s5_inner_x)
        ld (fill_x),hl
        ld hl,(s5_inner_y)
        ld (fill_y),hl
        ld hl,(s5_inner_w)
        ld (fill_w),hl
        ld hl,(s5_inner_h)
        ld (fill_h),hl
        ret

s5_unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret
s5_bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

; ---- icon -----------------------------------------------------------------

win_icon:
        ld (s5_control_ptr),de
        ld bc,WIN_ICON_SIZE
        ld hl,s5_icon_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s5_icon_scratch+WIN_ICO_FLAGS)
        and #fe
        jr nz,s5_unsupported
        ld a,(s5_icon_scratch+WIN_ICO_RESERVED)
        or a
        jr nz,s5_bad
        ld hl,(s5_icon_scratch+WIN_ICO_WIDTH)
        ld a,h
        or a
        jp nz,s5_bad
        ld a,l
        cp 8
        jr z,.size
        cp 16
        jp nz,s5_bad
        ld a,(s5_icon_scratch+WIN_ICO_SLOT)
        cp 64
        jp nc,s5_bad
.size:
        ld de,(s5_icon_scratch+WIN_ICO_HEIGHT)
        or a
        sbc hl,de
        jp nz,s5_bad
        ld hl,(s5_icon_scratch+WIN_ICO_X)
        ld (rect_scratch+WIN_RC_X),hl
        ld hl,(s5_icon_scratch+WIN_ICO_Y)
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(s5_icon_scratch+WIN_ICO_WIDTH)
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        call s1_load_rect_internal
        jr nz,.done
        call s1_resolve_pair
        jr nz,.done
        call s5_prepare_icon_addresses
        call s5_map_icon_pair
        ld a,(rect_y)
        ld (s5_icon_y),a
        ld a,(s5_icon_scratch+WIN_ICO_WIDTH)
        ld (s5_icon_rows),a
.row:
        ld a,(s5_icon_y)
        out (YPORT),a
        ld hl,(s5_icon_source)
        ld de,(s5_icon_dest)
        ld a,(s5_icon_scratch+WIN_ICO_WIDTH)
        call s2_copy_chunk
        ld a,(s5_icon_scratch+WIN_ICO_WIDTH)
        ld e,a
        ld d,0
        ld hl,(s5_icon_source)
        add hl,de
        ld (s5_icon_source),hl
        ld hl,s5_icon_y
        inc (hl)
        ld hl,s5_icon_rows
        dec (hl)
        jr nz,.row
        call s1_unmap_pair
        xor a
.done:
        or a
        ret

s5_prepare_icon_addresses:
        ld a,(s5_icon_scratch+WIN_ICO_SLOT)
        ld h,a
        ld l,0
        ld a,(s5_icon_scratch+WIN_ICO_WIDTH)
        cp 16
        jr z,.offset
        srl h
        rr l
        srl h
        rr l
.offset:
        ld de,(resolved_data_base)
        add hl,de
        ld (s5_icon_source),hl
        ld hl,(vram_screen_base)
        ld de,(rect_x)
        add hl,de
        ld (s5_icon_dest),hl
        ret

s5_map_icon_pair:
        call s1_save_iff
        ld a,(resolved_data_port)
        ld c,a
        call s1_read_page_c
        ld (saved_data_page),a
        ld a,(resolved_vram_port)
        ld c,a
        call s1_read_page_c
        ld (saved_vram_page),a
        ld a,(resolved_data_port)
        ld c,a
        ld a,(s5_icon_scratch+WIN_ICO_PAGE)
        call s1_write_page_c
        ld a,(s5_icon_scratch+WIN_ICO_FLAGS)
        and WIN_ICO_KEYED
        add a,a
        add a,a
        add a,a
        add a,VIDEO_PAGE
        ld b,a
        ld a,(resolved_vram_port)
        ld c,a
        ld a,b
        jp s1_write_page_c

; ---- scrollbar ------------------------------------------------------------

win_scrollbar_init:
        ld (s5_control_ptr),de
        call s5_load_scrollbar
        ret nz
        ld hl,(s5_control_ptr)
        ld de,WIN_SB_LAST_POS
        add hl,de
        ld (hl),#ff
        inc hl
        ld (hl),#ff
        xor a
        ret

win_scrollbar_draw:
        ld (s5_control_ptr),de
        jp s5_scrollbar_draw_ptr

s5_scrollbar_draw_ptr:
        call s5_load_scrollbar
        ret nz
        call s5_scrollbar_geometry
        call s1_resolve_vram
        ret nz
        ; An unchanged descriptor is already represented on screen.  This is
        ; the common path for listbox cursor moves within the current page.
        ld hl,(s5_scroll_scratch+WIN_SB_LAST_POS)
        inc hl
        ld a,h
        or l
        jr z,.full
        ld hl,(s5_scroll_scratch+WIN_SB_LAST_POS)
        ld de,(s5_new_pos)
        or a
        sbc hl,de
        jr nz,.changed
        ld hl,(s5_scroll_scratch+WIN_SB_THUMB_LEN)
        ld de,(s5_new_len)
        sbc hl,de                    ; carry is clear after equal positions
        jr z,.publish
.changed:
        call s1_map_vram
        call s5_scrollbar_old_thumb_mapped
        jr .thumb
.full:
        call s1_map_vram
        call s5_scrollbar_full_mapped
.thumb:
        call s5_scrollbar_thumb_mapped
        call s1_unmap_vram
.publish:
        jp s5_publish_scrollbar

s5_load_scrollbar:
        ld de,(s5_control_ptr)
        ld bc,WIN_SCROLLBAR_SIZE
        ld hl,s5_scroll_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and #fc
        jp nz,s5_unsupported
        ld a,(s5_scroll_scratch+WIN_SB_RESERVED)
        or a
        jp nz,s5_bad
        ld hl,(s5_scroll_scratch+WIN_SB_TOTAL)
        ld a,h
        or l
        jr nz,.nonempty
        ld hl,(s5_scroll_scratch+WIN_SB_VISIBLE)
        ld a,h
        or l
        jp nz,s5_bad
        ld hl,(s5_scroll_scratch+WIN_SB_FIRST)
        ld a,h
        or l
        jp nz,s5_bad
        jr .state_ok
.nonempty:
        ld de,(s5_scroll_scratch+WIN_SB_VISIBLE)
        ld a,d
        or e
        jp z,s5_bad
        or a
        sbc hl,de
        jr nc,.max_ready
        ld hl,0
.max_ready:
        ld de,(s5_scroll_scratch+WIN_SB_FIRST)
        or a
        sbc hl,de
        jp c,s5_bad
.state_ok:
        ld hl,(s5_scroll_scratch+WIN_SB_X)
        ld (rect_scratch+WIN_RC_X),hl
        ld hl,(s5_scroll_scratch+WIN_SB_Y)
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(s5_scroll_scratch+WIN_SB_WIDTH)
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld hl,(s5_scroll_scratch+WIN_SB_HEIGHT)
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        call s1_load_rect_internal
        ret nz
        ld a,(rect_empty)
        or a
        jp nz,s5_bad
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_HORIZONTAL
        ld hl,(rect_h)
        ld de,(rect_w)
        jr nz,.dimensions
        ex de,hl
.dimensions:
        ld (s5_thickness),hl
        ex de,hl
        ld (s5_track_len),hl
        ld hl,(s5_thickness)
        ld de,6
        or a
        sbc hl,de
        jp c,s5_bad
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_ARROWS
        jr z,.ready
        ld hl,(s5_thickness)
        add hl,hl
        ex de,hl
        ld hl,(s5_track_len)
        or a
        sbc hl,de
        jp c,s5_bad
        ld a,h
        or l
        jp z,s5_bad
        ld (s5_track_len),hl
.ready:
        xor a
        ret

; Derive track rectangle plus current thumb position/length.
s5_scrollbar_geometry:
        ld hl,(rect_x)
        ld (s5_track_x),hl
        ld hl,(rect_y)
        ld (s5_track_y),hl
        ld hl,(rect_w)
        ld (s5_track_w),hl
        ld hl,(rect_h)
        ld (s5_track_h),hl
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        bit 1,a
        jr z,.scale
        rrca
        jr nc,.vertical_arrows
        ld hl,(s5_track_x)
        ld de,(s5_thickness)
        add hl,de
        ld (s5_track_x),hl
        ld hl,(s5_track_len)
        ld (s5_track_w),hl
        jr .scale
.vertical_arrows:
        ld hl,(s5_track_y)
        ld de,(s5_thickness)
        add hl,de
        ld (s5_track_y),hl
        ld hl,(s5_track_len)
        ld (s5_track_h),hl
.scale:
        ld hl,(s5_scroll_scratch+WIN_SB_TOTAL)
        ld de,(s5_scroll_scratch+WIN_SB_VISIBLE)
        ld a,h
        or l
        jr z,.whole
        or a
        sbc hl,de
        jr c,.whole
        jr z,.whole
        ld hl,(s5_track_len)
        ld (s5_scale_pixels),hl
        ld hl,(s5_scroll_scratch+WIN_SB_VISIBLE)
        ld (s5_scale_numerator),hl
        ld hl,(s5_scroll_scratch+WIN_SB_TOTAL)
        ld (s5_scale_denominator),hl
        call s5_scale_ratio
        ; Clamp without losing the ratio in HL.  The previous subtract-based
        ; comparisons stored (length-minimum-track) on the common in-range
        ; path, e.g. 56-4-84 = #FFE0, which wrapped a vertical thumb through
        ; the whole screen.
        ld a,h
        or a
        jr nz,.len_ok
        ld a,l
        cp WIN_SB_MIN_THUMB
        jr nc,.len_ok
        ld hl,WIN_SB_MIN_THUMB
.len_ok:
        ld de,(s5_track_len)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.store_len
        ex de,hl
.store_len:
        ld (s5_new_len),hl
        ld de,(s5_track_len)
        ex de,hl
        or a
        sbc hl,de
        ld (s5_scale_pixels),hl
        ld hl,(s5_scroll_scratch+WIN_SB_FIRST)
        ld (s5_scale_numerator),hl
        ld hl,(s5_scroll_scratch+WIN_SB_TOTAL)
        ld de,(s5_scroll_scratch+WIN_SB_VISIBLE)
        or a
        sbc hl,de
        ld (s5_scale_denominator),hl
        call s5_scale_ratio
        ld (s5_new_pos),hl
        ret
.whole:
        ld hl,(s5_track_len)
        ld (s5_new_len),hl
        ld hl,0
        ld (s5_new_pos),hl
        ret

; floor(pixels*numerator/denominator), pixels <= 320 without a 32-bit product.
s5_scale_ratio:
        ld hl,0                      ; remainder
        ld ix,0                      ; quotient
        ld bc,(s5_scale_pixels)
.loop:
        ld a,b
        or c
        jr z,.done
        ld de,(s5_scale_numerator)
        add hl,de
        ld de,(s5_scale_denominator)
        jr c,.take
        or a
        sbc hl,de
        jr c,.restore
        jr .accepted
.take:
        or a
        sbc hl,de
.accepted:
        inc ix
        jr .next
.restore:
        add hl,de
.next:
        dec bc
        jr .loop
.done:
        push ix
        pop hl
        ret

s5_scrollbar_full_mapped:
        call s1_copy_rect_to_fill
        ld a,(current_theme+WIN_TH_SCROLL_TRACK)
        or #f0
        ld (fill_color),a
        call s1_fill_mapped
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_ARROWS
        ret z
        ld a,(current_theme+WIN_TH_FACE)
        or #f0
        ld (fill_color),a
        call s5_set_track_fill
        ld hl,0
        ld de,(s5_thickness)
        push de
        sbc hl,de
        call s5_set_thumb_fill
        call s5_raised_fill_mapped
        call s5_set_track_fill
        pop de
        ld hl,(s5_track_len)
        call s5_set_thumb_fill
        jp s5_raised_fill_mapped

; Incremental updates restore only the old thumb rectangle.  Repainting the
; complete track made every one-line listbox movement visibly flash.
s5_scrollbar_old_thumb_mapped:
        call s5_set_track_fill
        ld hl,(s5_scroll_scratch+WIN_SB_LAST_POS)
        ld de,(s5_scroll_scratch+WIN_SB_THUMB_LEN)
        call s5_set_thumb_fill
        ld a,(current_theme+WIN_TH_SCROLL_TRACK)
        or #f0
        ld (fill_color),a
        jp s1_fill_mapped

s5_scrollbar_thumb_mapped:
        call s5_set_track_fill
        ld hl,(s5_new_pos)
        ld de,(s5_new_len)
        call s5_set_thumb_fill
        ld a,(current_theme+WIN_TH_FACE)
        or #f0
        ld (fill_color),a
        jp s5_raised_fill_mapped

; Use the common raised-panel primitive so the thumb and endpoint buttons get
; distinct light top/left and shadow bottom/right edges.
s5_raised_fill_mapped:
        xor a
        ld (panel_sunken),a
        jp s1_panel_mapped

s5_set_track_fill:
        ld hl,(s5_track_x)
        ld (fill_x),hl
        ld (rect_x),hl
        ld hl,(s5_track_y)
        ld (fill_y),hl
        ld (rect_y),hl
        ld hl,(s5_track_w)
        ld (fill_w),hl
        ld (rect_w),hl
        ld hl,(s5_track_h)
        ld (fill_h),hl
        ld (rect_h),hl
        ret

; HL=position, DE=length; update fill rectangle for current orientation.
s5_set_thumb_fill:
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_HORIZONTAL
        jr z,.vertical
        push de
        ld de,(fill_x)
        add hl,de
        ld (fill_x),hl
        ld (rect_x),hl
        pop de
        ld (fill_w),de
        ld (rect_w),de
        ret
.vertical:
        push de
        ld de,(fill_y)
        add hl,de
        ld (fill_y),hl
        ld (rect_y),hl
        pop de
        ld (fill_h),de
        ld (rect_h),de
        ret

s5_publish_scrollbar:
        ld hl,(s5_control_ptr)
        ld de,WIN_SB_THUMB_POS
        add hl,de
        ld de,(s5_new_pos)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(s5_new_len)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(s5_new_pos)
        ld (hl),e
        inc hl
        ld (hl),d
        xor a
        ret

win_listbox_draw:
        ld (s5_control_ptr),de
        jp s5_listbox_draw_ptr

s5_listbox_draw_ptr:
        call s5_load_listbox
        ret nz
        call s5_sync_list_scrollbar
        ret nz
        ld hl,(s5_list_scratch+WIN_LB_LAST_FIRST)
        ld a,h
        and l
        inc a
        jr z,.full
        ld de,(s5_list_scratch+WIN_LB_FIRST)
        sbc hl,de
        jr z,.same_first
        inc hl
        ld a,h
        or l
        jr z,.scroll_up
        dec hl
        dec hl
        ld a,h
        or l
        jr nz,.full
        ld a,1
        call s5_listbox_scroll_pixels
        ret nz
        ld hl,(s5_list_scratch+WIN_LB_FIRST)
        jr .scroll_ready
.scroll_up:
        xor a
        call s5_listbox_scroll_pixels
        ret nz
        ld hl,(s5_list_scratch+WIN_LB_FIRST)
        ld a,(s5_visible)
        dec a
        ld e,a
        ld d,0
        add hl,de
.scroll_ready:
        ld (s5_scroll_edge),hl
        ld c,0
        jr .setup_rows
.same_first:
        ld hl,(s5_list_scratch+WIN_LB_LAST_CURSOR)
        ld de,(s5_list_scratch+WIN_LB_CURSOR)
        or a
        sbc hl,de
        jr nz,.row_update
        ; The caller descriptor still contains the focus bit used for the
        ; previous frame; s5_list_scratch contains the newly derived bit.
        ld hl,(s5_control_ptr)
        ld de,WIN_LB_FLAGS
        add hl,de
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        xor (hl)
        jr z,.publish
.row_update:
        ld hl,#ffff
        ld (s5_scroll_edge),hl
        ld c,0
        jr .setup_rows
.full:
        call s5_listbox_background
        ret nz
        ld c,1
.setup_rows:
        ld hl,(s5_list_scratch+WIN_LB_FIRST)
        ld (s5_row_index),hl
        ld hl,(s5_content_y)
        ld (s5_row_y),hl
        ld a,(s5_visible)
        ld b,a
.rows:
        push bc
        ld hl,(s5_row_index)
        ld de,(s5_list_scratch+WIN_LB_TOTAL)
        or a
        sbc hl,de
        jr nc,.next_row
.candidate:
        ld a,c
        or a
        jr nz,.draw_row
        ld hl,(s5_row_index)
        ld de,(s5_list_scratch+WIN_LB_LAST_CURSOR)
        or a
        sbc hl,de
        jr z,.draw_row
        add hl,de
        ld de,(s5_list_scratch+WIN_LB_CURSOR)
        or a
        sbc hl,de
        jr z,.draw_row
        add hl,de
        ld de,(s5_scroll_edge)
        or a
        sbc hl,de
        jr nz,.next_row
.draw_row:
        call s5_listbox_draw_row
        jr nz,.row_failed
.next_row:
        ld hl,(s5_row_index)
        inc hl
        ld (s5_row_index),hl
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        ld e,a
        ld d,0
        ld hl,(s5_row_y)
        add hl,de
        ld (s5_row_y),hl
        pop bc
        djnz .rows
        jr .publish
.row_failed:
        ld (s5_result),a
        pop bc
        ld a,(s5_result)
        or a
        ret
.publish:
        ld hl,(s5_control_ptr)
        ld de,WIN_LB_FLAGS
        add hl,de
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        ld (hl),a
        ld de,WIN_LB_LAST_FIRST-WIN_LB_FLAGS
        add hl,de
        ld de,(s5_list_scratch+WIN_LB_FIRST)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(s5_list_scratch+WIN_LB_CURSOR)
        ld (hl),e
        inc hl
        ld (hl),d
        xor a
        ret

; Move the visible pixel area by one item without repainting all glyphs.
; A=0 scrolls pixels up, A=1 scrolls them down.  The vertical accelerator
; first captures a complete column and then writes it at the new PORT_Y,
; matching the overlap-safe scroll primitive used by GFXView.
s5_listbox_scroll_pixels:
        ld (s5_result),a
        call s1_resolve_vram
        ret nz
        call s1_map_vram
        ld hl,(s5_content_x)
        call s1_make_dest
        ld bc,(s5_content_w)
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        ld e,a
        ld a,(s5_content_h)           ; 256 is encoded as low byte zero
        sub e
        jr z,s5_listbox_scroll_done
        ld (s5_scroll_height+1),a
        ld a,(s5_content_y)
        ld d,a
        add a,e
        ld e,a
        ld a,(s5_result)
        or a
        jr nz,.direction_ready
        ld a,d
        ld d,e
        ld e,a
.direction_ready:
        ld d,d
s5_scroll_height:
        ld a,0
        ld b,b
.column:
        ld a,d
        out (YPORT),a
        ld a,a
        ld a,(hl)
        ld b,b
        ld a,e
        out (YPORT),a
        ld a,a
        ld (hl),a
        ld b,b
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.column
s5_listbox_scroll_done:
        call s1_unmap_vram
        xor a
        ret

s5_load_listbox:
        ld de,(s5_control_ptr)
        ld bc,WIN_LISTBOX_SIZE
        ld hl,s5_list_scratch
        call s1_copy_caller_block
        ret nz
        ld a,(s4_focus_sync_valid)
        or a
        jr z,.focus_ready
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        ld b,a
        ld a,(s4_focus_sync_value)
        or a
        jr z,.focus_clear
        set 2,b
        jr .focus_store
.focus_clear:
        res 2,b
.focus_store:
        ld a,b
        ld (s5_list_scratch+WIN_LB_FLAGS),a
.focus_ready:
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and #f0
        jp nz,s5_unsupported
        ld a,(s5_list_scratch+WIN_LB_RESERVED)
        or a
        jp nz,s5_bad
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        cp 8
        jp c,s5_bad
        ld hl,(s5_list_scratch+WIN_LB_X)
        ld (rect_scratch+WIN_RC_X),hl
        ld hl,(s5_list_scratch+WIN_LB_Y)
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(s5_list_scratch+WIN_LB_WIDTH)
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld hl,(s5_list_scratch+WIN_LB_HEIGHT)
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        call s1_load_rect_internal
        ret nz
        ld a,(rect_empty)
        or a
        jp nz,s5_bad
        ld hl,(rect_x)
        ld (s5_content_x),hl
        ld hl,(rect_y)
        ld (s5_content_y),hl
        ld hl,(rect_w)
        ld (s5_content_w),hl
        ld hl,(rect_h)
        ld (s5_content_h),hl
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_FRAME
        jr z,.content
        ld hl,(s5_content_w)
        ld de,5
        or a
        sbc hl,de
        jp c,s5_bad
        ld hl,(s5_content_h)
        ld de,5
        or a
        sbc hl,de
        jp c,s5_bad
        ld hl,(s5_content_x)
        inc hl
        inc hl
        ld (s5_content_x),hl
        ld hl,(s5_content_y)
        inc hl
        inc hl
        ld (s5_content_y),hl
        ld hl,(s5_content_w)
        dec hl
        dec hl
        dec hl
        dec hl
        ld (s5_content_w),hl
        ld hl,(s5_content_h)
        dec hl
        dec hl
        dec hl
        dec hl
        ld (s5_content_h),hl
.content:
        ld hl,(s5_content_h)
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        ld e,a
        xor a
.divide:
        inc a
        sbc hl,de
        jr nc,.divide
        dec a
        or a
        jp z,s5_bad
        ld (s5_visible),a
        ; Keep the drawable/hit-test/scroll area on complete rows.  The
        ; remainder stays as field background inside the public rectangle.
        add hl,de
        ex de,hl
        ld hl,(s5_content_h)
        or a
        sbc hl,de
        ld (s5_content_h),hl
        ld hl,(s5_list_scratch+WIN_LB_TOTAL)
        ld a,h
        or l
        jr nz,.nonempty
        ld hl,(s5_list_scratch+WIN_LB_FIRST)
        ld a,h
        or l
        jr nz,.bad_state
        ld hl,(s5_list_scratch+WIN_LB_CURSOR)
        inc hl
        ld a,h
        or l
        jr nz,.bad_state
        jr .attrs
.nonempty:
        ld de,(s5_list_scratch+WIN_LB_FIRST)
        or a
        sbc hl,de
        jr c,.bad_state
        jr z,.bad_state
        ld hl,(s5_list_scratch+WIN_LB_CURSOR)
        inc hl
        ld a,h
        or l
        jr z,.items
        dec hl
        ld de,(s5_list_scratch+WIN_LB_TOTAL)
        or a
        sbc hl,de
        jr nc,.bad_state
.items:
        ld hl,(s5_list_scratch+WIN_LB_ITEMS)
        ld a,h
        or l
        jr z,.bad_state
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_PAGED
        jr nz,.paged
        ld a,(s5_list_scratch+WIN_LB_ITEMS_PAGE)
        or a
        jr nz,.bad_state
        ld hl,(s5_list_scratch+WIN_LB_TOTAL)
        add hl,hl
        ld b,h
        ld c,l
        ld hl,(s5_list_scratch+WIN_LB_ITEMS)
        call s1_validate_caller_range
        jr c,.bad_state
        jr .attrs
.paged:
        ld hl,(s5_list_scratch+WIN_LB_TOTAL)
        ld de,(s5_list_scratch+WIN_LB_TOTAL)
        add hl,hl
        add hl,de
        ld de,(s5_list_scratch+WIN_LB_ITEMS)
        add hl,de
        jr c,.bad_state
        ld de,#4001
        or a
        sbc hl,de
        jr nc,.bad_state
.attrs:
        xor a
        ret
.bad_state:
        jp s5_bad

s5_sync_list_scrollbar:
        ld hl,(s5_list_scratch+WIN_LB_SCROLLBAR)
        ld a,h
        or l
        ret z
        push hl
        ld bc,WIN_SB_FIRST+2
        call s1_validate_caller_range
        pop hl
        jr c,.bad
        ld de,WIN_SB_VISIBLE
        add hl,de
        ld a,(s5_visible)
        ld (hl),a
        inc hl
        ld (hl),0
        inc hl
        ld de,(s5_list_scratch+WIN_LB_TOTAL)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(s5_list_scratch+WIN_LB_FIRST)
        ld (hl),e
        inc hl
        ld (hl),d
        xor a
        ret
.bad:
        jp s5_bad

s5_listbox_background:
        ld a,(s5_list_scratch+WIN_LB_ATTR_NORMAL)
        ld b,WIN_TH_FIELD_BG
        ld c,WIN_TH_FIELD_FG
        call s1_resolve_text_attr
        ret c
        call s1_resolve_vram
        ret nz
        call s1_map_vram
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_FRAME
        jr z,.content
        ld a,1
        ld (panel_sunken),a
        call s1_panel_mapped
        ; The panel already filled its complete interior with the resolved
        ; field background.  Its bevel renderer leaves fill_color set to the
        ; shadow colour, so filling the content again would leave the unused
        ; tail below the last whole row gray.
        jr .unmap
.content:
        ld hl,(s5_content_x)
        ld (fill_x),hl
        ld hl,(s5_content_y)
        ld (fill_y),hl
        ld hl,(s5_content_w)
        ld (fill_w),hl
        ld hl,(rect_h)
        ld (fill_h),hl
        call s1_fill_mapped
.unmap:
        call s1_unmap_vram
        xor a
        ret

s5_listbox_draw_row:
        ld hl,(s5_row_index)
        call s5_listbox_text_pointer
        ret nz
        ld a,(s5_list_scratch+WIN_LB_ATTR_NORMAL)
        ld b,a
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_NOCURSOR
        jr nz,.attr
        ld hl,(s5_row_index)
        ld de,(s5_list_scratch+WIN_LB_CURSOR)
        or a
        sbc hl,de
        jr nz,.attr
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_FOCUS
        jr nz,.focused
        ld a,#ff
        ld b,WIN_TH_FACE
        ld c,WIN_TH_TEXT
        jr .resolve_cursor
.focused:
        ld a,(s5_list_scratch+WIN_LB_ATTR_CURSOR)
        ld b,WIN_TH_CURSOR_BG
        ld c,WIN_TH_CURSOR_FG
.resolve_cursor:
        call s1_resolve_text_attr
        ld b,a
.attr:
        ld a,b
        ld (label_scratch+WIN_LBL_ATTR),a
        ld hl,(s5_list_scratch+WIN_LB_X)
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_FRAME
        jr z,.x
        inc hl
        inc hl
.x:
        ld (label_scratch+WIN_LBL_X),hl
        ld hl,(s5_row_y)
        ld a,(origin_y)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (label_scratch+WIN_LBL_Y),hl
        ld hl,(s5_content_w)
        ld (label_scratch+WIN_LBL_WIDTH),hl
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        ld l,a
        ld h,0
        ld (label_scratch+WIN_LBL_HEIGHT),hl
        ld a,WIN_LABEL_FILL|WIN_LABEL_CLIP
        ld (label_scratch+WIN_LBL_FLAGS),a
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_PAGED
        jp nz,s5_listbox_draw_paged_text
        ld hl,(label_scratch+WIN_LBL_TEXT)
        call s1_copy_public_string
        ret nz
        jp s5_listbox_draw_paged_text

; Return direct text pointer in label_scratch or copy a paged string.
s5_listbox_text_pointer:
        ld a,(s5_list_scratch+WIN_LB_FLAGS)
        and WIN_LB_PAGED
        jp nz,s5_listbox_copy_paged
        add hl,hl
        ld de,(s5_list_scratch+WIN_LB_ITEMS)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (label_scratch+WIN_LBL_TEXT),de
        xor a
        ret

s5_listbox_copy_paged:
        ld hl,(s5_row_index)
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(s5_list_scratch+WIN_LB_ITEMS)
        add hl,de
        ld (s5_text_offset),hl
        call select_data_window
        jp c,.window
        call s5_map_work_page
        ld hl,(work_base)
        ld de,(s5_text_offset)
        add hl,de
        ld a,(hl)
        ld (s5_text_page),a
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (s5_text_offset),hl
        call unmap_font_page
        ld hl,(s5_text_offset)
        ld de,#4000
        or a
        sbc hl,de
        jr nc,.bad
        call s5_map_text_page
        ld hl,(work_base)
        ld de,(s5_text_offset)
        add hl,de
        ld de,text_scratch
        ld a,(text_format)
        or a
        jr nz,.pascal
        ld b,#ff
.asciiz:
        ld a,h
        and #c0
        ld c,a
        ld a,(work_base+1)
        and #c0
        cp c
        jr nz,.mapped_bad
        ld a,(hl)
        ld (de),a
        inc de
        inc hl
        or a
        jr z,.copied
        djnz .asciiz
        jr .mapped_bad
.pascal:
        ld a,(hl)
        inc hl
        ld c,a
        ld b,0
        push hl
        add hl,bc
        ld a,h
        and #c0
        ld (s5_row_attr),a
        ld a,(work_base+1)
        and #c0
        ld b,a
        ld a,(s5_row_attr)
        cp b
        ld b,0
        pop hl
        jr nz,.mapped_bad
        ld a,b
        or c
        jr z,.pascal_done
        ldir
.pascal_done:
        xor a
        ld (de),a
.copied:
        call unmap_font_page
        xor a
        ret
.mapped_bad:
        call unmap_font_page
.bad:
        jp s5_bad
.window:
        ld a,WIN_ERR_WINDOW
        or a
        ret

s5_map_work_page:
        ld a,(s5_list_scratch+WIN_LB_ITEMS_PAGE)
        jr s5_map_selected_page
s5_map_text_page:
        ld a,(s5_text_page)
s5_map_selected_page:
        ld b,a
        ld a,(font_page)
        push af
        ld a,b
        ld (font_page),a
        call map_font_page
        pop af
        ld (font_page),a
        ret

s5_listbox_draw_paged_text:
        ld hl,(label_scratch+WIN_LBL_X)
        ld de,(origin_x)
        add hl,de
        ld (label_x),hl
        ld hl,(label_scratch+WIN_LBL_Y)
        ld a,(origin_y)
        ld e,a
        ld d,0
        add hl,de
        ld (label_y),hl
        ld hl,(label_scratch+WIN_LBL_WIDTH)
        ld (label_w),hl
        ld hl,(label_scratch+WIN_LBL_HEIGHT)
        ld (label_h),hl
        ld a,WIN_LABEL_FILL|WIN_LABEL_CLIP
        ld (label_flags),a
        ld a,(label_scratch+WIN_LBL_ATTR)
        ld b,WIN_TH_FIELD_BG
        ld c,WIN_TH_FIELD_FG
        call s1_resolve_text_attr
        ret c
        call s1_measure_clip_text
        call s1_label_position
        ; The label fill still covers the complete row; only the glyph
        ; baseline is centred vertically inside item_height.
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        sub 8
        srl a
        ld hl,(text_y)
        add a,l
        ld l,a
        ld (text_y),hl
        jp s1_label_render_prepared

; Fill WinTrack.part/item for the composite control under the mouse.
; The public hit-test has already loaded item_scratch and checked the common
; geometry.  Scrollbar thumb fields deliberately come from the descriptor:
; they describe the last pixels drawn, so visual and interactive geometry
; cannot diverge between draw calls.
s5_hit_detail:
        ld a,(s3_track_scratch+WIN_TRK_EVENT)
        cp WIN_EV_HOTKEY
        jr c,.mouse_event
        cp WIN_EV_HOVER
        ret nz
.mouse_event:
        ld a,(item_scratch+WIN_ITEM_TYPE)
        cp WIN_T_SCROLLBAR
        jr z,.scrollbar
        cp WIN_T_LISTBOX
        ret nz
        ld a,#ff
        ld (s3_track_scratch+WIN_TRK_ITEM),a
        ld (s3_track_scratch+WIN_TRK_ITEM+1),a
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s5_control_ptr),hl
        call s5_load_listbox
        ret nz
        ld a,(s3_mouse_y)
        ld l,a
        ld h,0
        ld de,(window_scratch+WIN_WND_Y)
        sbc hl,de
        ld de,(s5_content_y)
        sbc hl,de
        ret c
        ld de,(s5_content_h)
        sbc hl,de
        ret nc
        add hl,de
        ld b,0
        ld a,(s5_list_scratch+WIN_LB_ITEM_HEIGHT)
        ld e,a
        ld d,0
.row:
        sbc hl,de
        jr c,.row_ready
        inc b
        jr .row
.row_ready:
        ld l,b
        ld h,0
        ld de,(s5_list_scratch+WIN_LB_FIRST)
        add hl,de
        ld de,(s5_list_scratch+WIN_LB_TOTAL)
        sbc hl,de
        ret nc
        add hl,de
        ld (s3_track_scratch+WIN_TRK_ITEM),hl
        ld a,WIN_LB_PART_ROW
        ld (s3_track_scratch+WIN_TRK_PART),a
        ret
.scrollbar:
        ld hl,(item_scratch+WIN_ITEM_CONTROL)
        ld (s5_control_ptr),hl
        call s5_load_scrollbar
        ret nz
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_HORIZONTAL
        jr z,.vertical
        ld hl,(s3_mouse_x)
        ld de,(window_scratch+WIN_WND_X)
        jr .axis
.vertical:
        ld a,(s3_mouse_y)
        ld l,a
        ld h,0
        ld de,(window_scratch+WIN_WND_Y)
.axis:
        sbc hl,de
        ret c
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_HORIZONTAL
        ld de,(s5_scroll_scratch+WIN_SB_Y)
        jr z,.start_ready
        ld de,(s5_scroll_scratch+WIN_SB_X)
.start_ready:
        sbc hl,de
        ld a,(s5_scroll_scratch+WIN_SB_FLAGS)
        and WIN_SB_ARROWS
        jr z,.track
        ld de,(s5_thickness)
        sbc hl,de
        jr c,.back
        ld de,(s5_track_len)
        sbc hl,de
        jr nc,.forward
        add hl,de
.track:
        ld de,(s5_scroll_scratch+WIN_SB_THUMB_POS)
        or a
        sbc hl,de
        jr c,.page_back
        ld de,(s5_scroll_scratch+WIN_SB_THUMB_LEN)
        sbc hl,de
        jr c,.thumb
        ld a,WIN_SB_PART_PAGE_FORWARD
        jr .part
.back:
        ld a,WIN_SB_PART_BACK
        jr .part
.forward:
        ld a,WIN_SB_PART_FORWARD
        jr .part
.page_back:
        ld a,WIN_SB_PART_PAGE_BACK
        jr .part
.thumb:
        ld a,WIN_SB_PART_THUMB
.part:
        ld (s3_track_scratch+WIN_TRK_PART),a
        ret
