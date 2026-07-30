        device noslot64k

        org 0
        jp start

        include "harness.inc"

mock_fault:         db 0
mock_free_count:    db 0
mock_page_latch:    db #55
mock_file_ptr:      dw mock_payload
mock_read_count:    dw 0
mock_read_calls:    db 0
saved_test_sp:      dw 0
auto_code:          db 0
auto_stack:         db 0
auto_failed:        db 0
actual_hl:          dw 0
actual_bc:          dw 0

test_config_buffer:
        db 20
        ds 19,0

reset_mock:
        xor a
        ld (mock_fault),a
        ld (mock_free_count),a
        ld (mock_read_calls),a
        ld a,#55
        ld (mock_page_latch),a
        ld hl,mock_payload
        ld (mock_file_ptr),hl
        ret

win_test_dss_call:
        ld a,c
        cp #3d
        jr z,.getmem
        cp #3e
        jr z,.freemem
        cp #13
        jr z,.read
        ld a,#ee
        scf
        ret
.getmem:
        ld a,(mock_fault)
        cp 1
        jr z,.fail
        ld a,#42
        or a
        ret
.freemem:
        ld hl,mock_free_count
        inc (hl)
        xor a
        ret
.read:
        ld a,(mock_read_calls)
        inc a
        ld (mock_read_calls),a
        ld a,(mock_fault)
        cp 3
        jr z,.fail
        ld (mock_read_count),de
        push hl
        ld hl,(mock_file_ptr)
        pop de
        ld bc,(mock_read_count)
        ldir
        ld (mock_file_ptr),hl
        ld de,(mock_read_count)
        ld a,(mock_fault)
        cp 4
        jr nz,.maybe_corrupt
        dec de
        xor a
        ret
.maybe_corrupt:
        cp 5
        jr nz,.ok
        ld a,(mock_read_calls)
        cp 1
        jr nz,.ok
        ld hl,io_scratch
        ld (hl),'X'
.ok:
        xor a
        ret
.fail:
        ld a,#f1
        scf
        ret

win_test_bios_call:
        ld a,(mock_fault)
        cp 2
        jr z,.fail
        ld (hl),#77
        xor a
        ret
.fail:
        ld a,#f2
        scf
        ret

win_test_read_page:
        ld a,(mock_page_latch)
        ret

