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


unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
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
  assert(actualChildrenValues["mainSkeleton"]["connectpoint.lower.position"] == "[0.0, -0.8]");
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


unittest
{
  string[] lines = ["basevalue = test", 
                    "first.position = [1, 2]", 
                    "random.angle = 0 to 10",
                    "random.position = [0, -1] to [1, 0]",
                    "parent.foo = bar", 
                    "child.owner = parent",
                    "connectBase.connectpoint.one.position = [0.0, 1.0]",
                    "connectChild.connection = connectBase.one",
                    "image.drawsource = image.png",
                    "external.source = cannon.txt",
                    "external.spawn.foo = bar"];
  
  string[] orderedEntityNames;
  auto entities = loadEntityCollection("test", lines, orderedEntityNames);
  
  assert(entities.length > 0);
  
  //writeln(orderedEntityNames);
  assert(orderedEntityNames == ["test", 
                                "test.first", 
                                "test.random", 
                                "test.parent", 
                                "test.child", 
                                "test.connectBase", 
                                "test.connectChild", 
                                "test.image", 
                                "test.external"]);
  
  assert("test" in entities);
  assert(entities["test"]["name"] == "test");
  assert(entities["test"]["basevalue"] == "test");
  
  assert("test.random" in entities);
  assert(entities["test.random"]["name"] == "random", "Expected entity name \"random\", got \"" ~ entities["test.random"]["name"] ~ "\"");
  assert(entities["test.random"]["angle"].length > 0);
  assert(entities["test.random"]["angle"].to!float >= 0.0);
  assert(entities["test.random"]["angle"].to!float < 10.0);
  assert(entities["test.random"]["position"].to!(float[])[0..2].vec2.x >= 0.0);
  assert(entities["test.random"]["position"].to!(float[])[0..2].vec2.y >= -1.0);
  assert(entities["test.random"]["position"].to!(float[])[0..2].vec2.x < 1.0);
  assert(entities["test.random"]["position"].to!(float[])[0..2].vec2.y < 0.0);
  
  assert("test.first" in entities, "Expected entity \"test.first\"");
  assert(entities["test.first"]["position"] == "[1, 2]");
  
  assert("test.parent" in entities);
  assert("test.child" in entities);
  assert(entities["test.parent"]["foo"] == "bar");
  assert(entities["test.child"]["owner"] != "parent", "test.child.owner did not get translated from name \"" ~ entities["test.child"]["owner"] ~ "\" to id");
  assert(entities["test.child"]["owner"] == entities["test.parent"].id.to!string, "Expected test.child.owner to be " ~ entities["test.parent"].id.to!string ~ ", got " ~ entities["test.child"]["owner"]);
  
  //foreach (name, entity; entities)
    //writeln(name ~ ": " ~ entity.values.to!string);
    
  assert("test.connectBase" in entities);
  assert("test.connectChild" in entities);
  assert(entities["test.connectBase"]["connectpoint.one.position"] == "[0.0, 1.0]", "test.connectBase connectpoint.one.position was " ~ entities["test.connectBase"]["connectpoint.one.position"] ~ ", expected [0.0, 1.0]");
  assert(entities["test.connectChild"]["connection"] == entities["test.connectBase"].id.to!string ~ ".one");
  assert(entities["test.connectChild"]["owner"] == entities["test.connectBase"].id.to!string);
  
  assert("test.image" in entities);
  assert(entities["test.image"]["drawsource"] == "image.png");
  
  assert("test.external" in entities);
  assert(entities["test.external"]["source"] == "cannon.txt");
  //assert(entities["test.external"]["drawsource"] == "images/cannon.txt");
  writeln(entities["test.external"].values.to!string);
}

