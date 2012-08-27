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

import gl3n.linalg;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Entity entity = new Entity(["dummyValue":"123"]);
  
  assert(entity.getValue("dummyValue") == "123");
  
  entity.setValue("dummyValue", "abc");
  
  assert(entity.getValue("dummyValue") == "abc");
  
  Entity another = new Entity(["foo":"bar"]);
  
  assert(entity.id != another.id);
}


class Entity
{
invariant()
{
}


public:

  this(string[string] p_extraParams)
  {
    id = m_idCounter++;
    
    foreach (extraParam; p_extraParams.keys)
    {
      setValue(extraParam, p_extraParams[extraParam]);
    }
  }
  
  Entity dup()
  {
    return new Entity(values.dup);
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
  
  
  string opIndex(string key)
  {
    return ((key in values) ? values[key] : null);
  }
  
  
  override int opCmp(Object other)
  {
    return id - (cast(Entity)other).id;
  }
  
  alias values this;
  
public:
  immutable int id;
  
  string[string] values;
  
private:
  shared synchronized static int m_idCounter;
}
