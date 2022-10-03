unit uIntelHex;

interface

uses
  System.SysUtils, System.Classes, Windows;

const
  HEX_ERROR_MARKER = 1;
  HEX_ERROR_ADDRESS = 2;
  HEX_ERROR_REC_TYPE = 3;
  HEX_ERROR_SECTION_SIZE = 4;
  HEX_ERROR_DATA = 5;
  HEX_ERROR_CHECK_SUM = 6;
  HEX_ERROR_SECTION_COUNT = 7;

type
  EHex2Bin = class( Exception )
  private
    FCode : integer;
  public
    constructor Create( ACode : integer );
    property Code : integer read FCode write FCode;
  end;

type
  TXxx2Bin = procedure( TxtStringList : TStringList; BinStream : TMemoryStream;
    var StartAddress : int64 );

procedure Txt2Bin( TxtStringList : TStringList; BinStream : TMemoryStream;
  var StartAddress : int64 );
procedure Hex2Bin( HexStringList : TStringList; BinStream : TMemoryStream;
  var StartAddress : int64 );
procedure Bin2Hex( BinStream : TMemoryStream; HexStringList : TStringList;
  StartAddress : int64 );

implementation

const
  ONE_RECORD_SIZE = 16;
  ONE_SECTION_SIZE = 64 * 1024;
  MAX_SECTION_COUNT = 16;
  MAX_BUFFER_SIZE = MAX_SECTION_COUNT * ONE_SECTION_SIZE;

type
  // Different possible records for Intel .hex files.
  TRecType = ( rtData = 0, // data
    rtEof = 1, // End Of File
    rtEsa = 2, // Extended Segment Address
    rtSsa = 3, // Start Segment Address
    rtEla = 4, // Extended Linear Address
    rtSla = 5 ); // Start Linear Address

  THexRec = record
    Marker : BYTE; // : Valid, other Invalid
    DataSize : BYTE;
    Addr : Word;
    RecType : TRecType;
    DataBuf : array [ 0 .. 255 ] of BYTE;
    CheckSum : BYTE;
  end;

  THexSection = record
    LinearAddress : DWORD;
    UsedOffset : DWORD;
    UnusedOffset : DWORD;
    DataBuffer : array [ 0 .. ONE_SECTION_SIZE - 1 ] of BYTE;
  end;

var
  HexSections : array [ 0 .. MAX_SECTION_COUNT - 1 ] of THexSection;
  Hex2BinErrorMessage : array [ HEX_ERROR_MARKER .. HEX_ERROR_SECTION_COUNT ]
    of string; // error messages

constructor EHex2Bin.Create( ACode : integer );
begin
  FCode := ACode;
  inherited Create( Hex2BinErrorMessage[ ACode ] );
end;

// : 10 0013 00 AC12AD13AE10AF1112002F8E0E8F0F22 44
// \_________________________________________/ CS
//
// The checksum is calculated by summing the values of all hexadecimal digit
// pairs in the record modulo 256  and taking the two's complement
//
function HexCalcCheckSum( HexRec : THexRec ) : BYTE;
var
  i : integer;
begin
  Result := HexRec.DataSize + HexRec.Addr + ( HexRec.Addr shr 8 ) +
    BYTE( HexRec.RecType );
  for i := 0 to HexRec.DataSize - 1 do
    Inc( Result, HexRec.DataBuf[ i ] );

  // Result := -Integer(Result);
  Result := ( not Result ) + 1;
end;

function HexRec2Str( HexRec : THexRec ) : string;
var
  i : integer;
begin
  Result := ':' + IntToHex( HexRec.DataSize, 2 ) + IntToHex( HexRec.Addr, 4 ) +
    IntToHex( Ord( HexRec.RecType ), 2 );
  for i := 0 to HexRec.DataSize - 1 do
    Result := Result + IntToHex( HexRec.DataBuf[ i ], 2 );
  Result := Result + IntToHex( HexCalcCheckSum( HexRec ), 2 );
