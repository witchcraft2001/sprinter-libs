# AFNT640

`AFNT640.DLL` is an L0 Sprinter libman library with the historical ANTONFNT
entry points and Anton Enin's packed 640×256×16 renderer.

| function | registers | meaning |
| ---: | --- | --- |
| 0 | — | initialise; select the default WIN1 video window |
| 1 | — | release (no-op) |
| 2 | A | set the EGA palette and clear the selected graphic screen |
| 3 | DE, IX, IY, A | print ASCIIZ text at `(IX,IY)`; `A = background << 4 \| foreground` |
| 4 | E | select VRAM window `E=0..3`; `A` is ignored for source compatibility |

`init` maps the video page through WIN1, preserving the historical layout. The
library is fixed to 640×256×16; there is no mode trigger to update. Function 4
returns the selected window in `A` with carry clear. An invalid window, or an
attempt to map VRAM over the window containing the DLL itself, returns carry
set and leaves the previous configuration unchanged. If the DLL itself was
loaded in WIN1, `init` keeps the default for compatibility but `fnstyle` and
`aprint` return carry until function 4 selects a different window.

Window 0..3 corresponds to
CPU address bases `#0000`, `#4000`, `#8000`, `#C000` and page ports
`#82`, `#A2`, `#C2`, `#E2`. Both display buffers use VRAM page `#50`; buffer 1
starts at offset `#140` in each scan line. `fnstyle` samples DSS
`GETVMOD` (`#51`) once to capture the selected screen;
`aprint` never queries DSS, so printing many lines does not incur a mode call
per line.

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
```

The resulting `build/AFNT640.DLL` is compressed using the historical L0
zero-RLE format and is accepted by libman 1.2. `make raw` writes a canonical
uncompressed image for inspection.

`make` also builds `build/AFNT640.EXE`, a visual test which loads
`AFNT640.DLL` from the EXE's directory and renders twelve coloured text
rows. It falls back to the current directory on older DSS versions.
