        ifndef TEXTCORE320_INC
TEXTCORE320_INC equ 1

; Shared 320x256 accelerator font renderer.
;
; The caller owns page mapping and interrupt state. Both the font page and
; VRAM page must already be visible, and textcore_vram_base must include the
; selected screen offset.
;
; In: HL=ASCIIZ text, DE=x, BC=y (C is used), A=BG<<4|FG.
; Out: all registers are private to the internal ABI; IX/IY are restored.

textcore_draw_mapped:
        push ix
        push iy
        push de
        pop ix
        ld b,a
        ld a,c
        ld (textcore_y_pos),a
        call textcore_prepare_colors

        ; Alternate BC is the destination X address. Alternate HL/DE point at
        ; the two eight-byte colour buffers.
        push de
        exx
        pop bc
        ld hl,(textcore_vram_base)
        add hl,bc
        ld b,h
        ld c,l
        ld hl,textcore_foreground_buffer
        ld de,textcore_background_buffer
        exx
        ld c,l
        ld b,h

        ld a,(textcore_bg_color)
        or a
        ld hl,textcore_columns_general
        jr nz,.dispatch_ready
        ld hl,textcore_columns_black
.dispatch_ready:
        ld (textcore_dispatch+1),hl

        ld a,(textcore_y_pos)
        cp 248
        jr c,.rows8
        neg
        jr .rows_ready
.rows8:
        ld a,8
.rows_ready:
        ld (textcore_height+1),a
        ld d,d
textcore_height:
        ld a,8
        ld b,b
        ld a,(bc)
        inc bc
        or a
        jp z,textcore_done

textcore_char:
        push bc
        ld bc,(textcore_font_base)
        ld l,a
        ld h,0
        add hl,bc
        ld b,(hl)
        ld iyl,b
        inc h
        ld e,(hl)
        inc h
        ld d,(hl)
        inc h
        ld a,(hl)
        ld iyh,a
        ld hl,(textcore_font_base)
        add hl,de
        ld de,8

        ; Clip only the final glyph crossing X=320.
        ld a,ixh
        or a
        jr z,.width_ready
        cp 1
        jr nz,textcore_skip_glyph
        ld a,ixl
        cp #40
        jr nc,textcore_skip_glyph
        ld c,a
        ld a,#40
        sub c
        cp b
        jr nc,.width_ready
        ld b,a
.width_ready:
        ld a,b
        or a
        jr z,textcore_skip_glyph
        ld c,iyh

textcore_dispatch:
        jp textcore_columns_general

; General colour path:
; background XOR (mask AND (foreground XOR background)).
textcore_columns_general:
        rlc c
        jr nc,.blank
        ld l,l
        ld a,(hl)
        ld b,b
        exx
        ld a,(textcore_y_pos)
        out (#89),a
        ld l,l
        and (hl)
        ld b,b
        ex de,hl
        ld l,l
        xor (hl)
        ld a,a
        ld (bc),a
        ld b,b
        ex de,hl
        inc bc
        exx
        add hl,de
        djnz textcore_columns_general
        jr textcore_skip_glyph
.blank:
        exx
        ld a,(textcore_y_pos)
        out (#89),a
        ld a,(textcore_bg_color)
        ld e,e
        ld (bc),a
        ld b,b
        inc bc
        exx
        djnz textcore_columns_general
        jr textcore_skip_glyph

; Black-background path: mask AND foreground.
textcore_columns_black:
        rlc c
        jr nc,.blank
        ld l,l
        ld a,(hl)
        ld b,b
        exx
        ld a,(textcore_y_pos)
        out (#89),a
        ld l,l
        and (hl)
        ld a,a
        ld (bc),a
        ld b,b
        inc bc
        exx
        add hl,de
        djnz textcore_columns_black
        jr textcore_skip_glyph
.blank:
        exx
        ld a,(textcore_y_pos)
        out (#89),a
        xor a
        ld e,e
        ld (bc),a
        ld b,b
        inc bc
        exx
        djnz textcore_columns_black

textcore_skip_glyph:
        pop bc
        ld e,iyl
        ld d,0
        add ix,de
        ld a,(bc)
        inc bc
        or a
        jp nz,textcore_char

textcore_done:
        ld b,b
        pop iy
        pop ix
        ret

textcore_prepare_colors:
        ld a,(textcore_color_valid)
        or a
        jr z,.rebuild
        ld a,b
.previous:
        cp 0
        ret z
.rebuild:
        ld a,1
        ld (textcore_color_valid),a
        ld a,b
        ld (.previous+1),a
        and #0f
        ld c,a
        ld a,b
        and #f0
        rrca
        rrca
        rrca
        rrca
        ld (textcore_bg_color),a
        xor c
        exx
        ld hl,textcore_foreground_buffer
        call textcore_fill_colour_buffer
        ld a,(textcore_bg_color)
        ld hl,textcore_background_buffer
        call textcore_fill_colour_buffer
        exx
        ret

textcore_fill_colour_buffer:
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

textcore_font_base:          dw 0
textcore_vram_base:          dw 0
textcore_y_pos:              db 0
textcore_bg_color:           db 0
textcore_color_valid:        db 0
textcore_foreground_buffer:  ds 8,0
textcore_background_buffer:  ds 8,0

        endif
