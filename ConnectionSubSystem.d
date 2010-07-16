module ConnectionSubSystem;

import std.conv;

import Control;
import Entity;
import FlockControl;
import InputHandler;
import PlayerControl;
import PhysicsSubSystem;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  // this control will just apply force to the right
  class MockControl : public Control
  {
  public:
    void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents)
    {
      p_sourceComponent.force = Vector(1.0, 0.0);
      p_sourceComponent.torque = 0.0;
    }
  }
  
  auto sys = new ConnectionSubSystem(new InputHandler(), new PhysicsSubSystem());
  
  Entity ship = new Entity();
  ship.setValue("mass", "2.0");
  ship.setValue("control", "mock");
  
  sys.registerEntity(ship);
  
  // macgyver in the mock control here, we don't want to know about it in the createComponent implementation
  sys.m_controlMapping[sys.findComponents(ship)[0]] = new MockControl();
  
  Entity engine = new Entity();
  engine.setValue("owner", to!string(ship.id));
  engine.setValue("mass", "1.0");
  
  sys.registerEntity(engine);
  
  assert(sys.findComponents(engine)[0].owner.entity == ship);
  
  sys.updateFromControllers();
  
  // assert that force from controller got propagated from engine to ship
  assert(sys.findComponents(ship)[0].force == Vector(1.0, 0.0));
    
  // the engine has a controller
  // the controller sends accelerate intent to engine
  // the connection system propagates the engine force to its owner entity
  // the top level entity (the ship) aggregates forces and stuff from children entities
  // only the top level entity should be in physics system
  // when physics have updated top level entity positions, connection system needs to update all children entities
  
  // 1. entities are updated from controllers
  // 2. connection system propagates intents and stuff to top level entity
  // 2b. physics component need to update force and torque and etc from connection component 
  // 3. physics update top level entity
  // 4. connection system propagates position and stuff to children of top level entities

  
  // is the engine entity accelerating?
  // then the ship entity needs to move
  //sys.update...
}


class ConnectionComponent
{
invariant()
{
  assert(m_entity !is null);
}


public:
  this(Entity p_entity)
  {
    m_entity = p_entity;
    
    m_force = Vector.origo;
    m_torque = 0.0;
    
    m_reload = 0.0;
  }
  
  Entity entity()
  {
    return m_entity;
  }

  ConnectionComponent owner()
  {
    return m_owner;
  }
  
  void owner(ConnectionComponent p_owner)
  {
    m_owner = p_owner;
  }
  
  PhysicsComponent physicsComponent()
  {
    return m_physicsComponent;
  }
  
  void physicsComponent(PhysicsComponent p_physicsComponent)
  {
    m_physicsComponent = p_physicsComponent;
  }
  
  Vector force()
  {
    return m_force;
  }
  
  float torque()
  {
    return m_torque;
  }
  
  
  void force(Vector p_force)
  {
    m_force = p_force;
  }
  
  void torque(float p_torque)
  {
    m_torque = p_torque;
  }
  
  @property float reload()
  {
    return m_reload;
  }
  
  @property float reload(float p_reload)
  {
    return m_reload = p_reload;
  }
  
  
private:
  Entity m_entity;
  
  ConnectionComponent m_owner;
  
  PhysicsComponent m_physicsComponent;
  
  Vector m_force;
  float m_torque;
  
  float m_reload;
}


class ConnectionSubSystem : public SubSystem!(ConnectionComponent)
{
public:
  this(InputHandler p_inputHandler, PhysicsSubSystem p_physics)
  {
    m_physics = p_physics;
    
    m_playerControl = new PlayerControl(p_inputHandler);
  }
  
  
  void updateFromControllers()
  {
    foreach (component; components)
    {
      // let eventual controller do its thing
      if (component in m_controlMapping)
      {
        //writeln(to!string(m_controlMapping[component].nearbyEntities(components, component, 10.0).length) ~ " components nearby");
        m_controlMapping[component].update(component, components);
      }
	  
      // propagate stuff from controller to owner
      if (component.owner !is null)
      {
        component.owner.force = component.owner.force + component.force;
        component.owner.torque = component.owner.torque + component.torque;
      }
      
      // update physics component
      if (component.physicsComponent !is null)
      {
        component.physicsComponent.force = component.physicsComponent.force + component.force;
        component.physicsComponent.torque = component.physicsComponent.torque + component.torque;
      }
      
      component.force = Vector.origo;
      component.torque = 0.0;
    }
  }
  
  
  void updateFromPhysics(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    foreach (component; components)
    {
      if (component.reload > 0.0)
        component.reload = component.reload - p_time;
      
      if (component.physicsComponent !is null)
      {
        //component.entity.position = component.physicsComponent.entity.position;
      }
    }
  }


protected:
  ConnectionComponent createComponent(Entity p_entity)
  {
    auto newComponent = new ConnectionComponent(p_entity);
    
    if (p_entity.getValue("owner").length > 0)
    {
      int ownerId = to!int(p_entity.getValue("owner"));
      
      foreach (component; components)
      {
        if (component.entity.id == ownerId)
        {
          newComponent.owner = component;
          break;
        }
      }
    }
    
    if (p_entity.getValue("control") == "player")
    {
      m_controlMapping[newComponent] = m_playerControl;
    }
    if (p_entity.getValue("control") == "flocker")
    {
      m_controlMapping[newComponent] = new FlockControl(2.5, 0.5, 20.0, 0.3);
    }
    
    if (m_physics.findComponents(p_entity).length > 0)
      newComponent.physicsComponent = m_physics.findComponents(p_entity)[0];
    
    return newComponent;
  }
  
  
private:
  PhysicsSubSystem m_physics;
  
  PlayerControl m_playerControl;
  Control[ConnectionComponent] m_controlMapping;
}
