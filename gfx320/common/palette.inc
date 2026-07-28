; Shared RGB8 palette implementation for Sprinter packed-pixel modes.
; Requires the host DLL to provide vram_base, vram_alias, map_vram,
; unmap_vram, check_vram_window, enter_di and leave_di.

; DE=RGB8[768], A=palette mask.
gfx_palette_load256:
        ld (pal_mask),a
        call palette_validate_idle_mask
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        ld hl,base_palette
        ex de,hl                  ; HL=caller source, DE=internal palette
        ld bc,768
        ldir
        xor a
        ld (pal_first),a
        ld (pal_hw_count),a       ; zero encodes 256 entries
        ld a,32
        ld (palette_level),a
        ; No LUT rebuild: at level 32 palette_write_range takes the identity
        ; fast path, and every fade entry rebuilds the LUT before using it.
        call palette_write_range
        or a
        ret nz
        ld a,1
        ld (palette_valid),a
        xor a
        ret

; DE=RGB8 source, A=first, IX=count_mask.
gfx_palette_load_range:
        ld (pal_first),a
        ld (pal_input),de
        ld a,ixh
        and #f8
        jr nz,.bad
        ld a,ixh
        and #06
        rrca
        ld (pal_mask),a
        call palette_validate_idle_mask
        or a
        ret nz
        ld a,ixh
        and 1
        jr z,.short_count
        ld a,ixl
        or a
        jr nz,.bad
        ld a,(pal_first)
        or a
        jr nz,.bad                 ; only first=0,count=256 is possible
        ld hl,256
        ld (pal_count),hl
        xor a
        ld (pal_hw_count),a
        jr .copy
.short_count:
        ld a,ixl
        ld l,a
        ld h,0
        ld (pal_count),hl
        ld a,l
        ld (pal_hw_count),a
        or a
        ret z                      ; validated empty operation
        ld a,(pal_first)
        ld e,a
        ld d,0
        add hl,de
        ld de,257
        or a
        sbc hl,de
        jr nc,.bad                 ; first+count <= 256
.copy:
        call check_vram_window
        or a
        ret nz
        ld hl,(pal_count)
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc                  ; byte count = entries * 3
        ld (pal_copy_len),hl
        ld a,(pal_first)
        call palette_base_at_a
        ld de,(pal_input)
        ex de,hl                   ; HL=caller source, DE=base[first]
        ld bc,(pal_copy_len)
        ldir
        call palette_write_range
        ret
.bad:  ld a,ERR_ARGUMENT
        ret

; A=index, D=R, E=G, IXL=B, IXH=palette mask.
gfx_palette_set:
        ld (pal_first),a
        ld a,d
        ld (pal_rgb),a
        ld a,e
        ld (pal_rgb+1),a
        ld a,ixl
        ld (pal_rgb+2),a
        ld a,ixh
        ld (pal_mask),a
        call palette_validate_idle_mask
        or a
        ret nz
        call check_vram_window
        or a
        ret nz
        ld a,(pal_first)
        call palette_base_at_a
        ex de,hl
        ld hl,pal_rgb
        ld bc,3
        ldir
        ld a,1
        ld (pal_hw_count),a
        call palette_write_range
        ret

palette_validate_idle_mask:
        ld a,(fade_active)
        or a
        jr nz,.busy
        ld a,(pal_mask)
        or a
        jr z,.bad
        and #fc
        jr nz,.bad
        xor a
        ret
.busy: ld a,ERR_BUSY
        ret
.bad:  ld a,ERR_PALETTE
        ret

; A=index -> HL=&base_palette[index*3].
palette_base_at_a:
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,base_palette
        add hl,de
        ret

; Write pal_hw_count entries (0=256), beginning at pal_first, from the saved
; base palette through the current 256-byte brightness LUT.
palette_write_range:
        ld a,(pal_first)
        call palette_base_at_a
        ld (pal_source),hl
        call check_vram_window
        or a
        ret nz
        ld a,VIDEO_PAGE
        ld (vram_alias),a
        ld a,(pal_first)
        ld (pal_index),a
        ld a,(pal_hw_count)
        or a
        jr nz,.short_total
        ld hl,256
        jr .store_total
.short_total:
        ld l,a
        ld h,0
.store_total:
        ld (pal_entries_left),hl
.next_chunk:
        ld hl,(pal_entries_left)
        ld a,h
        or a
        ld a,16
        jr nz,.chunk_ready
        ld a,l
        cp 17
        jr c,.chunk_ready
        ld a,16
