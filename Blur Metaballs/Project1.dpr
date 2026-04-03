program Project1;

uses
  WinApi.Windows,
  Messages,
  OpenGL,
  LookUpTable;

const
  WND_TITLE = 'Blur Metaballs - Press [W] for Wire effect';
  FPS_TIMER = 1;                     // Timer to calculate FPS
  FPS_INTERVAL = 500;               // Calculate FPS every 1000 ms

type
  TGLCoord = Record
    X, Y, Z : glFLoat;
  end;
  TMetaBall = Record
    Radius : glFloat;
    X, Y, Z : glFLoat;
  end;
  TGridPoint = record
    P : TGLCoord;
    Value : glFLoat;  // Result of the metaball equations at this point
  end;
  PGridPoint = ^TGridPoint;
  TGridCube = record
    GridPoint : Array [0..7] of PGridPoint; // Points to 8 grid points (cube)
  end;

var
  h_Wnd  : HWND;                     // Global window handle
  h_DC   : HDC;                      // Global device context
  h_RC   : HGLRC;                    // OpenGL rendering context
  keys : Array[0..255] of Boolean;   // Holds keystrokes
  FPSCount : Integer = 0;            // Counter for FPS
  ElapsedTime : Integer;             // Elapsed time between frames

  // Textures
  MyTextureTex : glUint;

  // User vaiables
  Wireframe     : Boolean;
  SmoothShading : Boolean;
  GridSize      : Integer;
  TessTriangles : Integer;  // Number of triangles by metaball tesselation.
  MetaBall : Array[1..3] of TMetaBall;
  Grid  : Array[0..50, 0..50, 0..50] of TGridPoint;  // for this demo set max gridsize = 50
  Cubes : Array[0..49, 0..49, 0..49] of TGridCube;

{$R *.RES}

procedure glBindTexture(target: GLenum; texture: GLuint); stdcall; external opengl32;

{------------------------------------------------------------------}
{  Function to convert int to string. (No sysutils = smaller EXE)  }
{------------------------------------------------------------------}
function IntToStr(Num : Integer) : String;  // using SysUtils increase file size by 100K
begin
  Str(Num, result);
end;

procedure SetColor(const V : TGLCoord);
var
  C : glFloat;
begin
  with V do
    C := sqrt(x*x + y*y +z*z);
  glColor3f(C, C, C+0.1);    // add a hint of blue
end;

procedure InitGrid;
var
  cx, cy, cz : Integer;
begin
  // Create the grid positions
  for cx := 0 to GridSize do
    for cy := 0 to GridSize do
      for cz := 0 to GridSize do
      begin
        Grid[cx, cy, cz].P.X := 2*cx/GridSize -1;   // grid from -1 to 1
        Grid[cx, cy, cz].P.Y := 2*cy/GridSize -1;   // grid from -1 to 1
        Grid[cx, cy, cz].P.Z := 1-2*cz/GridSize;    // grid from -1 to 1
      end;

  // Create the cubes. Each cube points to 8 grid points
  for cx := 0 to GridSize-1 do
    for cy := 0 to GridSize-1 do
      for cz := 0 to GridSize-1 do
      begin
        Cubes[cx,cy,cz].GridPoint[0] := @Grid[cx,   cy,   cz  ];
        Cubes[cx,cy,cz].GridPoint[1] := @Grid[cx+1, cy,   cz  ];
        Cubes[cx,cy,cz].GridPoint[2] := @Grid[cx+1, cy,   cz+1];
        Cubes[cx,cy,cz].GridPoint[3] := @Grid[cx,   cy,   cz+1];
        Cubes[cx,cy,cz].GridPoint[4] := @Grid[cx,   cy+1, cz  ];
        Cubes[cx,cy,cz].GridPoint[5] := @Grid[cx+1, cy+1, cz  ];
        Cubes[cx,cy,cz].GridPoint[6] := @Grid[cx+1, cy+1, cz+1];
        Cubes[cx,cy,cz].GridPoint[7] := @Grid[cx,   cy+1, cz+1];
      end;
end;

