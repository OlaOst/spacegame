﻿/*
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

module SubSystem.ConnectionHandler;

import std.conv;
import std.stdio;

import Entity;
import SubSystem.Base;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new ConnectionHandler();
  
  Entity ship = new Entity();
  ship.setValue("connectTarget", "true");
  
  sys.registerEntity(ship);
  
  Entity engine = new Entity();
  engine.setValue("owner", to!string(ship.id));
  engine.setValue("relativePosition", "1 0");
  //engine.setValue("mass", "1.0");
  
  sys.registerEntity(engine);
  
  auto engineComponent = sys.getComponent(engine);
  
  assert(engineComponent.relativePosition == Vector(1.0, 0.0), "Engine didn't set relative position to 1 0 0, it's " ~ engineComponent.relativePosition.toString());
  //assert(engineComponent.owner.entity == ship);
  
  // TODO: we need to take combined mass of ship and engine into account, this assumes just a mass of 1
  //assert(ship.position == Vector(1, 0, 0));
  
  //assert(engine.position == engineComponent.relativePosition + ship.position);
}


class ConnectionComponent
{
invariant()
{
  assert(owner !is null);
  assert(relativePosition.isValid());
  assert(relativeAngle == relativeAngle);
  
  // if the component has an owner, it should not have a grandparent
  // so it's not a tree structure
  // if an engine is connected to a skeleton, the owner component is still the ship, not the skeleton
  /*if (owner !is null)
  {
    assert(owner.owner is null);
  }*/
}


public:
  this(Entity p_owner)
  {
    owner = p_owner;
    
    relativePosition = Vector.origo;
    relativeAngle = 0.0;
    
    //force = Vector.origo;
    //torque = 0.0;
  } 
  
  
public:
  Entity owner;
  
  Vector relativePosition;
  float relativeAngle;
}


class ConnectionHandler : public Base!(ConnectionComponent)
{
public:
  void update() {}
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return (p_entity.getValue("owner").length > 0 ||
            p_entity.getValue("connectTarget").length > 0);
  }
  
  
  ConnectionComponent createComponent(Entity p_entity)
  {
    Entity owner = null;
    
    if (p_entity.getValue("owner").length > 0)
    {
      int ownerId = to!int(p_entity.getValue("owner"));
      
      foreach (entity; entities)
      {
        if (entity.id == ownerId)
        {
          // this should maybe be an enforce instead? 
          // nope, owner ids are translated from names in data files
          // the name->entity.id translation should throw if it doesn't find a match
          //assert(hasComponent(entity));
          
          //newComponent.owner = getComponent(entity);
          owner = entity;
          break;
        }
      }
    }
    
    // connectTargets are their own owners
    if (p_entity.getValue("connectTarget").length > 0)
    {
      owner = p_entity;
    }
    
    assert(owner !is null, "Could not find owner with id " ~ p_entity.getValue("owner"));
    
    auto newComponent = new ConnectionComponent(owner);
    
    if (p_entity.getValue("relativePosition").length > 0)
    {
      newComponent.relativePosition = Vector.fromString(p_entity.getValue("relativePosition"));
    }
    
    if (p_entity.getValue("relativeAngle").length > 0)
    {
      newComponent.relativeAngle = to!float(p_entity.getValue("relativeAngle"));
    }
    
    return newComponent;
  }
  
  
private:
}
