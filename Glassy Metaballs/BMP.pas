unit BMP;

interface

uses Windows, OpenGL;

procedure glBindTexture(Target: Cardinal; Texture: Cardinal); stdcall; external OpenGL32;
procedure glGenTextures(N: Integer; var Textures: Cardinal); stdcall; external OpenGL32;
procedure glDeleteTextures(N: Integer; var Textures: Cardinal); stdcall; external OpenGL32;
function gluBuild2DMipmaps(Target: Cardinal; Components, Width, Height: Integer;
  Format, AType: Cardinal; const Data: Pointer): Integer; stdcall; external 'glu32.dll';

function LoadBMP(FileName: string;
  var Tex: Cardinal): Boolean;

implementation

function LoadBMP(FileName: string;
  var Tex: Cardinal): Boolean;
var
  FileHeader: TBitmapFileHeader;
  InfoHeader: TBitmapInfoHeader;
  FileHandle: THandle; 
  BytesRead: Cardinal;
  Width, Height: Integer;
  Data: Pointer;
  I: Integer;
  R, B: ^Byte;
  T: Byte;
begin
  // Create the file handle and raise and
  // exit if the file does not exist.
  FileHandle := CreateFile(PChar(FileName), GENERIC_READ, 0, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if FileHandle = INVALID_HANDLE_VALUE then begin
    Result := False;
    Exit;
  end;

  // Read the file header and check if it is valid.
  ReadFile(FileHandle, FileHeader, SizeOf(TBitmapFileHeader), BytesRead, nil);
  if BytesRead <> SizeOf(TBitmapFileHeader) then begin
    Result := False;
    Exit;
  end;

  // Check if the bitmap is of type 'BM'
  if FileHeader.bfType <> $4D42 then begin
    Result := False;
    Exit;
  end;

  // Read the info header and check if it is valid.
  ReadFile(FileHandle, InfoHeader, SizeOf(BitmapInfoHeader), BytesRead, nil);
  if BytesRead <> SizeOf(TBitmapInfoHeader) then begin
    Result := False;
    Exit;
  end;

  // Exit if the bitmap is not 24-bit
  if InfoHeader.biBitCount <> 24 then begin
    Result := False;
    Exit;
  end;

  // Save the dimensions
  Width := InfoHeader.biWidth;
  Height := Abs(InfoHeader.biHeight);

  // Assign memory for the bitmap data
  GetMem(Data, InfoHeader.biSizeImage);

  // Read the bitmap data and exit if it is not valid
  ReadFile(FileHandle, Data^, InfoHeader.biSizeImage, BytesRead, nil);
  if BytesRead <> InfoHeader.biSizeImage then begin
    FreeMem(Data);
    Result := False;
    Exit;
  end;

  // Close the file handle
  CloseHandle(FileHandle);

  // Swap the red and blue bytes
  for I := 0 to Width * Height - 1 do begin
    R := Ptr(Integer(Data) + I * 3);
    B := Ptr(Integer(R) + 2);
    T := R^;
    R^ := B^;
    B^ := T;
  end;

  // Delete any existing texture
  glDeleteTextures(1, Tex);

  // Assign a new texture
  glGenTextures(1, Tex);
  glBindTexture(GL_TEXTURE_2D, Tex);

  // Set some texture parameters
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  // Load the texture data
  gluBuild2DMipmaps(GL_TEXTURE_2D, 3, Width, Height,
                GL_RGB, GL_UNSIGNED_BYTE, Data);

  // Free the memory assigned
  FreeMem(Data);

  // Return true - everything went OK.
  Result := True;
end;

end.
 