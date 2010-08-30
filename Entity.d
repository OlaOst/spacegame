/*
 Copyright (c) 2010 Ola Østtveit

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

module Entity;

import std.algorithm;
import std.conv;
import std.math;
import std.stdio;
import std.string;

import CollisionSubSystem;
import Vector : Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Entity entity = new Entity();
  
  assert(entity.position == Vector.origo);
  
  entity.setValue("dummyValue", "123");
  
  assert(entity.getValue("dummyValue"), "123");
  
  Entity another = new Entity();
  
  assert(entity.id != another.id);
  
  
  Entity fromFile = new Entity("data/shiproot.txt");
  
  assert(fromFile.getValue("drawtype") == "triangle");
  assert(fromFile.getValue("collisionType") == "ship");
  assert(fromFile.getValue("radius") == "2.0");
  assert(fromFile.getValue("mass") == "4.0");
}


class Entity
{
invariant()
{
  assert(m_position.x == m_position.x && m_position.y == m_position.y && m_position.z == m_position.z);
  assert(m_angle == m_angle);
  
  assert(m_lifetime == m_lifetime);
}


public:
  this()
  {
    m_position = Vector.origo;
    m_angle = 0.0;
    
    m_id = m_idCounter++;
    
    m_lifetime = float.infinity;
  }
  
  this(string p_file)
  {
    this();
    
    loadValues(m_values, p_file);
  }
  
  static void loadValues(ref string[string] p_values, string p_file)
  {
    string[] content;
    
    if (p_file in m_fileCache)
    {
      content = m_fileCache[p_file];
    }
    else
    {
      auto file = File(p_file, "r");
      
      foreach (string line; lines(file))
      {
        m_fileCache[p_file] ~= line;
      }
      
      content = m_fileCache[p_file];
    }

    foreach (string line; content)
    {
      // comment line signified by hashsign as first non-whitespace character
      if (line.strip.length > 0 && line.strip[0] == '#')
        continue;
        
      if (std.algorithm.find(line, '=').length > 0)
      {
        auto keyval = line.split("=");
        
        assert(keyval.length == 2, "unexpected value: " ~ to!string(keyval));
        assert(keyval[0].length > 0, "empty key");
        assert(keyval[1].length > 0, "empty value");
      
        if (keyval[0].strip == "root")
          loadValues(p_values, "data/" ~ keyval[1].strip);
        
        p_values[keyval[0].strip] = keyval[1].strip;
      }
    }
  }
  
  static string[][string] m_fileCache;
  
  Vector position()
  {
    return m_position;
  }
  
  void position(Vector p_position)
  {
    m_position = p_position;
  }
  
  float angle()
  {
    return m_angle;
  }
  
  void angle(float p_angle)
  {
    m_angle = p_angle;
  }
  
  float lifetime()
  {
    return m_lifetime;
  }
  
  void lifetime(float p_lifetime)
  {
    m_lifetime = p_lifetime;
  }
  
  void setValue(string p_name, string p_value)
  {
    m_values[p_name] = p_value;
  }
  
  string getValue(string p_name)
  in
  {
    //assert(p_name in m_values);
  }
  body
  {
    if (p_name in m_values)
      return m_values[p_name];
    else
      return null;
  }
  
  @property string[string] values()
  {
	return m_values;
  }
    
  int id()
  {
    return m_id;
  }
  
  void addSpawn(Entity p_spawn)
  {
    m_spawnList ~= p_spawn;
  }
  
  Entity[] getAndClearSpawns()
  out
  {
    assert(m_spawnList.length == 0);
  }
  body
  {
    Entity[] tmp = m_spawnList;
    
    m_spawnList.length = 0;
    
    return tmp;
  }

  void addCollision(Collision p_collision)
  {
    m_collisionList ~= p_collision;
  }
  
  Collision[] getAndClearCollisions()
  out
  {
    assert(m_collisionList.length == 0);
  }
  body
  {
    Collision[] tmp = m_collisionList;
    
    m_collisionList.length = 0;
    
    return tmp;
  }
  
  
private:
  Vector m_position;
  float m_angle;
  
  float m_lifetime;
  
  static int m_idCounter;
  int m_id;
  
  string[string] m_values;
  
  Entity[] m_spawnList;
  Collision[] m_collisionList;
}