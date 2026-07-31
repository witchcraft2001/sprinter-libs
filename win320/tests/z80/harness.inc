        ifndef WIN320_TEST_HARNESS
WIN320_TEST_HARNESS equ 1

TEST_RESULT equ #f800
TEST_DONE   equ #f801
TEST_FIRST  equ #f802
TEST_FAILS  equ #f803
TEST_LAST   equ #f804
DONE_MAGIC  equ #a5

t_saved_a: db 0

t_begin:
        xor a
        ld (TEST_RESULT),a
        ld (TEST_DONE),a
        ld (TEST_FIRST),a
        ld (TEST_FAILS),a
        ld (TEST_LAST),a
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

t_expect_nz:
        ret nz
        jr t_fail

t_fail:
        ld (TEST_LAST),a
        push af
        push hl
        push de
        ld a,(TEST_FAILS)
        ld e,a
        ld d,0
        ld hl,#f810
        add hl,de
        ld a,(TEST_LAST)
        ld (hl),a
        pop de
        pop hl
        pop af
        push af
        push hl
        ld hl,TEST_RESULT
        ld (hl),1
        ld hl,TEST_FAILS
        inc (hl)
        ld a,(TEST_FIRST)
        or a
        jr nz,.have_first
        pop hl
        pop af
        ld (TEST_FIRST),a
        ret
.have_first:
        pop hl
        pop af
        ret

        endif
