unit MetaBalls;

interface

uses OpenGL;

type
  // Taken from my vectors unit
  TGLVector = array[0..2] of Single;

  // A position on the voxel grid
  TVertex = record
    // Position vector
    Pos: TGLVector;
    // Normal vector
    Nrm: TGLVector;
    // Isovalue at this position
    Isovalue: Single;
  end;

  // A single voxel, defined by its vertices
  TGridCell = array[0..7] of ^TVertex;

  // A single metaball
  TMetaBall = class(TObject)
  public
    // Position vector
    Pos: TGLVector;
    // Radius of the metaball
    Radius: Single;
    // Evaluate this metaball at a given point
    function Evaluate(P: TGLVector): Single;
  end;

  // An array of metaball objects
  TMetaBalls = class(TObject)
  private
    // Resolution of the grid
    FGridSize: Integer;
    // Size of the grid
    FSize: Single;
    // Wireframe flag
    FWireframe: Boolean;
    // The actual array of metaballs
    FBalls: array of TMetaBall;
    // A dynamic array holding the grid vertices
    FVert: array of TVertex;
    // A dynamic array holding the grid voxels
    FGrid: array of TGridCell;
  protected
    // Set-and-get handlers for the metaballs array
    procedure SetMetaBall(I: Integer; Value: TMetaBall);
    function GetMetaBall(I: Integer): TMetaBall;
    // Set the size of the grid cell array
    procedure SetGridSize(Value: Integer);
    // Set the size of the grid
    procedure SetSize(Value: Single);
    // Resize the grid
    procedure ReCalculateGrid;
  public
    // Regular constructor
    constructor Create;
    // Add a metaball to the array
    procedure Add(Value: TMetaBall);
    // Evaluate all of the metaballs
    function Evaluate(P: TGLVector): Single;
    // The public metaball array -
    //   classes are essentially pointers so individual
    //   metaballs can be updated at runtime.
    property MetaBalls[I: Integer]: TMetaBall read GetMetaBall write SetMetaBall; default;
    // Wireframe flag.
    property Wireframe: Boolean read FWireframe write FWireframe;
    // Ammount of detail to use
    property GridSize: Integer read FGridSize write SetGridSize;
    // Size of the grid
    property Size: Single read FSize write SetSize;
    // Render the metaball grid
    procedure Render;
  end;

implementation

(*

  Look-up tables for the "Marching Cubes" algorithm
  Taken from Paul Bourke's site: http://astronomy.swin.edu.au/pbourke/

*)

