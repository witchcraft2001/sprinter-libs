# SOLID C `REGS` adapter

GFX320 is compatible with the existing `loaddll/calldll/freedll` client.
Before `calldll`, fill `A`, `DE`, `IX`, and `IY` exactly as listed in
`specs.md`/`gfx320.inc`; set the function number to the frozen entry value.

After dispatch, first check the DLL manager result, then inspect `A`:
`A=0` is success and `A=#10..#17` is a GFX320 error. Carry from entries
`>=1` is not a GFX320 result channel. Packed descriptors must remain reachable
while the call runs and may not be placed in WIN0 for tile operations.
