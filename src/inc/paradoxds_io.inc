{ TParadoxDataset — file I/O: open, close, block reading }

procedure TParadoxDataset.InternalOpen;
var
  hdrSize: Word;
  blobfn: String;
  cp: Word;
begin
  if FFileName = '' then
    DatabaseError('Tablename is not set');
  if not FileExists(FFileName) then
    DatabaseError(Format('Paradox file "%" does not exist.', [FFileName]));

  FStream := TFileStream.Create(FFilename, fmOpenRead or fmShareDenyNone);
  FStream.Position := 2;
  hdrSize := FStream.ReadWord;
  FHeader := AllocMem(hdrSize);
  FStream.Position := 0;
  if not FStream.Read(FHeader^, hdrSize) = hdrSize then
    DatabaseError('No valid Paradox file !');
  if not ((FHeader^.maxTableSize >= 1) and (FHeader^.maxTableSize <= 32)) then
    DatabaseError('No valid Paradox file !');

  if (FHeader^.fileVersionID >= 12) then
    FTableNameLen := 261
  else
    FTableNameLen := 79;

  if (FHeader^.fileVersionID <= 4) or not (FHeader^.FileType in [0,2,3,5]) then
    FFieldInfoPtr := @FHeader^.FieldInfo35
  else begin
    FFieldInfoPtr := @FHeader^.FieldInfo;
    cp := FHeader^.DosCodePage;
    if FInputEncoding = '' then
      FInputEncoding := 'CP' + IntToStr(cp);
  end;

  if Encrypted then
    exit;

  FBlobStream := nil;
  blobfn := ChangeFileExt(FFileName, '.mb');
  if FileExists(blobfn) then
    FBlobStream := TFileStream.Create(blobfn, fmOpenRead + fmShareDenyNone)
  else begin
    blobfn := ChangeFileExt(FFileName, '.MB');
    if FileExists(blobfn) then
      FBlobStream := TFileStream.Create(blobfn, fmOpenRead + fmShareDenyNone);
  end;

  FaBlock := AllocMem(FHeader^.maxTableSize * $0400);
  BookmarkSize := SizeOf(longword);
  InternalFirst;
  InternalInitFieldDefs;
  if DefaultFields then CreateFields;
  BindFields(True);
  FActive := True;

  try
    ParseFilter(Filter);
  except
    on E: Exception do
      Filter := '';
  end;
end;

procedure TParadoxDataset.InternalClose;
begin
  FInputEncoding := '';
  BindFields(FALSE);
  if DefaultFields then
    DestroyFields;
  FreeMem(FHeader);
  FreeMem(FaBlock);
  FreeAndNil(FParser);
  FreeAndNil(FBlobStream);
  FreeAndNil(FStream);
  FActive := False;
end;

procedure TParadoxDataset.ReadBlock;
var
  L: longint;
begin
  L := FaBlockIdx - 1;
  L := (L * FHeader^.maxTableSize * $0400) + FHeader^.headerSize;
  FStream.Position := L;
  FStream.Read(FaBlock^, FHeader^.maxTableSize * $0400);
  FBlockReaded := True;
end;

procedure TParadoxDataset.ReadNextBlockHeader;
var
  L: longint;
begin
  if FaBlock^.nextBlock = 0 then exit; // last block
  FaBlockStart := FaBlockStart + (FaBlock^.addDataSize div FHeader^.recordSize) + 1;
  FaRecord := FaBlockStart + 1;
  L := FaBlock^.nextBlock - 1;
  L := (L * FHeader^.maxTableSize * $0400) + FHeader^.headerSize;
  FaBlockIdx := FaBlock^.nextBlock;
  FBlockReaded := False;
  FStream.Position := L;
  FStream.Read(FaBlock^, 6); // read only block header
end;

procedure TParadoxDataset.ReadPrevBlockHeader;
var
  L: LongWord;
begin
  L := FaBlock^.prevBlock - 1;
  L := (L * FHeader^.maxTableSize * $0400) + FHeader^.headerSize;
  FaBlockIdx := FaBlock^.prevBlock;
  FBlockReaded := False;
  FStream.Position := L;
  FStream.Read(FaBlock^, 6); // read only block header
  L := ((FaBlock^.addDataSize div FHeader^.recordSize) + 1);
  FaBlockStart := FaBlockStart - L;
  FaRecord := FaBlockStart + 1;
end;
