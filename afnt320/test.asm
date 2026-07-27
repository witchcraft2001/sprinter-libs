        org     #8100-512

; AFNT320.DLL visual test.  Put AFNT320.DLL next to the resulting EXE.

        dw      #5845           ; EXE signature
        db      #45, #00        ; EXE type and version
        dw      #0200, #0000, #0000, #0000, #0000, #0000
        dw      start, start, #bfff
        ds      490

AFNT320_FNSTYLE        equ     2
AFNT320_APRINT         equ     3
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
        ld      bc,#0050        ; 320x256x256
        ld      a,#81           ; DSS_VMOD_G320 (gfxview mode)
        rst     #10
        ld      hl,(handle)
        ld      b,AFNT320_FNSTYLE
        call    LIBMAN.l_call
        jp      c,restore_and_fail

        ld      de,title
        ld      ix,#0010
        ld      iy,#0000
        ld      a,#1f
        call    print
        ld      de,info+16
        ld      ix,#0010
        ld      iy,#0010
        ld      a,#70
        call    print

        ld      hl,lines
        ld      iy,#0028
.next_line:
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        or      e
        jr      z,.done
        ld      a,(hl)
        inc     hl
        push    hl
        ld      ix,#0010
        call    print
        pop     hl
        ld      de,#0010
        add     iy,de
        jr      .next_line
.done:
        ld      hl,prompt
        ld      c,#5c
        rst     #10
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

print:
        push    hl
        push    iy
        ld      hl,(handle)
        ld      b,AFNT320_APRINT
        call    LIBMAN.l_call
        pop     iy
        pop     hl
        ret

handle:         dw      0
old_mode:       db      0
old_screen:     db      0
filename:       db      "AFNT320.DLL",0
used_exe_dir:   db      0
dll_path:       ds      272
welcome:        db      "AFNT320 visual test",13,10,0
error_message:  db      "Test setup failed. Put AFNT320.DLL beside this EXE.",13,10,"Press a key.",13,10,0
prompt:         db      13,10,"Press a key to return to the desktop.",13,10,0
title:          db      "AFNT320.DLL - 320 x 256 x 256 font test",0
line1:          db      "The quick brown fox jumps over the lazy dog.",0
line2:          db      "ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789",0
line3:          db      "abcdefghijklmnopqrstuvwxyz  ! ? . , : ;",0
line4:          db      "Compact 320-pixel renderer test.",0
line5:          db      "Colour #02: blue ink on black paper.",0
line6:          db      "Colour #4E: yellow ink on red paper.",0
line7:          db      "Colour #1F: bright white ink on blue paper.",0
line8:          db      "Colour #70: black ink on white paper.",0
line9:          db      "Embedded gfxview font, eight pixels high.",0
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

; See the ANTONFNT test for why this uses the current libman 1.3 loader.
        include "../../../sprinter-rtl8019a/src/lib/libman13.asm"

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