end;

// 1 23 4567 89 ABCDEF.............................
// : 10 0013 00 AC12AD13AE10AF1112002F8E0E8F0F22 44
//
function HexStr2Rec( HexStr : string ) : THexRec;
var
  i : integer;
begin
  Result.Marker := Ord( HexStr[ 1 ] );
  if Result.Marker <> Ord( ':' ) then
    raise EHex2Bin.Create( HEX_ERROR_MARKER );

  try
    Result.DataSize := StrToInt( '$' + Copy( HexStr, 2, 2 ) );
    Result.Addr := StrToInt( '$' + Copy( HexStr, 4, 4 ) );
    Result.RecType := TRecType( StrToInt( '$' + Copy( HexStr, 8, 2 ) ) );
    for i := 0 to Result.DataSize - 1 do
      Result.DataBuf[ i ] := StrToInt( '$' + Copy( HexStr, 10 + i * 2, 2 ) );

    Result.CheckSum :=
      StrToInt( '$' + Copy( HexStr, 10 + Result.DataSize * 2, 2 ) );
  except
    raise EHex2Bin.Create( HEX_ERROR_DATA );
  end;

  if Result.CheckSum <> HexCalcCheckSum( Result ) then
    raise EHex2Bin.Create( HEX_ERROR_CHECK_SUM );
end;

procedure Bin2Hex( BinStream : TMemoryStream; HexStringList : TStringList;
  StartAddress : int64 );
var
  HexRec : THexRec;
  BufferSize : DWORD;
  SectionSize : DWORD;
  RecordSize : DWORD;
  SectionAddr : DWORD;
  LinearAddr : DWORD;
begin
  SectionAddr := 0;
  LinearAddr := 0;
  BufferSize := BinStream.Size;
  SectionSize := BufferSize;
  BinStream.Seek( 0, soBeginning );

  while BufferSize > 0 do
  begin
    // Write Linear Address
    if ( StartAddress <> 0 ) or ( SectionSize = 0 ) then
    begin
      if ( StartAddress <> 0 ) then // first section
      begin
        SectionAddr := StartAddress and ( ONE_SECTION_SIZE - 1 );
        SectionSize := ONE_SECTION_SIZE - SectionAddr;
        LinearAddr := StartAddress shr 16;
        StartAddress := 0;
      end
      else // if ( SectionSize = 0 ) then
      begin
        SectionAddr := 0;
        SectionSize := BufferSize;
        LinearAddr := LinearAddr + 1;
      end;

      HexRec.DataSize := 2;
      HexRec.Addr := 0;
      HexRec.RecType := rtEla;
      HexRec.DataBuf[ 0 ] := LinearAddr shr 8;
      HexRec.DataBuf[ 1 ] := LinearAddr and $FF;
      HexStringList.Add( HexRec2Str( HexRec ) );

    end
    else // Write Data Record
    begin
      RecordSize := SectionSize;
      if RecordSize > ONE_RECORD_SIZE then
        RecordSize := ONE_RECORD_SIZE;

      HexRec.DataSize := RecordSize;
      HexRec.Addr := SectionAddr;
      HexRec.RecType := rtData;
      BinStream.Read( HexRec.DataBuf[ 0 ], RecordSize );
      HexStringList.Add( HexRec2Str( HexRec ) );

      SectionAddr := SectionAddr + RecordSize;
      SectionSize := SectionSize - RecordSize;
      BufferSize := BufferSize - RecordSize;
    end;
  end;

  // Write EOF :00000001FF
  HexRec.DataSize := 0;
  HexRec.Addr := 0;
  HexRec.RecType := rtEof;
  HexStringList.Add( HexRec2Str( HexRec ) );
end;

procedure Hex2Bin( HexStringList : TStringList; BinStream : TMemoryStream;
  var StartAddress : int64 );
