unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, Gauges;

type
  Hexbuffer = array[0..$4002] of byte;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Flashandreset: TButton;
    Closeapp: TButton;
    OpenDialog1: TOpenDialog;
    LoadHexfile: TButton;
    Memo2: TMemo;
    GETfirmwareversion: TButton;
    Resetonly: TButton;
    MemoryModel: TComboBox;
    Label1: TLabel;
    ProgressBar1: TGauge;
    comcombobox1: TComboBox;
    procedure FlashandresetClick(Sender: TObject);
    procedure LoadHexfileClick(Sender: TObject);
    procedure CloseappClick(Sender: TObject);
    procedure ResetonlyClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure GETfirmwareversionClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    ComportFile: THandle;
    sendreceive_buf : array[0..127] of byte;
    function device_set_params(addr:word; checksum:byte):word;
    function sendtoBL(sendbytes:byte;waitread:boolean=true):byte;
    function device_write(mempos:word) :word;
    procedure device_reset;
    procedure device_version;
    function OPENCOM:boolean;
    procedure CLOSECOM;
  end;


var
  Form1: TForm1;
  Hexbuf:Hexbuffer;

const
  Maxprog = 16383;
  BCMD_ERASE = $45;
  BCMD_RESET = $52;
  STATUS_OK = 1;
  STATUS_INVALID_COMMAND = 2;
  STATUS_INVALID_CHECKSUM = 3;
  STATUS_VERIFY_FAILED = 4;

implementation
uses COMportOwn;

{$R *.DFM}

function TForm1.OPENCOM : Boolean;
begin
   comportfile := OpenCOMPort(comcombobox1.text);
   Result := (comportfile <> INVALID_HANDLE_VALUE);
end;

procedure TForm1.CLOSECOM;
begin
   CloseCOMPort(comportfile);
   comportfile := 0;
end;


function readline(HexLine:string; var Buf:Hexbuffer):integer;
var ADDR,count:integer;
    CHKSUM,SUMLINE,RECLEN,RECTYPE,DATA:byte;
    HIADDR: Word;
    t:shortstring;
begin
{$R-}
  if HexLine[1] = ':' then
  begin
  t       := '$'+copy(HexLine,2,2);   // get length
  RECLEN  := strtoint(t);
  CHKSUM  := 0;
  CHKSUM  := CHKSUM+RECLEN;
  t       := '$'+copy(HexLine,4,4); // get address
  ADDR    := strtoint(t);
  CHKSUM  := CHKSUM+lo(ADDR)+hi(ADDR);
  t       := '$'+copy(HexLine,8,2);
  RECTYPE := strtoint(t);
  CHKSUM  := CHKSUM+RECTYPE;

  case RECTYPE of
   0:begin             // datablock
     count := 0;
     while (count < RECLEN) do
     begin
      t      := '$'+copy(HexLine,10+2*count,2);
      DATA   := strtoint(t);
      CHKSUM := CHKSUM+DATA;
      Buf[ADDR+count] := DATA;
      inc(count);
     end;
     t := '$' + copy(HexLine,10+2*count,2);
     SUMLINE := strtoint(t);
     end;
   1:begin    // end of file
      t       := '$' + copy(HexLine,10,2);
      SUMLINE := strtoint(t);
      result  := 1;
     end;
   4:begin   // extended memory
      t       := '$'+copy(HexLine,10,4); // get address
      HiADDR  := strtoint(t);
      if HiADDR <> 0 then result := 9; //indicator to skip next line
      exit;
     end;
     else
     begin
        result := -2;  // invalid record type
        exit;
     end;
    end; //case
  // test checksum
  DATA := SUMLINE+CHKSUM;
  if (DATA <> 0) then result:=-3; // checksum error
 end
 else result := -1; // no record
{$R+};
end;


function testblock(mempos:word) : boolean;
var i : word;
begin
 Result := false;
  for i := 0 to 63 do
  if Hexbuf[mempos+i] <> $FF then Result := true;
end;

function CompBlockChKSum(Mempos:word):word;
var j:byte;
    chksum:word;
begin
{$R-};
 j:=0;
 chksum := 0;
 repeat
  chksum := chksum + Hexbuf[Mempos+j];
  chksum := chksum + (Hexbuf[Mempos+j+1] and $3F);
  j := j + 2;
 until j >= 63;
 chksum := 256 - (chksum mod 256);
 if chksum = 256 then chksum := 0;
 Result := chksum;
{$R+};
end;

function TForm1.sendtoBL(sendbytes:byte;waitread:boolean=true):byte;
var cdcstr : string[128];
    i: word;
begin
  Result := 0;
  cdcstr :='';
  for i:=0 to Sendbytes-1 do cdcstr := cdcstr + chr(sendreceive_buf[i]);
  SendText(comportfile,cdcstr);
  if waitread then Result := ReadText(comportfile);
end;

procedure TForm1.device_reset;
begin
	sendreceive_buf[0] := ord('R');
    sendtobl(1,false);
end;

