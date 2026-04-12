{ TParadoxDataset — record navigation }

procedure TParadoxDataset.InternalFirst;
begin
  FaBlockIdx   := FHeader^.firstBlock;
  FaBlockstart := 0;
  FaRecord     := 0;
  ReadBlock;
end;

procedure TParadoxDataset.InternalLast;
begin
  while FaBlockIdx <> FHeader^.lastBlock do
    ReadNextBlockHeader;
  inc(FaRecord, (FaBlock^.addDataSize div FHeader^.RecordSize) + 1);
end;

procedure TParadoxDataset.InternalEdit;
begin
  // read-only dataset — no-op
end;

procedure TParadoxDataset.InternalInitRecord({%H-}Buffer: PChar);
begin
  // no initialization needed for read-only records
end;

procedure TParadoxDataset.InternalPost;
begin
  // read-only dataset — no-op
end;

function TParadoxDataset.GetRecord(Buffer: PChar; GetMode: TGetMode; {%H-}DoCheck: Boolean): TGetResult;
var
  L       : Longword;
  accepted: Boolean;
begin
  Result   := grOK;
  accepted := false;

  repeat
    case GetMode of
      gmNext:
        begin
          inc(FaRecord);
          if (FaBlockIdx = FHeader^.lastBlock) and
             (FaRecord > FaBlockStart + FaBlock^.addDataSize div FHeader^.recordSize + 1)
          then
            Result := grEOF
          else
          if FaRecord > FaBlockStart + 1 + (FaBlock^.addDataSize div FHeader^.recordSize) then
            ReadNextBlockHeader;
        end;
      gmPrior:
        begin
          dec(FaRecord);
          if (FaBlockIdx = FHeader^.firstBlock) and (FaRecord < 1) then
            Result := grBOF
          else
          if FaRecord <= FaBlockStart then
          begin
            ReadPrevBlockHeader;
            FaRecord := FaBlockStart + (FaBlock^.addDataSize div FHeader^.recordSize) + 1;
          end;
        end;
      gmCurrent:
        if (FaRecord > RecordCount) or (FaRecord < 1) then
          result := grError;
    end;

    if Result = grOK then begin
      if not FBlockReaded then
        ReadBlock;
      L := ((faRecord - (FaBlockstart + 1)) * FHeader^.recordSize) + 6;
      if (faRecord - (FaBlockstart + 1)) >= 0 then
        Move(PChar(FaBlock)[L], Buffer[0], FHeader^.recordSize)
      else
        Result := grError;
      with PRecInfo(Buffer + FHeader^.recordSize)^ do begin
        BookmarkFlag := bfCurrent;
        RecordNumber := FaRecord;
      end;

      if Filtered then
        accepted := PXFilterRecord(Buffer)
      else
        accepted := True;
      if (GetMode = gmCurrent) and not accepted then
        Result := grError;
    end;
  until (Result <> grOK) or Accepted;
end;

function TParadoxDataset.GetRecordCount: Integer;
begin
  if Assigned(FHeader) then
    Result := FHeader^.numRecords
  else
    Result := 0;
end;

function TParadoxDataset.GetRecordSize: Word;
begin
  Result := FHeader^.recordSize + SizeOf(TRecInfo);
end;

function TParadoxDataset.GetRecNo: Integer;
begin
  Result := -1;
  if Assigned(ActiveBuffer) then
    Result := PRecInfo(ActiveBuffer + FHeader^.recordSize)^.RecordNumber;
end;

procedure TParadoxDataset.SetRecNo(Value: Integer);
begin
  if Value < FaRecord then
  begin
    while (Value <= FaBlockstart) do
      ReadPrevBlockHeader;
    FaRecord := Value;
  end else
  begin
    while (Value > FaBlockstart + ((FaBlock^.addDataSize div FHeader^.recordSize) + 1)) do
      ReadNextBlockHeader;
    FaRecord := Value;
  end;
end;

procedure TParadoxDataset.InternalSetToRecord(Buffer: PChar);
var
  bm: LongWord;
begin
  if (State <> dsInsert) then begin
    bm := PRecInfo(Buffer + FHeader^.RecordSize)^.RecordNumber;
    InternalGotoBookmark(@bm);
  end;
end;
