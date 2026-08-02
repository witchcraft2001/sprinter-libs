        ifndef RELOC_DELTA
RELOC_DELTA equ 0
        endif

        device noslot64k

        include "win320.inc"
        include "win320_layout.inc"
        include "build/stage5_symbols.inc"

YPORT                   equ #89
VIDEO_PAGE              equ #50

        org 0
        ds S5_OVERLAY_OFFSET+RELOC_DELTA,0
        jp win_icon
        jp win_progress_init
        jp win_progress_draw
        jp win_scrollbar_init
        jp win_scrollbar_draw
        jp win_listbox_draw
        jp s5_hit_detail
        jp win_checkbox
        jp win_radiobutton
        jp s6_choice_item
        jp s6_validate_choice_item
        jp s6_choice_enabled
        jp s6_choice_click
        jp s6_choice_key
        jp s6_tab_accept

        include "stage5.inc"

        assert S5_OVERLAY_OFFSET+S5_OVERLAY_CODE_SIZE == #4000
        assert $-(S5_OVERLAY_OFFSET+RELOC_DELTA) <= S5_OVERLAY_CODE_SIZE
