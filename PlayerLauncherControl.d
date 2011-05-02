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
import common.Vector;


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
  
  
  void update(ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents)
  out
  {
    //assert(p_sourceComponent.force.isValid());
    //assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    //auto dir = Vector.fromAngle(p_sourceComponent.entity.angle);
    
    //auto force = p_sourceComponent.force;
    //auto torque = p_sourceComponent.torque;
    
    if (m_inputHandler.isPressed(Event.Space))
    {
      if (p_sourceComponent.reload <= 0.0)
      {
        Entity bullet = new Entity();

        bullet.setValue("drawsource", "Bullet");
        bullet.setValue("collisionType", "Bullet");
        bullet.setValue("radius", "0.1");
        bullet.setValue("mass", "0.2");
        //bullet.setValue("spawnedFrom", to!string(p_sourceComponent.entity.id));
        
        //bullet.setValue("velocity", 

        bullet.setValue("position", to!string(p_sourceComponent.position));
        bullet.setValue("angle", to!string(p_sourceComponent.angle));
        
        bullet.lifetime = 5.0;
        
        //p_sourceComponent.entity.addSpawn(bullet);
        
        immutable string[4] sounds = ["mgshot1.wav", "mgshot2.wav", "mgshot3.wav", "mgshot4.wav"];
        
        //bullet.setValue("soundFile", sounds[uniform(0, sounds.length)]);
        bullet.setValue("soundFile", sounds[0]);
        
        p_sourceComponent.reload = 0.1;
      }
    }
    
    //p_sourceComponent.force = force;
    //p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}