        device noslot64k

DSS_APPINFO            equ #47
APPINFO_EXE_HOMEDIR    equ 1

        org 0
        jp start
        ds #10-$,0
        jp fake_dss

        include "harness.inc"

        module LIBMAN
LR_OPEN equ 2
l_reason:       db 0
load_calls:     db 0
fail_first:     db 0
first_reason:   db 0

l_load:
        push af
        ld a,(load_calls)
        inc a
        ld (load_calls),a
        cp 1
        jr nz,.success
        ld a,(fail_first)
        or a
        jr z,.success
        ld a,(first_reason)
        ld (l_reason),a
        pop af
        scf
        ret
.success:
        pop af
        ld hl,#1234
        xor a
        ret
        endmodule

dss_fail: db 0

fake_dss:
        ld a,(dss_fail)
        or a
        jr nz,.fail
        ld (hl),'X'
        inc hl
        xor a
        ld (hl),a
        ret
.fail:
        scf
        ret

reset_mocks:
        xor a
        ld (LIBMAN.load_calls),a
        ld (LIBMAN.fail_first),a
        ld (LIBMAN.first_reason),a
        ld (LIBMAN.l_reason),a
        ld (dss_fail),a
        ret

start:
        ld sp,#bff0
        call t_begin

        ; A non-OPEN loader error must remain an error after reason dispatch.
        call reset_mocks
        ld a,1
        ld (LIBMAN.fail_first),a
        ld a,4                    ; LR_FORMAT
        ld (LIBMAN.first_reason),a
        call load_library
        ld a,1
        call t_expect_c
        ld a,(LIBMAN.load_calls)
        cp 1
        ld a,2
        call t_expect_z
        ld a,(LIBMAN.l_reason)
        cp 4
        ld a,3
        call t_expect_z

        ; LR_OPEN retries with the bare name and returns the second result.
        call reset_mocks
        ld a,1
        ld (LIBMAN.fail_first),a
        ld a,LIBMAN.LR_OPEN
        ld (LIBMAN.first_reason),a
        call load_library
        ld a,4
        call t_expect_nc
        ld a,(LIBMAN.load_calls)
        cp 2
        ld a,5
        call t_expect_z
        ld de,#1234
        or a
        sbc hl,de
        ld a,6
        call t_expect_z

        ; Missing APPINFO support goes directly to the bare-name load.
        call reset_mocks
        ld a,1
        ld (dss_fail),a
        call load_library
        ld a,7
        call t_expect_nc
        ld a,(LIBMAN.load_calls)
        cp 1
        ld a,8
        call t_expect_z

        call t_end
        halt

        include "../../common/load_library.inc"

libname: db "GFX320.DLL",0
libpath: ds 128
