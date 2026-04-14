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
  LazFileUtils, TypInfo,
  pxvLog;

{ Returns the SQLite column type for a field, or '' if the type cannot be exported. }
function FieldSQLType(AField: TField): String;
begin
  if AField.DataType in [ftSmallInt, ftInteger, ftWord, ftLargeInt] then
    Result := 'INTEGER'
  else if AField.DataType = ftFloat then
    Result := 'REAL'
  else if AField.DataType in [ftDateTime, ftDate, ftTime] then
    Result := 'TEXT'
  else if AField.DataType = ftBoolean then
    Result := 'BOOL'
  else if AField.DataType = ftMemo then
    Result := 'TEXT'
  else if AField.DataType in [ftString, ftWideString] then
  begin
    if AField.Size > 0 then
      Result := 'VARCHAR(' + IntToStr(AField.Size) + ')'
    else
      Result := 'TEXT';
  end
  else if AField.DataType in [ftBlob, ftGraphic, ftBytes, ftBCD] then
    Result := 'BLOB'
  else
    Result := '';
end;

procedure ExportToSQLite3(
  ADataset        : TParadoxDataset;
  AConnection     : TSQLite3Connection;
  ATransaction    : TSQLTransaction;
  AAsCombinedFile : Boolean;
  ASilent         : Boolean = False
);
var
  sql        : String;
  F          : TField;
  dt         : String;
  i, p       : Integer;
  s          : String;
  firstField : Boolean;
  query      : TSQLQuery;
  dbName     : String;
  tblName    : String;
  // Indices of fields actually exported (skipping unsupported types)
  inclIdx    : array of Integer;
  inclCount  : Integer;
begin
  AConnection.Connected := False;

  tblName := ChangeFileExt(ExtractFileName(ADataset.TableName), '');

  if AAsCombinedFile then
  begin
    dbName := ExtractFileDir(ADataset.TableName) + '.sqlite';
    AConnection.DatabaseName := dbName;
    AConnection.Open;
    ATransaction.Active := True;
    AConnection.ExecuteDirect('DROP TABLE IF EXISTS "' + tblName + '"');
  end
  else
  begin
    dbName := ChangeFileExt(ADataset.TableName, '.sqlite');
    if FileExists(dbName) then
      DeleteFile(dbName);
    AConnection.DatabaseName := dbName;
    AConnection.Open;
    ATransaction.Active := True;
  end;

  // Collect exportable fields and build CREATE TABLE
  SetLength(inclIdx, ADataset.FieldCount);
  inclCount  := 0;
  sql        := Format('CREATE TABLE "%s" (', [tblName]);
  firstField := True;

  for i := 0 to ADataset.FieldCount - 1 do
  begin
    F  := ADataset.Fields[i];
    dt := FieldSQLType(F);

    if dt = '' then
    begin
      LogFmt('  Campo ignorado: "%s" (tipo %s não suportado para SQLite)',
        [F.FieldName, GetEnumName(TypeInfo(TFieldType), Integer(F.DataType))]);
      Continue;
    end;

    inclIdx[inclCount] := i;
    Inc(inclCount);

    if not firstField then sql := sql + ',';
    firstField := False;
    sql := sql + Format('"%s" %s', [F.FieldName, dt]);

    // Single-field primary key
    if (inclCount = 1) and (ADataset.PrimaryKeyFieldCount = 1) then
      sql := sql + ' PRIMARY KEY';
  end;

  SetLength(inclIdx, inclCount);

  // Composite primary key
  if ADataset.PrimaryKeyFieldCount > 1 then
  begin
    sql := sql + ', PRIMARY KEY ("' + ADataset.Fields[0].FieldName + '"';
    for i := 1 to ADataset.PrimaryKeyFieldCount - 1 do
      sql := sql + ',"' + ADataset.Fields[i].FieldName + '"';
    sql := sql + ')';
  end;

  sql := sql + ');';
  LogFmt('  CREATE TABLE com %d campo(s) (de %d no arquivo)', [inclCount, ADataset.FieldCount]);
  AConnection.ExecuteDirect(sql);
  ATransaction.Commit;

  // Insert records using only the exportable fields
  if (inclCount > 0) and not ADataset.IsEmpty then
  begin
    query := TSQLQuery.Create(nil);
    try
      query.Database    := AConnection;
      query.Transaction := ATransaction;

      // Build INSERT using only inclIdx fields; parameters are :P0..:Pn (sequential)
      sql := Format('INSERT INTO "%s" ("%s"', [tblName, ADataset.Fields[inclIdx[0]].FieldName]);
      s   := 'VALUES (:P0';
      for p := 1 to inclCount - 1 do
      begin
        sql := sql + ',"' + ADataset.Fields[inclIdx[p]].FieldName + '"';
        s   := s   + ',:P' + IntToStr(p);
      end;
      query.SQL.Text := sql + ') ' + s + ');';

      ADataset.First;
      while not ADataset.EoF do
      begin
        for p := 0 to inclCount - 1 do
        begin
          F := ADataset.Fields[inclIdx[p]];
          if F.IsNull then
            query.Params.ParamByName('P' + IntToStr(p)).Clear
          else if F.DataType in [ftMemo, ftString, ftWideString] then
            query.Params.ParamByName('P' + IntToStr(p)).AsString := F.AsString
          else if F.DataType = ftDate then
            query.Params.ParamByName('P' + IntToStr(p)).AsString :=
              FormatDateTime('yyyy-mm-dd', F.AsDateTime)
          else if F.DataType = ftTime then
            query.Params.ParamByName('P' + IntToStr(p)).AsString :=
              FormatDateTime('hh:nn:ss', F.AsDateTime)
          else if F.DataType = ftDateTime then
            query.Params.ParamByName('P' + IntToStr(p)).AsString :=
              FormatDateTime('yyyy-mm-dd hh:nn:ss', F.AsDateTime)
          else
            query.Params.ParamByName('P' + IntToStr(p)).Value := F.Value;
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
  begin
    if not ASilent then
      ShowMessage('Tabela "' + tblName + '" adicionada com sucesso ao banco de dados SQLite3 "' + dbName + '"')
  end
  else
  begin
    if not ASilent then
      ShowMessage('Banco de dados SQLite3 "' + dbName + '" criado com sucesso.')
  end;
end;

end.
