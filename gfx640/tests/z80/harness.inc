        ifndef GFX640_TEST_HARNESS
GFX640_TEST_HARNESS equ 1

; The runner reads these bytes from the emulator's 64-KiB memory dump.
; A test only passes when it both reaches TEST_DONE and has no failures.
TEST_RESULT equ #e000
TEST_DONE   equ #e001
TEST_FIRST  equ #e002
TEST_FAILS  equ #e003
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

; A = assertion id. Flags are preserved by LD/CALL and consumed here.
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

t_expect_pe:
        ret pe
        jr t_fail

t_expect_po:
        ret po
        jr t_fail

t_fail:
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
