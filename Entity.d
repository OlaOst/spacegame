module Entity;


unittest
{
  Entity entity = new Entity();
  
  assert(entity.position == Vector.origo);
}


struct Vector
{
  float x, y;
  
  /*Position opOpAssign("+=")(Position p_right)
  {
    return Position(x + p_right.x, y + p_right.y);
  }*/
  
  static Vector origo = { x:0.0, y:0.0 };
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
  
  void addPosition(Vector p_add)
  {
    m_position.x += p_add.x;
    m_position.y += p_add.y;
  }
  
private:
  Vector m_position;
}