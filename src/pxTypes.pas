unit pxTypes;

{ Paradox file format — constants and record type definitions.
  Extracted from paradoxds.pas (Christian Ulrich, LGPL).
}

{$mode objfpc}{$H+}

interface

uses
  DB;

const
  { Paradox codes for field types }
  pxfAlpha        = $01;
  pxfDate         = $02;
  pxfShort        = $03;
  pxfLong         = $04;
  pxfCurrency     = $05;
  pxfNumber       = $06;
  pxfLogical      = $09;
  pxfMemoBLOb     = $0C;
  pxfBLOb         = $0D;
  pxfFmtMemoBLOb  = $0E;
  pxfOLE          = $0F;
  pxfGraphic      = $10;
  pxfTime         = $14;
  pxfTimestamp    = $15;
  pxfAutoInc      = $16;
  pxfBCD          = $17;
  pxfBytes        = $18;

type
  { Internal record info appended after each data record in the buffer }
  PRecInfo = ^TRecInfo;
  TRecInfo = packed record
    RecordNumber: PtrInt;
    BookmarkFlag: TBookmarkFlag;
  end;

  PLongWord = ^Longword;

  { Field information entry stored in the file header }
  PFldInfoRec = ^TFldInfoRec;
  TFldInfoRec = packed record
    fType: byte;
    fSize: byte;
  end;

  { Full Paradox file header — layout varies by file version (3.x vs 4.0+) }
  PPxHeader = ^TPxHeader;
  TPxHeader = packed record
    recordSize              : word;
    headerSize              : word;
    fileType                : byte;
    maxTableSize            : byte;
    numRecords              : longint;
    nextBlock               : word;
    fileBlocks              : word;
    firstBlock              : word;
    lastBlock               : word;
    unknown12x13            : word;
    modifiedFlags1          : byte;
    indexFieldNumber        : byte;
    primaryIndexWorkspace   : longint;   // not used; cast to pointer
    unknownPtr1A            : longint;   // not used; cast to pointer
    unknown1Ex20            : array[$001E..$0020] of byte;
    numFields               : smallint;
    primaryKeyFields        : smallint;
    encryption1             : longint;
    sortOrder               : byte;
    modifiedFlags2          : byte;
    unknown2Bx2C            : array[$002B..$002C] of byte;
    changeCount1            : byte;
    changeCount2            : byte;
    unknown2F               : byte;
    tableNamePtrPtr         : longint;   // cast to ^pchar
    fldInfo                 : longint;   // use FFieldInfoPtr instead
    writeProtected          : byte;
    fileVersionID           : byte;
    maxBlocks               : word;
    unknown3C               : byte;
    auxPasswords            : byte;
    unknown3Ex3F            : array[$003E..$003F] of byte;
    cryptInfoStartPtr       : longint;   // not used; cast to pointer
    cryptInfoEndPtr         : longint;   // not used; cast to pointer
    unknown48               : byte;
    autoIncVal              : longint;
    unknown4Dx4E            : array[$004D..$004E] of byte;
    indexUpdateRequired     : byte;
    unknown50x54            : array[$0050..$0054] of byte;
    refIntegrity            : byte;
    unknown56x57            : array[$0056..$0057] of byte;
    case smallint of
      3: (fieldInfo35       : array[1..255] of TFldInfoRec);
      4: (fileVerID2        : smallint;
          fileVerID3        : smallint;
          encryption2       : longint;
          fileUpdateTime    : longint;   { 4.0 only }
          hiFieldID         : word;
          hiFieldIDinfo     : word;
          sometimesNumFields: smallint;
          dosCodePage       : word;
          unknown6Cx6F      : array[$006C..$006F] of byte;
          changeCount4      : smallint;
          unknown72x77      : array[$0072..$0077] of byte;
          fieldInfo         : array[1..255] of TFldInfoRec);
    { NOTE: the fieldInfo arrays above are declared with 255 elements but
      their actual size is determined by numFields in the header. }
  end;

  { Data block header — each block holds one or more records }
  PDataBlock = ^TDataBlock;
  TDataBlock = packed record
    nextBlock   : word;
    prevBlock   : word;
    addDataSize : smallint;
    // actual record data follows; size = maxTableSize * $0400
  end;

  { Runtime field descriptor built from the header during InternalOpen }
  TPxField = record
    Info  : PFldInfoRec;
    Offset: LongInt;
    Name  : String;
  end;

  { 10-byte BLOB info block stored at the end of a BLOB field in the record }
  TPxBlobInfo = packed record
    FileLoc  : LongWord;
    Length   : LongWord;
    ModCount : Word;
  end;

  { Entry in the suballocated BLOB index block }
  TPxBlobIndex = packed record
    Offset  : Byte;
    Len16   : Byte;
    ModCount: Word;
    Len     : Byte;
  end;

implementation

end.
