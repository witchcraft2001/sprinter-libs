        org #8100-512

; WIN320 visual test. WIN320.DLL must be beside this EXE.
        dw #5845
        db #45,#00
        dw #0200,#0000,#0000,#0000,#0000,#0000
        dw start,start,#bff0
        ds 490

        include "win320.inc"

        define LIBMAN_MAX_LIBS 1
        define LIBMAN_NO_LEGACY_API
        define LIBMAN_DIAGNOSTICS

DSS_SETVMOD             equ #50
DSS_GETVMOD             equ #51
DSS_SELPAGE             equ #54
DSS_WAITKEY             equ #30
DSS_EXIT                equ #41
DSS_PUTS                equ #5c
DSS_GETMEM              equ #3d
DSS_FREEMEM             equ #3e
DSS_OPEN                equ #11
DSS_CLOSE               equ #12
DSS_READ                equ #13
BIOS_GETMEMBLKPAGES     equ #c5
PAGE_PORT1              equ #a2

start:
        xor a
        ld (dll_loaded),a
        ld (backstore_allocated),a
        ld (icon_pack_allocated),a
        ld (api_status),a
        ld (test_stage),a
        ld hl,msg_banner
        ld c,DSS_PUTS
        rst #10

        ld c,DSS_GETVMOD
        rst #10
        ld (old_mode),a
        ld a,b
        ld (old_screen),a
        ld bc,#0050
        ld a,#81
        rst #10

        ld hl,dll_name
        ld a,3
        call LIBMAN.l_load
        jp c,load_failed
        ld (dll_handle),hl
        ld a,1
        ld (dll_loaded),a

        ld a,1
        ld (test_stage),a
        ld hl,(dll_handle)
        ld b,WIN_GET_VERSION
        call LIBMAN.l_call
        jp c,manager_failed
        or a
        jp nz,api_failed
        ld a,d
        cp 2
        jp nz,self_failed
        ld a,e
        cp 0
        jp nz,self_failed
        push ix
        pop hl
        ld de,WIN_CAP_CORE|WIN_CAP_EDIT|WIN_CAP_LISTBOX|WIN_CAP_SCROLLBAR|WIN_CAP_PROGRESS|WIN_CAP_ICON|WIN_CAP_FOCUS|WIN_CAP_PASCAL_STR|WIN_CAP_CHECKBOX|WIN_CAP_RADIOBUTTON
        or a
        sbc hl,de
        jp nz,self_failed

        ; Install EGA colours and clear both buffers with the default desktop.
        ld a,2
        ld (test_stage),a
        ld hl,(dll_handle)
        ld d,#ff
        ld e,WIN_STYLE_PALETTE|WIN_STYLE_CLEAR|WIN_STYLE_BOTH
        ld b,WIN_STYLE
        call LIBMAN.l_call
        jp c,manager_failed
        or a
        jp nz,api_failed

        call allocate_backstore
        jp nz,api_failed

        ifdef WIN320_BENCH
        call win_benchmark_run
        jp nz,api_failed
        call wait_step
        jp success
        endif

        ; Development shortcut for focused MAME visual/input regression runs.
        ifdef WIN320_STAGE5_ONLY
        ld a,7
        ld (test_stage),a
        call run_stage5_showcase
        jp nz,api_failed
        jp success
        endif

        xor a
        call select_target_screen
        jp nz,api_failed
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        jp nz,api_failed
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        jp nz,api_failed
        call draw_default_scene
        jp nz,api_failed

        ; A failed external WF32 must not disturb the embedded font. The final
        ; label on screen 0 is drawn only after the expected failure.
        ld a,3
        ld (test_stage),a
        ld hl,(dll_handle)
        ld de,missing_font
        ld b,WIN_LOAD_FONT
        call LIBMAN.l_call
        jp c,manager_failed
        cp WIN_ERR_FONT
        jp nz,self_failed
        ld de,label_font_ok
        ld b,WIN_LABEL
        call call_api
        jp nz,api_failed

        ld a,1
        call select_target_screen
        jp nz,api_failed
        ld e,WIN_TXT_PASCAL
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        jp nz,api_failed
        ld de,blue_theme
        ld b,WIN_SET_THEME
        call call_api
        jp nz,api_failed
        ; Apply the new desktop role too, instead of leaving screen 1 with
        ; the blue desktop installed by the initial default-theme clear.
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        jp nz,api_failed
        call draw_pascal_scene
        jp nz,api_failed

        ld a,4
        ld (test_stage),a
        call draw_stage2_sequence
        jp nz,api_failed

        ; Stage 3 is intentionally interactive: application code owns mouse
        ; INIT, then demonstrates one non-blocking poll and a blocking tracker.
        ld a,5
        ld (test_stage),a
        call run_stage3_dialog
        jp nz,api_failed

        ld a,6
        ld (test_stage),a
        call run_stage4_dialogs
        jp nz,api_failed

        ld a,7
        ld (test_stage),a
        call run_stage5_showcase
        jp nz,api_failed

        ld a,8
        ld (test_stage),a
        xor a
        call run_stage6_showcase
        jp nz,api_failed
        ld a,1
        call run_stage6_showcase
        jp nz,api_failed

        ld a,9
        ld (test_stage),a
        call run_stage7_showcase
        jp nz,api_failed

success:
        call free_library
        call restore_video
        ld hl,msg_ok
        ld c,DSS_PUTS
        rst #10
        ld bc,#0041
        rst #10
        ret

; A=screen 0/1, updates WIN320's drawing target.
select_target_screen:
        ld e,a
        ld b,WIN_SET_SCREEN
        jp call_api

; A=visible screen 0/1.
show_screen:
        ld b,a
        ld c,DSS_SELPAGE
        rst #10
        ret

; B=entry, other public registers already set.
call_api:
        ld hl,(dll_handle)
        call LIBMAN.l_call
        jr nc,.status
        ld a,#ff
.status:
        or a
        ret

allocate_backstore:
        ld b,WIN_BACKSTORE_MAX_PAGES
        ld c,DSS_GETMEM
        rst #10
        jr c,.memory
        ld (backstore_block),a
        push af
        ld a,1
        ld (backstore_allocated),a
        pop af
        ld b,WIN_BACKSTORE_MAX_PAGES
        ld hl,backstore_physical_pages
        ld c,BIOS_GETMEMBLKPAGES
        rst #08
        jr c,.memory
        ld de,backstore_physical_pages
        ld ix,WIN_BACKSTORE_MAX_PAGES
        ld b,WIN_SET_BACKSTORE
        jp call_api
.memory:
        ld a,WIN_ERR_MEMORY
        or a
        ret

