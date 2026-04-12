{ TParadoxDataset — bookmark management }

function TParadoxDataset.BookmarkValid(ABookmark: TBookmark): Boolean;
begin
  Result := Assigned(ABookmark) and (Length(ABookmark) >= BookmarkSize);
end;

function TParadoxDataset.CompareBookmarks(Bookmark1, Bookmark2: TBookmark): Longint;
var
  idx1, idx2: LongWord;
begin
  idx1 := PLongWord(Bookmark1)^;
  idx2 := PLongWord(Bookmark2)^;
  if    idx1 > idx2 then Result := +1
  else if idx1 = idx2 then Result :=  0
  else                     Result := -1;
end;

procedure TParadoxDataset.InternalGotoBookmark(ABookmark: Pointer);
var
  bm: LongWord;
begin
  if (ABookmark <> nil) and (Length(TBookmark(ABookmark)) >= BookmarkSize) then
  begin
    bm := PLongWord(ABookmark)^;
    if bm <= GetRecordCount then
      SetRecNo(bm);
  end;
end;

procedure TParadoxDataset.GetBookmarkData(Buffer: PChar; Data: Pointer);
begin
  PLongWord(Data)^ := PRecInfo(Buffer + FHeader^.RecordSize)^.RecordNumber;
end;

function TParadoxDataset.GetBookmarkFlag(Buffer: PChar): TBookmarkFlag;
begin
  Result := PRecInfo(Buffer + FHeader^.RecordSize)^.BookmarkFlag;
end;

procedure TParadoxDataset.SetBookmarkData({%H-}Buffer: PChar; {%H-}Data: Pointer);
begin
  if Data <> nil then
    PRecInfo(Buffer + FHeader^.RecordSize)^.RecordNumber := PLongWord(Data)^
  else
    PRecInfo(Buffer + FHeader^.RecordSize)^.RecordNumber := 0;
end;

procedure TParadoxDataset.SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag);
begin
  PRecInfo(Buffer + FHeader^.RecordSize)^.BookmarkFlag := Value;
end;
