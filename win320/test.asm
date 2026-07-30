        org #8100-512

; WIN320 Stage-1 visual test. WIN320.DLL must be beside this EXE.
        dw #5845
        db #45,#00
        dw #0200,#0000,#0000,#0000,#0000,#0000
        dw start,start,#bff0
        ds 490

        include "win320.inc"

        define LIBMAN_MAX_LIBS 1
        define LIBMAN_NO_LEGACY_API
        define LIBMAN_DIAGNOSTICS

DSS_SETVMOD             equ #50
DSS_GETVMOD             equ #51
DSS_SELPAGE             equ #54
DSS_WAITKEY             equ #30
DSS_EXIT                equ #41
DSS_PUTS                equ #5c

start:
        xor a
        ld (dll_loaded),a
        ld (api_status),a
        ld (test_stage),a
        ld hl,msg_banner
        ld c,DSS_PUTS
        rst #10

        ld c,DSS_GETVMOD
        rst #10
        ld (old_mode),a
        ld a,b
        ld (old_screen),a
        ld bc,#0050
        ld a,#81
        rst #10

        ld hl,dll_name
        ld a,3
        call LIBMAN.l_load
        jp c,load_failed
        ld (dll_handle),hl
        ld a,1
        ld (dll_loaded),a

        ld a,1
        ld (test_stage),a
        ld hl,(dll_handle)
        ld b,WIN_GET_VERSION
        call LIBMAN.l_call
        jp c,manager_failed
        or a
        jp nz,api_failed
        ld a,d
        cp 1
        jp nz,self_failed
        ld a,e
        or a
        jp nz,self_failed
        push ix
        pop hl
        ld de,WIN_CAP_PASCAL_STR
        or a
        sbc hl,de
        jp nz,self_failed

        ; Install EGA colours and clear both buffers with the default desktop.
        ld a,2
        ld (test_stage),a
        ld hl,(dll_handle)
        ld d,#ff
        ld e,WIN_STYLE_PALETTE|WIN_STYLE_CLEAR|WIN_STYLE_BOTH
        ld b,WIN_STYLE
        call LIBMAN.l_call
        jp c,manager_failed
        or a
        jp nz,api_failed

        xor a
        call select_target_screen
        jp nz,api_failed
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        jp nz,api_failed
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        jp nz,api_failed
        call draw_default_scene
        jp nz,api_failed

        ; A failed external WF32 must not disturb the embedded font. The final
        ; label on screen 0 is drawn only after the expected failure.
        ld a,3
        ld (test_stage),a
        ld hl,(dll_handle)
        ld de,missing_font
        ld b,WIN_LOAD_FONT
        call LIBMAN.l_call
        jp c,manager_failed
        cp WIN_ERR_FONT
        jp nz,self_failed
        ld de,label_font_ok
        ld b,WIN_LABEL
        call call_api
        jp nz,api_failed

        ld a,1
        call select_target_screen
        jp nz,api_failed
        ld e,WIN_TXT_PASCAL
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        jp nz,api_failed
        ld de,blue_theme
        ld b,WIN_SET_THEME
        call call_api
        jp nz,api_failed
        ; Apply the new desktop role too, instead of leaving screen 1 with
        ; the blue desktop installed by the initial default-theme clear.
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        jp nz,api_failed
        call draw_pascal_scene
        jp nz,api_failed

        ; Page 0: any key opens page 1. Page 1 remains visible until Escape,
        ; so an auto-repeated Tab cannot immediately dismiss the test.
        xor a
        call show_screen
        ld c,DSS_WAITKEY
        rst #10
        ld a,1
        call show_screen
.wait_escape:
        ld c,DSS_WAITKEY
        rst #10
        cp 27
        jr nz,.wait_escape

success:
        call free_library
        call restore_video
        ld hl,msg_ok
        ld c,DSS_PUTS
        rst #10
        ld bc,#0041
        rst #10
        ret

