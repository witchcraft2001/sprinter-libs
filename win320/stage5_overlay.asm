        ifndef RELOC_DELTA
RELOC_DELTA equ 0
        endif

        device noslot64k

        include "win320.inc"
        include "build/stage5_symbols.inc"

YPORT                   equ #89
VIDEO_PAGE              equ #50

        org 0
        ds #351e+RELOC_DELTA,0
        jp win_icon
        jp win_progress_init
        jp win_progress_draw
        jp win_scrollbar_init
        jp win_scrollbar_draw
        jp win_listbox_draw
        jp s5_hit_detail

        include "stage5.inc"
