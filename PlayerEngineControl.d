/*
 Copyright (c) 2010 Ola Østtveit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

module PlayerEngineControl;

import std.conv;
import std.stdio;

import InputHandler;
import SubSystem.Controller;
import common.Vector;


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
  
  
  void update(ref ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents)
  out
  {
    assert(p_sourceComponent.position.isValid());
    assert(p_sourceComponent.force.isValid());
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    //auto dir = Vector.fromAngle(p_sourceComponent.angle);
    auto dir = Vector(1.0, 0.0);
    
    auto force = p_sourceComponent.force;
    auto torque = p_sourceComponent.torque;
    
    float enginePower = 5.0;
    
    if (m_inputHandler.isPressed(Event.UpKey))
      force += dir * enginePower;
    if (m_inputHandler.isPressed(Event.DownKey))
      force -= dir * enginePower;
    
    if (m_inputHandler.isPressed(Event.LeftKey))
      torque += enginePower;
    if (m_inputHandler.isPressed(Event.RightKey))
      torque -= enginePower;
    
    p_sourceComponent.force = force;
    p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}
