﻿/*
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

module Control.Flocker;

import std.algorithm;
import std.conv;
import std.math;
import std.stdio;

import gl3n.linalg;

import Control.ControlBase;
import Entity;
import SubSystem.Controller;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  // 0.5 avoid distance, 0.5 avoid weight, 5.0 flock distance, 0.3 flock weight
  FlockControl flock = new FlockControl(0.5, 0.5, 5.0, 0.3);
  
  // check that desired velocity is kept with no other boids in sight
  assert(flock.desiredVelocity([]) == vec2(0.0, 0.0));
  
  // check that desired velocity is kept with one boid outside both avoid and flock distances
  assert(flock.desiredVelocity([vec2(0.0, 10.0)]) == vec2(0.0, 0.0));
  
  // check that desired velocity is changed away with one boid inside avoid distance
  assert(flock.desiredVelocity([vec2(0.0, 0.2)]).y > 0.0, "got undesired velocity: " ~ flock.desiredVelocity([vec2(0.0, 0.3)]).toString());
  
  // check that desired velocity is changed towards with one boid outside avoid distance but inside flock distance
  assert(flock.desiredVelocity([vec2(0.0, 2.0)]).y < 0.0);
  
  // check that desired velocity is kept with one boid in front and one in back (avoidance rules should nullify with those two)
  //assert(flock.desiredVelocity(/*vec2(0.0, 1.0),*/ [vec2(0.0, 1.0), vec2(0.0, -1.0)]) == vec2(0.0, 1.0), flock.desiredVelocity(vec2(0.0, 1.0), [vec2(0.0, 1.0), vec2(0.0, -1.0)]).toString());
  
  // need alignment rule to harmonize headings
}


class FlockControl : ControlBase
{
invariant()
{
  assert(m_avoidDistance >= 0.0);
  assert(m_avoidWeight == m_avoidWeight); // negative weights should be possible, so we just check for NaNs
  
  assert(m_flockDistance >= 0.0);
  assert(m_flockWeight == m_flockWeight); // negative weights should be possible, so we just check for NaNs
}


public:
  this(float p_avoidDistance, float p_avoidWeight,
       float p_flockDistance, float p_flockWeight)
  {
    m_avoidDistance = p_avoidDistance;
    m_avoidWeight = p_avoidWeight;
    
    m_flockDistance = p_flockDistance;
    m_flockWeight = p_flockWeight;
  }
  
  
  void update(ref ControlComponent p_sourceComponent)
  out
  {
    assert(p_sourceComponent.force.ok);
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    vec2[] relativePositions = [];
    
    // TODO: we don't want ai control to see the modules of its ship (the entities sharing owner) as stuff to follow
    foreach (flockMember; flockMembers) //nearbyEntities(p_sourceComponent, p_otherComponents, 50.0))
    {
      if (controller.hasComponent(flockMember))
      {
        auto controlComponent = controller.getComponent(flockMember);
        
        //if (controlComponent != p_sourceComponent)
          relativePositions ~= p_sourceComponent.position - controlComponent.position;
      }
    }
    
    auto desiredVel = desiredVelocity(relativePositions);
    
    assert(desiredVel.ok);
    
    if (desiredVel.length() < 0.01)
      return;
    
    //vec2 dir = vec2.fromAngle(p_sourceComponent.angle);
    //float desiredTorque = dir.angle(desiredVel);
    
    //float desiredTorque = p_sourceComponent.angle - desiredVel;
    float desiredTorque = 0.0;
    
    if (desiredTorque > p_sourceComponent.torqueForce)
      desiredTorque = p_sourceComponent.torqueForce;
    if (desiredTorque < -p_sourceComponent.torqueForce)
      desiredTorque = -p_sourceComponent.torqueForce;
    
    if (desiredTorque < 0.1 && p_sourceComponent.velocity.length < 10.0)
      //p_sourceComponent.force += dir.normalized * p_sourceComponent.thrustForce;
      p_sourceComponent.force += vec2(0.0, 1.0 * p_sourceComponent.thrustForce);

    p_sourceComponent.torque = desiredTorque;
  }

  
private:
  // p_otherPositions are relative
  vec2 desiredVelocity(vec2[] p_otherPositions)
  in
  {    
    foreach (otherPos; p_otherPositions)
      assert(otherPos.ok);
  }
  out(result)
  {
    //assert(result.ok);
  }
  body
  {
    vec2 desiredVelocity = vec2(0.0, 0.0);
    
    foreach (otherPosition; p_otherPositions)
    {      
      if (otherPosition.length < m_avoidDistance)
        desiredVelocity += otherPosition.normalized() * m_avoidWeight;
      else if (otherPosition.length < m_flockDistance)
        desiredVelocity -= otherPosition.normalized() * m_flockWeight;
    }
    
    assert(desiredVelocity.ok);
    
    return desiredVelocity;
  }
  
  
public:  
  Entity[] flockMembers;
  Controller controller;
  
private: 
  float m_avoidDistance;
  float m_avoidWeight;
  
  float m_flockDistance;
  float m_flockWeight;
}
