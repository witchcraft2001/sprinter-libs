from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "win320.asm").read_text()
STAGE2 = (ROOT / "stage2.inc").read_text()
STAGE3 = (ROOT / "stage3.inc").read_text()
STAGE4 = (ROOT / "stage4.inc").read_text()
HARNESS = (ROOT / "tests" / "z80" / "t_stage4.asm").read_text()


class Stage4ContractTests(unittest.TestCase):
    def test_entries_capabilities_and_stage5_tail(self) -> None:
        self.assertIn("jp win_edit_draw            ; 29", SOURCE)
        self.assertIn("jp win_edit                 ; 30", SOURCE)
        for entry, name in enumerate((
            "win_icon", "win_progress_init", "win_progress_draw",
            "win_scrollbar_init", "win_scrollbar_draw", "win_listbox_draw",
        ), 31):
            self.assertIn(f"jp {name}", SOURCE)
            self.assertIn(f"; {entry}", SOURCE)
        self.assertIn("WIN_CAP_LISTBOX|WIN_CAP_SCROLLBAR|WIN_CAP_PROGRESS|WIN_CAP_ICON", SOURCE)
        self.assertIn('include "stage4.inc"', SOURCE)

    def test_edit_validation_is_bounded_and_publish_is_after_render(self) -> None:
        load = STAGE4.split("s4_load_edit:", 1)[1].split(
            "s4_recount_buffer:", 1
        )[0]
        self.assertIn("cp 64", load)
        self.assertIn("call s1_validate_caller_range", load)
        self.assertIn("call s4_recount_buffer", load)
        self.assertIn("WIN_ED_FRAME", load)

        render = STAGE4.split("s4_render_loaded_edit:", 1)[1].split(
            "s4_publish_edit:", 1
        )[0]
        self.assertIn("call s1_map_pair", render)
        self.assertIn("call s1_unmap_pair", render)
        self.assertIn("call s4_publish_edit", render)
        self.assertIn("WIN_ED_PASSWORD", render)
        self.assertNotIn("s4_cursor_attr", render)

    def test_editor_uses_smooth_redraw_and_saved_extended_caret(self) -> None:
        self.assertIn("S4_CARET_TICKS         equ 14", STAGE4)
        caret = STAGE4.split("s4_caret_toggle_mapped:", 1)[1].split(
            "s4_publish_edit:", 1
        )[0]
        self.assertNotIn("call s1_invert_mapped", caret)
        self.assertIn("ld de,xor_scratch", caret)
        self.assertIn("ld a,(text_attr)", caret)
        self.assertIn("or #f0", caret)
        self.assertIn("ld (de),a", caret)
        self.assertIn("ld a,(de)", caret)
        self.assertIn("and WIN_ED_FRAME", caret)
        self.assertIn("dec c", caret)
        self.assertIn("ld b,10", caret)
        self.assertIn("xor #80", caret)
        self.assertNotIn("s4_caret_h", STAGE4)
        self.assertNotIn("s4_caret_y", STAGE4)

        content = STAGE4.split("s4_render_edit_content_mapped:", 1)[1].split(
            "s4_caret_toggle_mapped:", 1
        )[0]
        self.assertIn("call c,s4_caret_toggle_mapped", content)
        self.assertIn("s4_render_edit_content_mapped_fresh:", content)
        self.assertLess(
            content.index("call textcore_draw_mapped"),
            content.index("call nz,s1_fill_mapped"),
        )
        editor = STAGE4.split("s4_edit_run:", 1)[1].split(
            "s4_validate_edit_track:", 1
        )[0]
        redraw = editor.split(".redraw:", 1)[1].split(".escape:", 1)[0]
        self.assertIn("call s4_render_modal_content", redraw)
        self.assertNotIn("call s4_render_modal_edit", redraw)

    def test_active_edit_click_places_cursor_and_keeps_editing(self) -> None:
        editor = STAGE4.split("s4_edit_run:", 1)[1].split(
            "s4_validate_edit_track:", 1
        )[0]
        mouse = editor.split(".mouse:", 1)[1].split(".mouse_exit:", 1)[0]
        self.assertIn("WIN_EV_LCLICK", mouse)
        self.assertIn("item_scratch+WIN_ITEM_CONTROL", mouse)
        self.assertIn("s4_active_edit_ptr", mouse)
        self.assertIn("call s4_cursor_from_mouse_x", mouse)
        self.assertIn("call s4_render_modal_content", mouse)
        self.assertIn("jp .loop", mouse)

        hit = STAGE4.split("s4_cursor_from_mouse_x:", 1)[1].split(
            "s4_render_modal_edit:", 1
        )[0]
        self.assertIn("WIN_TRK_MOUSE_X", hit)
        self.assertIn("s4_content_x", hit)
        self.assertIn("call s4_char_width_at", hit)
        self.assertIn("WIN_ED_CURSOR", hit)

    def test_focus_is_integrated_with_draw_update_and_poll(self) -> None:
        self.assertIn("call s4_publish_last_focus", STAGE2)
        self.assertIn("call s4_item_needs_focus_redraw", STAGE2)
        self.assertIn("call s4_sync_item_focus", STAGE2)
        self.assertIn("dw s4_edit_draw_item", STAGE2)
        self.assertIn("call s4_keyboard_focus", STAGE3)
        self.assertIn("call s4_focus_click", STAGE3)
        self.assertIn("WIN_TRK_TAB_FOCUS", STAGE4)
        self.assertIn("s4_clear_hidden_focus", STAGE4)
        edit_item = STAGE4.split("s4_edit_draw_item:", 1)[1].split(
            "s4_preflight_edit_item:", 1
        )[0]
        self.assertIn("jp s4_render_loaded_edit", edit_item)
        self.assertIn("s2_item_rendered", edit_item)
        self.assertIn("jp c,s4_render_edit_content", edit_item)
        focus_redraw = STAGE4.split("s4_redraw_focus_index:", 1)[1].split(
            "s4_cursor_hide:", 1
        )[0]
        self.assertIn("ld a,#80", focus_redraw)
        self.assertIn("jp s2_process_item_marked", focus_redraw)
        update = STAGE2.split("s2_win_update:", 1)[1].split(
            "s2_load_window:", 1
        )[0]
        self.assertIn("ld a,#80", update)
        self.assertIn("call s2_process_item_marked", update)

    def test_ctrl_arrows_follow_flexnavigator_word_boundaries(self) -> None:
        editor = STAGE4.split("s4_edit_run:", 1)[1].split(
            "s4_validate_edit_track:", 1
        )[0]
        self.assertGreaterEqual(editor.count("ld a,(s4_key_mods)"), 2)
        self.assertGreaterEqual(editor.count("bit 5,a"), 2)
        self.assertIn(".word_left:", editor)
        self.assertIn(".word_right:", editor)
        separators = STAGE4.split("s4_is_word_separator:", 1)[1].split(
            "s4_insert_char:", 1
        )[0]
        for char in ("' '", "','", "'.'", "'\\'"):
            self.assertIn(f"cp {char}", separators)
        input_path = STAGE4.split("s4_edit_next_input:", 1)[1].split(
            "s4_is_word_separator:", 1
        )[0]
        self.assertIn("WIN_TRK_KEY_MODS", input_path)
        self.assertIn("ld a,b", input_path)
        self.assertGreaterEqual(input_path.count("ld (s4_key_mods),a"), 2)

    def test_keyboard_activation_uses_three_halt_ticks(self) -> None:
        activation = STAGE4.split("s4_activate_focused_button:", 1)[1].split(
            "s4_draw_button_state:", 1
        )[0]
        self.assertEqual(3, activation.count("call win_halt_call"))
        self.assertIn("WIN_EV_LCLICK", activation)
        self.assertIn("WIN_BTN_PRESSED", (ROOT / "win320.inc").read_text())

    def test_navigation_keys_are_not_consumed_and_listbox_repaints_focus(self) -> None:
        focus = STAGE4.split("s4_keyboard_focus:", 1)[1].split(
            "s4_tab_focus:", 1
        )[0]
        self.assertIn("call s6_choice_key", focus)
        self.assertIn("ret nc", focus)
        redraw = STAGE4.split("s4_redraw_focus_index:", 1)[1].split(
            "s4_cursor_hide:", 1
        )[0]
        self.assertIn("call s4_is_focus_visual", redraw)
        visuals = STAGE4.split("s4_is_focus_visual:", 1)[1].split(
            "s4_cursor_hide:", 1
        )[0]
        self.assertIn("cp WIN_T_LISTBOX", visuals)
        harness = (ROOT / "tests" / "z80" / "t_stage4.asm").read_text()
        self.assertIn("keys_arrow_up", harness)
        self.assertIn("cp WIN_EV_KEY", harness)

    def test_modal_editor_has_all_keys_and_byte_exact_escape_buffer(self) -> None:
        editor = STAGE4.split("s4_edit_run:", 1)[1].split(
            "s4_edit_next_input:", 1
        )[0]
        for token in (
            "S4_SCAN_DELETE", "S4_SCAN_END", "S4_SCAN_LEFT",
            "S4_SCAN_RIGHT", "S4_SCAN_HOME", "WIN_ED_ESC",
            "WIN_ED_TAB", "WIN_ED_MOUSE",
        ):
            self.assertIn(token, editor)
        self.assertIn("ld hl,s4_original_buffer", editor)
        self.assertIn("ld de,(s4_buffer_ptr)", editor)
        self.assertIn("s4_original_buffer      equ path_scratch+69", STAGE4)

    def test_z80_harness_covers_formats_focus_editing_and_rollback(self) -> None:
        for token in (
            "edit_buffer", "pascal_buffer", "edit_bad_buffer",
            "keys_shift_tab", "keys_edit_accept", "keys_edit_escape",
            "keys_edit_navigation", "keys_full", "keys_pascal_edit",
            "keys_space", "mock_mouse_buttons", "mock_hide_fail_from",
            "mock_key_delay", "test_caret_blink", "s4_test_caret_toggles",
            "s4_test_caret_saves", "s4_test_caret_restores",
            "s4_test_full_edit_renders", "keys_word_navigation",
            "mock_click_phase", "test_mouse_cursor",
            "test_error_consistency", "WIN_IT_HIDDEN",
            "call win_edit_draw", "call win_update", "call win_poll",
            "call win_edit", "cp 3", "WIN_EV_FOCUS", "WIN_EV_LCLICK",
        ):
            self.assertIn(token, HARNESS)

    def test_visual_dialog_tracks_the_focused_button_and_reports_results(self) -> None:
        visual = (ROOT / "test.asm").read_text()
        stage4 = visual.split("run_stage4_dialogs:", 1)[1].split(
            "wait_step:", 1
        )[0]
        self.assertGreaterEqual(stage4.count("ld b,WIN_TRACK"), 2)
        self.assertIn("WIN_ED_TAB", stage4)
        self.assertIn("WIN_EV_LCLICK", stage4)
        self.assertIn("str_stage4_result_button", visual)
        self.assertIn("pstr_stage4_result_button", visual)


if __name__ == "__main__":
    unittest.main()
