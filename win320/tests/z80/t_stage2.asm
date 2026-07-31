        device noslot64k

        org 0
        jp start

        include "harness.inc"

mock_getmem_count:      db 0
mock_free_count:        db 0
mock_file_ptr:          dw mock_payload
mock_read_count:        dw 0
mock_pages:             db #10,#11,#12,#13
saved_page:             db 0
expected_pixel:         db 0
row_width:              dw 0
width_index:            db 0
expected_commands:      db 0
observed_bc:             dw 0
observed_hl:             dw 0
observed_ix:             dw 0
observed_iy:             dw 0

page_list_ok:           db #30,#31,#32,#33
page_list_dup:          db #30,#31,#30,#33
page_list_font:         db #30,#77,#32,#33
page_list_one:          db #30

fill_a:
        dw 0,0,5,5
        db 2,0
fill_b:
        dw 0,0,5,5
        db 3,0
fill_hidden:
        dw 400,400,5,5
        db 4,0
zone_a:
        dw 8,8,10,10
        db 0,0
button_a:
        dw 10,12,64,14
        db #ff,0
        dw text_button
label_a:
        dw 2,32,100,8
        db #ff,WIN_LABEL_FILL
        dw text_label

draw_items:
        db WIN_T_NONE,WIN_IT_DIRTY,#ff,0
        dw 0,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw fill_a,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw fill_b,0
        db WIN_T_ZONE,WIN_IT_DIRTY|WIN_IT_HIT,3,0
        dw zone_a,0
        db WIN_T_FILL,WIN_IT_DIRTY|WIN_IT_HIDDEN,#ff,0
        dw fill_hidden,0
        db WIN_T_BUTTON,WIN_IT_DIRTY|WIN_IT_DISABLED,#ff,0
        dw button_a,0
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw label_a,0
DRAW_ITEM_COUNT equ 7

draw_window:
        dw 10,20,150,80
        db #ff,WIN_WND_NOPANEL,DRAW_ITEM_COUNT,#ff
        dw draw_items
        db #ff,0

mid_items:
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw fill_a,0
        db WIN_T_ICON,WIN_IT_DIRTY,#ff,0
        dw fill_a,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw fill_b,0
mid_window:
        dw 20,30,100,60
        db #ff,WIN_WND_NOPANEL,3,#ff
        dw mid_items
        db #ff,0

back_window:
        dw 0,120,1,1
        db #ff,WIN_WND_NOPANEL,0,#ff
        dw 0
        db #ff,0

rollback_good:
        dw 0,0,5,5
        db 2,0
rollback_bad:
        dw 6,0,5,5
        db 16,0
rollback_items:
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw rollback_good,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw rollback_bad,0
rollback_window:
        dw 40,150,20,10
        db #ff,WIN_WND_NOPANEL,2,#ff
        dw rollback_items
        db #ff,0

overflow_label:
        dw 0,0,1,8
        db #ff,0
        dw text_label
overflow_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw overflow_label,0
overflow_window:
        dw 40,140,8,8
        db #ff,WIN_WND_NOPANEL,1,#ff
        dw overflow_items
        db #ff,0

text_button:            db "Disabled",0
text_label:             db "Declarative Stage 2",0
widths:                 dw 1,255,256,257,320

reset_mock:
        xor a
        ld (mock_getmem_count),a
        ld (mock_free_count),a
        ld hl,mock_payload
        ld (mock_file_ptr),hl
        ld hl,#1110
        ld (mock_pages),hl
        ld hl,#1312
        ld (mock_pages+2),hl
        ret

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
        cp DSS_READ
        jr z,.read
        cp DSS_GETMEM
        jr z,.getmem
        cp DSS_FREEMEM
        jr z,.freemem
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
        ld a,#41
        or a
        ret
.freemem:
        ld hl,mock_free_count
        inc (hl)
        xor a
        ret

win_test_bios_call:
        ld (hl),#77
        xor a
        ret

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

; A=screen, B=y, HL=x -> A=pixel.
read_pixel:
        push af
        call map_vram_test
        pop af
        or a
        ld de,#4000
        jr z,.base
        ld de,#4140
