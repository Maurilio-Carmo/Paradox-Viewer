unit pxvLog;

{ Simple append-to-file logger.
  Log file is written next to the executable: <exedir>/log.txt
}

{$mode objfpc}{$H+}

interface

{ Call once at the start of an export session to open a fresh log. }
procedure LogNewSession(const ALabel: String);

procedure Log(const AMsg: String);
procedure LogFmt(const AMsg: String; const AArgs: array of const);
procedure LogError(const AMsg: String; const AException: String = '');

function LogFilePath: String;

implementation

uses
  SysUtils, Forms;

function LogFilePath: String;
begin
  Result := ExtractFilePath(Application.ExeName) + 'pxView.log';
end;

procedure LogLine(const ALine: String);
var
  F: TextFile;
begin
  AssignFile(F, LogFilePath);
  {$I-}
  Append(F);
  if IOResult <> 0 then
  begin
    {$I+}
    Rewrite(F);
  end;
  {$I+}
  WriteLn(F, ALine);
  CloseFile(F);
end;

procedure LogNewSession(const ALabel: String);
var
  F: TextFile;
begin
  AssignFile(F, LogFilePath);
  Rewrite(F);
  WriteLn(F, '=== ' + ALabel + ' — ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ===');
  CloseFile(F);
end;

procedure Log(const AMsg: String);
begin
  LogLine(FormatDateTime('[hh:nn:ss] ', Now) + AMsg);
end;

procedure LogFmt(const AMsg: String; const AArgs: array of const);
begin
  Log(Format(AMsg, AArgs));
end;

procedure LogError(const AMsg: String; const AException: String = '');
begin
  if AException <> '' then
    Log('[ERRO] ' + AMsg + ': ' + AException)
  else
    Log('[ERRO] ' + AMsg);
end;

end.
