module Entity;

import std.math;

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
  assert(m_position.x == m_position.x && m_position.y == m_position.y);
  assert(m_angle == m_angle);
  
  assert(m_force.x == m_force.x && m_force.y == m_force.y);
  assert(m_torque == m_torque);
  
  assert(m_lifetime == m_lifetime);
}


public:
  this()
  {
    m_position = Vector.origo;
    m_angle = 0.0;
    
    m_force = Vector.origo;
    m_torque = 0.0;
    
    m_id = m_idCounter++;
    
    m_lifetime = real.infinity;
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

private:
  Vector m_position;
  float m_angle;
  
  Vector m_force;
  float m_torque;
  
  float m_lifetime;
  
  static int m_idCounter;
  int m_id;
  
  string[string] m_values;
}