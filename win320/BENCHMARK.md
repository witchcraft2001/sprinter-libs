# WIN320 hardware benchmark

The benchmark measures real public-ABI rendering and backstore batches on a
Sprinter. Build it with:

```sh
make benchmark
```

Place `build/WINBENCH.EXE` beside the matching `build/WIN320.DLL`. The harness
uses CTC channels 2/3 as an exact 500 Hz counter, restores IM1 and the previous
`I` register afterwards, and draws five result bars. One counter tick becomes
two pixels, so each bar width in pixels is the elapsed batch time in
milliseconds:

1. red — 128 calls of `win_invert_rect`, width 1;
2. green — 128 calls, width 8;
3. cyan — 64 calls, width 32;
4. orange — 16 calls, width 320;
5. magenta — four `win_open`/`win_close` pairs for a 320×64 backstore area.

Bars clamp at 320 ms. Divide the width by the iteration count for average
public-call time. Record raw widths, machine revision and CPU clock. MAME
results are useful for regression but are not sufficient to select the final
CPU/FN_ACC crossover or certify the default `WIN_DI_BUDGET_US=200` budget.

The timer observes whole public calls. Backstore rows are intentionally
measured separately because `WIN_BACKSTORE_CHUNK=256` is one atomic transfer
and is exempt from the ordinary drawing budget.

## Recorded results

### MAME, 2026-08-03

Approximate bar widths from the visual run:

| Batch | Bar | Average operation time |
|---|---:|---:|
| 128 × invert width 1 | 16 ms | 125 µs |
| 128 × invert width 8 | 16 ms | 125 µs |
| 64 × invert width 32 | 8 ms | 125 µs |
| 16 × invert width 320 | 2 ms | 125 µs |
| 4 × open+close, 320×64 | 16 ms | 4 ms |

These screenshot-derived values are approximate. The identical invert
averages indicate that dispatcher/timer quantization dominates this MAME run;
they do not establish a CPU/FN_ACC crossover. Keep the default 200 µs budget
until the same batches are measured on real hardware.
