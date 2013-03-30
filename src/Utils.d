/*
 Copyright (c) 2011 Ola Østtveit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

module Utils;

import gl3n.linalg;


unittest
{
  assert(interleave(0, 0) == 0, "Expected " ~ to!string(0) ~ ", got " ~ to!string(interleave(0, 0)));
  assert(interleave(1, 0) == 1, "Expected " ~ to!string(1) ~ ", got " ~ to!string(interleave(1, 0)));
  assert(interleave(0, 1) == 2, "Expected " ~ to!string(2) ~ ", got " ~ to!string(interleave(0, 1)));
  assert(interleave(1, 1) == 3, "Expected " ~ to!string(3) ~ ", got " ~ to!string(interleave(1, 1)));
  
  assert(interleave(2^^15-1, 2^^15-1) == 2^^30-1, "Expected " ~ to!string(2^^30-1) ~ ", got " ~ to!string(interleave(2^^15-1, 2^^15-1)));
  
  assert(interleave(2^^15, 2^^15) == 2^^31/2, "Expected " ~ to!string(2^^30) ~ ", got " ~ to!string(interleave(2^^15, 2^^15)));

  
  vec3 origoVector = vec3(0, 0, 0);
  int origoIndex = -2^^30;
  
  vec3 leastVector = vec3(-2^^15, -2^^15, 0);
  int leastIndex = 0;
  
  vec3 largestVector = vec3(2^^15-1, 2^^15-1, 0);
  int largestIndex = 2^^32-1;
  
  assert(indexForVector(origoVector)   == origoIndex, "Expected " ~   to!string(origoIndex) ~   ", got " ~ to!string(indexForVector(origoVector)));
  assert(vectorForIndex(origoIndex)    == origoVector, "Expected "   ~ to!string(origoVector)   ~ ", got " ~ to!string(vectorForIndex(origoIndex)));
  
  assert(indexForVector(leastVector)   == leastIndex, "Expected " ~   to!string(leastIndex) ~   ", got " ~ to!string(indexForVector(leastVector)));
  assert(vectorForIndex(leastIndex)    == leastVector, "Expected "   ~ to!string(leastVector)   ~ ", got " ~ to!string(vectorForIndex(leastIndex)));
  
  assert(indexForVector(largestVector) == largestIndex, "Expected " ~ to!string(largestIndex) ~ ", got " ~ to!string(indexForVector(largestVector)));
  assert(vectorForIndex(largestIndex)  == largestVector, "Expected " ~ to!string(largestVector) ~ ", got " ~ to!string(vectorForIndex(largestIndex)));
  
  
  assert(indexForVector(vectorForIndex(-2^^16)) == -2^^16);
  assert(indexForVector(vectorForIndex(2^^16)) == 2^^16);
  
    
  for (int i = -256; i < 256; i++)
    assert(indexForVector(vectorForIndex(i)) == i, "Expected " ~ to!string(i) ~ ", got " ~ to!string(indexForVector(vectorForIndex(i))) ~ ", via " ~ to!string(vectorForIndex(i)));
  
  for (int i = int.max - 256; i < int.max + 256; i++)
    assert(indexForVector(vectorForIndex(i)) == i, "Expected " ~ to!string(i) ~ ", got " ~ to!string(indexForVector(vectorForIndex(i))) ~ ", via " ~ to!string(vectorForIndex(i)));
  
  for (int y = 0; y < 256; y++)
    for (int x = 0; x < 256; x++)
      assert(vectorForIndex(indexForVector(vec3(x, y, 0))) == vec3(x, y, 0), "Expected " ~ vec3(x, y, 0).to!string ~ ", got " ~ vectorForIndex(indexForVector(vec3(x, y, 0))).to!string);

  for (int y = int.max - 256; y < int.max + 256; y++)
    for (int x = int.max - 256; x < int.max + 256; x++)
      assert(vectorForIndex(indexForVector(vec3(x, y, 0))) == vec3(x, y, 0), "Expected " ~ to!string(vec3(x, y, 0)) ~ ", got " ~ to!string(vectorForIndex(indexForVector(vec3(x, y, 0)))));
}


int indexForVector(vec3 vector)
in
{
  assert(vector.x >= -2^^15 && vector.x < 2^^15, "Tried to call indexForVector with vector.x out of bounds: " ~ to!string(vector.x));
  assert(vector.y >= -2^^15 && vector.y < 2^^15, "Tried to call indexForVector with vector.y out of bounds: " ~ to!string(vector.y));
}
body
{
  return interleave(cast(int)vector.x + 2^^15, cast(int)vector.y + 2^^15);
}

vec3 vectorForIndex(int index)
in
{
  assert(index >= -2^^31 && index < 2^^31-1, "Tried to call vectorForIndex with index out of bounds: " ~ to!string(index));
}
body
{
  return vec3(deinterleave(index) - 2^^15, deinterleave(index >> 1) - 2^^15, 0);
}


// will extract even bits
int deinterleave(int z)
in
{
  assert(z >= -2^^31 && z < 2^^31-1, "Tried to call deinterleave with z out of bounds: " ~ to!string(z));
}
body
{
  z = z & 0x55555555;
  
  z = (z | (z >> 1)) & 0x33333333;
  z = (z | (z >> 2)) & 0x0F0F0F0F;
  z = (z | (z >> 4)) & 0x00FF00FF;
  z = (z | (z >> 8)) & 0x0000FFFF;
  
  return z;
}

int interleave(int x, int y)
in
{
  assert(x >= 0 && x < 2^^16, "Tried to call interleave with x out of bounds: " ~ to!string(x));
  assert(y >= 0 && y < 2^^16, "Tried to call interleave with y out of bounds: " ~ to!string(y));
}
body
{
  // from http://graphics.stanford.edu/~seander/bithack.html#InterleaveBMN
  static immutable uint B[] = [0x55555555, 0x33333333, 0x0F0F0F0F, 0x00FF00FF];
  static immutable uint S[] = [1, 2, 4, 8];

  // Interleave lower 16 bits of x and y, so the bits of x
  // are in the even positions and bits from y in the odd;
  
  uint z; // z gets the resulting 32-bit Morton Number.  
          // x and y must initially be less than 65536.

  x = (x | (x << S[3])) & B[3];
  x = (x | (x << S[2])) & B[2];
  x = (x | (x << S[1])) & B[1];
  x = (x | (x << S[0])) & B[0];

  y = (y | (y << S[3])) & B[3];
  y = (y | (y << S[2])) & B[2];
  y = (y | (y << S[1])) & B[1];
  y = (y | (y << S[0])) & B[0];

  z = x | (y << 1);
  
  return z;
}
