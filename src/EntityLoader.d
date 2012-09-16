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

module EntityLoader;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;

import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  string[][string] cache;
  string[string] values;
 
  File testFile = File("data/unittest.data", "w");
  
  testFile.writeln("a = b");
  testFile.writeln("one = 1");
  
  testFile.close();
  
 
  addValue("one = one", values);
  
  assert(values["one"] == "one");
  
  addValue("one = two", values);
  
  assert(values["one"] == "two");
  
  
  string[] lines = ["one = two", "three = four", "five = six", "#and this is a comment", "source = unittest.data"];
  
  values = getValues(cache, lines);
  
  assert(values["a"] == "b");
  assert(values["one"] == "two");
  assert(values["three"] == "four");
  assert(values["five"] == "six");
  
  
  
  // get values 
  // expand source values 
  // (child entities not expanded yet)
  // figure out child entities
  // get values for child entities (recursive)
  // expand wildcard values (ie entity with two children and a line like *.foo = bar means both children should have a foo = bar value)
  // value accumulation done in subsystems, on a per-entity basis (when registering child entity physics will update mass of parent entity)
  
  string[] linesWithChildren = ["hei = hoi", "child1.source = unittest.data", "child2.source = unittest.data", "*.one = foo", "child1.three = bar"];
  
  values = getValues(cache, linesWithChildren);
  
  string[string][string] childrenValues = findChildrenValues(cache, values);
  
  assert(childrenValues.length == 2, to!string(childrenValues));
  assert("child1" in childrenValues);
  assert("child2" in childrenValues);
  
  assert("a" in childrenValues["child1"], to!string(childrenValues["child1"]));
  
  assert(childrenValues["child1"]["a"] == "b");
  assert(childrenValues["child1"]["one"] == "foo");
  assert(childrenValues["child2"]["one"] == "foo");
  assert(childrenValues["child1"]["three"] == "bar");
  
  
  auto actualValues = loadValues(cache, "data/simpleship.txt");
  auto actualChildrenValues = findChildrenValues(cache, actualValues);
  assert(actualChildrenValues["mainSkeleton"]["source"] == "verticalskeleton.txt");
  assert(actualChildrenValues["mainSkeleton"]["connectpoint.lower.position"] == "0.0 -0.8");
}


void addValue(string line, ref string[string] values)
{
  line = line.strip;
  if (line.length > 0 && line.startsWith("#") == false)
  {
    auto key = to!string(line.until("=")).strip;
    
    values[key] = line.split("=")[1].strip;
  }
}

void addToCache(ref string[][string] cache, string filename)
out
{
  assert(filename in cache);
}
body
{
  auto fixedFilename = filename;
  if (fixedFilename.startsWith("data/") == false)
    fixedFilename = "data/" ~ filename;
  
  foreach (string line; fixedFilename.File.lines)
    cache[filename] ~= line;
}

string[string] loadValues(ref string[][string] cache, string filename)
{
  if (filename !in cache)
    addToCache(cache, filename);
    
  return getValues(cache, cache[filename]);
}

string[string] getValues(ref string[][string] cache, string[] lines)
{
  string[string] values;
  
  // first we load values from source
  foreach (line; lines)
  {
    if (line.strip.startsWith("source"))
    {
      string sourceFilename = line.strip.split("=")[1].strip;
      
      if (sourceFilename !in cache)
        addToCache(cache, sourceFilename);
      
      values = getValues(cache, cache[sourceFilename]);
    }
  }
    
  // then from the other values, this will likely override values from source
  foreach (line; lines)
  {
    addValue(line, values);
  }
  
  return values;
}


string[string][string] findChildrenValues(ref string[][string] cache, string[string] values)
{
  string[string][string] childValues;
  
  foreach (key; filter!(key => key.find(".").length > 0)(values.keys))
  {
    string childName = to!string(key.until("."));
      
    if (childName.length == 0 || childName == "*" || childName == "spawn" || childName == "connectpoint")
      continue;
    
    string childKey = key;
    
    auto ck = childKey.find(".")[1..$];
    
    childValues[childName][ck] = values[key];
  }
  
  // expand source values in children
  foreach (childName, values; childValues)
  {
    if ("source" in values)
    {
      string sourceFilename = values["source"];
      
      if (sourceFilename !in cache)
        addToCache(cache, sourceFilename);
      
      auto sourceValues = getValues(cache, cache[sourceFilename]);
      
      // values from source should not override already existing values
      foreach (sourceKey, sourceValue; sourceValues)
      {
        if (sourceKey !in values)
          values[sourceKey] = sourceValue;
      }
    }  
  }
  
  // override wildcard values from parent
  foreach (key, value; values)
  {
    if (to!string(key.until(".")) == "*")
    {
      auto wildcardKey = key.find(".")[1..$];
      foreach (childName, values; childValues)
      {
        values[wildcardKey] = value;
      }
    }
  }
  
  return childValues;
}