draw_stage2_sequence:
        ld a,#40
        ld (test_stage),a
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld a,#41
        ld (test_stage),a
        xor a
        call select_target_screen
        ret nz
        ld a,#42
        ld (test_stage),a
        ld de,demo_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        call show_screen
        call wait_step

        ; Change two descriptors, mark only their entries dirty, and update.
        ld hl,str_dirty_done
        ld (demo_label+WIN_LBL_TEXT),hl
        ld a,14
        ld (demo_fill+WIN_RC_COLOR),a
        ld a,WIN_IT_DIRTY
        ld (demo_items+0*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld (demo_items+2*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld a,#43
        ld (test_stage),a
        ld de,demo_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step

        ; Modal A saves screen 0. Modal B is nested on screen 1.
        ld a,#44
        ld (test_stage),a
        ld de,modal_a_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        call wait_step
        ld a,#45
        ld (test_stage),a
        ld a,1
        call select_target_screen
        ret nz
        ld a,#46
        ld (test_stage),a
        ld de,modal_b_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        ld a,1
        call show_screen
        call wait_step

        ld a,#47
        ld (test_stage),a
        ld b,WIN_CLOSE
        call call_api
        ret nz
        call wait_step
        ; The global target remains screen 1, but the next LIFO close restores
        ; the saved screen-0 rectangle from its stack record.
        ld a,#48
        ld (test_stage),a
        ld b,WIN_CLOSE
        call call_api
        ret nz
        xor a
        call show_screen
        call wait_step
        xor a
        ret

run_stage3_dialog:
        xor a
        call select_target_screen
        ret nz
        ld hl,str_stage3_hint
        ld (demo_label+WIN_LBL_TEXT),hl
        ; This zone deliberately has no HOVER flag: the test must wait for a
        ; visible mouse action rather than returning immediately on entry.
        ld a,WIN_IT_DIRTY|WIN_IT_HIT
        ld (demo_items+4*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,demo_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        ld (stage3_track+WIN_TRK_STATE),a
        ld (stage3_track+WIN_TRK_STATE+1),a
        ld (stage3_track+WIN_TRK_STATE+2),a
        ld (stage3_track+WIN_TRK_STATE+3),a
        ld (stage3_track+WIN_TRK_STATE+4),a
        ld (stage3_track+WIN_TRK_STATE+5),a
        ld (stage3_track+WIN_TRK_STATE+6),a
        ld (stage3_track+WIN_TRK_STATE+7),a
        ld c,0                       ; mandatory application-side Mouse INIT
        rst #30
        ld e,0                       ; install a defined BIOS cursor sprite
        ld b,WIN_SET_CURSOR
        call call_api
        ret nz
        ld hl,160                    ; keep the first SHOW away from an edge
        ld de,128
        ld c,4
        rst #30
        ld c,1                       ; poll must leave this visible cursor up
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
        ld de,stage3_track
        ld b,WIN_POLL
        call call_api
        ret nz
        ld c,2                       ; win_track owns the next SHOW/HIDE pair
        rst #30
        ld de,stage3_track
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld hl,str_stage3_done
        ld (demo_label+WIN_LBL_TEXT),hl
        ld a,WIN_IT_DIRTY
        ld (demo_items+0*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,demo_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step
        xor a
        ret

run_stage4_dialogs:
        ; Screen 0: edit remains modal while it owns focus. Tab hands control
        ; to win_track so Enter really animates and activates the button;
        ; another Tab returns to the field without requiring a mouse.
        xor a
        call select_target_screen
        ret nz
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz
        xor a
        ld (stage4_window_a+WIN_WND_FOCUS),a
        ld a,#ff
        ld (stage4_window_a+WIN_WND_LAST_FOCUS),a
        ld hl,stage4_track_a+WIN_TRK_STATE
        ld b,8
.clear_a:
        ld (hl),0
        inc hl
        djnz .clear_a
        ld de,stage4_window_a
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        call show_screen
        ld c,1
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
.edit_a:
        ld ix,24
        ld e,36
        ld b,WIN_SET_ORIGIN
        call call_api
        jr nz,.fail_visible_a
        ld de,stage4_edit_a
        ld ix,stage4_track_a
        ld b,WIN_EDIT
        call call_api
        ld (stage4_api_status),a
        ld a,e
        ld (stage4_reason),a
        ld ix,0
        ld e,0
        ld b,WIN_SET_ORIGIN
        call call_api
        jr nz,.fail_visible_a
        ld a,(stage4_api_status)
        or a
        jr nz,.fail_visible_a
        ld a,(stage4_reason)
        cp WIN_ED_TAB
        jr z,.track_a
        ld c,2
        rst #30
        ld a,(stage4_reason)
        cp WIN_ED_ESC
        ld hl,str_stage4_result_enter
        jr nz,.result_a_reason
        ld hl,str_stage4_result_esc
.result_a_reason:
        ld a,(stage4_reason)
        cp WIN_ED_MOUSE
        jr nz,.result_a
        ld hl,str_stage4_result_mouse
.result_a:
        ld (stage4_label_a+WIN_LBL_TEXT),hl
        ld a,WIN_IT_DIRTY
        ld (stage4_items_a+WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,stage4_window_a
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step

        jr .screen_p
.fail_visible_a:
        push af
        ld c,2
        rst #30
        pop af
        or a
        ret
.track_a:
        ; win_edit leaves the application-owned cursor visible. win_track owns
        ; visibility during its blocking call, so hand it a hidden cursor.
        ld c,2
        rst #30
.track_a_again:
        ld de,stage4_track_a
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld a,(stage4_window_a+WIN_WND_FOCUS)
        or a
        jr z,.resume_edit_a
        ld a,(stage4_track_a+WIN_TRK_EVENT)
        cp WIN_EV_LCLICK
        jr nz,.track_a_again
        ld a,(stage4_track_a+WIN_TRK_ID)
        cp 21
        jr nz,.track_a_again
        ld hl,str_stage4_result_button
        jp .result_a
.resume_edit_a:
        ld c,1
        rst #30
        jp .edit_a

        ; Screen 1: Pascal string with password masking and the same focus
        ; semantics. The backing buffer remains a normal Pascal string.
.screen_p:
        ld a,1
        call select_target_screen
        ret nz
        ld e,WIN_TXT_PASCAL
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,blue_theme
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz
        xor a
        ld (stage4_window_p+WIN_WND_FOCUS),a
        ld a,#ff
        ld (stage4_window_p+WIN_WND_LAST_FOCUS),a
        ld hl,stage4_track_p+WIN_TRK_STATE
        ld b,8
.clear_p:
        ld (hl),0
        inc hl
        djnz .clear_p
        ld de,stage4_window_p
        ld b,WIN_DRAW
        call call_api
        ret nz
        ld a,1
        call show_screen
        ld c,1
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
.edit_p:
        ld ix,24
        ld e,36
        ld b,WIN_SET_ORIGIN
        call call_api
        jr nz,.fail_visible_p
        ld de,stage4_edit_p
        ld ix,stage4_track_p
        ld b,WIN_EDIT
        call call_api
        ld (stage4_api_status),a
        ld a,e
        ld (stage4_reason),a
        ld ix,0
        ld e,0
        ld b,WIN_SET_ORIGIN
        call call_api
        jr nz,.fail_visible_p
        ld a,(stage4_api_status)
        or a
        jr nz,.fail_visible_p
        ld a,(stage4_reason)
        cp WIN_ED_TAB
        jr z,.track_p
        ld c,2
        rst #30
        ld a,(stage4_reason)
        cp WIN_ED_ESC
        ld hl,pstr_stage4_result_enter
        jr nz,.result_p_reason
        ld hl,pstr_stage4_result_esc
.result_p_reason:
        ld a,(stage4_reason)
        cp WIN_ED_MOUSE
        jr nz,.result_p
        ld hl,pstr_stage4_result_mouse
.result_p:
        ld (stage4_label_p+WIN_LBL_TEXT),hl
        ld a,WIN_IT_DIRTY
        ld (stage4_items_p+WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,stage4_window_p
        ld b,WIN_UPDATE
        call call_api
        ret nz
        call wait_step
        xor a
        ret
.fail_visible_p:
        push af
        ld c,2
        rst #30
        pop af
        or a
        ret
.track_p:
        ld c,2
        rst #30
.track_p_again:
        ld de,stage4_track_p
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld a,(stage4_window_p+WIN_WND_FOCUS)
        or a
        jr z,.resume_edit_p
        ld a,(stage4_track_p+WIN_TRK_EVENT)
        cp WIN_EV_LCLICK
        jr nz,.track_p_again
        ld a,(stage4_track_p+WIN_TRK_ID)
        cp 31
        jr nz,.track_p_again
        ld hl,pstr_stage4_result_button
        jp .result_p
.resume_edit_p:
        ld c,1
        rst #30
        jp .edit_p

run_stage5_showcase:
        call load_icon_pack
        ret nz
        ld a,#80
        ld (test_stage),a
        xor a
        call select_target_screen
        ret nz
        ld a,#81
        ld (test_stage),a
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz
        ld a,#82
        ld (test_stage),a
        ld de,stage5_progress
        ld b,WIN_PROGRESS_INIT
        call call_api
        ret nz
        ld a,#83
        ld (test_stage),a
        ld de,stage5_scrollbar
        ld b,WIN_SCROLLBAR_INIT
        call call_api
        ret nz
        ld a,#84
        ld (test_stage),a
        ld de,stage5_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        xor a
        call show_screen

        ; Direct progress calls use the same origin as their declarative item.
        ld a,#85
        ld (test_stage),a
        ld ix,16
        ld e,16
        ld b,WIN_SET_ORIGIN
        call call_api
        ret nz
        ld a,#86
        ld (test_stage),a
        xor a
.progress_up:
        ld (stage5_progress+WIN_PG_PERCENT),a
        push af
        ld de,stage5_progress
        ld b,WIN_PROGRESS_DRAW
        call call_api
        jr nz,.progress_failed
        halt
        pop af
        inc a
        cp 101
        jr nz,.progress_up
        ld a,100
.progress_down:
        ld (stage5_progress+WIN_PG_PERCENT),a
        push af
        ld de,stage5_progress
        ld b,WIN_PROGRESS_DRAW
        call call_api
        jr nz,.progress_failed
        halt
        pop af
        or a
        jr z,.progress_done
        dec a
        jr .progress_down
.progress_failed:
        ld (api_status),a
        pop af
        xor a
        ld ix,0
        ld e,0
        ld b,WIN_SET_ORIGIN
        call call_api
        ld a,(api_status)
        or a
        ret
.progress_done:
        ld a,#87
        ld (test_stage),a
        ld ix,0
        ld e,0
        ld b,WIN_SET_ORIGIN
        call call_api
        ret nz
        ld a,#88
        ld (test_stage),a
        ifdef WIN320_STAGE5_AUTOMATED
        ; Headless visual regression stops on the stable initial page.
        call wait_step
        xor a
        ret
        else
        jp stage5_interact
        endif

; The library reports list rows and scrollbar parts; selection policy remains
; application-owned.  This demo makes that contract visible and usable.
stage5_interact:
        ld hl,stage5_track+WIN_TRK_STATE
        ld b,WIN_TRACK_SIZE-WIN_TRK_STATE
        xor a
.clear_state:
        ld (hl),a
        inc hl
        djnz .clear_state
        ld c,0                       ; application-side Mouse INIT
        rst #30
        ld e,0
        ld b,WIN_SET_CURSOR
        call call_api
        ret nz
        ld hl,160
        ld de,128
        ld c,4
        rst #30
        ld c,1
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
        ld c,2                       ; win_track owns SHOW/HIDE from here
        rst #30
.track:
        ld de,stage5_track
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld a,(stage5_track+WIN_TRK_EVENT)
        cp WIN_EV_RCLICK
        jr z,.track
        cp WIN_EV_OUTSIDE
        jr z,.track
        cp WIN_EV_KEY
        jr z,.key
        cp WIN_EV_LCLICK
        jr z,.mouse
        cp WIN_EV_REPEAT
        jr nz,.track
.mouse:
        ld a,(stage5_track+WIN_TRK_ID)
        cp 42
        jp z,.done
        cp 40
        jr z,.list_click
        cp 41
        jr nz,.track
        ld a,(stage5_track+WIN_TRK_PART)
        cp WIN_SB_PART_BACK
        jr z,.up
        cp WIN_SB_PART_FORWARD
        jr z,.down
        cp WIN_SB_PART_PAGE_BACK
        jr z,.page_up
        cp WIN_SB_PART_PAGE_FORWARD
        jr z,.page_down
        jr .track
.list_click:
        ld hl,(stage5_track+WIN_TRK_ITEM)
        ld a,h
        and l
        inc a
        jr z,.track
        jr .select
.key:
        ld a,(stage5_track+WIN_TRK_KEY_ASCII)
        cp #1b
        jp z,.done
        ld a,(stage5_window+WIN_WND_FOCUS)
        cp 1                         ; keyboard navigation belongs to listbox
        jp nz,.track
        ld a,(stage5_track+WIN_TRK_KEY_SCAN)
        and #7f
        cp #58                       ; Up
        jr z,.up
        cp #52                       ; Down
        jr z,.down
        cp #59                       ; Page Up
        jr z,.page_up
        cp #53                       ; Page Down
        jr z,.page_down
        cp #57                       ; Home
        jr z,.home
        cp #51                       ; End
        jr z,.end
        jr .track
.up:
        ld hl,(stage5_listbox+WIN_LB_CURSOR)
        ld a,h
        or l
        jp z,.track
        dec hl
        jr .select
.down:
        ld hl,(stage5_listbox+WIN_LB_CURSOR)
        ld de,11
        or a
        sbc hl,de
        jp z,.track
        add hl,de
        inc hl
        jr .select
.page_up:
        ld hl,(stage5_listbox+WIN_LB_CURSOR)
        ld de,8
        or a
        sbc hl,de
        jr nc,.select
.home:
        ld hl,0
        jr .select
.page_down:
        ld hl,(stage5_listbox+WIN_LB_CURSOR)
        ld de,8
        add hl,de
        ld de,12
        or a
        sbc hl,de
        jr c,.restore_page
.end:
        ld hl,11
        jr .select
.restore_page:
        add hl,de
.select:
        ld (stage5_listbox+WIN_LB_CURSOR),hl
        ld de,(stage5_listbox+WIN_LB_FIRST)
        push hl
        or a
        sbc hl,de
        pop hl
        jr c,.new_first
        push hl
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.below_view
        ld a,l
        cp 8
.below_view:
        pop hl
        jr c,.redraw
        ld de,7
        or a
        sbc hl,de
.new_first:
        ld (stage5_listbox+WIN_LB_FIRST),hl
.redraw:
        ld a,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_FOCUSABLE
        ld (stage5_items+1*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld a,WIN_IT_DIRTY|WIN_IT_HIT|WIN_IT_REPEAT
        ld (stage5_items+2*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,stage5_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        jp .track
.done:
        xor a
        ret

; Separate ABI-1.1 screen on each video buffer. WIN320 owns choice state,
; group selection, focus, cursor-safe redraw and CHANGE publication; the
; application updates only the compact state label after each real change.
run_stage6_showcase:
        ld (stage6_screen),a
        call select_target_screen
        ret nz
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz

        xor a
        ld (stage6_checkbox+WIN_CH_FLAGS),a
        ld a,WIN_CH_DISABLED
        ld (stage6_checkbox_disabled+WIN_CH_FLAGS),a
        ld a,WIN_CH_CHECKED
        ld (stage6_radio_audio_a+WIN_CH_FLAGS),a
        ld (stage6_radio_view_a+WIN_CH_FLAGS),a
        xor a
        ld (stage6_radio_audio_b+WIN_CH_FLAGS),a
        ld (stage6_radio_view_b+WIN_CH_FLAGS),a
        ld a,1
        ld (stage6_window+WIN_WND_FOCUS),a
        ld a,#ff
        ld (stage6_window+WIN_WND_LAST_FOCUS),a
        call stage6_write_status
        ld de,stage6_window
        ld b,WIN_DRAW
        call call_api
        ret nz
        ld a,(stage6_screen)
        call show_screen

        ld hl,stage6_track+WIN_TRK_STATE
        ld b,WIN_TRACK_SIZE-WIN_TRK_STATE
        xor a
.clear_state:
        ld (hl),a
        inc hl
        djnz .clear_state
        ld c,0                       ; application-side Mouse INIT
        rst #30
        ld e,0
        ld b,WIN_SET_CURSOR
        call call_api
        ret nz
        ld hl,160
        ld de,128
        ld c,4
        rst #30
        ld c,1
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
        ld c,2                       ; win_track owns SHOW/HIDE
        rst #30
.track:
        ld de,stage6_track
        ld b,WIN_TRACK
        call call_api
        ret nz
        ld a,(stage6_track+WIN_TRK_EVENT)
        cp WIN_EV_CHANGE
        jr z,.changed
        cp WIN_EV_LCLICK
        jr nz,.key
        ld a,(stage6_track+WIN_TRK_ID)
        cp 87
        jr z,.done
        jr .track
.key:
        ld a,(stage6_track+WIN_TRK_EVENT)
        cp WIN_EV_KEY
        jr nz,.track
        ld a,(stage6_track+WIN_TRK_KEY_ASCII)
        cp #1b
        jr z,.done
        jr .track
.changed:
        call stage6_write_status
        ld a,WIN_IT_DIRTY
        ld (stage6_items+7*WIN_ITEM_SIZE+WIN_ITEM_FLAGS),a
        ld de,stage6_window
        ld b,WIN_UPDATE
        call call_api
        ret nz
        jr .track
.done:
        xor a
        ret

stage6_write_status:
        ld a,'0'
        ld hl,stage6_checkbox+WIN_CH_FLAGS
        bit 0,(hl)
        jr z,.checkbox
        inc a
.checkbox:
        ld (str_stage6_status+6),a
        ld a,'A'
        ld hl,stage6_radio_audio_b+WIN_CH_FLAGS
        bit 0,(hl)
        jr z,.audio
        inc a
.audio:
        ld (str_stage6_status+15),a
        ld a,'1'
        ld hl,stage6_radio_view_b+WIN_CH_FLAGS
        bit 0,(hl)
        jr z,.view
        inc a
.view:
        ld (str_stage6_status+23),a
        ret

stage6_screen:          db 0

; A window title/close button are properties of WinWindow, not items: no
; extra declarative entries are needed beyond the ones the dialog itself
; wants. The companion window has no title at all, drawn for contrast.
run_stage7_showcase:
        xor a
        call select_target_screen
        ret nz
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz

        ld de,stage7_plain_window
        ld b,WIN_DRAW
        call call_api
        ret nz

        xor a
        ld (stage7_theme_toggle),a
        call stage7_write_status
        ld de,stage7_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        xor a
        call show_screen

        ld hl,stage7_track+WIN_TRK_STATE
        ld b,WIN_TRACK_SIZE-WIN_TRK_STATE
        xor a
.clear_state:
        ld (hl),a
        inc hl
        djnz .clear_state
        ld c,0                       ; application-side Mouse INIT
        rst #30
        ld e,0
        ld b,WIN_SET_CURSOR
        call call_api
        ret nz
        ld hl,160
        ld de,128
        ld c,4
        rst #30
        ld c,1
        rst #30
        ld b,WIN_WAIT_RELEASE
        call call_api
        ret nz
        ld c,2                       ; win_track owns SHOW/HIDE
        rst #30
.track:
        ld de,stage7_track
        ld b,WIN_TRACK
        call call_api
        jr nz,.close
        ld a,(stage7_track+WIN_TRK_EVENT)
        cp WIN_EV_CLOSE
        jr z,.close
        cp WIN_EV_LCLICK
        jr nz,.key
        ld a,(stage7_track+WIN_TRK_ID)
        cp 91                         ; Exit button
        jr z,.close
        cp 90                         ; Theme button
        jr nz,.track
        ld hl,stage7_theme_toggle
        ld a,(hl)
        xor 1
        ld (hl),a
        call stage7_apply_theme
        jr nz,.close
        jr .track
.key:
        ld a,(stage7_track+WIN_TRK_EVENT)
        cp WIN_EV_KEY
        jr nz,.track
        ld a,(stage7_track+WIN_TRK_KEY_ASCII)
        cp #1b
        jr nz,.track
.close:
        ld b,WIN_CLOSE
        call call_api
        ret nz
        call wait_step
        xor a
        ret

; Toggling the title's theme requires a full WIN_DRAW: the title bar is
; painted by the same declarative-window pass as the item list, not by
; WIN_UPDATE's dirty-item-only path.
stage7_apply_theme:
        ld a,(stage7_theme_toggle)
        or a
        ld de,0
        jr z,.set
        ld de,stage7_theme_alt
.set:
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        call stage7_write_status
        ld de,stage7_window
        ld b,WIN_DRAW
        jp call_api

stage7_write_status:
        ld a,(stage7_theme_toggle)
        add a,'0'
        ld (str_stage7_status+13),a
        ret

        ifdef WIN320_BENCH
; Hardware timing harness. CTC channels 2/3 form an exact 500-Hz source from
; the fixed 7-MHz clock. Results are batches measured through the public ABI;
; one result tick is rendered as two pixels, so bar width equals milliseconds.
WIN_BENCH_CTC_CH0       equ #10
WIN_BENCH_CTC_CH2       equ #12
WIN_BENCH_CTC_CH3       equ #13

win_benchmark_run:
        xor a
        call select_target_screen
        ret nz
        ld e,WIN_TXT_ASCIIZ
        ld b,WIN_SET_TEXT_FORMAT
        call call_api
        ret nz
        ld de,0
        ld b,WIN_SET_THEME
        call call_api
        ret nz
        ld d,#ff
        ld e,WIN_STYLE_CLEAR
        ld b,WIN_STYLE
        call call_api
        ret nz
        xor a
        call show_screen

        call win_benchmark_im2_setup

        ld hl,1
        ld (win_benchmark_rect+WIN_RC_WIDTH),hl
        ld a,128
        call win_benchmark_invert_batch
        jr nz,.failed
        ld (win_benchmark_invert1_ticks),hl

        ld hl,8
        ld (win_benchmark_rect+WIN_RC_WIDTH),hl
        ld a,128
        call win_benchmark_invert_batch
        jr nz,.failed
        ld (win_benchmark_invert8_ticks),hl

        ld hl,32
        ld (win_benchmark_rect+WIN_RC_WIDTH),hl
        ld a,64
        call win_benchmark_invert_batch
        jr nz,.failed
        ld (win_benchmark_invert32_ticks),hl

        ld hl,320
        ld (win_benchmark_rect+WIN_RC_WIDTH),hl
        ld a,16
        call win_benchmark_invert_batch
        jr nz,.failed
        ld (win_benchmark_invert320_ticks),hl

        ld a,4
        call win_benchmark_backstore_batch
        jr nz,.failed
        ld (win_benchmark_backstore_ticks),hl

        call win_benchmark_im2_stop
        call win_benchmark_draw_results
        ret
.failed:
        push af
        call win_benchmark_im2_stop
        pop af
        or a
        ret

; A=iterations, returns HL=elapsed 2-ms ticks or A!=0.
win_benchmark_invert_batch:
        ld (win_benchmark_loops),a
        call win_benchmark_start
.loop:
        ld de,win_benchmark_rect
        ld b,WIN_INVERT_RECT
        call call_api
        ret nz
        call win_benchmark_dec_loop
        jr nz,.loop
        call win_benchmark_stop
        xor a
        ret

; A=iterations of save+restore for a 320x64 NOPANEL window.
win_benchmark_backstore_batch:
        ld (win_benchmark_loops),a
        call win_benchmark_start
.loop:
        ld de,win_benchmark_window
        ld b,WIN_OPEN
        call call_api
        ret nz
        ld b,WIN_CLOSE
        call call_api
        ret nz
        call win_benchmark_dec_loop
        jr nz,.loop
        call win_benchmark_stop
        xor a
        ret

win_benchmark_dec_loop:
        ld a,(win_benchmark_loops)
        dec a
        ld (win_benchmark_loops),a
        ret

win_benchmark_start:
        call win_benchmark_wait_tick
        ld hl,(win_benchmark_counter)
        ld (win_benchmark_started),hl
        ret

win_benchmark_stop:
        ld hl,(win_benchmark_counter)
        ld de,(win_benchmark_started)
        or a
        sbc hl,de
        ret

win_benchmark_wait_tick:
        ld hl,(win_benchmark_counter)
.wait:
        halt
        ld de,(win_benchmark_counter)
        ld a,h
        cp d
        jr nz,.changed
        ld a,l
        cp e
        jr z,.wait
.changed:
        ret

win_benchmark_im2_setup:
        di
        ld hl,win_benchmark_im2_table
        ld de,win_benchmark_im2_empty
        ld b,128
.fill:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .fill
        ld hl,win_benchmark_im2_handler
        ld (win_benchmark_im2_table+6),hl
        ld hl,win_benchmark_im2_empty
        ld (win_benchmark_im2_table+#ff),hl
        ld a,i
        ld (win_benchmark_saved_i),a
        ld a,high win_benchmark_im2_table
        ld i,a
        im 2
        ld a,#57
        out (WIN_BENCH_CTC_CH2),a
        ld a,112
        out (WIN_BENCH_CTC_CH2),a
        ld a,#d7
        out (WIN_BENCH_CTC_CH3),a
        ld a,125
        out (WIN_BENCH_CTC_CH3),a
        xor a
        out (WIN_BENCH_CTC_CH0),a
        ld (win_benchmark_counter),a
        ld (win_benchmark_counter+1),a
        ei
        ret

win_benchmark_im2_stop:
        di
        ld a,3
        out (WIN_BENCH_CTC_CH2),a
        out (WIN_BENCH_CTC_CH3),a
        ld a,(win_benchmark_saved_i)
        ld i,a
        im 1
        ei
        ret

win_benchmark_im2_handler:
        push af
        push hl
        ld hl,win_benchmark_counter
        inc (hl)
        jr nz,.done
        inc hl
        inc (hl)
.done:
        pop hl
        pop af
        ei
        reti

win_benchmark_im2_empty:
        ei
        reti

win_benchmark_draw_results:
        ld hl,win_benchmark_invert1_ticks
        ld de,24
        ld a,4
        call win_benchmark_bar
        ret nz
        ld hl,win_benchmark_invert8_ticks
        ld de,48
        ld a,2
        call win_benchmark_bar
        ret nz
        ld hl,win_benchmark_invert32_ticks
        ld de,72
        ld a,3
        call win_benchmark_bar
        ret nz
        ld hl,win_benchmark_invert320_ticks
        ld de,96
        ld a,6
        call win_benchmark_bar
        ret nz
        ld hl,win_benchmark_backstore_ticks
        ld de,120
        ld a,5
        jp win_benchmark_bar

; HL=&ticks, DE=y, A=colour. Width is ticks*2, clamped to 320 pixels.
win_benchmark_bar:
        ld (win_benchmark_bar_rect+WIN_RC_Y),de
        ld (win_benchmark_bar_rect+WIN_RC_COLOR),a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        add hl,hl
        ld de,321
        or a
        sbc hl,de
        add hl,de
        jr c,.width_ready
        ld hl,320
.width_ready:
        ld (win_benchmark_bar_rect+WIN_RC_WIDTH),hl
        ld de,win_benchmark_bar_rect
        ld b,WIN_FILL_RECT
        jp call_api

win_benchmark_rect:
        dw 0,8,1,1
        db #ff,0
win_benchmark_bar_rect:
        dw 0,24,0,8
        db 4,0
win_benchmark_window:
        dw 0,160,320,64
        db #ff,WIN_WND_NOPANEL,0,#ff
        dw 0
        dw 0
        db #ff,#ff
        dw 0

win_benchmark_counter:          dw 0
win_benchmark_started:          dw 0
win_benchmark_invert1_ticks:    dw 0
win_benchmark_invert8_ticks:    dw 0
win_benchmark_invert32_ticks:   dw 0
win_benchmark_invert320_ticks:  dw 0
win_benchmark_backstore_ticks:  dw 0
win_benchmark_loops:            db 0
win_benchmark_saved_i:          db 0

        align 256
win_benchmark_im2_table:        ds 257
        endif

; Load the two payload pages of ICONS.WIP into application-owned EMM.
load_icon_pack:
        ld a,#70
        ld (test_stage),a
        ld hl,icon_pack_name
        ld a,1
        ld c,DSS_OPEN
        rst #10
        jp c,.bad
        ld (icon_pack_handle),a
        ld a,#71
        ld (test_stage),a
        ld a,(icon_pack_handle)
        ld hl,icon_pack_header
        ld de,12
        ld c,DSS_READ
        rst #10
        jp c,.close_bad
        ; Old DSS revisions do not consistently publish the transferred byte
        ; count in DE.  Like FlexNavigator, trust CF and validate the bytes.
        ld a,#72
        ld (test_stage),a
        ld hl,icon_pack_header
        ld de,icon_pack_expected
        ld b,12
.header:
        ld a,(de)
        cp (hl)
        jp nz,.close_bad
        inc de
        inc hl
        djnz .header
        ld a,#73
        ld (test_stage),a
        ld b,2
        ld c,DSS_GETMEM
        rst #10
        jp c,.close_memory
        ld (icon_pack_block),a
        ld a,1
        ld (icon_pack_allocated),a
        ld a,#74
        ld (test_stage),a
        ld a,(icon_pack_block)
        ld b,2
        ld hl,icon_physical_pages
        ld c,BIOS_GETMEMBLKPAGES
        rst #08
        jp c,.close_memory
        in a,(PAGE_PORT1)
        ld (icon_saved_win1),a
        xor a
        ld (icon_page_index),a
.page:
        add a,#75
        ld (test_stage),a
        ld a,(icon_page_index)
        ld e,a
        ld d,0
        ld hl,icon_physical_pages
        add hl,de
        ld a,(hl)
        out (PAGE_PORT1),a
        ld a,(icon_pack_handle)
        ld hl,#4000
        ld de,#4000
        ld c,DSS_READ
        rst #10
        jr c,.mapped_bad
        ld a,(icon_page_index)
        inc a
        ld (icon_page_index),a
        cp 2
        jr nz,.page
        ld a,(icon_saved_win1)
        out (PAGE_PORT1),a
        ld a,#77
        ld (test_stage),a
        ld a,(icon_pack_handle)
        ld c,DSS_CLOSE
        rst #10
        jr c,.bad
        ld a,(icon_physical_pages)
        ld (stage5_icon8_a+WIN_ICO_PAGE),a
        ld (stage5_icon8_b+WIN_ICO_PAGE),a
        ld a,(icon_physical_pages+1)
        ld (stage5_icon16_a+WIN_ICO_PAGE),a
        ld (stage5_icon16_b+WIN_ICO_PAGE),a
        xor a
        ret
.mapped_bad:
        ld a,(icon_saved_win1)
        out (PAGE_PORT1),a
.close_bad:
        ld a,(icon_pack_handle)
        ld c,DSS_CLOSE
        rst #10
.bad:
        ld a,WIN_ERR_ARGUMENT
        or a
        ret
.close_memory:
        ld a,(icon_pack_handle)
        ld c,DSS_CLOSE
        rst #10
        ld a,WIN_ERR_MEMORY
        or a
        ret

wait_step:
        ld c,DSS_WAITKEY
        rst #10
        ret

draw_default_scene:
        ld de,desktop_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,inner_frame
        ld b,WIN_FRAME
        call call_api
        ret nz
        ld de,h_separator
        ld b,WIN_SEPARATOR
        call call_api
        ret nz
        ld de,v_separator
        ld b,WIN_SEPARATOR
        call call_api
        ret nz
        ld de,label_title
        ld b,WIN_LABEL
        call call_api
        ret nz
        ld de,label_clip
        ld b,WIN_LABEL
        call call_api
        ret nz
        call draw_buttons_asciiz
        ret nz
        ld de,invert_band
        ld b,WIN_INVERT_RECT
        call call_api
        ret nz
        ld de,focus_demo
        ld b,WIN_FOCUS_RECT
        call call_api
        ret nz
        ld de,bottom_right
        ld b,WIN_FILL_RECT
        call call_api
        ret nz
        ld de,label_page0_hint
        ld b,WIN_LABEL
        jp call_api

draw_pascal_scene:
        ld de,desktop_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,sunken_panel
        ld b,WIN_PANEL
        call call_api
        ret nz
        ld de,pascal_title
        ld b,WIN_LABEL
        call call_api
        ret nz
        ld de,pascal_center
        ld b,WIN_LABEL
        call call_api
        ret nz
        call draw_buttons_pascal
        ret nz
        ld de,focus_demo
        ld b,WIN_FOCUS_RECT
        call call_api
        ret nz
        ld de,pascal_hint
        ld b,WIN_LABEL
        jp call_api

draw_buttons_asciiz:
        ld de,button_normal
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_focus
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_pressed
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_disabled
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,button_glyph
        ld b,WIN_BUTTON
        jp call_api

draw_buttons_pascal:
        ld de,pbutton_normal
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_focus
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_pressed
        ld b,WIN_BUTTON
        call call_api
        ret nz
        ld de,pbutton_disabled
        ld b,WIN_BUTTON
        jp call_api

manager_failed:
        ld a,#ff
        jr failed
api_failed:
        ; A already contains the WIN_ERR_* status.
        jr failed
self_failed:
        ld a,#fe
failed:
        ld (api_status),a
        call free_library
        call restore_video
        ld hl,msg_failed
        ld c,DSS_PUTS
        rst #10
        ld a,(test_stage)
        call print_hex8
        ld hl,msg_status
        ld c,DSS_PUTS
        rst #10
        ld a,(api_status)
        call print_hex8
        ld hl,msg_newline
        ld c,DSS_PUTS
        rst #10
        ld c,DSS_WAITKEY
        rst #10
        ld bc,#0041
        rst #10
        ret

load_failed:
        call restore_video
        ld hl,msg_load_failed
        ld c,DSS_PUTS
        rst #10
        ld a,(LIBMAN.l_reason)
        call print_hex8
        ld hl,msg_dss
        ld c,DSS_PUTS
        rst #10
        ld a,(LIBMAN.l_dss_error)
        call print_hex8
        ld hl,msg_newline
        ld c,DSS_PUTS
        rst #10
        ld c,DSS_WAITKEY
        rst #10
        ld bc,#0041
        rst #10
        ret

free_library:
        call free_icon_pack
        ld a,(dll_loaded)
        or a
        jr z,free_backstore
        xor a
        ld (dll_loaded),a
        ld hl,(dll_handle)
        call LIBMAN.l_free
        jr free_backstore

free_icon_pack:
        ld a,(icon_pack_allocated)
        or a
        ret z
        xor a
        ld (icon_pack_allocated),a
        ld a,(icon_pack_block)
        ld c,DSS_FREEMEM
        rst #10
        ret

free_backstore:
        ld a,(backstore_allocated)
        or a
        ret z
        xor a
        ld (backstore_allocated),a
        ld a,(backstore_block)
        ld c,DSS_FREEMEM
        rst #10
        ret

restore_video:
        ld a,(old_screen)
        ld b,a
        ld a,(old_mode)
        ld c,DSS_SETVMOD
        rst #10
        ret

print_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call hex_nibble
        call putc
        pop af
        call hex_nibble
        jp putc

hex_nibble:
        and #0f
        add a,'0'
        cp '9'+1
        ret c
        add a,'A'-'9'-1
        ret

putc:
        ld (char_buffer),a
        ld hl,char_buffer
        ld c,DSS_PUTS
        rst #10
        ret

; ---- descriptors -----------------------------------------------------------

desktop_panel:
        dw 4,4,312,248
        db #ff,0
inner_frame:
        dw 12,12,296,224
        db 0,WIN_RC_SUNKEN
sunken_panel:
        dw 20,30,280,192
        db #ff,WIN_RC_SUNKEN
h_separator:
        dw 20,42,280,2
        db 0,0
v_separator:
        dw 158,50,2,170
        db 0,WIN_RC_VERTICAL
invert_band:
        dw 20,214,130,8
        db #0f,0
focus_demo:
        dw 168,208,126,22
        db #ff,0
bottom_right:
        dw 319,255,1,1
        db 15,0

label_title:
        dw 20,20,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_title
label_clip:
        dw 20,50,125,8
        db #ff,WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_long
label_font_ok:
        dw 20,228,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_font_ok
label_page0_hint:
        dw 20,240,280,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_page0_hint
pascal_title:
        dw 28,42,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw pstr_title
pascal_center:
        dw 28,62,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw pstr_long
pascal_hint:
        dw 28,232,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw pstr_hint

button_normal:
        dw 20,78,120,18
        db #ff,0
        dw str_normal
button_focus:
        dw 20,102,120,18
        db #ff,WIN_BTN_FOCUS
        dw str_focus
button_pressed:
        dw 20,126,120,18
        db #ff,WIN_BTN_PRESSED
        dw str_pressed
button_disabled:
        dw 20,150,120,18
        db #ff,WIN_BTN_DISABLED
        dw str_disabled
button_glyph:
        dw 58,178,44,18
        db #ff,WIN_BTN_GLYPH|WIN_BTN_FOCUS
        dw #0018

pbutton_normal:
        dw 42,88,104,18
        db #ff,0
        dw pstr_normal
pbutton_focus:
        dw 174,88,104,18
        db #ff,WIN_BTN_FOCUS
        dw pstr_focus
pbutton_pressed:
        dw 42,118,104,18
        db #ff,WIN_BTN_PRESSED
        dw pstr_pressed
pbutton_disabled:
        dw 174,118,104,18
        db #ff,WIN_BTN_DISABLED
        dw pstr_disabled

; ---- Stage-2 declarative and modal descriptors ----------------------------

demo_window:
        dw 20,24,280,204
        db #ff,0,5,#ff
        dw demo_items
        dw 0
        db #ff,#ff
        dw 0
demo_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw demo_label,0
        db WIN_T_SEPARATOR,WIN_IT_DIRTY,#ff,0
        dw demo_separator,0
        db WIN_T_FILL,WIN_IT_DIRTY,#ff,0
        dw demo_fill,0
        db WIN_T_BUTTON,WIN_IT_DIRTY|WIN_IT_DISABLED,#ff,0
        dw demo_button,0
        db WIN_T_ZONE,WIN_IT_DIRTY|WIN_IT_HIT,7,0
        dw demo_zone,0
demo_label:
        dw 8,10,264,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_declarative
demo_separator:
        dw 8,28,264,2
        db 0,0
demo_fill:
        dw 20,48,240,68
        db 11,0
demo_button:
        dw 80,148,120,20
        db #ff,0
        dw str_item_disabled
demo_zone:
        dw 20,48,240,68
        db 0,0

stage3_track:
        dw demo_window,0
        db 0,WIN_TRK_OUTSIDE|WIN_TRK_HALT|WIN_TRK_SHOW_CUR
        ds WIN_TRACK_SIZE-6,0

modal_a_window:
        dw 54,62,212,116
        db #ff,0,2,#ff
        dw modal_a_items
        dw 0
        db #ff,#ff
        dw 0
modal_a_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw modal_a_label,0
        db WIN_T_BUTTON,WIN_IT_DIRTY,#ff,0
        dw modal_a_button,0
modal_a_label:
        dw 10,18,192,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_modal_a
modal_a_button:
        dw 56,64,100,20
        db #ff,0
        dw str_nested_next

modal_b_window:
        dw 80,88,160,80
        db #ff,WIN_WND_SUNKEN,1,#ff
        dw modal_b_items
        dw 0
        db #ff,#ff
        dw 0
modal_b_items:
        db WIN_T_LABEL,WIN_IT_DIRTY,#ff,0
        dw modal_b_label,0
modal_b_label:
        dw 8,32,144,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_modal_b

; ---- Stage-4 edit/focus dialogs -----------------------------------------

stage4_window_a:
        dw 24,36,272,160
        db #ff,0,3,0
        dw stage4_items_a
        dw 0
        db #ff,#ff
        dw 0
stage4_items_a:
        db WIN_T_EDIT,WIN_IT_HIT|WIN_IT_FOCUSABLE,20,0
        dw stage4_edit_a,stage4_buffer_a
        db WIN_T_LABEL,0,#ff,0
        dw stage4_label_a,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,21,0
        dw stage4_button_a,0
stage4_edit_a:
        dw 20,54,232,16
        db #ff,WIN_ED_FRAME,32,0,0,0
        dw stage4_buffer_a
stage4_label_a:
        dw 12,16,248,24
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_stage4_edit
stage4_button_a:
        dw 76,104,120,20
        db #ff,0
        dw str_stage4_button
stage4_buffer_a:
        db "edit this text",0
        ds 33-15,0
stage4_track_a:
        dw stage4_window_a,0
        db 0,WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

stage4_window_p:
        dw 24,36,272,160
        db #ff,0,3,0
        dw stage4_items_p
        dw 0
        db #ff,#ff
        dw 0
stage4_items_p:
        db WIN_T_EDIT,WIN_IT_HIT|WIN_IT_FOCUSABLE,30,0
        dw stage4_edit_p,stage4_buffer_p
        db WIN_T_LABEL,0,#ff,0
        dw stage4_label_p,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,31,0
        dw stage4_button_p,0
stage4_edit_p:
        dw 20,54,232,16
        db #ff,WIN_ED_FRAME|WIN_ED_PASSWORD,32,0,0,0
        dw stage4_buffer_p
stage4_label_p:
        dw 12,16,248,24
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw pstr_stage4_edit
stage4_button_p:
        dw 76,104,120,20
        db #ff,0
        dw pstr_stage4_button
stage4_buffer_p:
        db 6,"secret"
        ds 32-6,0
stage4_track_p:
        dw stage4_window_p,0
        db 0,WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

; ---- Stage-5 controls and WIP1 showcase ----------------------------------

stage5_window:
        dw 16,16,288,224
        db #ff,0,12,1
        dw stage5_items
        dw 0
        db #ff,#ff
        dw 0
stage5_items:
        db WIN_T_LABEL,0,#ff,0
        dw stage5_label,0
        db WIN_T_LISTBOX,WIN_IT_HIT|WIN_IT_FOCUSABLE,40,0
        dw stage5_listbox,0
        db WIN_T_SCROLLBAR,WIN_IT_HIT|WIN_IT_REPEAT,41,0
        dw stage5_scrollbar,0
        db WIN_T_PROGRESS,0,#ff,0
        dw stage5_progress,0
        db WIN_T_ICON,0,#ff,0
        dw stage5_icon8_a,0
        db WIN_T_ICON,0,#ff,0
        dw stage5_icon8_b,0
        db WIN_T_ICON,0,#ff,0
        dw stage5_icon16_a,0
        db WIN_T_ICON,0,#ff,0
        dw stage5_icon16_b,0
        db WIN_T_LABEL,0,#ff,0
        dw stage5_hint,0
        ; Non-hit standard buttons provide the endpoint bevel and the same
        ; arrow glyphs used by the rest of WIN320.  Hit ownership remains
        ; with the composite scrollbar item above.
        db WIN_T_BUTTON,0,#ff,0
        dw stage5_scroll_up,0
        db WIN_T_BUTTON,0,#ff,0
        dw stage5_scroll_down,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,42,0
        dw stage5_exit,0
stage5_label:
        dw 8,8,272,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_stage5_title
stage5_listbox:
        dw 16,32,200,104
        db 12,#ff,#ff,WIN_LB_FRAME
        dw 12,0,0,stage5_list_items
        db 0,0
        dw stage5_scrollbar,#ffff,#ffff
stage5_scrollbar:
        dw 216,32,12,104
        dw 0,0,0
        db WIN_SB_ARROWS,0
        dw 0,0,#ffff
stage5_progress:
        dw 16,148,214,12
        db WIN_PG_FRAME,0
        dw #ffff
stage5_icon8_a:
        dw 246,36,8,8
        db WIN_ICO_KEYED,0,0,0
stage5_icon8_b:
        dw 266,36,8,8
        db WIN_ICO_KEYED,0,1,0
stage5_icon16_a:
        dw 242,64,16,16
        db WIN_ICO_KEYED,0,0,0
stage5_icon16_b:
        dw 262,88,16,16
        db WIN_ICO_KEYED,0,1,0
stage5_hint:
        dw 8,176,272,8
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL
        dw str_stage5_hint
stage5_scroll_up:
        dw 216,32,12,12
        db #ff,WIN_BTN_GLYPH
        dw #0018
stage5_scroll_down:
        dw 216,124,12,12
        db #ff,WIN_BTN_GLYPH
        dw #0019
stage5_exit:
        dw 104,192,80,20
        db #ff,0
        dw str_stage5_exit
stage5_track:
        dw stage5_window,0
        db 0,WIN_TRK_ANY_KEY|WIN_TRK_OUTSIDE|WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0
stage5_list_items:
        dw str_stage5_00,str_stage5_01,str_stage5_02,str_stage5_03
        dw str_stage5_04,str_stage5_05,str_stage5_06,str_stage5_07
        dw str_stage5_08,str_stage5_09,str_stage5_10,str_stage5_11

; ---- Stage-6 checkbox/radio showcase ------------------------------------

stage6_window:
        dw 30,20,260,216
        db #ff,0,9,0
        dw stage6_items
        dw 0
        db #ff,#ff
        dw 0
stage6_items:
        db WIN_T_LABEL,0,#ff,0
        dw stage6_title,0
        db WIN_T_CHECKBOX,WIN_IT_HIT|WIN_IT_FOCUSABLE,80,0
        dw stage6_checkbox,0
        db WIN_T_CHECKBOX,WIN_IT_HIT|WIN_IT_FOCUSABLE,81,0
        dw stage6_checkbox_disabled,0
        db WIN_T_RADIOBUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,82,0
        dw stage6_radio_audio_a,0
        db WIN_T_RADIOBUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,83,0
        dw stage6_radio_audio_b,0
        db WIN_T_RADIOBUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,84,0
        dw stage6_radio_view_a,0
        db WIN_T_RADIOBUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,85,0
        dw stage6_radio_view_b,0
        db WIN_T_LABEL,0,#ff,0
        dw stage6_status,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE,87,0
        dw stage6_exit,0
stage6_title:
        dw 8,8,244,16
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_stage6_title
stage6_checkbox:
        dw 16,32,220,12
        db #ff,0,0,0
        dw str_stage6_checkbox
stage6_checkbox_disabled:
        dw 16,50,220,12
        db #ff,WIN_CH_DISABLED,0,0
        dw str_stage6_disabled
stage6_radio_audio_a:
        dw 16,76,220,12
        db #ff,WIN_CH_CHECKED,1,0
        dw str_stage6_audio_a
stage6_radio_audio_b:
        dw 16,94,220,12
        db #ff,0,1,0
        dw str_stage6_audio_b
stage6_radio_view_a:
        dw 16,122,220,12
        db #ff,WIN_CH_CHECKED,2,0
        dw str_stage6_view_a
stage6_radio_view_b:
        dw 16,140,220,12
        db #ff,0,2,0
        dw str_stage6_view_b
stage6_status:
        dw 8,166,244,12
        db #ff,WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP
        dw str_stage6_status
stage6_exit:
        dw 90,184,80,20
        db #ff,0
        dw str_stage6_exit
stage6_track:
        dw stage6_window,0
        db 0,WIN_TRK_ANY_KEY|WIN_TRK_OUTSIDE|WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0

; ---- Stage-7 window title bar and close button showcase -----------------

stage7_hint:
        dw 10,20,190,10
        db #ff,WIN_LABEL_CLIP
        dw str_stage7_hint
stage7_status:
        dw 10,34,190,10
        db #ff,WIN_LABEL_CLIP
        dw str_stage7_status
stage7_theme_button:
        dw 10,54,85,24
        db #ff,0
        dw str_stage7_theme_btn
stage7_exit_button:
        dw 110,54,85,24
        db #ff,0
        dw str_stage7_exit_btn
stage7_items:
        db WIN_T_LABEL,0,#ff,0
        dw stage7_hint,0
        db WIN_T_LABEL,0,#ff,0
        dw stage7_status,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE|WIN_IT_PRESS,90,0
        dw stage7_theme_button,0
        db WIN_T_BUTTON,WIN_IT_HIT|WIN_IT_FOCUSABLE|WIN_IT_PRESS,91,0
        dw stage7_exit_button,0
stage7_window:
        dw 16,30,210,100
        db #ff,WIN_WND_CLOSE,4,2
        dw stage7_items
        dw str_stage7_title
        db #ff,#ff
        dw 0
stage7_track:
        dw stage7_window,0
        db 0,WIN_TRK_ANY_KEY|WIN_TRK_HALT|WIN_TRK_SHOW_CUR|WIN_TRK_TAB_FOCUS
        ds WIN_TRACK_SIZE-6,0
stage7_theme_toggle:    db 0

stage7_plain_label:
        dw 0,24,64,10
        db #ff,WIN_LABEL_CENTER
        dw str_stage7_plain
stage7_plain_items:
        db WIN_T_LABEL,0,#ff,0
        dw stage7_plain_label,0
stage7_plain_window:
        dw 240,30,64,60
        db #ff,0,1,#ff
        dw stage7_plain_items
        dw 0
        db #ff,#ff
        dw 0

stage7_theme_alt:
        db 15,7,8,1,0,7,15,0
        db 1,15,7,1,7,1,#0f,9,15,0

blue_theme:
        db 15,1,9,3,15,8,0,15
        db 3,15,1,11,1,9,#55,1,15,0

str_title:       db "WIN320 Stage 4 / screen 0 / ASCIIZ",0
str_long:        db "Clipped proportional label with a deliberately long tail",0
str_font_ok:     db "Embedded WF32 survived failed win_load_font",0
str_normal:      db "Normal",0
str_focus:       db "Focus",0
str_pressed:     db "Pressed",0
str_disabled:    db "Disabled",0
str_page0_hint:  db "Any key: alternate screen",0
str_declarative: db "Stage 2: declarative draw - press any key",0
str_stage3_hint: db "Stage 3: click yellow zone, right-click, or click outside",0
str_stage3_done: db "Stage 3 event received; press a key to finish",0
str_dirty_done:  db "Dirty update complete - press any key",0
str_item_disabled: db "Item-disabled",0
str_modal_a:     db "Modal A / screen 0 - press any key",0
str_nested_next: db "Next: screen 1",0
str_modal_b:     db "Nested modal B / screen 1 - press any key",0
str_stage4_edit: db "Edit: Enter accept, Esc undo, Tab Continue",0
str_stage4_button: db "Continue",0
str_stage4_result_enter: db "Enter: accepted. Press any key",0
str_stage4_result_esc: db "Esc: original restored. Press any key",0
str_stage4_result_mouse: db "Mouse event accepted. Press any key",0
str_stage4_result_button: db "Continue activated. Press any key",0
str_stage5_title: db "Stage 5: icons, listbox, scrollbar, progress",0
str_stage5_hint: db "Arrows/PgUp/PgDn, mouse or Tab; Esc exits",0
str_stage5_exit: db "Exit",0
str_stage5_00: db "BOOT",0
str_stage5_01: db "CONFIG",0
str_stage5_02: db "DEMOS",0
str_stage5_03: db "DOCS",0
str_stage5_04: db "GAMES",0
str_stage5_05: db "LIB",0
str_stage5_06: db "NETWORK",0
str_stage5_07: db "SYSTEM",0
str_stage5_08: db "TOOLS",0
str_stage5_09: db "WIN320.DLL",0
str_stage5_10: db "WIN320.EXE",0
str_stage5_11: db "ICONS.WIP",0
str_stage6_title: db "Stage 6: mouse, Tab, Space and radio arrows",0
str_stage6_checkbox: db "Enable sound",0
str_stage6_disabled: db "Disabled checkbox",0
str_stage6_audio_a: db "Audio A: AY",0
str_stage6_audio_b: db "Audio B: Beeper",0
str_stage6_view_a: db "View 1: List",0
str_stage6_view_b: db "View 2: Icons",0
str_stage6_status: db "Check=0  Audio=A  View=1",0
str_stage6_exit: db "Exit",0

str_stage7_title: db "Stage 7: window title bar and close button (click X or Theme)",0
str_stage7_hint: db "Theme recolors the title live; X or Exit closes",0
str_stage7_status: db "Title theme: 0",0
str_stage7_theme_btn: db "Theme",0
str_stage7_exit_btn: db "Exit",0
str_stage7_plain: db "No title",0

pstr_title:      db 39,"WIN320 Stage 4 / screen 1 / Pascal text"
pstr_long:       db 55,"Alternate theme, centered and clipped Pascal label tail"
pstr_hint:       db 17,"Escape: exit test"
pstr_normal:     db 6,"Normal"
pstr_focus:      db 5,"Focus"
pstr_pressed:    db 7,"Pressed"
pstr_disabled:   db 8,"Disabled"
pstr_stage4_edit: db 46,"Password: Enter accept, Esc undo, Tab Continue"
pstr_stage4_button: db 8,"Continue"
pstr_stage4_result_enter: db 33,"Enter: password accepted. Any key"
pstr_stage4_result_esc: db 31,"Esc: password restored. Any key"
pstr_stage4_result_mouse: db 29,"Mouse event accepted. Any key"
pstr_stage4_result_button: db 27,"Continue activated. Any key"

missing_font:    db "__WIN320_MISSING__.FNT",0
icon_pack_name:  db "ICONS.WIP",0
icon_pack_expected:
        db "WIP1",1,2
        dw 12
        db 8,2,16,2
dll_name:        db "WIN320.DLL",0
msg_banner:      db "WIN320 ABI 2.0 visual test",13,10,0
msg_ok:          db "PASS: Stage 6 choice sequence.",13,10,0
msg_failed:      db "FAIL: stage=$",0
msg_status:      db " status=$",0
msg_load_failed: db "FAIL: load reason=$",0
msg_dss:         db " DSS=$",0
msg_newline:     db 13,10,0
char_buffer:     db 0,0

dll_handle:      dw 0
dll_loaded:      db 0
api_status:      db 0
stage4_api_status: db 0
stage4_reason:   db 0
test_stage:      db 0
old_mode:        db 0
old_screen:      db 0
backstore_block: db 0
backstore_allocated: db 0
backstore_physical_pages:
        ds WIN_BACKSTORE_MAX_PAGES,0
icon_pack_handle: db 0
icon_pack_block: db 0
icon_pack_allocated: db 0
icon_saved_win1: db 0
icon_page_index: db 0
icon_pack_header: ds 12,0
icon_physical_pages: ds 2,0

        include "libman.asm"
