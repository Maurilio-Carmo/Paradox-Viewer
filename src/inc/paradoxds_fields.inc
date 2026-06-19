{ TParadoxDataset — field definitions and field data access }

procedure TParadoxDataset.InternalInitFieldDefs;
var
  i: integer;
  F: PFldInfoRec;
  FNamesStart: PChar;
  fname: String;
  offs: LongInt;
  origLen: Integer;
begin
  FieldDefs.Clear;
  F := FFieldInfoPtr;
  FNamesStart := Pointer(F);
  inc(FNamesStart, SizeOf(F^) * (FHeader^.numFields));      // jump over FieldDefs
  inc(FNamesStart, SizeOf(LongInt));                        // over TableName pointer
  inc(FNamesStart, SizeOf(LongInt) * (FHeader^.numFields)); // over FieldName pointers
  inc(FNamesStart, FTableNameLen);                          // over Tablename and padding

  SetLength(FPxFields, FHeader^.NumFields);
  offs := 0;

  for i := 1 to FHeader^.NumFields do
  begin
    origLen := StrLen(FNamesStart);   // advance by ORIGINAL byte length, not UTF-8 expanded length
    fname := ConvertEncoding(StrPas(FNamesStart), GetInputEncoding, GetTargetEncoding);
    case F^.fType of
      pxfAlpha:       FieldDefs.Add(fname, ftString,   F^.fSize);
      pxfDate:        FieldDefs.Add(fname, ftDate,     0);
      pxfShort:       FieldDefs.Add(fname, ftSmallInt, F^.fSize);
      pxfLong:        FieldDefs.Add(fname, ftInteger,  F^.fSize);
      pxfCurrency:    FieldDefs.Add(fname, ftFloat,    F^.fSize);   // ftCurrency expects a 64-bit BCD layout; ftFloat (Double) is used instead
      pxfNumber:      FieldDefs.Add(fname, ftFloat,    F^.fSize);
      pxfLogical:     FieldDefs.Add(fname, ftBoolean,  0);
      pxfMemoBLOb:    FieldDefs.Add(fname, ftMemo,     F^.fSize);
      pxfBLOb:        FieldDefs.Add(fname, ftBlob,     F^.fSize);
      pxfFmtMemoBLOb: FieldDefs.Add(fname, ftMemo,     F^.fSize);
      pxfOLE:         FieldDefs.Add(fname, ftBlob,     F^.fSize);
      pxfGraphic:     FieldDefs.Add(fname, ftGraphic,  F^.fSize);
      pxfTime:        FieldDefs.Add(fname, ftTime,     0);
      pxfTimestamp:   FieldDefs.Add(fname, ftDateTime, 0);
      pxfAutoInc:     FieldDefs.Add(fname, ftInteger,  F^.fSize);  // ftAutoInc crashes in Move(int,Buffer^); ftInteger is used instead
      pxfBCD:         FieldDefs.Add(fname, ftFloat,    F^.fSize);  // on-disk fSize is the decimal scale, not a byte length; see DecodePxBCD
      pxfBytes:       FieldDefs.Add(fname, ftBytes,    F^.fSize);
    end;
    with FPxFields[i-1] do begin
      Name   := fname;
      Info   := F;
      Offset := offs;
    end;
    if F^.fType = pxfBCD then
      offs := offs + 17   // BCD fields are always 17 bytes on disk, regardless of fSize
    else
      offs := offs + F^.fSize;
    inc(FNamesStart, origLen + 1);
    inc(F);
  end;
end;

// Layout reverse-engineered from pxlib's PX_get_data_bcd: byte 0 holds sign + scale,
// the remaining 16 bytes hold 32 packed BCD digits (complemented when negative).
function DecodePxBCD(Data: PByte; Scale: Integer; out Value: Double): Boolean;
var
  i        : Integer;
  size     : Integer;
  sign     : Byte;
  nibble   : Byte;
  lz       : Boolean;
  digits   : String;
  fs       : TFormatSettings;
begin
  Result := False;
  Value  := 0;
  if Data[0] = 0 then
    exit;

  digits := '';
  if (Data[0] and $80) <> 0 then
    sign := $00
  else begin
    digits := '-';
    sign := $0F;
  end;

  size := Data[0] and $3F;
  if size <> Scale then
    exit;

  lz := True;
  for i := 2 to 33 - size do begin
    if Odd(i) then
      nibble := Data[i div 2] and $0F
    else
      nibble := (Data[i div 2] shr 4) and $0F;
    if lz and ((nibble xor sign) <> 0) then
      lz := False;
    if not lz then
      digits := digits + Chr((nibble xor sign) + Ord('0'));
  end;
  if lz then
    digits := digits + '0';

  if size > 0 then begin
    digits := digits + '.';
    for i := 34 - size to 33 do begin
      if Odd(i) then
        nibble := Data[i div 2] and $0F
      else
        nibble := (Data[i div 2] shr 4) and $0F;
      digits := digits + Chr((nibble xor sign) + Ord('0'));
    end;
  end;

  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  Value := StrToFloat(digits, fs);
  Result := True;
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
      begin
        str := ConvertEncoding(StrPas(p), GetInputEncoding, GetTargetEncoding);
        if Buffer <> nil then
          StrLCopy(Buffer, PChar(str), Length(str));
        Result := true;
      end;
    pxfBytes:
      begin
        if Buffer <> nil then
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
      if si <> Low(SmallInt) then begin   // 0x8000 = NULL in Paradox
        if Assigned(Buffer) then
          Move(si, Buffer^, SizeOf(SmallInt));
        Result := True;
      end;
    pxfLong, pxfAutoInc:
      if int <> Low(LongInt) then begin   // 0x80000000 = NULL in Paradox
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
      if int <> Low(LongInt) then begin   // 0x80000000 = NULL in Paradox
        if Assigned(Buffer) then
          Move(int, Buffer^, SizeOf(LongInt));
        Result := True;
      end;
    pxfGraphic, pxfMemoBLOb, pxfBLOb, pxfFmtMemoBLOb, pxfOLE:
      Result := ActiveBuffer <> nil;
    pxfBCD:
      if DecodePxBCD(PByte(p), F^.fSize, d) then begin
        if Assigned(Buffer) then
          Move(d, Buffer^, SizeOf(d));
        Result := True;
      end;
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
