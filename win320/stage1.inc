; WIN320 stage 1: theme, static controls and accelerated primitives.
; All caller-owned descriptors and strings are copied into internal storage
; before a CPU window is remapped.

; ---- public state and font entry points ------------------------------------

; DE=ASCIIZ path. The old font remains active unless the new WF32 has been
; completely read, validated and closed.
win_load_font:
        ex de,hl
        ld de,path_scratch
        call s1_copy_path
        or a
        ret nz
        ; Retry deferred cleanup before another replacement can overwrite a
        ; retained block id. The active font remains untouched on failure.
        call s1_release_temp_font
        jp c,.memory
        call s1_release_old_font
        jp c,.memory
        call select_data_window
        jp c,.window

        ld hl,path_scratch
        ld a,1
        ld c,DSS_OPEN
        call win_dss_call
        jp c,.font
        ld (external_handle),a

        ld b,1
        ld c,DSS_GETMEM
        call win_dss_call
        jr c,.memory_close
        ld (temp_font_block),a
        ld a,#ff
        ld (temp_font_page),a
        ld b,1
        ld hl,temp_font_page
        ld c,BIOS_GETMEMBLKPAGES
        call win_bios_call
        jr c,.memory_release

        ; Existing stage-0 loader helpers operate on font_page/init_handle.
        ; Stash the live font identity, point them at the temporary page, then
        ; restore the live identity before any public return.
        ld a,(font_page)
        ld (old_font_page),a
        ld a,(init_handle)
        ld (old_font_handle),a
        ld a,(temp_font_page)
        ld (font_page),a
        ld a,(external_handle)
        ld (init_handle),a
        call s1_read_wf32
        push af
        ld a,(old_font_page)
        ld (font_page),a
        ld a,(old_font_handle)
        ld (init_handle),a
        pop af
        jr c,.font_release

        ld a,(external_handle)
        ld c,DSS_CLOSE
        call win_dss_call
        jr c,.font_release_closed

        ; The file is closed and the temporary page is valid. Publish the new
        ; page/block as one state update; measurements read its WF32 widths.
        ld a,(temp_font_page)
        ld (font_page),a
        ld a,(font_block)
        ld (old_font_block),a
        ld a,(temp_font_block)
        ld (font_block),a
        ld a,#ff
        ld (temp_font_block),a
        ; Cleanup failure is deferred: the new font is already valid and the
        ; retained old block id is retried by the next load or win_free.
        call s1_release_old_font
.success:
        xor a
        ret

.window:
        ld a,WIN_ERR_WINDOW
        or a
        ret
.memory:
        ld a,WIN_ERR_MEMORY
        or a
        ret
.memory_release:
        call s1_release_temp_font
.memory_close:
        ld a,(external_handle)
        ld c,DSS_CLOSE
        call win_dss_call
        ld a,WIN_ERR_MEMORY
        or a
        ret
.font_release:
        push af
        ld a,(external_handle)
        ld c,DSS_CLOSE
        call win_dss_call
        pop af
.font_release_closed:
        call s1_release_temp_font
.font:
        ld a,WIN_ERR_FONT
        or a
        ret

s1_read_wf32:
        ld hl,io_scratch
        ld de,WF32_HEADER_SIZE
        call read_payload
        ret c
        ld a,d
        or a
        jr nz,.bad
        ld a,e
        cp WF32_HEADER_SIZE
        jr nz,.bad
        call validate_wf32_header
        ret c

        xor a
        ld (copy_offset),a
        ld (copy_offset+1),a
        ld a,WF32_HEADER_SIZE
        ld (copy_count),a
        ld hl,io_scratch
        call copy_scratch_to_font

        ld hl,(font_data_size)
        ld (payload_remaining),hl
        ld hl,WF32_HEADER_SIZE
        ld (copy_offset),hl
.read:
        ld hl,(payload_remaining)
        ld a,h
        or l
        jr z,.validate
        ld a,h
        or a
        ld a,FONT_STAGE_SIZE
        jr nz,.count
        ld a,l
        cp FONT_STAGE_SIZE
        jr c,.count
        ld a,FONT_STAGE_SIZE
.count:
        ld (copy_count),a
        ld e,a
        ld d,0
        ld hl,io_scratch
        call read_payload
        ret c
        ld a,d
        or a
        jr nz,.bad
        ld a,(copy_count)
        cp e
        jr nz,.bad
        ld hl,io_scratch
        call copy_scratch_to_font
        ld a,(copy_count)
        ld e,a
        ld d,0
        ld hl,(payload_remaining)
        or a
        sbc hl,de
        ld (payload_remaining),hl
        ld hl,(copy_offset)
        add hl,de
        ld (copy_offset),hl
        jr .read
.validate:
        jp validate_loaded_font
.bad:
        scf
        ret

s1_release_temp_font:
        ld a,(temp_font_block)
        cp #ff
        ret z
        ld c,DSS_FREEMEM
        call win_dss_call
        ret c
        ld a,#ff
        ld (temp_font_block),a
        ld (temp_font_page),a
        ret

s1_release_old_font:
        ld a,(old_font_block)
        cp #ff
        ret z
        ld c,DSS_FREEMEM
        call win_dss_call
        ret c
        ld a,#ff
        ld (old_font_block),a
        ret

; HL=caller path, DE=path_scratch. At most 255 non-NUL bytes are accepted.
s1_copy_path:
        ld b,#ff
.loop:
        call s1_pointer_byte_ok
        jr c,.bad
        ld a,(hl)
        ld (de),a
        inc de
        or a
        jr z,.ok
        inc hl
        jr z,.bad
        djnz .loop
        call s1_pointer_byte_ok
        jr c,.bad
        ld a,(hl)
        or a
        jr nz,.bad
        ld (de),a
.ok:
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_set_theme:
        ld a,d
        or e
        jr nz,.custom
        ld hl,default_theme
        jr .store
.custom:
        ld bc,WIN_THEME_SIZE
        ld hl,theme_scratch
        call s1_copy_caller_block
        or a
        ret nz
        ld hl,theme_scratch
        ld b,14
.colors:
        ld a,(hl)
        cp 16
        jr nc,.bad
        inc hl
        djnz .colors
        inc hl                      ; focus mask is a full byte
        ld a,(hl)
        or a
        jr nz,.bad
        ld hl,theme_scratch
.store:
        ld de,current_theme
        ld bc,WIN_THEME_SIZE
        ldir
        xor a
        ld (textcore_color_valid),a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_set_text_format:
        ld a,e
        cp 2
        jr nc,.bad
        ld (text_format),a
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_set_origin:
        ld (origin_x),ix
        ld a,e
        ld (origin_y),a
        xor a
        ret

; ---- descriptor and string safety helpers ---------------------------------

