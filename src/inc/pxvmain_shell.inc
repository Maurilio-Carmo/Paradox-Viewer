{ TMainForm — shell tree/list view handlers and startup file navigation }

procedure TMainForm.FormActivate(Sender: TObject);
var
  fn: String;
begin
  if ParamCount > 0 then begin
    fn := ParamStr(1);
    if DirectoryExists(fn) then
      ShellTreeView.Path := fn
    else begin
      ShellTreeview.Path := ExtractFilepath(fn);
      OpenParadoxFile(fn);
    end;
  end;
end;

procedure TMainForm.ShellListViewSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  fn: String;
begin
  if Selected then
  begin
    fn := ShellListview.GetPathFromItem(ShellListview.Selected);
    ShellTreeview.MakeSelectionVisible;
    OpenParadoxFile(fn);
  end;
end;

procedure TMainForm.ShellTreeViewGetImageIndex(Sender: TObject; Node: TTreeNode);
begin
  Node.ImageIndex := 0;
end;

procedure TMainForm.ShellTreeViewGetSelectedIndex(Sender: TObject; Node: TTreeNode);
begin
  Node.SelectedIndex := 1;
end;

// Source: https://forum.lazarus.freepascal.org/index.php/topic,61347.msg462091.html
function TMainForm.ShellTreeViewSortCompare(Item1, Item2: TFileItem): integer;
begin
  // Folders first
  Result := ord(Item2.isFolder) - ord(Item1.isFolder);
  // Folders starting with underscore go to the very top
  if Result = 0 then
    if (pos('_', Item1.FileInfo.Name) = 1) or (pos('_', Item2.FileInfo.Name) = 1) then
      Result := AnsiCompareText(Item1.FileInfo.Name, Item2.FileInfo.Name)
    else
      Result := CompareText(Item1.FileInfo.Name, Item2.FileInfo.Name);
end;
