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
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.typetuple;

import gl3n.math;
import gl3n.linalg;

import Entity;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new ConnectionHandler();
  
  Entity ship = new Entity(["connectpoint.testpoint.position":"1 0"]);
  
  sys.registerEntity(ship);
  
  Entity engine = new Entity(["owner":to!string(ship.id),"relativePosition":"1 0"]);
  
  sys.registerEntity(engine);
  
  auto engineComponent = sys.getComponent(engine);
  
  assert(engineComponent.relativePosition == vec2(1.0, 0.0), "Engine didn't set relative position to 1 0, it's " ~ engineComponent.relativePosition.toString());
  
  auto connectPointsEntity = new Entity(["name":"connectPointsEntity","connectpoint.lower.position":"0 -1"]);
  
  sys.registerEntity(connectPointsEntity);
  
  auto connectPointsComponent = sys.getComponent(connectPointsEntity);
  
  assert(connectPointsComponent.connectPoints.length > 0);
  
  auto connectingEntity = new Entity(["owner": to!string(connectPointsEntity.id), "connection": to!string(connectPointsEntity.id) ~ ".lower"]);
  
  sys.registerEntity(connectingEntity);
  
  auto connectingComponent = sys.getComponent(connectingEntity);
  
  assert(connectingComponent.relativePosition == vec2(0, -1), "Connecting component didn't get relative position 0 -1, it got " ~ to!string(connectingComponent.relativePosition));
  
  // reload connectPointsComponent, check if connectpoint has correct connectedEntity
  connectPointsComponent = sys.getComponent(connectPointsEntity);
  assert(connectPointsComponent.connectPoints["lower"].connectedEntity == connectingEntity);
}


struct ConnectPoint
{
  string name;
  vec2 position = vec2(0.0, 0.0);
  Entity connectedEntity = null;
  Entity owner;
}


class ConnectionComponent
{
invariant()
{
  assert(owner !is null);
  assert(relativePosition.ok);
  assert(relativePositionToCenterOfMass.ok);
  assert(relativeAngle == relativeAngle);
  assert(mass == mass);
}


public:
  this(Entity p_owner)
  {
    owner = p_owner;
  }
  
public:
  Entity owner;
  
  vec2 position = vec2(0.0, 0.0);
  float angle = 0.0;
  
  float mass = 0.0;
  
  vec2 relativePosition = vec2(0.0, 0.0);
  vec2 relativePositionToCenterOfMass = vec2(0.0, 0.0);
  float relativeAngle = 0.0;
  
  ConnectPoint[string] connectPoints;
}