; DE=caller, BC=size, HL=internal destination.
s1_copy_caller_block:
        push hl
        push de
        push bc
        ex de,hl
        call s1_validate_caller_range
        pop bc
        pop hl                      ; caller
        pop de                      ; internal destination
        jr c,.bad
        ldir
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

; HL=start, BC=size. Reject wrap and any byte in the DLL's CPU window.
s1_validate_caller_range:
        ld a,b
        or c
        jr z,.bad
        push hl
        call s1_pointer_byte_ok
        pop hl
        jr c,.bad
        push hl
        dec bc
        add hl,bc
        jr c,.bad_pop
        call s1_pointer_byte_ok
        pop hl
        ret
.bad_pop:
        pop hl
.bad:
        scf
        ret

s1_pointer_byte_ok:
        push bc
        ld a,h
        and #c0
        rlca
        rlca
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.bad
        pop bc
        or a
        ret
.bad:
        pop bc
        scf
        ret

; HL=caller string. Copies the selected public format to text_scratch and
; always emits an internal ASCIIZ representation.
s1_copy_public_string:
        ld a,(text_format)
        or a
        jr nz,.pascal
        ld de,text_scratch
        ld b,#ff
.asciiz:
        call s1_pointer_byte_ok
        jr c,.bad
        ld a,(hl)
        ld (de),a
        inc de
        or a
        jr z,.ok
        inc hl
        jr z,.bad
        djnz .asciiz
        call s1_pointer_byte_ok
        jr c,.bad
        ld a,(hl)
        or a
        jr nz,.bad
        ld (de),a
        jr .ok
.pascal:
        call s1_pointer_byte_ok
        jr c,.bad
        ld a,(hl)
        inc hl
        ld c,a
        ld b,0
        push af
        push hl
        call s1_validate_optional_range
        pop hl
        pop af
        jr c,.bad
        ld c,a
        ld b,0
        ld de,text_scratch
        ld a,b
        or c
        jr z,.pascal_done
        ldir
.pascal_done:
        xor a
        ld (de),a
.ok:
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

; HL=start, BC may be zero.
s1_validate_optional_range:
        ld a,b
        or c
        ret z
        jp s1_validate_caller_range

; ---- dynamic work-window selection and mapping -----------------------------

s1_update_stack_window:
        ld hl,0
        add hl,sp
        ld a,h
        and #c0
        rlca
        rlca
        ld (stack_window),a
        ret

; One mapped VRAM window is sufficient for geometry and palette operations.
s1_resolve_vram:
        call s1_update_stack_window
        ld a,(vram_window)
        cp WIN_WORK_AUTO
        jr z,.auto
        call s1_candidate_basic
        jr c,.bad
        jp s1_configure_vram
.auto:
        xor a
.loop:
        call s1_candidate_basic
        jp nc,s1_configure_vram
        inc a
        cp 4
        jr nz,.loop
.bad:
        ld a,WIN_ERR_WINDOW
        or a
        ret

; Resolve data+VRAM simultaneously. A fixed role is reserved while AUTO for
; the other role is chosen, so mixed AUTO/fixed configurations are stable.
s1_resolve_pair:
        call s1_update_stack_window
        ld a,(data_window)
        cp WIN_WORK_AUTO
        jr z,.data_auto
        call s1_candidate_basic
        jr c,.bad
        ld b,a
        ld a,(vram_window)
        cp WIN_WORK_AUTO
        jr z,.data_store
        cp b
        jr z,.bad
.data_store:
        ld a,b
        jr .have_data
.data_auto:
        xor a
.data_loop:
        call s1_candidate_basic
        jr c,.next_data
        ld b,a
        ld a,(vram_window)
        cp WIN_WORK_AUTO
        ld a,b
        jr z,.have_data
        ld c,a
        ld a,(vram_window)
        cp c
        ld a,c
        jr nz,.have_data
.next_data:
        inc a
        cp 4
        jr nz,.data_loop
        jr .bad
.have_data:
        ld (resolved_data_window),a
        call s1_configure_data

        ld a,(vram_window)
        cp WIN_WORK_AUTO
        jr z,.vram_auto
        ld b,a
        ld a,(resolved_data_window)
        cp b
        jr z,.bad
        ld a,b
        call s1_candidate_basic
        jr c,.bad
        jr s1_configure_vram
.vram_auto:
        xor a
.vram_loop:
        ld b,a
        ld a,(resolved_data_window)
        cp b
        ld a,b
        jr z,.next_vram
        call s1_candidate_basic
        jr nc,s1_configure_vram
.next_vram:
        inc a
        cp 4
        jr nz,.vram_loop
.bad:
        ld a,WIN_ERR_WINDOW
        or a
        ret

; A=candidate. CF means code/SP conflict.
s1_candidate_basic:
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.bad
        ld a,(stack_window)
        cp b
        jr z,.bad
        ld a,b
        or a
        ret
.bad:
        ld a,b
        scf
        ret

s1_configure_data:
        ld (resolved_data_window),a
        ld b,a
        call s1_window_port_base
        ld (resolved_data_port),a
        ld (resolved_data_base),hl
        ifdef WIN320_TEST_BUILD
        ld hl,win_test_font_memory
        ld (resolved_data_base),hl
        endif
        xor a
        ret

s1_configure_vram:
        ld (resolved_vram_window),a
        ld b,a
        call s1_window_port_base
        ld (resolved_vram_port),a
        ld (resolved_vram_base),hl
        call s1_set_screen_base
        xor a
        ret

; B=window -> A=page port, HL=logical base.
s1_window_port_base:
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,PAGE_PORT0
        push af
        ld a,b
        rrca
        rrca
        ld h,a
        ld l,0
        pop af
        ret

s1_set_screen_base:
        ld hl,(resolved_vram_base)
        ld a,(screen_id)
        or a
        jr z,.store
        ld de,SCREEN_STRIDE
        add hl,de
.store:
        ld (vram_screen_base),hl
        ret

s1_save_iff:
        ld a,i
        jp po,.off
        ld a,1
        jr .store
.off:
        xor a
.store:
        ld (s1_saved_iff),a
        di
        ret

s1_restore_iff:
        ld a,(s1_saved_iff)
        or a
        ret z
        ei
        ret

; C=page port -> A=current page.
s1_read_page_c:
        ifdef WIN320_TEST_BUILD
        jp win_test_read_page
        else
        in a,(c)
        ret
        endif

; C=page port, A=new page.
s1_write_page_c:
        ifdef WIN320_TEST_BUILD
        jp win_test_write_page
        else
        out (c),a
        ret
        endif

s1_map_vram:
        call s1_save_iff
        ld a,(resolved_vram_port)
        ld c,a
        call s1_read_page_c
        ld (saved_vram_page),a
        ld a,VIDEO_PAGE
        jp s1_write_page_c

s1_unmap_vram:
        ld a,#c0
        out (YPORT),a
        ld a,(resolved_vram_port)
        ld c,a
        ld a,(saved_vram_page)
        call s1_write_page_c
        jp s1_restore_iff

