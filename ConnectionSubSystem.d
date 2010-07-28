module ConnectionSubSystem;

import std.conv;
import std.stdio;

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
  
  auto physics = new PhysicsSubSystem();
  auto sys = new ConnectionSubSystem(new InputHandler(), physics);
  
  Entity ship = new Entity();
  ship.setValue("mass", "2.0");
  
  physics.registerEntity(ship);
  sys.registerEntity(ship);
  

  Entity engine = new Entity();
  engine.setValue("owner", to!string(ship.id));
  engine.setValue("relativePosition", "1 0");
  engine.setValue("mass", "1.0");
  engine.setValue("control", "mock");
  
  sys.registerEntity(engine);
  
  // macgyver in the mock control here, we don't want to know about it in the createComponent implementation
  auto controller = new MockControl();
  sys.m_controlMapping[sys.findComponents(engine)[0]] = controller;

  auto engineComponent = sys.findComponents(engine)[0];
  
  assert(engineComponent.relativePosition == Vector(1.0, 0.0), "Engine didn't set relative position to 1 0 0, it's " ~ engineComponent.relativePosition.toString());
  assert(engineComponent.owner.entity == ship);

  sys.updateFromControllers();

  assert(physics.findComponents(ship)[0].force == Vector(1.0, 0.0), "Force didn't get propagated from controller component to physics component: " ~ physics.findComponents(ship)[0].force.toString());
  
  physics.move(1.0);
  
  // TODO: we need to take combined mass of ship and engine into account, this assumes just a mass of 1
  assert(ship.position == Vector(1, 0, 0));
  
  sys.updateFromPhysics(1.0);
  
  assert(engine.position == engineComponent.relativePosition + ship.position);
  
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
  
  assert(m_force.isValid());
  assert(m_relativePosition.isValid());
  assert(m_relativeAngle == m_relativeAngle);
  
  // if the component has an owner, it should not have a grandparent
  // also the owner has to have a physics component
  // so it's not a tree structure
  // if an engine is connected to a skeleton, the owner component is still the ship, not the skeleton
  if (m_owner !is null)
  {
    assert(m_owner.owner is null);
    assert(m_owner.physicsComponent !is null);
  }
}


public:
  this(Entity p_entity)
  {
    m_entity = p_entity;
    
    m_relativePosition = Vector.origo;
    m_relativeAngle = 0.0;
    
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
  
  Vector relativePosition()
  {
    return m_relativePosition;
  }
  
  void relativePosition(Vector p_relativePosition)
  {
    m_relativePosition = p_relativePosition;
  }
  
  float relativeAngle()
  {
    return m_relativeAngle;
  }
  
  void relativeAngle(float p_relativeAngle)
  {
    m_relativeAngle = p_relativeAngle;
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
  
  Vector m_relativePosition;
  float m_relativeAngle;
  
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
      if (component.owner !is null && component.owner.physicsComponent !is null)
      {
        component.owner.physicsComponent.force = component.owner.physicsComponent.force + component.force;
        component.owner.physicsComponent.torque = component.owner.physicsComponent.torque + component.torque;
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
      
      if (component.owner !is null)
      {
        component.entity.position = component.relativePosition.rotate(component.owner.physicsComponent.entity.angle) + component.owner.physicsComponent.entity.position;
        component.entity.angle = component.relativeAngle + component.owner.physicsComponent.entity.angle;
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
    
    if (p_entity.getValue("relativePosition").length > 0)
    {
      newComponent.relativePosition = Vector.fromString(p_entity.getValue("relativePosition"));
    }
    
    if (p_entity.getValue("relativeAngle").length > 0)
    {
      newComponent.relativeAngle = to!float(p_entity.getValue("relativeAngle"));
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
