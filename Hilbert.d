// copied from http://en.wikipedia.org/wiki/Hilbert_curve
// with wrappers to use gl3n vectors

module Hilbert;

import gl3n.linalg;


unittest
{
  int dim = 4;
  
  for (int scalar = 0; scalar < dim^^2; scalar++)
  {
    vec2i vector = scalarToVector(dim, scalar);
    
    assert(scalar == vectorToScalar(dim, scalarToVector(dim, scalar)));
  }
  
  assert(scalarToVector(dim, 0) == vec2i(0,0));
  assert(scalarToVector(dim, 1) == vec2i(1,0));
  assert(scalarToVector(dim, 2) == vec2i(1,1));
  assert(scalarToVector(dim, 3) == vec2i(0,1));
  assert(scalarToVector(dim, 4) == vec2i(0,2), to!string(scalarToVector(dim, 4)));
  assert(scalarToVector(dim, 5) == vec2i(0,3), to!string(scalarToVector(dim, 5)));
  assert(scalarToVector(dim, 6) == vec2i(1,3), to!string(scalarToVector(dim, 6)));
  assert(scalarToVector(dim, 7) == vec2i(1,2), to!string(scalarToVector(dim, 7)));
  assert(scalarToVector(dim, 8) == vec2i(2,2), to!string(scalarToVector(dim, 8)));
  assert(scalarToVector(dim, 9) == vec2i(2,3), to!string(scalarToVector(dim, 9)));
  assert(scalarToVector(dim,10) == vec2i(3,3), to!string(scalarToVector(dim,10)));
  assert(scalarToVector(dim,11) == vec2i(3,2), to!string(scalarToVector(dim,11)));
  assert(scalarToVector(dim,12) == vec2i(3,1), to!string(scalarToVector(dim,12)));
  assert(scalarToVector(dim,13) == vec2i(2,1), to!string(scalarToVector(dim,13)));
  assert(scalarToVector(dim,14) == vec2i(2,0), to!string(scalarToVector(dim,14)));
  assert(scalarToVector(dim,15) == vec2i(3,0), to!string(scalarToVector(dim,15)));
}

int vectorToScalar(int n, vec2i coord) 
{
  return xy2d(n, coord.x, coord.y);
}

vec2i scalarToVector(int n, int d) 
{
  int x, y;
  
  d2xy(n, d, &x, &y);
  
  return vec2i(x, y);
}

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