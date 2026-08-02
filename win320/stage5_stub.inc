; Production Stage-5 entries jump into the overlay installed by win_init.
win_icon                equ s5_overlay_base+0
win_progress_init       equ s5_overlay_base+3
win_progress_draw       equ s5_overlay_base+6
win_scrollbar_init      equ s5_overlay_base+9
win_scrollbar_draw      equ s5_overlay_base+12
win_listbox_draw        equ s5_overlay_base+15
win_checkbox            equ s5_overlay_base+21
win_radiobutton         equ s5_overlay_base+24
s6_choice_item          equ s5_overlay_base+27
s6_validate_choice_item equ s5_overlay_base+30
s6_choice_enabled       equ s5_overlay_base+33
s6_choice_click         equ s5_overlay_base+36
s6_choice_key           equ s5_overlay_base+39
s6_tab_accept           equ s5_overlay_base+42

        assert $ <= S5_OVERLAY_OFFSET
