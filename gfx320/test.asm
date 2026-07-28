        org #8100-512

; Visual MVP test.  GFX320.DLL must be beside this EXE.
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
        ld hl,(handle)
        ld b,GFX_INIT
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        ld hl,(handle)
        ld de,gfx_config
        ld b,GFX_GET_CONFIG
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
        ld hl,(handle)
        ld de,page_table
        ld ix,1
        ld b,GFX_SET_PAGE_TABLE
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
        call self_check
        jp c,failed_loaded
        or a
        jp nz,failed_gfx

        ; A black background, filled panels, horizontal and vertical lines.
        ld hl,(handle)
        ld a,0
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR
        call LIBMAN.l_call
        jp c,failed_loaded
        or a
        jp nz,failed_gfx
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
        ld hl,prompt
        ld c,#5c
        rst #10
        ld c,#30
        rst #10

close:
        call free_tile_page
        ld hl,(handle)
        call LIBMAN.l_free
restore:
        ld a,(old_screen)
        ld b,a
        ld a,(old_mode)
        ld c,#50
        rst #10
        ld bc,#0041
        rst #10
failed_gfx:
        ld (gfx_status),a
        jr failed_loaded
failed_loaded:
        call free_tile_page
        ld hl,(handle)
        call LIBMAN.l_free
        jr failed
failed:
        ld a,(LIBMAN.l_reason)
        ld e,100
        call draw_cpu_probe
        ld a,(LIBMAN.l_dsserr)
        ld e,110
        call draw_cpu_probe
        ld a,(gfx_status)
        ld e,120
        call draw_cpu_probe
        ld hl,error_message
        ld c,#5c
        rst #10
        ld c,#30
        rst #10
        jr restore

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

; API checks that must not modify the screen: zero-length operations are no-op
; successes and safe tile drawing rejects a slot outside the 0..63 page range.
self_check:
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
        ld hl,(handle)
        ld de,#0040              ; logical page 0, invalid slot 64
        ld ix,0
        ld iy,0
        ld a,GFX_TARGET_FRONT
        ld b,GFX_DRAW_TILE
        call LIBMAN.l_call
        ret c
        cp GFX_ERR_TILE
        jr z,.ok
        ld a,GFX_ERR_ARGUMENT
        or a
        ret
.ok:   xor a
        ret

; Build "EXE directory\GFX320.DLL", with a bare-name fallback for older DSS.
load_library:
        ld hl,libpath
        ld b,APPINFO_EXE_HOMEDIR
        ld c,DSS_APPINFO
        rst #10
        jr c,.fallback
        ld a,(libpath)
        or a
        jr z,.fallback
        ld hl,libpath
.find_end:
        ld a,(hl)
        or a
        jr z,.append
        inc hl
        jr .find_end
.append:
        dec hl
        ld a,(hl)
        inc hl
        cp #5c
        jr z,.copy_name
        cp '/'
        jr z,.copy_name
        ld (hl),#5c
        inc hl
.copy_name:
        ex de,hl
        ld hl,libname
.copy_loop:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,.copy_loop
        ld hl,libpath
        ld a,3                    ; keep DLL in WIN3, away from EXE/data WIN2
        call LIBMAN.l_load
        ret nc
        ld a,(LIBMAN.l_reason)
        cp LIBMAN.LR_OPEN
        ret nz
.fallback:
        ld hl,libname
        ld a,3
        jp LIBMAN.l_load

welcome: db "GFX320 visual MVP test: loading DLL...",13,10,0
prompt: db 13,10,"Primitives and row-major WIN0 tiles rendered. Press any key.",13,10,0
error_message: db "GFX320 test setup failed. Put GFX320.DLL beside this EXE.",13,10,0
libname: db "GFX320.DLL",0
libpath: ds 128

; Descriptor x,y,width,height,color,flags,reserved[3].
rect_blue: dw 12
           db 12
           dw 296,32
           db 1,GFX_TARGET_FRONT,0,0,0

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
gfx_config:     db 16
                ds 15,0

        include "libman13.asm"
