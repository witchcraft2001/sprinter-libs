{ GFX640.DLL ABI 1.0 constants and thin helpers.
  The DLL is non-reentrant: never call GFX entries directly from an ISR.
  Let a frame ISR update a flag/counter and make GFX calls from the main loop.
  Include the updated LIBMAN.INC first. Packed descriptors should be declared
  as byte arrays and filled through the offsets below. }

const
  GfxClear = 6; GfxFillRect = 7; GfxHLine = 8; GfxVLine = 9;
  GfxCopyRect = 10; GfxCopyBuffer = 11; GfxRestoreRect = 12;
  GfxPaletteLoad256 = 13; GfxPaletteLoadRange = 14; GfxPaletteSet = 15;
  GfxFadeBegin = 16; GfxFadeStep = 17; GfxFadeCancel = 18;
  GfxSwapBuffers = 21; GfxSetPageTable = 22;
  GfxDrawTile = 23; GfxDrawTileFast = 24; GfxDrawTileSpan = 25;
  GfxDrawTilemap = 26; GfxDrawMetatile = 27; GfxDrawRect = 28;
  GfxPutPixel = 29; GfxGetPixel = 30; GfxLine = 31;
  GfxMoveRect = 32; GfxScrollRect = 33; GfxDrawTileList = 34;
  GfxDrawTileClip = 35;
  GfxDrawTileTransparent = 36; GfxDrawTileClipTransparent = 37;
  GfxDrawTileSpanTransparent = 38; GfxDrawTileListTransparent = 39;
  GfxDrawTilemapTransparent = 40; GfxDrawMetatileTransparent = 41;

  GfxErrArgument = $10; GfxErrMode = $11; GfxErrWindow = $12;
  GfxErrPage = $13; GfxErrTile = $14; GfxErrPalette = $15;
  GfxErrBusy = $16; GfxErrUnsupported = $17;

  GfxTargetBuf0 = 0; GfxTargetBuf1 = 1;
  GfxTargetFront = 2; GfxTargetBack = 3;
  GfxVramOnly = 4; GfxKeyFF = 8;
  GfxPalBuffer0 = 1; GfxPalBuffer1 = 2; GfxPalBoth = 3;
  GfxFadeOut = 0; GfxFadeIn = 1;
  GfxScreenWidth = 640; GfxScreenHeight = 256;
  GfxTileWidth = 32; GfxTileHeight = 16; GfxColorMask = $0f;
  GfxLengthMask = $03ff; GfxLengthFlagsMask = $3c00;
  GfxLengthFlagsShift = 10;
  GfxCapNibbleKey = $0100;

  GfxFillRectSize = 12; GfxCopyRectSize = 12;
  GfxRestoreRectSize = 8; GfxTileSpanSize = 8;
  GfxTileListSize = 8; GfxTilemapSize = 20;
  GfxMetatileSize = 8; GfxLineSize = 8; GfxScrollRectSize = 16;

type
  GfxFillRectDesc = array[0..11] of byte;
  GfxCopyRectDesc = array[0..11] of byte;
  GfxRestoreRectDesc = array[0..7] of byte;
  GfxTileSpanDesc = array[0..7] of byte;
  GfxTileListDesc = array[0..7] of byte;
  GfxTilemapDesc = array[0..19] of byte;
  GfxMetatileDesc = array[0..7] of byte;
  GfxLineDesc = array[0..7] of byte;
  GfxScrollRectDesc = array[0..15] of byte;

function GfxCallStatus(handle, entry : integer) : byte;
begin
  if LibCall(handle, entry) then GfxCallStatus := LibRegA
  else GfxCallStatus := LibErr
end;

function GfxCallDescriptor(handle, entry : integer; var descriptor) : byte;
begin
  LibRegA := 0;
  LibRegDE.W := addr(descriptor);
  LibRegIX.W := 0;
  LibRegIY.W := 0;
  GfxCallDescriptor := GfxCallStatus(handle, entry)
end;
