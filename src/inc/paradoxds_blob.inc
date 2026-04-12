{ TParadoxDataset — BLOB stream reading }

function TParadoxDataset.CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream;
var
  memStream : TMemoryStream;
  p         : PChar;
  header    : PAnsiChar;
  idx       : Byte;
  loc       : Integer;
  s         : String = '';
  blobInfo  : TPxBlobInfo;
  blobIndex : TPxBlobIndex;
begin
  memStream := TMemoryStream.Create;
  Result    := memStream;

  if Mode <> bmRead then
    exit;

  p      := ActiveBuffer + FPxFields[Field.FieldNo - 1].Offset;
  header := p + Field.Size - SizeOf(TPxBlobInfo);
  Move(header^, blobInfo{%H-}, SizeOf(blobInfo));

  if blobInfo.Length = 0 then
    exit;

  if Integer(blobInfo.Length) > Field.Size - SizeOf(TPxBlobInfo) then
  begin
    // BLOB data is stored in the companion .mb file
    if Assigned(FBlobStream) then begin
      idx := blobInfo.FileLoc and $FF;
      loc := blobInfo.FileLoc and $FFFFFF00;

      if idx = $FF then begin
        // Single blob block
        FBlobStream.Seek(loc + 9, soFromBeginning);
        if Field.DataType = ftMemo then begin
          SetLength(s, blobInfo.Length);
          FBlobStream.Read(s[1], blobInfo.Length);
          s := ConvertEncoding(s, GetInputEncoding, GetTargetEncoding);
          memStream.Write(s[1], Length(s));
        end else begin
          if Field.DataType = ftGraphic then begin
            memstream.WriteAnsiString('bmp');     // Paradox stores graphics as BMP
            FBlobStream.Position := FBlobStream.Position + 8;
          end;
          memStream.CopyFrom(FBlobStream, blobInfo.Length);
        end;
      end else begin
        // Suballocated block
        FBlobStream.Seek(loc + 12 + 5 * idx, soFromBeginning);
        FBlobStream.Read(blobIndex{%H-}, SizeOf(TPxBlobIndex));
        FBlobStream.Seek(loc + 16 * blobIndex.Offset, soFromBeginning);
        if Field.DataType = ftMemo then begin
          SetLength(s, blobInfo.Length);
          FBlobStream.Read(s[1], blobInfo.Length);
          s := ConvertEncoding(s, GetInputEncoding, GetTargetEncoding);
          memStream.Write(s[1], Length(s));
        end else
          memStream.CopyFrom(FBlobStream, blobInfo.Length);
      end;
    end;
  end else
  // BLOB data fits inline within the record
  if Field.DataType = ftMemo then begin
    SetLength(s, blobInfo.Length);
    Move(p^, s[1], blobInfo.Length);
    s := ConvertEncoding(s, GetInputEncoding, GetTargetEncoding);
    memStream.Write(s[1], Length(s));
  end else
    memStream.Write(p, blobInfo.Length);

  memStream.Position := 0;
end;
