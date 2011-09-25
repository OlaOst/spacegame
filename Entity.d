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
import std.exception;
import std.math;
import std.stdio;
import std.string;

import SubSystem.CollisionHandler;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Entity entity = new Entity();
  
  entity.setValue("dummyValue", "123");
  
  assert(entity.getValue("dummyValue"), "123");
  
  Entity another = new Entity();
  
  assert(entity.id != another.id);
}


class Entity
{
invariant()
{
}


public:
  this()
  {
    id = m_idCounter++;
    
    //values["name"] = to!string(id);
  }
  
  this(string p_file)
  {
    id = m_idCounter++;
    
    if (p_file.startsWith("data/") == false)
      p_file = "data/" ~ p_file;
    
    values["source"] = p_file;
    
    loadValues(values, p_file);
  }
  
  this(string[string] p_extraParams)
  {
    id = m_idCounter++;
    
    foreach (extraParam; p_extraParams.keys)
    {
      setValue(extraParam, p_extraParams[extraParam]);
    }
  }
  
  this(string p_file, string[string] p_extraParams)
  {
    this(p_file);
    
    foreach (extraParam; p_extraParams.keys)
    {
      setValue(extraParam, p_extraParams[extraParam]);
    }
  }
  
  
  static void loadValues(ref string[string] p_values, string p_file)
  {
    string[] content;
    
    if (p_file !in m_fileCache)
    {
      auto file = File(p_file, "r");
      
      foreach (string line; lines(file))
      {
        m_fileCache[p_file] ~= line;
      }
    }

    content = m_fileCache[p_file];

    foreach (string line; content)
    {
      // comment line signified by hashsign as first non-whitespace character
      if (line.strip.length > 0 && line.strip[0] == '#')
        continue;
        
      // parse key-value line
      if (std.algorithm.find(line, '=').length > 0)
      {
        auto keyval = line.split("=");
        
        assert(keyval.length == 2, "unexpected value: " ~ to!string(keyval));
        
        auto key = keyval[0].strip;
        auto val = keyval[1].strip;
        
        assert(key.length > 0, "empty key");
        assert(val.length > 0, "empty value");
      
        //writeln("setting key '" ~ key ~ "' to '" ~ val ~ "'");
      
        if (key == "root")
          loadValues(p_values, "data/" ~ keyval[1].strip);
        
        p_values[key] = val;
      }
      else
      {
        //enforce(false, "Don't know how to parse this: " ~ line);
      }
    }
  }
  
  void setValue(string p_name, string p_value)
  {
    values[p_name] = p_value;
  }
  
  string getValue(string p_name)
  {
    if (p_name in values)
      return values[p_name];
    else
      return null;
  }
  
  
public:
  immutable int id;
  
  string[string] values;
  //alias values this;
  
private:
  shared synchronized static int m_idCounter;
  private static string[][string] m_fileCache;
}
