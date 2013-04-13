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

module Control.AiChaser;

import std.math;
import std.stdio;

import gl3n.linalg;

import Control.ControlBase;
import SubSystem.Controller;


unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  AiChaser aiChaser = new AiChaser();  
}


class AiChaser : ControlBase
{
public:
  
  override void update(ref ControlComponent p_sourceComponent)
  {
    // we want to match the targets velocity
    // we also want to get closer to the target
    // but not too close
    // and we want to look where the target will be so shots can hit
    
    auto targetPosition = p_sourceComponent.targetPosition;
    auto targetVelocity = p_sourceComponent.targetVelocity;
    
    vec2 relativeTargetPosition = targetPosition - p_sourceComponent.position;
    vec2 relativeTargetVelocity = targetVelocity - p_sourceComponent.velocity;
    
    if (relativeTargetPosition.length > 0.0)
    {
      assert(p_sourceComponent.torqueForce == p_sourceComponent.torqueForce);
      
      //vec2 desiredVelocity = relativeTargetPosition;
      //vec2 desiredVelocity = relativeTargetPosition + targetVelocity * 2.0;
      vec2 desiredVelocity = relativeTargetPosition + relativeTargetVelocity * sqrt(relativeTargetPosition.length) * 0.1;
      
      vec2 currentDirection = mat2.rotation(p_sourceComponent.angle) * vec2(0.0, 1.0);
      vec2 desiredDirection = desiredVelocity.normalized;
      
      auto angle = atan2(currentDirection.y, currentDirection.x) - atan2(desiredDirection.y, desiredDirection.x);
      
      while (angle > PI)
        angle -= PI * 2.0;
      while (angle < -PI)
        angle += PI * 2.0;
      
      float desiredTorque = (angle / PI) * p_sourceComponent.torqueForce - p_sourceComponent.rotation;
      
      /*if (angle > 0.0)
        desiredTorque = 1.0;
      else
        desiredTorque = -1.0;

      desiredTorque *= p_sourceComponent.torqueForce;*/

      assert(isFinite(desiredTorque));
      
      p_sourceComponent.torque = desiredTorque;
      
      p_sourceComponent.angularImpulse += p_sourceComponent.rotation * -1.0;
      
      if (abs(angle) < 0.2 && p_sourceComponent.velocity.length < p_sourceComponent.maxSpeed)
        p_sourceComponent.force += vec2(0.0, 1.0 * p_sourceComponent.thrustForce);
        
      p_sourceComponent.isFiring = false;
      if (p_sourceComponent.force.length > 0.0)
      {
        p_sourceComponent.isFiring = true;
      }
    }
  }

  
public:
  //vec2 targetPosition;
  //vec2 targetVelocity;
}
