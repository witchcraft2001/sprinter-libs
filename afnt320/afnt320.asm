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

			INCLUDE	"../common/fontlayout.inc"

			DB	"L0"
			DW	0			; loaded size (filled by sprinter-mkdll)
			DW	0			; uncompressed code size
			DW	0			; relocation bitmap size
			DW	0			; checksum
			DB	28,7			; build date: 28-Jul
			DW	2026
			DW	0x0104			; v1.4
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
			; A relocated label may be anywhere inside its 16K CPU window.  Only
			; H7..H6 identify that window; the remaining bits are its offset.
			LD	HL,video_window
			LD	A,H
			AND	0xC0
			RLCA
			RLCA
			LD	(code_window),A
			; Preserve the historical default: video page through WIN1.
			LD	A,DEFAULT_WINDOW
			CALL	configure_window
			XOR	A
			LD	(screen_id),A
			LD	(textcore_color_valid),A
			LD	HL,my_font
			LD	(textcore_font_base),HL
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


; AFNT320 owns mapping and interrupt state. The shared core only renders into
; the already mapped font and VRAM pages.
text_out_320:
			PUSH	HL
			PUSH	DE
			PUSH	BC
			DI
			CALL	read_page
			LD	(saved_page),A
			CALL	select_video_page
			LD	HL,(vram_base)
			LD	A,(screen_id)
			OR	A
			JR	Z,text_out_320_base_ready_shared
			LD	DE,SCREEN_STRIDE
			ADD	HL,DE
text_out_320_base_ready_shared:
			LD	(textcore_vram_base),HL
			POP	BC
			POP	DE
			POP	HL
			LD	A,(print_color)
			CALL	textcore_draw_mapped
			LD	A,(saved_page)
			CALL	write_page
			LD	A,0xC0
			OUT	(YPORT),A
			EI
			RET

			INCLUDE	"../common/textcore320.inc"

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
