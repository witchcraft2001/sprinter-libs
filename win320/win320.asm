; WIN320.DLL — stage 2 windows, dirty update and modal backstore.
; Public ABI is described in specs.md and win320.inc.

        ifndef WIN320_TEST_BUILD
        org 0
        endif

        db "L0"
        dw 0,0,0,0
        db 30,7
        dw 2026
        dw #0001                    ; implementation 0.1, public ABI is 1.0
        db "WIN320 GUI",0
        ds 16-11,0

        assert ($ & #ff) == #20

        jp win_init                 ; 0
        jp win_free                 ; 1
        jp win_set_work_windows     ; 2
        jp win_set_screen           ; 3
        jp win_get_version          ; 4
        jp win_get_config           ; 5
        jp win_load_font            ; 6
        jp win_set_theme            ; 7
        jp win_set_text_format      ; 8
        jp win_set_origin           ; 9
        jp win_style                ; 10
        jp win_fill_rect            ; 11
        jp win_frame                ; 12
        jp win_panel                ; 13
        jp win_separator            ; 14
        jp win_invert_rect          ; 15
        jp win_focus_rect           ; 16
        jp win_label                ; 17
        jp win_button               ; 18
        jp win_draw                 ; 19
        jp win_draw_item            ; 20
        jp win_update               ; 21
        jp win_set_backstore        ; 22
        jp win_open                 ; 23
        jp win_close                ; 24
        jp win_reserved             ; 25
        jp win_reserved             ; 26
        jp win_reserved             ; 27
        jp win_reserved             ; 28
        jp win_reserved             ; 29
        jp win_reserved             ; 30
        jp win_reserved             ; 31
        jp win_reserved             ; 32
        jp win_reserved             ; 33
        jp win_reserved             ; 34
        jp win_reserved             ; 35
        jp win_reserved             ; 36

        include "win320.inc"
        include "../common/fontlayout.inc"

PAGE_PORT0              equ #82
YPORT                   equ #89
DSS_OPEN                equ #11
DSS_CLOSE               equ #12
DSS_READ                equ #13
DSS_GETMEM              equ #3d
DSS_FREEMEM             equ #3e
BIOS_GETMEMBLKPAGES     equ #c5
FONT_STAGE_SIZE         equ 128
VIDEO_PAGE              equ #50
SCREEN_STRIDE           equ #0140

; ---- public stage-0 entry points ------------------------------------------

win_init:
        ld (init_handle),a
        ld a,#ff
        ld (font_block),a
        ld (font_page),a
        ld (temp_font_block),a
        ld (temp_font_page),a
        ld (old_font_block),a
        ld (data_window),a
        ld (vram_window),a
        xor a
        ld (screen_id),a
        ld (origin_x),a
        ld (origin_x+1),a
        ld (origin_y),a
        ld (text_format),a
        ld (backstore_pages),a
        ld (backstore_depth),a
        ld (backstore_alloc_page),a
        ld (backstore_alloc_offset),a
        ld (backstore_alloc_offset+1),a
        ld (textcore_color_valid),a
        ld a,#f0
        ld (textcore_palette_base),a
        ld hl,default_theme
        ld de,current_theme
        ld bc,WIN_THEME_SIZE
        ldir
        ld a,#c0
        out (YPORT),a

        ld hl,win_init
        ld a,h
        and #c0
        rlca
        rlca
        ld (code_window),a
        call select_data_window
        jp c,.window_error

        ld b,1
        ld c,DSS_GETMEM
        call win_dss_call
        jp c,.memory_error
        ld (font_block),a
        ld b,1
        ld hl,font_page
        ld c,BIOS_GETMEMBLKPAGES
        call win_bios_call
        jp c,.memory_cleanup

        ld hl,io_scratch
        ld de,WF32_HEADER_SIZE
        call read_payload
        jp c,.font_cleanup
        ld a,d
        or a
        jp nz,.font_cleanup
        ld a,e
        cp WF32_HEADER_SIZE
        jp nz,.font_cleanup
        call validate_wf32_header
        jp c,.font_cleanup

        xor a
        ld (copy_offset),a
        ld (copy_offset+1),a
        ld a,WF32_HEADER_SIZE
        ld (copy_count),a
        ld hl,io_scratch
        call copy_scratch_to_font

        ld hl,(font_data_size)
        ld (payload_remaining),hl
        ld hl,WF32_HEADER_SIZE
        ld (copy_offset),hl
.read_loop:
        ld hl,(payload_remaining)
        ld a,h
        or l
        jr z,.validate
        ld a,h
        or a
        ld a,FONT_STAGE_SIZE
        jr nz,.count_ready
        ld a,l
        cp FONT_STAGE_SIZE
        jr c,.count_ready
        ld a,FONT_STAGE_SIZE
.count_ready:
        ld (copy_count),a
        ld e,a
        ld d,0
        ld hl,io_scratch
        call read_payload
        jr c,.font_cleanup
        ld a,d
        or a
        jr nz,.font_cleanup
        ld a,(copy_count)
        cp e
        jr nz,.font_cleanup
        ld hl,io_scratch
        call copy_scratch_to_font
        ld a,(copy_count)
        ld e,a
        ld d,0
        ld hl,(payload_remaining)
        or a
        sbc hl,de
        ld (payload_remaining),hl
        ld hl,(copy_offset)
        add hl,de
        ld (copy_offset),hl
        jr .read_loop

.validate:
        call validate_loaded_font
        jr c,.font_cleanup
        call cache_loaded_font_widths
        xor a
        scf
        ccf
        ret

.font_cleanup:
        call release_font_page
        ld a,WIN_ERR_FONT
        scf
        ret
.memory_cleanup:
        call release_font_page
.memory_error:
        ld a,WIN_ERR_MEMORY
        scf
        ret
.window_error:
        ld a,WIN_ERR_WINDOW
        scf
        ret

win_free:
        call s2_close_all
        call s1_release_temp_font
        call s1_release_old_font
        call release_font_page
        xor a
        ld (backstore_pages),a
        ld (backstore_depth),a
        ld (backstore_alloc_page),a
        ld (backstore_alloc_offset),a
        ld (backstore_alloc_offset+1),a
        ld a,#c0
        out (YPORT),a
        xor a
        scf
        ccf
        ret

; D=data window, E=VRAM window; each 0..3 or #ff AUTO.
win_set_work_windows:
        push bc
        ld a,d
        call validate_window_setting
        jr c,.bad
        ld a,e
        call validate_window_setting
        jr c,.bad
        ld a,d
        cp #ff
        jr z,.store
        ld b,a
        ld a,e
        cp #ff
        jr z,.store
        cp b
        jr z,.window
.store:
        ld a,d
        ld (data_window),a
        ld a,e
        ld (vram_window),a
        pop bc
        xor a
        scf
        ccf
        ret
.window:
        pop bc
        ld a,WIN_ERR_WINDOW
        or a
        ret
.bad:
        pop bc
        or a
        ret

win_set_screen:
        ld a,e
        cp 2
        jr nc,.bad
        ld (screen_id),a
        xor a
        scf
        ccf
        ret
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

win_get_version:
        ld d,1
        ld e,0
        ld ix,WIN_CAP_PASCAL_STR
        xor a
        scf
        ccf
        ret

win_get_config:
        push hl
        push bc
        ld (config_dest),de
        ld a,(de)
        or a
        jr z,.bad
        cp WIN_CONFIG_SIZE
        jr c,.count_ready
        ld a,WIN_CONFIG_SIZE
.count_ready:
        ld (config_count),a
        call validate_config_destination
        jr c,.bad
        call build_config
        ld hl,config_buffer
        ld de,(config_dest)
        ld a,(config_count)
        ld c,a
        ld b,0
        ldir
        pop bc
        pop hl
        xor a
        scf
        ccf
        ret
.bad:
        pop bc
        pop hl
        ld a,WIN_ERR_ARGUMENT
        or a
        ret

        include "stage1.inc"
        include "stage2.inc"

win_reserved:
        ld a,WIN_ERR_UNSUPPORTED
        or a
        ret

; ---- configuration helpers ------------------------------------------------

validate_window_setting:
        cp #ff
        jr z,.ok
        cp 4
        jr nc,.argument
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.window
.ok:
        or a
        ret
.argument:
        ld a,WIN_ERR_ARGUMENT
        scf
        ret
.window:
        ld a,WIN_ERR_WINDOW
        scf
        ret

select_data_window:
        ld hl,0
        add hl,sp
        ld a,h
        and #c0
        rlca
        rlca
        ld (stack_window),a
        ld a,(data_window)
        cp #ff
        jr z,.auto
        call data_candidate_ok
        jr c,.failed
        jr configure_work_window
.auto:
        xor a
        call data_candidate_ok
        jr nc,configure_work_window
        ld a,1
        call data_candidate_ok
        jr nc,configure_work_window
        ld a,2
        call data_candidate_ok
        jr nc,configure_work_window
        ld a,3
        call data_candidate_ok
        jr nc,configure_work_window
.failed:
        scf
        ret

data_candidate_ok:
        ld b,a
        ld a,(code_window)
        cp b
        jr z,.bad
        ld a,(stack_window)
        cp b
        jr z,.bad
        ld a,b
        or a
        ret
.bad:
        ld a,b
        scf
        ret

configure_work_window:
        ld (work_window),a
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,PAGE_PORT0
        ld (work_page_port),a
        ld a,b
        rrca
        rrca
        ld h,a
        ld l,0
        ifdef WIN320_TEST_BUILD
        ld hl,win_test_font_memory
        endif
        ld (work_base),hl
        or a
        ret

build_config:
        ld a,WIN_CONFIG_SIZE
        ld (config_buffer+0),a
        ld a,#81
        ld (config_buffer+1),a
        ld hl,320
        ld (config_buffer+2),hl
        ld hl,256
        ld (config_buffer+4),hl
        ld a,(vram_window)
        ld (config_buffer+6),a
        ld a,(code_window)
        ld (config_buffer+7),a
        ld a,(screen_id)
        ld (config_buffer+8),a
        ld a,(backstore_pages)
        ld (config_buffer+9),a
        ld a,(backstore_depth)
        ld (config_buffer+10),a
        ld a,FONT320_HEIGHT
        ld (config_buffer+11),a
        ld hl,WIN_CAP_PASCAL_STR
        ld (config_buffer+12),hl
        ld a,(font_page)
        ld (config_buffer+14),a
        ld a,(data_window)
        ld (config_buffer+15),a
        ld hl,(origin_x)
        ld (config_buffer+16),hl
        ld a,(origin_y)
        ld (config_buffer+18),a
        ld a,(text_format)
        ld (config_buffer+19),a
        ret

validate_config_destination:
        ld hl,(config_dest)
        ld a,h
        and #c0
        ld b,a
        ld a,(code_window)
        rrca
        rrca
        and #c0
        cp b
        jr z,.bad
        ld a,(config_count)
        dec a
        ld e,a
        ld d,0
        add hl,de
        jr c,.bad
        ld a,h
        and #c0
        ld b,a
        ld a,(code_window)
        rrca
        rrca
        and #c0
        cp b
        jr z,.bad
        or a
        ret
.bad:
        scf
        ret

; ---- WF32 loading and validation ------------------------------------------

read_payload:
        ld a,(init_handle)
        ld c,DSS_READ
        jp win_dss_call

validate_wf32_header:
        ld hl,io_scratch
        ld a,(hl)
        cp 'W'
        jr nz,.bad
        inc hl
        ld a,(hl)
        cp 'F'
        jr nz,.bad
        inc hl
        ld a,(hl)
        cp '3'
        jr nz,.bad
        inc hl
        ld a,(hl)
        cp '2'
        jr nz,.bad
        inc hl
        ld a,(hl)
        cp WF32_VERSION
        jr nz,.bad
        inc hl
        ld a,(hl)
        cp FONT320_HEIGHT
        jr nz,.bad
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (font_data_size),de
        ld hl,FONT320_BITMAP
        or a
        sbc hl,de
        jr z,.min_ok
        jr nc,.bad
.min_ok:
        ld hl,WF32_MAX_DATA_SIZE
        or a
        sbc hl,de
        jr c,.bad
        or a
        ret
.bad:
        scf
        ret

copy_scratch_to_font:
        push hl
        call map_font_page
        pop hl
        ld de,(work_base)
        ld bc,(copy_offset)
        ex de,hl
        add hl,bc
        ex de,hl
        ifdef WIN320_TEST_BUILD
        ld a,(copy_count)
        ld c,a
        ld b,0
        ldir
        else
        ld a,(copy_count)
        ld (copy_stage_size+1),a
        ld d,d
copy_stage_size:
        ld a,0
        ld b,b
        ld l,l
        ld a,(hl)
        ld (de),a
        ld b,b
        endif
        jp unmap_font_page

validate_loaded_font:
        ld hl,FONT320_BITMAP
        ld (expected_offset),hl
        xor a
        ld (validation_index),a
.chunk:
        call load_validation_tables
        ld ix,io_scratch
        ld b,32
.glyph:
        push bc
        ld a,(ix+0)
        cp 1
        jr c,.bad_pop
        cp 9
        jr nc,.bad_pop
        dec a
        ld e,a
        ld d,0
        ld hl,font_width_masks
        add hl,de
        ld c,(hl)
        ld a,(ix+96)
        ld d,a
        ld a,c
        cpl
        and d
        jr nz,.bad_pop
        ld c,d
        ld l,(ix+32)
        ld h,(ix+64)
        ld de,(expected_offset)
        or a
        sbc hl,de
        jr nz,.bad_pop
        ld a,c
        ld b,8
.bits:
        rlca
        jr nc,.next_bit
        ld hl,(expected_offset)
        ld de,8
        add hl,de
        ld (expected_offset),hl
.next_bit:
        djnz .bits
        ld hl,(font_data_size)
        ld de,(expected_offset)
        or a
        sbc hl,de
        jr c,.bad_pop
        inc ix
        pop bc
        djnz .glyph
        ld a,(validation_index)
        add a,32
        ld (validation_index),a
        jr nz,.chunk
        ld hl,(expected_offset)
        ld de,(font_data_size)
        or a
        sbc hl,de
        ret z
        scf
        ret
.bad_pop:
        pop bc
        scf
        ret

load_validation_tables:
        call map_font_page
        ld a,(validation_index)
        ld c,a
        ld b,0
        ld hl,(work_base)
        ld de,WF32_HEADER_SIZE
        add hl,de
        add hl,bc
        ld de,io_scratch
        push bc
        ld bc,32
        ldir
        pop bc
        ld hl,(work_base)
        ld de,WF32_HEADER_SIZE+FONT320_OFFSETS_LO
        add hl,de
        add hl,bc
        ld de,io_scratch+32
        push bc
        ld bc,32
        ldir
        pop bc
        ld hl,(work_base)
        ld de,WF32_HEADER_SIZE+FONT320_OFFSETS_HI
        add hl,de
        add hl,bc
        ld de,io_scratch+64
        push bc
        ld bc,32
        ldir
        pop bc
        ld hl,(work_base)
        ld de,WF32_HEADER_SIZE+FONT320_COLUMN_MAPS
        add hl,de
        add hl,bc
        ld de,io_scratch+96
        ld bc,32
        ldir
        jp unmap_font_page

cache_loaded_font_widths:
        call map_font_page
        ld hl,(work_base)
        ld de,WF32_HEADER_SIZE+FONT320_WIDTHS
        add hl,de
        ld de,font_width_cache
        ld bc,FONT320_GLYPHS
        ldir
        jp unmap_font_page

map_font_page:
        ld a,i
        jp po,.interrupts_off
        ld a,1
        jr .save_iff
.interrupts_off:
        xor a
.save_iff:
        ld (saved_iff),a
        di
        call read_work_page
        ld (saved_work_page),a
        ld a,(font_page)
        jp write_work_page

unmap_font_page:
        ld a,#c0
        out (YPORT),a
        ld a,(saved_work_page)
        call write_work_page
        ld a,(saved_iff)
        or a
        ret z
        ei
        ret

read_work_page:
        ifdef WIN320_TEST_BUILD
        jp win_test_read_page
        else
        ld a,(work_page_port)
        ld c,a
        in a,(c)
        ret
        endif

write_work_page:
        ifdef WIN320_TEST_BUILD
        jp win_test_write_page
        else
        ld b,a
        ld a,(work_page_port)
        ld c,a
        ld a,b
        out (c),a
        ret
        endif

release_font_page:
        ld a,(font_block)
        cp #ff
        ret z
        ld c,DSS_FREEMEM
        call win_dss_call
        ret c
        ld a,#ff
        ld (font_block),a
        ld (font_page),a
        ret

win_dss_call:
        ifdef WIN320_TEST_BUILD
        jp win_test_dss_call
        else
        rst #10
        ret
        endif

win_bios_call:
        ifdef WIN320_TEST_BUILD
        jp win_test_bios_call
        else
        rst #08
        ret
        endif

; ---- common text core (used publicly from stage 1) ------------------------

        include "../common/textcore320.inc"

; ---- runtime state ---------------------------------------------------------

code_window:            db #ff
stack_window:           db #ff
data_window:            db #ff
vram_window:            db #ff
work_window:            db #ff
work_page_port:         db PAGE_PORT0
work_base:              dw 0
saved_work_page:        db 0
saved_iff:              db 0
screen_id:              db 0
origin_x:               dw 0
origin_y:               db 0
text_format:            db WIN_TXT_ASCIIZ
backstore_pages:        db 0
backstore_depth:        db 0
font_block:             db #ff
font_page:              db #ff
font_data_size:         dw 0
init_handle:            db 0
payload_remaining:      dw 0
copy_offset:            dw 0
copy_count:             db 0
validation_index:       db 0
expected_offset:        dw 0
config_dest:            dw 0
config_count:           db 0
config_buffer:          ds WIN_CONFIG_SIZE,0
io_scratch:             ds FONT_STAGE_SIZE,0
font_width_cache:       ds FONT320_GLYPHS,0

font_width_masks:
        db #80,#c0,#e0,#f0,#f8,#fc,#fe,#ff
