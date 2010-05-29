module Entity;

import Vector : Vector;


unittest
{
  Entity entity = new Entity();
  
  assert(entity.position == Vector.origo);
}


class Entity
{
public:
  this()
  {
    m_position = Vector.origo;
  }
  
  Vector position()
  {
    return m_position;
  }
  
  void position(Vector p_position)
  {
    m_position = p_position;
  }
  
  /*void addPosition(Vector p_add)
  {
    m_position.x += p_add.x;
    m_position.y += p_add.y;
  }*/
  
private:
  Vector m_position;
}