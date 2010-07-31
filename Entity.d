module Entity;

import std.math;

import CollisionSubSystem;
import Vector : Vector;


unittest
{
  Entity entity = new Entity();
  
  assert(entity.position == Vector.origo);
  
  entity.setValue("dummyValue", "123");
  
  assert(entity.getValue("dummyValue"), "123");
  
  Entity another = new Entity();
  
  assert(entity.id != another.id);
}


class Entity
{
invariant()
{
  assert(m_position.x == m_position.x && m_position.y == m_position.y && m_position.z == m_position.z);
  assert(m_angle == m_angle);
  
  assert(m_lifetime == m_lifetime);
}


public:
  this()
  {
    m_position = Vector.origo;
    m_angle = 0.0;
        
    m_id = m_idCounter++;
    
    m_lifetime = float.infinity;
  }
  
  Vector position()
  {
    return m_position;
  }
  
  void position(Vector p_position)
  {
    m_position = p_position;
  }
  
  float angle()
  {
    return m_angle;
  }
  
  void angle(float p_angle)
  {
    m_angle = p_angle;
  }
  
  float lifetime()
  {
    return m_lifetime;
  }
  
  void lifetime(float p_lifetime)
  {
    m_lifetime = p_lifetime;
  }
  
  void setValue(string p_name, string p_value)
  {
    m_values[p_name] = p_value;
  }
  
  string getValue(string p_name)
  {
    if (p_name in m_values)
      return m_values[p_name];
    else
      return null;
  }
    
  int id()
  {
    return m_id;
  }
  
  void addSpawn(Entity p_spawn)
  {
    m_spawnList ~= p_spawn;
  }
  
  Entity[] getAndClearSpawns()
  out
  {
    assert(m_spawnList.length == 0);
  }
  body
  {
    Entity[] tmp = m_spawnList;
    
    m_spawnList.length = 0;
    
    return tmp;
  }

  void addCollision(Collision p_collision)
  {
    m_collisionList ~= p_collision;
  }
  
  Collision[] getAndClearCollisions()
  out
  {
    assert(m_collisionList.length == 0);
  }
  body
  {
    Collision[] tmp = m_collisionList;
    
    m_collisionList.length = 0;
    
    return tmp;
  }
  
  
private:
  Vector m_position;
  float m_angle;
  
  float m_lifetime;
  
  static int m_idCounter;
  int m_id;
  
  string[string] m_values;
  
  Entity[] m_spawnList;
  Collision[] m_collisionList;
}