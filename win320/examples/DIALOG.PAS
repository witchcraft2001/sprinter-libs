{ WIN320 ABI 2.0 Turbo Pascal example. Build with the Sprinter TPC library }
{ search path and place WIN320.DLL beside the resulting executable.         }
program WinDialog;
{$I DSSCORE.INC}
{$I DSSFILE.INC}
{$I DSSSYS.INC}
{$I LIBMAN.INC}
{$I ..\bind\WIN320.INC}

var
  H : integer;
  StatusCode, Drawn : byte;
  TitleText, StatusReady, StatusChanged : string[31];
  EditBuffer : string[31];
  OkText, CancelText : string[8];
  Row0, Row1, Row2 : string[16];
  Rows : array[0..2] of integer;
  StatusLabel : TWinLabel;
  EditBox : TWinEdit;
  OkButton, CancelButton : TWinButton;
  Scrollbar : TWinScrollbar;
  Listbox : TWinListbox;
  DirectMarker : TWinRect;
  Items : array[0..5] of TWinItem;
  Window : TWinWindow;
  Track : TWinTrack;

procedure SetItem(N, Kind, Flags, Id, Control : integer);
begin
  Items[N].Kind := Kind; Items[N].Flags := Flags; Items[N].Id := Id;
  Items[N].Reserved := 0; Items[N].Control := Control;
  Items[N].UserData := 0
end;

procedure InitMouse;
begin
  asm
    ld c,0
    rst $30
  end
end;

procedure InitDialog;
begin
  TitleText := 'WIN320 Pascal dialog';
  StatusReady := 'Ready'; StatusChanged := 'Selection changed';
  EditBuffer := 'edit me'; OkText := 'OK'; CancelText := 'Cancel';
  Row0 := 'First row'; Row1 := 'Second row'; Row2 := 'Third row';
  Rows[0] := addr(Row0); Rows[1] := addr(Row1); Rows[2] := addr(Row2);

  StatusLabel.X := 12; StatusLabel.Y := 184; StatusLabel.Width := 232;
  StatusLabel.Height := 8; StatusLabel.Attr := $FF;
  StatusLabel.Flags := WinLabelCenter; StatusLabel.Text := addr(StatusReady);

  EditBox.X := 12; EditBox.Y := 32; EditBox.Width := 232;
  EditBox.Height := 18; EditBox.Attr := $FF; EditBox.Flags := WinEditFrame;
  EditBox.MaxLen := 31; EditBox.Len := length(EditBuffer);
  EditBox.Cursor := EditBox.Len; EditBox.Scroll := 0;
  EditBox.Buffer := addr(EditBuffer);

  OkButton.X := 40; OkButton.Y := 154; OkButton.Width := 72;
  OkButton.Height := 20; OkButton.Attr := $FF; OkButton.Flags := 0;
  OkButton.Text := addr(OkText);
  CancelButton.X := 132; CancelButton.Y := 154; CancelButton.Width := 72;
  CancelButton.Height := 20; CancelButton.Attr := $FF;
  CancelButton.Flags := 0; CancelButton.Text := addr(CancelText);

  Scrollbar.X := 232; Scrollbar.Y := 60; Scrollbar.Width := 12;
  Scrollbar.Height := 80; Scrollbar.Visible := 3; Scrollbar.Total := 3;
  Scrollbar.First := 0; Scrollbar.Flags := WinScrollbarArrows;
  Scrollbar.Reserved := 0; Scrollbar.ThumbPos := 0;
  Scrollbar.ThumbLen := 0; Scrollbar.LastPos := -1;

  Listbox.X := 12; Listbox.Y := 60; Listbox.Width := 220;
  Listbox.Height := 80; Listbox.ItemHeight := 12;
  Listbox.AttrNormal := $FF; Listbox.AttrCursor := $FF;
  Listbox.Flags := WinListboxFrame; Listbox.Total := 3;
  Listbox.First := 0; Listbox.Cursor := 0; Listbox.Items := addr(Rows);
  Listbox.ItemsPage := 0; Listbox.Reserved := 0;
  Listbox.Scrollbar := addr(Scrollbar);
  Listbox.LastFirst := -1; Listbox.LastCursor := -1;

  SetItem(0, WinTypeEdit, WinItemHit or WinItemFocusable, 10, addr(EditBox));
  SetItem(1, WinTypeListbox, WinItemHit or WinItemFocusable, 11, addr(Listbox));
  SetItem(2, WinTypeScrollbar, WinItemHit or WinItemRepeat, 12, addr(Scrollbar));
  SetItem(3, WinTypeButton, WinItemHit or WinItemFocusable, 1, addr(OkButton));
  SetItem(4, WinTypeButton, WinItemHit or WinItemFocusable, 2, addr(CancelButton));
  SetItem(5, WinTypeLabel, 0, $FF, addr(StatusLabel));

  Window.X := 32; Window.Y := 20; Window.Width := 256; Window.Height := 216;
  Window.Color := $FF; Window.Flags := WinWindowClose; Window.Count := 6;
  Window.Focus := 2; Window.Items := addr(Items);
  Window.Title := addr(TitleText); Window.TitleAttr := $FF;
  Window.LastFocus := $FF; Window.Reserved := 0;

  DirectMarker.X := 22; DirectMarker.Y := 222; DirectMarker.Width := 16;
  DirectMarker.Height := 8; DirectMarker.Color := 10; DirectMarker.Flags := 0;

  Track.Window := addr(Window); Track.Keys := 0; Track.KeyCount := 0;
  Track.Options := WinTrackAnyKey or WinTrackHalt or WinTrackShowCursor or
                   WinTrackTabFocus;
  Track.RepeatDelay := 12; Track.RepeatRate := 3
end;

begin
  H := LibLoad('WIN320.DLL', 3);
  if H < 0 then exit;
  InitDialog;
  StatusCode := WinSetTextFormatCall(H, WinTxtPascal);
  if StatusCode = 0 then
    StatusCode := WinDescriptorCall(H, WinScrollbarInit, addr(Scrollbar));
  if StatusCode = 0 then StatusCode := WinDrawCall(H, Window);
  if StatusCode = 0 then
    StatusCode := WinDescriptorCall(H, WinFillRect, addr(DirectMarker));
  if StatusCode = 0 then
  begin
    InitMouse;
    repeat
      StatusCode := WinPollCall(H, Track);
      if (StatusCode = 0) and (Track.EventCode <> WinEventNone) and
         (Track.EventCode <> WinEventClose) and (Track.Id <> 2) then
      begin
        StatusLabel.Text := addr(StatusChanged);
        Items[5].Flags := WinItemDirty;
        StatusCode := WinUpdateCall(H, Window, Drawn)
      end
    until (StatusCode <> 0) or (Track.Id = 2) or
          (Track.EventCode = WinEventClose)
  end;
  if LibFree(H) then;
end.
