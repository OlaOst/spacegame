/*
 Copyright (c) 2011 Ola Østtveit

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


module AiGunner;

import std.conv;
import std.math;
import std.stdio;

import SubSystem.Controller;

import gl3n.linalg;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  AiGunner aigunner = new AiGunner();
  
  
}


class AiGunner : public Control
{
invariant()
{  
}


public:
  
  void update(ref ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents)
  {
    p_sourceComponent.isFiring = false;
    
    if (p_sourceComponent.reload <= 0.0)
    {
      foreach (targetPosition; targetPositions)
      {
        auto targetDistance = (targetPosition - p_sourceComponent.position).length;
        auto targetAngle = (targetPosition - p_sourceComponent.position).angle;
        
        //writeln("sourcecomp pos is " ~ to!string(p_sourceComponent.position))
        //writeln("targetangle is " ~ to!string(targetAngle));
        //writeln("sourceangle is " ~ to!string(p_sourceComponent.angle));
        if (targetDistance < 100.0 && abs(p_sourceComponent.angle - targetAngle) < 0.1)
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
          
          break;
        }
      }
    }
  }

  
public:
  vec2[] targetPositions;
}
