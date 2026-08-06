# GFX640 hardware benchmark

Русская версия: [BENCHMARK.ru.md](BENCHMARK.ru.md).

## Purpose

The benchmark answers one question: how long do real GFX640 operations take
on the target machine. Those numbers gate optimization work — specs.md §15
requires hardware timing proof that the worst-case DI sections fit the
`GFX_DI_BUDGET_US` budget before optional loop unrolling or nonempty-row
masks may be enabled. It is not needed to *use* the library.

## Running

Build with `make -C gfx640 benchmark` and place `build/GFXBENCH.EXE` beside
the matching `GFX640.DLL`. Unlike `GFX640.EXE`, the benchmark build skips
the visual demo entirely: it initializes the library, runs the timed
batches, clears the screen and draws only the results, then waits for a key.

The harness installs its own CTC IM2 counter for the duration of the
measurements. The Sprinter CTC is clocked at a fixed 7 MHz, so the counter
cascade 112×125 = 14000 yields an exact 500 Hz tick (2 ms). The IM2 vector
table lives inside the EXE image (never in WIN0 — that is the DSS system
page), the previous `I` register is saved and restored, and the CTC channels
are reset before returning to DSS.

## Reading the results

The final screen contains four horizontal bars starting at the left edge.
One 2-ms tick draws two pixels, therefore **bar width in pixels equals the
batch duration in milliseconds**; bars clamp at the full 640-pixel width
(≥ 640 ms):

1. red — 8 full-screen clears;
2. green — 128 opaque packed 16×32 tiles;
3. cyan — 8 complete front-to-back buffer copies;
4. orange — 4 full RGB8 palette loads into both banks.

Average time per operation = `bar_width_in_px ms / iterations`. A missing
bar means the batch finished within the same tick it started (under 2 ms).

A note on the palette: a full load is not a 1.5-KB block copy. The hardware
palette lives in 256 separate VRAM rows: every colour takes an `OUT` to
`PORT_Y` plus 8 bytes written to fixed register addresses in both banks, so
LDIR is architecturally impossible. At full brightness the library uses a
fast path that bypasses the LUT translation; the brightness-LUT path remains
only inside an active fade.

Record the bar widths together with the machine and clock configuration.
The harness measures the public `l_call` cost as well as the DLL operation
itself. MAME results should be recorded separately and must not be used as
the sole performance decision.
