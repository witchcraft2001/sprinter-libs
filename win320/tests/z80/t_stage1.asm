        device noslot64k

        org 0
        jp start

        include "harness.inc"

mock_fault:             db 0
mock_getmem_count:      db 0
mock_free_count:        db 0
mock_close_count:       db 0
mock_file_ptr:          dw mock_payload
mock_read_count:        dw 0
mock_pages:             db #10,#11,#12,#13
saved_font_block:       db 0
saved_font_page:        db 0
saved_page:             db 0
width_index:            db 0
actual_byte:            db 0
expected_pixel:         db 0
row_fail_id:            db 0
focus_saved:            db 0

rect:
        dw 0,0,1,1
        db 2,0
label_a:
        dw 8,48,80,8
        db #ff,WIN_LABEL_FILL
        dw asciiz_text
label_p:
        dw 8,64,80,8
        db #ff,WIN_LABEL_FILL
        dw pascal_text
button:
        dw 100,48,64,12
        db #ff,0
        dw asciiz_text

asciiz_text:            db "Stage 1",0
pascal_text:            db 7,"Stage 1"
pascal_empty:           db 0
font_path:              db "BROKEN.FNT",0
bad_wf32:               db "XF32",1,8,#70,#29

reset_mock:
        xor a
        ld (mock_fault),a
        ld (mock_getmem_count),a
        ld (mock_free_count),a
        ld (mock_close_count),a
        ld hl,mock_payload
        ld (mock_file_ptr),hl
        ld hl,#1110
        ld (mock_pages),hl
        ld hl,#1312
        ld (mock_pages+2),hl
        ret

; Test hooks execute the real page-port write as well as retaining a readable
; software latch. This lets z88dk-ticks exercise actual #50 VRAM mapping while
; the harness can still assert byte-exact restoration.
win_test_read_page:
        ld a,c
        sub #82
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,mock_pages
        add hl,de
        ld a,(hl)
        ret

win_test_write_page:
        push af
        ld b,a
        ld a,c
        sub #82
        rrca
        rrca
        rrca
        rrca
        rrca
        and 3
        ld e,a
        ld d,0
        ld hl,mock_pages
        add hl,de
        ld (hl),b
        ld a,c
        cp #82
        jr z,.no_hardware_map
        ld a,b
        out (c),a
.no_hardware_map:
        pop af
        ret

win_test_dss_call:
        ld a,c
        cp DSS_OPEN
        jr z,.open
        cp DSS_CLOSE
        jr z,.close
        cp DSS_READ
        jr z,.read
        cp DSS_GETMEM
        jr z,.getmem
        cp DSS_FREEMEM
        jr z,.freemem
        ld a,#ee
        scf
        ret
.open:
        ld a,(mock_fault)
        cp 1
        jr z,.fail
        ld hl,bad_wf32
        ld (mock_file_ptr),hl
        ld a,#21
        or a
        ret
.close:
        ld hl,mock_close_count
        inc (hl)
        xor a
        ret
.read:
        ld (mock_read_count),de
        push hl
        ld hl,(mock_file_ptr)
        pop de
        ld bc,(mock_read_count)
        ldir
        ld (mock_file_ptr),hl
        ld de,(mock_read_count)
        xor a
        ret
.getmem:
        ld hl,mock_getmem_count
        inc (hl)
        ld a,(hl)
        add a,#41
        or a
        ret
.freemem:
        ld hl,mock_free_count
        inc (hl)
        ld a,(mock_fault)
        cp 2
        jr z,.fail
        xor a
        ret
.fail:
        ld a,#f1
        scf
        ret

win_test_bios_call:
        ld a,(mock_getmem_count)
        add a,#76
        ld (hl),a
        xor a
        ret

