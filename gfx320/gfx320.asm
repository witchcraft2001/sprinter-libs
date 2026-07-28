; GFX320.DLL — accelerated primitives and 16x16 row-major tiles for mode #81.
; Public ABI is described in specs.md.  This is the MVP implementation.

        org 0

        db "L0"
        dw 0,0,0,0
        db 28,7
        dw 2026
        dw #0100
        ; L0 dispatch table is fixed at #0020.  Header prefix is 16 bytes,
        ; therefore the encoded name field must occupy exactly 16 bytes.
        db "GFX320 graphics",0

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
        jp gfx_reserved             ; 10 copy_rect
        jp gfx_reserved             ; 11 copy_buffer
        jp gfx_reserved             ; 12 restore_background_rect
        jp gfx_reserved             ; 13 palette_load
        jp gfx_reserved             ; 14 palette_set
        jp gfx_reserved             ; 15 palette_get
        jp gfx_reserved             ; 16 fade_begin
        jp gfx_reserved             ; 17 fade_step
        jp gfx_reserved             ; 18 fade_cancel
        jp gfx_reserved             ; 19
        jp gfx_reserved             ; 20
        jp gfx_reserved             ; 21 swap_buffers
        jp gfx_set_page_table       ; 22
        jp gfx_draw_tile            ; 23
        jp gfx_draw_tile_fast       ; 24
        jp gfx_draw_tile_span       ; 25
        jp gfx_reserved             ; 26 draw_tilemap
        jp gfx_reserved             ; 27 draw_metatile
        jp gfx_reserved             ; 28 draw_rect
        jp gfx_reserved             ; 29 put_pixel
        jp gfx_reserved             ; 30 get_pixel
        jp gfx_reserved             ; 31 line
        jp gfx_reserved             ; 32 move_rect
        jp gfx_reserved             ; 33 scroll_rect
        jp gfx_draw_tile_list       ; 34
        jp gfx_reserved             ; 35 draw_tile_clip

; constants
; Keep these values byte-exact with gfx320.inc and specs.md.  #01..#0f are
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

; ---- core and configuration -------------------------------------------------

gfx_init:
        ; Keep the loader hook side-effect free: libman calls entry 0 while
        ; l_load still owns its mapping state.  The caller selects mode #81
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
        ld ix,#00cf                ; accel, mirror, key, DB, tiles, WIN0 source
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

enter_di:
        ld a,i
        di
        jp po,.off
        ld a,1
        ld (restore_ei),a
        ret
.off:   xor a
        ld (restore_ei),a
        ret

; A = window containing the current stack pointer (0..3).
current_stack_window:
        ld hl,0
        add hl,sp
        ld a,h
        and #c0
        rlca
        rlca
        ret

; Reject mapping VRAM over the current stack.  This is deliberately checked
; immediately before every public drawing operation, not only at gfx_init.
check_vram_window:
        call current_stack_window
        ld b,a
        ld a,(vram_window)
        cp b
        jr z,.bad
        xor a
        ret
.bad:   ld a,ERR_WINDOW
        ret

; A tile operation additionally replaces WIN0.  The implementation contains
; CALL/RET while WIN0 is mapped, so both the DLL code and current stack must
; live outside WIN0 for the duration of the tile loop.
check_tile_windows:
        call check_vram_window
        or a
        ret nz
        ld a,(code_window)
        or a
        jr z,.bad
        call current_stack_window
        or a
        jr z,.bad
        xor a
        ret
.bad:   ld a,ERR_WINDOW
        ret

leave_di:
        ld a,(restore_ei)
        or a
        ret z
        ei
        ret

map_vram:
        ld a,(vram_port)
        ld c,a
        in a,(c)
        ld (saved_vram_page),a
        ld a,(vram_alias)
        out (c),a
        ret

unmap_vram:
        ld a,(vram_port)
        ld c,a
        ld a,(saved_vram_page)
        out (c),a
        ld a,#c0
        out (YPORT),a
        ret

