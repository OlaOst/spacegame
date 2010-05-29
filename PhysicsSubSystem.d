module PhysicsSubSystem;

import Entity;
import SubSystem;


unittest
{
  PhysicsSubSystem physics = new PhysicsSubSystem();
  
  physics.move();
}


struct PhysicsComponent
{
public:
  void addPosition(Vector p_vector)
  {
    m_entity.position.x += p_vector.x;
    m_entity.position.y += p_vector.y;
  }
  
  Vector velocity()
  {
    return m_velocity;
  }
  
private:
  Entity m_entity;
  Vector m_velocity;
}


class PhysicsSubSystem : public SubSystem.SubSystem!(PhysicsComponent)
{
public:
  void move()
  {
    foreach (component; components)
    {
      component.addPosition(component.velocity);
    }
  }
  
  
protected:
  PhysicsComponent createComponent(Entity p_entity)
  {
    return PhysicsComponent();
  }
}