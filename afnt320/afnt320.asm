; AFNT320 - L0 DLL for Sprinter libman 1.2/1.3
;
; ABI-compatible 320x256 text library.  At build time the compact gfxview font
; is converted to column-major 00/FF masks for the Sprinter accelerator.
; The public entry points are:
;   0 init, 1 free, 2 fnstyle, 3 aprint, 4 set_window.
; aprint receives DE=text (ASCIIZ), IX=x, IY=y and A=BG<<4|FG.
; WIN1 is the default video-memory window.  Function 4 selects another
; window in E=0..3; it must not be the window containing this DLL.

			ORG	0x0000

			DB	"L0"
			DW	0			; loaded size (filled by sprinter-mkdll)
			DW	0			; uncompressed code size
			DW	0			; relocation bitmap size
			DW	0			; checksum
			DB	27,7			; build date: 27-Jul
			DW	2026
			DW	0x0103			; v1.3
			DB	"AFNT320 gfx lib",0

			JP	init
			JP	free
			JP	fnstyle
			JP	aprint
			JP	set_window

VIDEO_PAGE	EQU	0x50
PAGE_PORT_BASE	EQU	0x82		; WIN0; WINn page port = base + n*0x20
DEFAULT_WINDOW	EQU	1
YPORT		EQU	0x89
DSS_GETVMOD	EQU	0x51
SCREEN_STRIDE	EQU	0x0140		; second-screen offset in 320-byte rows

; ---------------------------------------------------------------------------
; libman entry points

init:
			; Determine the libman code window from a relocated data address.
			LD	HL,video_window
			LD	A,H
			RRCA
			RRCA
			RRCA
			RRCA
			RRCA
			RRCA
			LD	(code_window),A
			; Preserve the historical default: video page through WIN1.
			LD	A,DEFAULT_WINDOW
			CALL	configure_window
			XOR	A
			LD	(screen_id),A
			LD	(color_valid),A
			RET

free:
			RET

; Set the palette and clear the currently selected 320x256 graphic screen.
fnstyle:
			CALL	ensure_window_safe
			JR	C,fnstyle_window_error
			CALL	capture_screen
			CALL	clear_screen_320
			CALL	load_palette
			XOR	A
			RET

fnstyle_window_error:
			SCF
			RET

; Text ABI adapter.  AFNT320 has no mode switch; every call uses the
; gfxview-format 320x256 renderer.
aprint:
			LD	(print_color),A
			CALL	ensure_window_safe
			JR	C,aprint_window_error
			EX	DE,HL			; HL = text
			PUSH	IX
			POP	DE			; DE = x
			PUSH	IY
			POP	BC			; BC = y
			LD	A,(print_color)
			CALL	text_out_320
			XOR	A
			RET

aprint_window_error:
			SCF
			RET

; ---------------------------------------------------------------------------
; Window/palette and screen helpers

; Function #4.  E selects the memory window where the video page is mapped.
; On success A returns the selected window with carry clear.  Invalid values,
; or a request to map over the DLL's own code window, leave state unchanged.
; A is ignored for source compatibility with the former universal library.
set_window:
			LD	A,E
			CP	4
			JR	NC,set_window_error
			LD	B,A
			LD	A,(code_window)
			CP	B
			JR	Z,set_window_error
			LD	A,B
			CALL	configure_window
			LD	A,(video_window)
			RET

set_window_error:
			SCF
			RET

; Configure page register and CPU address base for WIN0..WIN3.  YPORT selects
; the scan line, so its byte data begins at the mapped window base.
configure_window:
			LD	(video_window),A
			LD	B,A
			ADD	A,A
			ADD	A,A
			ADD	A,A
			ADD	A,A
			ADD	A,A
			ADD	A,PAGE_PORT_BASE
			LD	(page_port),A
			LD	A,B
			LD	HL,0x0000
			OR	A
			JR	Z,configure_window_base_ready
			LD	DE,0x4000
configure_window_base_loop:
			ADD	HL,DE
			DJNZ	configure_window_base_loop
configure_window_base_ready:
			LD	(vram_base),HL
			RET

; GETVMOD is confined to style setup.  It returns B=selected screen page.
capture_screen:
			LD	C,DSS_GETVMOD
			RST	0x10
			LD	A,B
			LD	(screen_id),A
			RET

; Return carry if the selected VRAM window is the window containing this DLL.
ensure_window_safe:
			PUSH	BC
			LD	A,(video_window)
			LD	B,A
			LD	A,(code_window)
			CP	B
			JR	Z,ensure_window_conflict
			POP	BC
			XOR	A
			RET

ensure_window_conflict:
			POP	BC
			SCF
			RET

read_page:
			PUSH	BC
			LD	A,(page_port)
			LD	C,A
			IN	A,(C)
			POP	BC
			RET

write_page:
			LD	(page_latch),A
			PUSH	BC
			LD	A,(page_port)
			LD	C,A
			LD	A,(page_latch)
			OUT	(C),A
			POP	BC
			RET

load_palette:
			LD	HL,custom_palette
			LD	DE,0x1000
			LD	BC,0xFFA4		; BIOS PIC_SET_PAL
			LD	A,(screen_id)
			RST	0x08
			RET

