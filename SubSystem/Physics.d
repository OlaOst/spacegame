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

module SubSystem.Physics;

import std.conv;
import std.exception;
import std.math;
import std.random;
import std.stdio;

import SubSystem.Base;
import Entity;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Physics physics = new Physics();
  
  Entity entity = new Entity();
  
  entity.setValue("mass", "1.0");
  
  physics.registerEntity(entity);
  
  assert(physics.getComponent(entity).position == Vector.origo);
  {
    physics.getComponent(entity).velocity = Vector(1.0, 0.0);
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
  assert(entity !is null, "Physics component had null entity");
  
  assert(force.isValid());
  assert(torque == torque);
}


public:
  this(Entity p_entity)
  {  
    entity = p_entity;
    
    force = velocity = position = Vector.origo;
    
    torque = rotation = angle = 0.0;
    
    mass = 1.0;
  }

  
private:
  void move(float p_time)
  in
  {
    assert(p_time == p_time);
    assert(p_time > 0.0);
    assert(force.isValid());
    assert(torque == torque);
  }
  out
  {
    assert(position.isValid());
    assert(velocity.isValid());
  }
  body
  {
    velocity += (force / mass) * p_time;
    position += velocity * p_time;
    
    rotation += (torque / mass) * p_time;
    angle += rotation * p_time;
      
    // reset force and torque after applying them
    force = Vector.origo;
    torque = 0.0;
  }
  

public:
  Entity entity;
  
  Vector position;
  Vector velocity;
  Vector force;
  
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
      // add spring force to center
      //component.force = component.force + (component.position * -0.05);
      
      // and some damping
      component.force = component.force + (component.velocity * -0.15);
      component.torque = component.torque + (component.rotation * -2.5);
      
      // handle collisions TODO: but not in physics
      /*foreach (collision; component.entity.getAndClearCollisions)
      {
        ColliderComponent self = (collision.first.entity == component.entity) ? collision.first : collision.second;
        ColliderComponent other = (collision.first.entity == component.entity) ? collision.second : collision.first;
        
        // this physics component might have collided with a non-physics component, i.e. ship moving over and lighting up something in the background or the hud, like a targeting reticle 
        // if we have physics component on the other collision component, we can do something physical
        if (hasComponent(other.entity))
        {
          auto otherPhysicsComponent = getComponent(other.entity);
          
          // determine collision force
          float collisionForce = (component.velocity * component.mass + otherPhysicsComponent.velocity * otherPhysicsComponent.mass).length2d;

          // give a kick from the contactpoint
          component.force = component.force + (collision.contactPoint.normalized() * -collisionForce);
          
          // reduce health for certain collisiontypes
          if (self.collisionType == CollisionType.NpcShip && other.collisionType == CollisionType.Bullet)
          {
            debug write("reducing npc ship health from " ~ to!string(self.entity.health) ~ " to ");
            self.entity.health -= otherPhysicsComponent.mass * (other.entity.velocity.length2d() - self.entity.velocity.length2d());
            debug writeln(to!string(self.entity.health));
          }
        }
      }
      */
      
      component.move(p_time);
      
      // reset force and torque so they're ready for next update
      component.force = Vector.origo;
      component.torque = 0.0;
    }
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("mass").length > 0;
  }
  
  
  PhysicsComponent createComponent(Entity p_entity)
  {
    auto newComponent = new PhysicsComponent(p_entity);
    
    if (p_entity.getValue("position").length > 0)
      newComponent.position = Vector.fromString(p_entity.getValue("position"));
    
    if (p_entity.getValue("velocity") == "randomize")
    {
      newComponent.velocity = Vector(uniform(-1.5, 1.5), uniform(-1.5, 1.5));
    }
    else if (p_entity.getValue("velocity").length > 0)
    {
      newComponent.velocity = Vector.fromString(p_entity.getValue("velocity"));
    }
    
    if (p_entity.getValue("force").length > 0)
      newComponent.force = Vector.fromString(p_entity.getValue("force"));
      
    
    //enforce(p_entity.getValue("mass").length > 0, "couldn't find mass for physics component");
    if (p_entity.getValue("mass").length > 0)
      newComponent.mass = to!float(p_entity.getValue("mass"));
    
    return newComponent;
  }
  
private:
  float m_timeStep;
}
