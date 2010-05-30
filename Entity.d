module Entity;

import Vector : Vector;


unittest
{
  Entity entity = new Entity();
  
  assert(entity.position == Vector.origo);
}


class Entity
{
invariant()
{
  assert(m_position.x == m_position.x && m_position.y == m_position.y);
  assert(m_force.x == m_force.x && m_force.y == m_force.y);
}


public:
  this()
  {
    m_position = Vector.origo;
    m_force = Vector.origo;
  }
  
  Vector position()
  {
    return m_position;
  }
  
  void position(Vector p_position)
  {
    m_position = p_position;
  }
  
  Vector force()
  {
    return m_force;
  }
  
  void force(Vector p_force)
  {
    m_force = p_force;
  }
  
private:
  Vector m_position;
  Vector m_force;
}