; Map VRAM in WIN1 for direct CPU fixture/readback.
map_vram_test:
        in a,(#a2)
        ld (saved_page),a
        ld a,#50
        out (#a2),a
        ret

unmap_vram_test:
        ld a,#c0
        out (#89),a
        ld a,(saved_page)
        out (#a2),a
        ret

; A=y, HL=x -> A=pixel.
read_pixel:
        out (#89),a
        ld de,#4000
        add hl,de
        ld a,(hl)
        ret

; A=y, HL=x, E=value.
write_pixel:
        out (#89),a
        ld bc,#4000
        add hl,bc
        ld (hl),e
        ret

; VRAM #50 is mapped. A=expected byte, D=assertion id.
check_test_row:
        ld (expected_pixel),a
        ld a,d
        ld (row_fail_id),a
        ld a,30
        out (#89),a
        ld hl,#4000
        ld bc,(rect+WIN_RC_WIDTH)
.loop:
        ld a,(expected_pixel)
        cp (hl)
        jr nz,.fail
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.loop
        ret
.fail:
        ld a,(row_fail_id)
        jp t_fail

start:
        ld sp,#bff0
        call t_begin
        call reset_mock

        ld a,#33
        call win_init
        call t_keep_a
        ld a,1
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,2
        call t_expect_z
        ld a,(font_block)
        ld (saved_font_block),a
        ld a,(font_page)
        ld (saved_font_page),a
        ld d,0
        ld e,1
        call win_set_work_windows
        or a
        ld a,3
        call t_expect_z

        ; Theme validation is atomic and ABI 1.1 advertises all live features.
        ld de,custom_theme
        call win_set_theme
        or a
        ld a,4
        call t_expect_z
        ld a,(current_theme+WIN_TH_FACE)
        cp 3
        ld a,5
        call t_expect_z
        ld de,bad_theme
        call win_set_theme
        cp WIN_ERR_ARGUMENT
        ld a,6
        call t_expect_z
        ld a,(current_theme+WIN_TH_FACE)
        cp 3
        ld a,7
        call t_expect_z
        call win_get_version
        push ix
        pop hl
        ld de,WIN_CAP_CORE|WIN_CAP_EDIT|WIN_CAP_LISTBOX|WIN_CAP_SCROLLBAR|WIN_CAP_PROGRESS|WIN_CAP_ICON|WIN_CAP_FOCUS|WIN_CAP_PASCAL_STR|WIN_CAP_CHECKBOX|WIN_CAP_RADIOBUTTON
        or a
        sbc hl,de
        ld a,8
        call t_expect_z
        call test_other_entries

        ; Origin participates in checked u16 geometry.
        ld ix,10
        ld e,20
        call win_set_origin
        ld de,rect
        call win_fill_rect
        or a
        ld a,9
        call t_expect_z
        call map_vram_test
        ld a,20
        ld hl,10
        call read_pixel
        ld (actual_byte),a
        call unmap_vram_test
        ld a,(actual_byte)
        cp #f2
        ld a,10
        call t_expect_z
        ld ix,0
        ld e,0
        call win_set_origin

        ; Width boundaries, followed by byte-exact single and double XOR.
        call test_widths
        ld a,(width_index)
        cp 5
        ld a,11
        call t_expect_z

        ; ASCIIZ and Pascal labels use the same internal representation.
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld de,label_a
        call win_label
        or a
        ld a,12
        call t_expect_z
        ld e,WIN_TXT_PASCAL
        call win_set_text_format
        ld de,label_p
        call win_label
        or a
        ld a,13
        call t_expect_z
        ld a,(text_pixel_width)
        or a
        ld a,14
        call t_expect_nz
        ld hl,pascal_empty
        ld (label_p+WIN_LBL_TEXT),hl
        ld de,label_p
        call win_label
        or a
        ld a,36
        call t_expect_z
        ld hl,pascal_text
        ld (label_p+WIN_LBL_TEXT),hl
        ld e,WIN_TXT_ASCIIZ
        call win_set_text_format
        ld hl,0
        ld (label_a+WIN_LBL_WIDTH),hl
        ld a,WIN_LABEL_CLIP
        ld (label_a+WIN_LBL_FLAGS),a
        ld de,label_a
        call win_label
        or a
        ld a,37
        call t_expect_z
        ld a,(text_scratch)
        cp 'S'
        ld a,38
        call t_expect_z
        ld hl,80
        ld (label_a+WIN_LBL_WIDTH),hl
        ld a,WIN_LABEL_FILL
        ld (label_a+WIN_LBL_FLAGS),a

        ; Every Stage-1 button state and the focus minimum geometry.
        xor a
.button_state:
        ld (button+WIN_BTN_FLAGS),a
        push af
        ld de,button
        call win_button
        or a
        ld a,15
        call t_expect_z
        pop af
        inc a
        cp 16
        jr nz,.button_state
        ld hl,5
        ld (button+WIN_BTN_WIDTH),hl
        ld a,WIN_BTN_FOCUS
        ld (button+WIN_BTN_FLAGS),a
        ld de,button
        call win_button
        cp WIN_ERR_ARGUMENT
        ld a,16
        call t_expect_z
        ld hl,64
        ld (button+WIN_BTN_WIDTH),hl

        ; Descriptors may be supplied from WIN1/WIN2 even when one is about
        ; to become the VRAM window; both mappings are restored afterwards.
        ld a,4
        ld (rect+WIN_RC_COLOR),a
        ld hl,rect
        ld de,#5000
        ld bc,WIN_RECT_SIZE
        ldir
        ld de,#5000
        call win_fill_rect
        or a
        ld a,17
        call t_expect_z
        ld hl,rect
        ld de,#9000
        ld bc,WIN_RECT_SIZE
        ldir
        ld de,#9000
        call win_fill_rect
        or a
        ld a,18
        call t_expect_z
        ld a,(mock_pages)
        cp #10
        ld a,19
        call t_expect_z
        ld a,(mock_pages+1)
        cp #11
        ld a,20
        call t_expect_z

        ; A fixed window that now contains SP is rejected before drawing.
        ld d,0
        ld e,2
        call win_set_work_windows
        ld de,rect
        call win_fill_rect
        cp WIN_ERR_WINDOW
        ld a,21
        call t_expect_z
        ld d,0
        ld e,1
        call win_set_work_windows

        ; Malformed replacement WF32 closes/frees the temporary allocation
        ; and leaves the embedded font identity untouched.
        ld de,font_path
        call win_load_font
        cp WIN_ERR_FONT
        ld a,22
        call t_expect_z
        ld a,(font_block)
        ld b,a
        ld a,(saved_font_block)
        cp b
        ld a,23
        call t_expect_z
        ld a,(font_page)
        ld b,a
        ld a,(saved_font_page)
        cp b
        ld a,24
        call t_expect_z
        ld a,(mock_close_count)
        cp 1
        ld a,25
        call t_expect_z
        ld a,(mock_free_count)
        cp 1
        ld a,26
        call t_expect_z

        call test_textcore_and_cleanup_guards
        call win_free
        call t_end
        halt

test_textcore_and_cleanup_guards:
        ; Rebuilding palette colours must not replace the pending text source
        ; pointer in HL. A cache hit alone would not expose this regression.
        xor a
        ld (textcore_color_valid),a
        ld hl,#1234
        ld b,#70
        call textcore_prepare_colors
        ld de,#1234
        or a
        sbc hl,de
        ld a,47
        call t_expect_z
        ld hl,#5678
        ld b,#80
        call textcore_prepare_colors
        ld de,#5678
        or a
        sbc hl,de
        ld a,48
        call t_expect_z

        ; Force the worst legal clipped prefix: without the 253-byte cap the
        ; trailing NUL lands in xor_scratch, immediately after text_scratch.
        ld hl,text_scratch
        ld (hl),'A'
        ld de,text_scratch+1
        ld bc,254
        ldir
        xor a
        ld (text_scratch+255),a
        ld a,1
        ld (win_test_font_memory+WF32_HEADER_SIZE+FONT320_WIDTHS+'A'),a
        ld (win_test_font_memory+WF32_HEADER_SIZE+FONT320_WIDTHS+'.'),a
        ld hl,256
        ld (label_w),hl
        ld hl,257
        ld (text_pixel_width),hl
        ld a,WIN_LABEL_CLIP
        ld (label_flags),a
        ld a,#a5
        ld (text_scratch+319),a
        call s1_clip_text
        ld a,(text_scratch+319)
        cp #a5
        ld a,49
        call t_expect_z
        ld a,(text_scratch+253)
        cp '.'
        ld a,50
        call t_expect_z
        ld a,(text_scratch+254)
        cp '.'
        ld a,51
        call t_expect_z
        ld a,(text_scratch+255)
        or a
        ld a,52
        call t_expect_z

        ; A failed FREEMEM keeps ownership so a later cleanup can retry.
        ld a,#66
        ld (temp_font_block),a
        ld a,#77
        ld (temp_font_page),a
        ld a,2
        ld (mock_fault),a
        call s1_release_temp_font
        ld a,(temp_font_block)
        cp #66
        ld a,53
        call t_expect_z
        xor a
        ld (mock_fault),a
        call s1_release_temp_font
        ld a,(temp_font_block)
        cp #ff
        ld a,54
        call t_expect_z
        ret

test_other_entries:
        ld d,#ff
        ld e,WIN_STYLE_PALETTE|WIN_STYLE_CLEAR|WIN_STYLE_BOTH
        call win_style
        or a
        ld a,40
        call t_expect_z
        ld hl,20
        ld (rect+WIN_RC_X),hl
        ld (rect+WIN_RC_Y),hl
        ld hl,10
        ld (rect+WIN_RC_WIDTH),hl
        ld (rect+WIN_RC_HEIGHT),hl
        ld a,#ff
        ld (rect+WIN_RC_COLOR),a
        xor a
        ld (rect+WIN_RC_FLAGS),a
        ld de,rect
        call win_frame
        or a
        ld a,41
        call t_expect_z
        ld de,rect
        call win_panel
        or a
        ld a,42
        call t_expect_z
        ld hl,2
        ld (rect+WIN_RC_HEIGHT),hl
        ld de,rect
        call win_separator
        or a
        ld a,43
        call t_expect_z
        ; The fill row cursor must not advance the line helper coordinate:
        ; win_separator itself increments it exactly once, so its two rows
        ; are adjacent at y=20 and y=21.
        ld hl,(line_y)
        ld de,21
        or a
        sbc hl,de
        ld a,55
        call t_expect_z
        ld hl,10
        ld (rect+WIN_RC_HEIGHT),hl
        ld a,#55
        ld (rect+WIN_RC_COLOR),a
        call map_vram_test
        ld a,20
        ld hl,20
        call read_pixel
        ld (focus_saved),a
        call unmap_vram_test
        ld de,rect
        call win_focus_rect
        or a
        ld a,44
        call t_expect_z
        ld de,rect
        call win_focus_rect
        or a
        ld a,45
        call t_expect_z
        call map_vram_test
        ld a,20
        ld hl,20
        call read_pixel
        ld b,a
        call unmap_vram_test
        ld a,(focus_saved)
        cp b
        ld a,46
        call t_expect_z
        ld hl,0
        ld (rect+WIN_RC_X),hl
        ld (rect+WIN_RC_Y),hl
        ld hl,1
        ld (rect+WIN_RC_WIDTH),hl
        ld (rect+WIN_RC_HEIGHT),hl
        ld a,2
        ld (rect+WIN_RC_COLOR),a
        xor a
        ld (rect+WIN_RC_FLAGS),a
        ret

test_widths:
        xor a
        ld (width_index),a
.next:
        ld a,(width_index)
        add a,a
        ld e,a
        ld d,0
        ld hl,widths
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (rect+WIN_RC_WIDTH),de
        ld hl,30
        ld (rect+WIN_RC_Y),hl
        xor a
        ld (rect+WIN_RC_X),a
        ld (rect+WIN_RC_X+1),a
        ld hl,1
        ld (rect+WIN_RC_HEIGHT),hl
        ld a,4
        ld (rect+WIN_RC_COLOR),a
        xor a
        ld (rect+WIN_RC_FLAGS),a
        push de
        ld de,rect
        call win_fill_rect
        or a
        ld a,30
        call t_expect_z
        pop de

        call map_vram_test
        ld a,#f4
        ld d,31
        call check_test_row
        call unmap_vram_test

        ld a,#55
        ld (rect+WIN_RC_COLOR),a
        ld de,rect
        call win_invert_rect
        or a
        ld a,32
        call t_expect_z
        call map_vram_test
        ld a,#a1
        ld d,33
        call check_test_row
        call unmap_vram_test
        ld de,rect
        call win_invert_rect
        or a
        ld a,34
        call t_expect_z
        call map_vram_test
        ld a,#f4
        ld d,35
        call check_test_row
        call unmap_vram_test

        ld hl,width_index
        inc (hl)
        ld a,(hl)
        cp 5
        jp nz,.next
        ret

widths:
        dw 1,255,256,257,320

custom_theme:
        db 15,7,3,1,0,7,15,0,1,15,7,1,7,8,#55,1,15,0
bad_theme:
        db 15,7,16,1,0,7,15,0,1,15,7,1,7,8,#55,1,15,0

        ds #2000-$,0
        assert $ == #2000
win_test_font_memory:
        ds #4000,0

        assert $ == #6000
mock_payload:
        incbin "build/font.wf32"

        ds #c000-$,0
        assert $ == #c000
        define WIN320_TEST_BUILD
        include "../../win320.asm"
        assert $ < TEST_RESULT
