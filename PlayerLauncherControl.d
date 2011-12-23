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

module PlayerLauncherControl;

import std.conv;
import std.random;
import std.stdio;

import Entity;
import InputHandler;
import SubSystem.Controller;
import gl3n.linalg;


unittest
{
  auto playerControl = new PlayerLauncherControl(new InputHandler());
  
}


class PlayerLauncherControl : public Control
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
    assert(p_sourceComponent.force.ok);
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    p_sourceComponent.isFiring = false;
    
    if (m_inputHandler.isPressed(Event.Space))
    {
      if (p_sourceComponent.reload <= 0.0)
      {
        p_sourceComponent.isFiring = true;
        p_sourceComponent.reload = 0.2;
        
        // TODO: recoil should be calculated from spawnforce or something
        auto recoil = 1.0;
        
        // TODO: dir should be from module angle 
        auto dir = vec2(0.0, 1.0); // default direction is up
        
        auto force = p_sourceComponent.force;
        
        force -= dir * recoil;
        
        p_sourceComponent.force = force;
      }
    }
  }
  
  
private:
  InputHandler m_inputHandler;
}