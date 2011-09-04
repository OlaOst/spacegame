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
import std.array;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.string;
import std.typetuple;

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
  
  // reload connectPointsComponent, check if connectpoint has correct connectedEntity
  connectPointsComponent = sys.getComponent(connectPointsEntity);
  assert(connectPointsComponent.connectPoints["lower"].connectedEntity == connectingEntity);
}


struct ConnectPoint
{
  string name;
  Vector position = Vector.origo;
  Entity connectedEntity = null;
  Entity owner;
}


class ConnectionComponent
{
invariant()
{
  assert(owner !is null);
  assert(relativePosition.isValid());
  assert(relativeAngle == relativeAngle);
}


public:
  this(Entity p_owner)
  {
    owner = p_owner;
    
    position = Vector.origo;
    angle = 0.0;
    
    relativePosition = Vector.origo;
    relativeAngle = 0.0;
  } 
  
  
public:
  Entity owner;
  
  Vector position;
  float angle;
  
  Vector relativePosition;
  float relativeAngle;
  
  ConnectPoint[string] connectPoints;
}


class ConnectionHandler : public Base!(ConnectionComponent)
{
public:
  void update() 
  {
  }
  
  
  override void removeEntity(Entity p_entity)
  {
    disconnectEntity(p_entity);
    super.removeEntity(p_entity);
  }
  
  // disconnect an entity and update owners connectpoints etc
  void disconnectEntity(Entity p_entity)
  {
    if (hasComponent(p_entity))
    {
      auto componentToDisconnect = getComponent(p_entity);

      // set connectpoint.connectedEntity = null so it's free for other entities
      if (componentToDisconnect.owner !is p_entity)
      {
        auto entityName = extractEntityAndConnectPointName(p_entity.getValue("connection"))[0];
        auto connectPointName = extractEntityAndConnectPointName(p_entity.getValue("connection"))[1];
      
        foreach (siblingEntity; entities)
        {
          // only look at entites whose owner is the same as p_entity
          if (siblingEntity == p_entity || 
              getComponent(siblingEntity).owner != componentToDisconnect.owner || 
              entityName != siblingEntity.getValue("name"))
            continue;

          auto siblingComp = getComponent(siblingEntity);

          if (connectPointName in siblingComp.connectPoints)
          {
            siblingComp.connectPoints[connectPointName].connectedEntity = null;
            
            assert(getComponent(siblingEntity).connectPoints[connectPointName].connectedEntity is null);
            
            break;
          }
        }
      }
      
      componentToDisconnect.relativePosition = Vector.origo;
      
      // a disconnected entity owns itself
      componentToDisconnect.owner = p_entity;
      
      // TODO: any entities connected to p_entity needs to have stuff updated - owner, relativePosition, etc
      // might be better to look for any entities with owner = original owner
    }
  }
  
  
  Entity[] getOwnedEntities(Entity p_entity)
  {
    Entity[] owned;
    
    foreach (entity; entities)
    {
      if (getComponent(entity).owner == p_entity && entity != p_entity)
        owned ~= entity;
    }
    
    return owned;
  }
  
  
  Entity[] getConnectedEntities(Entity p_entity)
  {
    if (hasComponent(p_entity) == false)
      return [];
      
    Entity[] connectedEntities;
    
    auto connectPoints = getComponent(p_entity).connectPoints;
    
    foreach (connectPoint; connectPoints)
    {
      if (connectPoint.connectedEntity !is null)
        connectedEntities ~= connectPoint.connectedEntity;
    }
    
    return connectedEntities;
  }
    
  
  Vector[ConnectPoint] findOverlappingEmptyConnectPointsWithPosition(Entity p_entity, Vector p_position)
  in
  {
    assert(p_entity !is null);
  }
  body
  {
    Vector[ConnectPoint] overlappingConnectPoints;
    
    auto radius = to!float(p_entity.getValue("radius"));
    
    foreach (component; components)
    {
      // ignore your own connectpoints
      if (hasComponent(p_entity) && getComponent(p_entity) == component)
        continue;

      foreach (connectPoint; component.connectPoints)
      {
        // ignore nonempty connectpoints
        if (connectPoint.connectedEntity !is null)
          continue;
          
        // assume component positions are up to date
        auto connectPointPosition = component.position + connectPoint.position;
        
        auto distanceToConnectPoint = (p_position - connectPointPosition).length2d;
        
        if (distanceToConnectPoint < radius)
          overlappingConnectPoints[connectPoint] = component.position;
      }
    }
    
    return overlappingConnectPoints;
  }
  
  /*void connectEntityToConnectPoint(Entity p_entity, ConnectPoint p_connectPoint)
  {
    p_connectPoint.connectedEntity = p_entity;
    
    assert(hasComponent(p_entity));
    
    // TODO: update owner entity with mass, center of mass etc
    auto component = getComponent(p_entity);
    
    component.owner = p_connectPoint.owner.owner;
  }*/

  
protected:

  bool canCreateComponent(Entity p_entity)
  {
    foreach (value; p_entity.values.keys)
      if (value.startsWith("connectpoint"))
        return true;

    // we might want to check for owner OR connection value
    // but with only connection value we need to figure out owner in createComponent
    return p_entity.getValue("owner").length > 0;
  }

  
  ConnectionComponent createComponent(Entity p_entity)
  {
    Entity owner = null;
    
    ConnectPoint[string] connectPoints;
    
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
        connectPoint.connectedEntity = null;
        connectPoint.owner = p_entity;
        if (connectPointAttribute == "position")
          connectPoint.position = Vector.fromString(p_entity.getValue(value));
          
        connectPoints[connectPointName] = connectPoint;
        
        // entities with connectpoints are their own owners to begin with
        owner = p_entity;
      }
    }
    
    Vector relativePosition = Vector.origo;
    if (p_entity.getValue("connection").length > 0)
    {
      auto entityAndConnectPointName = extractEntityAndConnectPointName(p_entity.getValue("connection"));
      
      auto connectEntityName = entityAndConnectPointName[0];
      auto connectPointName = entityAndConnectPointName[1];
      
      Entity connectToEntity;
      
      foreach (cand; entities)
      {
        if (cand.getValue("name") == connectEntityName)
        {
          connectToEntity = cand;
          break;
        }
      }
      
      enforce(connectToEntity !is null, "Could not find connect-to entity named " ~ connectEntityName);
      enforce(hasComponent(connectToEntity), "Could not find connectcomponent for connect-to entity named " ~ connectEntityName);
      
      auto connectComponent = getComponent(connectToEntity);
      
      auto connectPoint = connectPointName in connectComponent.connectPoints;
      
      if (connectPoint && connectPoint.connectedEntity is null)
      {
        connectPoint.connectedEntity = p_entity;
        setComponent(connectToEntity, connectComponent);
        
        assert(getComponent(connectToEntity).connectPoints[connectPointName].connectedEntity == p_entity);
        
        relativePosition = getComponent(connectToEntity).relativePosition + connectPoint.position;
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


// returns [0] == entity name, [1] == connect point name
string[2] extractEntityAndConnectPointName(string p_data)
{
  // p_data looks like 'entityname.connectpointname'
  // entityname may contain '.' characters, so everything until the last '.' is entityname, rest is connectpointname
  // so we split into entity and connectpoint name by reversing and splitting by first '.' (which will be the last) and reversing again to get out names
  auto connectionData = findSplit(retro(p_data), ".");

  return [to!string(retro(to!string((connectionData[2])))), to!string(retro(to!string((connectionData[0]))))];
}
