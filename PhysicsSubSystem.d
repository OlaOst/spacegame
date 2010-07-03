module PhysicsSubSystem;

import std.stdio;
import std.conv;
import std.math;

import Entity;
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
}


class PhysicsComponent
{
invariant()
{
  assert(m_entity !is null, "Physics component had null entity");
  
  assert(m_velocity.x == m_velocity.x && m_velocity.y == m_velocity.y && m_velocity.z == m_velocity.z);
  assert(m_rotation == m_rotation);
}

public:
  this(Entity p_entity)
  {  
    m_entity = p_entity;
    m_velocity = Vector.origo;
    m_rotation = 0.0;
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
    return m_entity.force;
  }
  
  void force(Vector p_force)
  {
    m_entity.force = p_force;
  }
  
  float torque()
  {
    return m_entity.torque;
  }
  
  void torque(float p_torque)
  {
    m_entity.torque = p_torque;
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
    
    m_velocity = m_velocity + m_entity.force * p_time;
    m_entity.position = m_entity.position + m_velocity * p_time;
    
    m_rotation = m_rotation + m_entity.torque * p_time;
    m_entity.angle = m_entity.angle + m_rotation * p_time;
  }
  
private:
  Entity m_entity;
  Vector m_velocity;
  float m_rotation;
}


class PhysicsSubSystem : public SubSystem!(PhysicsComponent)
{
public:
  void move(float p_time)
  {
    foreach (component; components)
    {
      // add spring force to center
      component.force = component.force + (component.position * -0.05);
      
      // and some damping
      component.force = component.force + (component.velocity * -0.15);
      component.torque = component.torque + (component.rotation * -0.5);
      
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
    
    if (p_entity.getValue("inputSource") == "player")
    {
      //newComponent.inputSource = m_playerInput;
    }
    
    if (p_entity.getValue("inputSource") == "flockingNpc")
    {
      //newComponent.inputSource = new FlockInput();
    }
    
    return newComponent;
  }
  
private:
}