{----------------------------------------------------------}
{  Interpolate the position where an metaballs intersects  }
{  the line betweenthe two coordicates, C1 and C2          }
{----------------------------------------------------------}
function Interpolate(const C1, C2 : TGLCoord; Val1, Val2 : glFloat) : TGLCoord;
var
  mu : glFLoat;
begin
  if Abs(Val1) = 1 then
    Result := C1
  else
  if Abs(Val2) = 1 then
    Result := C2
  else
  if Val1 = Val2 then
    Result := C1
  else
  begin
    mu := (1 - Val1) / (Val2 - Val1);
    Result.x := C1.x + mu * (C2.x - C1.x);
    Result.y := C1.y + mu * (C2.y - C1.y);
    Result.z := C1.z + mu * (C2.z - C1.z);
  end;
end;


{------------------------------------------------------------}
{  Calculate the triangles required to draw a Cube.          }
{  Draws the triangles that makes up a Cube                  }
{------------------------------------------------------------}
procedure CreateCubeTriangles(const GridCube : TGridCube);
var
  I : Integer;
  C : glFloat;
  CubeIndex: Integer;
  VertList : Array[0..11] of TGLCoord;
begin
  // Determine the index into the edge table which tells
  // us which vertices are inside/outside the metaballs
  CubeIndex := 0;
  if GridCube.GridPoint[0]^.Value < 1 then CubeIndex := CubeIndex or 1;
  if GridCube.GridPoint[1]^.Value < 1 then CubeIndex := CubeIndex or 2;
  if GridCube.GridPoint[2]^.Value < 1 then CubeIndex := CubeIndex or 4;
  if GridCube.GridPoint[3]^.Value < 1 then CubeIndex := CubeIndex or 8;
  if GridCube.GridPoint[4]^.Value < 1 then CubeIndex := CubeIndex or 16;
  if GridCube.GridPoint[5]^.Value < 1 then CubeIndex := CubeIndex or 32;
  if GridCube.GridPoint[6]^.Value < 1 then CubeIndex := CubeIndex or 64;
  if GridCube.GridPoint[7]^.Value < 1 then CubeIndex := CubeIndex or 128;

  // Check if the cube is entirely in/out of the surface
  if edgeTable[CubeIndex] = 0 then
    Exit;

  // Find the vertices where the surface intersects the cube.
  with GridCube do
  begin
    if (edgeTable[CubeIndex] and 1) <> 0 then
      VertList[0] := Interpolate(GridPoint[0]^.P, GridPoint[1]^.P,
      GridPoint[0]^.Value, GridPoint[1]^.Value);
    if (edgeTable[CubeIndex] and 2) <> 0 then
      VertList[1] := Interpolate(GridPoint[1]^.P, GridPoint[2]^.P,
      GridPoint[1]^.Value, GridPoint[2]^.Value);
    if (edgeTable[CubeIndex] and 4) <> 0 then
      VertList[2] := Interpolate(GridPoint[2]^.P, GridPoint[3]^.P,
      GridPoint[2]^.Value, GridPoint[3]^.Value);
    if (edgeTable[CubeIndex] and 8) <> 0 then
      VertList[3] := Interpolate(GridPoint[3]^.P, GridPoint[0]^.P,
      GridPoint[3]^.Value, GridPoint[0]^.Value);
    if (edgeTable[CubeIndex] and 16) <> 0 then
      VertList[4] := Interpolate(GridPoint[4]^.P, GridPoint[5]^.P,
      GridPoint[4]^.Value, GridPoint[5]^.Value);
    if (edgeTable[CubeIndex] and 32) <> 0 then
      VertList[5] := Interpolate(GridPoint[5]^.P, GridPoint[6]^.P,
      GridPoint[5]^.Value, GridPoint[6]^.Value);
    if (edgeTable[CubeIndex] and 64) <> 0 then
      VertList[6] := Interpolate(GridPoint[6]^.P, GridPoint[7]^.P,
      GridPoint[6]^.Value, GridPoint[7]^.Value);
    if (edgeTable[CubeIndex] and 128) <> 0 then
      VertList[7] := Interpolate(GridPoint[7]^.P, GridPoint[4]^.P,
      GridPoint[7]^.Value, GridPoint[4]^.Value);
    if (edgeTable[CubeIndex] and 256) <> 0 then
      VertList[8] := Interpolate(GridPoint[0]^.P, GridPoint[4]^.P,
      GridPoint[0]^.Value, GridPoint[4]^.Value);
    if (edgeTable[CubeIndex] and 512) <> 0 then
      VertList[9] := Interpolate(GridPoint[1]^.P, GridPoint[5]^.P,
      GridPoint[1]^.Value, GridPoint[5]^.Value);
    if (edgeTable[CubeIndex] and 1024) <> 0 then
      VertList[10] := Interpolate(GridPoint[2]^.P, GridPoint[6]^.P,
      GridPoint[2]^.Value, GridPoint[6]^.Value);
    if (edgeTable[CubeIndex] and 2048) <> 0 then
      VertList[11] := Interpolate(GridPoint[3]^.P, GridPoint[7]^.P,
      GridPoint[3]^.Value, GridPoint[7]^.Value);
  end;

  // Draw the triangles for this cube
  I := 0;
  while TriangleTable[CubeIndex, i] <> -1 do
  begin
    SetColor(VertList[TriangleTable[CubeIndex][i]]);
    glVertex3fv(@VertList[TriangleTable[CubeIndex][i]]);

    SetColor(VertList[TriangleTable[CubeIndex][i+1]]);
    glVertex3fv(@VertList[TriangleTable[CubeIndex][i+1]]);

    if SmoothShading then
      SetColor(VertList[TriangleTable[CubeIndex][i+2]]);
    glVertex3fv(@VertList[TriangleTable[CubeIndex][i+2]]);

    Inc(TessTriangles);
    Inc(i, 3);
  end;
