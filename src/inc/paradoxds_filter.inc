{ TParadoxDataset — record filtering }

procedure TParadoxDataset.ParseFilter(const AFilter: string);
begin
  if Length(AFilter) > 0 then
  begin
    if (FParser = nil) and IsCursorOpen then
      FParser := TBufDatasetParser.Create(Self);
    if FParser <> nil then
    begin
      FParser.PartialMatch    := not (foNoPartialCompare in FilterOptions);
      FParser.CaseInsensitive := foCaseInsensitive in FilterOptions;
      FParser.ParseExpression(AFilter);
    end;
  end;
end;

function TParadoxDataset.PxFilterRecord(Buffer: TRecordBuffer): Boolean;
var
  SaveState: TDatasetState;
begin
  Result := True;
  if not Assigned(OnFilterRecord) and not Filtered then
    Exit;
  SaveState := SetTempState(dsFilter);
  try
    FFilterBuffer := Buffer;
    if Assigned(OnFilterRecord) then
      OnFilterRecord(Self, Result);
    if Result and Filtered and (Filter <> '') then
      Result := Boolean((FParser.ExtractFromBuffer(FFilterBuffer))^);
  finally
    RestoreState(SaveState);
  end;
end;

function TParadoxDataset.PxGetActiveBuffer(var Buffer: TRecordBuffer): Boolean;
begin
  case State of
    dsBrowse:
      if IsEmpty then Buffer := nil
      else            Buffer := ActiveBuffer;
    dsEdit,
    dsInsert: Buffer := ActiveBuffer;
    dsFilter: Buffer := FFilterBuffer;
  else
    Buffer := nil;
  end;
  Result := (Buffer <> nil);
end;

procedure TParadoxDataset.SetFiltered(Value: Boolean);
begin
  if Value <> Filtered then begin
    inherited;
    if IsCursorOpen then
      Refresh;
  end;
end;

procedure TParadoxDataset.SetFilterText(const Value: String);
begin
  if Value <> Filter then begin
    ParseFilter(Value);
    inherited;
    if IsCursorOpen and Filtered then
      Refresh;
  end;
end;
