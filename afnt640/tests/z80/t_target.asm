		device noslot64k
		org 0
		jp start
		ds #08-$,0
		jp bios_stub
		ds #10-$,0
		jp dss_stub

		include "harness.inc"

dss_screen_fixture: db 0
palette_screen: db #ff
empty_text: db 0

bios_stub:
		ld (palette_screen),a
		or a
		ret
dss_stub:
		ld a,#82
		ld b,(dss_screen_fixture)
		or a
		ret

start:
		ld sp,#bff0
		call t_begin
		call init
		ld e,3
		call set_window
		ld a,1
		call t_expect_nc
		; Model a prior page value despite the emulator's missing page ports.
		ld a,#3e
		ld (read_page_input),a
		ld a,#37
		ld (read_page_input+1),a

		; Legacy fnstyle masks GETVMOD B and restores enabled IFF.
		ld a,#ff
		ld (dss_screen_fixture),a
		ei
		nop
		call fnstyle
		call t_keep_a
		ld a,2
		call t_expect_nc
		ld a,(screen_id)
		cp 1
		ld a,3
		call t_expect_z
		ld a,(palette_screen)
		cp 1
		ld a,4
		call t_expect_z
		ld a,(page_latch)
		cp #37
		ld a,20
		call t_expect_z
		ld a,i
		ld a,5
		call t_expect_pe
		; z88dk-ticks has no Sprinter RGMOD latch. Replace each two-byte
		; IN A,(#c9) with an equal-size LD A,n and vary n below.
		ld a,#3e
		ld (afnt_resolve_front),a
		ld (afnt_resolve_back),a

		; Physical selectors ignore RGMOD.
		ld e,AFNT640_TARGET_BUF0
		call afnt_set_target
		ld a,1
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		or a
		ld a,6
		call t_expect_z
		ld e,AFNT640_TARGET_BUF1
		call afnt_set_target
		xor a
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		cp 1
		ld a,7
		call t_expect_z

		; FRONT/BACK truth table and symbolic persistence across a flip.
		ld e,AFNT640_TARGET_FRONT
		call afnt_set_target
		xor a
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		or a
		ld a,8
		call t_expect_z
		ld a,1
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		cp 1
		ld a,9
		call t_expect_z
		ld a,(target_selector)
		cp AFNT640_TARGET_FRONT
		ld a,10
		call t_expect_z

		ld e,AFNT640_TARGET_BACK
		call afnt_set_target
		xor a
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		cp 1
		ld a,11
		call t_expect_z
		ld a,1
		call set_rgmod_fixture
		call afnt_resolve_target
		ld a,(screen_id)
		or a
		ld a,12
		call t_expect_z

		; Invalid selector reports the public error and preserves state.
		ld e,4
		call afnt_set_target
		call t_keep_a
		ld a,13
		call t_expect_c
		ld a,(t_saved_a)
		cp AFNT640_ERR_ARGUMENT
		ld a,14
		call t_expect_z
		ld a,(target_selector)
		cp AFNT640_TARGET_BACK
		ld a,15
		call t_expect_z

		; Code/stack windows are rejected without changing WIN3.
		ld e,1
		call set_window
		ld a,16
		call t_expect_c
		ld e,2
		call set_window
		ld a,17
		call t_expect_c
		ld a,(video_window)
		cp 3
		ld a,18
		call t_expect_z

		; A disabled caller remains disabled after the mapped aprint path.
		ld e,AFNT640_TARGET_BUF0
		call afnt_set_target
		di
		ld de,empty_text
		ld ix,0
		ld iy,0
		xor a
		call aprint
		ld a,i
		ld a,19
		call t_expect_po

		call t_end
		halt

set_rgmod_fixture:
		ld (afnt_resolve_front+1),a
		ld (afnt_resolve_back+1),a
		ret

		ds #4000-$,0
		define AFNT_TEST_BUILD
		include "../../afnt640.asm"
		assert $ < #8000
