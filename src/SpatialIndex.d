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

import gl3n.aabb;
import gl3n.linalg;

import Utils;


unittest
{
  struct Content { AABB aabb; string payload; }

  Index!Content index;
  
  auto one = Content(AABB(vec3(0, 0, 0), vec3(1, 1, 0)), "one");  
  index.insert(one);
  
  assert(one in index.indicesForContent);
  assert(index[one].length == 1);
  
  
  auto two = Content(AABB(vec3(0, 0, 0), vec3(2, 2, 0)), "two");  
  index.insert(two);
  
  assert(two in index.indicesForContent);
  assert(index[two].length >= 1);
  
  
  auto check = Content(AABB(vec3(1, 1, 0), vec3(3, 3, 0)), "three");
  
  Content[] candidates = index.findNearbyContent(check);
  assert(candidates == [one, two], "Expected " ~ [two].to!string ~ ", got " ~ candidates.to!string ~ " instead");
  
  
  auto checkAll = Content(AABB(vec3(-10, -10, 0), vec3(10, 10, 0)), "four");
  
  candidates = index.findNearbyContent(checkAll);
  assert(candidates == [one, two], "Expected " ~ [one, two].to!string ~ ", got " ~ candidates.to!string ~ " instead");
  
  
  auto negative = Content(AABB(vec3(-100, -100, 0), vec3(-50, -50, 0)), "negative");
  index.insert(negative);
  
  assert(negative in index.indicesForContent);
  assert(index[negative].length >= 1);  
  
  
  auto weird = Content(AABB(vec3(5, -7, 0), vec3(7, -5, 0)), "weird");
  index.insert(weird);
  
  assert(weird in index.indicesForContent);
  assert(index[weird].length >= 1);  
  
  //auto huh = Content(AABB(vec3
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
    
    AABB sector = AABB(vec3(-2^^15, -2^^15, 0.0), vec3(2^^15, 2^^15, 0.0));
    
    insert(checkContent, sector, 15, indicesToCheck, contentsToCheck);
    
    if (checkContent.aabb.min.x > sector.min.x &&
        checkContent.aabb.min.y > sector.min.y &&
        checkContent.aabb.max.x < sector.max.x &&
        checkContent.aabb.max.y < sector.max.y)
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
    insert(content, AABB(vec3(-2^^15, -2^^15, 0.0), vec3(2^^15, 2^^15, 0.0)), 15, indicesForContent, contentsInIndex);
  }

  
private:
  static void insert(Content content, AABB sector, int level, ref int[][Content] indicesForContent, ref Content[][int] contentsInIndex)
  in
  {
    assert(level >= 0 && level <= 15, "Tried to insert content with level out of bounds (0-15): " ~ to!string(level));
    
    /* we allow out of bounds content, we just ignore it instead
    assert(content.aabb.min.x > sector.min.x &&
           content.aabb.min.y > sector.min.y &&
           content.aabb.max.x < sector.max.x &&
           content.aabb.max.y < sector.max.y, "Tried to insert content out of bounds: " ~ to!string(content.aabb));
    */
  }
  body
  {
    //writeln("putting content with AABB " ~ to!string(content.aabb) ~ " in sector " ~ to!string(sector) ~ " with midpoint " ~ to!string(sector.midpoint) ~ " at level " ~ to!string(level));
    
    // ignore out of bounds content
    if (content.aabb.min.x < sector.min.x ||
        content.aabb.min.y < sector.min.y ||
        content.aabb.max.x > sector.max.x ||
        content.aabb.max.y > sector.max.y)
      return;
    
    if (level <= 3)
    {
      auto index = indexForVector(sector.center);
      
      indicesForContent[content] ~= index;
      contentsInIndex[index] ~= content;
      
      return;
    }
    
    AABB box = content.aabb;
    
    if (box.min.x < sector.center.x && box.max.x > sector.min.x &&  // the box is overlapping one of the left squares of this level
        box.min.y < sector.center.y && box.max.y > sector.min.y)    // the box is overlapping one of the lower squares of this level
    {
      insert(content, AABB(sector.min, 
                           vec3(sector.max.x - 2^^(level-1), sector.max.y - 2^^(level-1), 0.0)), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.min.x < sector.max.x && box.max.x > sector.center.x &&  // the box is overlapping one of the right squares of this level
        box.min.y < sector.center.y && box.max.y > sector.min.y)     // the box is overlapping one of the lower squares of this level
    {
      insert(content, AABB(vec3(sector.min.x + 2^^(level-1), sector.min.y, 0.0), 
                           vec3(sector.max.x, sector.max.y - 2^^(level-1), 0.0)), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.min.x < sector.max.x && box.max.x > sector.center.x &&  // the box is overlapping one of the right squares of this level
        box.min.y < sector.max.y && box.max.y > sector.center.y)    // the box is overlapping one of the upper squares of this level
    {
      insert(content, AABB(vec3(sector.min.x + 2^^(level-1), sector.min.y + 2^^(level-1), 0.0), 
                           sector.max), 
             level-1, indicesForContent, contentsInIndex);
    }
    
    if (box.min.x < sector.center.x && box.max.x > sector.min.x &&  // the box is overlapping one of the left squares of this level
        box.min.y < sector.max.y && box.max.y > sector.center.y)   // the box is overlapping one of the upper squares of this level
    {
      insert(content, AABB(sector.min, 
                           sector.max), 
             level-1, indicesForContent, contentsInIndex);
    }
  }
}
