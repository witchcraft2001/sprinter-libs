# AFNT640

`AFNT640.DLL` is an L0 Sprinter libman library with the historical ANTONFNT
entry points and Anton Enin's packed 640×256×16 renderer. ABI 1.5 preserves
entries 0..4 and adds flexible physical/display-relative buffer selection.

The ready-to-use release binary is committed as
[`AFNT640.DLL`](AFNT640.DLL). Consumers should use this file directly rather
than rebuilding the library.

| function | registers | meaning |
| ---: | --- | --- |
| 0 | — | initialise; select the default WIN1 video window |
| 1 | — | release (no-op) |
| 2 | A | set the EGA palette and clear the selected graphic screen |
| 3 | DE, IX, IY, A | print ASCIIZ text at `(IX,IY)`; `A = background << 4 \| foreground` |
| 4 | E | select VRAM window `E=0..3`; `A` is ignored for source compatibility |
| 5 | E | select target: `0=BUF0`, `1=BUF1`, `2=FRONT`, `3=BACK` |

Entry 5 returns `A=0`, carry clear on success. An invalid selector returns
`A=AFNT640_ERR_ARGUMENT` (`#10`), carry set, without changing the previous
target. Public constants are in [`afnt640.inc`](afnt640.inc).

`BUF0`/`BUF1` always mean physical buffers. `FRONT`/`BACK` read bit 0 of
`RGMOD` (`#C9`) once at the beginning of each `fnstyle` or `aprint`. The
selected target applies both to text and to `fnstyle` clear/palette work;
entry 5 itself has no rendering or palette side effects.

Without an explicit target, legacy behaviour remains: `aprint` initially uses
BUF0 and `fnstyle` samples DSS `GETVMOD`, masks its `B` result to bit 0, and
caches the resulting physical bank. Initialise both palette banks with
`set_target(BUF0)` + `fnstyle`, followed by `set_target(BUF1)` + `fnstyle`.

`init` maps the video page through WIN1, preserving the historical layout. The
library is fixed to 640×256×16; there is no mode trigger to update. Function 4
returns the selected window in `A` with carry clear. An invalid window, or an
attempt to map VRAM over the window containing the DLL or current stack,
returns carry set and leaves the previous configuration unchanged. If the DLL itself was
loaded in WIN1, `init` keeps the default for compatibility but `fnstyle` and
`aprint` return carry until function 4 selects a different window.

Window 0..3 corresponds to
CPU address bases `#0000`, `#4000`, `#8000`, `#C000` and page ports
`#82`, `#A2`, `#C2`, `#E2`. Both display buffers use VRAM page `#50`; buffer 1
starts at offset `#140` in each scan line. The explicit-target path never
queries DSS. Rendering restores the original mapped page, `PORT_Y=#C0`, and
the caller's original interrupt-enable state.

The historical libman 1.3 dispatcher preserves `A` but normalises CF for
non-init entries. Clients using `LIBMAN.l_call` should test `A`; direct entry
calls also receive the documented CF.

The font is embedded with `INCBIN`, so the DLL has no runtime asset
dependency. `font.bin` is the 6888-byte original Anton format: 256 packed
column widths, 256 low offset bytes, 256 high offset bytes, then variable-size
column-major 8-row glyph rasters.

Screen clearing is performed by the accelerator as 320 vertical fills, one
for each packed byte column. Text rendering uses
`background XOR (mask AND (foreground XOR background))`; on a black
background it omits the background XOR pass. When the text and video memory
occupy different CPU windows, the video page is mapped once for the complete
string. The safe per-character mapping path remains in use when both share a
window.

## Build

The Makefile uses the repository's `sprinter-mkdll` and its `sjasmplus`
two-pass profile:

```sh
make
make verify
make inspect
make raw
make host-test
make z80-test
make release
```

The resulting `build/AFNT640.DLL` is compressed using the historical L0
zero-RLE format and is accepted by libman 1.2. `make raw` writes a canonical
uncompressed image for inspection.
`make release` builds, verifies, runs host/Z80 tests and updates the tracked top-level
`AFNT640.DLL`; commit it together with its source changes.

`make` also builds `build/AFNT640.EXE`, a visual test which separately clears
and initialises BUF0/BUF1, writes through FRONT/BACK before and after an
`RGMOD` flip, and pauses on each physical buffer. It loads the DLL from the
EXE's directory and falls back to the current directory on older DSS versions.
