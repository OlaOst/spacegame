module Control;

import Entity;
import PhysicsSubSystem;
import Vector : Vector;


unittest
{
  auto physics = new PhysicsSubSystem(new InputHandler());
  auto controlComponent = new PhysicsComponent(new Entity());
  
  class MockControl : public Control
  {
  public:
    void update(PhysicsComponent p_sourceComponent, PhysicsComponent[] p_otherComponents)
    {
    }
  }
  
  auto controller = new MockControl();
  
  PhysicsComponent[] components = [];
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 0);
  
  components ~= new PhysicsComponent(new Entity());
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  
  auto farAwayComponent = new PhysicsComponent(new Entity());
  
  farAwayComponent.entity.position(Vector(100.0, 100.0));
  components ~= farAwayComponent;
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  assert(controller.nearbyEntities(controlComponent, components, 1000.0).length == 2);
}


class Control
{
public:
  abstract void update(PhysicsComponent p_sourceComponent, PhysicsComponent[] p_otherComponents);
  

protected:
  Entity[] nearbyEntities(PhysicsComponent p_sourceComponent, PhysicsComponent[] p_candidateComponents, float p_radius)
  in
  {
    assert(p_radius > 0.0);
  }
  body
  {
    Entity[] inRangeEntities = [];
    foreach (candidateComponent; p_candidateComponents)
    {
      if (candidateComponent != p_sourceComponent && (candidateComponent.entity.position - p_sourceComponent.entity.position).length2d < p_radius)
        inRangeEntities ~= candidateComponent.entity;
    }
    return inRangeEntities;
  }
}