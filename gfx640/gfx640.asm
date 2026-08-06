; GFX640.DLL — accelerated packed-4bpp graphics and 16x32 row-major tiles
; for DSS mode #82. Screen coordinates are always expressed in pixels;
; accelerator and VRAM addresses are expressed in packed bytes.
; Public ABI is described in specs.md.

        ; Production DLLs are linked at zero and relocated by libman.  The
        ; override lets the Z80 harness execute the same source at each real
        ; 16-KiB window address without maintaining a second test-only copy.
        ifndef GFX640_TEST_BUILD
        org 0
        endif

gfx_image_start:
        db "L0"
        dw 0,0,0,0
        db 28,7
        dw 2026
        dw #0100
        ; L0 dispatch table is fixed at #0020.  Header prefix is 16 bytes,
        ; therefore the encoded name field must occupy exactly 16 bytes.
        db "GFX640 graphics",0

        assert ($ & #ff) == #20

        jp gfx_init                 ; 0
        jp gfx_free                 ; 1
        jp gfx_set_vram_window      ; 2
        jp gfx_reserved             ; 3: source is always WIN0
        jp gfx_get_version           ; 4
        jp gfx_get_config            ; 5
        jp gfx_clear                ; 6
        jp gfx_fill_rect            ; 7
        jp gfx_hline                ; 8
        jp gfx_vline                ; 9
        jp gfx_copy_rect            ; 10
        jp gfx_copy_buffer          ; 11
        jp gfx_restore_background_rect ; 12
        jp gfx_palette_load256      ; 13
        jp gfx_palette_load_range   ; 14
        jp gfx_palette_set          ; 15
        jp gfx_fade_begin           ; 16
        jp gfx_fade_step            ; 17
        jp gfx_fade_cancel          ; 18
        jp gfx_reserved             ; 19
        jp gfx_reserved             ; 20
        jp gfx_swap_buffers         ; 21
        jp gfx_set_page_table       ; 22
        jp gfx_draw_tile            ; 23
        jp gfx_draw_tile_fast       ; 24
        jp gfx_draw_tile_span       ; 25
        jp gfx_draw_tilemap         ; 26
        jp gfx_draw_metatile        ; 27
        jp gfx_draw_rect            ; 28
        jp gfx_put_pixel            ; 29
        jp gfx_get_pixel            ; 30
        jp gfx_line                 ; 31
        jp gfx_move_rect            ; 32
        jp gfx_scroll_rect          ; 33
        jp gfx_draw_tile_list       ; 34
        jp gfx_draw_tile_clip       ; 35

; constants
; Keep these values byte-exact with gfx640.inc and specs.md.  #01..#0f are
; reserved for libman/binding errors, therefore GFX errors start at #10.
; For entry >=1 the public status channel is A; CF is intentionally unspecified
; because libman l_call replaces it with its own dispatcher status.
ERR_ARGUMENT    equ #10
ERR_MODE        equ #11
ERR_WINDOW      equ #12
ERR_PAGE        equ #13
ERR_TILE        equ #14
ERR_PALETTE     equ #15
ERR_BUSY        equ #16
ERR_UNSUPPORTED equ #17

PAGEPORT0       equ #82
YPORT           equ #89
RGMOD           equ #c9
VIDEO_PAGE      equ #50
BUF_STRIDE      equ #0140

        ifndef GFX_DI_BUDGET_US
GFX_DI_BUDGET_US equ 200
        endif

        include "../common/accelerator.inc"

; ---- core and configuration -------------------------------------------------

gfx_init:
        ; Keep the loader hook side-effect free: libman calls entry 0 while
        ; l_load still owns its mapping state.  The caller selects mode #82
        ; before rendering; drawing never changes the application video mode.
        ; derive own window: (high byte & #c0) rotated to 0..3
        ld hl,gfx_init
        ld a,h
        and #c0
        rlca
        rlca
        ld (code_window),a
        ; derive stack window and choose a distinct VRAM window from 1..3.
        ld hl,0
        add hl,sp
        ld a,h
        and #c0
        rlca
        rlca
        ld (stack_window),a
        ; Prefer WIN1, then WIN2/WIN3; never hide code or the caller stack.
        ld a,1
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.try2
        ld a,(stack_window)
        cp b
        jr nz,.chosen
.try2:  ld a,2
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.try3
        ld a,(stack_window)
        cp b
        jr nz,.chosen
.try3:  ld a,3
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.no_window
        ld a,(stack_window)
        cp b
        jr z,.no_window
.chosen: ld a,b
        ld (vram_window),a
        call configure_vram_port
        ld a,(initialized)
        or a
        jr nz,.state_ready
        ld a,1
        ld (initialized),a
        xor a
        ld (page_count),a
        ld (page_table_valid),a
        ld (fade_active),a
        ld (palette_valid),a
        ld a,32
        ld (palette_level),a
.state_ready:
        ld a,#c0
        out (YPORT),a
        xor a
        scf
        ccf                        ; A=0, CF=0 for direct Pascal callers
        ret
.no_window:
        ld a,ERR_WINDOW
        scf
        ret
gfx_free:
        ld a,#c0
        out (YPORT),a
        xor a
        scf
        ccf
        ret

gfx_reserved:
        ld a,ERR_UNSUPPORTED
        scf
        ret

; E = 1..3. WIN0 is deliberately reserved for temporary tile source mapping.
gfx_set_vram_window:
        ld a,e
        cp 1
        jr c,.bad
        cp 4
        jr nc,.bad
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.win
        call current_stack_window
        cp b
        jr z,.win
        ld a,b
        ld (vram_window),a
        call configure_vram_port
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        scf
        ret
.win:   ld a,ERR_WINDOW
        scf
        ret

configure_vram_port:
        ld a,(vram_window)
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a                    ; window * #20
        add a,PAGEPORT0
        ld (vram_port),a
        ; CPU address base of WIN1/WIN2/WIN3: #4000/#8000/#C000.
        ld a,b
        rrca
        rrca
        ld h,a
        ld l,0
        ld (vram_base),hl
        ret

gfx_get_version:
        ld de,#0100
        ld ix,#00ff                ; all ABI 1.0 capability groups implemented
        xor a
        ret

; DE -> caller GfxConfig. Byte 0 is caller capacity (1..16).
gfx_get_config:
        ld a,(vram_window)
        ld (config_payload+6),a
        ld a,(code_window)
        ld (config_payload+8),a
        ld a,(de)
        or a
        jr z,.bad
        cp 17
        jr c,.count_ready
        ld a,16
.count_ready:
        ld b,a
        ld hl,config_payload
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
.ok:    xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        scf
        ret

; DE -> page_count physical page bytes. IX=page_count (1..256).
gfx_set_page_table:
        ld a,ixh
        or ixl
        jr z,.bad
        ld a,ixh
        or a
        jr z,.short
        cp 1
        jr nz,.bad
        ld a,ixl
        or a
        jr nz,.bad                 ; #0100 is the only 16-bit full count
.full:  xor a                    ; 256 is represented internally as 0
        ld (page_count),a
        ld bc,256
        jr .copy
.short: ld a,ixl
        ld (page_count),a
        ld c,a
        ld b,0
        jr .copy
.copy:
        ld hl,page_table
        ex de,hl                   ; HL=caller table, DE=internal table
        ldir
        ld a,1
        ld (page_table_valid),a
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        scf
        ret

; ---- target resolution and mapping -----------------------------------------
; A=flags.  Returns A=status; stores alias and destination base (#000/#140).
resolve_target:
        ld (op_flags),a
        and #f0
        jr nz,.bad
        ld a,(op_flags)
        and #0c
        or VIDEO_PAGE
        ld (vram_alias),a
        ld a,(op_flags)
        and 3
        cp 2
        jr c,.fixed
        in a,(RGMOD)
        and 1
        ld b,a
        ld a,(op_flags)
        and 3
        cp 2
        jr z,.front
        ld a,b
        xor 1
        jr .buffer
.front: ld a,b
        jr .buffer
.fixed: ; target 0/1 remains in A
.buffer:or a
        jr z,.zero
        ld hl,BUF_STRIDE
        ld (dest_buffer),hl
        xor a
        ret
.zero:  ld hl,0
        ld (dest_buffer),hl
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

        include "../common/winmgr.inc"

; HL = packed byte x, A = y; outputs the CPU VRAM byte address.
make_dest:
        ld de,(dest_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ret

; Accelerator horizontal fill. HL address, A count (0=256), fill_color set.
hfill_chunk:
        ld (hfill_size+1),a       ; accelerator samples the immediate operand
        ld a,(fill_color)
        ld c,a
        ld d,d                    ; SET_BUFFER
hfill_size:
        ld a,0
        ld c,c                    ; FILL_HORZ; next memory write starts it
        ld a,c
        ld (hl),a
        ld b,b                    ; mandatory completion/idle
        ret

; Accelerator vertical fill. HL=x address, A=y, C=len (0=256).
vfill_chunk:
        ld (line_y),a
        ld a,c
        ld (vfill_size+1),a       ; accelerator samples the immediate operand
        ld a,(line_y)
        out (YPORT),a
        ld a,(fill_color)
        ld e,a                    ; AFNT-compatible fill value register
        ld d,d
vfill_size:
        ld a,0
        ld b,b                    ; SET_BUFFER completion
        ld e,e                    ; FILL_VERT; next memory write starts it
        ld (hl),e
        ld b,b                    ; mandatory completion/idle
        ret

; ---- MVP accelerated primitives --------------------------------------------
; A=color 0..15, E=destination flags. Clear uses 320 accelerator V fills.
gfx_clear:
        cp 16
        jr nc,.bad_color
        bit 3,e
        jr nz,gfx_clear_key
        call expand_color
        ld (fill_color),a
        ld a,e
        call resolve_target
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        call clear_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.bad_color:
        ld a,ERR_ARGUMENT
        ret

; Fill the selected mapped buffer with fill_color using exactly 320 vertical
; accelerator operations.  Caller owns the VRAM mapping and interrupt state.
clear_mapped:
        ld hl,(dest_buffer)
        ld de,(vram_base)
        add hl,de
        xor a
        out (YPORT),a
        ld a,(fill_color)
        ld e,a
        ld d,d                    ; SET_BUFFER, exactly as AFNT320
        ld a,0                    ; immediate operand; 0 means 256 rows
        ld b,b
        ld bc,320
.col:   ld e,e                    ; FILL_VERT
        ld (hl),e
        ld b,b
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.col
        ret
gfx_clear_key:
        ld a,ERR_UNSUPPORTED
        scf
        ret

; A=4-bit color -> A duplicated into both packed nibbles.
expand_color:
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        ret

; A=flags. NZ/ERR_UNSUPPORTED when a solid primitive requests KEY_FF.
reject_solid_key:
        bit 3,a
        jr z,.ok
        ld a,ERR_UNSUPPORTED
        or a
        ret
.ok:   xor a
        ret

; Rect coordinates are still pixels. Aligned byte primitives require even
; x and width and convert them only after all pixel-bound checks succeed.
validate_rect_alignment:
        ld a,(rect_x)
        bit 0,a
        jr nz,.bad
        ld a,(rect_w)
        bit 0,a
        jr nz,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

rect_pixels_to_bytes:
        ld hl,(rect_x)
        srl h
        rr l
        ld (rect_x),hl
        ld hl,(rect_w)
        srl h
        rr l
        ld (rect_w),hl
        ret

; DE -> GfxFillRect: x u16, y u8, w u16, h u16, color, flags, reserved[3].
gfx_fill_rect:
        ld a,(de)
        ld (rect_x),a
        inc de
        ld a,(de)
        ld (rect_x+1),a
        inc de
        ld a,(de)
        ld (rect_y),a
        inc de
        ld a,(de)
        ld (rect_w),a
        inc de
        ld a,(de)
        ld (rect_w+1),a
        inc de
        ld a,(de)
        ld (rect_h),a
        inc de
        ld a,(de)
        ld (rect_h+1),a
        inc de
        ld a,(de)
        ld (pixel_color),a
        inc de
        ld a,(de)
        ld b,a
        ld (pixel_flags),a
        inc de
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        or c
        ld c,a
        inc de
        ld a,(de)
        or c
        jr nz,.bad_reserved
        ld a,(pixel_color)
        cp 16
        jr nc,.bad_reserved
        call expand_color
        ld (fill_color),a
        ld a,(pixel_flags)
        call reject_solid_key
        or a
        ret nz
        ld a,(pixel_flags)
        call resolve_target
        or a
        ret nz
        call validate_rect_alignment
        or a
        ret nz
        call rect_is_empty
        or a
        jr z,.empty
        call validate_rect
        or a
        ret nz
        call rect_pixels_to_bytes
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        call fill_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.bad_reserved:
        ld a,ERR_ARGUMENT
        ret

; IX=x, IYH=0, IYL=y, DE: low 10 bits length, bits 10..13 flags.
gfx_hline:
        cp 16
        jr nc,.bad
        call expand_color
        ld (fill_color),a
        ld a,iyh
        or a
        jr nz,.bad
        ld (rect_x),ix
        ld a,iyl
        ld (rect_y),a
        ld a,e
        ld (rect_w),a
        ld a,d
        and 3
        ld (rect_w+1),a
        ld hl,1
        ld (rect_h),hl
        ld a,d
        and #c0
        jr nz,.bad
        ld a,d
        and #3c
        rrca
        rrca
        ld b,a
        call reject_solid_key
        or a
        ret nz
        ld a,b
        call resolve_target
        or a
        ret nz
        call validate_rect_alignment
        or a
        ret nz
        call rect_is_empty
        or a
        jr z,.empty
        call validate_rect
        or a
        ret nz
        call rect_pixels_to_bytes
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        call fill_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

; IX=x, IYH=0, IYL=y, DE: low 10 bits length, bits 10..13 flags.
gfx_vline:
        cp 16
        jr nc,.bad
        ld (fill_color),a
        ld a,iyh
        or a
        jr nz,.bad
        ld (rect_x),ix
        ld a,iyl
        ld (rect_y),a
        ld hl,1
        ld (rect_w),hl
        ld a,e
        ld (rect_h),a
        ld a,d
        and 3
        ld (rect_h+1),a
        ld a,d
        and #c0
        jr nz,.bad
        ld a,d
        and #3c
        rrca
        rrca
        ld b,a
        call reject_solid_key
        or a
        ret nz
        ld a,b
        call resolve_target
        or a
        ret nz
        call rect_is_empty
        or a
        jr z,.empty
        call validate_rect
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        ld hl,(rect_h)
        ld (line_count),hl
        ld a,(rect_y)
        ld (line_y),a
.loop: ld hl,(rect_x)
        ld a,(line_y)
        call pixel_write_mapped
        ld a,(line_y)
        inc a
        ld (line_y),a
        ld hl,(line_count)
        dec hl
        ld (line_count),hl
        ld a,h
        or l
        jr nz,.loop
        call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

validate_rect:
        ld hl,(rect_x)
        ld de,(rect_w)
        add hl,de
        ld de,641
        or a
        sbc hl,de                 ; x+w <= 640 pixels
        jr nc,.bad
        ld a,(rect_y)
        ld l,a
        ld h,0
        ld de,(rect_h)
        add hl,de
        ld de,257
        or a
        sbc hl,de                 ; y+h <=256
        jr nc,.bad
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

; Write fill_color (0..15) to pixel HL,A in the already mapped target. Reads
; always come from the DRAM mirror; with VRAM_ONLY this deliberately means a
; neighbouring VRAM-only nibble can be restored from the mirror.
pixel_write_mapped:
        ld b,0
        bit 0,l
        jr z,.parity_ready
        inc b
.parity_ready:
        srl h
        rr l
        out (YPORT),a
        call make_dest
        ld a,(fill_color)
        ld c,a
        ld a,b
        or a
        jr nz,.low
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,(hl)
        and #0f
        or c
        ld (hl),a
        ret
.low:  ld a,(hl)
        and #f0
        or c
        ld (hl),a
        ret

; A=0 when either extent is zero, A=1 otherwise.  Empty operations return
; success without looking at coordinates or mapping any hardware window.
rect_is_empty:
        ld a,(rect_w)
        ld b,a
        ld a,(rect_w+1)
        or b
        ret z
        ld a,(rect_h)
        ld b,a
        ld a,(rect_h+1)
        or b
        ret z
        ld a,1
        ret

; Mapped rectangle.  Horizontal blocks are limited to proven 160-byte fills;
; narrow/tall rectangles use one vertical fill per column.
fill_rect_mapped:
        ; The full screen is faster as the required 320 vertical fills than
        ; as 512 horizontal chunks.
        ld hl,(rect_x)
        ld a,h
        or l
        jr nz,.choose
        ld a,(rect_y)
        or a
        jr nz,.choose
        ld hl,(rect_w)
        ld de,320
        or a
        sbc hl,de
        jr nz,.choose
        ld hl,(rect_h)
        ld de,256
        or a
        sbc hl,de
        jp z,clear_mapped
.choose:
        ; A vertical fill costs one command per column; horizontal fill costs
        ; one or two commands per row.  Prefer the cheaper orientation.
        ld hl,(rect_w)
        ld de,(rect_h)
        or a
        sbc hl,de
        jr c,.vertical
        jr z,.vertical
        jr .horizontal
.vertical:
        ld hl,(rect_x)
        call make_dest
.vcol:  ld a,(rect_h+1)
        or a
        jr z,.vshort
        ld c,0                     ; 256 rows
        jr .vfill
.vshort:
        ld a,(rect_h)
        ld c,a
.vfill: ld a,(rect_y)
        call vfill_chunk
        inc hl
        ld de,(rect_w)
        dec de
        ld (rect_w),de
        ld a,d
        or e
        jr nz,.vcol
        ret
.horizontal:
        ld a,(rect_y)
        ld (line_y),a
        ld bc,(rect_h)
.row:   ld hl,(rect_x)
        ld a,(line_y)
        out (YPORT),a
        call make_dest
        push bc
        ld de,(rect_w)
        ld a,d
        or a
        jr nz,.wide
        ld a,e
        cp 161
        jr c,.short
.wide:  ld a,160
        call hfill_chunk
        ld de,160
        add hl,de
        ld de,(rect_w)
        ld a,e
        sub 160                   ; remaining 1..160
        call hfill_chunk
        jr .next
.short: ld a,(rect_w)
        call hfill_chunk
.next:  pop bc
        ld a,(line_y)
        inc a
        ld (line_y),a
        dec bc
        ld a,b
        or c
        jr nz,.row
        ret

; Palette and fade are shared source modules.  They build into this monolithic
; DLL and do not introduce a second runtime handle.
        include "../common/palette.inc"
        include "../common/fade.inc"

; ---- copy, restore and double buffering ------------------------------------

; A=source id 0/1/front/back. Returns source_buffer offset.
resolve_source:
        cp 4
        jr nc,.bad
        cp 2
        jr c,.fixed
        ld b,a
        in a,(RGMOD)
        and 1
        ld c,a
        ld a,b
        cp 2
        ld a,c
        jr z,.selected
        xor 1
.selected:
        or a
        jr z,.zero
        ld hl,BUF_STRIDE
        ld (source_buffer),hl
        xor a
        ret
.fixed:
        or a
        jr z,.zero
        ld hl,BUF_STRIDE
        ld (source_buffer),hl
        xor a
        ret
.zero: ld hl,0
        ld (source_buffer),hl
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; DE -> GfxCopyRect/GfxMoveRect.
gfx_copy_rect:
        call copy_descriptor
        xor a
        ld (copy_require_same),a
        jp copy_rect_core

gfx_move_rect:
        call copy_descriptor
        ld a,1
        ld (copy_require_same),a
        jp copy_rect_core

copy_descriptor:
        ld a,(de)
        ld (copy_source_id),a
        inc de
        ld a,(de)
        ld (copy_flags),a
        inc de
        ld a,(de)
        ld (copy_sx),a
        inc de
        ld a,(de)
        ld (copy_sx+1),a
        inc de
        ld a,(de)
        ld (copy_sy),a
        inc de
        ld a,(de)
        ld (copy_dx),a
        inc de
        ld a,(de)
        ld (copy_dx+1),a
        inc de
        ld a,(de)
        ld (copy_dy),a
        inc de
        ld a,(de)
        ld (copy_w),a
        inc de
        ld a,(de)
        ld (copy_w+1),a
        inc de
        ld a,(de)
        ld (copy_h),a
        inc de
        ld a,(de)
        ld (copy_h+1),a
        ret

copy_rect_core:
        ld a,(copy_source_id)
        call resolve_source
        or a
        ret nz
        ld a,(copy_flags)
        call resolve_target
        or a
        ret nz
        call validate_copy_alignment
        or a
        ret nz
        ld hl,(copy_w)
        ld a,h
        or l
        ret z
        ld hl,(copy_h)
        ld a,h
        or l
        ret z
        call validate_copy_rect
        or a
        ret nz
        call copy_pixels_to_bytes
        ld a,(copy_require_same)
        or a
        jr z,.mapping
        ld hl,(source_buffer)
        ld de,(dest_buffer)
        or a
        sbc hl,de
        jr nz,.bad
.mapping:
        call check_vram_window
        or a
        ret nz
        call copy_rect_prepare
.chunk:
        call enter_di
        call map_vram
        call copy_rect_chunk_mapped
        call unmap_vram
        call leave_di
        ld hl,(copy_rows)
        ld a,h
        or l
        jr nz,.chunk
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

validate_copy_rect:
        ld hl,(copy_sx)
        ld (rect_x),hl
        ld a,(copy_sy)
        ld (rect_y),a
        ld hl,(copy_w)
        ld (rect_w),hl
        ld hl,(copy_h)
        ld (rect_h),hl
        call validate_rect
        or a
        ret nz
        ld hl,(copy_dx)
        ld (rect_x),hl
        ld a,(copy_dy)
        ld (rect_y),a
        jp validate_rect

validate_copy_alignment:
        ld a,(copy_sx)
        bit 0,a
        jr nz,.bad
        ld a,(copy_dx)
        bit 0,a
        jr nz,.bad
        ld a,(copy_w)
        bit 0,a
        jr nz,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

copy_pixels_to_bytes:
        ld hl,(copy_sx)
        srl h
        rr l
        ld (copy_sx),hl
        ld hl,(copy_dx)
        srl h
        rr l
        ld (copy_dx),hl
        ld hl,(copy_w)
        srl h
        rr l
        ld (copy_w),hl
        ret

; D=source, E=destination flags.
gfx_copy_buffer:
        ld a,d
        ld (copy_source_id),a
        ld a,e
        ld (copy_flags),a
        xor a
        ld (copy_sx),a
        ld (copy_sx+1),a
        ld (copy_sy),a
        ld (copy_dx),a
        ld (copy_dx+1),a
        ld (copy_dy),a
        ld (copy_require_same),a
        ld hl,640
        ld (copy_w),hl
        ld hl,256
        ld (copy_h),hl
        jp copy_rect_core

; DE -> GfxRestoreRect: x,y,width,height,target.
gfx_restore_background_rect:
        ld a,(de)
        ld (copy_sx),a
        ld (copy_dx),a
        inc de
        ld a,(de)
        ld (copy_sx+1),a
        ld (copy_dx+1),a
        inc de
        ld a,(de)
        ld (copy_sy),a
        ld (copy_dy),a
        inc de
        ld a,(de)
        ld (copy_w),a
        inc de
        ld a,(de)
        ld (copy_w+1),a
        inc de
        ld a,(de)
        ld (copy_h),a
        inc de
        ld a,(de)
        ld (copy_h+1),a
        inc de
        ld a,(de)
        cp 4
        jr nc,.bad
        ld (copy_source_id),a
        or #04                    ; mirror -> VRAM, do not alter mirror
        ld (copy_flags),a
        xor a
        ld (copy_require_same),a
        jp copy_rect_core
.bad:  ld a,ERR_ARGUMENT
        ret

gfx_swap_buffers:
        in a,(RGMOD)
        xor 1
        out (RGMOD),a
        xor a
        ret

; Both pages are already represented through the selected #50/#54/#58/#5C
; alias. Same-buffer copies use a row buffer and reverse row order when needed.
copy_rect_prepare:
        ld hl,(copy_h)
        ld (copy_rows),hl
        ld a,1
        ld (copy_row_step),a
        ld hl,(source_buffer)
        ld de,(dest_buffer)
        or a
        sbc hl,de
        jr nz,.cross_buffer
        ld a,1
        ld (copy_use_row_buffer),a
        ld a,(copy_dy)
        ld b,a
        ld a,(copy_sy)
        cp b
        jr nc,.rows_ready
        ; Destination begins below source: consume rows bottom-to-top.
        ld hl,(copy_h)
        dec hl
        ld a,(copy_sy)
        add a,l
        ld (copy_sy),a
        ld a,(copy_dy)
        add a,l
        ld (copy_dy),a
        ld a,#ff
        ld (copy_row_step),a
        jr .rows_ready
.cross_buffer:
        ; The accelerator row copy cannot switch PORT_Y between its source
        ; read and destination write, so the direct path is valid only when
        ; both rows coincide.  Cross-row copies bounce through the row buffer.
        ld a,(copy_sy)
        ld b,a
        ld a,(copy_dy)
        cp b
        jr z,.direct
        ld a,1
        ld (copy_use_row_buffer),a
        jr .rows_ready
.direct:
        xor a
        ld (copy_use_row_buffer),a
.rows_ready:
        ld hl,(copy_sx)
        ld de,(source_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ld (copy_src_addr),hl
        ld hl,(copy_dx)
        ld de,(dest_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ld (copy_dst_addr),hl
        ret

; Copy at most eight rows per DI section so sound/input ISRs get bounded gaps.
copy_rect_chunk_mapped:
        ld hl,(copy_rows)
        ld a,h
        or a
        ld a,8
        jr nz,.chunk_ready
        ld a,l
        cp 9
        jr c,.chunk_ready
        ld a,8
.chunk_ready:
        ld (copy_chunk_rows),a
.row:
        ld a,(copy_use_row_buffer)
        or a
        jr z,.direct_row
        ld a,(copy_sy)
        out (YPORT),a
        ld hl,(copy_src_addr)
        ld de,row_buffer
        ld bc,(copy_w)
        ldir
        ld hl,row_buffer
        ld de,(copy_dst_addr)
        call copy_cpu_row
        jr .next_row
.direct_row:
        ld hl,(copy_src_addr)
        ld de,(copy_dst_addr)
        call copy_direct_row
.next_row:
        ld a,(copy_row_step)
        ld b,a
        ld a,(copy_sy)
        add a,b
        ld (copy_sy),a
        ld a,(copy_dy)
        add a,b
        ld (copy_dy),a
        ld hl,(copy_rows)
        dec hl
        ld (copy_rows),hl
        ld a,(copy_chunk_rows)
        dec a
        ld (copy_chunk_rows),a
        jr nz,.row
        ret

; HL=source mirror, DE=destination, width from copy_w.
copy_direct_row:
        ld a,(copy_w+1)
        or a
        jr nz,.wide
        ld a,(copy_w)
        cp 161
        jr c,copy_direct_chunk
.wide:
        ld a,160
        call copy_direct_chunk
        ld bc,160
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,(copy_w)
        ld a,c
        sub 160
        jp copy_direct_chunk

; Direct copies run entirely inside the single PORT_Y row selected before the
; command (copy_rect_prepare guarantees copy_sy == copy_dy here).  The source
; read and the triggering write must stay adjacent: the accelerator latches
; its source from the last read before the write, so any interleaved memory
; read or I/O re-latches the source and corrupts the whole block.
copy_direct_chunk:
        ld (copy_direct_size+1),a
        ld a,(copy_sy)
        out (YPORT),a
        ACC_SET_SIZE
copy_direct_size:
        ld a,0
        ACC_COPY_H
        ld a,(hl)
        ld (de),a
        ACC_OFF
        ret

; HL=ordinary CPU buffer, DE=VRAM destination.
copy_cpu_row:
        ld a,(copy_w+1)
        or a
        jr nz,.wide
        ld a,(copy_w)
        cp 161
        jr c,copy_cpu_chunk
.wide:
        ld a,160
        call copy_cpu_chunk
        ld bc,160
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,(copy_w)
        ld a,c
        sub 160
        jp copy_cpu_chunk

copy_cpu_chunk:
        ld (copy_cpu_size+1),a
        ld a,(copy_dy)
        out (YPORT),a
        ACC_SET_SIZE
copy_cpu_size:
        ld a,0
        ACC_COPY_H
        ld a,(hl)
        ld (de),a
        ACC_OFF
        ret

; ---- additional primitives -------------------------------------------------

; DE -> GfxDrawRect, identical layout to GfxFillRect.
gfx_draw_rect:
        ld a,(de)
        ld (draw_x),a
        inc de
        ld a,(de)
        ld (draw_x+1),a
        inc de
        ld a,(de)
        ld (draw_y),a
        inc de
        ld a,(de)
        ld (draw_w),a
        inc de
        ld a,(de)
        ld (draw_w+1),a
        inc de
        ld a,(de)
        ld (draw_h),a
        inc de
        ld a,(de)
        ld (draw_h+1),a
        inc de
        ld a,(de)
        ld (pixel_color),a
        inc de
        ld a,(de)
        ld b,a
        ld (pixel_flags),a
        inc de
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        or c
        ld c,a
        inc de
        ld a,(de)
        or c
        jr nz,.bad_reserved
        ld a,(pixel_color)
        cp 16
        jr nc,.bad_reserved
        call expand_color
        ld (fill_color),a
        ld a,(pixel_flags)
        call reject_solid_key
        or a
        ret nz
        ld a,(pixel_flags)
        call resolve_target
        or a
        ret nz
        call draw_load_original_rect
        call validate_rect_alignment
        or a
        ret nz
        call rect_is_empty
        or a
        ret z
        call validate_rect
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        call draw_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.bad_reserved:
        ld a,ERR_ARGUMENT
        ret

draw_load_original_rect:
        ld hl,(draw_x)
        ld (rect_x),hl
        ld a,(draw_y)
        ld (rect_y),a
        ld hl,(draw_w)
        ld (rect_w),hl
        ld hl,(draw_h)
        ld (rect_h),hl
        ret

draw_rect_mapped:
        ; top edge
        call draw_load_original_rect
        call rect_pixels_to_bytes
        ld hl,1
        ld (rect_h),hl
        call fill_rect_mapped
        ld hl,(draw_h)
        dec hl
        ld a,h
        or l
        ret z                       ; height=1 consists only of the top edge
        ; bottom edge
        call draw_load_original_rect
        call rect_pixels_to_bytes
        ld hl,(draw_h)
        dec hl
        ld a,(draw_y)
        add a,l
        ld (rect_y),a
        ld hl,1
        ld (rect_h),hl
        call fill_rect_mapped
        ld hl,(draw_h)
        ld de,2
        or a
        sbc hl,de
        ret z                       ; height=2 consists only of top and bottom
        ; Pixel-wide sides excluding corners use nibble read-modify-write.
        ld a,(pixel_color)
        ld (fill_color),a
        ld a,(draw_y)
        inc a
        ld (line_y),a
        ld hl,(draw_h)
        dec hl
        dec hl
        ld (line_count),hl
        ld hl,(draw_w)
        dec hl
        ld de,(draw_x)
        add hl,de
        ld (line_x1),hl
.side: ld hl,(draw_x)
        ld a,(line_y)
        call pixel_write_mapped
        ld hl,(line_x1)
        ld a,(line_y)
        call pixel_write_mapped
        ld a,(line_y)
        inc a
        ld (line_y),a
        ld hl,(line_count)
        dec hl
        ld (line_count),hl
        ld a,h
        or l
        jr nz,.side
        ret

; IX=x, IYH=0, IYL=y, A=color, E=flags.
gfx_put_pixel:
        cp 16
        jr nc,.bad
        ld (pixel_color),a
        ld a,e
        ld (pixel_flags),a
        ld a,iyh
        or a
        jr nz,.bad
        push ix
        pop hl
        ld de,640
        or a
        sbc hl,de
        jr nc,.bad
        ld a,(pixel_flags)
        call resolve_target
        or a
        ret nz
        ld a,(op_flags)
        bit 3,a
        jr z,.map
        ld a,(pixel_color)
        cp 15
        jr nz,.map
        xor a                      ; KEY_FF colour 15 is a successful no-op
        ret
.map:
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        push ix
        pop hl
        ld a,(pixel_color)
        ld (fill_color),a
        ld a,iyl
        call pixel_write_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; IX=x, IYH=0, IYL=y, E=source. Returns E=color.
gfx_get_pixel:
        ld a,e
        ld (pixel_flags),a
        ld a,iyh
        or a
        jr nz,.bad
        push ix
        pop hl
        ld de,640
        or a
        sbc hl,de
        jr nc,.bad
        ld a,(pixel_flags)
        call resolve_source
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        ld a,VIDEO_PAGE
        ld (vram_alias),a
        call enter_di
        call map_vram
        push ix
        pop hl
        ld b,0
        bit 0,l
        jr z,.parity_ready
        inc b
.parity_ready:
        srl h
        rr l
        ld de,(source_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ld a,iyl
        out (YPORT),a
        ld a,(hl)
        ld c,a
        ld a,b
        or a
        ld a,c
        jr nz,.low
        rrca
        rrca
        rrca
        rrca
.low:  and #0f
        ld (pixel_color),a
        call unmap_vram
        call leave_di
        ld a,(pixel_color)
        ld e,a
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; DE -> GfxLine: x0,y0,x1,y1,color,flags.
gfx_line:
        ld a,(de)
        ld (line_x0),a
        inc de
        ld a,(de)
        ld (line_x0+1),a
        inc de
        ld a,(de)
        ld (line_y0),a
        inc de
        ld a,(de)
        ld (line_x1),a
        inc de
        ld a,(de)
        ld (line_x1+1),a
        inc de
        ld a,(de)
        ld (line_y1),a
        inc de
        ld a,(de)
        ld (fill_color),a
        inc de
        ld a,(de)
        ld (pixel_flags),a
        ld a,(fill_color)
        cp 16
        jr nc,.bad
        ld a,(pixel_flags)
        call reject_solid_key
        or a
        ret nz
        ld a,(pixel_flags)
        call resolve_target
        or a
        ret nz
        ld hl,(line_x0)
        call validate_x
        or a
        ret nz
        ld hl,(line_x1)
        call validate_x
        or a
        ret nz
        call line_prepare
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        ld hl,(line_dy)
        ld de,(line_dx)
        or a
        sbc hl,de
        jr nc,.y_major
        call line_x_major
        jr .done
.y_major:
        call line_y_major
.done:
        call unmap_vram
        call leave_di
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

validate_x:
        ld de,640
        or a
        sbc hl,de
        jr nc,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

line_prepare:
        ld hl,(line_x0)
        ld (line_cur_x),hl
        ld a,(line_y0)
        ld (line_cur_y),a
        ld hl,(line_x1)
        ld de,(line_x0)
        or a
        sbc hl,de
        jr c,.x_negative
        ld (line_dx),hl
        ld hl,1
        ld (line_sx),hl
        jr .y
.x_negative:
        ld hl,(line_x0)
        ld de,(line_x1)
        or a
        sbc hl,de
        ld (line_dx),hl
        ld hl,#ffff
        ld (line_sx),hl
.y:
        ld a,(line_y1)
        ld b,a
        ld a,(line_y0)
        cp b
        jr c,.y_positive
        jr z,.y_zero
        sub b
        ld l,a
        ld h,0
        ld (line_dy),hl
        ld a,#ff
        ld (line_sy),a
        ret
.y_positive:
        ld a,b
        ld c,a
        ld a,(line_y0)
        ld b,a
        ld a,c
        sub b
        ld l,a
        ld h,0
        ld (line_dy),hl
        ld a,1
        ld (line_sy),a
        ret
.y_zero:
        ld hl,0
        ld (line_dy),hl
        ld a,1
        ld (line_sy),a
        ret

line_x_major:
        ld hl,(line_dx)
        inc hl
        ld (line_count),hl
        dec hl
        srl h
        rr l
        ld (line_error),hl
.loop:
        call line_plot
        ld hl,(line_count)
        dec hl
        ld (line_count),hl
        ld a,h
        or l
        ret z
        ld hl,(line_cur_x)
        ld de,(line_sx)
        add hl,de
        ld (line_cur_x),hl
        ld hl,(line_error)
        ld de,(line_dy)
        or a
        sbc hl,de
        jr nc,.store_error
        ld de,(line_dx)
        add hl,de
        ld a,(line_cur_y)
        ld b,a
        ld a,(line_sy)
        add a,b
        ld (line_cur_y),a
.store_error:
        ld (line_error),hl
        jr .loop

line_y_major:
        ld hl,(line_dy)
        inc hl
        ld (line_count),hl
        dec hl
        srl h
        rr l
        ld (line_error),hl
.loop:
        call line_plot
        ld hl,(line_count)
        dec hl
        ld (line_count),hl
        ld a,h
        or l
        ret z
        ld a,(line_cur_y)
        ld b,a
        ld a,(line_sy)
        add a,b
        ld (line_cur_y),a
        ld hl,(line_error)
        ld de,(line_dx)
        or a
        sbc hl,de
        jr nc,.store_error
        ld de,(line_dy)
        add hl,de
        ld de,(line_sx)
        push hl
        ld hl,(line_cur_x)
        add hl,de
        ld (line_cur_x),hl
        pop hl
.store_error:
        ld (line_error),hl
        jr .loop

line_plot:
        ld hl,(line_cur_x)
        ld a,(line_cur_y)
        jp pixel_write_mapped

; DE -> GfxScrollRect (16-byte packed descriptor).
gfx_scroll_rect:
        ld a,(de)
        ld (scroll_x),a
        inc de
        ld a,(de)
        ld (scroll_x+1),a
        inc de
        ld a,(de)
        ld (scroll_y),a
        inc de
        ld a,(de)
        ld (scroll_w),a
        inc de
        ld a,(de)
        ld (scroll_w+1),a
        inc de
        ld a,(de)
        ld (scroll_h),a
        inc de
        ld a,(de)
        ld (scroll_h+1),a
        inc de
        ld a,(de)
        ld (scroll_dx),a
        inc de
        ld a,(de)
        ld (scroll_dx+1),a
        inc de
        ld a,(de)
        ld (scroll_dy),a
        inc de
        ld a,(de)
        ld (scroll_dy+1),a
        inc de
        ld a,(de)
        ld (scroll_fill),a
        inc de
        ld a,(de)
        ld (scroll_flags),a
        inc de
        ld a,(de)
        ld b,a
        inc de
        ld a,(de)
        or b
        ld b,a
        inc de
        ld a,(de)
        or b
        jp nz,.bad
        ld a,(scroll_fill)
        cp 16
        jp nc,.bad
        ld a,(scroll_flags)
        call reject_solid_key
        or a
        ret nz
        ld a,(scroll_x)
        bit 0,a
        jp nz,.bad
        ld a,(scroll_w)
        bit 0,a
        jp nz,.bad
        ld a,(scroll_dx)
        bit 0,a
        jp nz,.bad
        ld hl,(scroll_x)
        ld (rect_x),hl
        ld a,(scroll_y)
        ld (rect_y),a
        ld hl,(scroll_w)
        ld (rect_w),hl
        ld hl,(scroll_h)
        ld (rect_h),hl
        call rect_is_empty
        or a
        ret z
        call validate_rect
        or a
        ret nz
        ld a,(scroll_flags)
        call resolve_target
        or a
        ret nz
        ld hl,(scroll_dx)
        call signed_abs
        ld (scroll_abs_dx),hl
        ld a,(signed_negative)
        ld (scroll_dx_negative),a
        ld hl,(scroll_dy)
        call signed_abs
        ld (scroll_abs_dy),hl
        ld a,(signed_negative)
        ld (scroll_dy_negative),a
        ld hl,(scroll_abs_dx)
        ld de,(scroll_w)
        call unsigned_lt
        jr nz,.fill_all
        ld hl,(scroll_abs_dy)
        ld de,(scroll_h)
        call unsigned_lt
        jr nz,.fill_all
        call scroll_prepare_copy
        ld hl,(copy_w)
        ld a,h
        or l
        jr z,.fill_strips
        ld hl,(copy_h)
        ld a,h
        or l
        jr z,.fill_strips
        call copy_rect_core
        or a
        ret nz
.fill_strips:
        call scroll_fill_vertical_strip
        or a
        ret nz
        jp scroll_fill_horizontal_strip
.fill_all:
        ld hl,(scroll_x)
        ld (rect_x),hl
        ld a,(scroll_y)
        ld (rect_y),a
        ld hl,(scroll_w)
        ld (rect_w),hl
        ld hl,(scroll_h)
        ld (rect_h),hl
        jp scroll_fill_current_rect
.bad:  ld a,ERR_ARGUMENT
        ret

; HL signed -> absolute HL, signed_negative=1 for negative.
signed_abs:
        xor a
        ld (signed_negative),a
        bit 7,h
        ret z
        ld a,1
        ld (signed_negative),a
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        ret

; NZ means HL >= DE; Z means HL < DE.
unsigned_lt:
        or a
        sbc hl,de
        jr c,.less
        ld a,1
        or a
        ret
.less: xor a
        ret

scroll_prepare_copy:
        ld a,(scroll_flags)
        and 3
        ld (copy_source_id),a
        ld a,(scroll_flags)
        ld (copy_flags),a
        ld a,1
        ld (copy_require_same),a
        ld hl,(scroll_w)
        ld de,(scroll_abs_dx)
        or a
        sbc hl,de
        ld (copy_w),hl
        ld hl,(scroll_h)
        ld de,(scroll_abs_dy)
        or a
        sbc hl,de
        ld (copy_h),hl
        ld hl,(scroll_x)
        ld (copy_sx),hl
        ld (copy_dx),hl
        ld a,(scroll_y)
        ld (copy_sy),a
        ld (copy_dy),a
        ld hl,(scroll_abs_dx)
        ld a,h
        or l
        jr z,.vertical
        ld a,(scroll_dx_negative)
        or a
        jr z,.dest_right
        ld de,(scroll_x)
        add hl,de
        ld (copy_sx),hl
        jr .vertical
.dest_right:
        ld de,(scroll_x)
        add hl,de
        ld (copy_dx),hl
.vertical:
        ld hl,(scroll_abs_dy)
        ld a,h
        or l
        ret z
        ld a,h
        or a
        ret nz                     ; only reached when abs(dy)<height<=256
        ld b,l
        ld a,(scroll_dy_negative)
        or a
        jr z,.dest_down
        ld a,(scroll_y)
        add a,b
        ld (copy_sy),a
        ret
.dest_down:
        ld a,(scroll_y)
        add a,b
        ld (copy_dy),a
        ret

scroll_fill_vertical_strip:
        ld hl,(scroll_abs_dy)
        ld a,h
        or l
        ret z
        ld hl,(scroll_x)
        ld (rect_x),hl
        ld hl,(scroll_w)
        ld (rect_w),hl
        ld hl,(scroll_abs_dy)
        ld (rect_h),hl
        ld a,(scroll_dy_negative)
        or a
        ld a,(scroll_y)
        jr z,.top
        ld hl,(scroll_h)
        ld de,(scroll_abs_dy)
        or a
        sbc hl,de
        add a,l
.top:  ld (rect_y),a
        jp scroll_fill_current_rect

scroll_fill_horizontal_strip:
        ld hl,(scroll_abs_dx)
        ld a,h
        or l
        ret z
        ld hl,(scroll_abs_dx)
        ld (rect_w),hl
        ld hl,(scroll_h)
        ld (rect_h),hl
        ld a,(scroll_y)
        ld (rect_y),a
        ld a,(scroll_dx_negative)
        or a
        jr z,.left
        ld hl,(scroll_w)
        ld de,(scroll_abs_dx)
        or a
        sbc hl,de
        ld de,(scroll_x)
        add hl,de
        ld (rect_x),hl
        jr scroll_fill_current_rect
.left: ld hl,(scroll_x)
        ld (rect_x),hl

scroll_fill_current_rect:
        ld a,(scroll_fill)
        call expand_color
        ld (fill_color),a
        ld a,(scroll_flags)
        call resolve_target
        or a
        ret nz
        call rect_pixels_to_bytes
        call check_vram_window
        or a
        ret nz
        call enter_di
        call map_vram
        call fill_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret

; ---- 16x32 packed-4bpp row-major tiles -------------------------------------
; DE TileRef: D logical page, E slot. IX=x, IYH=0, IYL=y, A flags.
gfx_draw_tile:
        call tile_prefetch_safe
        or a
        ret nz
        jp draw_tile_prefetched

gfx_draw_tile_fast:
        call tile_prefetch_fast
        jp draw_tile_prefetched

gfx_draw_tile_clip:
        call tile_prefetch_clip
        or a
        ret nz
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        ld a,8
        ld (tile_draw_width),a
        ld a,32
        ld (tile_draw_rows),a
        ld hl,640
        ld de,(tile_x)
        or a
        sbc hl,de
        srl h
        rr l
        ld a,h
        or a
        jr nz,.vertical_clip
        ld a,l
        cp 9
        jr nc,.vertical_clip
.store_width:
        ld (tile_draw_width),a
.vertical_clip:
        ld a,(tile_y)
        cp 225
        jr c,.draw
        neg                         ; 256-y, valid for y=225..255
        ld (tile_draw_rows),a
.draw:  jp draw_tile_sized_target_ready

tile_prefetch_safe:
        ld (tile_flags),a
        ld a,(page_table_valid)
        or a
        jr z,.page
        ld a,e
        cp 64
        jr nc,.tile
        ld a,(page_count)
        or a
        jr z,.full_table
        ld a,d
        ld b,a
        ld a,(page_count)
        cp b
        jr c,.page
        jr z,.page
        jr .have
.full_table:
        ; A zero count is the internal representation of a 256-entry table.
.have:
        call tile_prefetch_no_flags
        push ix
        pop hl
        bit 0,l
        jr nz,.bad
        ld de,625                 ; x<=624 is the last full 16-pixel tile
        or a
        sbc hl,de
        jr nc,.bad
.x_ok:
        ld a,iyh
        or a
        jr nz,.bad
        ld a,iyl
        cp 225
        jr nc,.bad
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret
.page:  ld a,ERR_PAGE
        ret
.tile:  ld a,ERR_TILE
        ret

tile_prefetch_clip:
        ld (tile_flags),a
        ld a,(page_table_valid)
        or a
        jr z,.page
        ld a,e
        cp 64
        jr nc,.tile
        ld a,(page_count)
        or a
        jr z,.page_ok
        ld a,d
        ld b,a
        ld a,(page_count)
        cp b
        jr c,.page
        jr z,.page
.page_ok:
        call tile_prefetch_no_flags
        push ix
        pop hl
        bit 0,l
        jr nz,.bad
        ld de,640
        or a
        sbc hl,de
        jr nc,.bad
.y:    ld a,iyh
        or a
        jr nz,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret
.page: ld a,ERR_PAGE
        ret
.tile: ld a,ERR_TILE
        ret

tile_prefetch_fast:
        ld (tile_flags),a
tile_prefetch_no_flags:
        ld a,e
        ld (tile_slot),a
        ld (tile_x),ix
        ld a,iyl
        ld (tile_y),a
        ld a,d
        ld e,a
        ld d,0
        ld hl,page_table
        add hl,de
        ld a,(hl)
        ld (tile_page),a
        xor a
        ret

; Draw uses only prefetched state. Source is mapped into WIN0 while DI is held.
draw_tile_prefetched:
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        ; Fall through only after destination/alias have been resolved.  Batch
        ; entries use this shared target state and skip the repeated resolver.
draw_tile_target_ready:
        ld a,8
        ld (tile_draw_width),a
        ld a,32
        ld (tile_draw_rows),a
draw_tile_sized_target_ready:
        call check_tile_windows
        or a
        ret nz
        ld a,(tile_draw_width)
        ld (.copy_size+1),a
        call enter_di
        in a,(PAGEPORT0)
        ld (saved_win0_page),a
        ld a,(tile_page)
        out (PAGEPORT0),a
        call map_vram
        ld hl,(tile_x)
        srl h
        rr l
        ld a,(tile_y)
        call make_dest
        ex de,hl                  ; DE=destination column in VRAM
        ld a,(tile_slot)
        ld h,a
        ld l,0                    ; HL=WIN0 + slot*256 source
        ld a,(tile_y)
        ld c,a
        ld a,(tile_draw_rows)
        ld b,a
.row:   ld a,c
        out (YPORT),a
        ; OFF ends the previous command, therefore the 8-byte block size
        ; must be latched again for every row (proven spevosdk sequence).
        ld d,d
.copy_size:
        ld a,8
        ld l,l
        ld a,(hl)
        ld (de),a
        ld b,b                    ; mandatory completion/idle
        ld a,l
        add a,8                   ; next 8-byte packed row
        ld l,a
        inc c
        djnz .row
        call unmap_vram
        ld a,(saved_win0_page)
        out (PAGEPORT0),a
        call leave_di
        xor a
        ret

; Span descriptor: TileRef*, count, x, y, flags (8 bytes).
gfx_draw_tile_span:
        ld a,(de)
        ld (batch_ptr),a
        inc de
        ld a,(de)
        ld (batch_ptr+1),a
        inc de
        ld a,(de)
        ld (batch_count),a
        inc de
        ld a,(de)
        ld (batch_count+1),a
        inc de
        ld a,(de)
        ld (tile_x),a
        inc de
        ld a,(de)
        ld (tile_x+1),a
        inc de
        ld a,(de)
        ld (tile_y),a
        inc de
        ld a,(de)
        ld (tile_flags),a
        ld a,(tile_x)
        bit 0,a
        jr nz,.bad
        ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
        ; A 16-pixel span can contain at most 40 whole tiles in 640 pixels.
        ld a,h
        or a
        jr nz,.bad
        ld a,l
        cp 41
        jr nc,.bad
        ld a,(tile_y)
        cp 225
        jr nc,.bad
        ld hl,(batch_count)
        add hl,hl
        ld de,(batch_ptr)
        add hl,de
        jr c,.bad                 ; TileRef array must not wrap address space
        ld hl,(batch_count)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                  ; count * 16
        ld de,(tile_x)
        add hl,de
        ld de,641
        or a
        sbc hl,de
        jr nc,.bad                 ; x + count*16 <= 640
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        xor a
        ld (batch_page_valid),a
        jp draw_span_loop
.bad:   ld a,ERR_ARGUMENT
        ret

; List descriptor: item*, count, common flags, reserved[3]; item=TileRef,x,y.
gfx_draw_tile_list:
        ld a,(de)
        ld (batch_ptr),a
        inc de
        ld a,(de)
        ld (batch_ptr+1),a
        inc de
        ld a,(de)
        ld (batch_count),a
        inc de
        ld a,(de)
        ld (batch_count+1),a
        inc de
        ld a,(de)
        ld (tile_flags),a
        inc de
        ld a,(de)
        ld b,a
        inc de
        ld a,(de)
        or b
        ld b,a
        inc de
        ld a,(de)
        or b
        jr nz,.bad
        ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
        ld hl,(batch_count)
        ld de,5
        call mul16_checked
        or a
        ret nz
        ld de,(batch_ptr)
        add hl,de
        jr c,.bad                 ; item array must remain resident/contiguous
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        xor a
        ld (batch_page_valid),a
.next:  ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
        ld hl,(batch_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (tile_x),a
        inc hl
        ld a,(hl)
        ld (tile_x+1),a
        inc hl
        ld a,(hl)
        ld (tile_y),a
        inc hl
        ld (batch_ptr),hl
        call batch_prefetch_safe
        or a
        ret nz
        call draw_tile_target_ready
        or a
        ret nz
        ld hl,(batch_count)
        dec hl
        ld (batch_count),hl
        jr .next
.bad:  ld a,ERR_ARGUMENT
        ret
gfx_batch_done:
        xor a
        ret

draw_span_loop:
        ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
        ld hl,(batch_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (batch_ptr),hl
        call batch_prefetch_safe
        or a
        ret nz
        call draw_tile_target_ready
        or a
        ret nz
        ld hl,(tile_x)
        ld de,16
        add hl,de
        ld (tile_x),hl
        ld hl,(batch_count)
        dec hl
        ld (batch_count),hl
        jr draw_span_loop

; DE -> GfxTilemap (20-byte packed descriptor).
gfx_draw_tilemap:
        ld a,(de)
        ld (grid_base_ptr),a
        inc de
        ld a,(de)
        ld (grid_base_ptr+1),a
        inc de
        ld a,(de)
        ld (map_width),a
        inc de
        ld a,(de)
        ld (map_width+1),a
        inc de
        ld a,(de)
        ld (map_height),a
        inc de
        ld a,(de)
        ld (map_height+1),a
        inc de
        ld a,(de)
        ld (map_source_x),a
        inc de
        ld a,(de)
        ld (map_source_x+1),a
        inc de
        ld a,(de)
        ld (map_source_y),a
        inc de
        ld a,(de)
        ld (map_source_y+1),a
        inc de
        ld a,(de)
        ld (grid_cols),a
        inc de
        ld a,(de)
        ld (grid_cols+1),a
        inc de
        ld a,(de)
        ld (grid_rows),a
        inc de
        ld a,(de)
        ld (grid_rows+1),a
        inc de
        ld a,(de)
        ld (grid_x),a
        inc de
        ld a,(de)
        ld (grid_x+1),a
        inc de
        ld a,(de)
        ld (grid_y),a
        inc de
        ld a,(de)
        ld (tile_flags),a
        inc de
        ld a,(de)
        ld b,a
        inc de
        ld a,(de)
        or b
        jr nz,.bad
        ld a,(grid_x)
        bit 0,a
        jr nz,.bad
        call grid_empty
        ret z
        call validate_tilemap
        or a
        ret nz
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        xor a
        ld (batch_page_valid),a
        jp draw_grid
.bad:  ld a,ERR_ARGUMENT
        ret

; DE -> GfxMetatile (8-byte packed descriptor).
gfx_draw_metatile:
        ld a,(de)
        ld (grid_base_ptr),a
        inc de
        ld a,(de)
        ld (grid_base_ptr+1),a
        inc de
        ld a,(de)
        ld (grid_cols),a
        xor a
        ld (grid_cols+1),a
        inc de
        ld a,(de)
        ld (grid_rows),a
        xor a
        ld (grid_rows+1),a
        inc de
        ld a,(de)
        ld (grid_x),a
        inc de
        ld a,(de)
        ld (grid_x+1),a
        inc de
        ld a,(de)
        ld (grid_y),a
        inc de
        ld a,(de)
        ld (tile_flags),a
        ld a,(grid_x)
        bit 0,a
        jr nz,.bad
        call grid_empty
        ret z
        call validate_grid_destination
        or a
        ret nz
        ld hl,(grid_cols)
        add hl,hl
        ld (grid_row_stride),hl
        ld hl,(grid_cols)
        ld de,(grid_rows)
        call mul16_checked
        or a
        ret nz
        add hl,hl
        jr c,.bad
        ld de,(grid_base_ptr)
        add hl,de
        jr c,.bad
        ld a,(tile_flags)
        call resolve_target
        or a
        ret nz
        ld hl,(grid_base_ptr)
        ld (grid_ptr),hl
        xor a
        ld (batch_page_valid),a
        jp draw_grid
.bad:  ld a,ERR_ARGUMENT
        ret

grid_empty:
        ld hl,(grid_cols)
        ld a,h
        or l
        ret z
        ld hl,(grid_rows)
        ld a,h
        or l
        ret

validate_tilemap:
        ld hl,(map_width)
        ld a,h
        or l
        jp z,.bad
        ld hl,(map_height)
        ld a,h
        or l
        jp z,.bad
        ; source_x + draw_width <= map_width
        ld hl,(map_source_x)
        ld de,(grid_cols)
        add hl,de
        jr c,.bad
        ld de,(map_width)
        call unsigned_le
        jr nz,.bad
        ; source_y + draw_height <= map_height
        ld hl,(map_source_y)
        ld de,(grid_rows)
        add hl,de
        jr c,.bad
        ld de,(map_height)
        call unsigned_le
        jr nz,.bad
        call validate_grid_destination
        or a
        ret nz
        ; row stride is map_width*2 bytes.
        ld hl,(map_width)
        add hl,hl
        jr c,.bad
        ld (grid_row_stride),hl
        ; Compute first TileRef pointer with checked 16-bit multiplication.
        ld hl,(map_width)
        ld de,(map_source_y)
        call mul16_checked
        or a
        ret nz
        ld de,(map_source_x)
        add hl,de
        jr c,.bad
        add hl,hl
        jr c,.bad
        ld de,(grid_base_ptr)
        add hl,de
        jr c,.bad
        ld (grid_ptr),hl
        ; Preflight the end-exclusive address of the last selected row.
        ld hl,(map_source_y)
        ld de,(grid_rows)
        add hl,de
        dec hl
        ex de,hl
        ld hl,(map_width)
        call mul16_checked
        or a
        ret nz
        ld de,(map_source_x)
        add hl,de
        jr c,.bad
        ld de,(grid_cols)
        add hl,de
        jr c,.bad
        add hl,hl
        jr c,.bad
        ld de,(grid_base_ptr)
        add hl,de
        jr c,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

validate_grid_destination:
        ld hl,(grid_cols)
        ld a,h
        or a
        jr nz,.bad
        ld a,l
        cp 41
        jr nc,.bad
        ld a,(grid_x)
        bit 0,a
        jr nz,.bad
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(grid_x)
        add hl,de
        jr c,.bad
        ld de,641
        or a
        sbc hl,de
        jr nc,.bad
        ld hl,(grid_rows)
        ld a,h
        or a
        jr nz,.bad
        ld a,l
        cp 9
        jr nc,.bad
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(grid_y)
        ld e,a
        ld d,0
        add hl,de
        ld de,257
        or a
        sbc hl,de
        jr nc,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; Z means HL <= DE, NZ means HL > DE.
unsigned_le:
        or a
        sbc hl,de
        jr c,.yes
        ret z
        ld a,1
        or a
        ret
.yes:  xor a
        ret

; HL*DE -> HL. Returns ERR_ARGUMENT on a product above #FFFF.
mul16_checked:
        ld b,h
        ld c,l                    ; BC=multiplicand
        ld hl,0                   ; result
        xor a
        ld (mul_overflow),a
        ld a,16
        ld (mul_bits),a
.loop:
        bit 0,e
        jr z,.no_add
        add hl,bc
        jr nc,.no_add
        ld a,1
        ld (mul_overflow),a
.no_add:
        srl d
        rr e
        sla c
        rl b
        jr nc,.shift_ok
        ld a,d
        or e
        jr z,.shift_ok
        ld a,1
        ld (mul_overflow),a
.shift_ok:
        ld a,(mul_bits)
        dec a
        ld (mul_bits),a
        jr nz,.loop
        ld a,(mul_overflow)
        or a
        jr nz,.bad
        xor a
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; Draw a validated rectangular grid of complete tiles.
draw_grid:
        ld hl,(grid_ptr)
        ld (grid_row_ptr),hl
        ld hl,(grid_rows)
        ld (grid_rows_left),hl
        ld a,(grid_y)
        ld (tile_y),a
.row:
        ld hl,(grid_row_ptr)
        ld (batch_ptr),hl
        ld hl,(grid_cols)
        ld (grid_cols_left),hl
        ld hl,(grid_x)
        ld (tile_x),hl
.column:
        ld hl,(batch_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (batch_ptr),hl
        call batch_prefetch_safe
        or a
        ret nz
        call draw_tile_target_ready
        or a
        ret nz
        ld hl,(tile_x)
        ld de,16
        add hl,de
        ld (tile_x),hl
        ld hl,(grid_cols_left)
        dec hl
        ld (grid_cols_left),hl
        ld a,h
        or l
        jr nz,.column
        ld hl,(grid_rows_left)
        dec hl
        ld (grid_rows_left),hl
        ld a,h
        or l
        ret z
        ld hl,(grid_row_ptr)
        ld de,(grid_row_stride)
        add hl,de
        jr c,.argument
        ld (grid_row_ptr),hl
        ld a,(tile_y)
        add a,32
        ld (tile_y),a
        jr .row
.argument:
        ld a,ERR_ARGUMENT
        ret

; Safe TileRef resolution for span/list.  A successful lookup is cached by
; logical page; WIN0 is mapped and restored only by the following per-tile
; draw step, keeping each DI section bounded and ISR-safe between elements.
batch_prefetch_safe:
        ld a,d
        ld b,a                    ; preserve logical page across X arithmetic
        ld a,e
        cp 64
        jr nc,.tile
        ld (tile_slot),a
        ld hl,(tile_x)
        bit 0,l
        jr nz,.arg
        ld de,625
        or a
        sbc hl,de
        jr nc,.arg
.x_ok:
        ld a,(tile_y)
        cp 225
        jr nc,.arg
        ld a,(page_table_valid)
        or a
        jr z,.page
        ld a,(page_count)
        or a
        jr z,.page_ok
        cp b
        jr c,.page
        jr z,.page
.page_ok:
        ld a,(batch_page_valid)
        or a
        jr z,.lookup
        ld a,(batch_logical_page)
        cp b
        jr z,.cached
.lookup:
        ld a,b
        ld (batch_logical_page),a
        ld e,a
        ld d,0
        ld hl,page_table
        add hl,de
        ld a,(hl)
        ld (tile_page),a
        ld a,1
        ld (batch_page_valid),a
.cached:
        xor a
        ret
.arg:   ld a,ERR_ARGUMENT
        ret
.page:  ld a,ERR_PAGE
        ret
.tile:  ld a,ERR_TILE
        ret

; ---- state -----------------------------------------------------------------
code_window:    db 0
stack_window:   db 0
initialized:    db 0
vram_window:    db 1
vram_port:      db #a2
restore_ei:     db 0
saved_vram_page: db 0
saved_win0_page: db 0
vram_alias:     db VIDEO_PAGE
op_flags:       db 0
vram_base:      dw #4000
dest_buffer:    dw 0
fill_color:     db 0
rect_x:         dw 0
rect_y:         db 0
rect_w:         dw 0
rect_h:         dw 0
line_y:         db 0
page_count:     db 0
page_table_valid: db 0
page_table:     ds 256
tile_page:      db 0
tile_slot:      db 0
tile_x:         dw 0
tile_y:         db 0
tile_flags:     db 0
tile_draw_width: db 16
tile_draw_rows: db 16
batch_ptr:      dw 0
batch_count:    dw 0
batch_page_valid: db 0
batch_logical_page: db 0

grid_base_ptr:  dw 0
grid_ptr:       dw 0
grid_row_ptr:   dw 0
grid_row_stride: dw 0
grid_cols:      dw 0
grid_rows:      dw 0
grid_cols_left: dw 0
grid_rows_left: dw 0
grid_x:         dw 0
grid_y:         db 0
map_width:      dw 0
map_height:     dw 0
map_source_x:   dw 0
map_source_y:   dw 0
mul_bits:       db 0
mul_overflow:   db 0

source_buffer:  dw 0
copy_source_id: db 0
copy_flags:     db 0
copy_sx:        dw 0
copy_sy:        db 0
copy_dx:        dw 0
copy_dy:        db 0
copy_w:         dw 0
copy_h:         dw 0
copy_rows:      dw 0
copy_src_addr:  dw 0
copy_dst_addr:  dw 0
copy_row_step:  db 1
copy_use_row_buffer: db 0
copy_require_same: db 0
copy_chunk_rows: db 0

draw_x:         dw 0
draw_y:         db 0
draw_w:         dw 0
draw_h:         dw 0
pixel_color:    db 0
pixel_flags:    db 0
line_x0:        dw 0
line_y0:        db 0
line_x1:        dw 0
line_y1:        db 0
line_cur_x:     dw 0
line_cur_y:     db 0
line_dx:        dw 0
line_dy:        dw 0
line_sx:        dw 0
line_sy:        db 0
line_error:     dw 0
line_count:     dw 0

scroll_x:       dw 0
scroll_y:       db 0
scroll_w:       dw 0
scroll_h:       dw 0
scroll_dx:      dw 0
scroll_dy:      dw 0
scroll_abs_dx:  dw 0
scroll_abs_dy:  dw 0
scroll_dx_negative: db 0
scroll_dy_negative: db 0
scroll_fill:    db 0
scroll_flags:   db 0
signed_negative: db 0

pal_mask:       db 0
pal_first:      db 0
pal_index:      db 0
pal_hw_count:   db 0
pal_remaining:  db 0
pal_chunk_count: db 0
pal_entries_left: dw 0
pal_count:      dw 0
pal_copy_len:   dw 0
pal_input:      dw 0
pal_source:     dw 0
pal_rgb:        ds 3
palette_valid:  db 0
palette_level:  db 32
fade_active:    db 0
fade_direction: db 0
fade_duration:  db 0
fade_frames_left: db 0
fade_accumulator: dw 0
fade_palette_mask: db 3
fade_write_pending: db 0

row_buffer:     ds 320
base_palette:   ds 768
palette_lut:    ds 256

config_payload:
        db 16                    ; known structure size
        db #82                   ; required DSS packed-4bpp mode
        dw 640,256
        db 1                     ; vram window (updated by gfx_get_config)
        db 0                     ; source window is fixed WIN0
        db 0                     ; code window (updated by gfx_get_config)
        db 1                     ; GFX_MAPPING_SOURCE_WIN0
        dw #00ff                ; implemented capabilities
        db 16,32
        db 0                     ; GFX_TILE_ROW_MAJOR
        db 0                     ; reserved

        ; An L0 image is mapped through one 16-KiB CPU window.
        assert $-gfx_image_start <= #4000
