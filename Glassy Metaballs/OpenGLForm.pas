unit OpenGLForm;

interface

uses
  Windows, Classes, Forms, SyncObjs;

type
  TOpenGLWindow = class;

  TOpenGLWindowThread = class(TThread)
  private
    FForm: TOpenGLWindow;
  protected
    procedure Execute; override;
  public
    constructor Create(Form: TOpenGLWindow);
  end;

  TOpenGLWindow = class(TForm)
  private
    H_DC: HDC;                      
    H_RC: HGLRC;                    
    Thread: TOpenGLWindowThread;    
    procedure Init;
    procedure Kill;                 
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DoSwapBuffers;
    procedure EnableWnd;
  end;

implementation

var
  { A critical section object makes sure threaded code
    does not get interrupted - Thankyou to Jeroen Commandeur
    for showing me this method }
  CS: TCriticalSection;

constructor TOpenGLWindow.Create(AOwner: TComponent);
begin
  inherited;
  Thread := TOpenGLWindowThread.Create(Self);
  Init;
end;

destructor TOpenGLWindow.Destroy;
begin
  inherited;
  Thread.Terminate;
  Kill;
end;

procedure TOpenGLWindow.DoSwapBuffers;
begin
  SwapBuffers(H_DC);
end;

procedure TOpenGLWindow.EnableWnd;
begin
  wglMakeCurrent(H_DC, H_RC);
end;

procedure TOpenGLWindow.Resize;
begin
  CS.Enter;
  EnableWnd;
  inherited;
  CS.Leave;
end;

procedure TOpenGLWindow.Paint;
begin
  CS.Enter;
  EnableWnd;
  inherited;
  CS.Leave;
end;

procedure TOpenGLWindow.Init;
var
  PixelFormat: Integer;
  PFD: TPixelFormatDescriptor;
begin
  H_DC := GetDC(Handle);

  ZeroMemory(@PFD, SizeOf(PFD));

  with PFD do begin
    nSize := SizeOf(PFD);
    nVersion := 1;
    dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
    iPixelType := PFD_TYPE_RGBA;
    cColorBits := 16;
    cDepthBits := 16;
  end;

  PixelFormat := ChoosePixelFormat(H_DC, @PFD);
  if PixelFormat = 0 then begin
    Kill;
    MessageBox(0, 'Unable to choose pixel format', 'Error', MB_OK or MB_ICONERROR);
    Exit;
  end;

  if not SetPixelFormat(H_DC, PixelFormat, @PFD) then begin
    Kill;
    MessageBox(0, 'Unable to set pixel format', 'Error', MB_OK or MB_ICONERROR);
    Exit;
  end;

  H_RC := wglCreateContext(H_DC);
  if H_RC = 0 then begin
    Kill;
    MessageBox(0, 'Unable to create rendering context', 'Error', MB_OK or MB_ICONERROR);
    Exit;
  end;

  if not wglMakeCurrent(H_DC, H_RC) then begin
    Kill;
    MessageBox(0, 'Unable to activate rendering context', 'Error', MB_OK or MB_ICONERROR);
    Exit;
  end;

  Resize;
end;

procedure TOpenGLWindow.Kill;
begin
  if not wglMakeCurrent(H_DC, 0) then
    MessageBox(0, 'Unable to release rendering context', 'Error', MB_OK or MB_ICONERROR);

  if not wglDeleteContext(H_RC) then begin
    MessageBox(0, 'Unable to release rendering context', 'Error', MB_OK or MB_ICONERROR);
    H_RC := 0;
  end;
end;

constructor TOpenGLWindowThread.Create(Form: TOpenGLWindow);
begin
  inherited Create(True);
  FForm := Form;
  FreeOnTerminate := True;
  Resume;
end;

procedure TOpenGLWindowThread.Execute;
begin
  while not Terminated do begin
    Application.ProcessMessages;
    Synchronize(FForm.Paint);
  end;
end;

initialization
  CS := TCriticalSection.Create;

finalization
  CS.Free;

end.
