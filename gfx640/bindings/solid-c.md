# SOLID C `REGS` adapter

GFX640 is compatible with the existing `loaddll/calldll/freedll` client.
Before `calldll`, fill `A`, `DE`, `IX`, and `IY` exactly as listed in
`specs.md`/`gfx640.inc`; set the function number to the frozen entry value.
Entries 36..41 are the exact-transparent tile, clip, span, list, tilemap and
metatile variants. They use the same registers/descriptors as entries
23/35/25/34/26/27 and apply per-nibble colour-15 transparency only when
`GFX_KEY_FF` is present.

After dispatch, first check the DLL manager result, then inspect `A`:
`A=0` is success and `A=#10..#17` is a GFX640 error. Carry from entries
`>=1` is not a GFX640 result channel. Packed descriptors must remain reachable
while the call runs and may not be placed in WIN0 for tile operations.
