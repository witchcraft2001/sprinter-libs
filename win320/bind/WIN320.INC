{ WIN320.DLL ABI 1.1 binding for Sprinter Turbo Pascal.                 }
{ Include DSSCORE.INC, DSSFILE.INC, DSSSYS.INC and LIBMAN.INC first.    }
{ This compiler stores record fields byte-packed; all addresses are u16. }

const
  WinSetWorkWindows = 2;  WinSetScreen = 3;       WinGetVersion = 4;
  WinGetConfig = 5;       WinLoadFont = 6;        WinSetTheme = 7;
  WinSetTextFormat = 8;   WinSetOrigin = 9;       WinStyle = 10;
  WinFillRect = 11;       WinFrame = 12;          WinPanel = 13;
  WinSeparator = 14;      WinInvertRect = 15;     WinFocusRect = 16;
  WinLabel = 17;          WinButton = 18;         WinDraw = 19;
  WinDrawItem = 20;       WinUpdate = 21;         WinSetBackstore = 22;
  WinOpen = 23;           WinClose = 24;          WinPoll = 25;
  WinTrack = 26;          WinWaitRelease = 27;    WinSetCursor = 28;
  WinEditDraw = 29;       WinEdit = 30;           WinIcon = 31;
  WinProgressInit = 32;   WinProgressDraw = 33;   WinScrollbarInit = 34;
  WinScrollbarDraw = 35;  WinListboxDraw = 36;    WinCheckbox = 37;
  WinRadiobutton = 38;    WinEntryCount = 39;

  WinErrArgument = $20;   WinErrVideoMode = $21;  WinErrWindow = $22;
  WinErrBackstore = $23;  WinErrDepth = $24;      WinErrUnsupported = $25;
  WinErrBusy = $26;       WinErrFont = $27;       WinErrMemory = $28;

  WinWorkAuto = $FF;
  WinTxtAsciiz = 0;       WinTxtPascal = 1;
  WinRectSunken = $01;    WinRectVertical = $02;
  WinLabelLeft = 0;       WinLabelCenter = 1;      WinLabelRight = 2;
  WinLabelAlignMask = $03; WinLabelFill = $04;     WinLabelClip = $08;
  WinButtonGlyph = $01;   WinButtonFocus = $02;
  WinButtonPressed = $04; WinButtonDisabled = $08;
  WinWindowNoPanel = $01; WinWindowSunken = $02;

  WinTypeNone = 0;        WinTypeLabel = 1;        WinTypeFill = 2;
  WinTypeFrame = 3;       WinTypePanel = 4;        WinTypeSeparator = 5;
  WinTypeButton = 6;      WinTypeIcon = 7;         WinTypeProgress = 8;
  WinTypeScrollbar = 9;   WinTypeListbox = 10;     WinTypeEdit = 11;
  WinTypeZone = 12;       WinTypeCheckbox = 13;    WinTypeRadiobutton = 14;

  WinItemDirty = $01;     WinItemHidden = $02;     WinItemDisabled = $04;
  WinItemHit = $08;       WinItemFocusable = $10;  WinItemPress = $20;
  WinItemRepeat = $40;    WinItemHover = $80;

  WinTrackAnyKey = $01;   WinTrackOutside = $02;   WinTrackHalt = $04;
  WinTrackShowCursor = $08; WinTrackTabFocus = $10;
  WinEventNone = 0;       WinEventLClick = 1;      WinEventRClick = 2;
  WinEventRepeat = 3;     WinEventHotkey = 4;      WinEventKey = 5;
  WinEventHover = 6;      WinEventLeave = 7;       WinEventOutside = 8;
  WinEventFocus = 9;      WinEventChange = 10;

  WinEditFrame = $01;     WinEditFocus = $02;      WinEditPassword = $04;
  WinEditEnter = 0;       WinEditEsc = 1;          WinEditTab = 2;
  WinEditMouse = 3;
  WinChoiceChecked = $01; WinChoiceFocus = $02;    WinChoiceDisabled = $04;
  WinIconKeyed = $01;     WinProgressFrame = $01;
  WinScrollbarHorizontal = $01; WinScrollbarArrows = $02;
  WinListboxFrame = $01;  WinListboxNoCursor = $02;
  WinListboxFocus = $04;  WinListboxPaged = $08;
  WinStylePalette = $01;  WinStyleClear = $02;     WinStyleBoth = $04;

  WinCapCore = $0001;     WinCapEdit = $0002;      WinCapListbox = $0004;
  WinCapScrollbar = $0008; WinCapProgress = $0010; WinCapIcon = $0020;
  WinCapFocus = $0040;    WinCapPascalStr = $0080;
  WinCapCheckbox = $0100; WinCapRadiobutton = $0200;
  WinDiBudgetUs = 200;    WinBackstoreChunk = 256;