s1_map_pair:
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
        ld a,(font_page)
        call s1_write_page_c
        ld a,(resolved_vram_port)
        ld c,a
        ld a,VIDEO_PAGE
        call s1_write_page_c
        ld hl,(resolved_data_base)
        ld de,WF32_HEADER_SIZE
        add hl,de
        ld (textcore_font_base),hl
        ld hl,(vram_screen_base)
        ld (textcore_vram_base),hl
        ret

s1_unmap_pair:
        ld a,#c0
        out (YPORT),a
        ld a,(resolved_vram_port)
        ld c,a
        ld a,(saved_vram_page)
        call s1_write_page_c
        ld a,(resolved_data_port)
        ld c,a
        ld a,(saved_data_page)
        call s1_write_page_c
        jp s1_restore_iff

; ---- geometry validation ---------------------------------------------------

; A=allowed WinRect flags, DE=caller descriptor.
s1_load_rect:
        ld (rect_allowed_flags),a
        ld bc,WIN_RECT_SIZE
        ld hl,rect_scratch
        call s1_copy_caller_block
        or a
        ret nz
        ld a,(rect_scratch+WIN_RC_FLAGS)
        ld b,a
        ld a,(rect_allowed_flags)
        cpl
        and b
        jr nz,.unsupported
        ld a,b
        ld (rect_flags),a
        ld a,(rect_scratch+WIN_RC_COLOR)
        ld (rect_color),a
        ld hl,(rect_scratch+WIN_RC_WIDTH)
        ld (rect_w),hl
        ld a,h
        or l
        jr z,.empty
        ld hl,(rect_scratch+WIN_RC_HEIGHT)
        ld (rect_h),hl
        ld a,h
        or l
        jr z,.empty

        ld hl,(rect_scratch+WIN_RC_X)
        ld de,(origin_x)
        add hl,de
        jr c,.bad
        ld (rect_x),hl
        ld de,(rect_w)
        add hl,de
        jr c,.bad
        ld de,321
        or a
        sbc hl,de
        jr nc,.bad

        ld hl,(rect_scratch+WIN_RC_Y)
        ld a,(origin_y)
        ld e,a
        ld d,0
        add hl,de
        jr c,.bad
        ld (rect_y),hl
        ld de,(rect_h)
        add hl,de
        jr c,.bad
        ld de,257
        or a
        sbc hl,de
        jr nc,.bad
        xor a
        ld (rect_empty),a
        ret
.empty:
        ld a,1
        ld (rect_empty),a
        xor a
        ret
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

s1_require_frame_size:
        ld hl,(rect_w)
        ld a,h
        or a
        jr nz,.w_ok
        ld a,l
        cp 2
        jr c,.bad
.w_ok:
        ld hl,(rect_h)
        ld a,h
        or a
        jp nz,.ok
        ld a,l
        cp 2
        jr c,.bad
.ok:
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

; A=descriptor color, B=theme role. Output A=palette byte #F0..#FF.
s1_resolve_palette_color:
        cp #ff
        jr nz,.explicit
        ld a,b
        ld e,a
        ld d,0
        ld hl,current_theme
        add hl,de
        ld a,(hl)
        jr .map
.explicit:
        cp 16
        jr nc,.bad
.map:
        or #f0
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        scf
        ret

; A=descriptor full-byte XOR mask. #FF selects theme focus mask.
s1_resolve_xor_mask:
        cp #ff
        ret nz
        ld a,(current_theme+WIN_TH_FOCUS_MASK)
        ret

s1_copy_rect_to_fill:
        ld hl,(rect_x)
        ld (fill_x),hl
        ld hl,(rect_y)
        ld (fill_y),hl
        ld hl,(rect_w)
        ld (fill_w),hl
        ld hl,(rect_h)
        ld (fill_h),hl
        ret

; ---- accelerator fill core -------------------------------------------------

; HL=x -> mapped screen address.
s1_make_dest:
        ld de,(vram_screen_base)
        add hl,de
        ret

; HL=address, A=count 1..160.
s1_hfill_chunk:
        ld (s1_hfill_size+1),a
        ld a,(fill_color)
        ld c,a
        ld d,d
s1_hfill_size:
        ld a,0
        ld c,c
        ld a,c
        ld (hl),a
        ld b,b
        ret

; HL=x address, A=y, C=height (0 means 256).
s1_vfill_chunk:
        ld (fill_current_y),a
        ld a,c
        ld (s1_vfill_size+1),a
        ld a,(fill_current_y)
        out (YPORT),a
        ld a,(fill_color)
        ld e,a
        ld d,d
s1_vfill_size:
        ld a,0
        ld b,b
        ld e,e
        ld (hl),e
        ld b,b
        ret

; fill_x/y/w/h and fill_color are set.  Public rectangles are validated, but
; computed control parts can legitimately collapse to zero.  Treat those as
; empty: accelerator count zero means 256, so forwarding it would paint a
; wrapped full-screen stripe instead of doing no work.
s1_fill_mapped:
        ld hl,(fill_w)
        ld a,h
        or l
        ret z
        ld hl,(fill_h)
        ld a,h
        or l
        ret z
        ifdef WIN320_TEST_BUILD
        jp s1_fill_mapped_test
        else
        ld hl,(fill_x)
        ld a,h
        or l
        jr nz,.choose
        ld hl,(fill_y)
        ld a,h
        or l
        jr nz,.choose
        ld hl,(fill_w)
        ld de,320
        or a
        sbc hl,de
        jr nz,.choose
        ld hl,(fill_h)
        ld de,256
        or a
        sbc hl,de
        jr z,.vertical
.choose:
        ; Multi-column rectangles are filled row by row.  The accelerator's
        ; vertical command is kept only for true one-pixel lines: on mode #81
        ; a wider vertical fill can escape the requested PORT_Y span and leave
        ; a full-height stripe (notably the 10-pixel Stage-5 scrollbar).
        ld hl,(fill_w)
        dec hl
        ld a,h
        or l
        jr z,.vertical
        jr .horizontal
.vertical:
        ld hl,(fill_x)
        call s1_make_dest
        ld de,(fill_w)
        ld (fill_columns_left),de
.vloop:
        ld a,(fill_h+1)
        or a
        jr z,.vshort
        ld c,0
        jr .vgo
.vshort:
        ld a,(fill_h)
        ld c,a
.vgo:
        ld a,(fill_y)
        call s1_vfill_chunk
        inc hl
        ld de,(fill_columns_left)
        dec de
        ld (fill_columns_left),de
        ld a,d
        or e
        jr nz,.vloop
        ret
.horizontal:
        ld hl,(fill_h)
        ld (fill_rows_left),hl
        ld a,(fill_y)
        ld (fill_current_y),a
