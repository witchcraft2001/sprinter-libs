        org #8100-512

; WIN320 Stage-3 visual test. WIN320.DLL must be beside this EXE.
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
DSS_GETMEM              equ #3d
DSS_FREEMEM             equ #3e
BIOS_GETMEMBLKPAGES     equ #c5

start:
        xor a
        ld (dll_loaded),a
        ld (backstore_allocated),a
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
        ld de,WIN_CAP_CORE|WIN_CAP_PASCAL_STR
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

        call allocate_backstore
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

        ld a,4
        ld (test_stage),a
        call draw_stage2_sequence
        jp nz,api_failed

        ; Stage 3 is intentionally interactive: application code owns mouse
        ; INIT, then demonstrates one non-blocking poll and a blocking tracker.
        ld a,5
        ld (test_stage),a
        call run_stage3_dialog
        jp nz,api_failed

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

allocate_backstore:
        ld b,WIN_BACKSTORE_MAX_PAGES
        ld c,DSS_GETMEM
        rst #10
        jr c,.memory
        ld (backstore_block),a
        push af
        ld a,1
        ld (backstore_allocated),a
        pop af
        ld b,WIN_BACKSTORE_MAX_PAGES
        ld hl,backstore_physical_pages
        ld c,BIOS_GETMEMBLKPAGES
        rst #08
        jr c,.memory
        ld de,backstore_physical_pages
        ld ix,WIN_BACKSTORE_MAX_PAGES
        ld b,WIN_SET_BACKSTORE
        jp call_api
.memory:
        ld a,WIN_ERR_MEMORY
        or a
        ret

