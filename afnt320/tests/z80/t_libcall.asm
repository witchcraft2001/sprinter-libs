		device noslot64k
		org 0
		jp start
		ds #10-$,0
		jp fake_dss
		include "harness.inc"
fake_dss:
		or a
		ret
start:
		ld sp,#bff0
		call t_begin
		ld hl,LIBMAN.lib_table
		ld (hl),1
		inc hl
		ld (hl),1
		inc hl
		ld (hl),#c0
		inc hl
		ld (hl),#dd

		ld hl,0
		ld b,AFNT320_INIT
		call LIBMAN.l_call
		ld a,1
		call t_expect_nc
		ld hl,0
		ld b,AFNT320_SET_TARGET
		ld e,AFNT320_TARGET_FRONT
		call LIBMAN.l_call
		call t_keep_a
		ld a,2
		call t_expect_nc
		ld a,(t_saved_a)
		or a
		ld a,3
		call t_expect_z
		ld hl,0
		ld b,AFNT320_SET_TARGET
		ld e,4
		call LIBMAN.l_call
		call t_keep_a
		ld a,4
		; libman 1.3 preserves A but normalises CF for non-init entries.
		call t_expect_nc
		ld a,(t_saved_a)
		cp AFNT320_ERR_ARGUMENT
		ld a,5
		call t_expect_z
		call t_end
		halt

		ds #2000-$,0
		include "libman13.asm"
		ds #c000-$,0
		define AFNT_TEST_BUILD
		include "../../afnt320.asm"
		assert $ < TEST_RESULT