.row:
        ld hl,(fill_x)
        call s1_make_dest
        ld a,(fill_current_y)
        out (YPORT),a
        ld de,(fill_w)
        ld (fill_bytes_left),de
.chunk:
        ld de,(fill_bytes_left)
        ld a,d
        or a
        jr nz,.wide
        ld a,e
        cp 161
        jr c,.last
.wide:
        ld a,160
        push hl
        call s1_hfill_chunk
        pop hl
        ld de,160
        add hl,de
        ld de,(fill_bytes_left)
        ld bc,160
        ex de,hl
        or a
        sbc hl,bc
        ld (fill_bytes_left),hl
        ex de,hl
        jr .chunk
.last:
        call s1_hfill_chunk
        ld a,(fill_current_y)
        inc a
        ld (fill_current_y),a
        ld hl,(fill_rows_left)
        dec hl
        ld (fill_rows_left),hl
        ld a,h
        or l
        jr nz,.row
        ret
        endif

        ifdef WIN320_TEST_BUILD
s1_fill_mapped_test:
        ld hl,(fill_h)
        ld (fill_rows_left),hl
        ld a,(fill_y)
        ld (fill_current_y),a
.row:
        out (YPORT),a
        ld hl,(fill_x)
        call s1_make_dest
        ld bc,(fill_w)
.pixel:
        ld a,(fill_color)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.pixel
        ld a,(fill_current_y)
        inc a
        ld (fill_current_y),a
        ld hl,(fill_rows_left)
        dec hl
        ld (fill_rows_left),hl
        ld a,h
        or l
        ld a,(fill_current_y)
        jr nz,.row
        ret
        endif

; Draw one horizontal line from line_x/line_y with line_len.
s1_hline_mapped:
        ld hl,(line_x)
        ld (fill_x),hl
        ld hl,(line_y)
        ld (fill_y),hl
        ld hl,(line_len)
        ld (fill_w),hl
        ld hl,1
        ld (fill_h),hl
        jp s1_fill_mapped

; Draw one vertical line from line_x/line_y with line_len.
s1_vline_mapped:
        ld hl,(line_x)
        ld (fill_x),hl
        ld hl,(line_y)
        ld (fill_y),hl
        ld hl,1
        ld (fill_w),hl
        ld hl,(line_len)
        ld (fill_h),hl
        jp s1_fill_mapped

; theme light/shadow, swapped when panel_sunken != 0.
s1_prepare_bevel_colors:
        ld a,(current_theme+WIN_TH_LIGHT)
        or #f0
        ld b,a
        ld a,(current_theme+WIN_TH_SHADOW)
        or #f0
        ld c,a
        ld a,(panel_sunken)
        or a
        jr z,.store
        ld a,b
        ld b,c
        ld c,a
.store:
        ld a,b
        ld (bevel_top_color),a
        ld a,c
        ld (bevel_bottom_color),a
        ret

s1_frame_mapped:
        call s1_prepare_bevel_colors
        ld hl,(rect_x)
        ld (line_x),hl
        ld hl,(rect_y)
        ld (line_y),hl
        ld hl,(rect_w)
        ld (line_len),hl
        ld a,(bevel_top_color)
        ld (fill_color),a
        call s1_hline_mapped

        ld hl,(rect_x)
        ld (line_x),hl
        ld hl,(rect_y)
        ld (line_y),hl
        ld hl,(rect_h)
        ld (line_len),hl
        call s1_vline_mapped

        ld hl,(rect_y)
        ld de,(rect_h)
        add hl,de
        dec hl
        ld (line_y),hl
        ld hl,(rect_x)
        ld (line_x),hl
        ld hl,(rect_w)
        ld (line_len),hl
        ld a,(bevel_bottom_color)
        ld (fill_color),a
        call s1_hline_mapped

        ld hl,(rect_x)
        ld de,(rect_w)
        add hl,de
        dec hl
        ld (line_x),hl
        ld hl,(rect_y)
        ld (line_y),hl
        ld hl,(rect_h)
        ld (line_len),hl
        jp s1_vline_mapped

s1_panel_mapped:
        ; Fill only the interior; the four bevel lines own the border pixels.
        ld hl,(rect_w)
        ld de,2
        or a
        sbc hl,de
        jr z,.frame
        ld (fill_w),hl
        ld hl,(rect_h)
        ld de,2
        or a
        sbc hl,de
        jr z,.frame
        ld (fill_h),hl
        ld hl,(rect_x)
        inc hl
        ld (fill_x),hl
        ld hl,(rect_y)
        inc hl
        ld (fill_y),hl
        call s1_fill_mapped
.frame:
        jp s1_frame_mapped

; ---- public style and geometry entry points --------------------------------

win_style:
        ld a,e
        and #f8
        jr nz,.unsupported
        ld a,e
        ld (style_flags),a
        and WIN_STYLE_PALETTE|WIN_STYLE_CLEAR
        ret z
        ld a,e
        and WIN_STYLE_CLEAR
        jr z,.resolve
        ld a,d
        ld b,WIN_TH_DESKTOP
        call s1_resolve_palette_color
        jr c,.bad
        ld (style_clear_color),a
.resolve:
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        ld a,(style_flags)
        and WIN_STYLE_PALETTE
        call nz,s1_style_palette_mapped
        ld a,(style_flags)
        and WIN_STYLE_CLEAR
        call nz,s1_style_clear_mapped
        call s1_unmap_vram
        xor a
        ret
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret
.bad:
        or a
        ret

s1_style_palette_mapped:
        ld hl,(resolved_vram_base)
        ld de,#03e0
        add hl,de
        push hl
        pop iy
        ld de,ega_palette
        ld c,#f0
        ld b,16
.entry:
        ld a,c
        out (YPORT),a
        ld a,(style_flags)
        and WIN_STYLE_BOTH
        jr nz,.both
        ld a,(screen_id)
        or a
        jr nz,.screen1
        ld a,(de)
        ld (iy+0),a
        inc de
        ld a,(de)
        ld (iy+1),a
        inc de
        ld a,(de)
        ld (iy+2),a
        inc de
        xor a
        ld (iy+3),a
        jr .next
.screen1:
        ld a,(de)
        ld (iy+4),a
        inc de
        ld a,(de)
        ld (iy+5),a
        inc de
        ld a,(de)
        ld (iy+6),a
        inc de
        xor a
        ld (iy+7),a
        jr .next
.both:
        ld a,(de)
        ld (iy+0),a
        ld (iy+4),a
        inc de
        ld a,(de)
        ld (iy+1),a
        ld (iy+5),a
        inc de
        ld a,(de)
        ld (iy+2),a
        ld (iy+6),a
        inc de
        xor a
        ld (iy+3),a
        ld (iy+7),a
.next:
        inc c
        djnz .entry
        ret

