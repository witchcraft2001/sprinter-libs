from __future__ import annotations

import unittest


def valid_rect(x: int, y: int, width: int, height: int) -> bool:
    return (
        x >= 0
        and y >= 0
        and width >= 0
        and height >= 0
        and x + width <= 640
        and y + height <= 256
    )


def valid_byte_rect(x: int, y: int, width: int, height: int) -> bool:
    return valid_rect(x, y, width, height) and (x | width) & 1 == 0


def valid_copy(source_x: int, destination_x: int, width: int) -> bool:
    return (source_x | destination_x | width) & 1 == 0


def valid_scroll(x: int, width: int, dx: int) -> bool:
    return (x | width | dx) & 1 == 0


def valid_tile(x: int, y: int) -> bool:
    return x & 1 == 0 and 0 <= x <= 608 and 0 <= y <= 240


def valid_tile_clip(x: int, y: int) -> bool:
    return x & 1 == 0 and 0 <= x < 640 and 0 <= y < 256


def compose_keyed(source: int, shadow: int, keyed: bool) -> int:
    if not keyed:
        return source
    if source == 0xFF:
        return shadow
    if source & 0xF0 == 0xF0:
        return (shadow & 0xF0) | (source & 0x0F)
    if source & 0x0F == 0x0F:
        return (source & 0xF0) | (shadow & 0x0F)
    return source


class GeometryTests(unittest.TestCase):
    def test_rect_pixel_boundaries(self) -> None:
        self.assertTrue(valid_byte_rect(0, 0, 640, 256))
        self.assertTrue(valid_byte_rect(638, 255, 2, 1))
        self.assertFalse(valid_byte_rect(639, 255, 1, 1))
        self.assertFalse(valid_byte_rect(2, 0, 640, 1))
        self.assertFalse(valid_byte_rect(0, 1, 2, 256))

    def test_copy_alignment_covers_all_three_fields(self) -> None:
        self.assertTrue(valid_copy(0, 638, 2))
        for values in ((1, 2, 2), (2, 1, 2), (2, 2, 1)):
            self.assertFalse(valid_copy(*values))

    def test_scroll_signed_dx_alignment(self) -> None:
        self.assertTrue(valid_scroll(0, 640, -2))
        self.assertTrue(valid_scroll(2, 638, 2))
        self.assertFalse(valid_scroll(0, 640, -1))
        self.assertFalse(valid_scroll(1, 638, 2))

    def test_tile_full_and_clip_boundaries(self) -> None:
        self.assertTrue(valid_tile(608, 240))
        self.assertFalse(valid_tile(610, 240))
        self.assertFalse(valid_tile(608, 241))
        self.assertTrue(valid_tile_clip(638, 255))
        self.assertFalse(valid_tile_clip(639, 255))
        self.assertFalse(valid_tile_clip(640, 255))

    def test_pixel_primitives_reach_both_last_nibbles(self) -> None:
        for x in (0, 1, 638, 639):
            byte_x, nibble = divmod(x, 2)
            self.assertLess(byte_x, 320)
            self.assertIn(nibble, (0, 1))
        self.assertEqual((319, 0), divmod(638, 2))
        self.assertEqual((319, 1), divmod(639, 2))

    def test_nibble_key_truth_table_is_exhaustive(self) -> None:
        for source in range(256):
            for shadow in range(256):
                self.assertEqual(source, compose_keyed(source, shadow, False))
                actual = compose_keyed(source, shadow, True)
                if source == 0xFF:
                    expected = shadow
                elif source >> 4 == 0x0F:
                    expected = (shadow & 0xF0) | (source & 0x0F)
                elif source & 0x0F == 0x0F:
                    expected = (source & 0xF0) | (shadow & 0x0F)
                else:
                    expected = source
                self.assertEqual(expected, actual)

        self.assertEqual(0xA1, compose_keyed(0xF1, 0xAB, True))
        self.assertEqual(0x2B, compose_keyed(0x2F, 0xAB, True))
        self.assertEqual(0x34, compose_keyed(0x34, 0xAB, True))


if __name__ == "__main__":
    unittest.main()