procedure TForm1.device_version;
var ret : byte;
begin
 if OPENCOM then
 begin
   sendreceive_buf[0] := ord('V');
   sendreceive_buf[1] := ord('B');
   ret := sendtobl(2);
   memo2.lines.add('Bootloaderversion: ' + inttohex(ret,2));
 end;

 CLOSECOM;
end;

function TForm1.device_set_params(addr:word; checksum:byte):word;
begin
	sendreceive_buf[0] := addr and $FF;
	sendreceive_buf[1] := (addr shr 8) and $FF;
	sendreceive_buf[2] := checksum;
	sendreceive_buf[3] := BCMD_ERASE;

    Result := sendtobl(4);
end;

function TForm1.device_write(mempos:word) :word;
var i :word;
begin
 i := 0;
 repeat
    sendreceive_buf[i] := HEXbuf[mempos+i];
    inc(i);
    sendreceive_buf[i] := HEXbuf[mempos+i] and $3F;
    inc(i);
 until i = 64;

  Result := sendtobl(64);
end;

procedure TForm1.FlashandresetClick(Sender: TObject);
var i,startaddr,endaddr,ret:word;
    usedblock : boolean;
    checksum:byte;
    maxprogflash:word;
begin
if memo1.lines.Count = 0 then exit;

 Fillchar(Hexbuf,sizeof(Hexbuf),$FF);
 i:=0;
 startaddr := 0;
 endaddr := 0;
 repeat
  if (readline(memo1.lines.strings[i],Hexbuf) = 9) then
    inc(i); // skip next line
  inc(i);
 until i = memo1.lines.count -1;

 i:= 0;
 Repeat
  usedblock := testblock(i);
  if ((startaddr=0) and (usedblock)) then startaddr := i;
  if usedblock then endaddr := i;
  i := i + 64;
 until i > Maxprog;

 memo2.lines.add('Flash from: 0x' + inttohex(startaddr div 2,4) + '  to: 0x' + inttohex(endaddr div 2,4));
 ProgressBar1.progress := 0;

 maxprogflash := 0;
 case MemoryModel.itemindex of
  0: maxprogflash := $1FFF*2;
  1: maxprogflash := $1F80*2;
  2: maxprogflash := $1F00*2;
 end;
 ProgressBar1.Maxvalue := maxprogflash;

try
 if not OPENCOM then
 begin
   memo2.lines.add('CAN NOT OPEN COMPORT');
   exit;
 end;

 //Get Version of Bootloader
 sendreceive_buf[0] := ord('V');
 sendreceive_buf[1] := ord('B');
 ret := sendtobl(2);
 memo2.lines.add('Bootloaderversion: ' + inttohex(ret,2)+#13#10);

//Write Firmware
 i := startaddr;
 repeat
  checksum := CompBlockChKSum(i);
  ret := device_set_params(i div 2, checksum);
  if ret = 1 then
   begin
     ret := device_write(i);
     case ret of
       STATUS_OK:                memo2.lines.add(inttohex(i div 2,4) + ' Write 32 bytes OK');
       STATUS_INVALID_COMMAND:   memo2.lines.add(inttohex(i div 2,4) + ' Invalid Command');
       STATUS_INVALID_CHECKSUM:  memo2.lines.add(inttohex(i div 2,4) + ' Invalid Checksum');
       STATUS_VERIFY_FAILED:     memo2.lines.add(inttohex(i div 2,4) + ' Verify failed');
       255:                      memo2.lines.add('ERROR DURING SEND/RECEIVE - CLOSE APP AND TRY AGAIN!');
     end;
   end;
   if ret <> 1 then break;

  i := i + 64;
  ProgressBar1.progress := i;
  ProgressBar1.Update;
 until i > endaddr;

//Erase the rest of the flash
 if maxprogflash > (endaddr + 64) then
 begin
   i := endaddr + 64;
   repeat
 	ret:= device_set_params(i div 2, 0); //just erase the resr of the flash
    if ret <> 1 then break;
    memo2.lines.add(inttohex(i div 2,4) + ' Erase Flash 32 bytes OK');


    i := i + 64;
    ProgressBar1.progress := i;
    ProgressBar1.Update;
    until i >= maxprogflash;
 end;

 device_reset;

finally
 CLOSECOM;
end;

end;


procedure TForm1.CloseappClick(Sender: TObject);
begin
close;
end;

procedure TForm1.LoadHexfileClick(Sender: TObject);
var hexfile : string;
begin
if opendialog1.Execute then
 hexfile := opendialog1.FileName
else exit;

memo1.lines.LoadFromFile(hexfile);
end;

procedure TForm1.ResetonlyClick(Sender: TObject);
begin
 if OPENCOM then
 begin
   sendreceive_buf[0] := ord('R');
   sendtobl(1,false);
   memo2.lines.add('Reset done');
 end;
 CLOSECOM;
end;

procedure TForm1.FormActivate(Sender: TObject);
begin
MemoryModel.itemindex := 0;
end;

procedure TForm1.GETfirmwareversionClick(Sender: TObject);
begin
device_version;
end;


end.

