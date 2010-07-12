module ConnectionSubSystem;

import std.conv;

import Entity;
import SubSystem : SubSystem;


unittest
{
  auto sys = new ConnectionSubSystem();
  
  Entity ship = new Entity();
  ship.setValue("mass", "2.0");
  
  sys.registerEntity(ship);
  
  Entity engine = new Entity();
  engine.setValue("owner", to!string(ship.id));
  engine.setValue("mass", "1.0");
  
  sys.registerEntity(engine);
  
  // the engine has a controller
  // the controller sends accelerate intent to engine
  // the connection system propagates the engine force to its owner entity
  // the top level entity (the ship) aggregates forces and stuff from children entities
  // only the top level entity should be in physics system
  // when physics have updated top level entity positions, connection system needs to update all children entities
  
  // 1. entities are updated from controllers
  // 2. connection system propagates intents and stuff to top level entity
  // 3. physics update top level entity
  // 4. connection system propagates position and stuff to children of top level entities
  
  // right now controllers directly update physics components
  // they should update connection components instead
  
  
  // is the engine entity accelerating?
  // then the ship entity needs to move
  //sys.update...
}


class ConnectionComponent
{

}


class ConnectionSubSystem : public SubSystem!(ConnectionComponent)
{
protected:
  ConnectionComponent createComponent(Entity p_entity)
  {
    return new ConnectionComponent();
  }
}
