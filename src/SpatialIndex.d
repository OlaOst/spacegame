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

import std.algorithm;
import std.array;
import std.math;
import std.stdio;

import gl3n.linalg;

import Utils;


unittest
{
  struct Content { AABB aabb; string payload; }

  Index!Content index;
  
  auto one = Content(AABB(vec2i(0, 0), vec2i(1, 1)), "one");  
  index.insert(one);
  
  assert(one in index.indicesForContent);
  assert(index[one].length == 1);
  
  
  auto two = Content(AABB(vec2i(0, 0), vec2i(2, 2)), "two");  
  index.insert(two);
  
  assert(two in index.indicesForContent);
  assert(index[two].length >= 1);
  
  
  auto check = Content(AABB(vec2i(1, 1), vec2i(3, 3)), "three");
  
  Content[] candidates = index.findNearbyContent(check);
  assert(candidates == [one, two], "Expected " ~ to!string([two]) ~ ", got " ~ to!string(candidates) ~ " instead");
  
  
  auto checkAll = Content(AABB(vec2i(-10, -10), vec2i(10, 10)), "four");
  
  candidates = index.findNearbyContent(checkAll);
  assert(candidates == [one, two], "Expected " ~ to!string([one, two]) ~ ", got " ~ to!string(candidates) ~ " instead");
  
  
  auto negative = Content(AABB(vec2i(-100, -100), vec2i(-50, -50)), "negative");
  index.insert(negative);
  
  assert(negative in index.indicesForContent);
  assert(index[negative].length >= 1);  
  
  
  auto weird = Content(AABB(vec2i(5,-7), vec2i(7, -5)), "weird");
  index.insert(weird);
  
  assert(weird in index.indicesForContent);
  assert(index[weird].length >= 1);  
}


struct Index(Content)
  if (__traits(compiles, function AABB (Content c) { return c.aabb; }))
{
public:
  int[][Content] indicesForContent;
  Content[][int] contentsInIndex;
  
  
  void clear()
  {
    indicesForContent = null;
    contentsInIndex = null;
  }
  
  int[] opIndex(Content content)
  {
    return indicesForContent[content];
  }
  
  Content[] findNearbyContent(Content checkContent)
  {
    int[][Content] indicesToCheck;
    Content[][int] contentsToCheck;
    
    AABB sector = AABB(vec2i(-2^^15, -2^^15), vec2i(2^^15, 2^^15));
    
    insert(checkContent, sector, 15, indicesToCheck, contentsToCheck);
    
    if (checkContent.aabb.lowerleft.x > sector.lowerleft.x &&
        checkContent.aabb.lowerleft.y > sector.lowerleft.y &&
        checkContent.aabb.upperright.x < sector.upperright.x &&
        checkContent.aabb.upperright.y < sector.upperright.y)
    {
      assert(indicesToCheck.length == 1, "Did not find checkContent with " ~ to!string(checkContent.aabb) ~ " in indicesToCheck");
      assert(checkContent in indicesToCheck);
    }
    
    Content[] nearbyContent;
    
    foreach (index, contents; contentsToCheck)
    {
      if (index in contentsInIndex)
        nearbyContent ~= contentsInIndex[index];
    }
    
    return nearbyContent;
  }
    
  
  void insert(Content content)
  {
    insert(content, AABB(vec2i(-2^^15, -2^^15), vec2i(2^^15, 2^^15)), 15, indicesForContent, contentsInIndex);
  }

  
private:
  static void insert(Content content, AABB sector, int level, ref int[][Content] indicesForContent, ref Content[][int] contentsInIndex)
  in
  {
    assert(level >= 0 && level <= 15, "Tried to insert content with level out of bounds (0-15): " ~ to!string(level));
    
    /* we allow out of bounds content, we just ignore it instead
    assert(content.aabb.lowerleft.x > sector.lowerleft.x &&
           content.aabb.lowerleft.y > sector.lowerleft.y &&
           content.aabb.upperright.x < sector.upperright.x &&
           content.aabb.upperright.y < sector.upperright.y, "Tried to insert content out of bounds: " ~ to!string(content.aabb));
    */
  }
  body
  {
    //writeln("putting content with AABB " ~ to!string(content.aabb) ~ " in sector " ~ to!string(sector) ~ " with midpoint " ~ to!string(sector.midpoint) ~ " at level " ~ to!string(level));
    
    // ignore out of bounds content
    if (content.aabb.lowerleft.x < sector.lowerleft.x ||
        content.aabb.lowerleft.y < sector.lowerleft.y ||
        content.aabb.upperright.x > sector.upperright.x ||
        content.aabb.upperright.y > sector.upperright.y)
      return;
    
    if (level <= 3)
    {
      auto index = indexForVector(sector.midpoint);
      
      indicesForContent[content] ~= index;
      contentsInIndex[index] ~= content;
      
      return;
    }
    
    AABB box = content.aabb;
    
    if (box.lowerleft.x < sector.midpoint.x && box.upperright.x > sector.lowerleft.x &&  // the box is overlapping one of the left squares of this level
        box.lowerleft.y < sector.midpoint.y && box.upperright.y > sector.lowerleft.y)    // the box is overlapping one of the lower squares of this level
    {
      insert(content, AABB(sector.lowerleft, 
                      vec2i(sector.upperright.x - 2^^(level-1), sector.upperright.y - 2^^(level-1))), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.lowerleft.x < sector.upperright.x && box.upperright.x > sector.midpoint.x &&  // the box is overlapping one of the right squares of this level
        box.lowerleft.y < sector.midpoint.y && box.upperright.y > sector.lowerleft.y)     // the box is overlapping one of the lower squares of this level
    {
      insert(content, AABB(vec2i(sector.lowerleft.x + 2^^(level-1), sector.lowerleft.y), 
                      vec2i(sector.upperright.x, sector.upperright.y - 2^^(level-1))), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.lowerleft.x < sector.upperright.x && box.upperright.x > sector.midpoint.x &&  // the box is overlapping one of the right squares of this level
        box.lowerleft.y < sector.upperright.y && box.upperright.y > sector.midpoint.y)    // the box is overlapping one of the upper squares of this level
    {
      insert(content, AABB(vec2i(sector.lowerleft.x + 2^^(level-1), sector.lowerleft.y + 2^^(level-1)), 
                      vec2i(sector.upperright)), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.lowerleft.x < sector.midpoint.x && box.upperright.x > sector.lowerleft.x &&  // the box is overlapping one of the left squares of this level
        box.lowerleft.y < sector.upperright.y && box.upperright.y > sector.midpoint.y)   // the box is overlapping one of the upper squares of this level
    {
      insert(content, AABB(sector.lowerleft, 
                      vec2i(sector.upperright)), 
             level-1, indicesForContent, contentsInIndex);
    }
  }
}