end;

{------------------------------------------------------------------}
{  Function to draw the actual scene                               }
{------------------------------------------------------------------}
procedure glDraw();
var
  cx, cy, cz : Integer;
  I : Integer;
begin
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);    // Clear The Screen And The Depth Buffer
  glLoadIdentity();                                       // Reset The View

  glTranslatef(0.0,0.0,-2.5);
  glRotatef(ElapsedTime/30, 0, 1, 0);
  glRotatef(ElapsedTime/20, 1, 0, 0);

  MetaBall[2].X :=0.4*sin(ElapsedTime/400) - 0.25*cos(ElapsedTime/600);
  MetaBall[2].Y :=0.45*cos(ElapsedTime/400) - 0.2*cos(ElapsedTime/600);
  MetaBall[3].X :=-0.4*cos(ElapsedTime/500) - 0.2*sin(ElapsedTime/600);
  MetaBall[3].Z :=0.4*sin(ElapsedTime/500) - 0.2*sin(ElapsedTime/400);

  TessTriangles := 0;
  For cx := 0 to GridSize do
    For cy := 0 to GridSize do
      For cz := 0 to GridSize do
        with Grid[cx, cy, cz] do
        begin
          Value :=0;
          for I :=1 to 3 do  // go through all meta balls
          begin
            with Metaball[I] do
              Value := Value + Radius*Radius /((P.x-x)*(P.x-x) +
                                               (P.y-y)*(P.y-y) +
                                               (P.z-z)*(P.z-z));
          end;
        end;

  // Draw the metaballs by drawing the triangle in each cube in the grid
  glBegin(GL_TRIANGLES);
    For cx := 0 to GridSize-1 do
      for cy := 0 to GridSize-1 do
        for cz := 0 to GridSize-1 do
          CreateCubeTriangles(Cubes[cx, cy, cz]);
  glEnd;
end;


