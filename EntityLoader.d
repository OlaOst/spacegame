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
  
  
  
  // get values - DONE
  // expand source values - DONE
  // (child entities not expanded yet)
  // figure out child entities
  // get values for child entities (recursive)
  // expand wildcard values (ie entity with two children and a line like *.foo = bar means both children should have a foo = bar value)
  // value accumulation done in subsystems, on a per-entity basis (when registering child entity physics will update mass of parent entity)
  
  string[] linesWithChildren = ["hei = hoi", "child1.source = unittest.data", "child2.source = unittest.data", "*.one = foo", "child1.three = bar"];
  
  values = getValues(cache, linesWithChildren);
  
  string[string][string] childValues = findChildValues(cache, values);
  
  assert(childValues.length == 2, to!string(childValues));
  assert("child1" in childValues);
  assert("child2" in childValues);
  
  assert("a" in childValues["child1"], to!string(childValues["child1"]));
  
  assert(childValues["child1"]["a"] == "b");
  assert(childValues["child1"]["one"] == "foo");
  assert(childValues["child2"]["one"] == "foo");
  assert(childValues["child1"]["three"] == "bar");
}


void addValue(string line, ref string[string] values)
{
  if (line.strip.length > 0 && line.strip.startsWith("#") == false)
  {
    line = line.strip;
    
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
  auto file = File("data/" ~ filename);
  
  foreach (string line; lines(file))
    cache[filename] ~= line;
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


string[string][string] findChildValues(ref string[][string] cache, string[string] values)
{
  string[string][string] childValues;
  foreach (key, value; values)
  {
    if (key.find(".").length > 0)
    {
      string childName = to!string(key.until("."));
      
      if (childName.length == 0 || childName == "*")
        continue;
      
      string childKey = key;
      
      auto ck = childKey.find(".")[1..$];
      
      childValues[childName][ck] = value;
    }
  }
  
  // expand source values in children
  foreach (childName, values; childValues)
  {
    foreach (key, value; values)
    {
      if (key == "source")
      {
        string sourceFilename = value;
        
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

// a datasource may define multiple entities
/+
Entity[] loadData(string data)
{
  Entity[] entities;
  
  auto values = getValues(data);
  
  entities ~= new Entity(values);
  
  string[] orderedChildEntityNames;
  
  foreach (key, value; values)
  {
    if (key.find(".").length > 0)
    {
      if (orderedChildEntityNames.find(to!string(key.until("."))) == [])
        orderedChildEntityNames ~= to!string(key.until("."));
    }
  }
  
  // load in child entities, signified by <childentity>.source = <source filename>
  foreach (orderedChildEntityName; orderedChildEntityNames)
  {
    auto source = values.keys.find(orderedChildEntityName ~ ".source");
    if (source.length == 0)
      continue;
    auto childSource = source[0];
  
    auto childValues = getValues("data/" ~ values[childSource]);

    //Entity subEntity = new Entity("data/" ~ ship.getValue(subSource));

    //subEntity.setValue("name", subSource);
    
    auto subName = subSource[0..std.string.indexOf(subSource, ".source")];
    
    // all references to subName should be replaced with the entity id, since the id is guaranteed unique
    nameToId[subName] = subEntity.id;
    
    subEntity.setValue("owner", to!string(ship.id));
    
    // inital position of submodules are equal to owner module position
    subEntity.setValue("position", ship.getValue("position"));      
    
    // set extra values on submodule from the module that loads them in
    foreach (subSourceValue; filter!(delegate(x) { return x.startsWith(subName ~ "."); })(ship.values.keys))
    {
      auto key = subSourceValue[std.string.indexOf(subSourceValue, '.')+1..$];
      
      subEntity.setValue(key, ship.getValue(subSourceValue));
    }
    
    if (subEntity.getValue("mass").length > 0)
    {
      accumulatedMass += to!float(subEntity.getValue("mass"));
    }
    
    subEntitiesToAdd[subEntity.id] = subEntity;
  }
  
  return entities;
}


Entity loadShip(string p_fileName, string[string] p_extraParams = null)
{
  writeln("loading ship from file " ~ p_fileName ~ ", with extraparams " ~ to!string(p_extraParams));
  Entity ship = new Entity("data/" ~ p_fileName, p_extraParams);
  
  if (ship.getValue("name").length == 0)
    ship.setValue("name", p_fileName);
  
  // need to add sub entities after they're loaded
  // since the ship entity needs accumulated values from sub entities
  // and sub entities must have the ship registered before they can be registered themselves
  Entity[int] subEntitiesToAdd;
  float accumulatedMass = 0.0;

  int[string] nameToId;
  
  // figure out ordered list of submodules
  string[] orderedSubModuleNames;
  auto file = File("data/" ~ p_fileName);
  foreach (string line; lines(file))
  {
    if (line.strip.length > 0 && line.strip.startsWith("#") == false)
    {
      auto key = to!string(line.strip.until("=")).strip;
      
      if (key.find(".").length > 0)
      {
        if (orderedSubModuleNames.find(to!string(key.until("."))) == [])
          orderedSubModuleNames ~= to!string(key.until("."));
      }
    }
  }
  
  // load in submodules, signified by <modulename>.source = <module source filename>
  foreach (orderedSubModuleName; orderedSubModuleNames)
  {
    auto source = ship.values.keys.find(orderedSubModuleName ~ ".source");
    if (source.length == 0)
      continue;
    auto subSource = source[0];
  
    Entity subEntity = new Entity("data/" ~ ship.getValue(subSource));
    
    subEntity.setValue("name", subSource);
    
    auto subName = subSource[0..std.string.indexOf(subSource, ".source")];
    
    // all references to subName should be replaced with the entity id, since the id is guaranteed unique
    nameToId[subName] = subEntity.id;
    
    subEntity.setValue("owner", to!string(ship.id));
    
    // inital position of submodules are equal to owner module position
    subEntity.setValue("position", ship.getValue("position"));      
    
    // set extra values on submodule from the module that loads them in
    foreach (subSourceValue; filter!(delegate(x) { return x.startsWith(subName ~ "."); })(ship.values.keys))
    {
      auto key = subSourceValue[std.string.indexOf(subSourceValue, '.')+1..$];
      
      subEntity.setValue(key, ship.getValue(subSourceValue));
    }
    
    if (subEntity.getValue("mass").length > 0)
    {
      accumulatedMass += to!float(subEntity.getValue("mass"));
    }
    
    subEntitiesToAdd[subEntity.id] = subEntity;
  }
  
  // keys on the form *.somekey = somevalue are for all subentities
  foreach (wildCard; filter!("a.startsWith(\"*.\")")(ship.values.keys))
  {
    //writeln("found wildcard " ~ wildCard[2..$] ~ " with value " ~ ship.getValue(wildCard));
    
    foreach (subEntity; subEntitiesToAdd.values)
    {
      subEntity.setValue(wildCard[2..$], ship.getValue(wildCard));
    }
  }
  
  if (accumulatedMass > 0.0)
    ship.setValue("mass", to!string(accumulatedMass));
  
  // ship entity is its own owner, this is also needed to register it to connection system
  ship.setValue("owner", to!string(ship.id));
  
  registerEntity(ship);
  
  Entity[Entity] entityDependicy;
  
  foreach (subEntity; subEntitiesToAdd)
  {
    // rename connection value to ensure it points to the unique entity created for the ship
    if (subEntity.getValue("connection").length > 0)
    {
      auto connectionValues = split!(string, string)(subEntity.getValue("connection"), ".");
      
      // TODO: unittest that these enforces kick in when they should
      enforce(connectionValues.length == 2);
      enforce(connectionValues[0] in nameToId, "Could not find " ~ subEntity.getValue("connection") ~ " when loading " ~ subEntity.getValue("name") ~ ". Make sure " ~ connectionValues[0] ~ " is defined before " ~ subEntity.getValue("name") ~ " in " ~ p_fileName ~ ". nameToId mappings: " ~ to!string(nameToId));
      
      auto connectionName = to!string(nameToId[connectionValues[0]]) ~ "." ~ connectionValues[1];
      
      // delay registering this subentity if the entity it's connected to hasn't been registered yet
      if (m_connector.hasComponent(subEntitiesToAdd[nameToId[connectionValues[0]]]) == false)
        entityDependicy[subEntity] = subEntitiesToAdd[nameToId[connectionValues[0]]];
      
      subEntity.setValue("connection", connectionName);
    }
    
    if (subEntity !in entityDependicy)
      registerEntity(subEntity);
    else if (m_connector.hasComponent(entityDependicy[subEntity]))
      registerEntity(subEntity);
  }
  
  // loop over dependent entities until all are registered
  while (entityDependicy.length > 0)
  {
    Entity[Entity] newEntityDependicy;
    
    foreach (entity; entityDependicy.keys)
    {
      if (m_connector.hasComponent(entityDependicy[entity]))
        registerEntity(entity);
      else
        newEntityDependicy[entity] = entityDependicy[entity];
    }
    
    // if no entities were registered and all were put in newEntityDependicy, we have a cycle or something
    enforce(newEntityDependicy.length < entityDependicy.length, "Could not resolve entity dependicies when loading " ~ p_fileName);
    
    entityDependicy = newEntityDependicy;
  }

  return ship;
}
+/