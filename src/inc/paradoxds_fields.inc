{ TParadoxDataset — field definitions and field data access }

procedure TParadoxDataset.InternalInitFieldDefs;
var
  i: integer;
  F: PFldInfoRec;
  FNamesStart: PChar;
  fname: String;
  offs: LongInt;
begin
  FieldDefs.Clear;
  F := FFieldInfoPtr;                  { begin with the first field identifier }
  FNamesStart := Pointer(F);
  inc(FNamesStart, SizeOf(F^) * (FHeader^.numFields));      // jump over FieldDefs
  inc(FNamesStart, SizeOf(LongInt));                        // over TableName pointer
  inc(FNamesStart, SizeOf(LongInt) * (FHeader^.numFields)); // over FieldName pointers
  inc(FNamesStart, FTableNameLen);                          // over Tablename and padding

  SetLength(FPxFields, FHeader^.NumFields);
  offs := 0;

  for i := 1 to FHeader^.NumFields do
  begin
    fname := ConvertEncoding(StrPas(FNamesStart), GetInputEncoding, GetTargetEncoding);
    case F^.fType of
      pxfAlpha:       FieldDefs.Add(fname, ftString,   F^.fSize);
      pxfDate:        FieldDefs.Add(fname, ftDate,     0);
      pxfShort:       FieldDefs.Add(fname, ftSmallInt, F^.fSize);
      pxfLong:        FieldDefs.Add(fname, ftInteger,  F^.fSize);
      pxfCurrency:    FieldDefs.Add(fname, ftFloat,    F^.fSize);   // FIX: ftCurrency expects 64-bit BCD; use ftFloat (Double) instead
      pxfNumber:      FieldDefs.Add(fname, ftFloat,    F^.fSize);
      pxfLogical:     FieldDefs.Add(fname, ftBoolean,  0);
      pxfMemoBLOb:    FieldDefs.Add(fname, ftMemo,     F^.fSize);
      pxfBLOb:        FieldDefs.Add(fname, ftBlob,     F^.fSize);
      pxfFmtMemoBLOb: FieldDefs.Add(fname, ftMemo,     F^.fSize);
      pxfOLE:         FieldDefs.Add(fname, ftBlob,     F^.fSize);
      pxfGraphic:     FieldDefs.Add(fname, ftGraphic,  F^.fSize);
      pxfTime:        FieldDefs.Add(fname, ftTime,     0);
      pxfTimestamp:   FieldDefs.Add(fname, ftDateTime, 0);
      pxfAutoInc:     FieldDefs.Add(fname, ftInteger,  F^.fSize);  // FIX: ftAutoInc causes crash in Move(int,Buffer^); use ftInteger
      pxfBCD:         FieldDefs.Add(fname, ftBCD,      F^.fSize);
      pxfBytes:       FieldDefs.Add(fname, ftBytes,    F^.fSize);
    end;
    with FPxFields[i-1] do begin
      Name   := fname;
      Info   := F;
      Offset := offs;
    end;
    offs := offs + F^.fSize;
    inc(FNamesStart, Length(fname) + 1);
    inc(F);
  end;
end;

function TParadoxDataset.GetFieldData(Field: TField; Buffer: Pointer): Boolean;
var
  b   : WordBool;
  F   : PFldInfoRec;
  i   : Integer;
  size: Integer;
  p   : PChar;
  s   : array[0..7] of byte;
  si  : SmallInt absolute s;
  int : LongInt  absolute s;
  d   : Double   absolute s;
  str : String;
  buf : TRecordBuffer = nil;
begin
  Result := False;
  if (RecordCount = 0) then
    exit;

  PXGetActiveBuffer(Buf);
  p    := buf + FPxFields[Field.FieldNo - 1].Offset;
  F    := FPxFields[Field.FieldNo - 1].Info;
  size := F^.fSize;

  // Numeric fields are stored big-endian → swap bytes
  if F^.fType in [pxfDate..pxfNumber, pxfTime..pxfAutoInc] then begin
    for i := 0 to pred(size) do
      s[pred(size-i)] := byte(p[i]);
    s[pred(size)] := s[pred(size)] xor $80;
  end;

  case F^.fType of
    pxfAlpha:
      if (Buffer <> nil) then begin
        str := ConvertEncoding(StrPas(p), GetInputEncoding, GetTargetEncoding);
        StrLCopy(Buffer, PChar(str), Length(str));
        Result := true;
      end;
    pxfBytes:
      if Buffer <> nil then begin
        StrLCopy(Buffer, PAnsiChar(p), F^.fSize);
        Result := true;
      end;
    pxfDate:
      if int <> $FFFFFFFF80000000 then begin     // Dec/12/9999 → probably NULL
        if Assigned(Buffer) then
          Move(int, Buffer^, SizeOf(LongInt));
        Result := True;
      end;
    pxfShort:
      begin
        if Assigned(Buffer) then
          Move(si, Buffer^, SizeOf(SmallInt));
        Result := True;
      end;
    pxfLong, pxfAutoInc:
      begin
        if Assigned(Buffer) then
          Move(int, Buffer^, SizeOf(LongInt));
        Result := True;
      end;
    pxfCurrency:
      begin
        if Assigned(Buffer) then
          Move(d, Buffer^, SizeOf(d));
        Result := True;
      end;
    pxfNumber, pxfTimeStamp:
      begin
        if Assigned(Buffer) then
          Move(d, Buffer^, SizeOf(d));
        Result := True;
      end;
    pxfLogical:
      begin
        b := not ((p^ = #$80) or (p^ = #0));
        if Assigned(Buffer) then
          Move(b, Buffer^, SizeOf(b));
        Result := true;  // must be outside "if Assigned" — otherwise checkboxes render wrong
      end;
    pxfTime:
      begin
        if Assigned(Buffer) then
          Move(int, Buffer^, SizeOf(LongInt));
        Result := True;
      end;
    pxfGraphic:
      Result := ActiveBuffer <> nil;
  end;
end;

procedure TParadoxDataset.SetFieldData({%H-}Field: TField; {%H-}Buffer: Pointer);
begin
  // read-only dataset — no-op
end;

function TParadoxDataset.GetVersion: String;
begin
  Result := '';
  if not FActive then exit;
  if not Assigned(FHeader) then exit;
  case FHeader^.fileVersionID of
    $3     : Result := '3.0';
    $4     : Result := '3.5';
    $5..$9 : Result := '4.0';
    $a..$b : Result := '5.0';
    $c     : Result := '7.0';
  end;
end;