; A=screen 0/1, updates WIN320's drawing target.
select_target_screen:
        ld e,a
        ld b,WIN_SET_SCREEN
        jp call_api

; A=visible screen 0/1.
show_screen:
        ld b,a
        ld c,DSS_SELPAGE
        rst #10
        ret

; B=entry, other public registers already set.
call_api:
        ld hl,(dll_handle)
        call LIBMAN.l_call
        jr nc,.status
        ld a,#ff
.status:
        or a
        ret

draw_default_scene:
        ld de,desktop_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,inner_frame
        ld b,WIN_FRAME
        call call_api
        ret nz
        ld de,h_separator
        ld b,WIN_SEPARATOR
        call call_api
        ret nz
        ld de,v_separator
        ld b,WIN_SEPARATOR
        call call_api
        ret nz
        ld de,label_title
        ld b,WIN_LABEL
        call call_api
        ret nz
        ld de,label_clip
        ld b,WIN_LABEL
        call call_api
        ret nz
        call draw_buttons_asciiz
        ret nz
        ld de,invert_band
        ld b,WIN_INVERT_RECT
        call call_api
        ret nz
        ld de,focus_demo
        ld b,WIN_FOCUS_RECT
        call call_api
        ret nz
        ld de,bottom_right
        ld b,WIN_FILL_RECT
        call call_api
        ret nz
        ld de,label_page0_hint
        ld b,WIN_LABEL
        jp call_api

draw_pascal_scene:
        ld de,desktop_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,sunken_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,pascal_title
        ld b,WIN_LABEL
        call call_api
        ret nz
        ld de,pascal_center
        ld b,WIN_LABEL
        call call_api
        ret nz
        call draw_buttons_pascal
        ret nz
        ld de,focus_demo
        ld b,WIN_FOCUS_RECT
        call call_api
        ret nz
        ld de,pascal_hint
        ld b,WIN_LABEL
        jp call_api

draw_buttons_asciiz:
        ld de,button_normal
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_focus
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_pressed
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_disabled
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_glyph
        ld b,WIN_BUTTON
        jp call_api

draw_buttons_pascal:
        ld de,pbutton_normal
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_focus
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_pressed
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_disabled
        ld b,WIN_BUTTON
        jp call_api

manager_failed:
        ld a,#ff
        jr failed
api_failed:
        ; A already contains the WIN_ERR_* status.
        jr failed
self_failed:
        ld a,#fe
failed:
        ld (api_status),a
        call free_library
        call restore_video
        ld hl,msg_failed
        ld c,DSS_PUTS
        rst #10
        ld a,(test_stage)
        call print_hex8
        ld hl,msg_status
        ld c,DSS_PUTS
        rst #10
        ld a,(api_status)
        call print_hex8
        ld hl,msg_newline
        ld c,DSS_PUTS
        rst #10
        ld c,DSS_WAITKEY
        rst #10
        ld bc,#0041
        rst #10
        ret

load_failed:
        call restore_video
        ld hl,msg_load_failed
        ld c,DSS_PUTS
        rst #10
        ld a,(LIBMAN.l_reason)
        call print_hex8
        ld hl,msg_dss
        ld c,DSS_PUTS
        rst #10
        ld a,(LIBMAN.l_dss_error)
        call print_hex8
        ld hl,msg_newline
        ld c,DSS_PUTS
        rst #10
        ld c,DSS_WAITKEY
        rst #10
        ld bc,#0041
        rst #10
        ret

free_library:
        ld a,(dll_loaded)
        or a
        ret z
        xor a
        ld (dll_loaded),a
        ld hl,(dll_handle)
        call LIBMAN.l_free
        ret

restore_video:
        ld a,(old_screen)
        ld b,a
        ld a,(old_mode)
        ld c,DSS_SETVMOD
        rst #10
        ret

print_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call hex_nibble
        call putc
        pop af
        call hex_nibble
        jp putc

hex_nibble:
        and #0f
        add a,'0'
        cp '9'+1
        ret c
        add a,'A'-'9'-1
        ret

