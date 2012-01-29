// copied from http://en.wikipedia.org/wiki/Hilbert_curve
// with wrappers to use gl3n vectors

module Hilbert;

import std.stdio;

import gl3n.linalg;


unittest
{
  assert(vectorToScalar(vec2i(0,0)) == 0, "Expected " ~ to!string(0) ~ ", got " ~ to!string(vectorToScalar(vec2i(0,0))));
  assert(vectorToScalar(vec2i(0,1)) == 1, "Expected " ~ to!string(1) ~ ", got " ~ to!string(vectorToScalar(vec2i(0,1))));
  assert(vectorToScalar(vec2i(1,1)) == 2, "Expected " ~ to!string(2) ~ ", got " ~ to!string(vectorToScalar(vec2i(1,1))));
  assert(vectorToScalar(vec2i(1,0)) == 3, "Expected " ~ to!string(3) ~ ", got " ~ to!string(vectorToScalar(vec2i(1,0))));
  
  assert(vectorToScalar(vec2i(2,0)) == 4, "Expected " ~ to!string(4) ~ ", got " ~ to!string(vectorToScalar(vec2i(2,0))));
  assert(vectorToScalar(vec2i(3,0)) == 5, "Expected " ~ to!string(5) ~ ", got " ~ to!string(vectorToScalar(vec2i(3,0))));
  assert(vectorToScalar(vec2i(3,1)) == 6, "Expected " ~ to!string(6) ~ ", got " ~ to!string(vectorToScalar(vec2i(3,1))));
  assert(vectorToScalar(vec2i(2,1)) == 7, "Expected " ~ to!string(7) ~ ", got " ~ to!string(vectorToScalar(vec2i(2,1))));   
  
  assert(vectorToScalar(vec2i(2,0), 1) == 0);
  assert(vectorToScalar(vec2i(3,0), 1) == 1);
  assert(vectorToScalar(vec2i(3,1), 1) == 2);
  assert(vectorToScalar(vec2i(2,1), 1) == 3);
  
  assert(scalarToVector(0) == vec2i(0,0), "Expected " ~ to!string(vec2i(0,0)) ~ ", got " ~ to!string(scalarToVector(0)));
  assert(scalarToVector(1) == vec2i(0,1), "Expected " ~ to!string(vec2i(0,1)) ~ ", got " ~ to!string(scalarToVector(1)));
  assert(scalarToVector(2) == vec2i(1,1), "Expected " ~ to!string(vec2i(1,1)) ~ ", got " ~ to!string(scalarToVector(2)));
  assert(scalarToVector(3) == vec2i(1,0), "Expected " ~ to!string(vec2i(1,0)) ~ ", got " ~ to!string(scalarToVector(3)));
  assert(scalarToVector(4) == vec2i(2,0), "Expected " ~ to!string(vec2i(2,0)) ~ ", got " ~ to!string(scalarToVector(4)));
  assert(scalarToVector(5) == vec2i(3,0), "Expected " ~ to!string(vec2i(3,0)) ~ ", got " ~ to!string(scalarToVector(5)));
  assert(scalarToVector(6) == vec2i(3,1), "Expected " ~ to!string(vec2i(3,1)) ~ ", got " ~ to!string(scalarToVector(6)));
  assert(scalarToVector(7) == vec2i(2,1), "Expected " ~ to!string(vec2i(2,1)) ~ ", got " ~ to!string(scalarToVector(7)));
  
  assert(scalarToVector(4, 1) == vec2i(0,0), "Expected " ~ to!string(vec2i(0,0)) ~ ", got " ~ to!string(scalarToVector(4, 1)));
  assert(scalarToVector(5, 1) == vec2i(1,0), "Expected " ~ to!string(vec2i(1,0)) ~ ", got " ~ to!string(scalarToVector(5, 1)));
  assert(scalarToVector(6, 1) == vec2i(1,1), "Expected " ~ to!string(vec2i(1,1)) ~ ", got " ~ to!string(scalarToVector(6, 1)));
  assert(scalarToVector(7, 1) == vec2i(0,1), "Expected " ~ to!string(vec2i(0,1)) ~ ", got " ~ to!string(scalarToVector(7, 1)));
  
  for (int i = 0; i < 64; i++)
    assert(vectorToScalar(scalarToVector(i)) == i, "Expected " ~ to!string(i) ~ ", got " ~ to!string(vectorToScalar(scalarToVector(i))) ~ " from " ~ to!string(scalarToVector(i)));
}