s1_style_clear_mapped:
        ld a,(style_clear_color)
        ld (fill_color),a
        ld hl,0
        ld (fill_x),hl
        ld (fill_y),hl
        ld hl,320
        ld (fill_w),hl
        ld hl,256
        ld (fill_h),hl
        ld a,(style_flags)
        and WIN_STYLE_BOTH
        jr nz,.both
        call s1_set_screen_base
        jp s1_fill_mapped
.both:
        ld hl,(resolved_vram_base)
        ld (vram_screen_base),hl
        call s1_fill_mapped
        ld hl,(resolved_vram_base)
        ld de,SCREEN_STRIDE
        add hl,de
        ld (vram_screen_base),hl
        call s1_fill_mapped
        jp s1_set_screen_base

win_fill_rect:
        xor a
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_color)
        ld b,WIN_TH_FACE
        call s1_resolve_palette_color
        jr c,.bad
        ld (fill_color),a
        ld a,(rect_empty)
        or a
        jp nz,.ok
        call s1_copy_rect_to_fill
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_fill_mapped
        call s1_unmap_vram
.ok:
        xor a
        ret
.bad:
        or a
        ret

win_frame:
        ld a,WIN_RC_SUNKEN
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_empty)
        or a
        jr nz,.ok
        call s1_require_frame_size
        or a
        ret nz
        ld a,(rect_flags)
        and WIN_RC_SUNKEN
        ld (panel_sunken),a
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_frame_mapped
        call s1_unmap_vram
.ok:
        xor a
        ret

win_panel:
        ld a,WIN_RC_SUNKEN
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_color)
        ld b,WIN_TH_FACE
        call s1_resolve_palette_color
        jr c,.bad
        ld (fill_color),a
        ld a,(rect_empty)
        or a
        jr nz,.ok
        call s1_require_frame_size
        or a
        ret nz
        ld a,(rect_flags)
        and WIN_RC_SUNKEN
        ld (panel_sunken),a
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_panel_mapped
        call s1_unmap_vram
.ok:
        xor a
        ret
.bad:
        or a
        ret

win_separator:
        ld a,WIN_RC_SUNKEN|WIN_RC_VERTICAL
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_empty)
        or a
        jp nz,.ok
        ld a,(rect_flags)
        and WIN_RC_VERTICAL
        jr nz,.vertical
        ld hl,(rect_h)
        ld de,2
        or a
        sbc hl,de
        jp nz,.bad
        jr .size_ok
.vertical:
        ld hl,(rect_w)
        ld de,2
        or a
        sbc hl,de
        jr nz,.bad
.size_ok:
        ld a,(rect_flags)
        and WIN_RC_SUNKEN
        ld (panel_sunken),a
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_prepare_bevel_colors
        ld a,(rect_flags)
        and WIN_RC_VERTICAL
        jr nz,.draw_vertical
        ld hl,(rect_x)
        ld (line_x),hl
        ld hl,(rect_y)
        ld (line_y),hl
        ld hl,(rect_w)
        ld (line_len),hl
        ld a,(bevel_bottom_color)
        ld (fill_color),a
        call s1_hline_mapped
        ld hl,(line_y)
        inc hl
        ld (line_y),hl
        ld a,(bevel_top_color)
        ld (fill_color),a
        call s1_hline_mapped
        jr .unmap
.draw_vertical:
        ld hl,(rect_x)
        ld (line_x),hl
        ld hl,(rect_y)
        ld (line_y),hl
        ld hl,(rect_h)
        ld (line_len),hl
        ld a,(bevel_bottom_color)
        ld (fill_color),a
        call s1_vline_mapped
        ld hl,(line_x)
        inc hl
        ld (line_x),hl
        ld a,(bevel_top_color)
        ld (fill_color),a
        call s1_vline_mapped
.unmap:
        call s1_unmap_vram
.ok:
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_invert_rect:
        xor a
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_color)
        call s1_resolve_xor_mask
        ld (xor_mask),a
        ld a,(rect_empty)
        or a
        jr nz,.ok
        call s1_fill_xor_scratch
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_invert_mapped
        call s1_unmap_vram
.ok:
        xor a
        ret

s1_fill_xor_scratch:
        ld a,(xor_mask)
        ld hl,xor_scratch
        ld (hl),a
        ld de,xor_scratch+1
        ld bc,255
        ldir
        ret

; DE=source pattern, HL=destination, A=size (0 means 256).
s1_xor_chunk:
        ifdef WIN320_TEST_BUILD
        push bc
        push de
        push hl
        or a
        jr nz,.short
        ld bc,256
        jr .loop
.short:
        ld c,a
        ld b,0
.loop:
        ld a,(de)
        xor (hl)
        ld (hl),a
        inc de
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.loop
        pop hl
        pop de
        pop bc
        ret
        else
        ld (s1_xor_size+1),a
        ld d,d
s1_xor_size:
        ld a,0
        ld b,b
        ld l,l
        ld a,(de)
        xor (hl)
        ld (hl),a
        ld b,b
        ret
        endif

s1_invert_mapped:
        ld hl,(rect_h)
        ld (xor_rows_left),hl
        ld a,(rect_y)
        ld (xor_y),a
.row:
        ld a,(xor_y)
        out (YPORT),a
        ld hl,(rect_x)
        call s1_make_dest
        ld bc,(rect_w)
        ld (xor_bytes_left),bc
.chunk:
        ld bc,(xor_bytes_left)
        ld a,b
        or a
        jr z,.last
        push hl
        ld de,xor_scratch
        xor a                       ; 256-byte block
        call s1_xor_chunk
        pop hl
        ld de,256
        add hl,de
        ld bc,(xor_bytes_left)
        dec b                       ; width is at most 320, so high byte is 1
        ld (xor_bytes_left),bc
        ld a,b
        or c
        jr z,.row_done
        jr .chunk
.last:
        ld a,c
        ld de,xor_scratch
        call s1_xor_chunk
.row_done:
        ld a,(xor_y)
        inc a
        ld (xor_y),a
        ld hl,(xor_rows_left)
        dec hl
        ld (xor_rows_left),hl
        ld a,h
        or l
        jr nz,.row
        ret

win_focus_rect:
        xor a
        call s1_load_rect
        or a
        ret nz
        ld a,(rect_color)
        call s1_resolve_xor_mask
        ld (xor_mask),a
        ld a,(rect_empty)
        or a
        jr nz,.ok
        call s1_require_frame_size
        or a
        ret nz
        call s1_resolve_vram
        or a
        ret nz
        call s1_map_vram
        call s1_focus_mapped
        call s1_unmap_vram
.ok:
        xor a
        ret

; Fill xor_scratch with a checker phase for a horizontal edge.
; focus_edge_x, focus_edge_y and rect_w are inputs.
s1_make_focus_pattern:
        ld hl,(focus_edge_x)
        ld a,l
        ld hl,(focus_edge_y)
        add a,l
        and 1
        ld (focus_phase),a
        ld hl,xor_scratch
        ld bc,(rect_w)
