import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
INC = (ROOT / "win320.inc").read_text()
MAKEFILE = (ROOT / "Makefile").read_text()
VISUAL = (ROOT / "test.asm").read_text()
C_BIND = (ROOT / "bind" / "win320.h").read_text()
C_IMPL = (ROOT / "bind" / "win320.c").read_text()
P_BIND = (ROOT / "bind" / "WIN320.INC").read_text()


class Stage7ContractTests(unittest.TestCase):
    def test_di_budget_is_public_and_overrideable(self) -> None:
        self.assertIn("ifndef WIN_DI_BUDGET_US", INC)
        self.assertIn("WIN_DI_BUDGET_US         equ 200", INC)

    def test_hardware_benchmark_target_is_buildable(self) -> None:
        self.assertIn("BENCH_EXE := $(BUILD)/WINBENCH.EXE", MAKEFILE)
        self.assertIn("-DWIN320_BENCH=1", MAKEFILE)
        self.assertIn("benchmark: $(BENCH_EXE)", MAKEFILE)

    def test_benchmark_covers_invert_scaling_and_backstore(self) -> None:
        bench = VISUAL.split("ifdef WIN320_BENCH", 2)[2].split(
            "; Load the two payload pages", 1
        )[0]
        for token in (
            "win_benchmark_invert1_ticks",
            "win_benchmark_invert8_ticks",
            "win_benchmark_invert32_ticks",
            "win_benchmark_invert320_ticks",
            "win_benchmark_backstore_ticks",
            "WIN_INVERT_RECT",
            "WIN_OPEN",
            "WIN_CLOSE",
            "WIN_BACKSTORE_CHUNK",
        ):
            self.assertIn(token, bench if token != "WIN_BACKSTORE_CHUNK" else INC)
        self.assertIn("dw 0,160,320,64", bench)
        self.assertIn("ld a,112", bench)
        self.assertIn("ld a,125", bench)
        self.assertIn("align 256", bench)
        self.assertIn("ds 257", bench)

    def test_c_binding_locks_all_structure_sizes_and_offsets(self) -> None:
        for size in (16, 10, 12, 8, 4, 32, 14, 22, 3, 28, 20):
            self.assertIn("== %d" % size, C_IMPL)
        for offset in (1, 4, 8, 10, 12, 14, 16, 18, 22, 24):
            self.assertIn("== %d" % offset, C_IMPL)
        self.assertIn("WIN_ENTRY_COUNT", C_BIND)
        self.assertIn("win320_radiobutton", C_BIND)
        self.assertIn("win320_libman_call", C_BIND)

    def test_pascal_binding_and_three_dialog_examples_are_present(self) -> None:
        for token in (
            "WinEntryCount = 39", "TWinWindow = record",
            "TWinTextRef = record", "TWinChoice = record",
            "WinApiCall", "LibRegDE.W", "LibRegIX.W", "LibRegIY.W",
        ):
            self.assertIn(token, P_BIND)
        for name in ("dialog.asm", "dialog.c", "DIALOG.PAS"):
            source = (ROOT / "examples" / name).read_text()
            for token in ("Win", "Listbox", "Scrollbar"):
                self.assertIn(token.lower(), source.lower())
        self.assertIn("WIN_IT_DIRTY", (ROOT / "examples" / "dialog.asm").read_text())
        self.assertIn("WIN_IT_DIRTY", (ROOT / "examples" / "dialog.c").read_text())
        self.assertIn("WinItemDirty", (ROOT / "examples" / "DIALOG.PAS").read_text())


if __name__ == "__main__":
    unittest.main()
