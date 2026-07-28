        device noslot64k

        org 0
        jp start
        ds #10-$,0
        jp fake_dss

        include "harness.inc"

; l_call only needs SETWIN for this test. The DLL is already present at C000,
; so the fake DSS reports success without changing the flat emulator memory.
fake_dss:
        or a
        ret

start:
        ld sp,#bff0
        call t_begin

        ld hl,LIBMAN.lib_table
        ld (hl),1                 ; occupied
        inc hl
        ld (hl),1                 ; mock DSS block descriptor
        inc hl
        ld (hl),#c0               ; DLL begins in WIN3
        inc hl
        ld (hl),#dd

        ; Run entry 0 through the real dispatcher.
        ld hl,0
        ld b,0
        call LIBMAN.l_call
        call t_keep_a
        ld a,1
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,2
        call t_expect_z

        ; Exact register set used by the visual test at self-check stage 53.
        ld hl,0
        ld ix,319
        ld iy,#00ff
        ld a,7
        ld e,0
        ld b,29                   ; GFX_PUT_PIXEL
        call LIBMAN.l_call
        call t_keep_a
        ld a,3
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,4
        call t_expect_z
        push ix
        pop hl
        ld de,319
        or a
        sbc hl,de
        ld a,5
        call t_expect_z
        push iy
        pop hl
        ld de,#00ff
        or a
        sbc hl,de
        ld a,6
        call t_expect_z

        ; Read the same mirror address through entry 30.
        ld hl,0
        ld ix,319
        ld iy,#00ff
        ld e,0
        ld b,30                   ; GFX_GET_PIXEL
        call LIBMAN.l_call
        call t_keep_a
        ld a,7
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,8
        call t_expect_z
        ld a,e
        cp 7
        ld a,9
        call t_expect_z

        call t_end
        halt

        ds #2000-$,0
        include "libman13.asm"

        ds #c000-$,0
        define GFX320_TEST_BUILD
        include "../../gfx320.asm"
        assert $ < TEST_RESULT
