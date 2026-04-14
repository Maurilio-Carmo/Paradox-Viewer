unit pxvMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil,
  LCLVersion, LConvEncoding,
  Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, ComCtrls, ShellCtrls, Grids,
  DB, DBGrids, DBCtrls, ParadoxDS, sqlite3conn, sqldb, sqlite3dyn,
  pxvExport, pxvLog;

type

  { TMainForm }

  TMainForm = class(TForm)
    ApplicationProperties: TApplicationProperties;
    btnExportSQLite3: TButton;
    cbAllTables: TCheckBox;
    cbAutoSizeCols: TCheckBox;
    cmbInputEncoding: TComboBox;
    DataSource: TDataSource;
    DBGrid: TDBGrid;
    DBImage: TDBImage;
    DBMemo: TDBMemo;
    DBNavigator1: TDBNavigator;
    ImageList: TImageList;
    Label1: TLabel;
    PageControl: TPageControl;
    Panel1: TPanel;
    DataPanel: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    BLOBPanel: TPanel;
    rbIndividualFiles: TRadioButton;
    rbCombinedFile: TRadioButton;
    ShellListView: TShellListView;
    ShellTreeView: TShellTreeView;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    BLOBSplitter: TSplitter;
    pgData: TTabSheet;
    pgFields: TTabSheet;
    Grid: TStringGrid;
    ImageSplitter: TSplitter;
    SQLite3Connection: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction: TSQLTransaction;
    procedure btnExportSQLite3Click(Sender: TObject);
    procedure cbAutoSizeColsChange(Sender: TObject);
    procedure cmbInputEncodingChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ParadoxDatasetAfterScroll(DataSet: TDataSet);
    procedure ShellListViewSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure ShellTreeViewGetImageIndex(Sender: TObject; Node: TTreeNode);
    procedure ShellTreeViewGetSelectedIndex(Sender: TObject; Node: TTreeNode);
    function ShellTreeViewSortCompare(Item1, Item2: TFileItem): integer;
  private
    ParadoxDataset: TParadoxDataset;
    function GetInputEncoding: String;
    procedure OpenParadoxFile(const AFileName: string);
    procedure UpdateGrid;
    procedure UpdateImage;
    procedure UpdateMemo;
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  TypInfo, LazFileUtils;

{$I pxvmain_shell.inc}
{$I pxvmain_blob.inc}
{$I pxvmain_grid.inc}

const
  PROGRAM_NAME = 'PARADOX Viewer';

{ TMainForm — core form logic }

procedure TMainForm.btnExportSQLite3Click(Sender: TObject);
var
  Files      : TStringList;
  SavedName  : String;
  i          : Integer;
  Combined   : Boolean;
  Exported   : Integer;
  Errors     : Integer;
begin
  Combined := rbCombinedFile.Checked;

  if cbAllTables.Checked and (ParadoxDataset.TableName <> '') then
  begin
    Files    := FindAllFiles(ExtractFileDir(ParadoxDataset.TableName), '*.db', False);
    Exported := 0;
    Errors   := 0;
    LogNewSession('Exportação SQLite3 — ' + IntToStr(Files.Count) + ' arquivo(s) encontrado(s)');
    try
      SavedName := ParadoxDataset.TableName;
      for i := 0 to Files.Count - 1 do
      begin
        LogFmt('Tabela [%d/%d]: %s', [i + 1, Files.Count, ExtractFileName(Files[i])]);
        try
          ParadoxDataset.Close;
          DBMemo.DataField  := '';   // evita "Field not found" se tabela anterior tinha campo memo/imagem
          DBImage.DataField := '';
          ParadoxDataset.TableName     := Files[i];
          ParadoxDataset.InputEncoding := GetInputEncoding;
          ParadoxDataset.Open;
          ExportToSQLite3(ParadoxDataset, SQLite3Connection, SQLTransaction, Combined, {ASilent=}True);
          Log('  OK');
          Inc(Exported);
        except
          on E: Exception do
          begin
            LogError('  Ignorada', E.Message);
            Inc(Errors);
          end;
        end;
      end;
      LogFmt('Resultado: %d exportada(s), %d ignorada(s)', [Exported, Errors]);
      if Errors = 0 then
        ShowMessage('Exportação concluída: ' + IntToStr(Exported) + ' tabela(s) exportada(s).')
      else
        ShowMessage('Exportação concluída: ' + IntToStr(Exported) + ' tabela(s) exportada(s), ' +
                    IntToStr(Errors) + ' ignorada(s) por erro.' + LineEnding +
                    'Veja o log em: ' + LogFilePath);
      OpenParadoxFile(SavedName);
    finally
      Files.Free;
    end;
  end
  else
  begin
    ExportToSQLite3(ParadoxDataset, SQLite3Connection, SQLTransaction, Combined);
  end;
end;

procedure TMainForm.cbAutoSizeColsChange(Sender: TObject);
begin
  if cbAutoSizeCols.Checked then
    DBGrid.Options := DBGrid.Options + [dgAutoSizeColumns]
  else
    DBGrid.Options := DBGrid.Options - [dgAutoSizeColumns];
  if ParadoxDataset.Active then
    OpenParadoxFile(ParadoxDataset.TableName);
end;

procedure TMainForm.cmbInputEncodingChange(Sender: TObject);
begin
  if ParadoxDataset.TableName <> '' then
    OpenParadoxFile(ParadoxDataset.TableName);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := PROGRAM_NAME;
  ShellListview.Mask := '*.db';

  // Compatibility with Linux/Mac
  {$IFDEF MSWINDOWS}
  {$IF LCL_FullVersion >= 2010000}
  ShellTreeView.Images     := nil;
  ShellListView.SmallImages := nil;
  {$IFEND}
  {$ENDIF}

  // Properties set at runtime for compatibility with Laz 2.0.8
  {$IF LCL_FullVersion >= 4000000}
  ShellTreeView.FilesortType        := fstCustom;
  ShellTreeView.OnSortCompare       := @ShellTreeViewSortCompare;
  DBMemo.WantReturns                := false;
  ImageList.Scaled                  := true;
  SQLite3Connection.AlwaysUseBigInt := false;
  {$ENDIF}

  // Create TParadoxDataset at runtime — avoids installing the CCR package
  ParadoxDataset             := TParadoxDataset.Create(self);
  ParadoxDataset.AfterScroll := @ParadoxDatasetAfterScroll;
  DataSource.Dataset         := ParadoxDataset;
end;

function TMainForm.GetInputEncoding: String;
var
  sa: TStringArray;
begin
  if (cmbInputEncoding.ItemIndex in [0, -1]) then
    Result := ''
  else begin
    sa := cmbInputEncoding.Items[cmbInputEncoding.ItemIndex].Split(' ');
    Result := Lowercase(StringReplace(sa[0], '-', '', [rfReplaceAll]));
  end;
end;

procedure TMainForm.OpenParadoxFile(const AFileName: String);
begin
  ParadoxDataset.Close;
  DBMemo.DataField  := '';
  DBImage.DataField := '';

  ParadoxDataset.TableName     := AFileName;
  ParadoxDataset.InputEncoding := GetInputEncoding;
  ParadoxDataset.Open;
  UpdateMemo;
  UpdateImage;
  UpdateGrid;

  Caption := Format('%s - %s', [PROGRAM_NAME, ExtractFileName(AFilename)]);
end;

procedure TMainForm.ParadoxDatasetAfterScroll(DataSet: TDataSet);
begin
  UpdateMemo;
  UpdateImage;
end;

end.