.chunk_ready:
        ld (pal_chunk_count),a
        ld (pal_remaining),a
        call enter_di
        call map_vram
        ld hl,(vram_base)
        ld de,#03e0
        add hl,de
        push hl
        pop iy                    ; IY = palette bank 0 registers
        ld de,4
        add hl,de
        ld b,h
        ld c,l                    ; BC = palette bank 1 registers
        ld ix,(pal_source)
        ld de,palette_lut          ; hoisted for the inlined both-bank loop
        ld a,(pal_mask)
        cp 3
        jr nz,.no_fast
        ld a,(palette_level)
        cp 32
        jr z,.fast_both
        jp .both_loop
.no_fast:
        cp 1
        jr z,.bank0_loop
        jr .bank1_loop

; Full-brightness dual-bank path.  The brightness LUT is the identity here,
; so bytes go straight from the base palette; HL walks the bank-0 registers,
; BC the bank-1 registers, E carries the palette index for PORT_Y.
.fast_both:
        push iy
        pop hl
        ld a,(pal_index)
        ld e,a
        ld a,(pal_remaining)
        ld d,a
.fast_entry:
        ld a,e
        out (YPORT),a
        inc e
        ld a,(ix+0)
        ld (hl),a
        inc hl
        ld (bc),a
        inc bc
        ld a,(ix+1)
        ld (hl),a
        inc hl
        ld (bc),a
        inc bc
        ld a,(ix+2)
        ld (hl),a
        inc hl
        ld (bc),a
        inc bc
        xor a
        ld (hl),a
        ld (bc),a
        dec hl
        dec hl
        dec hl
        dec bc
        dec bc
        dec bc
        inc ix
        inc ix
        inc ix
        dec d
        jr nz,.fast_entry
        ld a,e
        ld (pal_index),a
        jp .chunk_done

.bank1_loop:
        call palette_select_index
        call palette_lookup_r
        ld (bc),a
        inc bc
        call palette_lookup_g
        ld (bc),a
        inc bc
        call palette_lookup_b
        ld (bc),a
        inc bc
        xor a
        ld (bc),a
        inc bc
        dec bc
        dec bc
        dec bc
        dec bc
        call palette_advance
        jr nz,.bank1_loop
        jr .chunk_done

.bank0_loop:
        call palette_select_index
        call palette_lookup_r
        ld (iy+0),a
        call palette_lookup_g
        ld (iy+1),a
        call palette_lookup_b
        ld (iy+2),a
        xor a
        ld (iy+3),a
        call palette_advance
        jr nz,.bank0_loop
        jr .chunk_done

; The dual-bank loop carries every fade frame, so the LUT lookups and entry
; bookkeeping are inlined (DE holds palette_lut from the chunk setup above).
.both_loop:
        ld a,(pal_index)
        out (YPORT),a
        ld a,(ix+0)
        ld l,a
        ld h,0
        add hl,de
        ld a,(hl)
        ld (iy+0),a
        ld (bc),a
        inc bc
        ld a,(ix+1)
        ld l,a
        ld h,0
        add hl,de
        ld a,(hl)
        ld (iy+1),a
        ld (bc),a
        inc bc
        ld a,(ix+2)
        ld l,a
        ld h,0
        add hl,de
        ld a,(hl)
        ld (iy+2),a
        ld (bc),a
        inc bc
        xor a
        ld (iy+3),a
        ld (bc),a
        dec bc
        dec bc
        dec bc                    ; back to the bank-1 red register
        inc ix
        inc ix
        inc ix
        ld a,(pal_index)
        inc a
        ld (pal_index),a
        ld a,(pal_remaining)
        dec a
        ld (pal_remaining),a
        jr nz,.both_loop
.chunk_done:
        ld (pal_source),ix
        call unmap_vram
        call leave_di
        ld hl,(pal_entries_left)
        ld a,(pal_chunk_count)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        ld (pal_entries_left),hl
        ld a,h
        or l
        jp nz,.next_chunk
        xor a
        ret

palette_select_index:
        ld a,(pal_index)
        out (YPORT),a
        ret

palette_lookup_r:
        ld a,(ix+0)
        jr palette_lookup
palette_lookup_g:
        ld a,(ix+1)
        jr palette_lookup
palette_lookup_b:
        ld a,(ix+2)
palette_lookup:
        ld l,a
        ld h,0
        ld de,palette_lut
        add hl,de
        ld a,(hl)
        ret

; Return NZ while more entries remain in the current micro-batch.
palette_advance:
        inc ix
        inc ix
        inc ix
        ld a,(pal_index)
        inc a
        ld (pal_index),a
        ld a,(pal_remaining)
        dec a
        ld (pal_remaining),a
        ret
