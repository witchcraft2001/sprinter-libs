; Deterministic WIP1 asset used by the WIN320.EXE Stage-5 showcase.
        device noslot64k
        org 0

        db "WIP1",1,2
        dw 12
        db 8,2                    ; page 0: two 8x8 cells
        db 16,2                   ; page 1: two 16x16 cells
        assert $ == 12

page8:
        ; slot 0: right arrow
        db #ff,#ff,#ff,#fc,#ff,#ff,#ff,#ff
        db #ff,#ff,#ff,#fc,#fc,#ff,#ff,#ff
        db #ff,#fb,#fb,#fb,#fb,#fb,#ff,#ff
        db #fb,#fb,#fb,#fb,#fb,#fb,#fb,#ff
        db #ff,#fb,#fb,#fb,#fb,#fb,#ff,#ff
        db #ff,#ff,#ff,#fc,#fc,#ff,#ff,#ff
        db #ff,#ff,#ff,#fc,#ff,#ff,#ff,#ff
        db #ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff
        assert $ == page8+64
        ; slot 1: focus marker
        db #fa,#fa,#ff,#ff,#ff,#ff,#fa,#fa
        db #fa,#fa,#fa,#ff,#ff,#fa,#fa,#fa
        db #ff,#fa,#fa,#fa,#fa,#fa,#fa,#ff
        db #ff,#ff,#fa,#fa,#fa,#fa,#ff,#ff
        db #ff,#ff,#fa,#fa,#fa,#fa,#ff,#ff
        db #ff,#fa,#fa,#fa,#fa,#fa,#fa,#ff
        db #fa,#fa,#fa,#ff,#ff,#fa,#fa,#fa
        db #fa,#fa,#ff,#ff,#ff,#ff,#fa,#fa
        assert $ == page8+128
        ds page8+#4000-$,#ff

page16:
        ; slot 0: folder
        ds 16,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#fe,#ff,#ff
        db #ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff
        ds 16,#ff
        assert $ == page16+256
        ; slot 1: document
        db #ff,#ff,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#ff,#ff,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#f9,#ff,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#f9,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#fb,#fb,#fb,#fb,#fb,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#fb,#fb,#fb,#fb,#fb,#fb,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#fb,#fb,#fb,#fb,#fb,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#fb,#fb,#fb,#fb,#fb,#fb,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#ff,#f9,#ff,#ff,#ff
        db #ff,#ff,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#f9,#ff,#ff,#ff
        ds 16,#ff
        ds 16,#ff
        ds 16,#ff
        assert $ == page16+512
        ds page16+#4000-$,#ff

        assert $ == 12+2*#4000