{------------------------------------------------------------------}
{  Initialise OpenGL                                               }
{------------------------------------------------------------------}
procedure glInit();
begin
  glClearColor(0.0, 0.0, 0.0, 0.0); // Black Background
  glShadeModel(GL_SMOOTH);           // Enables Smooth Color Shading
  glClearDepth(1.0);                 // Depth Buffer Setup
  glEnable(GL_DEPTH_TEST);           // Enable Depth Buffer
  glDepthFunc(GL_LESS);		           // The Type Of Depth Test To Do

  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);   //Realy Nice perspective calculations

  glDisable(GL_TEXTURE_2D);          // Enable Texture Mapping

  // initialise the metaball size and positions
  MetaBall[1].Radius :=0.3;
  MetaBall[1].X :=0.5;
  MetaBall[1].Y :=0;
  MetaBall[1].Z :=0;

  MetaBall[2].Radius :=0.22;
  MetaBall[2].X :=0;
  MetaBall[2].Y :=0;
  MetaBall[2].Z :=0;

  MetaBall[3].Radius :=0.25;
  MetaBall[3].X :=0;
  MetaBall[3].Y :=0;
  MetaBall[3].Z :=0;

  SmoothShading :=TRUE;
  WireFrame :=FALSE;
  GridSize  :=31;
  InitGrid;
end;


{------------------------------------------------------------------}
{  Handle window resize                                            }
{------------------------------------------------------------------}
procedure glResizeWnd(Width, Height : Integer);
begin
  if (Height = 0) then                // prevent divide by zero exception
    Height := 1;
  glViewport(0, 0, Width, Height);    // Set the viewport for the OpenGL window
  glMatrixMode(GL_PROJECTION);        // Change Matrix Mode to Projection
  glLoadIdentity();                   // Reset View
  gluPerspective(45.0, Width/Height, 1.0, 100.0);  // Do the perspective calculations. Last value = max clipping depth

  glMatrixMode(GL_MODELVIEW);         // Return to the modelview matrix
  glLoadIdentity();                   // Reset View
end;


{------------------------------------------------------------------}
{  Processes all the keystrokes                                    }
{------------------------------------------------------------------}
procedure ProcessKeys;
begin
  if (keys[Ord('S')]) then     // Enable/Disable smooth shading
  begin
    SmoothShading :=NOT(SmoothShading);
    Keys[Ord('S')] :=FALSE;
  end;

  if (keys[Ord('W')]) then     // Enable/Disable wireframe draw
  begin
    if Wireframe then
    begin
      glPolygonMode(GL_FRONT, GL_FILL);
      glPolygonMode(GL_BACK, GL_FILL);
    end
    else
    begin
      glPolygonMode(GL_FRONT, GL_LINE);
      glPolygonMode(GL_BACK, GL_LINE);
    end;
    WireFrame :=NOT(WireFrame);
    Keys[Ord('W')] :=FALSE;
  end;

  if (keys[VK_SUBTRACT]) then     // decrease grid size / resolution
  begin
    if GridSize > 5 then
      GridSize :=GridSize-1;
    InitGrid;
    keys[VK_SUBTRACT] :=FALSE;
  end;

  if (keys[VK_ADD]) then         // increase grid size / resolution
  begin
    if GridSize < 50 then
      GridSize :=GridSize+1;
    InitGrid;
    keys[VK_ADD] :=FALSE;
  end;
end;


{------------------------------------------------------------------}
{  Determines the application’s response to the messages received  }
{------------------------------------------------------------------}
function WndProc(hWnd: HWND; Msg: UINT;  wParam: WPARAM;  lParam: LPARAM): LRESULT; stdcall;
begin
  case (Msg) of
    WM_CREATE:
      begin
        // Insert stuff you want executed when the program starts
      end;
    WM_CLOSE:
      begin
        PostQuitMessage(0);
        Result := 0
      end;
    WM_KEYDOWN:       // Set the pressed key (wparam) to equal true so we can check if its pressed
      begin
        keys[wParam] := True;
        Result := 0;
      end;
    WM_KEYUP:         // Set the released key (wparam) to equal false so we can check if its pressed
      begin
        keys[wParam] := False;
        Result := 0;
      end;
    WM_SIZE:          // Resize the window with the new width and height
      begin
        glResizeWnd(LOWORD(lParam),HIWORD(lParam));
        Result := 0;
      end;
    WM_TIMER :                     // Add code here for all timers to be used.
      begin
        if wParam = FPS_TIMER then
        begin
          FPSCount :=Round(FPSCount * 1000/FPS_INTERVAL);   // calculate to get per Second incase intercal is less or greater than 1 second
          SetWindowText(h_Wnd, PChar(WND_TITLE + '   [' + intToStr(FPSCount) +
                                ' FPS]     GridSize=' + intToStr(GridSize)));
          FPSCount := 0;
          Result := 0;
        end;
      end;
    else
      Result := DefWindowProc(hWnd, Msg, wParam, lParam);    // Default result if nothing happens
  end;