const
  EdgeTable: array [0..255] of Integer = (
    $0000, $0109, $0203, $030A, $0406, $050F, $0605, $070C,
    $080C, $0905, $0A0F, $0B06, $0C0A, $0D03, $0E09, $0F00,
    $0190, $0099, $0393, $029A, $0596, $049F, $0795, $069C,
    $099C, $0895, $0B9F, $0A96, $0D9A, $0C93, $0F99, $0E90,
    $0230, $0339, $0033, $013A, $0636, $073F, $0435, $053C,
    $0A3C, $0B35, $083F, $0936, $0E3A, $0F33, $0C39, $0D30,
    $03A0, $02A9, $01A3, $00AA, $07A6, $06AF, $05A5, $04AC,
    $0BAC, $0AA5, $09AF, $08A6, $0FAA, $0EA3, $0DA9, $0CA0,
    $0460, $0569, $0663, $076A, $0066, $016F, $0265, $036C,
    $0C6C, $0D65, $0E6F, $0F66, $086A, $0963, $0A69, $0B60,
    $05F0, $04F9, $07F3, $06FA, $01F6, $00FF, $03F5, $02FC,
    $0DFC, $0CF5, $0FFF, $0EF6, $09FA, $08F3, $0BF9, $0AF0,
    $0650, $0759, $0453, $055A, $0256, $035F, $0055, $015C,
    $0E5C, $0F55, $0C5F, $0D56, $0A5A, $0B53, $0859, $0950,
    $07C0, $06C9, $05C3, $04CA, $03C6, $02CF, $01C5, $00CC,
    $0FCC, $0EC5, $0DCF, $0CC6, $0BCA, $0AC3, $09C9, $08C0,
    $08C0, $09C9, $0AC3, $0BCA, $0CC6, $0DCF, $0EC5, $0FCC,
    $00CC, $01C5, $02CF, $03C6, $04CA, $05C3, $06C9, $07C0,
    $0950, $0859, $0B53, $0A5A, $0D56, $0C5F, $0F55, $0E5C,
    $015C, $0055, $035F, $0256, $055A, $0453, $0759, $0650,
    $0AF0, $0BF9, $08F3, $09FA, $0EF6, $0FFF, $0CF5, $0DFC,
    $02FC, $03F5, $00FF, $01F6, $06FA, $07F3, $04F9, $05F0,
    $0B60, $0A69, $0963, $086A, $0F66, $0E6F, $0D65, $0C6C,
    $036C, $0265, $016F, $0066, $076A, $0663, $0569, $0460,
    $0CA0, $0DA9, $0EA3, $0FAA, $08A6, $09AF, $0AA5, $0BAC,
    $04AC, $05A5, $06AF, $07A6, $00AA, $01A3, $02A9, $03A0,
    $0D30, $0C39, $0F33, $0E3A, $0936, $083F, $0B35, $0A3C,
    $053C, $0435, $073F, $0636, $013A, $0033, $0339, $0230,
    $0E90, $0F99, $0C93, $0D9A, $0A96, $0B9F, $0895, $099C,
    $069C, $0795, $049F, $0596, $029A, $0393, $0099, $0190,
    $0F00, $0E09, $0D03, $0C0A, $0B06, $0A0F, $0905, $080C,
    $070C, $0605, $050F, $0406, $030A, $0203, $0109, $0000
  );

  TriTable: array[0..255,  0..15] of Integer = (
    (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  8,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  1,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 1,  8,  3,  9,  8,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 1,  2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  8,  3,  1,  2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 9,  2, 10,  0,  2,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 2,  8,  3,  2, 10,  8, 10,  9,  8, -1, -1, -1, -1, -1, -1, -1), 
    ( 3, 11,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0, 11,  2,  8, 11,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 1,  9,  0,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 1, 11,  2,  1,  9, 11,  9,  8, 11, -1, -1, -1, -1, -1, -1, -1), 
    ( 3, 10,  1, 11, 10,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0, 10,  1,  0,  8, 10,  8, 11, 10, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  9,  0,  3, 11,  9, 11, 10,  9, -1, -1, -1, -1, -1, -1, -1),
    ( 9,  8, 10, 10,  8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  7,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  3,  0,  7,  3,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  1,  9,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  1,  9,  4,  7,  1,  7,  3,  1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 10,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  4,  7,  3,  0,  4,  1,  2, 10, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  2, 10,  9,  0,  2,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 2, 10,  9,  2,  9,  7,  2,  7,  3,  7,  9,  4, -1, -1, -1, -1), 
    ( 8,  4,  7,  3, 11,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (11,  4,  7, 11,  2,  4,  2,  0,  4, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  0,  1,  8,  4,  7,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  7, 11,  9,  4, 11,  9, 11,  2,  9,  2,  1, -1, -1, -1, -1), 
    ( 3, 10,  1,  3, 11, 10,  7,  8,  4, -1, -1, -1, -1, -1, -1, -1), 
    ( 1, 11, 10,  1,  4, 11,  1,  0,  4,  7, 11,  4, -1, -1, -1, -1), 
    ( 4,  7,  8,  9,  0, 11,  9, 11, 10, 11,  0,  3, -1, -1, -1, -1),
    ( 4,  7, 11,  4, 11,  9,  9, 11, 10, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  5,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  5,  4,  0,  8,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  5,  4,  1,  5,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  5,  4,  8,  3,  5,  3,  1,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 10,  9,  5,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  0,  8,  1,  2, 10,  4,  9,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 5,  2, 10,  5,  4,  2,  4,  0,  2, -1, -1, -1, -1, -1, -1, -1), 
    ( 2, 10,  5,  3,  2,  5,  3,  5,  4,  3,  4,  8, -1, -1, -1, -1), 
    ( 9,  5,  4,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0, 11,  2,  0,  8, 11,  4,  9,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  5,  4,  0,  1,  5,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1), 
    ( 2,  1,  5,  2,  5,  8,  2,  8, 11,  4,  8,  5, -1, -1, -1, -1), 
    (10,  3, 11, 10,  1,  3,  9,  5,  4, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  9,  5,  0,  8,  1,  8, 10,  1,  8, 11, 10, -1, -1, -1, -1), 
    ( 5,  4,  0,  5,  0, 11,  5, 11, 10, 11,  0,  3, -1, -1, -1, -1),
    ( 5,  4,  8,  5,  8, 10, 10,  8, 11, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  7,  8,  5,  7,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  3,  0,  9,  5,  3,  5,  7,  3, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  7,  8,  0,  1,  7,  1,  5,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  5,  3,  3,  5,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  7,  8,  9,  5,  7, 10,  1,  2, -1, -1, -1, -1, -1, -1, -1), 
    (10,  1,  2,  9,  5,  0,  5,  3,  0,  5,  7,  3, -1, -1, -1, -1), 
    ( 8,  0,  2,  8,  2,  5,  8,  5,  7, 10,  5,  2, -1, -1, -1, -1), 
    ( 2, 10,  5,  2,  5,  3,  3,  5,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 7,  9,  5,  7,  8,  9,  3, 11,  2, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  5,  7,  9,  7,  2,  9,  2,  0,  2,  7, 11, -1, -1, -1, -1), 
    ( 2,  3, 11,  0,  1,  8,  1,  7,  8,  1,  5,  7, -1, -1, -1, -1), 
    (11,  2,  1, 11,  1,  7,  7,  1,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  5,  8,  8,  5,  7, 10,  1,  3, 10,  3, 11, -1, -1, -1, -1), 
    ( 5,  7,  0,  5,  0,  9,  7, 11,  0,  1,  0, 10, 11, 10,  0, -1), 
    (11, 10,  0, 11,  0,  3, 10,  5,  0,  8,  0,  7,  5,  7,  0, -1),
    (11, 10,  5,  7, 11,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (10,  6,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  3,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  0,  1,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  8,  3,  1,  9,  8,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  6,  5,  2,  6,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  6,  5,  1,  2,  6,  3,  0,  8, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  6,  5,  9,  0,  6,  0,  2,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 5,  9,  8,  5,  8,  2,  5,  2,  6,  3,  2,  8, -1, -1, -1, -1), 
    ( 2,  3, 11, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (11,  0,  8, 11,  2,  0, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  1,  9,  2,  3, 11,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 5, 10,  6,  1,  9,  2,  9, 11,  2,  9,  8, 11, -1, -1, -1, -1), 
    ( 6,  3, 11,  6,  5,  3,  5,  1,  3, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8, 11,  0, 11,  5,  0,  5,  1,  5, 11,  6, -1, -1, -1, -1), 
    ( 3, 11,  6,  0,  3,  6,  0,  6,  5,  0,  5,  9, -1, -1, -1, -1),
    ( 6,  5,  9,  6,  9, 11, 11,  9,  8, -1, -1, -1, -1, -1, -1, -1), 
    ( 5, 10,  6,  4,  7,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  3,  0,  4,  7,  3,  6,  5, 10, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  9,  0,  5, 10,  6,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1), 
    (10,  6,  5,  1,  9,  7,  1,  7,  3,  7,  9,  4, -1, -1, -1, -1), 
    ( 6,  1,  2,  6,  5,  1,  4,  7,  8, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2,  5,  5,  2,  6,  3,  0,  4,  3,  4,  7, -1, -1, -1, -1), 
    ( 8,  4,  7,  9,  0,  5,  0,  6,  5,  0,  2,  6, -1, -1, -1, -1), 
    ( 7,  3,  9,  7,  9,  4,  3,  2,  9,  5,  9,  6,  2,  6,  9, -1), 
    ( 3, 11,  2,  7,  8,  4, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 5, 10,  6,  4,  7,  2,  4,  2,  0,  2,  7, 11, -1, -1, -1, -1), 
    ( 0,  1,  9,  4,  7,  8,  2,  3, 11,  5, 10,  6, -1, -1, -1, -1), 
    ( 9,  2,  1,  9, 11,  2,  9,  4, 11,  7, 11,  4,  5, 10,  6, -1), 
    ( 8,  4,  7,  3, 11,  5,  3,  5,  1,  5, 11,  6, -1, -1, -1, -1), 
    ( 5,  1, 11,  5, 11,  6,  1,  0, 11,  7, 11,  4,  0,  4, 11, -1), 
    ( 0,  5,  9,  0,  6,  5,  0,  3,  6, 11,  6,  3,  8,  4,  7, -1),
    ( 6,  5,  9,  6,  9, 11,  4,  7,  9,  7, 11,  9, -1, -1, -1, -1), 
    (10,  4,  9,  6,  4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4, 10,  6,  4,  9, 10,  0,  8,  3, -1, -1, -1, -1, -1, -1, -1), 
    (10,  0,  1, 10,  6,  0,  6,  4,  0, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  3,  1,  8,  1,  6,  8,  6,  4,  6,  1, 10, -1, -1, -1, -1), 
    ( 1,  4,  9,  1,  2,  4,  2,  6,  4, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  0,  8,  1,  2,  9,  2,  4,  9,  2,  6,  4, -1, -1, -1, -1), 
    ( 0,  2,  4,  4,  2,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  3,  2,  8,  2,  4,  4,  2,  6, -1, -1, -1, -1, -1, -1, -1), 
    (10,  4,  9, 10,  6,  4, 11,  2,  3, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  2,  2,  8, 11,  4,  9, 10,  4, 10,  6, -1, -1, -1, -1), 
    ( 3, 11,  2,  0,  1,  6,  0,  6,  4,  6,  1, 10, -1, -1, -1, -1), 
    ( 6,  4,  1,  6,  1, 10,  4,  8,  1,  2,  1, 11,  8, 11,  1, -1), 
    ( 9,  6,  4,  9,  3,  6,  9,  1,  3, 11,  6,  3, -1, -1, -1, -1), 
    ( 8, 11,  1,  8,  1,  0, 11,  6,  1,  9,  1,  4,  6,  4,  1, -1), 
    ( 3, 11,  6,  3,  6,  0,  0,  6,  4, -1, -1, -1, -1, -1, -1, -1),
    ( 6,  4,  8, 11,  6,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 7, 10,  6,  7,  8, 10,  8,  9, 10, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  7,  3,  0, 10,  7,  0,  9, 10,  6,  7, 10, -1, -1, -1, -1), 
    (10,  6,  7,  1, 10,  7,  1,  7,  8,  1,  8,  0, -1, -1, -1, -1), 
    (10,  6,  7, 10,  7,  1,  1,  7,  3, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2,  6,  1,  6,  8,  1,  8,  9,  8,  6,  7, -1, -1, -1, -1), 
    ( 2,  6,  9,  2,  9,  1,  6,  7,  9,  0,  9,  3,  7,  3,  9, -1), 
    ( 7,  8,  0,  7,  0,  6,  6,  0,  2, -1, -1, -1, -1, -1, -1, -1), 
    ( 7,  3,  2,  6,  7,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 2,  3, 11, 10,  6,  8, 10,  8,  9,  8,  6,  7, -1, -1, -1, -1), 
    ( 2,  0,  7,  2,  7, 11,  0,  9,  7,  6,  7, 10,  9, 10,  7, -1), 
    ( 1,  8,  0,  1,  7,  8,  1, 10,  7,  6,  7, 10,  2,  3, 11, -1), 
    (11,  2,  1, 11,  1,  7, 10,  6,  1,  6,  7,  1, -1, -1, -1, -1), 
    ( 8,  9,  6,  8,  6,  7,  9,  1,  6, 11,  6,  3,  1,  3,  6, -1), 
    ( 0,  9,  1, 11,  6,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 7,  8,  0,  7,  0,  6,  3, 11,  0, 11,  6,  0, -1, -1, -1, -1), 
    ( 7, 11,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 7,  6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  0,  8, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  1,  9, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  1,  9,  8,  3,  1, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1), 
    (10,  1,  2,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 10,  3,  0,  8,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 2,  9,  0,  2, 10,  9,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 6, 11,  7,  2, 10,  3, 10,  8,  3, 10,  9,  8, -1, -1, -1, -1), 
    ( 7,  2,  3,  6,  2,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 7,  0,  8,  7,  6,  0,  6,  2,  0, -1, -1, -1, -1, -1, -1, -1), 
    ( 2,  7,  6,  2,  3,  7,  0,  1,  9, -1, -1, -1, -1, -1, -1, -1),
    ( 1,  6,  2,  1,  8,  6,  1,  9,  8,  8,  7,  6, -1, -1, -1, -1), 
    (10,  7,  6, 10,  1,  7,  1,  3,  7, -1, -1, -1, -1, -1, -1, -1), 
    (10,  7,  6,  1,  7, 10,  1,  8,  7,  1,  0,  8, -1, -1, -1, -1), 
    ( 0,  3,  7,  0,  7, 10,  0, 10,  9,  6, 10,  7, -1, -1, -1, -1), 
    ( 7,  6, 10,  7, 10,  8,  8, 10,  9, -1, -1, -1, -1, -1, -1, -1), 
    ( 6,  8,  4, 11,  8,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  6, 11,  3,  0,  6,  0,  4,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  6, 11,  8,  4,  6,  9,  0,  1, -1, -1, -1, -1, -1, -1, -1),
    ( 9,  4,  6,  9,  6,  3,  9,  3,  1, 11,  3,  6, -1, -1, -1, -1), 
    ( 6,  8,  4,  6, 11,  8,  2, 10,  1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 10,  3,  0, 11,  0,  6, 11,  0,  4,  6, -1, -1, -1, -1), 
    ( 4, 11,  8,  4,  6, 11,  0,  2,  9,  2, 10,  9, -1, -1, -1, -1), 
    (10,  9,  3, 10,  3,  2,  9,  4,  3, 11,  3,  6,  4,  6,  3, -1), 
    ( 8,  2,  3,  8,  4,  2,  4,  6,  2, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  4,  2,  4,  6,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  9,  0,  2,  3,  4,  2,  4,  6,  4,  3,  8, -1, -1, -1, -1),
    ( 1,  9,  4,  1,  4,  2,  2,  4,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  1,  3,  8,  6,  1,  8,  4,  6,  6, 10,  1, -1, -1, -1, -1), 
    (10,  1,  0, 10,  0,  6,  6,  0,  4, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  6,  3,  4,  3,  8,  6, 10,  3,  0,  3,  9, 10,  9,  3, -1), 
    (10,  9,  4,  6, 10,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  9,  5,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  3,  4,  9,  5, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1), 
    ( 5,  0,  1,  5,  4,  0,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1), 
    (11,  7,  6,  8,  3,  4,  3,  5,  4,  3,  1,  5, -1, -1, -1, -1), 
    ( 9,  5,  4, 10,  1,  2,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1),
    ( 6, 11,  7,  1,  2, 10,  0,  8,  3,  4,  9,  5, -1, -1, -1, -1), 
    ( 7,  6, 11,  5,  4, 10,  4,  2, 10,  4,  0,  2, -1, -1, -1, -1), 
    ( 3,  4,  8,  3,  5,  4,  3,  2,  5, 10,  5,  2, 11,  7,  6, -1), 
    ( 7,  2,  3,  7,  6,  2,  5,  4,  9, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  5,  4,  0,  8,  6,  0,  6,  2,  6,  8,  7, -1, -1, -1, -1), 
    ( 3,  6,  2,  3,  7,  6,  1,  5,  0,  5,  4,  0, -1, -1, -1, -1), 
    ( 6,  2,  8,  6,  8,  7,  2,  1,  8,  4,  8,  5,  1,  5,  8, -1), 
    ( 9,  5,  4, 10,  1,  6,  1,  7,  6,  1,  3,  7, -1, -1, -1, -1), 
    ( 1,  6, 10,  1,  7,  6,  1,  0,  7,  8,  7,  0,  9,  5,  4, -1), 
    ( 4,  0, 10,  4, 10,  5,  0,  3, 10,  6, 10,  7,  3,  7, 10, -1),
    ( 7,  6, 10,  7, 10,  8,  5,  4, 10,  4,  8, 10, -1, -1, -1, -1), 
    ( 6,  9,  5,  6, 11,  9, 11,  8,  9, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  6, 11,  0,  6,  3,  0,  5,  6,  0,  9,  5, -1, -1, -1, -1), 
    ( 0, 11,  8,  0,  5, 11,  0,  1,  5,  5,  6, 11, -1, -1, -1, -1), 
    ( 6, 11,  3,  6,  3,  5,  5,  3,  1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 10,  9,  5, 11,  9, 11,  8, 11,  5,  6, -1, -1, -1, -1), 
    ( 0, 11,  3,  0,  6, 11,  0,  9,  6,  5,  6,  9,  1,  2, 10, -1), 
    (11,  8,  5, 11,  5,  6,  8,  0,  5, 10,  5,  2,  0,  2,  5, -1), 
    ( 6, 11,  3,  6,  3,  5,  2, 10,  3, 10,  5,  3, -1, -1, -1, -1), 
    ( 5,  8,  9,  5,  2,  8,  5,  6,  2,  3,  8,  2, -1, -1, -1, -1),
    ( 9,  5,  6,  9,  6,  0,  0,  6,  2, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  5,  8,  1,  8,  0,  5,  6,  8,  3,  8,  2,  6,  2,  8, -1), 
    ( 1,  5,  6,  2,  1,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  3,  6,  1,  6, 10,  3,  8,  6,  5,  6,  9,  8,  9,  6, -1), 
    (10,  1,  0, 10,  0,  6,  9,  5,  0,  5,  6,  0, -1, -1, -1, -1), 
    ( 0,  3,  8,  5,  6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (10,  5,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (11,  5, 10,  7,  5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    (11,  5, 10, 11,  7,  5,  8,  3,  0, -1, -1, -1, -1, -1, -1, -1),
    ( 5, 11,  7,  5, 10, 11,  1,  9,  0, -1, -1, -1, -1, -1, -1, -1), 
    (10,  7,  5, 10, 11,  7,  9,  8,  1,  8,  3,  1, -1, -1, -1, -1), 
    (11,  1,  2, 11,  7,  1,  7,  5,  1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  3,  1,  2,  7,  1,  7,  5,  7,  2, 11, -1, -1, -1, -1), 
    ( 9,  7,  5,  9,  2,  7,  9,  0,  2,  2, 11,  7, -1, -1, -1, -1), 
    ( 7,  5,  2,  7,  2, 11,  5,  9,  2,  3,  2,  8,  9,  8,  2, -1), 
    ( 2,  5, 10,  2,  3,  5,  3,  7,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  2,  0,  8,  5,  2,  8,  7,  5, 10,  2,  5, -1, -1, -1, -1), 
    ( 9,  0,  1,  5, 10,  3,  5,  3,  7,  3, 10,  2, -1, -1, -1, -1), 
    ( 9,  8,  2,  9,  2,  1,  8,  7,  2, 10,  2,  5,  7,  5,  2, -1),
    ( 1,  3,  5,  3,  7,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  7,  0,  7,  1,  1,  7,  5, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  0,  3,  9,  3,  5,  5,  3,  7, -1, -1, -1, -1, -1, -1, -1), 
    ( 9,  8,  7,  5,  9,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 5,  8,  4,  5, 10,  8, 10, 11,  8, -1, -1, -1, -1, -1, -1, -1), 
    ( 5,  0,  4,  5, 11,  0,  5, 10, 11, 11,  3,  0, -1, -1, -1, -1), 
    ( 0,  1,  9,  8,  4, 10,  8, 10, 11, 10,  4,  5, -1, -1, -1, -1), 
    (10, 11,  4, 10,  4,  5, 11,  3,  4,  9,  4,  1,  3,  1,  4, -1), 
    ( 2,  5,  1,  2,  8,  5,  2, 11,  8,  4,  5,  8, -1, -1, -1, -1), 
    ( 0,  4, 11,  0, 11,  3,  4,  5, 11,  2, 11,  1,  5,  1, 11, -1), 
    ( 0,  2,  5,  0,  5,  9,  2, 11,  5,  4,  5,  8, 11,  8,  5, -1), 
    ( 9,  4,  5,  2, 11,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 2,  5, 10,  3,  5,  2,  3,  4,  5,  3,  8,  4, -1, -1, -1, -1), 
    ( 5, 10,  2,  5,  2,  4,  4,  2,  0, -1, -1, -1, -1, -1, -1, -1), 
    ( 3, 10,  2,  3,  5, 10,  3,  8,  5,  4,  5,  8,  0,  1,  9, -1), 
    ( 5, 10,  2,  5,  2,  4,  1,  9,  2,  9,  4,  2, -1, -1, -1, -1), 
    ( 8,  4,  5,  8,  5,  3,  3,  5,  1, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  4,  5,  1,  0,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 8,  4,  5,  8,  5,  3,  9,  0,  5,  0,  3,  5, -1, -1, -1, -1), 
    ( 9,  4,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4, 11,  7,  4,  9, 11,  9, 10, 11, -1, -1, -1, -1, -1, -1, -1), 
    ( 0,  8,  3,  4,  9,  7,  9, 11,  7,  9, 10, 11, -1, -1, -1, -1), 
    ( 1, 10, 11,  1, 11,  4,  1,  4,  0,  7,  4, 11, -1, -1, -1, -1), 
    ( 3,  1,  4,  3,  4,  8,  1, 10,  4,  7,  4, 11, 10, 11,  4, -1),
    ( 4, 11,  7,  9, 11,  4,  9,  2, 11,  9,  1,  2, -1, -1, -1, -1), 
    ( 9,  7,  4,  9, 11,  7,  9,  1, 11,  2, 11,  1,  0,  8,  3, -1), 
    (11,  7,  4, 11,  4,  2,  2,  4,  0, -1, -1, -1, -1, -1, -1, -1), 
    (11,  7,  4, 11,  4,  2,  8,  3,  4,  3,  2,  4, -1, -1, -1, -1), 
    ( 2,  9, 10,  2,  7,  9,  2,  3,  7,  7,  4,  9, -1, -1, -1, -1), 
    ( 9, 10,  7,  9,  7,  4, 10,  2,  7,  8,  7,  0,  2,  0,  7, -1),
    ( 3,  7, 10,  3, 10,  2,  7,  4, 10,  1, 10,  0,  4,  0, 10, -1), 
    ( 1, 10,  2,  8,  7,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  9,  1,  4,  1,  7,  7,  1,  3, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  9,  1,  4,  1,  7,  0,  8,  1,  8,  7,  1, -1, -1, -1, -1), 
    ( 4,  0,  3,  7,  4,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 4,  8,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 9, 10,  8, 10, 11,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 3,  0,  9,  3,  9, 11, 11,  9, 10, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  1, 10,  0, 10,  8,  8, 10, 11, -1, -1, -1, -1, -1, -1, -1),
    ( 3,  1, 10, 11,  3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1), 
    ( 1,  2, 11,  1, 11,  9,  9, 11,  8, -1, -1, -1, -1, -1, -1, -1),
    ( 3,  0,  9,  3,  9, 11,  1,  2,  9,  2, 11,  9, -1, -1, -1, -1),
    ( 0,  2, 11,  8,  0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 3,  2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 2,  3,  8,  2,  8, 10, 10,  8,  9, -1, -1, -1, -1, -1, -1, -1),
    ( 9, 10,  2,  0,  9,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 2,  3,  8,  2,  8, 10,  0,  1,  8,  1, 10,  8, -1, -1, -1, -1),
    ( 1, 10,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 1,  3,  8,  9,  1,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  9,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    ( 0,  3,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1),
    (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)
  );

(*--- Vector functions ---*)

procedure NormalizeVector(var V: TGLVector);
var
  Len: Single;
begin
  Len := Sqrt(V[0] * V[0] + V[1] * V[1] + V[2] * V[2]);
  if (Len = 0) or (Len = 1) then Exit;
  V[0] := V[0] / Len;
  V[1] := V[1] / Len;
  V[2] := V[2] / Len;
end;

(*--- Interpolate between two vertices ---*)

procedure Interpolate(V1, V2: TVertex; var Pos, Nrm: TGLVector);
var
  Amt: Single;
begin
  if (V1.Isovalue = 1.0) then begin
    Pos := V1.Pos;
    Nrm := V1.Nrm;
    Exit;
  end;

  if (V2.Isovalue = 1.0) then begin
    Pos := V2.Pos;
    Nrm := V2.Nrm;
    Exit;
  end;

  if (V1.Isovalue = V2.Isovalue) then begin
    Pos := V1.Pos;
    Nrm := V1.Nrm;
    Exit;
  end;

  // Get the distance travelled between vertices
  Amt := (1 - V1.Isovalue) / (V2.Isovalue - V1.Isovalue);

  // Interpolate the position vector
  Pos[0] := V1.Pos[0] + (V2.Pos[0] - V1.Pos[0]) * Amt;
  Pos[1] := V1.Pos[1] + (V2.Pos[1] - V1.Pos[1]) * Amt;
  Pos[2] := V1.Pos[2] + (V2.Pos[2] - V1.Pos[2]) * Amt;

  // Interpolate the normal vector
  Nrm[0] := V1.Nrm[0] + (V2.Nrm[0] - V1.Nrm[0]) * Amt;
  Nrm[1] := V1.Nrm[1] + (V2.Nrm[1] - V1.Nrm[1]) * Amt;
  Nrm[2] := V1.Nrm[2] + (V2.Nrm[2] - V1.Nrm[2]) * Amt;
end;

(*--- TMetaBall Implementation ---*)

function TMetaBall.Evaluate(P: TGLVector): Single;
begin
  // Evaulate a single metaball
  Result := Sqr(Radius) / (Sqr(P[0] - Pos[0]) + Sqr(P[1] - Pos[1]) + Sqr(P[2] - Pos[2]));
end;

(*--- TMetaBalls Implementation ---*)

constructor TMetaBalls.Create;
begin
  inherited Create;

  FSize := 1.0;
  FGridSize := 25;
  FWireframe := False;
  ReCalculateGrid;
end;

procedure TMetaBalls.Add(Value: TMetaBall);
begin
  // Add a metaball to the array
  SetLength(FBalls, Length(FBalls) + 1);
  SetMetaBall(Length(FBalls) - 1, Value);
end;

function TMetaBalls.Evaluate(P: TGLVector): Single;
var
  I: Integer;
begin
  Result := 0.0;
  // Add all metaballs together
  for I := 0 to Length(FBalls) - 1 do
    Result := Result + GetMetaBall(I).Evaluate(P);
end;

function GetGridSize(X: Integer): Integer;
begin
  // Calculate X^3-1 - used to find the number
  // of vertices in the grid
  Result := X * X * X - 1;
end;

function GetIndex(X, Y, Z, Res: Integer): Integer;
var
  I: Integer;
begin
  I := Res - 1;
  // Get the index of an item in the 3D array
  Result := (X * I * I) + (Y * I) + Z;
end;

procedure TMetaBalls.Render;
var
  X, Y, Z: Integer;

  (*--- Render a single cell on the grid ---*)

  procedure RenderCell(Cell: TGridCell);
  var
    I: Integer;
    CellIndex: Cardinal;            // Used to get the correct edge
    Pos: array[0..11] of TGLVector; // Position vectors for each edge
    Nrm: array[0..11] of TGLVector; // Normal vectors for each edge
  begin
    // Get the correct CellIndex value depending
    // on which vertices are inside / outside the isosurface.
    CellIndex := 0;
    if Cell[0]^.Isovalue < 1.0 then CellIndex := CellIndex or 1;
    if Cell[1]^.Isovalue < 1.0 then CellIndex := CellIndex or 2;
    if Cell[2]^.Isovalue < 1.0 then CellIndex := CellIndex or 4;
    if Cell[3]^.Isovalue < 1.0 then CellIndex := CellIndex or 8;
    if Cell[4]^.Isovalue < 1.0 then CellIndex := CellIndex or 16;
    if Cell[5]^.Isovalue < 1.0 then CellIndex := CellIndex or 32;
    if Cell[6]^.Isovalue < 1.0 then CellIndex := CellIndex or 64;
    if Cell[7]^.Isovalue < 1.0 then CellIndex := CellIndex or 128;
  
    // Interpolate cell boundaries depending
    // on the value of CellIndex.
    if (EdgeTable[CellIndex] = 0) then Exit;
    if (EdgeTable[CellIndex] and 1) <> 0 then Interpolate(Cell[0]^, Cell[1]^, Pos[0], Nrm[0]);
    if (EdgeTable[CellIndex] and 2) <> 0 then Interpolate(Cell[1]^, Cell[2]^, Pos[1], Nrm[1]);
    if (EdgeTable[CellIndex] and 4) <> 0 then Interpolate(Cell[2]^, Cell[3]^, Pos[2], Nrm[2]);
    if (EdgeTable[CellIndex] and 8) <> 0 then Interpolate(Cell[3]^, Cell[0]^, Pos[3], Nrm[3]);
    if (EdgeTable[CellIndex] and 16) <> 0 then Interpolate(Cell[4]^, Cell[5]^, Pos[4], Nrm[4]);
    if (EdgeTable[CellIndex] and 32) <> 0 then Interpolate(Cell[5]^, Cell[6]^, Pos[5], Nrm[5]);
    if (EdgeTable[CellIndex] and 64) <> 0 then Interpolate(Cell[6]^, Cell[7]^, Pos[6], Nrm[6]);
    if (EdgeTable[CellIndex] and 128) <> 0 then Interpolate(Cell[7]^, Cell[4]^, Pos[7], Nrm[7]);
    if (EdgeTable[CellIndex] and 256) <> 0 then Interpolate(Cell[0]^, Cell[4]^, Pos[8], Nrm[8]);
    if (EdgeTable[CellIndex] and 512) <> 0 then Interpolate(Cell[1]^, Cell[5]^, Pos[9], Nrm[9]);
    if (EdgeTable[CellIndex] and 1024) <> 0 then Interpolate(Cell[2]^, Cell[6]^, Pos[10], Nrm[10]);
    if (EdgeTable[CellIndex] and 2048) <> 0 then Interpolate(Cell[3]^, Cell[7]^, Pos[11], Nrm[11]);
  
    I := 0;
  
    (*--- Iterate through the look-up table ---*)
  
    while (TriTable[CellIndex, I] <> -1) do begin
  
      // Use the correct primitives depending on
      // the wireframe flag
  
      if FWireframe then
        glBegin(GL_LINE_LOOP) else
        glBegin(GL_TRIANGLES);
  
      // Render the surface with smooth normals
      glNormal3fv(@Nrm[TriTable[CellIndex, I]]);
      glVertex3fv(@Pos[TriTable[CellIndex, I]]);
      glNormal3fv(@Nrm[TriTable[CellIndex, I + 1]]);
      glVertex3fv(@Pos[TriTable[CellIndex, I + 1]]);
      glNormal3fv(@Nrm[TriTable[CellIndex, I + 2]]);
      glVertex3fv(@Pos[TriTable[CellIndex, I + 2]]);
  
      glEnd;
  
      Inc(I, 3);
    end;
  end;

begin
  for X := 0 to FGridSize do
    for Y := 0 to FGridSize do
      for Z := 0 to FGridSize do
        // Set up the vertex table with correct isovalues
        FVert[GetIndex(X, Y, Z, FGridSize)].Isovalue := Evaluate(FVert[GetIndex(X, Y, Z, FGridSize)].Pos);

  for X := 1 to FGridSize - 1 do
    for Y := 1 to FGridSize - 1 do
      for Z := 1 to FGridSize - 1 do begin
        // Calculate normals at the grid vertices
        // The normal for each axis is proportional to the change in isovalue
        // as we move along the axis - however, doing things this way means we
        // can not go all the way to the edge of the grid, but this is not
        // usually a problem.
        FVert[GetIndex(X, Y, Z, FGridSize)].Nrm[0] := FVert[GetIndex(X - 1, Y, Z, FGridSize)].Isovalue - FVert[GetIndex(X + 1, Y, Z, FGridSize)].Isovalue;
        FVert[GetIndex(X, Y, Z, FGridSize)].Nrm[1] := FVert[GetIndex(X, Y - 1, Z, FGridSize)].Isovalue - FVert[GetIndex(X, Y + 1, Z, FGridSize)].Isovalue;
        FVert[GetIndex(X, Y, Z, FGridSize)].Nrm[2] := FVert[GetIndex(X, Y, Z - 1, FGridSize)].Isovalue - FVert[GetIndex(X, Y, Z + 1, FGridSize)].Isovalue;
        NormalizeVector(FVert[GetIndex(X, Y, Z, FGridSize)].Nrm);
      end;

  for X := 0 to FGridSize - 1 do
    for Y := 0 to FGridSize - 1 do
      for Z := 0 to FGridSize - 1 do
        // Render each grid cell individually
        RenderCell(FGrid[GetIndex(X, Y, Z, FGridSize - 1)]);
end;

procedure TMetaBalls.ReCalculateGrid;
var
  X, Y, Z: Integer;
begin
  // Set the size of the arrays
  SetLength(FVert, GetGridSize(FGridSize));
  SetLength(FGrid, GetGridSize(FGridSize - 1));

  // Set up grid positions
  for X := 0 to FGridSize do
    for Y := 0 to FGridSize do
      for Z := 0 to FGridSize do begin
        FVert[GetIndex(X, Y, Z, FGridSize)].Pos[0] := X / FGridSize * FSize - FSize / 2;
        FVert[GetIndex(X, Y, Z, FGridSize)].Pos[1] := Y / FGridSize * FSize - FSize / 2;
        FVert[GetIndex(X, Y, Z, FGridSize)].Pos[2] := Z / FGridSize * FSize - FSize / 2;
      end;

  // Set up the vertex map
  for X := 0 to FGridSize - 1 do
    for Y := 0 to FGridSize - 1 do
      for Z := 0 to FGridSize - 1 do begin
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][0] := @FVert[GetIndex(X, Y, Z, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][1] := @FVert[GetIndex(X + 1, Y, Z, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][2] := @FVert[GetIndex(X + 1, Y + 1, Z, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][3] := @FVert[GetIndex(X, Y + 1, Z, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][4] := @FVert[GetIndex(X, Y, Z + 1, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][5] := @FVert[GetIndex(X + 1, Y, Z + 1, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][6] := @FVert[GetIndex(X + 1, Y + 1, Z + 1, FGridSize)];
        FGrid[GetIndex(X, Y, Z, FGridSize - 1)][7] := @FVert[GetIndex(X, Y + 1, Z + 1, FGridSize)];
      end;
end;

(*--- Array access methods ---*)

procedure TMetaBalls.SetMetaBall(I: Integer; Value: TMetaBall);
begin
  FBalls[I] := Value;
end;

function TMetaBalls.GetMetaBall(I: Integer): TMetaBall;
begin
  Result := FBalls[I];
end;

procedure TMetaBalls.SetGridSize(Value: Integer);
begin
  FGridSize := Value;
  ReCalculateGrid;
end;

procedure TMetaBalls.SetSize(Value: Single);
begin
  FSize := Value;
  ReCalculateGrid;
end;

end.
