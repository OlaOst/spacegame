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


module AiChaser;

import std.math;
import std.stdio;

import SubSystem.Controller;

import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  AiChaser aiChaser = new AiChaser();
  
  
}


class AiChaser : public Control
{
invariant()
{  
}


public:
  
  void update(ref ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents)
  {
    // we want to match the targets velocity
    // we also want to get closer to the target
    // but not too close
    // and we want to look where the target will be so shots can hit
    
    Vector relativePosition = targetPosition - p_sourceComponent.position;
    
    if (relativePosition.length2d > 1.0)
    {
      Vector desiredVelocity = relativePosition + targetVelocity * 2.0;
      
      // this needs damping or there will be funky oscillations
      float desiredTorque = Vector.fromAngle(p_sourceComponent.angle).angle(desiredVelocity);
      desiredTorque /= abs(desiredTorque);
      
      desiredTorque *= p_sourceComponent.torqueForce;
      
      // accelerate if we're on our desired heading, else rotate towards target
      if (desiredTorque < 0.1 && p_sourceComponent.velocity.length2d < 3.0)
        p_sourceComponent.force += Vector(0.0, 1.0 * p_sourceComponent.thrustForce);
      else
        p_sourceComponent.torque = desiredTorque;
        
      //p_sourceComponent.force += desiredVelocity.normalized * p_sourceComponent.slideForce;
    }
  }

  
public:
  Vector targetPosition;
  Vector targetVelocity;
}
