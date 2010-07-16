module Control;

import Entity;
import ConnectionSubSystem;
import InputHandler;
import Vector : Vector;


unittest
{
  auto connectionSystem = new ConnectionSubSystem(new InputHandler(), new PhysicsSubSystem());
  auto controlComponent = new ConnectionComponent(new Entity());
  
  class MockControl : public Control
  {
  public:
    void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents)
    {
    }
  }
  
  auto controller = new MockControl();
  
  ConnectionComponent[] components = [];
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 0);
  
  components ~= new ConnectionComponent(new Entity());
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  
  auto farAwayComponent = new ConnectionComponent(new Entity());
  
  farAwayComponent.entity.position(Vector(100.0, 100.0));
  components ~= farAwayComponent;
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  assert(controller.nearbyEntities(controlComponent, components, 1000.0).length == 2);
}


abstract class Control
{
public:
  abstract void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents);
  

protected:
  Entity[] nearbyEntities(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_candidateComponents, float p_radius)
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