.base:
        add hl,de
        ld a,b
        out (#89),a
        ld a,(hl)
        push af
        call unmap_vram_test
        pop af
        ret

; A=screen, B=y, HL=x, E=value.
write_pixel:
        push af
        call map_vram_test
        pop af
        or a
        ld bc,#4000
        jr z,.base
        ld bc,#4140
.base:
        add hl,bc
        ld a,b
        ; B was consumed by the base address, reload y from the fixture.
        ld a,(back_window+WIN_WND_Y)
        out (#89),a
        ld (hl),e
        jp unmap_vram_test

; Fill/check the row described by back_window on screen 0.
fill_back_row:
        ld (expected_pixel),a
        call map_vram_test
        ld a,(back_window+WIN_WND_Y)
        out (#89),a
        ld hl,#4000
        ld de,(back_window+WIN_WND_X)
        add hl,de
        ld bc,(back_window+WIN_WND_WIDTH)
.loop:
        ld a,(expected_pixel)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.loop
        jp unmap_vram_test

check_back_row:
        ld (expected_pixel),a
        call map_vram_test
        ld a,(back_window+WIN_WND_Y)
        out (#89),a
        ld hl,#4000
        ld de,(back_window+WIN_WND_X)
        add hl,de
        ld bc,(back_window+WIN_WND_WIDTH)
.loop:
        ld a,(expected_pixel)
        cp (hl)
        jr nz,.bad
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.loop
        call unmap_vram_test
        xor a
        ret
.bad:
        call unmap_vram_test
        ld a,1
        or a
        ret

start:
        ld sp,#bff0
        call t_begin
        call reset_mock
        ld a,#33
        call win_init
        or a
        ld a,1
        call t_expect_z
        ld d,0
        ld e,1
        call win_set_work_windows
        or a
        ld a,2
        call t_expect_z
        call win_get_version
        ld a,d
        cp 1
        ld a,3
        call t_expect_z
        ld a,e
        or a
        ld a,4
        call t_expect_z
        push ix
        pop hl
        ld de,WIN_CAP_CORE|WIN_CAP_PASCAL_STR
        or a
        sbc hl,de
        ld a,5
        call t_expect_z

        call test_draw_update
        call test_backstore_validation
        call test_backstore_widths
        call test_allocator_and_depth
        call test_label_preflight
        call test_rollback_and_screens
        call test_free_closes
        call t_end
        halt

test_draw_update:
        ld ix,#1234
        ld e,77
        call win_set_origin
        ld bc,#3456
        ld hl,#789a
        ld ix,#bcde
        ld iy,#1357
        ld de,draw_window
        call win_draw
        ld (observed_bc),bc
        ld (observed_hl),hl
        ld (observed_ix),ix
        ld (observed_iy),iy
        or a
        ld a,10
        call t_expect_z
        ld hl,(observed_bc)
        ld de,#3456
        or a
        sbc hl,de
        ld a,31
        call t_expect_z
        ld hl,(observed_hl)
        ld de,#789a
        or a
        sbc hl,de
        ld a,32
        call t_expect_z
        ld hl,(observed_ix)
        ld de,#bcde
        or a
        sbc hl,de
        ld a,33
        call t_expect_z
        ld hl,(observed_iy)
        ld de,#1357
        or a
        sbc hl,de
        ld a,34
        call t_expect_z
        ld hl,(origin_x)
        ld de,#1234
        or a
        sbc hl,de
        ld a,11
        call t_expect_z
        ld a,(origin_y)
        cp 77
        ld a,12
        call t_expect_z
        ld a,(button_a+WIN_BTN_FLAGS)
        or a
        ld a,13
        call t_expect_z
        ld a,(draw_items+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,14
        call t_expect_z
        ld a,(draw_items+3*WIN_ITEM_SIZE+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,15
        call t_expect_z
        ld a,(draw_items+4*WIN_ITEM_SIZE+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,16
        call t_expect_z
        xor a
        ld b,20
        ld hl,10
        call read_pixel
        cp #f3
        ld a,17
        call t_expect_z

        ld a,WIN_IT_DIRTY
        ld (draw_items+0*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld (draw_items+1*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld a,WIN_IT_DIRTY|WIN_IT_HIT
        ld (draw_items+3*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld a,WIN_IT_DIRTY|WIN_IT_HIDDEN
        ld (draw_items+4*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld a,4
        ld (fill_a+WIN_RC_COLOR),a
        ld de,draw_window
        call win_update
        or a
        ld a,18
        call t_expect_z
        ld a,e
        cp 1
        ld a,19
        call t_expect_z
        ld a,(draw_items+3*WIN_ITEM_SIZE+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,20
        call t_expect_z

        ld de,mid_window
        call win_update
        cp WIN_ERR_UNSUPPORTED
        ld a,21
        call t_expect_z
        ld a,e
        cp 1
        ld a,22
        call t_expect_z
        ld a,(mid_items+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,23
        call t_expect_z
        ld a,(mid_items+WIN_ITEM_SIZE+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,24
        call t_expect_nz
        ld a,(mid_items+2*WIN_ITEM_SIZE+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,25
        call t_expect_nz

        ld de,draw_window
        ld ix,DRAW_ITEM_COUNT
        call win_draw_item
        cp WIN_ERR_ARGUMENT
        ld a,26
        call t_expect_z
        ld a,#ff
        ld (draw_window+WIN_WND_FOCUS),a
        ld a,WIN_IT_FOCUSABLE
        ld (draw_items+WIN_ITEM_FLAGS),a
        ld de,draw_window
        ld ix,0
        call win_draw_item
        cp WIN_ERR_UNSUPPORTED
        ld a,27
        call t_expect_z
        xor a
        ld (draw_items+WIN_ITEM_FLAGS),a

        ; Headers and arrays are valid in WIN1/WIN2 before those windows are
        ; temporarily remapped for drawing.
        ld hl,draw_window
        ld de,#5000
        ld bc,WIN_WINDOW_SIZE
        ldir
        ld hl,draw_items
        ld de,#5100
        ld bc,DRAW_ITEM_COUNT*WIN_ITEM_SIZE
        ldir
        ld hl,#5100
        ld (#5000+WIN_WND_ITEMS),hl
        ld de,#5000
        call win_draw
        or a
        ld a,28
        call t_expect_z
        ld hl,draw_window
        ld de,#9000
        ld bc,WIN_WINDOW_SIZE
        ldir
        ld de,#9000
        call win_draw
        or a
        ld a,29
        call t_expect_z

        ; A fixed VRAM role colliding with the current SP fails before draw.
        ld d,0
        ld e,2
        call win_set_work_windows
        ld de,draw_window
        call win_draw
        cp WIN_ERR_WINDOW
        ld a,30
        call t_expect_z
        ld d,0
        ld e,1
        call win_set_work_windows

        ; A header failure redraws nothing and therefore reports E=0.
        xor a
        ld (draw_window+WIN_WND_FOCUS),a
        ld de,draw_window
        call win_update
        cp WIN_ERR_UNSUPPORTED
        ld a,35
        call t_expect_z
        ld a,e
        or a
        ld a,36
        call t_expect_z
        ld a,#ff
        ld (draw_window+WIN_WND_FOCUS),a
        ld ix,0
        ld e,0
        call win_set_origin
        ret

test_backstore_validation:
        ld de,page_list_dup
        ld ix,4
        call win_set_backstore
        cp WIN_ERR_ARGUMENT
        ld a,40
        call t_expect_z
        ld de,page_list_font
        ld ix,4
        call win_set_backstore
        cp WIN_ERR_ARGUMENT
        ld a,41
        call t_expect_z
        ld de,page_list_ok
        ld ix,0
        call win_set_backstore
        cp WIN_ERR_ARGUMENT
        ld a,42
        call t_expect_z
        ld de,#c100
        ld ix,4
        call win_set_backstore
        cp WIN_ERR_ARGUMENT
        ld a,43
        call t_expect_z
        ld de,page_list_ok
        ld ix,4
        call win_set_backstore
        or a
        ld a,44
        call t_expect_z
        ld a,(backstore_pages)
        cp 4
        ld a,45
        call t_expect_z
        ret

test_backstore_widths:
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
        ld (back_window+WIN_WND_WIDTH),de
        ld a,#5a
        call fill_back_row
        xor a
        ld (s2_test_map_count),a
        ld (s2_test_unmap_count),a
        ld (s2_test_command_count),a
        ei
        ld de,back_window
        call win_open
        or a
        ld a,50
        call t_expect_z
        ld a,i
        jp pe,.open_iff_ok
        ld a,58
        call t_fail
.open_iff_ok:
        ld a,(s2_test_map_count)
        cp 1
        ld a,51
        call t_expect_z
        ld a,(back_window+WIN_WND_WIDTH+1)
        or a
        ld a,1
        jr z,.expected
        ld a,(back_window+WIN_WND_WIDTH)
        or a
        ld a,1
        jr z,.expected
        inc a
.expected:
        ld (expected_commands),a
        ld b,a
        ld a,(s2_test_command_count)
        cp b
        ld a,52
        call t_expect_z
        ld a,#a5
        call fill_back_row
        di
        call win_close
        push af
        ld a,i
        jp po,.iff_off
        ld a,53
        call t_fail
.iff_off:
        pop af
        or a
        ld a,54
        call t_expect_z
        ld a,#5a
        call check_back_row
        or a
        ld a,55
        call t_expect_z
        ld a,(s2_test_map_count)
        cp 2
        ld a,56
        call t_expect_z
        ld a,(mock_pages)
        cp #10
        ld a,59
        call t_expect_z
        ld a,(mock_pages+1)
        cp #11
        ld a,71
        call t_expect_z
        ld a,(expected_commands)
        add a,a
        ld b,a
        ld a,(s2_test_command_count)
        cp b
        ld a,57
        call t_expect_z
        ei
        ld hl,width_index
        inc (hl)
        ld a,(hl)
        cp 5
        jp nz,.next
        ret

test_allocator_and_depth:
        ld de,page_list_one
        ld ix,1
        call win_set_backstore
        ld hl,#3fff
        ld (backstore_alloc_offset),hl
        xor a
        ld (backstore_alloc_page),a
        ld hl,1
        ld (back_window+WIN_WND_WIDTH),hl
        ld de,back_window
        call win_open
        or a
        ld a,60
        call t_expect_z
        ld hl,(backstore_alloc_offset)
        ld de,#4000
        or a
        sbc hl,de
        ld a,61
        call t_expect_z
        call win_close
        ld hl,2
        ld (back_window+WIN_WND_WIDTH),hl
        ld de,back_window
        call win_open
        cp WIN_ERR_BACKSTORE
        ld a,62
        call t_expect_z

        ld de,page_list_ok
        ld ix,4
        call win_set_backstore
        ld hl,#3fff
        ld (backstore_alloc_offset),hl
        xor a
        ld (backstore_alloc_page),a
        ld de,back_window
        call win_open
        or a
        ld a,63
        call t_expect_z
        ld a,(backstore_alloc_page)
        cp 1
        ld a,64
        call t_expect_z
        ld hl,(backstore_alloc_offset)
        ld de,2
        or a
        sbc hl,de
        ld a,65
        call t_expect_z
        call win_close

        ; Reset allocator, then reach depth four and reject the fifth.
        ld de,page_list_ok
        ld ix,4
        call win_set_backstore
        ld hl,1
        ld (back_window+WIN_WND_WIDTH),hl
        ld b,4
.open:
        push bc
        ld de,back_window
        call win_open
        or a
        ld a,66
        call t_expect_z
        pop bc
        djnz .open
        ld de,back_window
        call win_open
        cp WIN_ERR_DEPTH
        ld a,67
        call t_expect_z
        ld de,page_list_one
        ld ix,1
        call win_set_backstore
        cp WIN_ERR_BUSY
        ld a,68
        call t_expect_z
        ld b,4
.close:
        push bc
        call win_close
        or a
        ld a,69
        call t_expect_z
        pop bc
        djnz .close
        call win_close
        cp WIN_ERR_DEPTH
        ld a,70
        call t_expect_z
        ret

test_label_preflight:
        ld de,page_list_ok
        ld ix,4
        call win_set_backstore
        ld ix,#2222
        ld e,33
        call win_set_origin
        xor a
        ld (s2_test_map_count),a
        ld de,overflow_window
        call win_open
        cp WIN_ERR_ARGUMENT
        ld a,83
        call t_expect_z
        ld a,(s2_test_map_count)
        or a
        ld a,84
        call t_expect_z
        ld a,(backstore_depth)
        or a
        ld a,85
        call t_expect_z
        ld hl,(origin_x)
        ld de,#2222
        or a
        sbc hl,de
        ld a,86
        call t_expect_z
        ld a,(origin_y)
        cp 33
        ld a,87
        call t_expect_z
        ld a,(overflow_items+WIN_ITEM_FLAGS)
        and WIN_IT_DIRTY
        ld a,88
        call t_expect_nz

        ; Declarative labels need a real field; direct win_label keeps its
        ; width=0 decorative mode.
        ld hl,0
        ld (overflow_label+WIN_LBL_WIDTH),hl
        ld de,overflow_window
        call win_draw
        cp WIN_ERR_ARGUMENT
        ld a,89
        call t_expect_z
        ld hl,1
        ld (overflow_label+WIN_LBL_WIDTH),hl
        ret

test_rollback_and_screens:
        ld de,page_list_ok
        ld ix,4
        call win_set_backstore
        xor a
        ld e,a
        call win_set_screen
        ld hl,40
        ld (back_window+WIN_WND_X),hl
        ld hl,150
        ld (back_window+WIN_WND_Y),hl
        ld hl,20
        ld (back_window+WIN_WND_WIDTH),hl
        ld hl,10
        ld (back_window+WIN_WND_HEIGHT),hl
        ld a,#62
        call fill_back_row
        ld ix,7
        ld e,9
        call win_set_origin

        ; A visible child outside the modal rectangle is rejected by
        ; preflight: no backstore row is mapped and no stack record is pushed.
        ld hl,18
        ld (rollback_bad+WIN_RC_X),hl
        ld a,2
        ld (rollback_bad+WIN_RC_COLOR),a
        xor a
        ld (s2_test_map_count),a
        ld de,rollback_window
        call win_open
        cp WIN_ERR_ARGUMENT
        ld a,72
        call t_expect_z
        ld a,(s2_test_map_count)
        or a
        ld a,73
        call t_expect_z
        ld a,(backstore_depth)
        or a
        ld a,74
        call t_expect_z
        ld hl,6
        ld (rollback_bad+WIN_RC_X),hl
        ld a,16
        ld (rollback_bad+WIN_RC_COLOR),a

        ld de,rollback_window
        call win_open
        cp WIN_ERR_ARGUMENT
        ld a,75
        call t_expect_z
        ld a,(backstore_depth)
        or a
        ld a,76
        call t_expect_z
        ld hl,(origin_x)
        ld de,7
        or a
        sbc hl,de
        ld a,77
        call t_expect_z
        ld a,(origin_y)
        cp 9
        ld a,78
        call t_expect_z
        ld a,#62
        call check_back_row
        or a
        ld a,79
        call t_expect_z

        ; Nested windows restore the screen captured in each stack record.
        ld hl,2
        ld (back_window+WIN_WND_X),hl
        ld (back_window+WIN_WND_Y),hl
        ld hl,1
        ld (back_window+WIN_WND_WIDTH),hl
        ld (back_window+WIN_WND_HEIGHT),hl
        xor a
        ld e,a
        call win_set_screen
        xor a
        ld b,2
        ld hl,2
        call read_pixel
        ld (expected_pixel),a
        ld de,back_window
        call win_open
        call map_vram_test
        ld a,2
        out (#89),a
        ld a,#a0
        ld (#4002),a
        call unmap_vram_test
        ld e,1
        call win_set_screen
        ld a,1
        ld b,2
        ld hl,2
        call read_pixel
        ld (row_width),a
        ld de,back_window
        call win_open
        call map_vram_test
        ld a,2
        out (#89),a
        ld a,#b0
        ld (#4142),a
        call unmap_vram_test
        call win_close
        ld a,1
        ld b,2
        ld hl,2
        call read_pixel
        ld b,a
        ld a,(row_width)
        cp b
        ld a,80
        call t_expect_z
        call win_close
        xor a
        ld b,2
        ld hl,2
        call read_pixel
        ld b,a
        ld a,(expected_pixel)
        cp b
        ld a,81
        call t_expect_z
        ld a,(screen_id)
        cp 1
        ld a,82
        call t_expect_z
        ret

test_free_closes:
        xor a
        ld e,a
        call win_set_screen
        ld hl,6
        ld (back_window+WIN_WND_X),hl
        ld hl,6
        ld (back_window+WIN_WND_Y),hl
        ld hl,1
        ld (back_window+WIN_WND_WIDTH),hl
        ld (back_window+WIN_WND_HEIGHT),hl
        xor a
        ld b,6
        ld hl,6
        call read_pixel
        ld (expected_pixel),a
        ld de,back_window
        call win_open
        call map_vram_test
        ld a,6
        out (#89),a
        ld a,#cc
        ld (#4006),a
        call unmap_vram_test

        ; fini must not lose the modal background if a later fixed config
        ; collides with the current stack window (WIN2 here).
        ld d,0
        ld e,2
        call win_set_work_windows
        or a
        ld a,94
        call t_expect_z
        call win_free
        xor a
        ld b,6
        ld hl,6
        call read_pixel
        ld b,a
        ld a,(expected_pixel)
        cp b
        ld a,90
        call t_expect_z
        ld a,(backstore_depth)
        or a
        ld a,91
        call t_expect_z
        ld a,(backstore_pages)
        or a
        ld a,92
        call t_expect_z
        ld a,(mock_free_count)
        cp 1
        ld a,93
        call t_expect_z
        ret

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
