/*
 Copyright (c) 2012 Ola Østtveit

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

module SubSystem.RelationHandler;

import std.algorithm;
import std.exception;
import std.stdio;

import gl3n.linalg;

import SubSystem.Base;

import Entity;


unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto handler = new RelationHandler();
  
  Entity parent = new Entity(["name" : "parent", "position" : "[0.0, 1.0]", "isRelation" : "true"]);
  Entity child = new Entity(["name" : "child", "relationName" : "parent", "relativePosition" : "[1.0, 0.0]"]);
  
  handler.registerEntity(parent);
  handler.registerEntity(child);  
  
  assert(handler.getComponent(parent).name == "parent");
  assert(handler.getComponent(child).name == "child");
  assert(handler.getComponent(child).relationName == "parent");
  
  assert(handler.getComponent(parent).position == vec2(0.0, 1.0));
  assert(handler.getComponent(child).position == vec2(0.0, 0.0), "Expected " ~ vec2(0.0, 0.0).to!string ~ ", got " ~ handler.getComponent(child).position.to!string);
  
  handler.update();
  
  assert(handler.getComponent(parent).position == vec2(0.0, 1.0));
  assert(handler.getComponent(child).position == vec2(1.0, 1.0), "Expected " ~ vec2(1.0, 1.0).to!string ~ ", got " ~ handler.getComponent(child).position.to!string);
  
  
  handler.getComponent(parent).position = vec2(1.0, 0.0);
  
  assert(handler.getComponent(parent).position == vec2(1.0, 0.0));
  
  handler.update();
  
  assert(handler.getComponent(parent).position == vec2(1.0, 0.0));
  assert(handler.getComponent(child).position == vec2(2.0, 0.0));
  
  
  handler.removeEntity(parent);
  handler.removeEntity(child);
  
  assert("parent" !in handler.relationMapping);
  assert("child" !in handler.relationMapping);
}

interface Relater
{
  RelationComponent update(RelationComponent base, RelationComponent relation);
  
  string[string] values();
}

class PositionRelater : Relater
{
  public:
    this(vec2 p_relativePosition)
    {
      relativePosition = p_relativePosition;
    }
    
    override RelationComponent update(RelationComponent base, RelationComponent relation)
    {
      debug writeln("positionrelater position from " ~ base.position.to!string ~ " to " ~ (relation.position + relativePosition).to!string);
    
      base.position = relation.position + relativePosition;
      
      return base;
    }
    
    override string[string] values()
    {
      // TODO: should we prefix Relater values?
      return ["relativePosition" : relativePosition.to!string];
    }
    
  private:
    vec2 relativePosition;
}

class RelationComponent
{
  string name;
  string relationName;
  
  Relater relater;
  
  vec2 position = vec2(0.0, 0.0);
}

class RelationHandler : Base!(RelationComponent)
{
public:
  this()
  {
  }
  
  void update()
  {
    foreach (component; components.filter!(component => component.relationName.length > 0))
    {
      assert(component.relationName in relationMapping);
      assert(component.relater !is null, "Relater is null for component " ~ component.name);
      
      component = component.relater.update(component, relationMapping[component.relationName]);
    }
  }
  
  override void removeEntity(Entity p_entity)
  {
    super.removeEntity(p_entity);
    
    if ("name" in p_entity && p_entity["name"] in relationMapping)
      relationMapping.remove(p_entity["name"]);
  }
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return ("relationName" in p_entity) !is null || ("isRelation" in p_entity) !is null;
  }
  
  
  RelationComponent createComponent(Entity p_entity)
  {
    auto component = new RelationComponent();
    
    if ("name" in p_entity)
      component.name = p_entity["name"];
      
    if ("relationName" in p_entity)
    {
      //debug writeln("entity " ~ p_entity["name"] ~ " with relationname " ~ p_entity["relationName"]);
      enforce(p_entity["relationName"] in relationMapping, "Could not find RelationComponent named " ~ p_entity["relationName"] ~ " for component " ~ component.name);
      component.relationName = p_entity["relationName"];
    }
      
    if ("position" in p_entity)
      component.position = vec2(p_entity["position"].to!(float[])[0..2]);
    
    if ("relativePosition" in p_entity)
      component.relater = new PositionRelater(vec2(p_entity["relativePosition"].to!(float[])[0..2]));
    
    enforce(component.name.length > 0, "Cannot create RelationComponent without name");
    enforce(component.name !in relationMapping, "RelationComponent with name " ~ component.name ~ " already registered");
    
    relationMapping[component.name] = component;
    
    return component;
  }
  
  override void updateEntity(Entity entity)
  {
    if (hasComponent(entity))
    {
      auto component = getComponent(entity);
      
      if (component.relater !is null)
      {
        foreach (key, value; component.relater.values)
        {
          entity.values[key] = value;
        }
      }
    }
  }
  
  
private:
  RelationComponent[string] relationMapping;
}