struct s { int coord; char next; }
  
static s[][char] sectormapping; // maps different u-form sectors to other. so i don't have to bittwiddle the rotations and reflections

static this()
{
  sectormapping['a'] = [s(0,'d'), s(1,'a'), s(3,'b'), s(2,'a')];
  sectormapping['b'] = [s(2,'b'), s(1,'b'), s(3,'a'), s(0,'c')];
  sectormapping['c'] = [s(2,'c'), s(3,'d'), s(1,'c'), s(0,'b')];
  sectormapping['d'] = [s(0,'a'), s(3,'c'), s(1,'d'), s(2,'d')];
}

int vectorToScalar(vec2i vector, int order = 16)
{
  int position = 0;
  char currentsector = 'a';
  for (int i = order - 1; i > -1; i--)
  {
    position <<= 2;
    
    auto index = (vector.x & (1 << i) ? 1 : 0) +
                 (vector.y & (1 << i) ? 2 : 0);

    auto sector = sectormapping[currentsector][index];
    
    currentsector = sector.next;
    
    position |= sector.coord;
  }
  
  return position;
}

vec2i scalarToVector(int scalar, int order = 16)
{
  int[] coords;
  coords.length = order;
  
  int sc = scalar;
  
  int n = 1;
  
  while (sc > 0 && n <= order)
  {
    coords[order-n] = sc%4;
    sc /= 4;
    n++;
  }
  
  char currentsector = 'a';
  
  vec2i result;
  
  foreach (coord; coords)
  {
    result.x = result.x << 1;
    result.y = result.y << 1;
    
    int nextcoord;
    foreach (index, sector; sectormapping[currentsector])
    {
      if (sector.coord == coord)
      {
        nextcoord = index;
        currentsector = sector.next;
        break;
      }
    }
    
    result.x = result.x + (nextcoord % 2);
    result.y = result.y + (nextcoord / 2);
  }
  
  return result;
}


/*int vectorToScalar(int n, vec2i coord) 
{
  return xy2d(n, coord.x, coord.y);
}

vec2i scalarToVector(int n, int d) 
{
  int x, y;
  
  d2xy(n, d, &x, &y);
  
  return vec2i(x, y);
}*/

//convert (x,y) to d
int xy2d (int n, int x, int y) {
    int rx, ry, s, d=0;
    for (s=n/2; s>0; s/=2) {
        rx = (x & s) > 0;
        ry = (y & s) > 0;
        d += s * s * ((3 * rx) ^ ry);
        rot(s, &x, &y, rx, ry);
    }
    return d;
}
 
//convert d to (x,y)
void d2xy(int n, int d, int *x, int *y) {
    int rx, ry, s, t=d;
    *x = *y = 0;
    for (s=1; s<n; s*=2) {
        rx = 1 & (t/2);
        ry = 1 & (t ^ rx);
        rot(s, x, y, rx, ry);
        *x += s * rx;
        *y += s * ry;
        t /= 4;
    }
}
 
//rotate/flip a quadrant appropriately
void rot(int n, int *x, int *y, int rx, int ry) {
    int t;
    if (ry == 0) {
        if (rx == 1) {
            *x = n-1 - *x;
            *y = n-1 - *y;
        }
        t  = *x;
        *x = *y;
        *y = t;
    }
}
