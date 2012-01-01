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

module SubSystem.Physics;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import SubSystem.Base;
import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Physics physics = new Physics();
  
  Entity entity = new Entity();
  
  entity.setValue("mass", "1.0");
  
  physics.registerEntity(entity);
  
  assert(physics.getComponent(entity).position == vec2(0.0, 0.0));
  {
    physics.getComponent(entity).velocity = vec2(1.0, 0.0);
    physics.move(1.0);
  }
  assert(physics.getComponent(entity).position.x > 0.0);
  
  {
    Entity notAPhysicsEntity = new Entity();
    notAPhysicsEntity.setValue("no mass value in this entity", "no mass at all");
    
    auto componentsBefore = physics.components.length;
    
    physics.registerEntity(notAPhysicsEntity);

    assert(physics.components.length == componentsBefore);
  }
}


class PhysicsComponent
{
invariant()
{
  //assert(entity !is null, "Physics component had null entity");
  
  assert(force.ok);
  assert(torque == torque);
  
  assert(mass == mass);
  assert(mass > 0.0);
}


public:
  this(/*Entity p_entity*/)
  {  
    //entity = p_entity;
    
    force = impulse = velocity = position = vec2(0.0, 0.0);
    
    torque = rotation = angle = 0.0;
    
    mass = 1.0;
  }

  
private:
  void move(float p_time)
  in
  {
    assert(p_time == p_time);
    assert(p_time > 0.0);
    assert(force.ok, "Physics component update detected invalid force vec2: " ~ force.toString());
    assert(torque == torque, to!string(torque));
  }
  out
  {
    assert(position.ok);
    assert(velocity.ok);
  }
  body
  {
    assert(mass > 0.0, "Trying to move physics component with zero mass");
    
    //if (force.length > 0.0)
      //writeln("physics update, force is " ~ to!string(force));
    
    velocity += (force * (1.0 / mass)) * p_time;
    velocity += impulse * p_time;
    
    position += velocity * p_time;
    
    rotation += (torque / mass) * p_time;
    angle += rotation * p_time;
    
    while (angle < -PI)
      angle += PI*2;
    while (angle > PI)
      angle -= PI*2;
    
    // reset force and torque after applying them
    force = vec2(0.0, 0.0);
    torque = 0.0;
    impulse = vec2(0.0, 0.0);
  }
  

public:
  //Entity entity;
  
  vec2 position;
  vec2 velocity;
  vec2 impulse;
  vec2 force;
  
  float angle;
  float rotation;
  float torque;
  
  float mass;
}


class Physics : public Base!(PhysicsComponent)
{
public:
  this()
  {
  }
  
  void update()
  {
    move(m_timeStep);
  }
  
  void setTimeStep(float p_timeStep)
  {
    m_timeStep = p_timeStep;
  }
  

private:
  void move(float p_time)
  in
  {
    assert(p_time > 0.0, "Physics must have a positive nonzero timestep to update: " ~ to!string(p_time) ~ " doesn't cut it.");
  }
  body
  {
    foreach (component; components)
    {
      assert(component.force.ok);
      assert(component.torque == component.torque);
      assert(component.velocity.ok);
      assert(component.rotation == component.rotation);
      
      // add spring force to center
      //component.force = component.force + (component.position * -0.05);
      
      // add some damping
      component.force += (component.velocity * -0.15);
      component.torque += (component.rotation * -20.5);
      
      assert(component.torque == component.torque);
      
      component.move(p_time);
      
      // reset force and torque so they're ready for next update
      component.force = vec2(0.0, 0.0);
      component.torque = 0.0;
    }
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    if ("mass" in p_entity.values)
      assert(to!float(p_entity.getValue("mass")) > 0.0, "Zero mass entity " ~ to!string(p_entity.id) ~ ": " ~ to!string(p_entity.values));
    
    return p_entity.getValue("mass").length > 0;
  }
  
  
  PhysicsComponent createComponent(Entity p_entity)
  {
    auto newComponent = new PhysicsComponent(/*p_entity*/);
    
    if (p_entity.getValue("position").length > 0)
      newComponent.position = vec2.fromString(p_entity.getValue("position"));
    
    if (p_entity.getValue("angle").length > 0)
      newComponent.angle = to!float(p_entity.getValue("angle")) * PI_180;
    
    //writeln(name ~ " setting angle to " ~ to!string(newComponent.angle) ~ " from " ~ p_entity.getValue("angle"));
    
    if (p_entity.getValue("velocity").length > 0)
      newComponent.velocity = vec2.fromString(p_entity.getValue("velocity"));
    
    if (p_entity.getValue("force").length > 0)
      newComponent.force = vec2.fromString(p_entity.getValue("force"));
      
    if (p_entity.getValue("mass").length > 0)
      newComponent.mass = to!float(p_entity.getValue("mass"));
    
    return newComponent;
  }
  
private:
  float m_timeStep;
}