; HL = x, A = y (for the caller's PORT_Y write); outputs CPU VRAM x address.
make_dest:
        ld de,(dest_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ret

; Accelerator horizontal fill. HL address, A count (0=256), fill_color set.
hfill_chunk:
        ld e,a                    ; preserve count while loading the colour
        ld a,(fill_color)
        ld c,a
        ld d,d                    ; SET_BUFFER
        ld a,e
        ld c,c                    ; switch directly from size to FILL_HORZ
        ld a,c
        ld (hl),a
        ld b,b                    ; mandatory completion/idle
        ret

; Accelerator vertical fill. HL=x address, A=y, C=len (0=256).
vfill_chunk:
        out (YPORT),a
        ld a,(fill_color)
        ld e,a                    ; AFNT-compatible fill value register
        ld d,d
        ld a,c
        ld b,b                    ; SET_BUFFER completion
        ld e,e                    ; FILL_VERT; next memory write starts it
        ld (hl),e
        ld b,b                    ; mandatory completion/idle
        ret

; ---- MVP accelerated primitives --------------------------------------------
; A=color, E=destination flags.  Clear uses exactly 320 accelerator V fills.
gfx_clear:
        bit 3,e
        jr nz,gfx_clear_key
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
        xor a                     ; count=0 means 256 rows
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
        ld (fill_color),a
        inc de
        ld a,(de)
        bit 3,a
        jr nz,.key
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
        call fill_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.key:   ld a,ERR_UNSUPPORTED
        scf
        ret

; IX=x, IYH=0, IYL=y, DE: low 9 bits length, high nibble flags, A=color.
gfx_hline:
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
        and 1
        ld (rect_w+1),a
        ld hl,1
        ld (rect_h),hl
        ld a,d
        and #e0
        jr nz,.bad
        ld a,d
        and #1e
        rrca
        bit 3,a
        jr nz,.key
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
        call fill_rect_mapped
        call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.key:   ld a,ERR_UNSUPPORTED
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

; IX=x, IYH=0, IYL=y, DE: low 9 bits length, high nibble flags, A=color.
gfx_vline:
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
        and 1
        ld (rect_h+1),a
        ld a,d
        and #e0
        jr nz,.bad
        ld a,d
        and #1e
        rrca
        bit 3,a
        jr nz,.key
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
        ld hl,(rect_x)
        ld de,(dest_buffer)
        add hl,de
        ld de,(vram_base)
        add hl,de
        ld a,(rect_h+1)
        or a
        jr z,.short
        ; A high byte can only be 1 for a valid height of 256.
        ld a,(rect_y)
        ld c,0
        call vfill_chunk
        jr .done
.short:
        ld a,(rect_h)
        ld c,a
        ld a,(rect_y)
        call vfill_chunk
.done:  call unmap_vram
        call leave_di
        xor a
        ret
.empty: xor a
        ret
.key:   ld a,ERR_UNSUPPORTED
        ret
.bad:   ld a,ERR_ARGUMENT
        ret

validate_rect:
        ld hl,(rect_x)
        ld de,(rect_w)
        add hl,de
        ld de,321
        or a
        sbc hl,de                 ; x+w <= 320
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

; ---- 16x16 row-major tiles -------------------------------------------------
; DE TileRef: D logical page, E slot. IX=x, IYH=0, IYL=y, A flags.
gfx_draw_tile:
        call tile_prefetch_safe
        or a
        ret nz
        jp draw_tile_prefetched

gfx_draw_tile_fast:
        call tile_prefetch_fast
        jp draw_tile_prefetched

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
        ld a,ixh
        cp 2
        jr nc,.bad
        or a
        jr z,.x_ok
        ld a,ixl
        cp 49                     ; X=#0130 (304) is the last full tile
        jr nc,.bad
.x_ok:
        ld a,iyh
        or a
        jr nz,.bad
        ld a,iyl
        cp 241
        jr nc,.bad
        xor a
        ret
.bad:   ld a,ERR_ARGUMENT
        ret
.page:  ld a,ERR_PAGE
        ret
.tile:  ld a,ERR_TILE
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
        call check_tile_windows
        or a
        ret nz
        call enter_di
        in a,(PAGEPORT0)
        ld (saved_win0_page),a
        ld a,(tile_page)
        out (PAGEPORT0),a
        call map_vram
        ld hl,(tile_x)
        ld a,(tile_y)
        call make_dest
        ex de,hl                  ; DE=destination column in VRAM
        ld a,(tile_slot)
        ld h,a
        ld l,0                    ; HL=WIN0 + slot*256 source
        ld a,(tile_y)
        ld c,a
        ld b,16
.row:   ld a,c
        out (YPORT),a
        ; OFF ends the previous command, therefore the 16-byte block size
        ; must be latched again for every row (proven spevosdk sequence).
        ld d,d
        ld a,16
        ld l,l
        ld a,(hl)
        ld (de),a
        ld b,b                    ; mandatory completion/idle
        ld a,l
        add a,16                  ; next 16-byte row in row-major tile
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
        ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
        ; A 16-pixel span can contain at most 20 whole tiles in 320 pixels.
        ld a,h
        or a
        jr nz,.bad
        ld a,l
        cp 21
        jr nc,.bad
        ld a,(tile_y)
        cp 241
        jr nc,.bad
        ld hl,(batch_count)
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                  ; count * 16
        ld de,(tile_x)
        add hl,de
        ld de,321
        or a
        sbc hl,de
        jr nc,.bad                 ; x + count*16 <= 320
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
        ld hl,(batch_count)
        ld a,h
        or l
        jp z,gfx_batch_done
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

; Safe TileRef resolution for span/list.  A successful lookup is cached by
; logical page; WIN0 is mapped and restored only by the following per-tile
; draw step, keeping each DI section bounded and ISR-safe between elements.
batch_prefetch_safe:
        ld a,e
        cp 64
        jr nc,.tile
        ld (tile_slot),a
        ld a,(tile_x+1)
        cp 2
        jr nc,.arg
        or a
        jr z,.x_ok
        ld a,(tile_x)
        cp 49
        jr nc,.arg
.x_ok:
        ld a,(tile_y)
        cp 241
        jr nc,.arg
        ld a,d
        ld b,a
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
batch_ptr:      dw 0
batch_count:    dw 0
batch_page_valid: db 0
batch_logical_page: db 0

config_payload:
        db 16                    ; known structure size
        db #81                   ; required DSS mode
        dw 320,256
        db 1                     ; vram window (updated by gfx_get_config)
        db 0                     ; source window is fixed WIN0
        db 0                     ; code window (updated by gfx_get_config)
        db 1                     ; GFX_MAPPING_SOURCE_WIN0
        dw #00cf                ; implemented capabilities
        db 16,16
        db 0                     ; GFX_TILE_ROW_MAJOR
        db 0                     ; reserved
