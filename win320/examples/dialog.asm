        org #8100-512

; ABI 1.1 assembly example. WIN320.DLL must be beside this EXE.
        dw #5845
        db #45,#00
        dw #0200,#0000,#0000,#0000,#0000,#0000
        dw start,start,#bff0
        ds 490

        include "win320.inc"

        define LIBMAN_MAX_LIBS 1
        define LIBMAN_NO_LEGACY_API

DSS_SETVMOD             equ #50
DSS_EXIT                equ #41

start:
        ld bc,#0050
        ld a,#81
        rst #10
        ld hl,dll_name
        ld a,3                       ; keep DLL in WIN3
        call LIBMAN.l_load
        jp c,.exit
        ld (dll_handle),hl

        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call api
        jr nz,.free
        ld de,scrollbar
        ld b,WIN_SCROLLBAR_INIT
        call api
        jr nz,.free
        ld de,window
        ld b,WIN_DRAW
        call api
        jr nz,.free

        ; Direct call outside the declarative item list.
        ld de,direct_marker
        ld b,WIN_FILL_RECT
        call api
        jr nz,.free

        ld c,0                       ; application owns BIOS mouse INIT
        rst #30
.poll:
        ld de,track
        ld b,WIN_POLL
        call api
        jr nz,.free
        ld a,(track+WIN_TRK_EVENT)
        or a
        jr z,.poll
        ld a,(track+WIN_TRK_ID)
        cp 2
        jr z,.free
        ld hl,status_changed
        ld (status_label+WIN_LBL_TEXT),hl
        ld a,WIN_IT_DIRTY
        ld (items+6*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,window
        ld b,WIN_UPDATE
        call api
        jr z,.poll

.free:
        ld hl,(dll_handle)
        call LIBMAN.l_free
.exit:
        ld bc,#0041
        rst #10
        ret

api:
        ld hl,(dll_handle)
        call LIBMAN.l_call
        ret c
        or a
        ret

window:
        dw 32,20,256,216
        db #ff,0,7,2
        dw items
        db #ff,0
items:
        db WIN_T_LABEL,0,#ff,0
        dw title_label,0
        db WIN_T_EDIT,WIN_IT_HIT|WIN_IT_FOCUSABLE,10,0
        dw edit,0
        db WIN_T_LISTBOX,WIN_IT_HIT|WIN_IT_FOCUSABLE,11,0
        dw listbox,0
        db WIN_T_SCROLLBAR,WIN_IT_HIT|WIN_IT_REPEAT,12,0
        dw scrollbar,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,1,0
        dw ok_button,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,2,0
        dw cancel_button,0
        db WIN_T_LABEL,0,#ff,0
        dw status_label,0

title_label:
        dw 12,10,232,8
        db #ff,WIN_LABEL_CENTER
        dw title_text
status_label:
        dw 12,184,232,8
        db #ff,WIN_LABEL_CENTER
        dw status_ready
edit:
        dw 12,32,232,18
        db #ff,WIN_ED_FRAME,31,7,7,0
        dw edit_buffer
ok_button:
        dw 40,154,72,20
        db #ff,0
        dw ok_text
cancel_button:
        dw 132,154,72,20
        db #ff,0
        dw cancel_text
scrollbar:
        dw 232,60,12,80
        dw 3,3,0
        db WIN_SB_ARROWS,0
        dw 0,0,#ffff
listbox:
        dw 12,60,220,80
        db 12,#ff,#ff,WIN_LB_FRAME
        dw 3,0,0,list_rows
        db 0,0
        dw scrollbar,#ffff,#ffff
direct_marker:
        dw 22,222,16,8
        db 10,0
track:
        dw window,0
        db 0,WIN_TRK_ANY_KEY|WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

list_rows:      dw row0,row1,row2
title_text:     db "WIN320 assembly dialog",0
status_ready:   db "Ready",0
status_changed: db "Selection changed",0
edit_buffer:    db "edit me",0
                ds 24,0
ok_text:        db "OK",0
cancel_text:    db "Cancel",0
row0:           db "First row",0
row1:           db "Second row",0
row2:           db "Third row",0
dll_name:       db "WIN320.DLL",0
dll_handle:     dw 0

        include "libman.asm"
