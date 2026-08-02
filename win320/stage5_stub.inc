; Production Stage-5 entries jump into the overlay installed by win_init.
win_icon:               jp s5_overlay_base+0
win_progress_init:      jp s5_overlay_base+3
win_progress_draw:      jp s5_overlay_base+6
win_scrollbar_init:     jp s5_overlay_base+9
win_scrollbar_draw:     jp s5_overlay_base+12
win_listbox_draw:       jp s5_overlay_base+15

        assert $ <= S5_OVERLAY_OFFSET
