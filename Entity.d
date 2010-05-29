module Entity;


unittest
{
  Entity entity = new Entity();
  
  assert(entity.position == Position.origo);
}


struct Position
{
  float x, y;
  
  /*Position opOpAssign("+=")(Position p_right)
  {
    return Position(x + p_right.x, y + p_right.y);
  }*/
  
  static Position origo = { x:0.0, y:0.0 };
}

class Entity
{
public:
  this()
  {
    m_position = Position.origo;
  }
  
  Position position()
  {
    return m_position;
  }
  
  void addPosition(Position p_add)
  {
    m_position.x += p_add.x;
    m_position.y += p_add.y;
  }
  
private:
  Position m_position;
}