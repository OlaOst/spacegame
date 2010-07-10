module PhysicsSubSystem;

import std.conv;
import std.math;
import std.random;
import std.stdio;

import Entity;
import FlockControl;
import InputHandler;
import PlayerControl;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  PhysicsSubSystem physics = new PhysicsSubSystem(new InputHandler());
  
  Entity entity = new Entity();
  
  physics.registerEntity(entity);
  
  assert(entity.position == Vector.origo);
  {
    physics.components[0].m_velocity = Vector(1.0, 0.0);
    physics.move(1.0);
  }
  assert(entity.position.x > 0.0);
  
  {
    Entity spawn = new Entity();
    spawn.setValue("spawnedFrom", to!string(entity.id));
    
    physics.registerEntity(spawn);
    
    auto spawnComp = physics.findComponents(spawn)[0];
    auto motherComp = physics.findComponents(entity)[0];
    
    //assert(spawnComp.velocity == motherComp.velocity, "Spawned entity didn't get velocity vector copied from spawner");
  }
  // TODO: what should happen when registering an entity whose spawnedFrom doesn't exists
  
  
  {
    Entity flocker = new Entity();
    flocker.setValue("control", "flocker");
    
    physics.registerEntity(flocker);

    physics.move(1.0);
  }
}


class PhysicsComponent
{
invariant()
{
  assert(m_entity !is null, "Physics component had null entity");
  
  assert(m_velocity.x == m_velocity.x && m_velocity.y == m_velocity.y && m_velocity.z == m_velocity.z);
  assert(m_rotation == m_rotation);
  
  //assert(m_force.x == m_force.x && m_force.y == m_force.y && m_force.z == m_force.z);
  //assert(m_torque == m_torque);
}

public:
  this(Entity p_entity)
  {  
    m_entity = p_entity;
    
    m_velocity = Vector.origo;
    m_force = Vector.origo;
    
    m_rotation = 0.0;
    m_torque = 0.0;
  }
  
  Vector position()
  {
    return m_entity.position;
  }
  
  Vector velocity()
  {
    return m_velocity;
  }
  
  void velocity(Vector p_velocity)
  {
    m_velocity = p_velocity;
  }
  
  float rotation()
  {
    return m_rotation;
  }
  
  Vector force()
  {
    return m_force;
  }
  
  void force(Vector p_force)
  {
    m_force = p_force;
  }
  
  float torque()
  {
    return m_torque;
  }
  
  void torque(float p_torque)
  {
    m_torque = p_torque;
  }

  Entity entity()
  {
    return m_entity;
  }

  
private:
  void move(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    //writeln("torque:   " ~ to!string(m_entity.torque));
    //writeln("rotation: " ~ to!string(m_rotation));
    //writeln("angle:    " ~ to!string(m_entity.angle));
    
    //writeln("force: " ~ m_entity.force.toString());
    //writeln("vel:   " ~ m_velocity.toString());
    //writeln("pos:   " ~ m_entity.position.toString());
    
    //writeln("time: " ~ to!string(p_time));
    
    m_velocity = m_velocity + m_force * p_time;
    m_entity.position = m_entity.position + m_velocity * p_time;
    
    m_rotation = m_rotation + m_torque * p_time;
    m_entity.angle = m_entity.angle + m_rotation * p_time;
  }
  
private:
  Entity m_entity;
  Vector m_velocity;
  Vector m_force;
  
  float m_rotation;
  float m_torque;
}


class PhysicsSubSystem : public SubSystem!(PhysicsComponent)
{
public:
  this(InputHandler p_inputHandler)
  {
    m_playerControl = new PlayerControl(p_inputHandler);
  }
  
  
  void move(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    foreach (component; components)
    {
      // add spring force to center
      component.force = component.force + (component.position * -0.05);
      
      // and some damping
      component.force = component.force + (component.velocity * -0.15);
      component.torque = component.torque + (component.rotation * -2.5);
      
      // let eventual controller do its thing
      if (component in m_controlMapping)
      {
        //writeln(to!string(m_controlMapping[component].nearbyEntities(components, component, 10.0).length) ~ " components nearby");
        m_controlMapping[component].update(component, components);
      }
      
      component.move(p_time);
      
      //if (component.entity.position.length2d > 100.0)
        //component.entity.position = component.entity.position * -1;
      if (abs(component.entity.position.x) > 30.0)
        component.entity.position = Vector(component.entity.position.x * -1, component.entity.position.y);
      if (abs(component.entity.position.y) > 30.0)
        component.entity.position = Vector(component.entity.position.x, component.entity.position.y * -1);
      
      component.force = Vector.origo;
      component.torque = 0.0;
    }
  }
  
  
protected:
  PhysicsComponent createComponent(Entity p_entity)
  {
    auto newComponent = new PhysicsComponent(p_entity);
    
    // spawns needs some stuff from spawnedFrom entity to know their initial position, direction, velocity, etc
    if (p_entity.getValue("spawnedFrom"))
    {
      int spawnedFromId = to!int(p_entity.getValue("spawnedFrom"));
      
      foreach (spawnerCandidate; components)
      {
        if (spawnerCandidate.entity.id == spawnedFromId)
        {
          Vector kick = Vector(cos(spawnerCandidate.entity.angle), sin(spawnerCandidate.entity.angle));
          
          // TODO: should be force from spawn value
          kick *= 25.0;
          
          newComponent.velocity = spawnerCandidate.velocity + kick;
          //newComponent.force = kick;
        }
      }
    }
    
    if (p_entity.getValue("velocity") == "randomize")
      newComponent.velocity = Vector(uniform(-1.5, 1.5), uniform(-1.5, 1.5));
    
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
  Control[PhysicsComponent] m_controlMapping;
}