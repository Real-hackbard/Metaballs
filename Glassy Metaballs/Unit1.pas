unit Unit1;

interface

uses
  WinApi.Windows, OpenGLForm, OpenGL, Vcl.Forms, MetaBalls, BMP;

type
  TForm1 = class(TOpenGLWindow)
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormDestroy(Sender: TObject);
  end;

var
  Form1: TForm1;

const
  NumBalls = 6;            // The number of metaballs

const
  // Lighting parameters
  lpAmbient: TGLArrayf4 = (0.0, 0.0, 0.0, 1.0);
  lpDiffuse: TGLArrayf4 = (1.0, 1.0, 1.0, 1.0);
  lpPosition: TGLArrayf4 = (1.0, 1.0, 1.0, 1.0);

  // Material parameters
  mpSpecular: TGLArrayf4 = (1.0, 1.0, 1.0, 1.0);
  mpShininess: Single = 80.0;

var
  Tex: DWORD;              // Environment map texture
  Balls: TMetaBalls;       // The metaball system class
  EnvMap: Boolean = True;  // Evnvironment mapping flag

implementation

{$R *.DFM}

procedure TForm1.FormCreate(Sender: TObject);
var
  I: Integer;
  Tmp: TMetaBall;
begin
  // Enable texturing and load the texture
  glEnable(GL_TEXTURE_2D);
  LoadBMP('glass.bmp', Tex);

  // Set up the metaballs
  Balls := TMetaBalls.Create;
  Balls.Size := 7.5;
  for I := 0 to NumBalls - 1 do begin
    Tmp := TMetaBall.Create;
    Tmp.Radius := 0.8;
    Balls.Add(Tmp);
  end;

  // Set up environment mapping
  glEnable(GL_TEXTURE_GEN_S);
  glEnable(GL_TEXTURE_GEN_T);
  glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
  glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);

  // Set up lighting
  glEnable(GL_LIGHTING);
  glLightfv(GL_LIGHT0, GL_AMBIENT, @lpAmbient);
  glLightfv(GL_LIGHT0, GL_DIFFUSE, @lpDiffuse);
  glLightfv(GL_LIGHT0, GL_POSITION, @lpPosition);
  glMaterialfv(GL_FRONT, GL_SPECULAR, @mpSpecular);
  glMaterialf(GL_FRONT, GL_SHININESS, mpShininess);
  glEnable(GL_LIGHT0);

  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
  glShadeModel(GL_SMOOTH);
  glClearColor(0, 0, 0, 0);

  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  glClearDepth(1);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  if ClientHeight = 0 then ClientHeight := 1;
  glViewport(0, 0, ClientWidth, ClientHeight);
  glMatrixMode(GL_PROJECTION);                                                                            
  glLoadIdentity;
  gluPerspective(60, ClientWidth / ClientHeight, 0.1, 100.0);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;                                                                                         
end;

procedure TForm1.FormPaint(Sender: TObject);
var
  T: Single;
  I: Integer;
begin
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity;

  // Get the current time
  T := GetTickCount / 1000.0;

  // Set up the camera
  glTranslatef(0, 0, -8.0);

  // Set up metaball positions
  for I := 0 to NumBalls - 1 do begin
    Balls[I].Pos[0] := Sin(T * 1.5 + I / 0.3) * 2.0;
    Balls[I].Pos[1] := Cos(T * 2.5 + I / 0.4) * 2.0;
    Balls[I].Pos[2] := Cos(T * 3.5 + I / 0.5) * 2.0;
  end;

  // Render the metaballs
  Balls.Render;

  DoSwapBuffers;
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    // Close the demo
    Chr(27): Close;
    // Increase the grid size
    '+': if Balls.GridSize < 50 then
      Balls.GridSize := Balls.GridSize + 1;
    // Decrease the grid size
    '-': if Balls.GridSize > 15 then
      Balls.GridSize := Balls.GridSize - 1;
    // Toggle wireframe
    'w', 'W': Balls.Wireframe := not Balls.Wireframe;
    // Toggle texturing
    'e', 'E': begin
      EnvMap := not EnvMap;
      if EnvMap then begin
        glEnable(GL_TEXTURE_2D);     // Enable texturing
        glEnable(GL_TEXTURE_GEN_S);  // Enable texgen
        glEnable(GL_TEXTURE_GEN_T);
      end else begin
        glDisable(GL_TEXTURE_2D);    // Disable texturing
        glDisable(GL_TEXTURE_GEN_S); // Disable texgen
        glDisable(GL_TEXTURE_GEN_T);
      end;
    end;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Balls.Free;
end;

end.
