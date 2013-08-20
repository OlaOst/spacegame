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
import std.exception;
import std.random;
import std.stdio;
import std.string;

import gl3n.linalg;

import Entity;


/*****************************
 * Data must be refined into a form that can be used by the game
 * This can happen in several steps
 * In general, the process goes file -> 
                                string -> 
                                array of lines -> 
                                key/value associative array -> 
                                keyvalues with imports -> 
                                named keyvalues -> 
                                named keyvalues with overrides -> 
                                entity
                                
 * What each step accepts and what it returns must be well-defined
 *
 * Special considerations must be taken for naming and keeping track of what is a key/value collection for a single entity and what is a key/value collection for multiple entities
 *
 * Simplification: A file always contains a collection of entities - the key/values must be named even if only one entity is defined in the file
 * 
 *****************************/

//string[] loadFile(File file)
//{
  //return file.lines;
//}

unittest
{
  string content = "  frontspacedkey=value\nbackspacedkey=value  \ninbetweenspaces = value\n\n\r\tkeyaftermultipleemptylines=value";
  
  auto result = content.makeLines;
  
  assert(result.length == 4, "Expected 4 lines, got " ~ result.length.to!string);
  assert(result[0] == "frontspacedkey=value");
  assert(result[1] == "backspacedkey=value");
  assert(result[2] == "inbetweenspaces = value"); // inbetweenspaces are stripped in makeKeyValues, not here
  assert(result[3] == "keyaftermultipleemptylines=value");
}
string[] makeLines(string content)
{
  return content.splitLines.map!(line => line.strip).filter!(line => line.length > 0).array;
}

unittest
{
  auto test = ["test.value = one", "test.othervalue = two"];
  
  auto result = test.makeKeyValues;
  
  assert("test.value" in result);
  assert("test.othervalue" in result);
  
  assert(result["test.value"] == "one");
  assert(result["test.othervalue"] == "two");
}
string[string] makeKeyValues(string[] lines)
{
  string[string] keyValues;

  foreach (line; lines)
    keyValues[line.split("=")[0].strip] = line.strip.split("=")[1].strip;
  
  return keyValues;
}

// test importing named values
unittest
{ 
  auto baseValues = ["base.key" : "value", "base.otherkey" : "othervalue", "otherbase.key" : "otherbasevalue"];
  auto cache = ["file://base.txt" : baseValues];
  
  auto importer = ["importer.import" : "file://base.txt", "importer.*.otherkey" : "overridenvalue"];
  
  auto result = importKeyValues(importer, cache);
  
  assert("importer.import" in result);
  assert(result["importer.import"] == "file://base.txt");
  
  assert("importer.base.key" in result);
  assert(result["importer.base.key"] == "value");
  
  assert("importer.otherbase.key" in result);
  assert(result["importer.otherbase.key"] == "otherbasevalue");
  
  assert("importer.*.otherkey" in result);
  assert(result["importer.*.otherkey"] == "overridenvalue");
  
  // TODO: value overriding should be done in another function
  //assert("third.first.otherkey" in result && result["third.first.otherkey"] == "overridenvalue");
  //assert("third.second.otherkey" in result && result["third.second.otherkey"] == "overridenvalue");
}

// test importing nameless values
unittest
{
  auto baseValues = ["key" : "value", "otherkey" : "othervalue"];
  auto cache = ["file://base.txt" : baseValues];
  
  auto importValues = ["import" : "file://base.txt", "key" : "overriddenvalue", "childkey" : "childvalue"];
  
  auto result = importKeyValues(importValues, cache);
  
  assert("import" in result && result["import"] == "file://base.txt");
  assert("key" in result);
  assert(result["key"] == "overriddenvalue", "key value expected to be overridenvalue, was " ~ result["key"]);
  assert("otherkey" in result && result["otherkey"] == "othervalue", "Could not find otherkey in expanded values: " ~ result.to!string);
  assert("childkey" in result && result["childkey"] == "childvalue");
}

// test recursive nameless import
unittest
{
  auto grandgrandparent = ["grandgrandparentkey" : "grandgrandparentvalue"];
  auto grandparent = ["import" : "file://grandgrandparent.txt", "grandparentkey" : "grandparentvalue", "grandparentoverridekey" : "valuetobeoverriden"];
  auto parent = ["import" : "file://grandparent.txt", "parentkey" : "parentvalue", "parentoverridekey" : "valuetobeoverriden"];
  auto keyValuesForImport = ["file://grandgrandparent.txt" : grandgrandparent, "file://grandparent.txt" : grandparent, "file://parent.txt" : parent];
  
  auto child = ["import" : "file://parent.txt", "childkey" : "childvalue", "grandparentoverridekey" : "overriddenvalue", "parentoverridekey" : "overriddenvalue"];
  
  auto result = importKeyValues(child, keyValuesForImport);
  
  assert("import" in result);
  assert(result["import"] == "file://parent.txt");
  
  assert("import.import" in result);
  assert(result["import.import"] == "file://grandparent.txt");
  
  assert("import.import.import" in result);
  assert(result["import.import.import"] == "file://grandgrandparent.txt");
  
  assert("parentkey" in result);
  assert(result["parentkey"] == "parentvalue");
  
  assert("grandparentkey" in result);
  assert(result["grandparentkey"] == "grandparentvalue");
  
  assert("grandparentoverridekey" in result);
  assert(result["grandparentoverridekey"] == "overriddenvalue");
  
  assert("parentoverridekey" in result);
  assert(result["parentoverridekey"] == "overriddenvalue");
}

