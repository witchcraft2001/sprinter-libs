# AFNT320

`AFNT320.DLL` is the 320×256×256 counterpart to `AFNT640.DLL`. It keeps the
same five-entry libman ABI, renders one byte per pixel in 320×256 graphics
mode, and embeds the font used by `gfxview`.

| function | registers | meaning |
| ---: | --- | --- |
| 0 | — | initialise; select the default WIN1 video window |
| 1 | — | release (no-op) |
| 2 | A | set the EGA palette and clear the selected graphic screen |
| 3 | DE, IX, IY, A | print ASCIIZ text at `(IX,IY)`; `A = background << 4 \| foreground` |
| 4 | E | select VRAM window `E=0..3`; return it in A, carry clear |

An invalid window, or a request to map video memory over the window containing
the relocated DLL, returns with carry set and leaves the prior mapping intact.
If the DLL is loaded in WIN1, call function 4 before `fnstyle`/`aprint` to
select a different window. The page ports are `#82/#A2/#C2/#E2`, and the
corresponding screen bases are `#0000/#4000/#8000/#C000`.

`fnstyle` calls DSS `GETVMOD` once and caches the selected screen page;
`aprint` never probes the video mode. Thus repeated text output does not pay a
per-line mode-call cost. Both buffers share VRAM page `#50`; buffer 1 begins
at offset `#140` within every scan line.

## Embedded accelerator font

`font.bin` is vendored verbatim from `gfxview/font.bin` (2304 bytes):

* bytes 0..255 — advance width for each character;
* bytes 256..2303 — eight rows of 256 one-bit glyph bytes, bit 7 leftmost.

During the build, `tools/font_to_accel.py` converts it to variable-width
column-major data. A 256-byte occupancy table identifies non-empty glyph
columns; only those columns are stored as eight `00/FF` mask bytes. Empty
columns are emitted directly with `FILL_VERT`, while non-empty columns are
combined with foreground/background blocks and written with `COPY_VERT`.
On a black background the renderer omits the background XOR pass entirely.
The generated asset is assembled with `INCBIN`, so the deployed DLL has no
external font-file dependency.

Screen clearing also uses the accelerator: 320 vertical fill operations clear
all 256 rows without an 81,920-iteration CPU pixel loop.

## Build

```sh
make
make verify
make inspect
make raw
```

The Makefile invokes the repository's `sprinter-mkdll` and `sjasmplus`; the
result is an L0 zero-RLE compressed DLL accepted by libman 1.2.

`make` also builds `build/AFNT320.EXE`, a visual test which loads
`AFNT320.DLL` from the EXE's directory and renders twelve coloured text
rows. It falls back to the current directory on older DSS versions.
