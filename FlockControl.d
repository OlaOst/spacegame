module FlockControl;

import Entity;
import PhysicsSubSystem;
import Vector : Vector;


unittest
{
  auto physics = new PhysicsSubSystem();
  auto controlComponent = new PhysicsComponent(new Entity());
  
  auto flocker = new FlockControl();
  
  PhysicsComponent[] components = [];
  
  assert(flocker.nearbyEntities(components, controlComponent, 10.0).length == 0);
  
  components ~= new PhysicsComponent(new Entity());
  
  assert(flocker.nearbyEntities(components, controlComponent, 10.0).length == 1);
  
  auto farAwayComponent = new PhysicsComponent(new Entity());
  
  farAwayComponent.entity.position(Vector(100.0, 100.0));
  components ~= farAwayComponent;
  
  assert(flocker.nearbyEntities(components, controlComponent, 10.0).length == 1);
  assert(flocker.nearbyEntities(components, controlComponent, 1000.0).length == 2);
}


class FlockControl
{
public:
  
  Entity[] nearbyEntities(PhysicsComponent[] p_candidateComponents, PhysicsComponent p_sourceComponent, float p_radius)
  in
  {
    assert(p_radius > 0.0);
  }
  body
  {
    Entity[] inRangeEntities = [];
    foreach (candidateComponent; p_candidateComponents)
    {
      if ((candidateComponent.entity.position - p_sourceComponent.entity.position).length2d < p_radius)
        inRangeEntities ~= candidateComponent.entity;
    }
    return inRangeEntities;
  }
}