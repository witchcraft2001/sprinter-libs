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
    return x & 1 == 0 and 0 <= x <= 624 and 0 <= y <= 224


def valid_tile_clip(x: int, y: int) -> bool:
    return x & 1 == 0 and 0 <= x < 640 and 0 <= y < 256


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
        self.assertTrue(valid_tile(624, 224))
        self.assertFalse(valid_tile(626, 224))
        self.assertFalse(valid_tile(624, 225))
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


if __name__ == "__main__":
    unittest.main()
