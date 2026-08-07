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
odd_fill:
        dw 1
        db 0
        dw 2,1
        db 1,0,0,0,0
odd_copy:
        db 0,0
        dw 0
        db 0
        dw 2
        db 0
        dw 3,1
one_ref:
        db 0,0
one_span:
        dw one_ref
        dw 1,608
        db 240,#08
one_item:
        db 0,0
        dw 0
        db 0
one_list:
        dw one_item
        dw 1
        db #08,0,0,0
one_map:
        dw one_ref
        dw 1,1
        dw 0,0
        dw 1,1
        dw 0
        db 0,#08,0,0
one_meta:
        dw one_ref
        db 1,1
        dw 0
        db 0,#08

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
        cp #82
        ld a,10
        call t_expect_z
        ld hl,(config_buffer+2)
        ld de,640
        or a
        sbc hl,de
        ld a,30
        call t_expect_z
        ld hl,(config_buffer+4)
        ld de,256
        or a
        sbc hl,de
        ld a,31
        call t_expect_z
        ld a,(config_buffer+12)
        cp 32
        ld a,32
        call t_expect_z
        ld a,(config_buffer+13)
        cp 16
        ld a,33
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

        ; Packed-mode validation must fail before touching any mapped window.
        ld a,16
        ld e,0
        call gfx_clear
        cp ERR_ARGUMENT
        ld a,34
        call t_expect_z
        ld ix,1
        ld iy,0
        ld de,2
        ld a,1
        call gfx_hline
        cp ERR_ARGUMENT
        ld a,35
        call t_expect_z
        ld de,odd_fill
        call gfx_fill_rect
        cp ERR_ARGUMENT
        ld a,36
        call t_expect_z
        ld de,odd_copy
        call gfx_copy_rect
        cp ERR_ARGUMENT
        ld a,37
        call t_expect_z
        ld de,0
        ld ix,1
        ld iy,0
        xor a
        call gfx_draw_tile
        cp ERR_ARGUMENT
        ld a,38
        call t_expect_z

        ; Full-tile and clip limits use 32x16 geometry; span shares the safe
        ; batch path and the same logical-page lookup.
        ld de,0
        ld ix,608
        ld iy,#00f0
        xor a
        call gfx_draw_tile
        or a
        ld a,45
        call t_expect_z
        ld de,0
        ld ix,610
        ld iy,#00f0
        xor a
        call gfx_draw_tile
        cp ERR_ARGUMENT
        ld a,46
        call t_expect_z
        ld de,0
        ld ix,638
        ld iy,#00ff
        xor a
        call gfx_draw_tile_clip
        or a
        ld a,47
        call t_expect_z
        ld de,one_span
        call gfx_draw_tile_span
        or a
        ld a,48
        call t_expect_z

        ; Every exact-transparency entry must dispatch and share the safe
        ; TileRef/page path. The emulator does not model hardware #FF keying,
        ; so byte composition itself is asserted in t_libcall and host tests.
        ld de,0
        ld ix,0
        ld iy,0
        ld a,#08
        call gfx_draw_tile_transparent
        or a
        ld a,56
        call t_expect_z
        ld de,0
        ld ix,638
        ld iy,#00ff
        ld a,#08
        call gfx_draw_tile_clip_transparent
        or a
        ld a,57
        call t_expect_z
        ld de,one_span
        call gfx_draw_tile_span_transparent
        or a
        ld a,58
        call t_expect_z
        ld de,one_list
        call gfx_draw_tile_list_transparent
        or a
        ld a,59
        call t_expect_z
        ld de,one_map
        call gfx_draw_tilemap_transparent
        or a
        ld a,60
        call t_expect_z
        ld de,one_meta
        call gfx_draw_metatile_transparent
        or a
        ld a,61
        call t_expect_z

        ; The rightmost odd pixel is legal. Mapping, PORT_Y and IFF are
        ; restored after its nibble read-modify-write.
        ld a,#37
        out (EXPECT_VRAM_PORT),a
        ld a,#55
        out (#89),a
        ei
        nop
        ld ix,639
        ld iy,#00ff
        ld a,15
        ld e,0
        call gfx_put_pixel
        call t_keep_a
        ld a,39
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,40
        call t_expect_z
        ; z88dk-ticks does not model Sprinter page/PORT_Y readback; the
        ; source-level ABI test asserts the exact unmap sequence instead.
        ld a,i
        ld a,43
        call t_expect_pe
        di
        ld ix,638
        ld a,7
        call gfx_put_pixel
        ld a,i
        ld a,44
        call t_expect_po

        ; KEY_FF colour 15 is a successful no-op, including through the direct
        ; entry path used by Pascal clients. It must return A=0 without mapping.
        ld ix,638
        ld iy,#00ff
        ld a,15
        ld e,#08
        call gfx_put_pixel
        call t_keep_a
        ld a,49
        call t_expect_nc
        ld a,(t_saved_a)
        or a
        ld a,50
        call t_expect_z

        ; Zero-length drawing must return before validation/mapping, while an
        ; out-of-range tile slot must report ERR_TILE deterministically.
        ld ix,640
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
        define GFX640_TEST_BUILD
        include "../../gfx640.asm"

        assert $ < TEST_RESULT
