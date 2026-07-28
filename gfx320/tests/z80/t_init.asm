        device noslot64k

        ifndef ORIGIN_VALUE
ORIGIN_VALUE equ #c000
        endif
        ifndef STACK_VALUE
STACK_VALUE equ #bff0
        endif
        ifndef EXPECT_CODE_WIN
EXPECT_CODE_WIN equ 3
        endif
        ifndef EXPECT_STACK_WIN
EXPECT_STACK_WIN equ 2
        endif
        ifndef EXPECT_VRAM_WIN
EXPECT_VRAM_WIN equ 1
        endif
        ifndef EXPECT_VRAM_PORT
EXPECT_VRAM_PORT equ #a2
        endif
        ifndef EXPECT_VRAM_BASE
EXPECT_VRAM_BASE equ #4000
        endif

        org 0
        jp start

        include "harness.inc"

config_buffer:
        db 16
        ds 15
page_fixture:
        db #31,#a7

start:
        ld sp,STACK_VALUE
        call t_begin

        ; The real entry-0 hook must return A=0, CF=0 and derive windows from
        ; its relocated address and the caller stack.
        call gfx_init
        call t_keep_a
        ld a,1
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,2
        call t_expect_z

        ld a,(code_window)
        cp EXPECT_CODE_WIN
        ld a,3
        call t_expect_z
        ld a,(stack_window)
        cp EXPECT_STACK_WIN
        ld a,4
        call t_expect_z
        ld a,(vram_window)
        cp EXPECT_VRAM_WIN
        ld a,5
        call t_expect_z
        ld a,(vram_port)
        cp EXPECT_VRAM_PORT
        ld a,6
        call t_expect_z
        ld hl,(vram_base)
        ld de,EXPECT_VRAM_BASE
        or a
        sbc hl,de
        ld a,7
        call t_expect_z

        ; gfx_get_config must expose the same automatically selected windows.
        ld de,config_buffer
        call gfx_get_config
        call t_keep_a
        ld a,8
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,9
        call t_expect_z
        ld a,(config_buffer+1)
        cp #81
        ld a,10
        call t_expect_z
        ld a,(config_buffer+6)
        cp EXPECT_VRAM_WIN
        ld a,11
        call t_expect_z
        ld a,(config_buffer+7)
        or a
        ld a,12
        call t_expect_z
        ld a,(config_buffer+8)
        cp EXPECT_CODE_WIN
        ld a,13
        call t_expect_z

        ; Selecting the code or stack window must fail and keep the previous
        ; mapping. This catches regressions in window auto-detection.
        ld e,EXPECT_CODE_WIN
        call gfx_set_vram_window
        call t_keep_a
        ld a,14
        call t_expect_c
        ld a,(t_saved_a)
        cp ERR_WINDOW
        ld a,15
        call t_expect_z
        ld e,EXPECT_STACK_WIN
        call gfx_set_vram_window
        call t_keep_a
        ld a,16
        call t_expect_c
        ld a,(t_saved_a)
        cp ERR_WINDOW
        ld a,17
        call t_expect_z
        ld a,(vram_window)
        cp EXPECT_VRAM_WIN
        ld a,18
        call t_expect_z

        ; Page-table setup is pure CPU code and is part of the tile-loader
        ; contract used immediately after init.
        ld de,page_fixture
        ld ix,2
        call gfx_set_page_table
        call t_keep_a
        ld a,19
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,20
        call t_expect_z
        ld a,(page_count)
        cp 2
        ld a,21
        call t_expect_z
        ld a,(page_table)
        cp #31
        ld a,22
        call t_expect_z
        ld a,(page_table+1)
        cp #a7
        ld a,23
        call t_expect_z

        ; Zero-length drawing must return before validation/mapping, while an
        ; out-of-range tile slot must report ERR_TILE deterministically.
        ld ix,320
        ld iy,0
        ld de,0
        xor a
        call gfx_hline
        call t_keep_a
        ld a,24
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,25
        call t_expect_z
        ld de,#0040
        ld ix,0
        ld iy,0
        xor a
        call gfx_draw_tile
        cp ERR_TILE
        ld a,26
        call t_expect_z

        ; Repeated init is idempotent and must not discard client state.
        call gfx_init
        call t_keep_a
        ld a,27
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,28
        call t_expect_z
        ld a,(page_table_valid)
        cp 1
        ld a,29
        call t_expect_z

        call t_end
        halt

        ; sjasmplus --raw does not materialize gaps created by ORG. Emit the
        ; gap so z88dk-ticks really loads the library at the tested window.
        ds ORIGIN_VALUE-$,0
        assert $ == ORIGIN_VALUE
        define GFX320_TEST_BUILD
        include "../../gfx320.asm"

        assert $ < TEST_RESULT
