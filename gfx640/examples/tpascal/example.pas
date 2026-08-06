{ Fragment for a program which already includes DSSCORE/DSSFILE/DSSSYS,
  the updated LIBMAN.INC, and bindings/tpascal/GFX640.INC. }

procedure PutWord(var d : GfxFillRectDesc; offset, value : integer);
begin
  d[offset] := lo(value);
  d[offset + 1] := hi(value)
end;

function DrawPanel(gfx : integer) : byte;
var r : GfxFillRectDesc;
begin
  fillchar(r, GfxFillRectSize, 0);
  PutWord(r, 0, 16);      { x }
  r[2] := 16;             { y }
  PutWord(r, 3, 608);     { width; packed-byte primitives require even values }
  PutWord(r, 5, 48);      { height }
  r[7] := 4;              { color }
  r[8] := GfxTargetFront;
  DrawPanel := GfxCallDescriptor(gfx, GfxFillRect, r)
end;