end;


{---------------------------------------------------------------------}
{  Properly destroys the window created at startup (no memory leaks)  }
{---------------------------------------------------------------------}
procedure glKillWnd(Fullscreen : Boolean);
begin
  if Fullscreen then             // Change back to non fullscreen
  begin
    ChangeDisplaySettings(devmode(nil^), 0);
    ShowCursor(True);
  end;

  // Makes current rendering context not current, and releases the device
  // context that is used by the rendering context.
  if (not wglMakeCurrent(h_DC, 0)) then
    MessageBox(0, 'Release of DC and RC failed!', 'Error', MB_OK or MB_ICONERROR);

  // Attempts to delete the rendering context
  if (not wglDeleteContext(h_RC)) then
  begin
    MessageBox(0, 'Release of rendering context failed!', 'Error', MB_OK or MB_ICONERROR);
    h_RC := 0;
  end;

  // Attemps to release the device context
  if ((h_DC = 1) and (ReleaseDC(h_Wnd, h_DC) <> 0)) then
  begin
    MessageBox(0, 'Release of device context failed!', 'Error', MB_OK or MB_ICONERROR);
    h_DC := 0;
  end;

  // Attempts to destroy the window
  if ((h_Wnd <> 0) and (not DestroyWindow(h_Wnd))) then
  begin
    MessageBox(0, 'Unable to destroy window!', 'Error', MB_OK or MB_ICONERROR);
    h_Wnd := 0;
  end;

  // Attempts to unregister the window class
  if (not UnRegisterClass('OpenGL', hInstance)) then
  begin
    MessageBox(0, 'Unable to unregister window class!', 'Error', MB_OK or MB_ICONERROR);
    hInstance := 0;
  end;
end;


{--------------------------------------------------------------------}
{  Creates the window and attaches a OpenGL rendering context to it  }
{--------------------------------------------------------------------}
function glCreateWnd(Width, Height : Integer; Fullscreen : Boolean;
          PixelDepth : Integer) : Boolean;
var
  wndClass : TWndClass;         // Window class
  dwStyle : DWORD;              // Window styles
  dwExStyle : DWORD;            // Extended window styles
  dmScreenSettings : DEVMODE;   // Screen settings (fullscreen, etc...)
  PixelFormat : GLuint;         // Settings for the OpenGL rendering
  h_Instance : HINST;           // Current instance
  pfd : TPIXELFORMATDESCRIPTOR;  // Settings for the OpenGL window