unittest
{
  string[string] values;
  values["source"] = "cannon.txt";
  values["foo"] = "bar";
  
  auto expandedValues = expandValues(values);
 
  writeln("expanded values: " ~ expandedValues.to!string);
 
  assert(expandedValues["source"] == "cannon.txt");
  assert(expandedValues["foo"] == "bar");
  assert(expandedValues["drawsource"] == "images/cannon.png");
}
string[string] expandValues(ref string[string] p_values)
{
  foreach (key, value; p_values)
  {
    auto fixedKey = key;
    while (fixedKey.findSkip(".")) {}
    
    if (fixedKey == "source")
    {
      auto fileName = p_values[key];
      
      auto fixedFileName = fileName;
      if (fixedFileName.startsWith("data/") == false)
        fixedFileName = "data/" ~ fileName;
      
      string[string] keyValues;
      foreach (string line; fixedFileName.File.lines)
      {
        line = line.strip;
        
        if (line.length > 0 && line.startsWith("#") == false)
        {
          auto keyAndValue = line.split("=");
        
          enforce(keyAndValue.length == 2, "Could not parse <key> = <value> from line " ~ line);
          
          auto key = keyAndValue[0].strip;
          auto value = keyAndValue[1].strip;
          
          keyValues[key] = value;
        }
      }
      
      auto expandedValues = expandValues(keyValues);
    
      foreach (key, value; expandedValues)
      {
        if (key !in p_values)
          p_values[key] = value;
      }
    }
  }
  
  return p_values;
}

Entity[string] loadEntityCollection(string collectionName, string[string] p_values, ref string[] orderedEntityNames)
{
  string[] lines;
  foreach (key, value; p_values)
  {
    lines ~= key ~ " = " ~ value;
  }
  
  return loadEntityCollection(collectionName, lines, orderedEntityNames);
}