type
  TWinTheme = record
    Light, Shadow, Face, Desktop, Text, TextDisabled : byte;
    FieldBg, FieldFg, CursorBg, CursorFg : byte;
    Progress, ProgressFill, ScrollTrack, ScrollThumb : byte;
    FocusMask, Reserved : byte
  end;

  TWinRect = record
    X, Y, Width, Height : integer;
    Color, Flags : byte
  end;

  TWinLabel = record
    X, Y, Width, Height : integer;
    Attr, Flags : byte;
    Text : integer
  end;

  TWinButton = record
    X, Y, Width, Height : integer;
    Attr, Flags : byte;
    Text : integer
  end;

  TWinWindow = record
    X, Y, Width, Height : integer;
    Color, Flags, Count, Focus : byte;
    Items : integer;
    LastFocus, Reserved : byte
  end;

  TWinItem = record
    Kind, Flags, Id, Reserved : byte;
    Control, UserData : integer
  end;

  TWinKey = record
    Ascii, Scan, Mods, Id : byte
  end;

  TWinTrack = record
    Window, Keys : integer;
    KeyCount, Options, EventCode, Id, ItemIndex, Part : byte;
    MouseX : integer;
    MouseY, Buttons, KeyAscii, KeyScan, KeyMods, Reserved : byte;
    Item, UserData : integer;
    RepeatDelay, RepeatRate : byte;
    State : array[0..7] of byte
  end;

  TWinCursor = record Width, Height, HotX, HotY : byte end;

  TWinEdit = record
    X, Y, Width, Height : integer;
    Attr, Flags, MaxLen, Len, Cursor, Scroll : byte;
    Buffer : integer
  end;

  TWinChoice = record
    X, Y, Width, Height : integer;
    Attr, Flags, GroupId, Reserved : byte;
    Text : integer
  end;

  TWinIcon = record
    X, Y, Width, Height : integer;
    Flags, PageNo, Slot, Reserved : byte
  end;

  TWinProgress = record
    X, Y, Width, Height : integer;
    Flags, Percent : byte;
    LastPx : integer
  end;

  TWinScrollbar = record
    X, Y, Width, Height, Visible, Total, First : integer;
    Flags, Reserved : byte;
    ThumbPos, ThumbLen, LastPos : integer
  end;

  TWinTextRef = record PageNo : byte; Offset : integer end;

  TWinListbox = record
    X, Y, Width, Height : integer;
    ItemHeight, AttrNormal, AttrCursor, Flags : byte;
    Total, First, Cursor, Items : integer;
    ItemsPage, Reserved : byte;
    Scrollbar, LastFirst, LastCursor : integer
  end;

  TWinConfig = record
    StructSize, DssMode : byte;
    Width, Height : integer;
    VramWindow, CodeWindow, Screen, BackstorePages : byte;
    BackstoreDepth, FontHeight : byte;
    Capabilities : integer;
    FontPage, DataWindow : byte;
    OriginX : integer;
    OriginY, TextFormat : byte
  end;

procedure WinSetRegs(AValue : byte; DEValue, IXValue, IYValue : integer);
begin
  LibRegA := AValue;
  LibRegDE.W := DEValue;
  LibRegIX.W := IXValue;
  LibRegIY.W := IYValue
end;

function WinApiCall(Handle, Entry : integer) : byte;
begin
  if LibCall(Handle, Entry) then WinApiCall := LibRegA
  else WinApiCall := LibErr
end;

function WinDescriptorCall(Handle, Entry, Descriptor : integer) : byte;
begin
  WinSetRegs(0, Descriptor, 0, 0);
  WinDescriptorCall := WinApiCall(Handle, Entry)
end;

function WinSetScreenCall(Handle : integer; Screen : byte) : byte;
begin
  WinSetRegs(0, Screen, 0, 0);
  WinSetScreenCall := WinApiCall(Handle, WinSetScreen)
end;

function WinSetTextFormatCall(Handle : integer; Fmt : byte) : byte;
begin
  WinSetRegs(0, Fmt, 0, 0);
  WinSetTextFormatCall := WinApiCall(Handle, WinSetTextFormat)
end;

function WinSetOriginCall(Handle, X : integer; Y : byte) : byte;
begin
  WinSetRegs(0, Y, X, 0);
  WinSetOriginCall := WinApiCall(Handle, WinSetOrigin)
end;

function WinStyleCall(Handle : integer; Desktop, Flags : byte) : byte;
begin
  WinSetRegs(0, Desktop * 256 + Flags, 0, 0);
  WinStyleCall := WinApiCall(Handle, WinStyle)
end;

function WinDrawCall(Handle : integer; var Window : TWinWindow) : byte;
begin WinDrawCall := WinDescriptorCall(Handle, WinDraw, addr(Window)) end;

function WinUpdateCall(Handle : integer; var Window : TWinWindow;
                       var Drawn : byte) : byte;
var Status : byte;
begin
  WinSetRegs(0, addr(Window), 0, 0);
  Status := WinApiCall(Handle, WinUpdate);
  if Status = 0 then Drawn := LibRegDE.Lo;
  WinUpdateCall := Status
end;

function WinPollCall(Handle : integer; var Track : TWinTrack) : byte;
begin WinPollCall := WinDescriptorCall(Handle, WinPoll, addr(Track)) end;

function WinTrackCall(Handle : integer; var Track : TWinTrack) : byte;
begin WinTrackCall := WinDescriptorCall(Handle, WinTrack, addr(Track)) end;

function WinEditCall(Handle : integer; var Edit : TWinEdit;
                     var Track : TWinTrack; var Reason : byte) : byte;
var Status : byte;
begin
  WinSetRegs(0, addr(Edit), addr(Track), 0);
  Status := WinApiCall(Handle, WinEdit);
  if Status = 0 then Reason := LibRegDE.Lo;
  WinEditCall := Status
end;