begin
  h_Instance := GetModuleHandle(nil);       //Grab An Instance For Our Window
  ZeroMemory(@wndClass, SizeOf(wndClass));  // Clear the window class structure

  with wndClass do                    // Set up the window class
  begin
    style         := CS_HREDRAW or    // Redraws entire window if length changes
                     CS_VREDRAW or    // Redraws entire window if height changes
                     CS_OWNDC;        // Unique device context for the window
    lpfnWndProc   := @WndProc;        // Set the window procedure to our func WndProc
    hInstance     := h_Instance;
    hCursor       := LoadCursor(0, IDC_ARROW);
    lpszClassName := 'OpenGL';
  end;

  if (RegisterClass(wndClass) = 0) then  // Attemp to register the window class
  begin
    MessageBox(0, 'Failed to register the window class!', 'Error',
                  MB_OK or MB_ICONERROR);
    Result := False;
    Exit
  end;

  // Change to fullscreen if so desired
  if Fullscreen then
  begin
    ZeroMemory(@dmScreenSettings, SizeOf(dmScreenSettings));
    with dmScreenSettings do begin              // Set parameters for the screen setting
      dmSize       := SizeOf(dmScreenSettings);
      dmPelsWidth  := Width;                    // Window width
      dmPelsHeight := Height;                   // Window height
      dmBitsPerPel := PixelDepth;               // Window color depth
      dmFields     := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL;
    end;

    // Try to change screen mode to fullscreen
    if (ChangeDisplaySettings(dmScreenSettings,
      CDS_FULLSCREEN) = DISP_CHANGE_FAILED) then
    begin
      MessageBox(0, 'Unable to switch to fullscreen!', 'Error', MB_OK or MB_ICONERROR);
      Fullscreen := False;
    end;
  end;

  // If we are still in fullscreen then
  if (Fullscreen) then
  begin
    dwStyle := WS_POPUP or                // Creates a popup window
               WS_CLIPCHILDREN            // Doesn't draw within child windows
               or WS_CLIPSIBLINGS;        // Doesn't draw within sibling windows
    dwExStyle := WS_EX_APPWINDOW;         // Top level window
    ShowCursor(False);                    // Turn of the cursor (gets in the way)
  end
  else
  begin
    dwStyle := WS_OVERLAPPEDWINDOW or     // Creates an overlapping window
               WS_CLIPCHILDREN or         // Doesn't draw within child windows
               WS_CLIPSIBLINGS;           // Doesn't draw within sibling windows
    dwExStyle := WS_EX_APPWINDOW or       // Top level window
                 WS_EX_WINDOWEDGE;        // Border with a raised edge
  end;

  // Attempt to create the actual window
  h_Wnd := CreateWindowEx(dwExStyle,      // Extended window styles
                          'OpenGL',       // Class name
                          WND_TITLE,      // Window title (caption)
                          dwStyle,        // Window styles
                          0, 0,           // Window position
                          Width, Height,  // Size of window
                          0,              // No parent window
                          0,              // No menu
                          h_Instance,     // Instance
                          nil);           // Pass nothing to WM_CREATE
  if h_Wnd = 0 then
  begin
    glKillWnd(Fullscreen);                // Undo all the settings we've changed
    MessageBox(0, 'Unable to create window!', 'Error', MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Try to get a device context
  h_DC := GetDC(h_Wnd);
  if (h_DC = 0) then
  begin
    glKillWnd(Fullscreen);
    MessageBox(0, 'Unable to get a device context!', 'Error', MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Settings for the OpenGL window
  with pfd do
  begin
    nSize           := SizeOf(TPIXELFORMATDESCRIPTOR); // Size Of This Pixel Format Descriptor
    nVersion        := 1;                    // The version of this data structure
    dwFlags         := PFD_DRAW_TO_WINDOW    // Buffer supports drawing to window
                       or PFD_SUPPORT_OPENGL // Buffer supports OpenGL drawing
                       or PFD_DOUBLEBUFFER;  // Supports double buffering
    iPixelType      := PFD_TYPE_RGBA;        // RGBA color format
    cColorBits      := PixelDepth;           // OpenGL color depth
    cRedBits        := 0;                    // Number of red bitplanes
    cRedShift       := 0;                    // Shift count for red bitplanes
    cGreenBits      := 0;                    // Number of green bitplanes
    cGreenShift     := 0;                    // Shift count for green bitplanes
    cBlueBits       := 0;                    // Number of blue bitplanes
    cBlueShift      := 0;                    // Shift count for blue bitplanes
    cAlphaBits      := 0;                    // Not supported
    cAlphaShift     := 0;                    // Not supported
    cAccumBits      := 0;                    // No accumulation buffer
    cAccumRedBits   := 0;                    // Number of red bits in a-buffer
    cAccumGreenBits := 0;                    // Number of green bits in a-buffer
    cAccumBlueBits  := 0;                    // Number of blue bits in a-buffer
    cAccumAlphaBits := 0;                    // Number of alpha bits in a-buffer
    cDepthBits      := 16;                   // Specifies the depth of the depth buffer
    cStencilBits    := 0;                    // Turn off stencil buffer
    cAuxBuffers     := 0;                    // Not supported
    iLayerType      := PFD_MAIN_PLANE;       // Ignored
    bReserved       := 0;                    // Number of overlay and underlay planes
    dwLayerMask     := 0;                    // Ignored
    dwVisibleMask   := 0;                    // Transparent color of underlay plane
    dwDamageMask    := 0;                     // Ignored
  end;

  // Attempts to find the pixel format supported by a device context that is the best match to a given pixel format specification.
  PixelFormat := ChoosePixelFormat(h_DC, @pfd);
  if (PixelFormat = 0) then
  begin
    glKillWnd(Fullscreen);
    MessageBox(0, 'Unable to find a suitable pixel format', 'Error',
      MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Sets the specified device context's pixel format to the format specified by the PixelFormat.
  if (not SetPixelFormat(h_DC, PixelFormat, @pfd)) then
  begin
    glKillWnd(Fullscreen);
    MessageBox(0, 'Unable to set the pixel format', 'Error',
      MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Create a OpenGL rendering context
  h_RC := wglCreateContext(h_DC);
  if (h_RC = 0) then
  begin
    glKillWnd(Fullscreen);
    MessageBox(0, 'Unable to create an OpenGL rendering context', 'Error',
      MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Makes the specified OpenGL rendering context the calling thread's current rendering context
  if (not wglMakeCurrent(h_DC, h_RC)) then
  begin
    glKillWnd(Fullscreen);
    MessageBox(0, 'Unable to activate OpenGL rendering context', 'Error',
      MB_OK or MB_ICONERROR);
    Result := False;
    Exit;
  end;

  // Initializes the timer used to calculate the FPS
  SetTimer(h_Wnd, FPS_TIMER, FPS_INTERVAL, nil);

  // Settings to ensure that the window is the topmost window
  ShowWindow(h_Wnd, SW_SHOW);
  SetForegroundWindow(h_Wnd);
  SetFocus(h_Wnd);

  // Ensure the OpenGL window is resized properly
  glResizeWnd(Width, Height);
  glInit();

  Result := True;
end;


{--------------------------------------------------------------------}
{  Main message loop for the application                             }
{--------------------------------------------------------------------}
function WinMain(hInstance : HINST; hPrevInstance : HINST;
                 lpCmdLine : PChar; nCmdShow : Integer) : Integer; stdcall;
var
  msg : TMsg;
  finished : Boolean;
  DemoStart, LastTime : DWord;
begin
  finished := False;

  // Perform application initialization:
  if not glCreateWnd(800, 600, FALSE, 32) then
  begin
    Result := 0;
    Exit;
  end;

  DemoStart := GetTickCount();            // Get Time when demo started

  // Main message loop:
  while not finished do
  begin
    if (PeekMessage(msg, 0, 0, 0, PM_REMOVE)) then // Check if there is a message for this window
    begin
      if (msg.message = WM_QUIT) then     // If WM_QUIT message received then we are done
        finished := True
      else
      begin                               // Else translate and dispatch the message to this window
  	TranslateMessage(msg);
        DispatchMessage(msg);
      end;
    end
    else
    begin
      Inc(FPSCount);                      // Increment FPS Counter

      LastTime :=ElapsedTime;
      ElapsedTime :=GetTickCount() - DemoStart;     // Calculate Elapsed Time
      ElapsedTime :=(LastTime + ElapsedTime) DIV 2; // Average it out for smoother movement

      glDraw();                           // Draw the scene
      SwapBuffers(h_DC);                  // Display the scene

      if (keys[VK_ESCAPE]) then           // If user pressed ESC then set finised TRUE
        finished := True
      else
        ProcessKeys;                      // Check for any other key Pressed
    end;
  end;
  glKillWnd(FALSE);
  Result := msg.wParam;
end;


begin
  WinMain( hInstance, hPrevInst, CmdLine, CmdShow );
end.