class ConnectionHandler : Base!(ConnectionComponent)
{
public:
  void update() 
  {
    return;
    foreach (component; components)
    {
      writeln("checking component with owner " ~ component.owner.id.to!string ~ ", has component: " ~ hasComponent(component.owner).to!string);
      
      if (component.owner !is null && hasComponent(component.owner))
      {
        auto ownerComponent = getComponent(component.owner);
        
        //writeln("got owner component with owner " ~ ownerComponent.owner.id.to!string ~ " from component with owner " ~ component.owner.id.to!string ~ ", component differs: " ~ (ownerComponent != component).to!string);
        
        writeln("updating connection position from " ~ component.position.toString() ~ " to " ~ (ownerComponent.position + component.relativePosition).toString());
        
        //if (ownerComponent != component)
        {
          component.position = ownerComponent.position + component.relativePosition;
        }
      }
    }
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
      if (componentToDisconnect.owner !is p_entity && p_entity.getValue("connection").length > 0)
      {
        auto entityId = to!int(extractEntityIdAndConnectPointName(p_entity.getValue("connection"))[0]);
        auto connectPointName = extractEntityIdAndConnectPointName(p_entity.getValue("connection"))[1];
      
        //foreach (siblingEntity; entities)
        // only look at entities whose owner is the same as p_entity
        foreach (siblingEntity; filter!(entity => entity != p_entity &&
                                                  getComponent(entity).owner == componentToDisconnect.owner &&
                                                  entityId == entity.id)(entities))
        {
          auto siblingComp = getComponent(siblingEntity);

          if (connectPointName in siblingComp.connectPoints)
          {
            siblingComp.connectPoints[connectPointName].connectedEntity = null;
            
            assert(getComponent(siblingEntity).connectPoints[connectPointName].connectedEntity is null);
            
            break;
          }
        }
        
        // entities connected to the disconnected entity should also be disconnected
        foreach (connectedEntity; getConnectedEntities(p_entity))
          disconnectEntity(connectedEntity);
      }
      
      //assert(hasComponent(componentToDisconnect.owner));
      //auto ownerComponent = getComponent(componentToDisconnect.owner);
      
      componentToDisconnect.relativePosition = vec2(0.0, 0.0);
      componentToDisconnect.relativePositionToCenterOfMass = vec2(0.0, 0.0);

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
    
  
  vec2[ConnectPoint] findOverlappingEmptyConnectPointsWithPosition(Entity p_entity, vec2 p_position)
  in
  {
    assert(p_entity !is null);
  }
  body
  {
    vec2[ConnectPoint] overlappingConnectPoints;
    
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

        auto connectPointPosition = component.position + mat2.rotation(-component.angle) * connectPoint.position;
        
        auto distanceToConnectPoint = (p_position - connectPointPosition).length;
        
        if (distanceToConnectPoint < radius)
        {
          overlappingConnectPoints[connectPoint] = component.position;
        }
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
    // since all entities can potentially be connected to, all entities are registered
    // NOPE just put em in the possibleOwners collection (this is a hack)
    //return true;
    
    possibleOwners[p_entity.id] = p_entity;
    
    foreach (value; p_entity.values.keys)
      if (value.startsWith("connectpoint"))
        return true;

    // we might want to check for owner OR connection value
    // but with only connection value we need to figure out owner in createComponent
    return p_entity.getValue("owner").length > 0;
  }
  
  
  ConnectionComponent createComponent(Entity p_entity)
  {
    // a connection component can be two things (TODO: this is bad and should be refactored so it is only one thing)
    // 1. when an entity is connected to another with connectpoints and connections
    // 2. when an entity has a relative position to another owner entity and keeps the position relative to that one when updating (the owner entity does not need to specify connectpoints)
    
    // in a better world, somebody would already have figured out all the values with connectpoint stuff and replaced that with owner and relativePosition values
  
    // to create a connectioncomponent from an entity:
    // 1. create connectpoints from entity values (could be none)
    // 2. if we have a connection value, figure out which entity we will connect to (this entity should already have been registered - the correct ordering here is up to the game class or whatever is registering these entities)
    // 3. set the owner entity
  
    //enforce("position" in p_entity.values, "Could not find position value when registering entity to connection subsystem");
  
    // all entities are their own owners to begin with
    Entity owner = p_entity;
    
    auto connectPoints = createConnectPoints(p_entity);
    
    vec2 relativePosition = vec2(0.0, 0.0);
    vec2 relativePositionToCenterOfMass = vec2(0.0, 0.0);
    
    if ("connection" in p_entity)
    {
      auto entityIdAndConnectPointName = p_entity.getValue("connection").extractEntityIdAndConnectPointName();
      
      auto connectEntityId = -1;
      try { connectEntityId = entityIdAndConnectPointName[0].to!int; } catch (ConvException) {}
      
      auto connectPointName = entityIdAndConnectPointName[1];
      
      enforce(connectEntityId in possibleOwners, "Could not find connect-to entity with id " ~ to!string(connectEntityId));
      Entity connectToEntity = possibleOwners[connectEntityId];
      enforce(hasComponent(connectToEntity), "Could not find connectcomponent for connect-to entity with id " ~ to!string(connectEntityId));
      
      auto connectComponent = getComponent(connectToEntity);
      
      enforce(connectPointName in connectComponent.connectPoints, "Could not find connectpoint " ~ connectPointName ~ " in connect-to entity with id " ~ connectEntityId.to!string);
      auto connectPoint = connectPointName in connectComponent.connectPoints;
      
      if (connectPoint && connectPoint.connectedEntity is null)
      {
        connectPoint.connectedEntity = p_entity;
        // TODO: is it really ok to update another component while creating this one?
        setComponent(connectToEntity, connectComponent);
        
        assert(getComponent(connectToEntity).connectPoints[connectPointName].connectedEntity == p_entity);
        
        relativePosition = getComponent(connectToEntity).relativePosition + connectPoint.position;
      }
    }
    
    if (p_entity.getValue("owner").length > 0)
    {
      int ownerId = p_entity.getValue("owner").to!int;
      
      //writeln("checking ownerid " ~ ownerId.to!string ~ " against possibleowners: " ~ possibleOwners.keys.to!string);
      
      if (ownerId != p_entity.id && ownerId in possibleOwners)
      {
        owner = possibleOwners[ownerId];
      }
      
      /*if (ownerId != p_entity.id)
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
      }*/
    }
    
    //writeln("creating connectioncomponent for " ~ p_entity.values.to!string ~ " with owner " ~ owner.id.to!string);
    
    auto newComponent = new ConnectionComponent(owner);
    
    newComponent.relativePosition = relativePosition;
    newComponent.relativePositionToCenterOfMass = relativePosition; // calculate actual center of mass position later on
    newComponent.connectPoints = connectPoints;
    
    if (p_entity.getValue("relativePosition").length > 0)
    {
      newComponent.relativePosition = vec2(p_entity.getValue("relativePosition").to!(float[])[0..2]);
    }
    
    if (p_entity["name"] != "Mouse cursor" && p_entity["name"] != "infotext")
      writeln("Entity " ~ p_entity["name"] ~ " setting relativePosition to " ~ newComponent.relativePosition.to!string);
    
    if (p_entity.getValue("relativeAngle").length > 0)
    {
      newComponent.relativeAngle = to!float(p_entity.getValue("relativeAngle")) * PI_180;
    }
    else if ("angle" in p_entity)
    {
      newComponent.relativeAngle = p_entity["angle"].to!float * PI_180;
    }
    
    if (p_entity.getValue("mass").length > 0)
      newComponent.mass = to!float(p_entity.getValue("mass"));
    
    return newComponent;
  }
  
  
private:
  private ConnectPoint[string] createConnectPoints(Entity p_entity)
  {
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
          connectPoint.position = vec2(p_entity.getValue(value).to!(float[])[0..2]);
        
        if ("radius" in p_entity.values)
          connectPoint.position *= to!float(p_entity.getValue("radius"));

        connectPoints[connectPointName] = connectPoint;
      }
    }
    
    return connectPoints;
  }
  
  
private:
  Entity[int] possibleOwners;
  
  ConnectionComponent[Entity] componentToOwner;
}


// returns [0] == entity name or id, [1] == connect point name
string[2] extractEntityIdAndConnectPointName(string p_data)
{
  // p_data looks like 'entityname.connectpointname'
  // entityname may contain '.' characters, so everything until the last '.' is entityname, rest is connectpointname
  // so we split into entity and connectpoint name by reversing and splitting by first '.' (which will be the last) and reversing again to get out names
  auto connectionData = p_data.retro.findSplit(".");

  //return [to!string(retro(to!string((connectionData[2])))), to!string(retro(to!string((connectionData[0]))))];
  return [connectionData[2].to!string.retro.to!string, connectionData[0].to!string.retro.to!string];
}
