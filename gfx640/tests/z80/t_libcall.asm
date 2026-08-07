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

        ; Install one logical tile page through the real libman dispatcher.
        ld hl,0
        ld de,test_tile_page
        ld ix,1
        ld b,22                   ; GFX_SET_PAGE_TABLE
        call LIBMAN.l_call
        call t_keep_a
        ld a,19
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,20
        call t_expect_z

        ; Seed both packed nibbles, then update the high/even pixel.
        ld a,#ab
        ld (#413f),a              ; WIN1 base + byte 319
        ld hl,0
        ld ix,638
        ld iy,#00ff
        ld a,6
        ld e,0
        ld b,29
        call LIBMAN.l_call
        call t_keep_a
        ld a,3
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,4
        call t_expect_z

        ; Exact low/odd register set used by the visual test.
        ld hl,0
        ld ix,639
        ld iy,#00ff
        ld a,7
        ld e,0
        ld b,29                   ; GFX_PUT_PIXEL
        call LIBMAN.l_call
        call t_keep_a
        ld a,5
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,6
        call t_expect_z
        push ix
        pop hl
        ld de,639
        or a
        sbc hl,de
        ld a,7
        call t_expect_z
        push iy
        pop hl
        ld de,#00ff
        or a
        sbc hl,de
        ld a,8
        call t_expect_z
        ld a,(#413f)
        cp #67
        ld a,9
        call t_expect_z

        ; Read the same mirror address through entry 30.
        ld hl,0
        ld ix,639
        ld iy,#00ff
        ld e,0
        ld b,30                   ; GFX_GET_PIXEL
        call LIBMAN.l_call
        call t_keep_a
        ld a,10
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,11
        call t_expect_z
        ld a,e
        cp 7
        ld a,12
        call t_expect_z

        ; Read the even pixel and verify that the odd update preserved it.
        ld hl,0
        ld ix,638
        ld iy,#00ff
        ld e,0
        ld b,30
        call LIBMAN.l_call
        call t_keep_a
        ld a,13
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,14
        call t_expect_z
        ld a,e
        cp 6
        ld a,15
        call t_expect_z

        ; KEY_FF with colour 15 is a byte-preserving no-op.
        ld hl,0
        ld ix,638
        ld iy,#00ff
        ld a,15
        ld e,#08
        ld b,29
        call LIBMAN.l_call
        call t_keep_a
        ld a,16
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,17
        call t_expect_z
        ld a,(#413f)
        cp #67
        ld a,18
        call t_expect_z

        ; One clipped row is enough to execute the relocated exact renderer.
        ; z88dk-ticks ignores Sprinter page/Y ports, so the source slot is
        ; deliberately placed at flat address #3000 and #FF is covered by the
        ; hardware/visual tests rather than asserted in this emulator.
        ld a,#ab
        ld (#4000),a
        ld (#4001),a
        ld (#4002),a
        ld hl,0
        ld de,#0030              ; logical page 0, slot 48 -> #3000
        ld ix,0
        ld iy,#00ff              ; clip to one row
        ld a,#08
        ld b,37                  ; GFX_DRAW_TILE_CLIP_TRANSPARENT
        call LIBMAN.l_call
        call t_keep_a
        ld a,21
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,22
        call t_expect_z
        ld a,(#4000)
        cp #a1
        ld a,23
        call t_expect_z
        ld a,(#4001)
        cp #2b
        ld a,24
        call t_expect_z
        ld a,(#4002)
        cp #34
        ld a,25
        call t_expect_z

        call t_end
        halt

        ds #2000-$,0
        include "libman13.asm"

test_tile_page:
        db 0
        ds #3000-$,0
tile_source:
        db #f1,#2f,#34
        ds 253,0

        ds #c000-$,0
        define GFX640_TEST_BUILD
        include "../../gfx640.asm"
        assert $ < TEST_RESULT
