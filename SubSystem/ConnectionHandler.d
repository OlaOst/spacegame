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

module SubSystem.ConnectionHandler;

import std.algorithm;
import std.conv;
import std.stdio;
import std.string;

import Entity;
import SubSystem.Base;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new ConnectionHandler();
  
  Entity ship = new Entity();
  ship.setValue("connectpoint.testpoint.position", "1 0");
  
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
  
  
  auto connectPointsEntity = new Entity();
  connectPointsEntity.setValue("name", "connectPointsEntity");
  //connectPointsEntity.setValue("connectTarget", "true");
  connectPointsEntity.setValue("connectpoint.lower.position", "0 -1");
  //connectPointsEntity.setValue("connectpoint.upper.position", "0 1");
  
  sys.registerEntity(connectPointsEntity);
  
  auto connectPointsComponent = sys.getComponent(connectPointsEntity);
  
  assert(connectPointsComponent.connectPoints.length > 0);
  
  auto connectingEntity = new Entity();
  connectingEntity.setValue("owner", to!string(connectPointsEntity.id));
  connectingEntity.setValue("connection", "connectPointsEntity.lower");
  
  sys.registerEntity(connectingEntity);
  
  auto connectingComponent = sys.getComponent(connectingEntity);
  
  assert(connectingComponent.relativePosition == Vector(0, -1));
  
  // reload connectPointsComponent, check if connectpoint is no longer empty
  connectPointsComponent = sys.getComponent(connectPointsEntity);
  assert(connectPointsComponent.connectPoints[0].empty == false);
}


struct ConnectPoint
{
  string name;
  Vector position = Vector.origo;
  bool empty = true;
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
  
  ConnectPoint[] connectPoints;
}


class ConnectionHandler : public Base!(ConnectionComponent)
{
public:
  void update() {}
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    foreach (value; p_entity.values.keys)
      if (value.startsWith("connectpoint"))
        return true;
        
    return p_entity.getValue("owner").length > 0;
  }
  
  
  ConnectionComponent createComponent(Entity p_entity)
  {
    Entity owner = null;
    
    ConnectPoint[] connectPoints;
    
    foreach (value; p_entity.values.keys)
    {
      if (value.startsWith("connectpoint"))
      {
        auto connectPointData = value.split(".");
        
        assert(connectPointData.length == 3);
        
        auto connectPointName = connectPointData[1];
        auto connectPointAttribute = connectPointData[2];
        
        ConnectPoint connectPoint;
        connectPoint.name = connectPointName;
        connectPoint.empty = true;
        if (connectPointAttribute == "position")
          connectPoint.position = Vector.fromString(p_entity.getValue(value));
          
        connectPoints ~= connectPoint;
        
        // connectTargets are their own owners
        owner = p_entity;
      }
    }
    
    Vector relativePosition = Vector.origo;    
    if (p_entity.getValue("connection").length > 0)
    {
      auto stuff = p_entity.getValue("connection").split(".");
      
      auto connectEntityName = stuff[0];
      auto connectPointName = stuff[1];
      bool foundConnectPoint = false;
      
      foreach (connectEntity; entities)
      {
        if (connectEntity.getValue("name") == connectEntityName)
        {
          auto connectComponent = getComponent(connectEntity);
          
          foreach (ref connectPoint; connectComponent.connectPoints)
          {
            if (connectPoint.name == connectPointName)
            {
              connectPoint.empty = false;
              setComponent(connectEntity, connectComponent);
              
              relativePosition = connectPoint.position;
              foundConnectPoint = true;
              break;
            }
          }
        }
        if (foundConnectPoint)
          break;
      }
    }
    
    if (p_entity.getValue("owner").length > 0)
    {
      int ownerId = to!int(p_entity.getValue("owner"));
      
      if (ownerId == p_entity.id)
      {
        owner = p_entity;
      }
      else
      {
      
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
    }
    
    assert(owner !is null, "Could not find owner with id " ~ p_entity.getValue("owner"));
    
    auto newComponent = new ConnectionComponent(owner);
    
    newComponent.relativePosition = relativePosition;
    newComponent.connectPoints = connectPoints;
    
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
