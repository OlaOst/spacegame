module ConnectionSubSystem;

import std.conv;

import Control;
import Entity;
import FlockControl;
import InputHandler;
import PlayerControl;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  auto sys = new ConnectionSubSystem(new InputHandler());
  
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
  
  float reload()
  {
    return m_reload;
  }
  
  void reload(float p_reload)
  {
    m_reload = p_reload;
  }
  
  
private:
  Entity m_entity;
  
  Vector m_force;
  float m_torque;
  
  float m_reload;
}


class ConnectionSubSystem : public SubSystem!(ConnectionComponent)
{
public:
  this(InputHandler p_inputHandler)
  {
    m_playerControl = new PlayerControl(p_inputHandler);
  }
  
  
  void dilldall()
  {
    foreach (component; components)
    {
      // let eventual controller do its thing
      if (component in m_controlMapping)
      {
        //writeln(to!string(m_controlMapping[component].nearbyEntities(components, component, 10.0).length) ~ " components nearby");
        m_controlMapping[component].update(component, components);
      }
    }
  }


protected:
  ConnectionComponent createComponent(Entity p_entity)
  {
    auto newComponent = new ConnectionComponent(p_entity);
    
    if (p_entity.getValue("control") == "player")
    {
      m_controlMapping[newComponent] = m_playerControl;
    }
    
    if (p_entity.getValue("control") == "flocker")
    {
      m_controlMapping[newComponent] = new FlockControl(2.5, 0.5, 20.0, 0.3);
    }
    
    return newComponent;
  }
  
  
private:
  PlayerControl m_playerControl;
  Control[ConnectionComponent] m_controlMapping;
}