.loop:
        ld a,(focus_phase)
        or a
        jr nz,.zero
        ld a,(xor_mask)
        jr .store
.zero:
        xor a
.store:
        ld (hl),a
        inc hl
        ld a,(focus_phase)
        xor 1
        ld (focus_phase),a
        dec bc
        ld a,b
        or c
        jr nz,.loop
        ret

s1_focus_horizontal:
        call s1_make_focus_pattern
        ld a,(focus_edge_y)
        out (YPORT),a
        ld hl,(focus_edge_x)
        call s1_make_dest
        ld bc,(rect_w)
        ld (xor_bytes_left),bc
        ld de,xor_scratch
.chunk:
        ld bc,(xor_bytes_left)
        ld a,b
        or a
        jr z,.last
        push hl
        push de
        xor a
        call s1_xor_chunk
        pop de
        pop hl
        push de
        ld de,256
        add hl,de
        pop de
        inc d                       ; xor_scratch + 256 is not used again
        ld bc,(xor_bytes_left)
        dec b
        ld (xor_bytes_left),bc
        ld a,b
        or c
        ret z
        jr .chunk
.last:
        ld a,c
        jp s1_xor_chunk

s1_focus_mapped:
        ld hl,(rect_x)
        ld (focus_edge_x),hl
        ld hl,(rect_y)
        ld (focus_edge_y),hl
        call s1_focus_horizontal
        ld hl,(rect_y)
        ld de,(rect_h)
        add hl,de
        dec hl
        ld (focus_edge_y),hl
        call s1_focus_horizontal

        ; Corners already belong to the horizontal edges. Apply the vertical
        ; checker only to the rows strictly between them.
        ld hl,(rect_h)
        ld de,2
        or a
        sbc hl,de
        ret z
        ld (focus_rows_left),hl
        ld hl,(rect_y)
        inc hl
        ld (focus_edge_y),hl
.vrow:
        ld hl,(focus_edge_y)
        ld a,l
        ld hl,(rect_x)
        add a,l
        and 1
        jr nz,.right
        ld a,(focus_edge_y)
        out (YPORT),a
        ld hl,(rect_x)
        call s1_make_dest
        ld de,xor_scratch
        ld a,(xor_mask)
        ld (de),a
        ld a,1
        call s1_xor_chunk
.right:
        ld hl,(rect_x)
        ld de,(rect_w)
        add hl,de
        dec hl
        ld a,l
        ld hl,(focus_edge_y)
        add a,l
        and 1
        jr nz,.next
        ld a,(focus_edge_y)
        out (YPORT),a
        ld hl,(rect_x)
        ld de,(rect_w)
        add hl,de
        dec hl
        call s1_make_dest
        ld de,xor_scratch
        ld a,(xor_mask)
        ld (de),a
        ld a,1
        call s1_xor_chunk
.next:
        ld hl,(focus_edge_y)
        inc hl
        ld (focus_edge_y),hl
        ld hl,(focus_rows_left)
        dec hl
        ld (focus_rows_left),hl
        ld a,h
        or l
        jr nz,.vrow
        ret

; ---- static text -----------------------------------------------------------

s1_measure_text:
        call map_font_page
        call s1_measure_text_mapped
        jp unmap_font_page

s1_measure_clip_text:
        call map_font_page
        call s1_measure_text_mapped
        call s1_clip_text
        jp unmap_font_page

s1_measure_text_mapped:
        ld hl,text_scratch
        ld de,0
.loop:
        ld a,(hl)
        or a
        jr z,.done
        inc hl
        push hl
        call s1_cached_width
        ld c,a
        ld b,0
        ex de,hl
        add hl,bc
        ex de,hl
        pop hl
        jr .loop
.done:
        ld (text_pixel_width),de
        ret

; A=glyph index, A=1..8 proportional width from the mapped WF32 table.
s1_cached_width:
        ld l,a
        ld h,0
        ld bc,WF32_HEADER_SIZE+FONT320_WIDTHS
        add hl,bc
        ifdef WIN320_TEST_BUILD
        ld bc,win_test_font_memory
        else
        ld bc,(work_base)
        endif
        add hl,bc
        ld a,(hl)
        ret

; Clip text_scratch to label width and add two literal dots.
s1_clip_text:
        ld hl,(label_w)
        ld a,h
        or l
        ret z
        ld hl,(text_pixel_width)
        ld de,(label_w)
        or a
        sbc hl,de
        ret c
        ret z
        ld a,(label_flags)
        and WIN_LABEL_CLIP
        ret z

        ; A clipped result needs two dots plus NUL. Cap the prefix at 253
        ; bytes so the terminator cannot spill into the adjacent scratch.
        xor a
        ld (text_scratch+253),a
        ld a,'.'
        call s1_cached_width
        add a,a
        ld (dots_width),a
        ld e,a
        ld d,0
        ld hl,(label_w)
        or a
        sbc hl,de
        jr c,.empty
        ld (clip_prefix_limit),hl
        ld hl,text_scratch
        ld de,0
.scan:
        ld a,(hl)
        or a
        jr z,.append
        push hl
        call s1_cached_width
        ld c,a
        ld b,0
        ex de,hl
        add hl,bc
        ex de,hl
        ld hl,(clip_prefix_limit)
        or a
        sbc hl,de
        pop hl
        jr c,.append
        inc hl
        jr .scan
.append:
        ld (hl),'.'
        inc hl
        ld (hl),'.'
        inc hl
        xor a
        ld (hl),a
        ld a,(dots_width)
        ld c,a
        ld b,0
        ex de,hl
        add hl,bc
        ld (text_pixel_width),hl
        ret
.empty:
        xor a
        ld (text_scratch),a
        ld hl,0
        ld (text_pixel_width),hl
        ret

; Resolve label/button attr. A=#FF uses B=background role, C=foreground role.
; Output A=packed low-nibble attr, fill_color=#F0|background.
s1_resolve_text_attr:
        cp #ff
        jr nz,.explicit
        ld a,b
        ld e,a
        ld d,0
        ld hl,current_theme
        add hl,de
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        ld b,a
        ld a,c
        ld e,a
        ld d,0
        ld hl,current_theme
        add hl,de
        ld a,(hl)
        or b
        jr .store
.explicit:
.store:
        ld (text_attr),a
        and #f0
        rrca
        rrca
        rrca
        rrca
        or #f0
        ld (fill_color),a
        ld a,(text_attr)
        ret

