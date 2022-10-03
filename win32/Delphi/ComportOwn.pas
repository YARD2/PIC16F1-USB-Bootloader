unit COMportOwn;

interface
  uses Windows;

function OpenCOMPort(c:string): THandle;
function SendText(ComFile:Thandle;s: string) : byte;
function ReadText(ComFile:Thandle): byte;
procedure CloseCOMPort(ComFile:Thandle);

implementation

function OpenCOMPort(c:string): THandle;
var
  CommTimeouts: TCommTimeouts;
  ComFile : Thandle;
begin

  ComFile := CreateFile(pchar('\\.\' + c),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0);

  if ComFile = INVALID_HANDLE_VALUE then
    Result := INVALID_HANDLE_VALUE
  else
   begin

    with CommTimeouts do
    begin
      ReadIntervalTimeout         := 100;
      ReadTotalTimeoutMultiplier  := 0;
      ReadTotalTimeoutConstant    := 100;
      WriteTotalTimeoutMultiplier := 0;
      WriteTotalTimeoutConstant   := 100;
    end;

    if not SetCommTimeouts(ComFile, CommTimeouts) then
      Result := INVALID_HANDLE_VALUE
    else
      Result := ComFile;
   end;
end;

function SendText(ComFile:Thandle; s: string) : byte;
var
  BytesWritten: DWORD;
begin
  WriteFile(ComFile, s[1], Length(s), BytesWritten, nil);
  Result := BytesWritten;
end;

function ReadText(ComFile:Thandle): byte;
var
  d : byte;
  BytesRead: cardinal;
begin
  if not ReadFile(ComFile, d, SizeOf(d), BytesRead, nil) then
  begin
    { Raise an exception or do someting else }
    Result := $FF;
  end
  else Result := d;
end;


procedure CloseCOMPort(ComFile:Thandle);
begin
  CloseHandle(ComFile);
end;

end.