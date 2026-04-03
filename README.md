# Metaballs

</br>

![Compiler](https://github.com/user-attachments/assets/a916143d-3f1b-4e1f-b1e0-1067ef9e0401) ![10 Seattle](https://github.com/user-attachments/assets/c70b7f21-688a-4239-87c9-9a03a8ff25ab) ![10 1 Berlin](https://github.com/user-attachments/assets/bdcd48fc-9f09-4830-b82e-d38c20492362) ![10 2 Tokyo](https://github.com/user-attachments/assets/5bdb9f86-7f44-4f7e-aed2-dd08de170bd5) ![10 3 Rio](https://github.com/user-attachments/assets/e7d09817-54b6-4d71-a373-22ee179cd49c)  ![10 4 Sydney](https://github.com/user-attachments/assets/e75342ca-1e24-4a7e-8fe3-ce22f307d881) ![11 Alexandria](https://github.com/user-attachments/assets/64f150d0-286a-4edd-acab-9f77f92d68ad) ![12 Athens](https://github.com/user-attachments/assets/59700807-6abf-4e6d-9439-5dc70fc0ceca)  
![Components](https://github.com/user-attachments/assets/d6a7a7a4-f10e-4df1-9c4f-b4a1a8db7f0e) ![None](https://github.com/user-attachments/assets/30ebe930-c928-4aaf-a8e1-5f68ec1ff349)  
![Description](https://github.com/user-attachments/assets/dbf330e0-633c-4b31-a0ef-b1edb9ed5aa7) ![Metaballs](https://github.com/user-attachments/assets/3cc87c57-1329-4097-abea-a5b6377d158e)  
![Last Update](https://github.com/user-attachments/assets/e1d05f21-2a01-4ecf-94f3-b7bdff4d44dd) ![042026](https://github.com/user-attachments/assets/2446b1e1-a732-4080-97bc-11906d6ff389)  
![License](https://github.com/user-attachments/assets/ff71a38b-8813-4a79-8774-09a2f3893b48) ![Freeware](https://github.com/user-attachments/assets/1fea2bbf-b296-4152-badd-e1cdae115c43)  

</br>

In [computer graphics](https://en.wikipedia.org/wiki/Computer_graphics), metaballs, also known as blobby objects, are organic-looking n-dimensional [isosurfaces](https://en.wikipedia.org/wiki/Isosurface), characterised by their ability to meld together when in close proximity to create single, contiguous objects.

In [solid modelling](https://en.wikipedia.org/wiki/Solid_modeling), [polygon meshes](https://en.wikipedia.org/wiki/Polygon_mesh) are commonly used. In certain instances, however, metaballs are superior. A metaball's "blobby" appearance makes them versatile tools, often used to model organic objects and also to create base meshes for [sculpting](https://en.wikipedia.org/wiki/Digital_sculpting).

The technique for [rendering](https://en.wikipedia.org/wiki/Rendering_(computer_graphics)) metaballs was invented by Jim Blinn in the early 1980s to model atom interactions for Carl Sagan's 1980 TV series Cosmos. It is also referred to colloquially as the "jelly effect" in the [motion](https://en.wikipedia.org/wiki/Motion_graphic_design) and [UX design](https://en.wikipedia.org/wiki/User_experience_design) community, commonly appearing in UI elements such as navigations and buttons. Metaball behavior corresponds to [mitosis](https://en.wikipedia.org/wiki/Mitosis) in cell biology, where chromosomes generate identical copies of themselves through cell division.

# [Blender](https://www.blender.org/) Example:

</br>

![blender-metaballs-1](https://github.com/user-attachments/assets/29e0e1be-351b-4ccc-abcd-136b4dab01ee)

</br>

# Definition:
Each metaball is defined as a function in n dimensions (e.g., for three dimensions, ```f(x,y,z)``` three-dimensional metaballs tend to be most common, with two-dimensional implementations popular as well). A thresholding value is also chosen, to define a solid volume. Then,

### &Sigma; metaball (x,y,z) > thresold

that is, all points larger than the threshold are inside the metaball.

</br>

*  The influence of 2 positive metaballs on each other.
*  The influence of a negative metaball on a positive metaball by creating an indentation in the positive metaball's surface.

</br>

![influence](https://github.com/user-attachments/assets/6d165ceb-c1ea-415e-a0f1-241d186342d7)

</br>


A typical function chosen for metaballs is simply inverse distance, that is, the contribution to the thresholding function falls off asymptotically toward zero as the distance from the centre of the metaball increases.

</br>

![Metaball_contact_sheet](https://github.com/user-attachments/assets/1c01aed3-c7d3-422f-ae12-634ce390d433)

</br>

The interaction between two differently coloured 3D positive metaballs, created in Bryce.
Note that the two smaller metaballs combine to create one larger object.

# Drawing in high resolution (OpenGL):
```pascal
procedure glDraw();
var
  cx, cy, cz : Integer;
  X, Y, Z : Integer;
  I : Integer;
  c : glFloat;
begin
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);    // Clear The Screen And The Depth Buffer
  glLoadIdentity();                                       // Reset The View

  glTranslatef(0.0,0.0,-2.5);

  glDisable(GL_TEXTURE_GEN_S);
  glDisable(GL_TEXTURE_GEN_T);
  glBindTexture(GL_TEXTURE_2D, Background);
  glBegin(GL_QUADS);
    glTexCoord(0, 0);   glVertex(-1.5,-1.1, 0);
    glTexCoord(1, 0);   glVertex( 1.5,-1.1, 0);
    glTexCoord(1, 1);   glVertex( 1.5, 1.1, 0);
    glTexCoord(0, 1);   glVertex(-1.5, 1.1, 0);
  glEnd();
  glEnable(GL_TEXTURE_GEN_S);
  glEnable(GL_TEXTURE_GEN_T);

  glRotatef(ElapsedTime/30, 0, 0, 1);

  c := 0.15*cos(ElapsedTime/600);
  MetaBall[1].X :=-0.3*cos(ElapsedTime/700) - c;
  MetaBall[1].Y :=0.3*sin(ElapsedTime/600) - c;

  MetaBall[2].X :=0.4*sin(ElapsedTime/400) + c;
  MetaBall[2].Y :=0.4*cos(ElapsedTime/400) - c;

  MetaBall[3].X :=-0.4*cos(ElapsedTime/400) - 0.2*sin(ElapsedTime/600);
  MetaBall[3].y :=0.4*sin(ElapsedTime/500) - 0.2*sin(ElapsedTime/400);

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
               Value := Value + Radius*Radius /((Pos.x-x)*(Pos.x-x) +
                              (Pos.y-y)*(Pos.y-y) + (Pos.z-z)*(Pos.z-z));
          end;
        end;

  // Calculate normals at the grid vertices
  For cx := 1 to GridSize-1 do
  begin
    For cy := 1 to GridSize-1 do
    begin
      For cz := 1 to GridSize-1 do
      begin
        Grid[cx,cy,cz].Normal.X := Grid[cx-1, cy,
          cz].Value - Grid[cx+1, cy, cz].Value;
        Grid[cx,cy,cz].Normal.Y := Grid[cx, cy-1,
          cz].Value - Grid[cx, cy+1, cz].Value;
        Grid[cx,cy,cz].Normal.Z := Grid[cx, cy, cz-1].Value -
          Grid[cx, cy, cz+1].Value;
//        NormalizeVector(Grid[cx,cy,cz].Normal);
      end;
    end;
  end;

  // Draw the metaballs by drawing the triangle in each cube in the grid
  glBindTexture(GL_TEXTURE_2D, EnviroTex);
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
var
  cx, cy, cz : Integer;
begin
  glClearColor(0.0, 0.0, 0.0, 0.0); 	   // Black Background
  glShadeModel(GL_SMOOTH);                 // Enables Smooth Color Shading
  glEnable(GL_DEPTH_TEST);                 // Enable Depth Buffer
  glDepthFunc(GL_LESS);		           // The Type Of Depth Test To Do

  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);   //Realy Nice perspective calculations

  glEnable(GL_TEXTURE_2D);                     // Enable Texture Mapping
  LoadTexture('chrome.bmp', EnviroTex);
  LoadTexture('background.bmp', background);

  // Set up environment mapping
  glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
  glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
  glTexGeni(GL_S, GL_SPHERE_MAP, 0);
  glTexGeni(GL_T, GL_SPHERE_MAP, 0);

  glEnable(GL_NORMALIZE);

  // initialise the metaball size and positions
  MetaBall[1].Radius :=0.3;
  MetaBall[1].X :=0;
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

  Textured :=TRUE;
  SmoothShading :=TRUE;
  WireFrame :=FALSE;
  GridSize  :=25;
  InitGrid;
end;
```