Entity[string] loadEntityCollection(string collectionName, string[] p_lines, ref string[] orderedEntityNames)
{
  //writeln("loadentitycollection, name: " ~ collectionName ~ ", lines: " ~ p_lines.to!string);
  Entity[string] entities;

  // split lines into entity sections, each with unique name
  string[string][string] namedValues;
    
  foreach (string line; p_lines)
  {
    line = line.strip;
    
    if (line.length > 0 && line.startsWith("#") == false)
    {
      auto keyAndValue = line.split("=");
      
      enforce(keyAndValue.length == 2);
      
      auto key = keyAndValue[0].strip;
      auto value = keyAndValue[1].strip;
      
      auto nameAndRest = key.findSplit(".");
      
      auto name = collectionName;
      
      if (!nameAndRest[1].empty)
        name ~=  "." ~ nameAndRest[0];
        
      namedValues[name][key] = value;
      
      bool reservedName = false;
      string fixedName = name;
      while (fixedName.findSkip(".")) {}
      if (fixedName == "connectpoint" || fixedName == "spawn" || fixedName == "*")
        reservedName = true;
      
      if (orderedEntityNames.find(name).empty && !reservedName)
        orderedEntityNames ~= name;
    }
  }
  
  foreach (name, ref keyValues; namedValues)
  {
    keyValues = expandValues(keyValues);
  }
  
  // recursively expand entity collections
  // or not, assume they are already expanded
  /*foreach (name, keyValues; namedValues)
  {
    string fixedName = name;
    while (fixedName.findSkip(".")) {}
    
    if (fixedName ~ ".source" in keyValues)
    {
      auto fileName = keyValues[fixedName ~ ".source"];
      
      auto fixedFileName = fileName;
      if (fixedFileName.startsWith("data/") == false)
        fixedFileName = "data/" ~ fileName;
      
      string[] fileLines;
      foreach (string line; fixedFileName.File.lines)
        fileLines ~= line;
        
      writeln(fileLines.to!string);
        
      foreach (entityName, entity; loadEntityCollection(name, fileLines, orderedEntityNames))
      {
        writeln("entity from source: " ~ entityName ~ " vs ownername: " ~ name);
        
        if (entityName == name)
        {
          
        }
        
        string fixedEntityName = entityName;
        while (fixedEntityName.findSkip(".")) {}
        if (fixedEntityName == "connectpoint" || fixedEntityName == "spawn" || fixedEntityName == "*")
          continue;

        entities[entityName] = entity;
      }
    }
  }
  */
  
  // replace values like "0 to 10" with randomized values
  foreach (name, keyValues; namedValues)
  {
    namedValues[name] = parseRandomizedValues(keyValues);
  }
  
  
  // create entities out of values
  int[string] nameIdMapping;
  foreach (name, keyValues; namedValues)
  {
    string[string] fixedKeyValues;
    
    foreach (key, value; keyValues)
    {
      auto fixedKey = key;
      
      // TODO: better way to keep track of reserved values
      if (!fixedKey.find("connectpoint").empty)
        fixedKey = fixedKey.find("connectpoint");
      else if (!fixedKey.find("spawn").empty)
        fixedKey = fixedKey.find("spawn");
      else if (!fixedKey.find("*").empty)
        fixedKey = fixedKey.find("*");
      else
        while (fixedKey.findSkip(".")) {}
      
      fixedKeyValues[fixedKey] = value;
    }
  
    auto entity = new Entity(fixedKeyValues);
    
    string fixedName = name;
    while (fixedName.findSkip(".")) {}
    if ("name" !in entity)
      entity.setValue("name", fixedName);
    
    nameIdMapping[name] = entity.id;
    
    entities[name] = entity;
  }
    
  
  // replace certain values referring to names with ids, so that subsystems can properly register them
  foreach (name, ref keyValues; namedValues)
  {
    foreach (key, value; keyValues)
    {
      auto fixedKey = key;
      while (fixedKey.findSkip(".")) {}
            
      if (fixedKey == "connection")
      {
        auto connectionData = value.split(".");
        
        auto fullName = collectionName ~ "." ~ connectionData[0];
        
        enforce(fullName in nameIdMapping, "Entity " ~ name ~ " tried to connect to " ~ fullName ~ " which is not found in the given entity names: " ~ nameIdMapping.keys.to!string);
        
        entities[name].setValue(fixedKey, nameIdMapping[fullName].to!string ~ "." ~ connectionData[1]);
        entities[name].setValue("owner", nameIdMapping[fullName].to!string);
      }
      
      if (fixedKey == "owner")
      {
        auto fullName = collectionName ~ "." ~ value;
        
        enforce(fullName in nameIdMapping, "Could not find " ~ fullName ~ " in nameIdMapping, " ~ nameIdMapping.to!string);
        
        entities[name].setValue(fixedKey, nameIdMapping[fullName].to!string);
      }
    }
  }
  
  return entities;
}


string[string] parseRandomizedValues(string[string] inValues)
{
  string[string] outValues = inValues.dup;
  
  foreach (key, value; inValues)
  {  
    auto foundPosition = key.find("position");
    auto foundAngle = key.find("angle");
    
    if (!foundPosition.empty && !value.find("to").empty)
    {
      auto fromToData = value.split("to");
      auto from = fromToData[0].strip.to!(float[]);
      auto to = fromToData[1].strip.to!(float[]);
      
      auto x = (from[0] == to[0]) ? from[0] : uniform(from[0], to[0]);
      auto y = (from[1] == to[1]) ? from[1] : uniform(from[1], to[1]);
      
      auto position = vec2(x, y);
      
      outValues[key] = position.toString();
    }
    
    if (!foundAngle.empty && !value.find("to").empty)
    {
      auto angleData = inValues[key].findSplit("to");
      
      enforce(!angleData[0].empty && !angleData[1].empty && !angleData[2].empty, "Problem parsing angle data with from/to values: " ~ angleData.to!string);
      
      auto fromAngle = to!float(angleData[0].strip);
      auto toAngle = to!float(angleData[2].strip);
      
      auto angle = uniform(fromAngle, toAngle);
      
      outValues[key] = to!string(angle);
    }
  }
  
  return outValues;
}
