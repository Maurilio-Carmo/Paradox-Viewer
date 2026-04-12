unit pxvExport;

{ SQLite3 export logic for ParadoxViewer.
  Extracted from pxvmain.pas to keep the form unit focused on UI concerns.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  DB,
  Dialogs,
  ParadoxDS,
  sqlite3conn, sqldb;

{ Exports the currently open ADataset to a SQLite3 file.
  - AAsCombinedFile = True  → appends the table into a single .sqlite named
                              after the source folder (e.g. C:\Data\clients\ → C:\Data\clients.sqlite)
  - AAsCombinedFile = False → creates an individual .sqlite file next to the .db file }
procedure ExportToSQLite3(
  ADataset        : TParadoxDataset;
  AConnection     : TSQLite3Connection;
  ATransaction    : TSQLTransaction;
  AAsCombinedFile : Boolean;
  ASilent         : Boolean = False
);

implementation

uses
  LazFileUtils;

procedure ExportToSQLite3(
  ADataset        : TParadoxDataset;
  AConnection     : TSQLite3Connection;
  ATransaction    : TSQLTransaction;
  AAsCombinedFile : Boolean;
  ASilent         : Boolean = False
);
var
  sql      : String;
  F        : TField;
  dt       : String;
  i        : Integer;
  s        : String;
  firstField: Boolean;
  query    : TSQLQuery;
  dbName   : String;
  tblName  : String;
begin
  AConnection.Connected := false;

  tblName := ChangeFileExt(ExtractFileName(ADataset.TableName), '');

  if AAsCombinedFile then begin
    dbName := ExtractFileDir(ADataset.TableName) + '.sqlite';
    AConnection.DatabaseName := dbName;
    AConnection.Open;
    ATransaction.Active := true;
    AConnection.ExecuteDirect('DROP TABLE IF EXISTS "' + tblName + '"');
  end else begin
    dbName := ChangeFileExt(ExtractFileName(ADataset.TableName), '.sqlite');
    if FileExists(dbName) then
      DeleteFile(dbName);
    AConnection.DatabaseName := dbName;
    AConnection.Open;
    ATransaction.Active := true;
  end;

  // Build CREATE TABLE statement with Paradox→SQLite3 type mapping
  sql := Format('CREATE TABLE "%s" (', [tblName]);
  firstField := True;
  for i := 0 to ADataset.FieldCount-1 do begin
    F := ADataset.Fields[i];
    if F.DataType in [ftSmallInt, ftInteger, ftWord, ftLargeInt] then
      dt := 'INTEGER'
    else if F.DataType in [ftFloat] then
      dt := 'REAL'
    else if F.DataType in [ftDateTime, ftDate, ftTime] then
      dt := 'TEXT'
    else if F.DataType = ftBoolean then
      dt := 'BOOL'
    else if F.DataType = ftMemo then
      dt := 'TEXT'
    else if F.DataType in [ftString, ftWideString] then begin
      if F.Size > 0 then
        dt := 'VARCHAR(' + IntToStr(F.Size) + ')'
      else
        dt := 'TEXT'
    end
    else if F.DataType in [ftBlob, ftGraphic, ftBytes, ftBCD] then
      dt := 'BLOB'
    else
      Continue;

    if not firstField then sql := sql + ',';
    firstField := False;
    sql := sql + Format('"%s" %s', [F.FieldName, dt]);

    // Single-field primary key
    if (i = 0) and (ADataset.PrimaryKeyFieldCount = 1) then
      sql := sql + ' PRIMARY KEY';
  end;

  // Composite primary key
  if ADataset.PrimaryKeyFieldCount > 1 then begin
    sql := sql + ', PRIMARY KEY ("' + ADataset.Fields[0].FieldName + '"';
    for i := 1 to ADataset.PrimaryKeyFieldCount-1 do
      sql := sql + ',"' + ADataset.Fields[i].FieldName + '"';
    sql := sql + ')';
  end;

  sql := sql + ');';
  AConnection.ExecuteDirect(sql);
  ATransaction.Commit;

  // Insert all records (skip if table is empty — structure was already created above)
  if (ADataset.FieldCount > 0) and not ADataset.IsEmpty then
  begin
    query := TSQLQuery.Create(nil);
    try
      query.Database    := AConnection;
      query.Transaction := ATransaction;

      sql := Format('INSERT INTO "%s" ("%s"', [tblName, ADataset.Fields[0].FieldName]);
      s   := 'VALUES (:P0';
      for i := 1 to ADataset.FieldCount-1 do begin
        sql := sql + ',"' + ADataset.Fields[i].FieldName + '"';
        s   := s   + ',:P' + IntToStr(i);
      end;
      query.SQL.Text := sql + ') ' + s + ');';

      ADataset.First;
      while not ADataset.EoF do begin
        for i := 0 to ADataset.FieldCount-1 do begin
          F := ADataset.Fields[i];
          if F.DataType in [ftMemo, ftString, ftWideString] then
            query.Params.ParamByName('P' + IntToStr(i)).AsString := F.AsString
          else if F.IsNull then
            query.Params.ParamByName('P' + IntToStr(i)).Clear
          else if F.DataType = ftDate then
            query.Params.ParamByName('P' + IntToStr(i)).AsString := FormatDateTime('yyyy-mm-dd', F.AsDateTime)
          else if F.DataType = ftTime then
            query.Params.ParamByName('P' + IntToStr(i)).AsString := FormatDateTime('hh:nn:ss', F.AsDateTime)
          else if F.DataType = ftDateTime then
            query.Params.ParamByName('P' + IntToStr(i)).AsString := FormatDateTime('yyyy-mm-dd hh:nn:ss', F.AsDateTime)
          else
            query.Params.ParamByName('P' + IntToStr(i)).Value := F.Value;
        end;
        query.ExecSQL;
        ADataset.Next;
      end;
      ATransaction.Commit;
    finally
      query.Free;
    end;
  end;

  if AAsCombinedFile then
    begin if not ASilent then ShowMessage('Tabela "' + tblName + '" adicionada com sucesso ao banco de dados SQLite3 "' + dbName + '"') end
  else
    begin if not ASilent then ShowMessage('Banco de dados SQLite3 "' + dbName + '" criado com sucesso.') end;
end;

end.
