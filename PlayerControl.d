module PlayerControl;

import Control;
import InputHandler;
import PhysicsSubSystem;
import Vector : Vector;


unittest
{
  auto playerControl = new PlayerControl(new InputHandler());
  
}


class PlayerControl : public Control
{
invariant()
{
  assert(m_inputHandler !is null);
}


public:
  this(InputHandler p_inputHandler)
  {
    m_inputHandler = p_inputHandler;
  }
  
  
  void update(PhysicsComponent p_sourceComponent, PhysicsComponent[] p_otherComponents)
  out
  {
    assert(p_sourceComponent.force.x == p_sourceComponent.force.x && p_sourceComponent.force.y == p_sourceComponent.force.y);
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    auto dir = Vector.fromAngle(p_sourceComponent.entity.angle);
    
    auto force = p_sourceComponent.force;
    auto torque = p_sourceComponent.torque;
    
    if (m_inputHandler.hasEvent(Event.UpKey))
      force += dir * 0.2;
    if (m_inputHandler.hasEvent(Event.DownKey))
      force -= dir * 0.2;
    
    if (m_inputHandler.hasEvent(Event.LeftKey))
      torque += 0.2;
    if (m_inputHandler.hasEvent(Event.RightKey))
      torque -= 0.2;
  
    p_sourceComponent.force = force;
    p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}