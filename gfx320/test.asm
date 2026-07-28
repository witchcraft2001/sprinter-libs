        org #8100-512

; Visual ABI 1.0 test. GFX320.DLL must be beside this EXE.
        dw #5845
        db #45,#00
        dw #0200,#0000,#0000,#0000,#0000,#0000
        dw start,start,#bfff
        ds 490

        include "gfx320.inc"

DSS_APPINFO            equ #47
APPINFO_EXE_HOMEDIR    equ 1
DSS_GETMEM             equ #3d
DSS_FREEMEM            equ #3e
BIOS_GETMEMBLKPAGES    equ #c5

start:
        xor a
        ld (gfx_status),a
        ld (load_reason),a
        ld (load_dsserr),a
        ld (test_stage),a
        ld (pixel_observed),a
        ld (tile_allocated),a
        ld (handle),a
        ld (handle+1),a
        ; Keep the visual result displayed until a key is pressed.
        ld hl,welcome
        ld c,#5c
        rst #10
        ld c,#51
        rst #10
        ld (old_mode),a
        ld a,b
        ld (old_screen),a
        ld bc,#0050
        ld a,#81
        rst #10
        ld c,#51
        rst #10
        ld a,b
        ld (test_screen),a
        call load_test_palette
        ; Early sentinel remains visible if DLL loading or init fails.
        ld a,15
        ld e,0
        call draw_cpu_probe
        call load_library
        jp c,failed
        ld (handle),hl
        ld a,1
        ld (test_stage),a          ; explicit GFX_INIT
        ld hl,(handle)
        ld b,GFX_INIT
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ld a,2
        ld (test_stage),a          ; GFX_GET_CONFIG
        ld hl,(handle)
        ld de,gfx_config
        ld b,GFX_GET_CONFIG
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ld a,3
        ld (test_stage),a          ; GFX_PALETTE_LOAD256
        ld hl,(handle)
        ld de,test_palette_rgb
        ld a,GFX_PAL_BOTH
        ld b,GFX_PALETTE_LOAD256
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ; Allocate a physical 16K tile page and ask BIOS for its page number.
        ld b,1
        ld c,DSS_GETMEM
        rst #10
        jp c,failed_loaded
        ld (tile_block),a
        push af
        ld a,1
        ld (tile_allocated),a
        pop af
        ld hl,physical_pages
        ld c,BIOS_GETMEMBLKPAGES
        rst #08
        jp c,failed_loaded
        ; Map the allocated block temporarily to WIN0 and copy generated tiles.
        ; The executable code is in WIN2, so this cannot hide it or the stack.
        di
        in a,(#82)
        ld (saved_win0),a
        ld a,(physical_pages)
        out (#82),a
        ld hl,tiles
        ld de,#0000
        ld bc,16*256
        ldir
        ; Return WIN0 to its prior page — GFX itself uses WIN0 for tile source.
        ld a,(saved_win0)
        out (#82),a
        ei
        ld a,(physical_pages)
        ld (page_table),a
        ld a,4
        ld (test_stage),a          ; GFX_SET_PAGE_TABLE
        ld hl,(handle)
        ld de,page_table
        ld ix,1
        ld b,GFX_SET_PAGE_TABLE
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ld a,5
        ld (test_stage),a          ; self-check sequence
        call self_check
        jp c,failed_loaded
        or a
        jp nz,failed_gfx

        ; A black background, filled panels, horizontal and vertical lines.
        ld a,6
        ld (test_stage),a          ; GFX_CLEAR
        ld hl,(handle)
        ld a,0
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ifndef GFX_BENCH
        call panel_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call line_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call tile_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call advanced_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call copy_swap_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call restore_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call move_scroll_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call fade_demo
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        endif
        ifdef GFX_BENCH
        ; The benchmark build measures timing only: the shared visual demo is
        ; skipped so the final screen holds nothing but the four result bars.
        call benchmark_run
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        endif
        ; The DSS console shares the graphics VRAM field: printing while mode
        ; #81 is active writes symbol/attribute bytes straight into the
        ; picture (visible as garbage in the top rows).  Wait silently and
        ; print the summary only after the original mode is restored.
        ld c,#30
        rst #10

close:
        call free_tile_page
        call restore_screen
        ld hl,prompt
        ld c,#5c
        rst #10
        ld hl,(handle)
        call LIBMAN.l_free
        jr exit_test

restore_screen:
        ld a,(old_screen)
        ld b,a
        ld a,(old_mode)
        ld c,#50
        rst #10
        ret

exit_test:
        ld bc,#0041
        rst #10
failed_gfx:
        ld (gfx_status),a
        ; l_reason/l_dsserr are only valid after a libman failure. Keeping a
        ; stale loader stage here made a GFX API error look like LR_INIT.
        xor a
        ld (load_reason),a
        ld (load_dsserr),a
        jr failed_report
failed_loaded:
        ; Do not call back into a DLL that has just failed.  Apart from hiding
        ; the original status, a damaged load hook can make its free entry
        ; unsafe. DSS reclaims process allocations when this EXE exits.
        jr failed
failed:
        ld a,(LIBMAN.l_reason)
        ld (load_reason),a
        ld a,(LIBMAN.l_dss_error)
        ld (load_dsserr),a
failed_report:
        call restore_screen
        ld hl,error_message
        ld c,#5c
        rst #10
        ld a,(load_reason)
        ld hl,load_reason_hex
        call hex_to_ascii
        ld a,(load_dsserr)
        ld hl,load_dsserr_hex
        call hex_to_ascii
        ld a,(gfx_status)
        ld hl,gfx_status_hex
        call hex_to_ascii
        ld a,(test_stage)
        ld hl,test_stage_hex
        call hex_to_ascii
        ld a,(pixel_observed)
        ld hl,pixel_observed_hex
        call hex_to_ascii
        ld hl,error_detail
        ld c,#5c
        rst #10
        ld c,#30
        rst #10
        jr exit_test

; Convert A to two uppercase hexadecimal digits at HL.
hex_to_ascii:
        push af
        rrca
        rrca
        rrca
        rrca
        call hex_nibble
        ld (hl),a
        inc hl
        pop af
        call hex_nibble
        ld (hl),a
        ret
hex_nibble:
        and #0f
        add a,'0'
        cp '9'+1
        ret c
        add a,'A'-'9'-1
        ret

panel_demo:
        ld hl,(handle)
        ld de,rect_blue
        ld b,GFX_FILL_RECT
        call LIBMAN.l_call
        ret

load_test_palette:
        ; BIOS PIC_SET_PAL: 32 BGRA entries for the displayed screen.  Entries
        ; #10..#17 make GFX_ERR_* diagnostic probes visible.
        ld hl,test_palette
        ld de,#2000
        ld bc,#ffa4
        ld a,(test_screen)
        rst #08
        ret

free_tile_page:
        ld a,(tile_allocated)
        or a
        ret z
        xor a
        ld (tile_allocated),a
        ld a,(tile_block)
        ld c,DSS_FREEMEM
        rst #10
        ret

; Unaccelerated 8x8 white sentinel in the top-left corner. If it is visible but
; the rest is absent, mode/palette/VRAM are correct and the fault is inside DLL.
draw_cpu_probe:
        ld (probe_color),a
        ld a,e
        ld (probe_x),a
        di
        in a,(#a2)
        ld (probe_saved_page),a
        ld a,#50
        out (#a2),a
        in a,(#c9)
        and 1
        ld hl,#4000
        jr z,.base_ready
        ld de,#0140
        add hl,de
.base_ready:
        ld a,(probe_x)
        ld e,a
        ld d,0
        add hl,de
        ld (probe_base),hl
        ld c,0
        ld b,8
.row:   ld a,c
        out (#89),a
        push bc
        ld hl,(probe_base)
        ld b,8
.pixel: ld a,(probe_color)
        ld (hl),a
        inc hl
        djnz .pixel
        pop bc
        inc c
        djnz .row
        ld a,#c0
        out (#89),a
        ld a,(probe_saved_page)
        out (#a2),a
        ei
        ret

line_demo:
        ld hl,(handle)
        ld ix,20
        ld iy,#0028
        ld de,#0518              ; front buffer + length 280
        ld a,2
        ld b,GFX_HLINE
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld ix,160
        ld iy,#0030
        ld de,#04d0              ; front buffer + length 208 (to row 255)
        ld a,3
        ld b,GFX_VLINE
        call LIBMAN.l_call
        ret

tile_demo:
        ; A span makes a 16-tile top row.  The list puts individual tiles below.
        ld hl,(handle)
        ld de,span
        ld b,GFX_DRAW_TILE_SPAN
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,tile_list
        ld b,GFX_DRAW_TILE_LIST
        call LIBMAN.l_call
        ret

advanced_demo:
        ld hl,(handle)
        ld de,frame_rect
        ld b,GFX_DRAW_RECT
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,diagonal_line
        ld b,GFX_LINE
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,tilemap_desc
        ld b,GFX_DRAW_TILEMAP
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,metatile_desc
        ld b,GFX_DRAW_METATILE
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,#000f              ; logical page 0, slot 15
        ld ix,312
        ld iy,#00f8             ; bottom/right 8x8 crop
        ld a,GFX_TARGET_FRONT
        ld b,GFX_DRAW_TILE_CLIP
        call LIBMAN.l_call
        ret

copy_swap_demo:
        ; Clone the finished front buffer into back, add a marker there, then
        ; swap. If copy/swap is broken most or all of the picture disappears.
        ld hl,(handle)
        ld d,GFX_SOURCE_FRONT
        ld e,GFX_TARGET_BACK
        ld b,GFX_COPY_BUFFER
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,back_marker
        ld b,GFX_FILL_RECT
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld b,GFX_SWAP_BUFFERS
        call LIBMAN.l_call
        ret

restore_demo:
        ; Draw a transient VRAM-only block and erase it from the clean mirror.
        ; A surviving block in the upper-right corner means restore is broken.
        ld hl,(handle)
        ld de,transient_rect
        ld b,GFX_FILL_RECT
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,restore_rect
        ld b,GFX_RESTORE_RECT
        call LIBMAN.l_call
        ret

move_scroll_demo:
        ld hl,(handle)
        ld de,move_marker
        ld b,GFX_MOVE_RECT
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,(handle)
        ld de,scroll_band
        ld b,GFX_SCROLL_RECT
        call LIBMAN.l_call
        ret

; A real application should call GFX_FADE_STEP from its existing frame ISR.
; This standalone test deliberately uses a busy delay: taking ownership of
; DSS CTC/IM2 channels here would leave the command environment damaged.
fade_demo:
        ld hl,(handle)
        ld a,GFX_FADE_OUT
        ld d,16
        ld e,GFX_PAL_BOTH
        ld b,GFX_FADE_BEGIN
        call LIBMAN.l_call
        jr c,.manager_error
        or a
        jr nz,.gfx_error
.out_loop:
        call fade_delay
        ld hl,(handle)
        ld b,GFX_FADE_STEP
        call LIBMAN.l_call
        jr c,.manager_error
        or a
        jr nz,.gfx_error
        ld a,e
        or a
        jr nz,.out_loop
        ld hl,(handle)
        ld a,GFX_FADE_IN
        ld d,16
        ld e,GFX_PAL_BOTH
        ld b,GFX_FADE_BEGIN
        call LIBMAN.l_call
        jr c,.manager_error
        or a
        jr nz,.gfx_error
.in_loop:
        call fade_delay
        ld hl,(handle)
        ld b,GFX_FADE_STEP
        call LIBMAN.l_call
        jr c,.manager_error
        or a
        jr nz,.gfx_error
        ld a,e
        or a
        jr nz,.in_loop
        xor a
        ret
.manager_error:
        scf
        ret
.gfx_error:
        or a
        ret

fade_delay:
        ld bc,#2000               ; ~10 ms/step at 21 MHz keeps 16 steps visible
.wait: dec bc
        ld a,b
        or c
        jr nz,.wait
        ret

; API checks that must not modify the screen: zero-length operations are no-op
; successes and safe tile drawing rejects a slot outside the 0..63 page range.
self_check:
        ld a,#51
        ld (test_stage),a          ; zero-length hline
        ld hl,(handle)
        ld ix,320
        ld iy,0
        ld de,0
        xor a
        ld b,GFX_HLINE
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld a,#52
        ld (test_stage),a          ; invalid tile slot
        ld hl,(handle)
        ld de,#0040              ; logical page 0, invalid slot 64
        ld ix,0
        ld iy,0
        ld a,GFX_TARGET_FRONT
        ld b,GFX_DRAW_TILE
        call LIBMAN.l_call
        ret c
        cp GFX_ERR_TILE
        jr z,.pixel
        or a
        ret nz                     ; preserve an unexpected real GFX status
        ld a,GFX_ERR_ARGUMENT
        or a
        ret
.pixel:
        ld a,#53
        ld (test_stage),a          ; put_pixel
        ld hl,(handle)
        ld ix,319
        ld iy,#00ff
        ld a,7
        ld e,GFX_TARGET_BUF0
        ld b,GFX_PUT_PIXEL
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld a,#54
        ld (test_stage),a          ; get_pixel
        ld hl,(handle)
        ld ix,319
        ld iy,#00ff
        ld e,GFX_SOURCE_BUF0
        ld b,GFX_GET_PIXEL
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld a,e
        ld (pixel_observed),a
        cp 7
        jr z,.ok
        ld a,#55
        ld (test_stage),a          ; pixel round-trip mismatch
        ld a,GFX_ERR_ARGUMENT
        or a
        ret
.ok:   xor a
        ret

        ifdef GFX_BENCH
; Hardware benchmark. The CTC clock is a fixed 7 MHz, so the counter cascade
; 112*125 = 14000 gives an exact 500 Hz tick (2 ms).  Bars at Y=24/48/72/96
; are drawn at 2 px per tick, therefore bar width in pixels equals batch
; duration in milliseconds: 8 clears, 128 tiles, 8 full-buffer copies and
; 4 palette loads respectively.  The IM2 vector table lives inside this EXE
; image: WIN0 belongs to the DSS system page and must never be written.
CTC_CH0   equ #10
CTC_CH2   equ #12
CTC_CH3   equ #13

benchmark_run:
        call benchmark_im2_setup
        ld a,8
        ld (bench_loops),a
        call benchmark_start
.clear_loop:
        ld hl,(handle)
        xor a
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR
        call LIBMAN.l_call
        jp c,.done
        or a
        jp nz,.done
        call benchmark_dec_loop
        jr nz,.clear_loop
        call benchmark_stop
        ld (bench_clear_ticks),hl

        ld a,128
        ld (bench_loops),a
        call benchmark_start
.tile_loop:
        ld hl,(handle)
        ld de,#0000
        ld ix,0
        ld iy,0
        ld a,GFX_TARGET_FRONT
        ld b,GFX_DRAW_TILE
        call LIBMAN.l_call
        jp c,.done
        or a
        jp nz,.done
        call benchmark_dec_loop
        jr nz,.tile_loop
        call benchmark_stop
        ld (bench_tile_ticks),hl

        ld a,8
        ld (bench_loops),a
        call benchmark_start
.copy_loop:
        ld hl,(handle)
        ld d,GFX_SOURCE_FRONT
        ld e,GFX_TARGET_BACK
        ld b,GFX_COPY_BUFFER
        call LIBMAN.l_call
        jp c,.done
        or a
        jp nz,.done
        call benchmark_dec_loop
        jr nz,.copy_loop
        call benchmark_stop
        ld (bench_copy_ticks),hl

        ld a,4
        ld (bench_loops),a
        call benchmark_start
.palette_loop:
        ld hl,(handle)
        ld de,test_palette_rgb
        ld a,GFX_PAL_BOTH
        ld b,GFX_PALETTE_LOAD256
        call LIBMAN.l_call
        jp c,.done
        or a
        jp nz,.done
        call benchmark_dec_loop
        jr nz,.palette_loop
        call benchmark_stop
        ld (bench_palette_ticks),hl
        call benchmark_im2_stop
        call benchmark_bars
        xor a
        ret
.done:
        push af
        call benchmark_im2_stop
        pop af
        ret

benchmark_dec_loop:
        ld a,(bench_loops)
        dec a
        ld (bench_loops),a
        ret

benchmark_start:
        call benchmark_wait_tick
        ld hl,(bench_counter)
        ld (bench_started),hl
        ret

benchmark_stop:
        ld hl,(bench_counter)
        ld de,(bench_started)
        or a
        sbc hl,de
        ret

benchmark_wait_tick:
        ld hl,(bench_counter)
.wait: halt
        ld de,(bench_counter)
        ld a,h
        cp d
        jr nz,.changed
        ld a,l
        cp e
        jr z,.wait
.changed:
        ret

benchmark_im2_setup:
        di
        ld hl,bench_im2_table
        ld de,bench_im2_empty
        ld b,128
.fill: ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .fill
        ld hl,bench_im2_handler
        ld (bench_im2_table+6),hl
        ld hl,bench_im2_empty
        ld (bench_im2_table+#ff),hl
        ld a,i
        ld (bench_saved_i),a
        ld a,high bench_im2_table
        ld i,a
        im 2
        ld a,#57
        out (CTC_CH2),a
        ld a,112
        out (CTC_CH2),a
        ld a,#d7
        out (CTC_CH3),a
        ld a,125                  ; 7 MHz / (112*125) = 500 Hz exactly
        out (CTC_CH3),a
        xor a
        out (CTC_CH0),a
        ld (bench_counter),a
        ld (bench_counter+1),a
        ei
        ret

benchmark_im2_stop:
        di
        ld a,3
        out (CTC_CH2),a
        out (CTC_CH3),a
        ld a,(bench_saved_i)
        ld i,a
        im 1
        ei
        ret

bench_im2_handler:
        push af
        push hl
        ld hl,bench_counter
        inc (hl)
        jr nz,.done
        inc hl
        inc (hl)
.done: pop hl
        pop af
        ei
        reti

bench_im2_empty:
        ei
        reti

benchmark_bars:
        ld hl,(handle)
        xor a
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR
        call LIBMAN.l_call
        ret c
        or a
        ret nz
        ld hl,bench_clear_ticks
        ld iy,#0018
        ld a,4
        call benchmark_bar
        ld hl,bench_tile_ticks
        ld iy,#0030
        ld a,2
        call benchmark_bar
        ld hl,bench_copy_ticks
        ld iy,#0048
        ld a,3
        call benchmark_bar
        ld hl,bench_palette_ticks
        ld iy,#0060
        ld a,6
        jp benchmark_bar

; HL -> tick counter word, IY = bar row, A = colour. One 2-ms tick draws two
; pixels, so bar width in pixels equals elapsed milliseconds; longer
; measurements clamp at the full 320-pixel width (>= 320 ms).
benchmark_bar:
        ld (bench_color),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or a
        jr z,.scale
        ld de,160                 ; >=256 ticks: clamp before scaling
.scale:
        ex de,hl
        add hl,hl                 ; pixels = ticks * 2 = milliseconds
        ld de,321
        or a
        sbc hl,de
        add hl,de
        jr c,.length_ready
        ld hl,320
.length_ready:
        ex de,hl
        ld a,d
        and 1
        or #04                    ; FRONT flags shifted into bits 9..12
        ld d,a
        ld ix,0
        ld hl,(handle)
        ld a,(bench_color)
        ld b,GFX_HLINE
        call LIBMAN.l_call
        ret

bench_counter:       dw 0
bench_started:       dw 0
bench_clear_ticks:   dw 0
bench_tile_ticks:    dw 0
bench_copy_ticks:    dw 0
bench_palette_ticks: dw 0
bench_loops:         db 0
bench_color:         db 0
bench_saved_i:       db 0

; The IM2 vector table must be 256-aligned and covers vector bytes 0..#FF,
; including the word that straddles offset #FF (257 bytes total).
        align 256
bench_im2_table:     ds 257
        endif

        include "common/load_library.inc"

welcome: db "GFX320 ABI 1.0 visual test: loading DLL...",13,10,0
prompt: db 13,10,"Palette, copy, primitives and tiles rendered.",13,10,0
error_message: db "GFX320 test setup failed. Put GFX320.DLL beside this EXE.",13,10,0
error_detail: db "libman reason=$"
load_reason_hex: db "00, DSS error=$"
load_dsserr_hex: db "00, GFX status=$"
gfx_status_hex: db "00, test stage=$"
test_stage_hex: db "00, pixel=$"
pixel_observed_hex: db "00",13,10,0
libname: db "GFX320.DLL",0
libpath: ds 128

; Descriptor x,y,width,height,color,flags,reserved[3].
rect_blue: dw 12
           db 12
           dw 296,32
           db 1,GFX_TARGET_FRONT,0,0,0

frame_rect: dw 8
            db 8
            dw 304,240
            db 6,GFX_TARGET_FRONT,0,0,0

diagonal_line: dw 16
               db 56
               dw 303
               db 239,10,GFX_TARGET_FRONT

back_marker: dw 280
             db 216
             dw 24,20
             db 9,GFX_TARGET_BACK,0,0,0

transient_rect: dw 248
                db 16
                dw 32,32
                db 12,GFX_TARGET_FRONT|GFX_VRAM_ONLY,0,0,0

restore_rect: dw 248
              db 16
              dw 32,32
              db GFX_TARGET_FRONT

move_marker:
              db GFX_SOURCE_FRONT,GFX_TARGET_FRONT
              dw 280
              db 216
              dw 240
              db 216
              dw 24,20

scroll_band:
              dw 32
              db 72
              dw 256,16
              dw 8,0
              db 0,GFX_TARGET_FRONT,0,0,0
; TileRef values: page 0, slots 0..15.
span: dw span_refs
      dw 16
      dw 32
      db 72,GFX_TARGET_FRONT
span_refs:
      db 0,0, 1,0, 2,0, 3,0, 4,0, 5,0, 6,0, 7,0
      db 8,0, 9,0, 10,0, 11,0, 12,0, 13,0, 14,0, 15,0

tile_list: dw list_items
           dw 8
           db GFX_TARGET_FRONT,0,0,0
list_items:
           db 0,0, 32,0, 112
           db 1,0, 64,0, 128
           db 2,0, 96,0, 144
           db 3,0,128,0, 160
           db 4,0,160,0, 176
           db 5,0,192,0, 192
           db 6,0,224,0, 208
           db 7,0, 0,1, 224

tilemap_desc:
           dw tilemap_refs
           dw 4,2
           dw 0,0
           dw 4,2
           dw 128
           db 112,GFX_TARGET_FRONT,0,0
tilemap_refs:
           db 0,0, 1,0, 2,0, 3,0
           db 4,0, 5,0, 6,0, 7,0

metatile_desc:
           dw metatile_refs
           db 2,2
           dw 272
           db 160,GFX_TARGET_FRONT
metatile_refs:
           db 8,0, 9,0, 10,0, 11,0

; 16 simple 16x16 tiles, arranged as coloured stripe/checker patterns.
tiles:
        ; Every row starts with a bright colour and has a dark checker body.
        ; Repetition also verifies that source offsets advance by 16 bytes/row.
        dup 256
          db 4
          ds 15,5
        edup

; 32-entry palette in BIOS B,G,R,reserved format.
test_palette:
        db #00,#00,#00,#00,  #aa,#00,#00,#00
        db #00,#aa,#00,#00,  #aa,#aa,#00,#00
        db #00,#00,#aa,#00,  #aa,#00,#aa,#00
        db #00,#55,#aa,#00,  #aa,#aa,#aa,#00
        db #55,#55,#55,#00,  #ff,#55,#55,#00
        db #55,#ff,#55,#00,  #ff,#ff,#55,#00
        db #55,#55,#ff,#00,  #ff,#55,#ff,#00
        db #55,#ff,#ff,#00,  #ff,#ff,#ff,#00
        ; #10..#17: visible colours for GFX error codes.
        db #00,#00,#ff,#00,  #00,#ff,#00,#00
        db #ff,#00,#00,#00,  #00,#ff,#ff,#00
        db #ff,#ff,#00,#00,  #ff,#00,#ff,#00
        db #00,#80,#ff,#00,  #ff,#ff,#ff,#00
        ; #18..#1F: reserve visible diagnostic entries.
        dup 8
          db #aa,#aa,#aa,#00
        edup

; Full RGB8 palette used through GFX_PALETTE_LOAD256.
test_palette_rgb:
        db #00,#00,#00,  #00,#00,#aa,  #00,#aa,#00,  #00,#aa,#aa
        db #aa,#00,#00,  #aa,#00,#aa,  #aa,#55,#00,  #aa,#aa,#aa
        db #55,#55,#55,  #55,#55,#ff,  #55,#ff,#55,  #55,#ff,#ff
        db #ff,#55,#55,  #ff,#55,#ff,  #ff,#ff,#55,  #ff,#ff,#ff
        dup 240
          db 0,0,0
        edup

handle:         dw 0
old_mode:       db 0
old_screen:     db 0
test_screen:    db 0
tile_block:     db 0
tile_allocated: db 0
physical_pages: ds 16
page_table:     db 0
                ds 255,0
saved_win0:     db 0
probe_saved_page: db 0
probe_base:     dw #4000
probe_color:    db 15
probe_x:        db 0
gfx_status:     db 0
load_reason:    db 0
load_dsserr:    db 0
test_stage:     db 0
pixel_observed: db 0
gfx_config:     db 16
                ds 15,0

        include "libman13.asm"