putc:
        ld (char_buffer),a
        ld hl,char_buffer
        ld c,DSS_PUTS
        rst #10
        ret

; ---- descriptors -----------------------------------------------------------

desktop_panel:
        dw 4,4,312,248
        db #ff,0
inner_frame:
        dw 12,12,296,224
        db 0,WIN_RC_SUNKEN
sunken_panel:
        dw 20,30,280,192
        db #ff,WIN_RC_SUNKEN
h_separator:
        dw 20,42,280,2
        db 0,0
v_separator:
        dw 158,50,2,170
        db 0,WIN_RC_VERTICAL
invert_band:
        dw 20,214,130,8
        db #0f,0
focus_demo:
        dw 168,208,126,22
        db #ff,0
bottom_right:
        dw 319,255,1,1
        db 15,0

label_title:
        dw 20,20,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_title
label_clip:
        dw 20,50,125,8
        db #ff,WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_long
label_font_ok:
        dw 20,228,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_font_ok
label_page0_hint:
        dw 20,240,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_page0_hint
pascal_title:
        dw 28,42,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw pstr_title
pascal_center:
        dw 28,62,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw pstr_long
pascal_hint:
        dw 28,232,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw pstr_hint

button_normal:
        dw 20,78,120,18
        db #ff,0
        dw str_normal
button_focus:
        dw 20,102,120,18
        db #ff,WIN_BTN_FOCUS
        dw str_focus
button_pressed:
        dw 20,126,120,18
        db #ff,WIN_BTN_PRESSED
        dw str_pressed
button_disabled:
        dw 20,150,120,18
        db #ff,WIN_BTN_DISABLED
        dw str_disabled
button_glyph:
        dw 58,178,44,18
        db #ff,WIN_BTN_GLYPH|WIN_BTN_FOCUS
        dw #0018

pbutton_normal:
        dw 42,88,104,18
        db #ff,0
        dw pstr_normal
pbutton_focus:
        dw 174,88,104,18
        db #ff,WIN_BTN_FOCUS
        dw pstr_focus
pbutton_pressed:
        dw 42,118,104,18
        db #ff,WIN_BTN_PRESSED
        dw pstr_pressed
pbutton_disabled:
        dw 174,118,104,18
        db #ff,WIN_BTN_DISABLED
        dw pstr_disabled

blue_theme:
        db 15,1,9,3,15,8,0,15
        db 3,15,1,11,1,9,#55,0

str_title:       db "WIN320 Stage 1 / screen 0 / ASCIIZ",0
str_long:        db "Clipped proportional label with a deliberately long tail",0
str_font_ok:     db "Embedded WF32 survived failed win_load_font",0
str_normal:      db "Normal",0
str_focus:       db "Focus",0
str_pressed:     db "Pressed",0
str_disabled:    db "Disabled",0
str_page0_hint:  db "Any key: alternate screen",0

pstr_title:      db 39,"WIN320 Stage 1 / screen 1 / Pascal text"
pstr_long:       db 55,"Alternate theme, centered and clipped Pascal label tail"
pstr_hint:       db 17,"Escape: exit test"
pstr_normal:     db 6,"Normal"
pstr_focus:      db 5,"Focus"
pstr_pressed:    db 7,"Pressed"
pstr_disabled:   db 8,"Disabled"

missing_font:    db "__WIN320_MISSING__.FNT",0
dll_name:        db "WIN320.DLL",0
msg_banner:      db "WIN320 Stage 1 visual test",13,10,0
msg_ok:          db "PASS: inspect both GUI screens.",13,10,0
msg_failed:      db "FAIL: stage=$",0
msg_status:      db " status=$",0
msg_load_failed: db "FAIL: load reason=$",0
msg_dss:         db " DSS=$",0
msg_newline:     db 13,10,0
char_buffer:     db 0,0

dll_handle:      dw 0
dll_loaded:      db 0
api_status:      db 0
test_stage:      db 0
old_mode:        db 0
old_screen:      db 0

        include "libman.asm"
