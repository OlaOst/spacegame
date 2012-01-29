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

module SpatialIndex;

import std.math;

import gl3n.linalg;

import SpatialIndexUtils;


unittest
{
  Index index;
  
  vec2i pos = [0,0];
  
  index[indexForVector(pos)] = pos;
  
  assert(index[indexForVector(pos)] == pos);
  
  AABB box = AABB(vec2i(-1,-1), vec2i(1,1));
  
  index.insert(box);
  
  assert(box in index.AABBtoIndices);
  
  assert(index[box].length == 1);
  
  
  AABB bigbox = AABB(vec2i(-1,-1), vec2i(10,10));
  
  index.insert(bigbox);
}

struct AABB
{
  invariant()
  {
    assert(lowerleft.x < upperright.x);
    assert(lowerleft.y < upperright.y);
  }

  vec2i lowerleft;
  vec2i upperright;
  
  vec2i midpoint()
  {
    return vec2i((lowerleft.x+upperright.x)/2, (lowerleft.y+upperright.y)/2);
  }
}

struct Index
{
  vec2i[int] indexToVector;
  int[][AABB] AABBtoIndices;
  
  vec2i opIndex(int index)
  {
    return indexToVector[index];
  }
  
  vec2i opIndexAssign(vec2i position, int index)
  {
    return indexToVector[index] = position;
  }
  
  
  int[] opIndex(AABB box)
  {
    return AABBtoIndices[box];
  }
  
  
  void insert(AABB box)
  {
    insert(box, AABB(vec2i(0,0), vec2i(2^^15, 2^^15)), 15);
  }
  
  void insert(AABB box, AABB sector, int level = 15)
  in
  {
    assert(level >= 0 && level <= 15, "Tried to insert AABB with level out of bounds (0-15): " ~ to!string(level));
  }
  body
  {
    //import std.stdio;
    //writeln("putting box " ~ to!string(box) ~ " in sector " ~ to!string(sector) ~ " at level " ~ to!string(level));
    
    if (level == 0)
    {
      AABBtoIndices[box] ~= indexForVector(box.midpoint);
      return;
    }
    
    if (box.lowerleft.x < sector.lowerleft.x && box.upperright.x > sector.lowerleft.x &&  // the box is overlapping one of the left squares of this level
        box.lowerleft.y < sector.lowerleft.y && box.upperright.y > sector.lowerleft.y)    // the box is overlapping one of the lower squares of this level
    {
      insert(box, 
             AABB(sector.lowerleft, 
                  vec2i(sector.upperright.x - 2^^(level-1), sector.upperright.y - 2^^(level-1))), 
             level-1);
    }
    
    if (box.lowerleft.x < sector.upperright.x && box.upperright.x > sector.upperright.x &&  // the box is overlapping one of the right squares of this level
        box.lowerleft.y < sector.lowerleft.y && box.upperright.y > sector.lowerleft.y)      // the box is overlapping one of the lower squares of this level
    {
      insert(box, 
             AABB(vec2i(sector.lowerleft.x + 2^^(level-1), sector.lowerleft.y), 
                  vec2i(sector.upperright.x, sector.upperright.y - 2^^(level-1))), 
             level-1);
    }
    
    if (box.lowerleft.x < sector.upperright.x && box.upperright.x > sector.upperright.x &&  // the box is overlapping one of the right squares of this level
        box.lowerleft.y < sector.upperright.y && box.upperright.y > sector.upperright.y)    // the box is overlapping one of the upper squares of this level
    {
      insert(box, 
             AABB(vec2i(sector.lowerleft.x + 2^^(level-1), sector.lowerleft.y + 2^^(level-1)), 
                  vec2i(sector.upperright)), 
             level-1);
    }
    
    if (box.lowerleft.x < sector.lowerleft.x && box.upperright.x > sector.lowerleft.x &&  // the box is overlapping one of the left squares of this level
        box.lowerleft.y < sector.upperright.y && box.upperright.y > sector.upperright.y)  // the box is overlapping one of the upper squares of this level
    {
      insert(box, 
             AABB(sector.lowerleft, 
                  vec2i(sector.upperright)), 
             level-1);
    }
  }
}
