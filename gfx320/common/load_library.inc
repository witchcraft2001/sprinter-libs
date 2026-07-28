; Build "EXE directory\GFX320.DLL", with a bare-name fallback for older DSS.
; Requires libpath, libname, DSS_APPINFO, APPINFO_EXE_HOMEDIR and LIBMAN.
load_library:
        ld hl,libpath
        ld b,APPINFO_EXE_HOMEDIR
        ld c,DSS_APPINFO
        rst #10
        jr c,.fallback
        ld a,(libpath)
        or a
        jr z,.fallback
        ld hl,libpath
.find_end:
        ld a,(hl)
        or a
        jr z,.append
        inc hl
        jr .find_end
.append:
        dec hl
        ld a,(hl)
        inc hl
        cp #5c
        jr z,.copy_name
        cp '/'
        jr z,.copy_name
        ld (hl),#5c
        inc hl
.copy_name:
        ex de,hl
        ld hl,libname
.copy_loop:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.copy_loop
        ld hl,libpath
        ld a,3                    ; keep DLL in WIN3, away from EXE/data WIN2
        call LIBMAN.l_load
        ret nc
        ld a,(LIBMAN.l_reason)
        cp LIBMAN.LR_OPEN
        jr z,.fallback
        ; CP is only a reason-code test. Preserve the failed-load contract for
        ; LR_FORMAT/LR_INIT/LR_CALL instead of returning its cleared carry.
        scf
        ret
.fallback:
        ld hl,libname
        ld a,3
        jp LIBMAN.l_load