var
  i : integer;
  LastAddress : int64;
  HexRec : THexRec;
  SectionFreeAddr : DWORD;
  SectionIndex : DWORD;
  SizeToWrite : DWORD;
  BufferToWrite : Pointer;
  LinearAddress : DWORD;
  FirstLinearAddr : DWORD;
  LastLinearAddr : DWORD;
  FirstUsedDataOffset : DWORD; // First Section : $0000
  LastUnusedDataOffset : DWORD; // Last Section : $10000
begin
  for i := 0 to MAX_SECTION_COUNT - 1 do // Mark as Unused
  begin
    HexSections[ i ].LinearAddress := $0000;
    HexSections[ i ].UnusedOffset := $0000;
    HexSections[ i ].UsedOffset := ONE_SECTION_SIZE;
    FillChar( HexSections[ i ].DataBuffer[ 0 ], ONE_SECTION_SIZE, $FF );
  end;

  SectionIndex := 0;
  for i := 0 to HexStringList.Count - 1 do
  begin
    HexRec := HexStr2Rec( HexStringList[ i ] );
    case HexRec.RecType of
      rtEof :
        break;
      rtSsa, rtEsa, rtSla :
        continue;
      rtEla :
        begin
          LinearAddress := HexRec.DataBuf[ 0 ] * 256 + HexRec.DataBuf[ 1 ];
          if HexSections[ SectionIndex ].LinearAddress <> LinearAddress then
          begin
            if ( i <> 0 ) then
              SectionIndex := SectionIndex + 1;
            if ( SectionIndex = MAX_SECTION_COUNT ) then
              raise EHex2Bin.Create( HEX_ERROR_SECTION_COUNT );

            HexSections[ SectionIndex ].LinearAddress := LinearAddress;
          end;
        end;

      rtData :
        begin
          SectionFreeAddr := HexRec.Addr + HexRec.DataSize; // ONE_SECTION_SIZE
          if SectionFreeAddr > ONE_SECTION_SIZE then
            raise EHex2Bin.Create( HEX_ERROR_SECTION_SIZE );
          if HexSections[ SectionIndex ].UnusedOffset < SectionFreeAddr then
            HexSections[ SectionIndex ].UnusedOffset := SectionFreeAddr;
          if HexSections[ SectionIndex ].UsedOffset > HexRec.Addr then
            HexSections[ SectionIndex ].UsedOffset := HexRec.Addr;
          CopyMemory( @HexSections[ SectionIndex ].DataBuffer[ HexRec.Addr ],
            @HexRec.DataBuf[ 0 ], HexRec.DataSize );
        end;
    end;
  end;

  FirstLinearAddr := $10000;
  LastLinearAddr := 0;
  FirstUsedDataOffset := 0;
  LastUnusedDataOffset := ONE_SECTION_SIZE;

  for i := 0 to SectionIndex do
  begin
    if HexSections[ i ].LinearAddress > LastLinearAddr then
    begin
      LastLinearAddr := HexSections[ i ].LinearAddress;
      LastUnusedDataOffset := HexSections[ i ].UnusedOffset;
    end;
    if HexSections[ i ].LinearAddress < FirstLinearAddr then
    begin
      FirstLinearAddr := HexSections[ i ].LinearAddress;
      FirstUsedDataOffset := HexSections[ i ].UsedOffset;
    end;
  end;

  StartAddress := DWORD( FirstLinearAddr ) shl 16;
  StartAddress := StartAddress + FirstUsedDataOffset;

  LastAddress := DWORD( LastLinearAddr ) shl 16;
  LastAddress := LastAddress + LastUnusedDataOffset;

  BinStream.Clear;
  BinStream.SetSize( LastAddress - StartAddress );

  // Write Every Section ( include unused sections : FF .. FF )
  for i := 0 to SectionIndex do
  begin
    if HexSections[ i ].LinearAddress = FirstLinearAddr then
    begin
      SizeToWrite := ONE_SECTION_SIZE - HexSections[ i ].UsedOffset;
      if SizeToWrite > BinStream.Size then
        SizeToWrite := BinStream.Size;

      BufferToWrite := @HexSections[ i ].DataBuffer
        [ HexSections[ i ].UsedOffset ];
    end
    else if HexSections[ i ].LinearAddress = LastLinearAddr then
    begin
      SizeToWrite := HexSections[ i ].UnusedOffset;
      BufferToWrite := @HexSections[ i ].DataBuffer[ 0 ];
    end
    else
    begin
      SizeToWrite := ONE_SECTION_SIZE;
      BufferToWrite := @HexSections[ i ].DataBuffer[ 0 ];
    end;
    BinStream.Write( BufferToWrite^, SizeToWrite );
  end;