// test recursive import loop - should fail
unittest
{
  auto first = ["import" : "file://second.txt"];
  auto second = ["import" : "file://first.txt"];
  auto keyValuesForImport = ["file://first.txt" : first, "file://second.txt" : second];
  
  assertThrown(first.importKeyValues(keyValuesForImport));
}

string[string] importKeyValues(string[string] keyValues, string[string][string] keyValuesForImport)
{
  bool[string] importLoopGuard;
  return importKeyValuesInner(keyValues, keyValuesForImport, importLoopGuard);
}

string[string] importKeyValuesInner(string[string] keyValues, string[string][string] keyValuesForImport, bool[string] importLoopGuard)
{
  foreach (importKey; keyValues.keys.filter!(key => key.endsWith("import")))
  {
    auto importName = keyValues[importKey];
    
    if (importName !in keyValuesForImport)
    {
      // TODO: get values from importName. Could be file, http, stream, etc. Make separate module for resource loading
      // TODO: if this can be done in another function, we can separate the resource loading from resource importing.
      //       this assumes all needed resources are in the keyValuesForResource parameter.
      debug writeln("Did not find import " ~ importName);
    }
    
    // prevent loop by checking if import has already been done
    enforce(importName !in importLoopGuard, "Import loop detected: " ~ importLoopGuard.keys.to!string);
    importLoopGuard[importName] = true;
    
    importKeyValuesInner(keyValuesForImport[importName], keyValuesForImport, importLoopGuard);
    
    auto name = importKey.chomp("import").chomp(".");
    if (name.length > 0)
      name ~= ".";
      
    foreach (sourceKey, sourceValue; keyValuesForImport[importName])
    {
      auto fullName = name ~ sourceKey;
      
      // for recursive nameless imports we want grandparent import to be "import.import"
      if (sourceKey.endsWith("import") && name.length == 0)
      {
        fullName ~= ".import";
      }
        
      if (fullName !in keyValues)
        keyValues[fullName] = sourceValue;
    }
  }
  
  return keyValues;
}

unittest
{
  auto test = ["name.key" : "value", "other.key" : "othervalue", "name.with.dots.in.it.key" : "value.with.dots.in.it"];
  
  auto result = test.getNamedKeyValues;
  
  assert("name" in result);
  assert("other" in result);
  assert("name.with.dots.in.it" in result);
  
  assert("key" in result["name"]);
  assert("key" in result["other"]);
  assert("key" in result["name.with.dots.in.it"]);
  
  assert(result["name"]["key"] == "value");
  assert(result["other"]["key"] == "othervalue");
  assert(result["name.with.dots.in.it"]["key"] == "value.with.dots.in.it");
}
string[string][string] getNamedKeyValues(string[string] keyValues)
{
  // all keys must be on the form name.key
  
  string[string][string] namedKeyValues;
  
  foreach (key, value; keyValues)
  {
    auto keyParts = key.split(".");
    
    enforce(keyParts.length >= 2);
    
    namedKeyValues[keyParts[0..$-1].join(".")][keyParts[$-1..$].join(".")] = value;
  }
  
  return namedKeyValues;
}

unittest
{
  auto parent = ["key" : "parentvalue"];
  auto parentOverride = ["overridekey" : "overridevalue"];
  auto child = ["key" : "childvalue", "overridekey" : "childvalue"];
  
  auto test = ["parent" : parent, "parent.*" : parentOverride, "parent.child" : child];
  
  auto result = test.overrideNamedKeyValues;
  
  assert("parent" in result);
  assert("parent.*" !in result);
  assert("parent.child" in result);
  
  assert("key" in result["parent"]);
  assert(result["parent"]["key"] == "parentvalue");
  
  assert("key" in result["parent.child"]);
  assert(result["parent.child"]["key"] == "childvalue");
  
  assert("overridekey" in result["parent.child"]);
  assert(result["parent.child"]["overridekey"] == "overridevalue");
}
string[string][string] overrideNamedKeyValues(string[string][string] namedKeyValues)
{
  string[string][string] result = namedKeyValues.dup;
  
  foreach (name, keyValues; namedKeyValues)
  {
    auto overrideNameParts = name.findSplit("*");
    
    if (!overrideNameParts[1].empty)
    {
      auto namesToOverride = overrideNameParts[0];
      
      result.remove(name);
      
      foreach (overrideName, overrideKeyValues; result)
      {
        if (overrideName.startsWith(namesToOverride) && overrideName != name)
        {
          foreach (key, value; keyValues)
          {
            overrideKeyValues[key] = value;
          }
        }
      }
    }
  }
  
  return result;
}

unittest
{
  auto data = "parent.key = parentvalue\nparent.child.key = childvalue\nparent.*.overridekey = overridenvalue";
  
  auto result = data.makeEntities;
  
  assert("parent" in result);
  assert("parent.child" in result);
  
  assert(result["parent"]["key"] == "parentvalue");
  
  assert(result["parent.child"]["key"] == "childvalue");
  assert(result["parent.child"]["overridekey"] == "overridenvalue");
}
Entity[string] makeEntities(string data)
{
  auto lines = data.makeLines;
  
  auto keyValues = lines.makeKeyValues;
  
  // TODO: where do we get keyValuesForImport from?
  string[string][string] keyValuesForImport;
  
  auto importedKeyValues = keyValues.importKeyValues(keyValuesForImport);
  
  auto namedKeyValues = importedKeyValues.getNamedKeyValues;
  
  auto overridenNamedKeyValues = namedKeyValues.overrideNamedKeyValues;
  
  Entity[string] entities;
  foreach (name, keyValues; overridenNamedKeyValues)
  {
    // here name should be a unique name for the entity in this collection
    entities[name] = new Entity(keyValues);
  }
  
  return entities;
}
