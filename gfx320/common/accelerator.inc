; Shared Sprinter accelerator opcodes.  ACC_SET_SIZE must be followed by
; `LD A,n`: hardware samples that instruction's immediate operand. Dynamic
; sizes therefore require a self-modifying `LD A,n`. Every triggered block
; command must be followed immediately by ACC_OFF.

        macro ACC_SET_SIZE
        ld d,d
        endm

        macro ACC_FILL_H
        ld c,c
        endm

        macro ACC_FILL_V
        ld e,e
        endm

        macro ACC_COPY_H
        ld l,l
        endm

        macro ACC_OFF
        ld b,b
        endm