win_test_write_page:
        ld (mock_page_latch),a
        ret

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
        ld a,(code_window)
        cp 3
        ld a,3
        call t_expect_z
        ld a,(font_block)
        cp #42
        ld a,4
        call t_expect_z
        ld a,(font_page)
        cp #77
        ld a,5
        call t_expect_z
        ld a,(mock_page_latch)
        cp #55
        ld a,6
        call t_expect_z
        ld a,(mock_free_count)
        or a
        ld a,7
        call t_expect_z

        ld de,test_config_buffer
        call win_get_config
        call t_keep_a
        ld a,8
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,9
        call t_expect_z
        ld a,(test_config_buffer+0)
        cp 20
        ld a,10
        call t_expect_z
        ld a,(test_config_buffer+1)
        cp #81
        ld a,11
        call t_expect_z
        ld a,(test_config_buffer+7)
        cp 3
        ld a,12
        call t_expect_z
        ld a,(test_config_buffer+14)
        cp #77
        ld a,13
        call t_expect_z
        ld a,(test_config_buffer+15)
        cp #ff
        ld a,14
        call t_expect_z

        ; A caller buffer may live in any application window WIN0..WIN2.
        ld a,20
        ld (#5000),a
        ld de,#5000
        call win_get_config
        or a
        ld a,40
        call t_expect_z
        ld a,(#5000+14)
        cp #77
        ld a,41
        call t_expect_z
        ld a,20
        ld (#9000),a
        ld de,#9000
        call win_get_config
        or a
        ld a,42
        call t_expect_z
        ld a,(#9000+7)
        cp 3
        ld a,43
        call t_expect_z
        ld de,#c100
        call win_get_config
        cp WIN_ERR_ARGUMENT
        ld a,44
        call t_expect_z

        ld hl,#1234
        ld bc,#5678
        ld de,test_config_buffer
        call win_get_config
        ld (actual_hl),hl
        ld (actual_bc),bc
        ld hl,(actual_hl)
        ld de,#1234
        or a
        sbc hl,de
        ld a,46
        call t_expect_z
        ld hl,(actual_bc)
        ld de,#5678
        or a
        sbc hl,de
        ld a,47
        call t_expect_z

        call test_auto_window_pairs
        ld a,(auto_failed)
        or a
        ld a,45
        call t_expect_z
        ld a,3
        ld (code_window),a

        call win_get_version
        call t_keep_a
        ld a,15
        call t_expect_nc
        ld a,d
        cp 1
        ld a,16
        call t_expect_z
        ld a,e
        or a
        ld a,17
        call t_expect_z

        ld d,0
        ld e,1
        call win_set_work_windows
        call t_keep_a
        ld a,18
        call t_expect_nc
        ld a,(data_window)
        or a
        ld a,19
        call t_expect_z
        ld a,(vram_window)
        cp 1
        ld a,20
        call t_expect_z
        ld d,1
        ld e,1
        call win_set_work_windows
        cp WIN_ERR_WINDOW
        ld a,21
        call t_expect_z
        ld a,(data_window)
        or a
        ld a,22
        call t_expect_z

        ld e,1
        call win_set_screen
        call t_keep_a
        ld a,23
        call t_expect_nc
        ld a,(screen_id)
        cp 1
        ld a,24
        call t_expect_z
        call win_reserved
        cp WIN_ERR_UNSUPPORTED
        ld a,25
        call t_expect_z

        call win_free
        ld a,(mock_free_count)
        cp 1
        ld a,26
        call t_expect_z
        call win_free
        ld a,(mock_free_count)
        cp 1
        ld a,27
        call t_expect_z

        ; GETMEM failure: no page is owned and free is not attempted.
        call reset_mock
        ld a,1
        ld (mock_fault),a
        ld a,#33
        call win_init
        call t_keep_a
        ld a,28
        call t_expect_c
        ld a,(t_saved_a)
        cp WIN_ERR_MEMORY
        ld a,29
        call t_expect_z
        ld a,(mock_free_count)
        or a
        ld a,30
        call t_expect_z

        ; BIOS page-list failure frees the allocated block exactly once.
        call reset_mock
        ld a,2
        ld (mock_fault),a
        ld a,#33
        call win_init
        call t_keep_a
        ld a,31
        call t_expect_c
        ld a,(t_saved_a)
        cp WIN_ERR_MEMORY
        ld a,32
        call t_expect_z
        ld a,(mock_free_count)
        cp 1
        ld a,33
        call t_expect_z

        ; Short and malformed payloads are FONT errors and also unwind once.
        call reset_mock
        ld a,4
        ld (mock_fault),a
        ld a,#33
        call win_init
        call t_keep_a
        ld a,34
        call t_expect_c
        ld a,(t_saved_a)
        cp WIN_ERR_FONT
        ld a,35
        call t_expect_z
        ld a,(mock_free_count)
        cp 1
        ld a,36
        call t_expect_z

        call reset_mock
        ld a,5
        ld (mock_fault),a
        ld a,#33
        call win_init
        call t_keep_a
        ld a,37
        call t_expect_c
        ld a,(t_saved_a)
        cp WIN_ERR_FONT
        ld a,38
        call t_expect_z
        ld a,(mock_free_count)
        cp 1
        ld a,39
        call t_expect_z

        call t_end
        halt

; Exercise every code/SP-window pair against the deterministic lowest-free
; AUTO policy. The test DLL itself remains in WIN3; only the state inspected
; by the pure resolver is varied.
test_auto_window_pairs:
        ld (saved_test_sp),sp
        xor a
        ld (auto_failed),a
        ld (auto_code),a
.code:
        xor a
        ld (auto_stack),a
.stack:
        ld a,(auto_code)
        ld (code_window),a
        ld a,#ff
        ld (data_window),a
        ld a,(auto_stack)
        add a,a
        ld e,a
        ld d,0
        ld hl,auto_stack_values
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld sp,hl
        call select_data_window
        ld sp,(saved_test_sp)
        jr c,.failed
        xor a
.expected:
        ld b,a
        ld a,(auto_code)
        cp b
        jr z,.next_expected
        ld a,(auto_stack)
        cp b
        jr nz,.compare
.next_expected:
        ld a,b
        inc a
        jr .expected
.compare:
        ld a,(work_window)
        cp b
        jr z,.next_pair
.failed:
        ld a,1
        ld (auto_failed),a
.next_pair:
        ld a,(auto_stack)
        inc a
        ld (auto_stack),a
        cp 4
        jr nz,.stack
        ld a,(auto_code)
        inc a
        ld (auto_code),a
        cp 4
        jr nz,.code
        ret

auto_stack_values:
        dw #2ff0,#6ff0,#aff0,#eff0

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
