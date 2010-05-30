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


struct PhysicsComponent
{
invariant()
{
  assert(m_entity !is null, "Physics component had null entity");
  assert(m_velocity.x == m_velocity.x && m_velocity.y == m_velocity.y);
}

public:
  this(Entity p_entity)
  {
    m_entity = p_entity;
    m_velocity = Vector.origo;
  }

  void move(float p_time)
  {
    m_velocity = m_velocity + m_entity.force * p_time;
    m_entity.position = m_entity.position + m_velocity * p_time;
  }
  
private:
  Entity m_entity;
  Vector m_velocity;
}


class PhysicsSubSystem : public SubSystem.SubSystem!(PhysicsComponent)
{
public:
  void move(float p_time)
  {
    foreach (component; components)
    {
      component.move(p_time);
    }
  }
  
  
protected:
  PhysicsComponent createComponent(Entity p_entity)
  {
    return PhysicsComponent(p_entity);
  }
}