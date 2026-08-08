; WIN320 stage 7: window title bar and optional close button.
; The title bar is a WinWindow property, not a control: it is composed from
; existing renderers (fill/label/button) and adds no new public entries.

; window_scratch already loaded (WIN_WND_TITLE/WIN_WND_FLAGS valid). Z means
; the title/close combination is acceptable; NZ means WIN_ERR_ARGUMENT.
s7_validate_title:
        ld hl,(window_scratch+WIN_WND_TITLE)
        ld a,h
        or l
        jr nz,.has_title
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_CLOSE
        ret
.has_title:
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_NOPANEL
        ret nz
        ld hl,(window_scratch+WIN_WND_WIDTH)
        ld a,20
        call s1_hl_minus_a
        ret c
        ld hl,(window_scratch+WIN_WND_HEIGHT)
        ld a,18
        call s1_hl_minus_a
        ret c
        xor a
        ret

; Stage label_scratch's X/Y/WIDTH/HEIGHT/FLAGS/TEXT for the title text (ATTR
; is left to the caller, since draw and preflight resolve it differently).
; Carry means the text has no room (only possible at the width=20 minimum
; with a close button); callers skip labeling the title in that case.
s7_stage_title_geometry:
        ld hl,(window_scratch+WIN_WND_WIDTH)
        ld a,8
        call s1_hl_minus_a
        ret c
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_CLOSE
        jr z,.width_ok
        ld a,14
        call s1_hl_minus_a
        ret c
.width_ok:
        ld (label_scratch+WIN_LBL_WIDTH),hl
        ld hl,6
        ld (label_scratch+WIN_LBL_X),hl
        ld l,5
        ld (label_scratch+WIN_LBL_Y),hl
        ld l,8
        ld (label_scratch+WIN_LBL_HEIGHT),hl
        ld a,WIN_LABEL_CLIP
        ld (label_scratch+WIN_LBL_FLAGS),a
        ld hl,(window_scratch+WIN_WND_TITLE)
        ld (label_scratch+WIN_LBL_TEXT),hl
        or a
        ret

; Populates rect_scratch's WIN_RC_X/Y/WIDTH/HEIGHT with the title strip's
; window-relative rect (WIN_RC_FLAGS is left to the caller). Also used by
; s7_chrome_hit, which copies the result into control_geometry.
s7_stage_strip_geometry:
        ld hl,2
        ld (rect_scratch+WIN_RC_X),hl
        ld (rect_scratch+WIN_RC_Y),hl
        ld hl,(window_scratch+WIN_WND_WIDTH)
        ld a,4
        call s1_hl_minus_a
        ld (rect_scratch+WIN_RC_WIDTH),hl
        ld hl,WIN_TITLE_H
        ld (rect_scratch+WIN_RC_HEIGHT),hl
        ret

; Title bar hook for win_draw/win_open, called with origin already set via
; s2_set_window_origin. Returns success (A=0) immediately when the window
; has no title. Not reentrant: label_scratch and button_scratch alias, and
; both stage their string into the shared text_scratch, so fill -> label ->
; button must run strictly in this order with no other s1_label_loaded or
; s1_button_loaded call interleaved.
s7_draw_title:
        ld hl,(window_scratch+WIN_WND_TITLE)
        ld a,h
        or l
        ret z
        ld a,(window_scratch+WIN_WND_TITLE_ATTR)
        ld b,WIN_TH_TITLE_BG
        ld c,WIN_TH_TITLE_FG
        call s1_resolve_text_attr
        xor a
        ld (rect_scratch+WIN_RC_FLAGS),a
        call s7_stage_strip_geometry
        call s1_load_rect_values
        ret nz
        call s1_copy_rect_to_fill
        ld hl,s1_fill_mapped
        call s1_draw_mapped_hl
        ret nz
        call s7_stage_title_geometry
        jr c,.close
        ld a,(text_attr)
        ld (label_scratch+WIN_LBL_ATTR),a
        call s1_label_loaded
        ret nz
.close:
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_CLOSE
        ret z
        call s7_stage_close_button
        jp s1_button_loaded

; Populate button_scratch with the close button's fixed 12x12 glyph
; descriptor. Callers: s7_draw_title, s7_chrome_hit and s3_set_pressed_index,
; each of which must have already finished with label_scratch/text_scratch
; for this iteration (see the aliasing note above s7_draw_title).
s7_stage_close_button:
        ld hl,(window_scratch+WIN_WND_WIDTH)
        ld a,15
        call s1_hl_minus_a
        ld (button_scratch+WIN_BTN_X),hl
        ld hl,3
        ld (button_scratch+WIN_BTN_Y),hl
        ld l,12
        ld (button_scratch+WIN_BTN_WIDTH),hl
        ld (button_scratch+WIN_BTN_HEIGHT),hl
        ld hl,(WIN_BTN_GLYPH<<8)|#ff
        ld (button_scratch+WIN_BTN_ATTR),hl
        ld hl,WIN_TITLE_CLOSE_GLYPH
        ld (button_scratch+WIN_BTN_TEXT),hl
        ret

; Preflight-only validation for the title label (font/string), called from
; win_open before the backstore is saved. The close button's fixed 12x12
; geometry cannot fail once s7_validate_title has accepted the window (it
; requires width>=20), and s1_button_loaded has no prepare-only entry point,
; so it is not preflighted separately.
s7_preflight_title:
        ld hl,(window_scratch+WIN_WND_TITLE)
        ld a,h
        or l
        ret z
        call s7_stage_title_geometry
        ret c
        ld a,(window_scratch+WIN_WND_TITLE_ATTR)
        ld (label_scratch+WIN_LBL_ATTR),a
        jp s1_label_prepare_loaded

; C=set and A=sentinel (#fe close button, #fd strip) when the mouse is over
; the window's title chrome. Reuses s3_point_in_geometry's arithmetic via
; control_geometry; window_scratch is filled once per tracking iteration by
; s3_preflight, so it stays valid for every s3_find_hit call in between.
s7_chrome_hit:
        ld hl,(window_scratch+WIN_WND_TITLE)
        ld a,h
        or l
        jr z,.no
        ld a,(window_scratch+WIN_WND_FLAGS)
        and WIN_WND_CLOSE
        jr z,.strip
        call s7_stage_close_button
        ld hl,button_scratch+WIN_BTN_X
        call .test
        jr nc,.strip
        ld a,#fe
        scf
        ret
.strip:
        call s7_stage_strip_geometry
        ld hl,rect_scratch+WIN_RC_X
        call .test
        ret nc
        ld a,#fd
        scf
        ret
.no:
        or a
        ret
.test:
        ld de,control_geometry
        ld bc,8
        ldir
        jp s3_point_in_geometry
