from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "win320.asm").read_text()
STAGE1 = (ROOT / "stage1.inc").read_text()
STAGE2 = (ROOT / "stage2.inc").read_text()
HARNESS = (ROOT / "tests" / "z80" / "t_stage2.asm").read_text()


class Stage2ContractTests(unittest.TestCase):
    def test_origin_is_restored_on_all_aggregate_paths(self) -> None:
        for entry, following in (
            ("win_draw:", "win_draw_item:"),
            ("win_draw_item:", "win_update:"),
            ("win_update:", "s2_load_window:"),
        ):
            body = STAGE2.split(entry, 1)[1].split(following, 1)[0]
            self.assertIn("call s2_set_window_origin", body)
            restore_calls = len(
                re.findall(r"(?:call|jp) s2_restore_origin(?:_keep_a)?\b", body)
            )
            self.assertGreaterEqual(restore_calls, 2)

    def test_disabled_button_uses_internal_scratch(self) -> None:
        button = STAGE2.split("s2_process_item:", 1)[1].split(
            "s2_process_zone:", 1
        )[0]
        self.assertIn("call s1_copy_button_block", button)
        copy_block = STAGE1.split("s1_copy_button_block:", 1)[1].split(
            "s1_copy_label_block:", 1
        )[0]
        self.assertIn("ld hl,button_scratch", copy_block)
        self.assertIn("or WIN_BTN_DISABLED", button)
        self.assertIn("call s1_button_loaded", button)
        self.assertIn("call s4_publish_button_focus", button)
        self.assertNotIn("ld (de),a", button)
        self.assertIn("s1_button_loaded:", STAGE1)

    def test_dirty_clear_follows_success_and_update_counts_visuals(self) -> None:
        update = STAGE2.split("win_update:", 1)[1].split(
            "s2_load_window:", 1
        )[0]
        process = update.find("call s2_process_item")
        clear = update.find("call s2_clear_item_dirty", process)
        count = update.find("inc (hl)", clear)
        self.assertGreater(process, -1)
        self.assertGreater(clear, process)
        self.assertGreater(count, clear)
        self.assertIn("ld e,a", update)
        self.assertIn("bit 0,(hl)", update)
        self.assertLess(
            update.find("bit 0,(hl)"),
            update.find("call s2_load_current_item"),
        )
        self.assertIn("ld e,0", update)

    def test_public_stage2_entries_preserve_unspecified_registers(self) -> None:
        wrappers = {
            "win_draw:": ("push bc", "push hl", "push ix", "push iy"),
            "win_draw_item:": ("push bc", "push hl", "push iy"),
            "win_update:": ("push bc", "push hl", "push ix", "push iy"),
            "win_set_backstore:": ("push bc", "push hl", "push iy"),
            "win_open:": ("push bc", "push hl", "push ix", "push iy"),
            "win_close:": (
                "push bc", "push de", "push hl", "push ix", "push iy"
            ),
        }
        labels = list(wrappers)
        for index, label in enumerate(labels):
            end = labels[index + 1] if index + 1 < len(labels) else "s2_win_close:"
            body = STAGE2.split(label, 1)[1].split(end, 1)[0]
            for instruction in wrappers[label]:
                self.assertIn(instruction, body, (label, instruction))

    def test_focus_and_edit_are_delegated_to_stage4(self) -> None:
        header = STAGE2.split("s2_load_window:", 1)[1].split(
            "s2_load_item_index:", 1
        )[0]
        item = STAGE2.split("s2_validate_item:", 1)[1].split(
            "s2_process_item:", 1
        )[0]
        self.assertIn("s4_validate_window_focus", header)
        self.assertIn("s2_window_ptr", header)
        self.assertIn("WIN_IT_FOCUSABLE", item)
        self.assertIn("cp WIN_T_RADIOBUTTON+1", item)
        dispatch = STAGE2.split(".dispatch:", 1)[1].split(
            "s2_process_label:", 1
        )[0]
        for control in (
            "WIN_T_ICON", "WIN_T_PROGRESS", "WIN_T_SCROLLBAR", "WIN_T_LISTBOX",
            "WIN_T_CHECKBOX", "WIN_T_RADIOBUTTON",
        ):
            self.assertIn(control, dispatch)

    def test_backstore_row_has_one_mapping_and_256_plus_remainder_copy(self) -> None:
        row = STAGE2.split("s2_copy_stack_rect:", 1)[1].split(
            "s2_advance_row_page:", 1
        )[0]
        self.assertEqual(1, row.count("call s2_map_backstore_row"))
        self.assertEqual(1, row.count("call s2_unmap_backstore_row"))
        self.assertEqual(1, row.count("call s2_copy_row_mapped"))

        copy = STAGE2.split("s2_copy_row_mapped:", 1)[1].split(
            "s2_copy_chunk:", 1
        )[0]
        self.assertIn("xor a                       ; first 256-byte command", copy)
        self.assertIn("ld bc,256", copy)
        self.assertIn("ld a,(s2_copy_width)", copy)

        chunk = STAGE2.split("s2_copy_chunk:", 1)[1].split(
            "; ---- stage-2 internal state", 1
        )[0]
        self.assertRegex(
            chunk,
            r"ld \(s2_copy_size\+1\),a\s+ld d,d\s+s2_copy_size:"
            r"\s+ld a,0\s+ld l,l\s+ld a,\(hl\)\s+ld \(de\),a\s+ld b,b",
        )

    def test_mapping_restores_port_pages_and_iff_in_order(self) -> None:
        # The port/VRAM restore is shared with stage1 via s1_unmap_vram_core.
        core = STAGE1.split("s1_unmap_vram_core:", 1)[1].split(
            "s1_unmap_vram:", 1
        )[0]
        core_sequence = ["ld a,#c0", "out (YPORT),a", "ld a,(saved_vram_page)"]
        position = 0
        for token in core_sequence:
            found = core.find(token, position)
            self.assertNotEqual(-1, found, token)
            position = found + len(token)

        unmap = STAGE2.split("s2_unmap_backstore_row:", 1)[1].split(
            "s2_copy_row_mapped:", 1
        )[0]
        self.assertIn("call s1_unmap_vram_core", unmap)
        tail_sequence = ["ld a,(saved_data_page)", "jp s1_restore_iff"]
        position = 0
        for token in tail_sequence:
            found = unmap.find(token, position)
            self.assertNotEqual(-1, found, token)
            position = found + len(token)

    def test_allocator_padding_stack_rollback_and_free_cleanup_are_present(self) -> None:
        allocator = STAGE2.split("s2_allocator_preflight:", 1)[1].split(
            "s2_push_stack_record:", 1
        )[0]
        self.assertIn("cp #40", allocator)
        self.assertIn("WIN_ERR_BACKSTORE", allocator)
        self.assertIn("backstore_alloc_page", STAGE2)
        self.assertIn("backstore_alloc_offset", STAGE2)
        self.assertIn("window_stack:", STAGE2)

        opened = STAGE2.split("win_open:", 1)[1].split("win_close:", 1)[0]
        self.assertIn("call s2_allocator_preflight", opened)
        self.assertIn("call s2_copy_stack_rect", opened)
        self.assertIn("call s2_draw_loaded_window", opened)
        self.assertIn("call s2_close_top", opened)

        free = SOURCE.split("win_free:", 1)[1].split(
            "; D=data window", 1
        )[0]
        self.assertIn("call s2_close_all", free)
        self.assertNotIn("DSS_FREEMEM", STAGE2)

    def test_z80_harness_locks_boundaries_mapping_and_lifo_cases(self) -> None:
        self.assertIn("dw 1,255,256,257,320", HARNESS)
        self.assertIn("s2_test_map_count", HARNESS)
        self.assertIn("s2_test_command_count", HARNESS)
        self.assertIn("WIN_ERR_BUSY", HARNESS)
        self.assertIn("WIN_ERR_DEPTH", HARNESS)
        self.assertIn("WIN_ERR_BACKSTORE", HARNESS)
        self.assertIn("call test_rollback_and_screens", HARNESS)
        self.assertIn("call test_label_preflight", HARNESS)
        self.assertIn("call test_free_closes", HARNESS)

    def test_modal_label_preflight_uses_exact_rendered_bounds(self) -> None:
        preflight = STAGE2.split("s2_preflight_label:", 1)[1].split(
            "s2_require_label_geometry:", 1
        )[0]
        self.assertIn("call s1_label_prepare_loaded", preflight)
        self.assertIn("text_pixel_width", preflight)
        self.assertIn("text_x", preflight)
        self.assertIn("text_y", preflight)
        aggregate = STAGE2.split("s2_win_open:", 1)[1].split(
            "s2_open_copy:", 1
        )[0]
        self.assertIn("call s2_set_window_origin", aggregate)
        self.assertIn("call s2_restore_origin", aggregate)
        self.assertIn("s1_label_prepare_loaded:", STAGE1)

    def test_free_cleanup_forces_auto_work_windows(self) -> None:
        cleanup = STAGE2.split("s2_close_all:", 1)[1].split(
            "; ---- modal preflight", 1
        )[0]
        self.assertIn("ld a,WIN_WORK_AUTO", cleanup)
        self.assertIn("ld (data_window),a", cleanup)
        self.assertIn("ld (vram_window),a", cleanup)
        self.assertIn("s2_cleanup_data_window", cleanup)
        self.assertIn("s2_cleanup_vram_window", cleanup)


if __name__ == "__main__":
    unittest.main()
