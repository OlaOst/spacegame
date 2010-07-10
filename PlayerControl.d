module PlayerControl;

import std.conv;

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
      force += dir * 2.5;
    if (m_inputHandler.hasEvent(Event.DownKey))
      force -= dir * 2.5;
    
    if (m_inputHandler.hasEvent(Event.LeftKey))
      torque += 1.5;
    if (m_inputHandler.hasEvent(Event.RightKey))
      torque -= 1.5;

    if (m_inputHandler.hasEvent(Event.Space))
    {
      Entity bullet = new Entity();
      
      bullet.setValue("drawtype", "bullet");
      bullet.setValue("spawnedFrom", to!string(p_sourceComponent.entity.id));
            
      bullet.position = p_sourceComponent.entity.position;
      bullet.angle = p_sourceComponent.entity.angle;
      
      bullet.lifetime = 5.0;
      
      p_sourceComponent.entity.addSpawn(bullet);
    }
  
    p_sourceComponent.force = force;
    p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}