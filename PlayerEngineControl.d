module PlayerEngineControl;

import std.conv;
import std.stdio;

import Control;
import InputHandler;
import ConnectionSubSystem;
import Vector : Vector;


unittest
{
  auto control = new PlayerEngineControl(new InputHandler());
  
}


class PlayerEngineControl : public Control
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
  
  
  void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents)
  out
  {
    //assert(p_sourceComponent.force.isValid());
    //assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    auto dir = Vector.fromAngle(p_sourceComponent.entity.angle);
    
    auto force = p_sourceComponent.force;
    auto torque = p_sourceComponent.torque;
    
    if (m_inputHandler.hasEvent(Event.UpKey))
      force += dir * 7.5;
    if (m_inputHandler.hasEvent(Event.DownKey))
      force -= dir * 7.5;
    
    if (m_inputHandler.hasEvent(Event.LeftKey))
      torque += 5.5;
    if (m_inputHandler.hasEvent(Event.RightKey))
      torque -= 5.5;
    
    p_sourceComponent.force = force;
    p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}