{ TMainForm — Fields tab grid update }

procedure TMainForm.UpdateGrid;
var
  i, j: Integer;
begin
  Grid.RowCount := ParadoxDataset.FieldCount + 1;
  j := 1;
  for i := 0 to ParadoxDataset.FieldCount-1 do begin
    Grid.Cells[0, j] := IntToStr(i);
    Grid.Cells[1, j] := ParadoxDataset.Fields[i].FieldName;
    Grid.Cells[2, j] := GetEnumName(TypeInfo(TFieldType), integer(ParadoxDataset.Fields[i].DataType));
    Grid.Cells[3, j] := IntToStr(ParadoxDataset.Fields[i].Size);
    Grid.Cells[4, j] := BoolToStr(ParadoxDataset.Fields[i].Required, true);
    inc(j);
  end;
end;