end;

function HexStr2Int( HexStr : PChar; var AByte : BYTE ) : boolean;
begin
  Result := FALSE;
  if ( HexStr[ 0 ] = '0' ) then
    if ( ( HexStr[ 1 ] = 'x' ) or ( HexStr[ 1 ] = 'X' ) ) then
      Exit;

  if CharInSet( HexStr[ 0 ], [ '0' .. '9', 'A' .. 'F', 'a' .. 'f' ] ) then
  begin
    if CharInSet( HexStr[ 1 ], [ '0' .. '9', 'A' .. 'F', 'a' .. 'f' ] ) then
    begin
      AByte := StrToInt( '$' + HexStr[ 0 ] + HexStr[ 1 ] );
      Result := TRUE;
    end;
  end;
end;

procedure Txt2Bin( TxtStringList : TStringList; BinStream : TMemoryStream;
  var StartAddress : int64 ); // dont care StartAddress
var
  CharIndex : DWORD;
  SectionIndex : DWORD;
  SectionOffset : DWORD;
  TextStr : string;
  BinSize : DWORD;
  AByte : BYTE;
  SizeToWrite : DWORD;
begin
  TextStr := '';
  for SectionOffset := 0 to TxtStringList.Count - 1 do
    TextStr := TextStr + TxtStringList[ SectionOffset ];

  SectionIndex := 0;
  SectionOffset := 0;
  CharIndex := 1;
  BinSize := 0;

  while CharIndex < Length( TextStr ) do
  begin
    if not HexStr2Int( @TextStr[CharIndex], AByte ) then
    begin
      Inc( CharIndex, 1 );
      continue;
    end;

    HexSections[ SectionIndex ].DataBuffer[ SectionOffset ] := AByte;
    Inc( BinSize, 1 );
    Inc( SectionOffset, 1 );
    if SectionOffset = ONE_SECTION_SIZE then
      Inc( SectionIndex, 1 );
    if SectionIndex = MAX_SECTION_COUNT then
      break;

    Inc( CharIndex, 2 );
  end;

  BinStream.SetSize( BinSize );
  while BinSize > 0 do
  begin
    SizeToWrite := BinSize;
    if SizeToWrite > ONE_SECTION_SIZE then
      SizeToWrite := ONE_SECTION_SIZE;
    BinStream.Write( HexSections[ SectionIndex ].DataBuffer[ 0 ], SizeToWrite );
    Inc( SectionIndex );
    BinSize := BinSize - SizeToWrite;
  end;
end;

initialization

Hex2BinErrorMessage[ HEX_ERROR_MARKER ] := 'Error Marker';
Hex2BinErrorMessage[ HEX_ERROR_ADDRESS ] := 'Error Address';
Hex2BinErrorMessage[ HEX_ERROR_REC_TYPE ] := 'Error Type';
Hex2BinErrorMessage[ HEX_ERROR_SECTION_SIZE ] := 'Error Section Size';
Hex2BinErrorMessage[ HEX_ERROR_DATA ] := 'Error Data';
Hex2BinErrorMessage[ HEX_ERROR_CHECK_SUM ] := 'Error CheckSum';
Hex2BinErrorMessage[ HEX_ERROR_SECTION_COUNT ] := 'Error Section Count';

end.
