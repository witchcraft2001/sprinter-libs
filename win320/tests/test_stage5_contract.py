from __future__ import annotations

import unittest
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "win320.asm").read_text()
STAGE2 = (ROOT / "stage2.inc").read_text()
STAGE4 = (ROOT / "stage4.inc").read_text()
STAGE5 = (ROOT / "stage5.inc").read_text()
VISUAL = (ROOT / "test.asm").read_text()
MAKEFILE = (ROOT / "Makefile").read_text()
LAYOUT = (ROOT / "win320_layout.inc").read_text()


def layout_value(name: str) -> int:
    match = re.search(
        rf"^{name}\s+equ\s+#([0-9a-f]+)$", LAYOUT,
        re.MULTILINE | re.IGNORECASE,
    )
    if match is None:
        raise AssertionError(f"missing literal layout equate {name}")
    return int(match.group(1), 16)


def decode_l0_image(path: Path) -> tuple[bytes, bytes]:
    raw = path.read_bytes()
    loaded_size = int.from_bytes(raw[2:4], "little")
    code_size = int.from_bytes(raw[4:6], "little")
    reloc_size = int.from_bytes(raw[6:8], "little")
    expected = code_size + reloc_size
    if loaded_size == expected:
        image = raw[:loaded_size]
    else:
        image = bytearray(raw[:16])
        position = 16
        while position < loaded_size:
            value = raw[position]
            position += 1
            if value:
                image.append(value)
                continue
            count = raw[position] or 256
            position += 1
            image.extend(bytes(count))
        image = bytes(image)
    if len(image) != expected:
        raise AssertionError("decoded L0 image has an unexpected size")
    return image[:code_size], image[code_size:]


