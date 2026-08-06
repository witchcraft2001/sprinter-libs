; Shared interrupt and page-window discipline for graphics DLLs.

enter_di:
        ld a,i
        di
        jp po,.off
        ld a,1
        ld (restore_ei),a
        ret
.off:  xor a
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

check_vram_window:
        call current_stack_window
        ld b,a
        ld a,(vram_window)
        cp b
        jr z,.bad
        xor a
        ret
.bad:  ld a,ERR_WINDOW
        ret

; Tile calls temporarily replace WIN0 and therefore require code and SP
; outside it. NMI exclusion remains an application-level precondition.
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
.bad:  ld a,ERR_WINDOW
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
