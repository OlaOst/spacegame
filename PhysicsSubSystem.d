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

module PhysicsSubSystem;

import std.conv;
import std.math;
import std.random;
import std.stdio;

import CollisionSubSystem;
import Entity;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  PhysicsSubSystem physics = new PhysicsSubSystem();
  
  Entity entity = new Entity();
  
  entity.setValue("mass", "1.0");
  
  physics.registerEntity(entity);
  
  assert(entity.position == Vector.origo);
  {
    physics.components[0].entity.velocity = Vector(1.0, 0.0);
    physics.move(1.0);
  }
  assert(entity.position.x > 0.0);
  
  {
    Entity spawn = new Entity();
    spawn.setValue("spawnedFrom", to!string(entity.id));
    spawn.setValue("mass", "0.2");
    
    physics.registerEntity(spawn);
    
    auto spawnComp = physics.findComponents(spawn)[0];
    auto motherComp = physics.findComponents(entity)[0];
    
    //assert(spawnComp.entity.velocity == motherComp.entity.velocity, "Spawned entity didn't get velocity vector copied from spawner");
  }
  // TODO: what should happen when registering an entity whose spawnedFrom doesn't exists
  
  
  {
    Entity flocker = new Entity();
    flocker.setValue("control", "flocker");
    flocker.setValue("mass", "0.5");
    
    physics.registerEntity(flocker);

    physics.move(1.0);
  }
}


class PhysicsComponent
{
invariant()
{
  assert(entity !is null, "Physics component had null entity");
  
  assert(force.isValid());
  assert(torque == torque);
  
  assert(reload == reload);
}


public:
  this(Entity p_entity)
  {  
    entity = p_entity;
    
    force = Vector.origo;
    
    torque = 0.0;
    
    mass = 1.0;
    
    reload = 0.0;
  }

  
private:
  void move(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    entity.velocity += force * p_time;
    entity.position += entity.velocity * p_time;
    
    entity.rotation += torque * p_time;
    entity.angle += entity.rotation * p_time;
    
    if (reload > 0.0)
      reload -= p_time;
  }
  

public:
  Entity entity;
  Vector force;
  
  float torque;
  
  float mass;
  
  float reload;
}


class PhysicsSubSystem : public SubSystem!(PhysicsComponent)
{
public:
  this()
  {
  }
  
  
  void move(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    foreach (component; components)
    {
      // add spring force to center
      //component.force = component.force + (component.position * -0.05);
      
      // and some damping
      component.force = component.force + (component.entity.velocity * -0.15);
      component.torque = component.torque + (component.entity.rotation * -2.5);
      
      // handle collisions
      foreach (collision; component.entity.getAndClearCollisions)
      {
        CollisionComponent other = (collision.first.entity == component.entity) ? collision.second : collision.first;
        
        // this physics component might have collided with a non-physics component, i.e. ship moving over and lighting up something in the background or the hud
        auto possiblePhysicsComponents = findComponents(other.entity);
        
        // if we have physics component on the other collision component, we can do something physical
        if (possiblePhysicsComponents.length > 0)
        {
          auto collisionPhysicsComponent = possiblePhysicsComponents[0];
          
          // determine collision force
          float collisionForce = (component.entity.velocity * component.mass + collisionPhysicsComponent.entity.velocity * collisionPhysicsComponent.mass).length2d;

          // give a kick from the contactpoint
          component.force = component.force + (collision.contactPoint.normalized() * -collisionForce);
        }
      }
      
      component.move(p_time);
      
      // do wraparound stuff      
      //if (component.entity.position.length2d > 100.0)
        //component.entity.position = component.entity.position * -1;
      if (abs(component.entity.position.x) > 100.0)
        component.entity.position = Vector(component.entity.position.x * -1, component.entity.position.y);
      if (abs(component.entity.position.y) > 100.0)
        component.entity.position = Vector(component.entity.position.x, component.entity.position.y * -1);
      
      // reset force and torque so they're ready for next update
      component.force = Vector.origo;
      component.torque = 0.0;
    }
  }
  
  
protected:
  PhysicsComponent createComponent(Entity p_entity)
  {
    auto newComponent = new PhysicsComponent(p_entity);
    
    // spawns needs some stuff from spawnedFrom entity to know their initial position, direction, velocity, etc
    if (p_entity.getValue("spawnedFrom"))
    {
      int spawnedFromId = to!int(p_entity.getValue("spawnedFrom"));
      
      foreach (spawnerCandidate; components)
      {
        if (spawnerCandidate.entity.id == spawnedFromId)
        {
          Vector kick = Vector.fromAngle(spawnerCandidate.entity.angle);
          
          // TODO: should be force from spawn value
          kick *= 25.0;
          
          newComponent.entity.velocity = spawnerCandidate.entity.velocity + kick;
        }
      }
    }
    
    if (p_entity.getValue("velocity") == "randomize")
    {
      newComponent.entity.velocity = Vector(uniform(-1.5, 1.5), uniform(-1.5, 1.5));
    }
    
    assert(p_entity.getValue("mass").length > 0, "couldn't find mass for physics component");
    newComponent.mass = to!float(p_entity.getValue("mass"));
    
    return newComponent;
  }
  
private:
}