draw_stage2_sequence:
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        xor a
        call select_target_screen
        ret nz
        ld de,demo_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        call show_screen
        call wait_step

        ; Change two descriptors, mark only their entries dirty, and update.
        ld hl,str_dirty_done
        ld (demo_label+WIN_LBL_TEXT),hl
        ld a,14
        ld (demo_fill+WIN_RC_COLOR),a
        ld a,WIN_IT_DIRTY
        ld (demo_items+0*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld (demo_items+2*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,demo_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step

        ; Modal A saves screen 0. Modal B is nested on screen 1.
        ld de,modal_a_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        call wait_step
        ld a,1
        call select_target_screen
        ret nz
        ld de,modal_b_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        ld a,1
        call show_screen
        call wait_step

        ld b,WIN_CLOSE
        call call_api
        ret nz
        call wait_step
        ; The global target remains screen 1, but the next LIFO close restores
        ; the saved screen-0 rectangle from its stack record.
        ld b,WIN_CLOSE
        call call_api
        ret nz
        xor a
        call show_screen
        call wait_step
        xor a
        ret

run_stage3_dialog:
        xor a
        call select_target_screen
        ret nz
        ld hl,str_stage3_hint
        ld (demo_label+WIN_LBL_TEXT),hl
        ; This zone deliberately has no HOVER flag: the test must wait for a
        ; visible mouse action rather than returning immediately on entry.
        ld a,WIN_IT_DIRTY|WIN_IT_HIT
        ld (demo_items+4*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,demo_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        ld (stage3_track+WIN_TRK_STATE),a
        ld (stage3_track+WIN_TRK_STATE+1),a
        ld (stage3_track+WIN_TRK_STATE+2),a
        ld (stage3_track+WIN_TRK_STATE+3),a
        ld (stage3_track+WIN_TRK_STATE+4),a
        ld (stage3_track+WIN_TRK_STATE+5),a
        ld (stage3_track+WIN_TRK_STATE+6),a
        ld (stage3_track+WIN_TRK_STATE+7),a
        ld c,0                       ; mandatory application-side Mouse INIT
        rst #30
        ld c,1                       ; poll must leave this visible cursor up
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
        ld de,stage3_track
        ld b,WIN_POLL
        call call_api
        ret nz
        ld de,stage3_track
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld c,2
        rst #30
        ld hl,str_stage3_done
        ld (demo_label+WIN_LBL_TEXT),hl
        ld a,WIN_IT_DIRTY
        ld (demo_items+0*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,demo_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step
        xor a
        ret

wait_step:
        ld c,DSS_WAITKEY
        rst #10
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
        jr z,free_backstore
        xor a
        ld (dll_loaded),a
        ld hl,(dll_handle)
        call LIBMAN.l_free

free_backstore:
        ld a,(backstore_allocated)
        or a
        ret z
        xor a
        ld (backstore_allocated),a
        ld a,(backstore_block)
        ld c,DSS_FREEMEM
        rst #10
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

; ---- Stage-2 declarative and modal descriptors ----------------------------

demo_window:
        dw 20,24,280,204
        db #ff,0,5,#ff
        dw demo_items
        db #ff,0
demo_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw demo_label,0
        db WIN_T_SEPARATOR,WIN_IT_DIRTY,#ff,0
        dw demo_separator,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw demo_fill,0
        db WIN_T_BUTTON,WIN_IT_DIRTY|WIN_IT_DISABLED,#ff,0
        dw demo_button,0
        db WIN_T_ZONE,WIN_IT_DIRTY|WIN_IT_HIT,7,0
        dw demo_zone,0
demo_label:
        dw 8,10,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_declarative
demo_separator:
        dw 8,28,264,2
        db 0,0
demo_fill:
        dw 20,48,240,68
        db 11,0
demo_button:
        dw 80,148,120,20
        db #ff,0
        dw str_item_disabled
demo_zone:
        dw 20,48,240,68
        db 0,0

stage3_track:
        dw demo_window,0
        db 0,WIN_TRK_OUTSIDE|WIN_TRK_HALT
        ds WIN_TRACK_SIZE-6,0

modal_a_window:
        dw 54,62,212,116
        db #ff,0,2,#ff
        dw modal_a_items
        db #ff,0
modal_a_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw modal_a_label,0
        db WIN_T_BUTTON,WIN_IT_DIRTY,#ff,0
        dw modal_a_button,0
modal_a_label:
        dw 10,18,192,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_modal_a
modal_a_button:
        dw 56,64,100,20
        db #ff,0
        dw str_nested_next

modal_b_window:
        dw 80,88,160,80
        db #ff,WIN_WND_SUNKEN,1,#ff
        dw modal_b_items
        db #ff,0
modal_b_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw modal_b_label,0
modal_b_label:
        dw 8,32,144,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_modal_b

blue_theme:
        db 15,1,9,3,15,8,0,15
        db 3,15,1,11,1,9,#55,0

str_title:       db "WIN320 Stage 3 / screen 0 / ASCIIZ",0
str_long:        db "Clipped proportional label with a deliberately long tail",0
str_font_ok:     db "Embedded WF32 survived failed win_load_font",0
str_normal:      db "Normal",0
str_focus:       db "Focus",0
str_pressed:     db "Pressed",0
str_disabled:    db "Disabled",0
str_page0_hint:  db "Any key: alternate screen",0
str_declarative: db "Stage 3: declarative draw (key = dirty update)",0
str_stage3_hint: db "Stage 3: click blue zone, right-click, or click outside",0
str_stage3_done: db "Stage 3 event received; press a key to finish",0
str_dirty_done:  db "Dirty update: only label and fill changed",0
str_item_disabled: db "Item-disabled",0
str_modal_a:     db "Modal A saved on screen 0",0
str_nested_next: db "Next: screen 1",0
str_modal_b:     db "Nested modal B / screen 1",0

pstr_title:      db 39,"WIN320 Stage 3 / screen 1 / Pascal text"
pstr_long:       db 55,"Alternate theme, centered and clipped Pascal label tail"
pstr_hint:       db 17,"Escape: exit test"
pstr_normal:     db 6,"Normal"
pstr_focus:      db 5,"Focus"
pstr_pressed:    db 7,"Pressed"
pstr_disabled:   db 8,"Disabled"

missing_font:    db "__WIN320_MISSING__.FNT",0
dll_name:        db "WIN320.DLL",0
msg_banner:      db "WIN320 Stage 3 visual test",13,10,0
msg_ok:          db "PASS: declarative, dirty and modal sequence.",13,10,0
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
backstore_block: db 0
backstore_allocated: db 0
backstore_physical_pages:
        ds WIN_BACKSTORE_MAX_PAGES,0

        include "libman.asm"
