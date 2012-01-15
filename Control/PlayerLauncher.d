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

module Control.PlayerLauncher;

import std.conv;
import std.random;
import std.stdio;

import Control.ControlBase;
import Entity;
import InputHandler;
import SubSystem.Controller;
import gl3n.linalg;


class PlayerLauncher : public ControlBase
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
  
  
  override void update(ref ControlComponent p_sourceComponent)
  in
  {
    assert(p_sourceComponent !is null);
  }
  out
  {
    // these asserts cause access violations. probably contract bug, recheck with dmd version later than 2.057
    
    //assert(p_sourceComponent !is null);
    //assert(p_sourceComponent.force.ok);
    //assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {    
    p_sourceComponent.isFiring = false;
    
    assert(m_inputHandler !is null);
    
    if (m_inputHandler.isPressed(Event.Space))
    {    
      if (p_sourceComponent.reloadTimeLeft <= 0.0)
      {
        p_sourceComponent.isFiring = true;
        p_sourceComponent.reloadTimeLeft = p_sourceComponent.reload;
                
        // TODO: recoil should be calculated from spawnforce or something
        auto recoil = 1.0;
        
        // TODO: dir should be from module angle 
        auto dir = vec2(0.0, 1.0); // default direction is up       
        
        auto force = p_sourceComponent.force;
        
        force -= dir * recoil;
        
        assert(force.ok);
        assert(p_sourceComponent.force.ok);
        
        p_sourceComponent.force = force;
      }
    }
    
    assert(p_sourceComponent !is null);
    assert(p_sourceComponent.force.ok);
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  
  
private:
  InputHandler m_inputHandler;
}