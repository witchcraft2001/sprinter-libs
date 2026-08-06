TEST_RESULT equ #ff00
TEST_DONE   equ #ff01
TEST_FIRST  equ #ff02
TEST_FAILS  equ #ff03
DONE_MAGIC  equ #a5

t_saved_a: db 0

t_begin:
		xor a
		ld (TEST_RESULT),a
		ld (TEST_DONE),a
		ld (TEST_FIRST),a
		ld (TEST_FAILS),a
		ret
t_end:
		ld a,DONE_MAGIC
		ld (TEST_DONE),a
		ret
t_keep_a:
		ld (t_saved_a),a
		ret
t_expect_nc:
		ret nc
		jr t_fail
t_expect_c:
		ret c
		jr t_fail
t_expect_z:
		ret z
		jr t_fail
t_expect_pe:
		ret pe
		jr t_fail
t_expect_po:
		ret po
t_fail:
		push af
		push hl
		ld hl,TEST_RESULT
		ld (hl),1
		ld hl,TEST_FAILS
		inc (hl)
		ld a,(TEST_FIRST)
		or a
		jr nz,.have
		pop hl
		pop af
		ld (TEST_FIRST),a
		ret
.have:	pop hl
		pop af
		ret
