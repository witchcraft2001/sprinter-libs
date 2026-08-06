        org     #8100-512

; AFNT640.DLL visual test.  Put AFNT640.DLL next to the resulting EXE.

        dw      #5845           ; EXE signature
        db      #45, #00        ; EXE type and version
        dw      #0200, #0000, #0000, #0000, #0000, #0000
        dw      start, start, #bfff
        ds      490

        include "afnt640.inc"

DSS_APPINFO            equ     #47
APPINFO_EXE_HOMEDIR    equ     1

start:
        ld      hl,welcome
        ld      c,#5c
        rst     #10

        call    load_library
        jp      c,failed
        ld      (handle),hl

        ld      hl,(handle)
        ld      de,info
        call    LIBMAN.l_info
        jp      c,failed_after_load

        ld      c,#51
        rst     #10
        ld      (old_mode),a
        ld      a,b
        ld      (old_screen),a
        ld      bc,#0050        ; 640x256x16
        ld      a,#82
        rst     #10

        ld      e,AFNT640_TARGET_BUF0
        call    select_and_style
        jp      c,restore_and_fail
        ld      de,buf0_text
        ld      ix,#0020
        ld      iy,#0000
        ld      a,#1f
        call    print

        ld      e,AFNT640_TARGET_BUF1
        call    select_and_style
        jp      c,restore_and_fail
        ld      de,buf1_text
        ld      ix,#0020
        ld      iy,#0000
        ld      a,#2f
        call    print

        ld      e,AFNT640_TARGET_FRONT
        call    select_target
        jp      c,restore_and_fail
        ld      de,front_before
        ld      ix,#0020
        ld      iy,#0020
        ld      a,#0e
        call    print

        ld      e,AFNT640_TARGET_BACK
        call    select_target
        jp      c,restore_and_fail
        ld      de,back_before
        ld      ix,#0020
        ld      iy,#0030
        ld      a,#0a
        call    print

        in      a,(#c9)
        xor     1
        out     (#c9),a

        ld      e,AFNT640_TARGET_FRONT
        call    select_target
        jp      c,restore_and_fail
        ld      de,front_after
        ld      ix,#0020
        ld      iy,#0050
        ld      a,#0d
        call    print

        ld      e,AFNT640_TARGET_BACK
        call    select_target
        jp      c,restore_and_fail
        ld      de,back_after
        ld      ix,#0020
        ld      iy,#0060
        ld      a,#0b
        call    print

        ld      c,#30
        rst     #10
        in      a,(#c9)
        xor     1
        out     (#c9),a
        ld      c,#30
        rst     #10

restore_and_close:
        ld      a,(old_screen)
        ld      b,a
        ld      a,(old_mode)
        ld      c,#50
        rst     #10
        jr      close_and_exit
restore_and_fail:
        ld      a,(old_screen)
        ld      b,a
        ld      a,(old_mode)
        ld      c,#50
        rst     #10
        jr      failed_after_load
close_and_exit:
        ld      hl,(handle)
        call    LIBMAN.l_free
        jr      exit
failed_after_load:
        ld      hl,(handle)
        call    LIBMAN.l_free
failed:
        ld      hl,error_message
        ld      c,#5c
        rst     #10
        ld      c,#30
        rst     #10
exit:
        ld      bc,#0041
        rst     #10

; DE = ASCIIZ string, IX/IY = pixel position, A = colour attribute.
print:
        push    hl
        push    iy
        ld      hl,(handle)
        ld      b,AFNT640_APRINT
        call    LIBMAN.l_call
        pop     iy
        pop     hl
        ret

select_target:
        ld      hl,(handle)
        ld      b,AFNT640_SET_TARGET
        call    LIBMAN.l_call
        or      a
        ret     z
        scf
        ret

select_and_style:
        call    select_target
        ret     c
        ld      hl,(handle)
        ld      b,AFNT640_FNSTYLE
        call    LIBMAN.l_call
        or      a
        ret     z
        scf
        ret

handle:         dw      0
old_mode:       db      0
old_screen:     db      0
filename:       db      "AFNT640.DLL",0
used_exe_dir:   db      0
dll_path:       ds      272
welcome:        db      "AFNT640 visual test",13,10,0
error_message:  db      "Test setup failed. Put AFNT640.DLL beside this EXE.",13,10,"Press a key.",13,10,0
prompt:         db      13,10,"Press a key to return to the desktop.",13,10,0
buf0_text:      db      "BUF0: physical buffer zero; local palette and clear",0
buf1_text:      db      "BUF1: physical buffer one; local palette and clear",0
front_before:   db      "FRONT before RGMOD flip",0
back_before:    db      "BACK before RGMOD flip",0
front_after:    db      "FRONT after RGMOD flip",0
back_after:     db      "BACK after RGMOD flip",0
line1:          db      "The quick brown fox jumps over the lazy dog.",0
line2:          db      "ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789",0
line3:          db      "abcdefghijklmnopqrstuvwxyz  ! ? . , : ;",0
line4:          db      "Wide glyphs, narrow glyphs, spaces and punctuation.",0
line5:          db      "Colour #02: blue ink on black paper.",0
line6:          db      "Colour #4E: yellow ink on red paper.",0
line7:          db      "Colour #1F: bright white ink on blue paper.",0
line8:          db      "Colour #70: black ink on white paper.",0
line9:          db      "AFNT640 renderer, accelerated graphic output.",0
line10:         db      "Each row is drawn through libman L_CALL entry 3.",0
line11:         db      "0123456789 +-*/=()[]{}<> @#$%&'\"",0
line12:         db      "Screen should remain clean from top to bottom.",0
lines:
        dw line1  : db #02
        dw line2  : db #0e
        dw line3  : db #0a
        dw line4  : db #0d
        dw line5  : db #02
        dw line6  : db #4e
        dw line7  : db #1f
        dw line8  : db #70
        dw line9  : db #0b
        dw line10 : db #0c
        dw line11 : db #09
        dw line12 : db #0f
        dw 0
info:           ds      32

; Canonical libman 1.3 loader, resolved through Makefile's LIBMAN_DIR.
        include "libman13.asm"

; Load from the executable's directory first, then fall back to the current
; directory for older DSS versions without APPINFO.
load_library:
        xor     a
        ld      (used_exe_dir),a
        ld      hl,dll_path
        ld      b,APPINFO_EXE_HOMEDIR
        ld      c,DSS_APPINFO
        rst     #10
        jr      c,.bare
        ld      a,(dll_path)
        or      a
        jr      z,.bare
        ld      hl,dll_path
.find_end:
        ld      a,(hl)
        or      a
        jr      z,.append
        inc     hl
        jr      .find_end
.append:
        dec     hl
        ld      a,(hl)
        inc     hl
        cp      #5c
        jr      z,.copy_name
        cp      '/'
        jr      z,.copy_name
        ld      (hl),#5c
        inc     hl
.copy_name:
        ex      de,hl
        ld      hl,filename
.copy_loop:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        or      a
        jr      nz,.copy_loop
        ld      a,1
        ld      (used_exe_dir),a
        ld      hl,dll_path
        ld      a,3
        call    LIBMAN.l_load
        ret     nc
        ld      a,(LIBMAN.l_reason)
        cp      LIBMAN.LR_OPEN
        ret     nz
.bare:
        ld      hl,filename
        ld      a,3
        call    LIBMAN.l_load
        ret