; Validate label geometry without treating width/height zero as a rectangle
; no-op: text still draws at x,y, while FILL uses the declared field.
s1_validate_label_geometry:
        ld hl,(label_x)
        ld de,(origin_x)
        add hl,de
        jr c,.bad
        ld (label_x),hl
        ld de,320
        or a
        sbc hl,de
        jr nc,.bad
        ld hl,(label_y)
        ld a,(origin_y)
        ld e,a
        ld d,0
        add hl,de
        jr c,.bad
        ld (label_y),hl
        ld de,256
        or a
        sbc hl,de
        jr nc,.bad
        ld hl,(label_w)
        ld a,h
        or l
        jr z,.height
        ld hl,(label_x)
        ld de,(label_w)
        add hl,de
        jr c,.bad
        ld de,321
        or a
        sbc hl,de
        jr nc,.bad
.height:
        ld hl,(label_h)
        ld a,h
        or l
        jr z,.ok
        ld hl,(label_y)
        ld de,(label_h)
        add hl,de
        jr c,.bad
        ld de,257
        or a
        sbc hl,de
        jr nc,.bad
.ok:
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_label:
        ld bc,WIN_LABEL_SIZE
        ld hl,label_scratch
        call s1_copy_caller_block
        or a
        ret nz
s1_label_loaded:
        call s1_label_prepare_loaded
        or a
        ret nz
s1_label_render_prepared:
        call s1_resolve_pair
        or a
        ret nz
        call s1_map_pair
        ld a,(label_flags)
        and WIN_LABEL_FILL
        call nz,s1_label_fill_mapped
        ld hl,text_scratch
        ld de,(text_x)
        ld bc,(text_y)
        ld a,(text_attr)
        call textcore_draw_mapped
        call s1_unmap_pair
        xor a
        ret

; Validate and prepare the descriptor already copied to label_scratch.
; Modal preflight reuses this path to measure the exact rendered bounds.
s1_label_prepare_loaded:
        ld a,(label_scratch+WIN_LBL_FLAGS)
        and #f0
        jp nz,.unsupported
        ld a,(label_scratch+WIN_LBL_FLAGS)
        and WIN_LABEL_ALIGN_MASK
        cp 3
        jr z,.bad
        ld a,(label_scratch+WIN_LBL_FLAGS)
        ld (label_flags),a
        ld hl,(label_scratch+WIN_LBL_X)
        ld (label_x),hl
        ld hl,(label_scratch+WIN_LBL_Y)
        ld (label_y),hl
        ld hl,(label_scratch+WIN_LBL_WIDTH)
        ld (label_w),hl
        ld a,h
        or l
        jr nz,.flags_ok
        ld a,(label_flags)
        and WIN_LABEL_ALIGN_MASK
        jp nz,.bad
.flags_ok:
        ld hl,(label_scratch+WIN_LBL_HEIGHT)
        ld (label_h),hl
        call s1_validate_label_geometry
        or a
        ret nz
        ld a,(label_scratch+WIN_LBL_ATTR)
        ld b,WIN_TH_FACE
        ld c,WIN_TH_TEXT
        call s1_resolve_text_attr

        ld hl,(label_scratch+WIN_LBL_TEXT)
        call s1_copy_public_string
        or a
        ret nz
        ld a,(font_page)
        cp #ff
        jr z,.font
        call s1_measure_clip_text
        call s1_label_position
        xor a
        ret
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret
.font:
        ld a,WIN_ERR_FONT
        or a
        ret

s1_label_position:
        ld hl,(label_x)
        ld (text_x),hl
        ld hl,(label_y)
        ld (text_y),hl
        ld hl,(label_w)
        ld a,h
        or l
        ret z
        ld de,(text_pixel_width)
        or a
        sbc hl,de                    ; free space (or underflow)
        ret c
        ld a,(label_flags)
        and WIN_LABEL_ALIGN_MASK
        ret z
        cp WIN_LABEL_CENTER
        jr nz,.right
        srl h
        rr l
.right:
        ld de,(text_x)
        add hl,de
        ld (text_x),hl
        ret

s1_label_fill_mapped:
        ld hl,(label_w)
        ld a,h
        or l
        ret z
        ld (fill_w),hl
        ld hl,(label_h)
        ld a,h
        or l
        ret z
        ld (fill_h),hl
        ld hl,(label_x)
        ld (fill_x),hl
        ld hl,(label_y)
        ld (fill_y),hl
        jp s1_fill_mapped

win_button:
        ld bc,WIN_BUTTON_SIZE
        ld hl,button_scratch
        call s1_copy_caller_block
        or a
        ret nz
        jp s1_button_loaded

; Draw the descriptor already copied to button_scratch. Stage 2 uses this
; path to derive WIN_BTN_DISABLED without mutating the caller's descriptor.
s1_button_loaded:
        ld a,(button_scratch+WIN_BTN_FLAGS)
        and #f0
        jp nz,.unsupported
        ld a,(button_scratch+WIN_BTN_FLAGS)
        ld (button_flags),a
        ld hl,(button_scratch+WIN_BTN_X)
        ld (rect_scratch+WIN_RC_X),hl
        ld hl,(button_scratch+WIN_BTN_Y)
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(button_scratch+WIN_BTN_WIDTH)
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld hl,(button_scratch+WIN_BTN_HEIGHT)
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        xor a
        ld (rect_scratch+WIN_RC_FLAGS),a
        ld a,#ff
        ld (rect_scratch+WIN_RC_COLOR),a
        call s1_load_rect_internal
        or a
        ret nz
        ld a,(rect_empty)
        or a
        jp nz,.bad
        ld hl,(rect_w)
        ld de,2
        or a
        sbc hl,de
        jp c,.bad
        ld hl,(rect_h)
        ld de,10
        or a
        sbc hl,de
        jp c,.bad
        ld a,(button_flags)
        and WIN_BTN_FOCUS
        jr z,.size_ok
        ld hl,(rect_w)
        ld de,6
        or a
        sbc hl,de
        jp c,.bad
.size_ok:
        ld a,(button_scratch+WIN_BTN_ATTR)
        ld b,WIN_TH_FACE
        ld c,WIN_TH_TEXT
        call s1_resolve_text_attr
        ld a,(button_flags)
        and WIN_BTN_DISABLED
        jr z,.text
        ld a,(text_attr)
        and #f0
        ld b,a
        ld a,(current_theme+WIN_TH_TEXT_DISABLED)
        or b
        ld (text_attr),a
.text:
        ld a,(button_flags)
        and WIN_BTN_GLYPH
        jr z,.string
        ld a,(button_scratch+WIN_BTN_TEXT+1)
        or a
        jr nz,.bad
        ld a,(button_scratch+WIN_BTN_TEXT)
        ld (text_scratch),a
        xor a
        ld (text_scratch+1),a
        jr .measured
.string:
        ld hl,(button_scratch+WIN_BTN_TEXT)
        call s1_copy_public_string
        or a
        ret nz
.measured:
        ld a,(font_page)
        cp #ff
        jr z,.font
        call s1_measure_text
        call s1_validate_button_text
        or a
        ret nz
        call s1_position_button_text
        call s1_resolve_pair
        or a
        ret nz
        call s1_map_pair
        ld a,(button_flags)
        and WIN_BTN_DISABLED
        jr nz,.raised
        ld a,(button_flags)
        and WIN_BTN_PRESSED
        jr .sunken