class Stage5ContractTests(unittest.TestCase):
    def test_overlay_reclaims_the_consumed_l0_bitmap(self) -> None:
        base = layout_value("S5_OVERLAY_OFFSET")
        size = layout_value("S5_OVERLAY_CODE_SIZE")
        self.assertEqual(0x4000, base + size)
        self.assertIn('include "win320_layout.inc"', SOURCE)
        self.assertIn("s5_overlay_base:", SOURCE)
        self.assertIn("call load_stage5_overlay", SOURCE)
        loader = SOURCE.split("load_stage5_overlay:", 1)[1].split(
            "; ---- configuration helpers", 1
        )[0]
        self.assertIn("ld de,S5_OVERLAY_CODE_SIZE", loader)
        self.assertIn("ld (s5_overlay_dest),hl", loader)
        self.assertIn("ld (s5_overlay_reads),a", loader)
        self.assertIn("cp S5_OVERLAY_CODE_SIZE/256", loader)
        stub = (ROOT / "stage5_stub.inc").read_text()
        self.assertEqual(14, stub.count("equ s5_overlay_base+"))
        jump_table = (ROOT / "stage5_overlay.asm").read_text().split(
            'include "stage5.inc"', 1
        )[0]
        self.assertEqual(15, jump_table.count("        jp "))
        overlay = (ROOT / "build" / "stage5.overlay").read_bytes()
        self.assertEqual(4 * size, len(overlay))

    def test_every_production_overlay_reference_is_relocated(self) -> None:
        code, bitmap = decode_l0_image(ROOT / "build" / "WIN320.DLL")
        base = layout_value("S5_OVERLAY_OFFSET")
        expected_offsets = {
            0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42
        }
        relocated_offsets: set[int] = set()
        for position in range(len(code) - 2):
            target = code[position + 1] | code[position + 2] << 8
            high_byte = position + 2
            relocated = bitmap[high_byte // 8] & (0x80 >> (high_byte % 8))
            if relocated and base <= target < base + 45:
                relocated_offsets.add(target - base)
        self.assertEqual(expected_offsets, relocated_offsets)

    def test_composite_hit_detail_is_part_of_the_overlay(self) -> None:
        overlay_source = (ROOT / "stage5_overlay.asm").read_text()
        stage3 = (ROOT / "stage3.inc").read_text()
        self.assertIn("jp s5_hit_detail", overlay_source)
        self.assertIn("call s5_overlay_base+18", stage3)
        for part in (
            "WIN_SB_PART_BACK", "WIN_SB_PART_FORWARD",
            "WIN_SB_PART_PAGE_BACK", "WIN_SB_PART_PAGE_FORWARD",
            "WIN_SB_PART_THUMB", "WIN_LB_PART_ROW",
        ):
            self.assertIn(part, STAGE5)

    def test_all_entries_have_implementations_and_declarative_dispatch(self) -> None:
        for label in (
            "win_icon:", "win_progress_init:", "win_progress_draw:",
            "win_scrollbar_init:", "win_scrollbar_draw:",
            "win_listbox_draw:",
        ):
            self.assertIn(label, STAGE5)
        for control in (
            "WIN_T_ICON", "WIN_T_PROGRESS", "WIN_T_SCROLLBAR", "WIN_T_LISTBOX"
        ):
            self.assertIn(control, STAGE2)

    def test_renderers_validate_and_publish_incremental_state(self) -> None:
        self.assertIn("WIN_ICO_KEYED", STAGE5)
        self.assertIn("call s5_map_icon_pair", STAGE5)
        self.assertIn("call s5_progress_boundary", STAGE5)
        progress = STAGE5.split("s5_progress_draw_ptr:", 1)[1].split(
            "; Validate and prepare full/inner geometry", 1
        )[0]
        self.assertIn(
            "call s1_panel_mapped\n        call s5_set_inner_fill",
            progress,
        )
        plain = progress.split(".plain:", 1)[1].split(".filled_bg:", 1)[0]
        self.assertIn("call s5_set_inner_fill", plain)
        self.assertIn("WIN_PG_LAST_PX", STAGE5)
        self.assertIn("call s5_scale_ratio", STAGE5)
        self.assertIn("WIN_SB_THUMB_POS", STAGE5)
        scrollbar_geometry = STAGE5.split("s5_scrollbar_geometry:", 1)[1].split(
            "s5_scale_ratio:", 1
        )[0]
        self.assertIn("cp WIN_SB_MIN_THUMB", scrollbar_geometry)
        self.assertIn(
            "ld de,(s5_track_len)\n"
            "        push hl\n"
            "        or a\n"
            "        sbc hl,de\n"
            "        pop hl",
            scrollbar_geometry,
        )
        self.assertIn("WIN_LB_PAGED", STAGE5)
        self.assertIn("jp nz,s5_listbox_copy_paged", STAGE5)
        self.assertIn("WIN_LB_LAST_FIRST", STAGE5)
        self.assertIn("WIN_LB_LAST_CURSOR", STAGE5)
        list_draw = STAGE5.split("s5_listbox_draw_ptr:", 1)[1].split(
            "s5_load_listbox:", 1
        )[0]
        self.assertIn("ld c,0", list_draw)
        self.assertIn("WIN_LB_LAST_CURSOR", list_draw)

    def test_listbox_focus_is_derived_from_window_focus(self) -> None:
        sync = STAGE4.split("s4_sync_item_focus:", 1)[1].split(
            "s4_cursor_hide:", 1
        )[0]
        redraw = STAGE4.split("s4_item_needs_focus_redraw:", 1)[1].split(
            "; ---- Stage-3 focus", 1
        )[0]
        self.assertIn("call s4_is_focus_visual", sync)
        self.assertIn("cp WIN_T_LISTBOX", sync)
        self.assertIn("call s4_is_focus_visual", redraw)
        self.assertIn("s4_focus_sync_value", STAGE5)
        list_draw = STAGE5.split("s5_listbox_draw_ptr:", 1)[1].split(
            "s5_load_listbox:", 1
        )[0]
        self.assertIn(
            "ld a,(s5_list_scratch+WIN_LB_FLAGS)\n        xor (hl)",
            list_draw,
        )

    def test_scrollbar_thumb_uses_common_raised_panel(self) -> None:
        raised = STAGE5.split("s5_raised_fill_mapped:", 1)[1].split(
            "s5_set_track_fill:", 1
        )[0]
        self.assertIn("jp s1_panel_mapped", raised)
        track = STAGE5.split("s5_set_track_fill:", 1)[1].split(
            "s5_publish_scrollbar:", 1
        )[0]
        self.assertIn("ld de,rect_x", track)
        self.assertIn("ld bc,8", track)
        self.assertIn("ld (rect_w),de", track)
        self.assertIn("ld (rect_h),de", track)

    def test_incremental_scroll_uses_pixel_move_and_small_repaints(self) -> None:
        scroll = STAGE5.split("s5_listbox_scroll_pixels:", 1)[1].split(
            "s5_load_listbox:", 1
        )[0]
        self.assertIn("ld a,a", scroll)
        self.assertIn("out (YPORT),a", scroll)
        self.assertIn("ld b,b", scroll)
        self.assertIn("jr z,s5_listbox_scroll_done", scroll)
        draw = STAGE5.split("s5_listbox_draw_ptr:", 1)[1].split(
            "s5_listbox_scroll_pixels:", 1
        )[0]
        self.assertIn("call s5_listbox_scroll_pixels", draw)
        self.assertIn("s5_scroll_edge", draw)
        load = STAGE5.split("s5_load_listbox:", 1)[1].split(
            "s5_sync_list_scrollbar:", 1
        )[0]
        self.assertIn("ld (s5_content_h),hl", load)
        self.assertIn("remainder stays as field background", load)

    def test_inactive_selection_and_thumb_use_button_face(self) -> None:
        thumb = STAGE5.split("s5_scrollbar_thumb_mapped:", 1)[1].split(
            "s5_raised_fill_mapped:", 1
        )[0]
        self.assertIn("current_theme+WIN_TH_FACE", thumb)
        old = STAGE5.split("s5_scrollbar_old_thumb_mapped:", 1)[1].split(
            "s5_scrollbar_thumb_mapped:", 1
        )[0]
        self.assertIn("WIN_SB_LAST_POS", old)
        self.assertIn("WIN_SB_THUMB_LEN", old)
        row = STAGE5.split("s5_listbox_draw_row:", 1)[1].split(
            "s5_listbox_text_pointer:", 1
        )[0]
        self.assertIn("ld b,WIN_TH_FACE", row)
        self.assertIn("ld c,WIN_TH_TEXT", row)

    def test_z80_harness_exercises_stage5_state(self) -> None:
        harness = (ROOT / "tests" / "z80" / "t_stage5.asm").read_text()
        for entry in (
            "win_progress_init", "win_progress_draw", "win_scrollbar_init",
            "win_scrollbar_draw", "win_listbox_draw", "win_icon",
        ):
            self.assertIn(entry, harness)

    def test_visual_showcase_loads_wip1_and_animates_controls(self) -> None:
        self.assertIn("call run_stage5_showcase", VISUAL)
        self.assertIn("load_icon_pack:", VISUAL)
        self.assertIn('icon_pack_name:  db "ICONS.WIP",0', VISUAL)
        self.assertIn("cp $(EXAMPLE_ICONS) $(RELEASE_ICONS)", MAKEFILE)
        self.assertIn('db "WIP1",1,2', VISUAL)
        header_read = VISUAL.split("load_icon_pack:", 1)[1].split(
            "ld hl,icon_pack_header", 1
        )[0]
        self.assertIn("ld a,(icon_pack_handle)", header_read)
        icon_loader = VISUAL.split("load_icon_pack:", 1)[1].split(
            "wait_step:", 1
        )[0]
        self.assertIn("out (PAGE_PORT1),a", icon_loader)
        self.assertIn("ld hl,#4000", icon_loader)
        self.assertNotIn("out (#82),a", icon_loader)
        self.assertNotIn("ld hl,0\n        ld de,#4000", icon_loader)
        for entry in (
            "WIN_PROGRESS_INIT", "WIN_PROGRESS_DRAW", "WIN_SCROLLBAR_INIT",
            "WIN_T_LISTBOX", "WIN_T_SCROLLBAR", "WIN_T_ICON",
        ):
            self.assertIn(entry, VISUAL)
        interactive = VISUAL.split("stage5_interact:", 1)[1].split(
            "; Load the two payload pages", 1
        )[0]
        for token in (
            "WIN_TRK_ITEM", "WIN_TRK_PART",
            "WIN_SB_PART_BACK", "WIN_SB_PART_FORWARD",
            "WIN_SB_PART_PAGE_BACK", "WIN_SB_PART_PAGE_FORWARD",
            "cp #58", "cp #52", "cp #59", "cp #53",
        ):
            self.assertIn(token, interactive)
        key_path = interactive.split(".key:", 1)[1].split(".up:", 1)[0]
        self.assertIn("ld a,(stage5_window+WIN_WND_FOCUS)", key_path)
        self.assertIn("cp 1", key_path)
        self.assertIn("jp nz,.track", key_path)
        self.assertIn("WIN_TRK_ANY_KEY|WIN_TRK_OUTSIDE", VISUAL)
        self.assertIn(
            'str_stage5_hint: db "Arrows/PgUp/PgDn, mouse or Tab; Esc exits",0',
            VISUAL,
        )

    def test_visual_mouse_demo_owns_cursor_without_double_show(self) -> None:
        stage3 = VISUAL.split("run_stage3_dialog:", 1)[1].split(
            "run_stage4_dialogs:", 1
        )[0]
        self.assertIn("ld b,WIN_SET_CURSOR", stage3)
        self.assertIn("ld c,4", stage3)
        self.assertIn("ld c,2                       ; win_track owns", stage3)
        self.assertIn(
            "WIN_TRK_OUTSIDE|WIN_TRK_HALT|WIN_TRK_SHOW_CUR", VISUAL
        )

    def test_visual_nested_modal_clips_its_long_prompt(self) -> None:
        modal_b = VISUAL.split("modal_b_label:", 1)[1].split(
            "; ---- Stage-4", 1
        )[0]
        self.assertIn(
            "WIN_LABEL_CENTER|WIN_LABEL_FILL|WIN_LABEL_CLIP", modal_b
        )


if __name__ == "__main__":
    unittest.main()
