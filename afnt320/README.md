# AFNT320

`AFNT320.DLL` is the 320×256×256 counterpart to `AFNT640.DLL`. ABI 1.5 keeps
historical entries 0..4 fixed and adds entry 5 for selecting either physical
or display-relative output. It renders one byte per pixel and embeds the font
used by `gfxview`.

The ready-to-use release binary is committed as
[`AFNT320.DLL`](AFNT320.DLL). Consumers should copy this file directly and do
not need the assembler or DLL packaging tools.

| function | registers | meaning |
| ---: | --- | --- |
| 0 | — | initialise; select the default WIN1 video window |
| 1 | — | release (no-op) |
| 2 | A | set the EGA palette and clear the selected graphic screen |
| 3 | DE, IX, IY, A | print ASCIIZ text at `(IX,IY)`; `A = background << 4 \| foreground` |
| 4 | E | select VRAM window `E=0..3`; return it in A, carry clear |
| 5 | E | select target: `0=BUF0`, `1=BUF1`, `2=FRONT`, `3=BACK` |

Entry 5 returns `A=0`, carry clear on success. An invalid selector returns
`A=AFNT320_ERR_ARGUMENT` (`#10`), carry set, without changing the previous
target. Public entry, selector and error constants are in
[`afnt320.inc`](afnt320.inc).

`BUF0` and `BUF1` always name physical buffers. `FRONT` and `BACK` read bit 0
of `RGMOD` (`#C9`) once at the beginning of each `fnstyle` or `aprint`, so one
call cannot straddle two buffers. The selected target applies to text and to
`fnstyle`; palette loading is restricted to the resolved physical bank.
`set_target` itself does not draw, clear or load a palette.

Without an explicit `set_target`, compatibility is unchanged: `aprint` starts
on BUF0, while `fnstyle` samples DSS `GETVMOD`, masks `B` to bit 0 and caches
that physical buffer. To initialise both palette banks, call
`set_target(BUF0)` + `fnstyle`, then `set_target(BUF1)` + `fnstyle`.

An invalid window, or a request to map video memory over the window containing
the relocated DLL or current stack, returns with carry set and leaves the
prior mapping intact.
If the DLL is loaded in WIN1, call function 4 before `fnstyle`/`aprint` to
select a different window. The page ports are `#82/#A2/#C2/#E2`, and the
corresponding screen bases are `#0000/#4000/#8000/#C000`.

No DSS call is made on the explicit-target hot path. Both buffers share VRAM
page `#50`; buffer 1 begins at offset `#140` within every scan line. Rendering
restores the mapped page and `PORT_Y=#C0`, and restores the caller's original
interrupt-enable state.

The historical libman 1.3 dispatcher preserves `A` but normalises CF for
non-init entries. Clients using `LIBMAN.l_call` should treat nonzero `A` as
the function error status; direct entry calls also receive the documented CF.

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
make host-test
make z80-test
make release
```

The Makefile invokes the repository's `sprinter-mkdll` and `sjasmplus`; the
result is an L0 zero-RLE compressed DLL accepted by libman 1.2.
`make release` builds, verifies, runs host/Z80 tests and updates the tracked top-level
`AFNT320.DLL`; commit it together with its source changes.

`make` also builds `build/AFNT320.EXE`, a visual test which separately clears
and initialises BUF0/BUF1, writes through FRONT/BACK before and after an
`RGMOD` flip, and pauses on each physical buffer. It loads the DLL from the
EXE's directory and falls back to the current directory on older DSS versions.