select_video_page:
			; Both display buffers live in VRAM page #50.  screen_id selects
			; the CPU base (#000/#140), not a different VRAM page.
			LD	A,VIDEO_PAGE
			CALL	write_page
			RET

; Clear the screen as 320 vertical lines.  A zero accelerator count means
; 256 bytes, so each iteration clears one complete X column.
clear_screen_320:
			DI
			CALL	read_page
			LD	(saved_page),A
			CALL	select_video_page
			LD	HL,(vram_base)
			LD	A,(screen_id)
			OR	A
			JR	Z,clear_screen_320_base_ready
			LD	BC,SCREEN_STRIDE
			ADD	HL,BC
clear_screen_320_base_ready:
			XOR	A
			OUT	(YPORT),A
			LD	E,A			; fill colour = palette index 0
			LD	D,D			; SET_BUFFER
			LD	A,0			; 0 encodes a 256-byte block
			LD	B,B			; OFF until the first column
			LD	BC,320
clear_screen_320_column:
			LD	E,E			; FILL_VERT
			LD	(HL),E
			LD	B,B			; OFF
			INC	HL
			DEC	BC
			LD	A,B
			OR	C
			JR	NZ,clear_screen_320_column

			LD	A,(saved_page)
			CALL	write_page
			LD	A,0xC0
			OUT	(YPORT),A
			EI
			RET

; ---------------------------------------------------------------------------
; Accelerator font renderer (320x256x256, one byte per pixel).  The generated
; font contains one vertical block of eight 00/FF mask bytes per non-empty
; glyph column.  The AND/XOR pipeline turns that mask into foreground and
; background palette indices, then COPY_VERT writes all eight pixels at once.

text_out_320:
			PUSH	IX
			PUSH	IY
			PUSH	DE
			POP	IX			; IX = current X
			LD	B,A
			LD	A,C
			LD	(y_pos),A
			CALL	read_page
			LD	(saved_page),A
			CALL	prepare_colors_320
			CALL	select_video_page

			; Alternate BC is the destination X address; alternate HL/DE
			; permanently point at the two eight-byte colour buffers.
			PUSH	DE
			EXX
			POP	BC
			LD	HL,(vram_base)
			LD	A,(screen_id)
			OR	A
			JR	Z,text_out_320_base_ready
			LD	DE,SCREEN_STRIDE
			ADD	HL,DE
text_out_320_base_ready:
			ADD	HL,BC
			LD	B,H
			LD	C,L
			LD	HL,foreground_buffer
			LD	DE,background_buffer
			EXX
			LD	C,L
			LD	B,H			; main BC = ASCIIZ string

			; Select the inner loop once per string.  With background zero,
			; mask AND foreground already produces the final pixels, so the
			; background XOR pass is unnecessary.
			LD	A,(bg_color)
			OR	A
			LD	HL,text_out_320_columns_general
			JR	NZ,text_out_320_dispatch_ready
			LD	HL,text_out_320_columns_black
text_out_320_dispatch_ready:
			LD	(text_out_320_dispatch+1),HL

			; Clip the vertical block at the bottom edge.  Patch the immediate
			; used by SET_BUFFER so no ordinary memory read occurs while the
			; accelerator is accepting its count.
			LD	A,(y_pos)
			CP	248
			JR	C,text_out_320_rows8
			NEG
			JR	text_out_320_rows_ready
text_out_320_rows8:
			LD	A,8
text_out_320_rows_ready:
			LD	(text_out_320_height+1),A
			DI
			LD	D,D			; SET_BUFFER
text_out_320_height:
			LD	A,8
			LD	B,B			; OFF
			LD	A,(BC)
			INC	BC
			OR	A
			JP	Z,text_out_320_done

text_out_320_char:
			PUSH	BC
			LD	BC,my_font
			LD	L,A
			LD	H,0
			ADD	HL,BC
			LD	B,(HL)			; glyph width
			LD	IYL,B			; preserve the unclipped advance
			INC	H
			LD	E,(HL)			; bitmap offset, low
			INC	H
			LD	D,(HL)			; bitmap offset, high
			INC	H
			LD	A,(HL)			; bit 7..0: non-empty columns
			LD	IYH,A
			LD	HL,my_font
			ADD	HL,DE
			LD	DE,8			; bytes per vertical column

			; Clip only the final glyph that crosses X=320.  Once cursor_x is
			; beyond that edge, later glyphs can be skipped immediately.
			LD	A,IXH
			OR	A
			JR	Z,text_out_320_width_ready
			CP	1
			JR	NZ,text_out_320_skip_glyph
			LD	A,IXL
			CP	0x40
			JR	NC,text_out_320_skip_glyph
			LD	C,A
			LD	A,0x40
			SUB	C
			CP	B
			JR	NC,text_out_320_width_ready
			LD	B,A
text_out_320_width_ready:
			LD	A,B
			OR	A
			JR	Z,text_out_320_skip_glyph
			LD	C,IYH

text_out_320_dispatch:
			JP	text_out_320_columns_general

; General colour path:
;   background XOR (mask AND (foreground XOR background))
text_out_320_columns_general:
			RLC	C
			JR	NC,text_out_320_column_blank_general
			LD	L,L			; COPY mask column to accelerator RAM
			LD	A,(HL)
			LD	B,B			; OFF
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			LD	L,L			; COPY foreground XOR background
			AND	(HL)
			LD	B,B
			EX	DE,HL
			LD	L,L			; COPY background block
			XOR	(HL)
			LD	A,A			; COPY_VERT result to VRAM
			LD	(BC),A
			LD	B,B
			EX	DE,HL
			INC	BC			; next screen X
			EXX
			ADD	HL,DE			; next eight-byte mask column
			DJNZ	text_out_320_columns_general
			JR	text_out_320_skip_glyph

text_out_320_column_blank_general:
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			LD	A,(bg_color)
			LD	E,E			; FILL_VERT background
			LD	(BC),A
			LD	B,B
			INC	BC
			EXX
			DJNZ	text_out_320_columns_general
			JR	text_out_320_skip_glyph

; Black-background path:
;   mask AND foreground
; This removes one complete eight-byte accelerator pass per non-empty column.
text_out_320_columns_black:
			RLC	C
			JR	NC,text_out_320_column_blank_black
			LD	L,L			; COPY mask column to accelerator RAM
			LD	A,(HL)
			LD	B,B
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			LD	L,L			; COPY foreground block
			AND	(HL)
			LD	A,A			; COPY_VERT result to VRAM
			LD	(BC),A
			LD	B,B
			INC	BC
			EXX
			ADD	HL,DE
			DJNZ	text_out_320_columns_black
			JR	text_out_320_skip_glyph

text_out_320_column_blank_black:
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			XOR	A
			LD	E,E			; FILL_VERT black background
			LD	(BC),A
			LD	B,B
			INC	BC
			EXX
			DJNZ	text_out_320_columns_black

text_out_320_skip_glyph:
			POP	BC
			LD	E,IYL
			LD	D,0
			ADD	IX,DE
			LD	A,(BC)
			INC	BC
			OR	A
			JP	NZ,text_out_320_char

text_out_320_done:
			LD	B,B			; accelerator OFF
			EI
			LD	L,C
			LD	H,B
			LD	A,(saved_page)
			CALL	write_page
			LD	A,0xC0
			OUT	(YPORT),A
			POP	IY
			POP	IX
			RET

; Build the two eight-byte operands used by the mask pipeline:
;   result = background XOR (mask AND (foreground XOR background))
prepare_colors_320:
			LD	A,(color_valid)
			OR	A
			JR	Z,prepare_colors_320_rebuild
			LD	A,B
prepare_colors_320_prev:
			CP	0
			RET	Z
prepare_colors_320_rebuild:
			LD	A,1
			LD	(color_valid),A
			LD	A,B
			LD	(prepare_colors_320_prev+1),A
			AND	0x0F
			LD	C,A			; foreground
			LD	A,B
			AND	0xF0
			RRCA
			RRCA
			RRCA
			RRCA
			LD	(bg_color),A
			XOR	C			; foreground XOR background
			EXX
			LD	HL,foreground_buffer
			CALL	fill_colour_buffer
			LD	A,(bg_color)
			LD	HL,background_buffer
			CALL	fill_colour_buffer
			EXX
			RET

; Active in the alternate register set.  Fill eight bytes at HL with A.
fill_colour_buffer:
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			INC	HL
			LD	(HL),A
			RET

; ---------------------------------------------------------------------------
; Runtime state and generated accelerator font.

code_window:	DB	1
video_window:	DB	DEFAULT_WINDOW
page_port:	DB	0xA2
page_latch:	DB	0
vram_base:	DW	0x4000
screen_id:	DB	0
saved_page:	DB	0
y_pos:		DB	0
print_color:	DB	0
bg_color:	DB	0
color_valid:	DB	0

foreground_buffer:	DS	8,0
background_buffer:	DS	8,0

; EGA-compatible palette, four bytes per entry (B,G,R,Y).
custom_palette:
			DB	0x00,0x00,0x00,0x00
			DB	0xAA,0x00,0x00,0x00
			DB	0x00,0xAA,0x00,0x00
			DB	0xAA,0xAA,0x00,0x00
			DB	0x00,0x00,0xAA,0x00
			DB	0xAA,0x00,0xAA,0x00
			DB	0x00,0x55,0xAA,0x00
			DB	0xAA,0xAA,0xAA,0x00
			DB	0x55,0x55,0x55,0x00
			DB	0xFF,0x55,0x55,0x00
			DB	0x55,0xFF,0x55,0x00
			DB	0xFF,0xFF,0x55,0x00
			DB	0x55,0x55,0xFF,0x00
			DB	0xFF,0x55,0xFF,0x00
			DB	0x55,0xFF,0xFF,0x00
			DB	0xFF,0xFF,0xFF,0x00

; Generated layout: 256 widths, 256 low offsets, 256 high offsets, 256
; non-empty-column masks, then only non-empty columns as eight 00/FF bytes.
my_font:
			INCBIN	"build/font_accel.bin"
