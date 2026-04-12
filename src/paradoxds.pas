unit paradoxds;

{ TParadoxDataSet
  Christian Ulrich christian@ullihome.de
  License: LGPL
}

{$mode objfpc}{$H+}

{$IF FPC_FullVersion >= 30200}
  {$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}
{$IFEND}

interface

uses
  Classes, SysUtils, DB, LConvEncoding, BufDataset_Parser,
  pxTypes;

type

  { TParadoxDataset }

  TParadoxDataset = class(TDataset)
  private
    FActive: Boolean;
    FStream: TStream;
    FBlobStream: TStream;
    FFileName: TFileName;
    FHeader: PPxHeader;
    FaRecord: LongInt;
    FaBlockstart: LongInt;
    FaBlock: PDataBlock;
    FaBlockIdx: word;
    FBlockReaded: Boolean;
    FFieldInfoPtr: PFldInfoRec;
    FTableNameLen: Integer;
    FInputEncoding: String;
    FTargetEncoding: String;
    FPxFields: Array of TPxField;
    FFilterBuffer: TRecordBuffer;
    FParser: TBufDatasetParser;
    function GetEncrypted: Boolean;
    function GetInputEncoding: String; inline;
    function GetPrimaryKeyFieldCount: Integer;
    function GetTargetEncoding: String; inline;
    function GetVersion: String;
    function IsStoredTargetEncoding: Boolean;
    function PxFilterRecord(Buffer: TRecordBuffer): Boolean;
    function PxGetActiveBuffer(var Buffer: TRecordBuffer): Boolean;
    procedure ReadBlock;
    procedure ReadNextBlockHeader;
    procedure ReadPrevBlockHeader;
    procedure SetFileName(const AValue: TFileName);
    procedure SetTargetEncoding(AValue: String);
  protected
    function  AllocRecordBuffer: PChar; override;
    procedure FreeRecordBuffer(var Buffer: PChar); override;
    procedure GetBookmarkData(Buffer: PChar; Data: Pointer); override;
    function  GetBookmarkFlag(Buffer: PChar): TBookmarkFlag; override;
    function  GetCanModify: Boolean; override;
    function  GetRecNo: Integer; override;
    function  GetRecord(Buffer: PChar; GetMode: TGetMode; {%H-}DoCheck: Boolean): TGetResult; override;
    function  GetRecordCount: Integer; override;
    function  GetRecordSize: Word; override;
    procedure InternalClose; override;
    procedure InternalEdit; override;
    procedure InternalFirst; override;
    procedure InternalGotoBookmark(ABookmark: Pointer); override;
    procedure InternalInitFieldDefs; override;
    procedure InternalInitRecord({%H-}Buffer: PChar); override;
    procedure InternalLast; override;
    procedure InternalOpen; override;
    procedure InternalPost; override;
    procedure InternalSetToRecord(Buffer: PChar); override;
    function  IsCursorOpen: Boolean; override;
    procedure ParseFilter(const AFilter: string);
    procedure SetBookmarkData({%H-}Buffer: PChar; {%H-}Data: Pointer); override;
    procedure SetBookmarkFlag(Buffer: PChar; Value: TBookmarkFlag); override;
    procedure SetFiltered(Value: Boolean); override;
    procedure SetFilterText(const Value: String); override;
    procedure SetRecNo(Value: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    function BookmarkValid(ABookmark: TBookmark): Boolean; override;
    function CompareBookmarks(Bookmark1, Bookmark2: TBookmark): Longint; override;
    function CreateBlobStream(Field: TField; Mode: TBlobStreamMode): TStream; override;
    function GetFieldData(Field: TField; Buffer: Pointer): Boolean; override;
    procedure SetFieldData({%H-}Field: TField; {%H-}Buffer: Pointer); override;
    property Encrypted: Boolean read GetEncrypted;
    property PrimaryKeyFieldCount: Integer read GetPrimaryKeyFieldCount;
  published
    property TableName: TFileName read FFileName write SetFileName;
    property TableLevel: String read GetVersion;
    property InputEncoding: String read FInputEncoding write FInputEncoding;
    property TargetEncoding: String read FTargetEncoding write SetTargetEncoding stored IsStoredTargetEncoding;
    property Active;
    property AutoCalcFields;
    property FieldDefs;
    property Filter;
    property Filtered;
    property BeforeOpen;
    property AfterOpen;
    property BeforeClose;
    property AfterClose;
    property BeforeScroll;
    property AfterScroll;
    property OnCalcFields;
    property OnFilterRecord;
  end;


implementation

{$I paradoxds_io.inc}
{$I paradoxds_fields.inc}
{$I paradoxds_nav.inc}
{$I paradoxds_bookmark.inc}
{$I paradoxds_blob.inc}
{$I paradoxds_filter.inc}

{ TParadoxDataset — general properties and lifecycle }

constructor TParadoxDataset.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHeader        := nil;
  FTargetEncoding := Uppercase(EncodingUTF8);
  FInputEncoding  := '';
  BookmarkSize    := SizeOf(LongWord);
end;

function TParadoxDataset.AllocRecordBuffer: PChar;
begin
  if Assigned(Fheader) then
    Result := AllocMem(GetRecordSize)
  else
    Result := nil;
end;

procedure TParadoxDataset.FreeRecordBuffer(var Buffer: PChar);
begin
  if Assigned(Buffer) then
    FreeMem(Buffer);
end;

function TParadoxDataset.GetCanModify: Boolean;
begin
  Result := False;
end;

function TParadoxDataset.GetEncrypted: Boolean;
begin
  if not Assigned(FHeader) then exit;
  if (FHeader^.fileVersionID <= 4) or not (FHeader^.fileType in [0,2,3,5]) then
    Result := (FHeader^.encryption1 <> 0)
  else
    Result := (FHeader^.encryption2 <> 0);
end;

function TParadoxDataset.GetInputEncoding: String;
begin
  if FInputEncoding = '' then
    Result := GetDefaultTextEncoding
  else
    Result := FInputEncoding;
end;

function TParadoxDataset.GetTargetEncoding: String;
begin
  if (FTargetEncoding = '') or SameText(FTargetEncoding, 'utf-8') then
    Result := EncodingUTF8
  else
    Result := FTargetEncoding;
end;

function TParadoxDataset.GetPrimaryKeyFieldCount: Integer;
begin
  if FHeader <> nil then
    Result := FHeader^.primaryKeyFields
  else
    Result := 0;
end;

function TParadoxDataset.IsCursorOpen: Boolean;
begin
  Result := FActive;
end;

function TParadoxDataset.IsStoredTargetEncoding: Boolean;
begin
  Result := not SameText(FTargetEncoding, EncodingUTF8);
end;

procedure TParadoxDataset.SetFileName(const AValue: TFileName);
begin
  if Active then
    Close;
  FFilename := AValue;
end;

procedure TParadoxDataset.SetTargetEncoding(AValue: String);
begin
  if AValue = FTargetEncoding then exit;
  FTargetEncoding := Uppercase(AValue);
end;


end.
