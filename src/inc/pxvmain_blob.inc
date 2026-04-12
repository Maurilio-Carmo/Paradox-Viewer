{ TMainForm — BLOB field display (Memo and Graphic panels) }

procedure TMainForm.UpdateImage;
var
  GF: TField;
  i : Integer;
begin
  GF := nil;
  for i := 0 to ParadoxDataset.FieldCount-1 do
    if ParadoxDataset.Fields[i].Datatype = ftGraphic then
    begin
      GF := ParadoxDataset.Fields[i];
      break;
    end;

  if GF <> nil then
  begin
    DBImage.DataField     := GF.FieldName;
    DBImage.Show;
    BLOBPanel.Show;
    BLOBSplitter.Show;
    BLOBSplitter.Top      := 0;
    ImageSplitter.Visible := DBMemo.Visible;
    ImageSplitter.Left    := Width;
  end else
  begin
    DBImage.Hide;
    ImageSplitter.Hide;
    BLOBPanel.Visible    := DBMemo.Visible;
    BLOBSplitter.Visible := BLOBPanel.Visible;
  end;
end;

procedure TMainForm.UpdateMemo;
var
  MF: TField;
  i : Integer;
begin
  MF := nil;
  for i := 0 to ParadoxDataset.FieldCount-1 do
    if ParadoxDataset.Fields[i].DataType = ftMemo then
    begin
      MF := ParadoxDataset.Fields[i];
      break;
    end;

  if MF <> nil then
  begin
    DBMemo.DataField      := MF.FieldName;
    DBMemo.Show;
    BLOBPanel.Show;
    BLOBSplitter.Show;
    BLOBSplitter.Top      := 0;
    ImageSplitter.Visible := DBImage.Visible;
    ImageSplitter.Left    := Width;
  end else
  begin
    ImageSplitter.Hide;
    DBMemo.Hide;
    BLOBPanel.Visible    := DBImage.Visible;
    BLOBSplitter.Visible := BLOBPanel.Visible;
  end;
end;
