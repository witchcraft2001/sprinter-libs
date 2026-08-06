; Shared non-blocking 33-level RGB8 fade state machine.

; A=direction (0 out, 1 in), D=duration in calls, E=palette mask.
gfx_fade_begin:
        ld (fade_direction),a
        ld a,d
        ld (fade_duration),a
        ld a,e
        ld (fade_palette_mask),a
        ld (pal_mask),a
        ld a,(palette_valid)
        or a
        jr z,.palette
        ld a,(fade_active)
        or a
        jr nz,.busy
        ld a,(fade_direction)
        cp 2
        jr nc,.argument
        ld a,(pal_mask)
        or a
        jr z,.palette
        and #fc
        jr nz,.palette
        ld a,(fade_direction)
        or a
        ld a,32
        jr z,.start_level
        xor a
.start_level:
        ld b,a
        ld a,(palette_level)
        sub b                      ; zero when already at the start level
        ld (fade_write_pending),a
        ld a,b
        ld (palette_level),a
        xor a
        ld (fade_accumulator),a
        ld (fade_accumulator+1),a
        ld a,(fade_duration)
        ld (fade_frames_left),a
        or a
        jr z,.immediate_level
        ; A fade-out normally begins at full brightness and a chained fade-in
        ; at zero: rewriting an unchanged palette would only delay the caller.
        ld a,(fade_write_pending)
        or a
        jr z,.activate
        call build_fade_lut
        call fade_write_full
        or a
        ret nz
.activate:
        ld a,1
        ld (fade_active),a
        xor a
        ret
.immediate_level:
        ld a,(fade_direction)
        or a
        ld a,0
        jr z,.final
        ld a,32
.final:
        ld (palette_level),a
        call build_fade_lut
        call fade_write_full
        ret
.palette:
        ld a,ERR_PALETTE
        ret
.busy: ld a,ERR_BUSY
        ret
.argument:
        ld a,ERR_ARGUMENT
        ret

; A=0 and E=1 while active, E=0 when finished/inactive.
gfx_fade_step:
        ld a,(fade_active)
        or a
        jr nz,.active
        ld e,0
        xor a
        ret
.active:
        ld hl,(fade_accumulator)
        ld de,32
        add hl,de
        ld b,0                     ; brightness steps due on this frame
.divide:
        ld a,h
        or a
        jr nz,.subtract
        ld a,(fade_duration)
        cp l
        jr c,.subtract
        jr z,.subtract
        jr .division_done
.subtract:
        ld a,(fade_duration)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        inc b
        jr .divide
.division_done:
        ld (fade_accumulator),hl
        ld a,(fade_frames_left)
        dec a
        ld (fade_frames_left),a
        jr z,.force_final
        ld a,b
        or a
        jr z,.still_active
        call fade_apply_steps
        jr .write_active
.force_final:
        ld a,(fade_direction)
        or a
        ld a,0
        jr z,.store_final
        ld a,32
.store_final:
        ld (palette_level),a
        xor a
        ld (fade_active),a
        call build_fade_lut
        call fade_write_full
        or a
        ret nz
        ld e,0
        xor a
        ret
.write_active:
        call build_fade_lut
        call fade_write_full
        or a
        ret nz
.still_active:
        ld e,1
        xor a
        ret

fade_apply_steps:
        ld a,(fade_direction)
        or a
        ld a,(palette_level)
        jr nz,.up
        sub b
        jr nc,.store
        xor a
        jr .store
.up:   add a,b
        cp 33
        jr c,.store
        ld a,32
.store:
        ld (palette_level),a
        ret

gfx_fade_cancel:
        xor a
        ld (fade_active),a
        ret

fade_write_full:
        xor a
        ld (pal_first),a
        ld (pal_hw_count),a
        ld a,(fade_palette_mask)
        ld (pal_mask),a
        jp palette_write_range

; palette_lut[c] = round(c * palette_level / 32).  The quotient/remainder
; accumulator is exact and performs at most one increment per component.
build_fade_lut:
        ld a,(palette_level)
        ld c,a                    ; numerator increment
        ld hl,palette_lut
        ld d,0                    ; quotient
        ld e,16                   ; rounding bias/remainder
        ld b,0                    ; 256 values
.loop:
        ld (hl),d
        inc hl
        ld a,e
        add a,c
        cp 32
        jr c,.no_carry
        sub 32
        inc d
.no_carry:
        ld e,a
        djnz .loop
        ret
