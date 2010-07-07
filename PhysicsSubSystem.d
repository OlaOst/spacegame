module PhysicsSubSystem;

import std.stdio;
import std.conv;
import std.math;

import Entity;
import FlockControl;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  PhysicsSubSystem physics = new PhysicsSubSystem();
  
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
  
  assert(m_force.x == m_force.x && m_force.y == m_force.y && m_force.z == m_force.z);
  assert(m_torque == m_torque);
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
      component.torque = component.torque + (component.rotation * -0.5);
      
      // let eventual controller do its thing
      if (component in m_controlMapping)
      {
        writeln(to!string(m_controlMapping[component].nearbyEntities(components, component, 10.0).length) ~ " components nearby");
      }
      
      component.move(p_time);
      
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
          Vector dir = Vector(cos(spawnerCandidate.entity.angle), sin(spawnerCandidate.entity.angle));
          
          // TODO: should be force from spawn value
          dir *= 5.0;
          
          newComponent.velocity = spawnerCandidate.velocity + dir;
        }
      }
    }
    
    if (p_entity.getValue("control") == "player")
    {
      // m_playerControl.setComponentToControl(newComponent);
    }
    
    if (p_entity.getValue("control") == "flocker")
    {
      //auto flocker = new FlockControl(this, newComponent);
      //newComponent.setControl(new FlockControl());
      m_controlMapping[newComponent] = new FlockControl();
    }
    
    return newComponent;
  }
  
private:
  FlockControl[PhysicsComponent] m_controlMapping;
}