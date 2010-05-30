module PhysicsSubSystem;

import std.stdio;
import std.conv;

import Entity;
import SubSystem;
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
}


class PhysicsComponent
{
invariant()
{
  assert(m_entity !is null, "Physics component had null entity");
  
  assert(m_velocity.x == m_velocity.x && m_velocity.y == m_velocity.y);
  assert(m_rotation == m_rotation);
}

public:
  this(Entity p_entity)
  {  
    m_entity = p_entity;
    m_velocity = Vector.origo;
    m_rotation = 0.0;
  }

  Vector force()
  {
    return m_entity.force;
  }
  
  void force(Vector p_force)
  {
    m_entity.force = p_force;
  }
  
  Vector position()
  {
    return m_entity.position;
  }
  

private:
  void move(float p_time)
  in
  {
    assert(p_time > 0.0);
  }
  body
  {
    //writeln("torque:   " ~ to!string(m_entity.torque));
    //writeln("rotation: " ~ to!string(m_rotation));
    //writeln("angle:    " ~ to!string(m_entity.angle));
    
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


class PhysicsSubSystem : public SubSystem.SubSystem!(PhysicsComponent)
{
public:
  void move(float p_time)
  {
    foreach (component; components)
    {
      // add spring force to center
      component.force = component.force + (component.position * -0.05);
      
      component.move(p_time);
    }
  }
  
  
protected:
  PhysicsComponent createComponent(Entity p_entity)
  {
    return new PhysicsComponent(p_entity);
  }
}