.raised:
        xor a
.sunken:
        ld (panel_sunken),a
        call s1_panel_mapped
        ld hl,text_scratch
        ld de,(text_x)
        ld bc,(text_y)
        ld a,(text_attr)
        call textcore_draw_mapped
        ld a,(button_flags)
        and WIN_BTN_FOCUS
        call nz,s1_button_focus_mapped
        call s1_unmap_pair
        xor a
        ret
.unsupported:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret
.font:
        ld a,WIN_ERR_FONT
        or a
        ret

; Load the already-internal rect_scratch without re-reading caller memory.
s1_load_rect_internal:
        xor a
        ld (rect_flags),a
        ld a,#ff
        ld (rect_color),a
        ld hl,(rect_scratch+WIN_RC_WIDTH)
        ld (rect_w),hl
        ld a,h
        or l
        jr z,.empty
        ld hl,(rect_scratch+WIN_RC_HEIGHT)
        ld (rect_h),hl
        ld a,h
        or l
        jr z,.empty
        ld hl,(rect_scratch+WIN_RC_X)
        ld de,(origin_x)
        add hl,de
        jr c,.bad
        ld (rect_x),hl
        ld de,(rect_w)
        add hl,de
        jr c,.bad
        ld de,321
        or a
        sbc hl,de
        jr nc,.bad
        ld hl,(rect_scratch+WIN_RC_Y)
        ld a,(origin_y)
        ld e,a
        ld d,0
        add hl,de
        jr c,.bad
        ld (rect_y),hl
        ld de,(rect_h)
        add hl,de
        jr c,.bad
        ld de,257
        or a
        sbc hl,de
        jr nc,.bad
        xor a
        ld (rect_empty),a
        ret
.empty:
        ld a,1
        ld (rect_empty),a
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

s1_validate_button_text:
        ld hl,(rect_w)
        ld de,2
        or a
        sbc hl,de
        jr c,.bad
        ld a,(button_flags)
        and WIN_BTN_FOCUS
        jr z,.compare
        dec hl
        dec hl
.compare:
        ld de,(text_pixel_width)
        or a
        sbc hl,de
        jr c,.bad
        xor a
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

s1_position_button_text:
        ld hl,(rect_w)
        ld de,(text_pixel_width)
        or a
        sbc hl,de
        srl h
        rr l
        ld de,(rect_x)
        add hl,de
        ld (text_x),hl
        ld hl,(rect_h)
        ld de,8
        or a
        sbc hl,de
        srl h
        rr l
        ld de,(rect_y)
        add hl,de
        ld (text_y),hl
        ld a,(button_flags)
        and WIN_BTN_DISABLED
        ret nz
        ld a,(button_flags)
        and WIN_BTN_PRESSED
        ret z
        ld hl,(text_x)
        inc hl
        ld (text_x),hl
        ld hl,(text_y)
        inc hl
        ld (text_y),hl
        ret

s1_button_focus_mapped:
        ld hl,(rect_x)
        inc hl
        inc hl
        ld (rect_x),hl
        ld hl,(rect_y)
        inc hl
        inc hl
        ld (rect_y),hl
        ld hl,(rect_w)
        dec hl
        dec hl
        dec hl
        dec hl
        ld (rect_w),hl
        ld hl,(rect_h)
        dec hl
        dec hl
        dec hl
        dec hl
        ld (rect_h),hl
        ld a,(current_theme+WIN_TH_FOCUS_MASK)
        ld (xor_mask),a
        jp s1_focus_mapped

; ---- stage-1 internal state -------------------------------------------------

external_handle:        db 0
temp_font_block:        db #ff
temp_font_page:         db #ff
old_font_block:         db #ff
old_font_page:          db #ff
old_font_handle:        db 0

resolved_data_window:   db #ff
resolved_vram_window:   db #ff
resolved_data_port:     db PAGE_PORT0
resolved_vram_port:     db PAGE_PORT0
resolved_data_base:     dw 0
resolved_vram_base:     dw 0
vram_screen_base:       dw 0
saved_data_page:        db 0
saved_vram_page:        db 0
s1_saved_iff:           db 0

rect_allowed_flags:     db 0
rect_flags:             db 0
rect_color:             db 0
rect_empty:             db 0
rect_x:                 dw 0
rect_y:                 dw 0
rect_w:                 dw 0
rect_h:                 dw 0

fill_color:             db 0
fill_x:                 dw 0
fill_y:                 dw 0
fill_w:                 dw 0
fill_h:                 dw 0
fill_columns_left:      dw 0
fill_rows_left:         dw 0
fill_bytes_left:        dw 0
fill_current_y:         db 0
line_x:                 dw 0
line_y:                 dw 0
line_len:               dw 0
panel_sunken:           db 0
bevel_top_color:        db 0
bevel_bottom_color:     db 0

style_flags:            db 0
style_clear_color:      db 0

xor_mask:               db 0
xor_y:                  db 0
xor_rows_left:          dw 0
xor_bytes_left:         dw 0
focus_edge_x:           dw 0
focus_edge_y:           dw 0
focus_rows_left:        dw 0
focus_phase:            db 0

label_x:                dw 0
label_y:                dw 0
label_w:                dw 0
label_h:                dw 0
label_flags:            db 0
button_flags:           db 0
text_attr:              db 0
text_x:                 dw 0
text_y:                 dw 0
text_pixel_width:       dw 0
dots_width:             db 0
clip_prefix_limit:      dw 0

rect_scratch:           ds WIN_RECT_SIZE,0
label_scratch:          ds WIN_LABEL_SIZE,0
button_scratch:         ds WIN_BUTTON_SIZE,0
theme_scratch           equ path_scratch
current_theme:          ds WIN_THEME_SIZE,0
path_scratch:           ds 256,0
text_scratch:           ds 256,0
; Text rendering and XOR/caret restoration never consume their buffers at
; the same time: an old caret is restored before the next glyph is staged.
; Share the larger 320-byte workspace to keep the L0 image below 16 KiB.
xor_scratch             equ text_scratch
                        ds 64,0

default_theme:
        db 15,7,8,1,0,7,15,0
        db 1,15,7,1,7,1,#0f,0

; Canonical 16-colour EGA palette (RGB8), installed at #F0..#FF.
ega_palette:
        db #00,#00,#00, #00,#00,#80, #00,#80,#00, #00,#80,#80
        db #80,#00,#00, #80,#00,#80, #80,#80,#00, #80,#80,#80
        db #c0,#c0,#c0, #00,#00,#ff, #00,#ff,#00, #00,#ff,#ff
        db #ff,#00,#00, #ff,#00,#ff, #ff,#ff,#00, #ff,#ff,#ff
