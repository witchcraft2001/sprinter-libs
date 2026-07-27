; AFNT640 - L0 DLL for Sprinter libman 1.2/1.3
;
; The public entry points intentionally keep the historical ANTONFNT ABI and
; add one optional video-window selector:
;   0 init, 1 free, 2 fnstyle, 3 aprint, 4 set_window.
; aprint receives DE=text (ASCIIZ), IX=x, IY=y and A=BG<<4|FG.
;
; This variant is fixed to 640x256x16 (the original ANTONFNT renderer), so
; no mode probe is made on the hot aprint path.  fnstyle samples GETVMOD
; (#51) once to capture the selected video page.  set_window receives E as
; the memory-window number (0..3); the selected window must not be the window
; where this DLL is resident.  WIN1 remains the default for compatibility.
;
; Build with sprinter-mkdll and sjasmplus (see Makefile).  The L0 header is
; deliberately kept in the source so old libman loaders can relocate it.

			ORG	0x0000

			DB	"L0"
			DW	0			; loaded size (filled by sprinter-mkdll)
			DW	0			; uncompressed code size
			DW	0			; relocation bitmap size
			DW	0			; checksum
			DB	27,7			; build date: 27-Jul
			DW	2026
			DW	0x0103			; v1.3
			DB	"AFNT640 gfx lib",0

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
SCREEN_STRIDE	EQU	0x0140		; BIOS PIC_FN2 second-screen offset

; ---------------------------------------------------------------------------
; libman entry points

init:
			; Determine the libman code window from the relocated data address.
			; The library may not map VRAM over its own code.
			LD	HL,video_window
			LD	A,H
			RRCA
			RRCA
			RRCA
			RRCA
			RRCA
			RRCA
			LD	(code_window),A

			; Keep the historical/default behaviour exactly: packed 640x256x16
			; and video page in WIN1.  If libman also placed this DLL in WIN1,
			; fnstyle/aprint will report a conflict until function #4 selects a
			; different window.
			LD	A,DEFAULT_WINDOW
			CALL	configure_window
			XOR	A
			LD	(screen_id),A
			LD	(color_valid),A
			RET

free:
			RET

; Set the first 16 palette entries to the EGA-compatible palette and clear
; the currently selected graphic screen.  A is accepted for ABI compatibility;
; the historical library always cleared with colour 0.
fnstyle:
			CALL	ensure_window_safe
			JR	C,fnstyle_window_error
			CALL	capture_screen
			CALL	clear_screen_640
			CALL	load_palette
			XOR	A
			RET

fnstyle_window_error:
			SCF
			RET

; Text ABI adapter.  This DLL always uses the packed 640x256 renderer; no
; DSS call is made while printing a line.
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
			CALL	text_out_640
			XOR	A
			RET

aprint_window_error:
			SCF
			RET

; ---------------------------------------------------------------------------
; Window/palette and screen helpers

; Function #4.  E selects the memory window where the video page is mapped
; (0..3).  On success A returns the selected window with carry clear.  An
; invalid window, or a request to map over this DLL's code window, leaves the
; previous configuration untouched and returns carry set.  A is ignored for
; source compatibility with callers that used the former mode selector.
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

; Configure the page register and CPU address base for a window number in A.
; WIN0..WIN3 use ports #82/#A2/#C2/#E2 and address bases #0000/#4000/
; #8000/#C000. YPORT selects the scan line, so no #40 offset is applied.
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

; GETVMOD is deliberately confined to style setup.  It returns A=mode and
; B=selected screen; only the latter is needed here because this renderer is
; fixed to 640x256 and uses the configured window above.
capture_screen:
			LD	C,DSS_GETVMOD
			RST	0x10
			LD	A,B
			LD	(screen_id),A
			RET

; Return carry if the configured VRAM window is the window containing this
; relocated DLL.  BC is preserved because callers may be holding a text
; pointer or loop counter there.
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
			; Both display buffers share VRAM page #50.  screen_id is an
			; in-row offset (#000/#140), never page #50/#51.
			LD	A,VIDEO_PAGE
			CALL	write_page
			RET

; Clear all 320 byte-columns with one 256-pixel vertical fill each.
clear_screen_640:
			DI
			CALL	read_page
			LD	(saved_page),A
			CALL	select_video_page
			LD	HL,(vram_base)
			LD	A,(screen_id)
			OR	A
			JR	Z,clear_screen_640_base_ready
			LD	BC,SCREEN_STRIDE
			ADD	HL,BC
clear_screen_640_base_ready:
			XOR	A
			OUT	(YPORT),A
			LD	E,A			; packed colour 0
			LD	D,D			; SET_BUFFER
			LD	A,0			; 0 encodes 256 rows
			LD	B,B
			LD	BC,320
clear_screen_640_column:
			LD	E,E			; FILL_VERT
			LD	(HL),E
			LD	B,B
			INC	HL
			DEC	BC
			LD	A,B
			OR	C
			JR	NZ,clear_screen_640_column

			LD	A,(saved_page)
			CALL	write_page
			LD	A,0xC0
			OUT	(YPORT),A
			EI
			RET

; ---------------------------------------------------------------------------
; 640x256x16 renderer.  This is the proven ANTONFNT accelerator path with
; the current screen page and configurable VRAM window selected by the
; adapter above.

text_out_640:
			PUSH	IY
			LD	B,A
			LD	A,C
			LD	(y_pos),A
			CALL	read_page
			LD	(saved_page),A
			CALL	prepare_print_colors
			PUSH	DE
			EXX
			POP	BC
			SRL	B
			RR	C
			LD	HL,(vram_base)
			LD	A,(screen_id)
			OR	A
			JR	Z,text_out_640_base_ready
			LD	DE,SCREEN_STRIDE
			ADD	HL,DE
text_out_640_base_ready:
			ADD	HL,BC
			LD	B,H
			LD	C,L
			LD	HL,foreground_buffer
			LD	DE,background_buffer
			EXX
			LD	C,L
			LD	B,H

			; Select the colour pipeline once for the complete string.
			LD	A,(bg_pattern)
			OR	A
			LD	HL,text_out_640_rows_general
			JR	NZ,text_out_640_dispatch_ready
			LD	HL,text_out_640_rows_black
text_out_640_dispatch_ready:
			LD	(text_out_640_dispatch+1),HL

			; Usually the ASCIIZ string lives in a different CPU window, so
			; map VRAM once for the whole call.  If it occupies the selected
			; video window, retain the safe historical per-character mapping.
			LD	A,B
			AND	0xC0
			RLCA
			RLCA
			LD	D,A
			LD	A,(video_window)
			CP	D
			LD	A,0
			JR	NZ,text_out_640_page_mode_ready
			INC	A
text_out_640_page_mode_ready:
			LD	(map_per_char),A
			OR	A
			CALL	Z,select_video_page

			DI
			; Exact accelerator setup from ANTONFNT_OLD_DISASM.Z80:
			; block size 8, then leave the accelerator idle until COPY.
			LD	D,D
			LD	A,8
			LD	B,B
			LD	A,(BC)
			INC	BC
			OR	A
			JR	Z,text_out_640_exit

text_out_640_char:
			PUSH	BC
			LD	BC,my_font
			LD	L,A
			LD	H,0
			ADD	HL,BC
			LD	B,(HL)
			INC	H
			LD	E,(HL)
			INC	H
			LD	D,(HL)
			LD	HL,my_font
			ADD	HL,DE
			LD	DE,8
			LD	A,(map_per_char)
			OR	A
			CALL	NZ,select_video_page

text_out_640_dispatch:
			JP	text_out_640_rows_general

; General colour path:
;   background XOR (mask AND (foreground XOR background))
text_out_640_rows_general:
			; COPY makes the accelerator latch the source font byte.  The
			; original renderer brackets the ordinary memory read with
			; COPY/OFF; without this pair every glyph becomes a solid bar.
			LD	L,L
			LD	A,(HL)
			LD	B,B
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			LD	L,L
			AND	(HL)
			LD	B,B
			EX	DE,HL
			LD	L,L
			XOR	(HL)
			LD	A,A
			LD	(BC),A
			LD	B,B
			EX	DE,HL
			INC	BC
			EXX
			ADD	HL,DE
			DJNZ	text_out_640_rows_general
			JR	text_out_640_char_done

; Black-background path: mask AND foreground.  The background XOR block is
; identically zero and can be omitted.
text_out_640_rows_black:
			LD	L,L
			LD	A,(HL)
			LD	B,B
			EXX
			LD	A,(y_pos)
			OUT	(YPORT),A
			LD	L,L
			AND	(HL)
			LD	A,A
			LD	(BC),A
			LD	B,B
			INC	BC
			EXX
			ADD	HL,DE
			DJNZ	text_out_640_rows_black

text_out_640_char_done:
			POP	BC
			LD	A,(map_per_char)
			OR	A
			JR	Z,text_out_640_next_char
			LD	A,(saved_page)
			CALL	write_page
text_out_640_next_char:
			LD	A,(BC)
			INC	BC
			OR	A
			JR	NZ,text_out_640_char

text_out_640_exit:
			LD	B,B
			EI
			LD	L,C
			LD	H,B
			LD	A,0xC0
			OUT	(YPORT),A
			LD	A,(saved_page)
			CALL	write_page
			POP	IY
			RET

prepare_print_colors:
			LD	A,(color_valid)
			OR	A
			JR	Z,prepare_print_colors_rebuild
			LD	A,B
prepare_print_colors_prev:
			CP	0
			RET	Z
prepare_print_colors_rebuild:
			LD	A,1
			LD	(color_valid),A
			LD	A,B
			LD	(prepare_print_colors_prev+1),A
			AND	0x0F
			LD	C,A
			RLCA
			RLCA
			RLCA
			RLCA
			OR	C
			LD	(fg_pattern),A
			LD	A,B
			AND	0xF0
			LD	C,A
			RRCA
			RRCA
			RRCA
			RRCA
			OR	C
			LD	(bg_pattern),A
			LD	C,A
			LD	A,(fg_pattern)
			XOR	C			; foreground XOR background
			EXX
			LD	HL,foreground_buffer
			CALL	fill_colour_buffer_640
			LD	A,(bg_pattern)
			LD	HL,background_buffer
			CALL	fill_colour_buffer_640
			EXX
			RET

; Active in the alternate register set.  Fill eight bytes at HL with A.
fill_colour_buffer_640:
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
; Runtime state (small, initialised data; no large buffers are reserved).

code_window:	DB	1
video_window:	DB	DEFAULT_WINDOW
page_port:	DB	0xA2
page_latch:	DB	0
vram_base:	DW	0x4000
screen_id:	DB	0
saved_page:	DB	0
y_pos:		DB	0
print_color:	DB	0
fg_pattern:	DB	0
bg_pattern:	DB	0
color_valid:	DB	0
map_per_char:	DB	0
fg_color:	DB	0
bg_color:	DB	0
str_ptr:	DW	0
cursor_x:	DW	0
glyph_ptr:	DW	0

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

; Anton variable-width font: 256 packed-column widths, 256 low offsets,
; 256 high offsets, followed by variable-size column-major 8-row rasters.
; The 6888-byte file is extracted from the original ANTONFNT.DLL and is
; embedded in the resulting DLL by INCBIN.
my_font:
			INCBIN	"font.bin"
