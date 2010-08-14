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
  PhysicsSubSystem physics = new PhysicsSubSystem();
  
  Entity entity = new Entity();
  
  entity.setValue("mass", "1.0");
  
  physics.registerEntity(entity);
  
  assert(entity.position == Vector.origo);
  {
    physics.components[0].m_velocity = Vector(1.0, 0.0);
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
    
    //assert(spawnComp.velocity == motherComp.velocity, "Spawned entity didn't get velocity vector copied from spawner");
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
  assert(m_entity !is null, "Physics component had null entity");
  
  assert(m_velocity.isValid());
  assert(m_rotation == m_rotation);
  
  assert(m_force.isValid());
  assert(m_torque == m_torque);
  
  assert(m_reload == m_reload);
}

public:
  this(Entity p_entity)
  {  
    m_entity = p_entity;
    
    m_velocity = Vector.origo;
    m_force = Vector.origo;
    
    m_rotation = 0.0;
    m_torque = 0.0;
    
    m_mass = 1.0;
    
    m_reload = 0.0;
  }
  
  Vector position()
  {
    return m_entity.position;
  }
  
  Vector velocity()
  {
    return m_velocity;
  }
  
  void velocity(Vector p_velocity)
  {
    m_velocity = p_velocity;
  }
  
  float rotation()
  {
    return m_rotation;
  }
  
  Vector force()
  {
    return m_force;
  }
  
  void force(Vector p_force)
  {
    m_force = p_force;
  }
  
  float torque()
  {
    return m_torque;
  }
  
  void torque(float p_torque)
  {
    m_torque = p_torque;
  }

  Entity entity()
  {
    return m_entity;
  }

  
  float reload()
  {
    return m_reload;
  }
  
  void reload(float p_reload)
  {
    m_reload = p_reload;
  }
  
  float mass()
  {
    return m_mass;
  }
  
  void mass(float p_mass)
  {
    m_mass = p_mass;
  }
  
private:
  void move(float p_time)
  in
  {
    assert(p_time >= 0.0);
  }
  body
  {
    //writeln("torque:   " ~ to!string(m_entity.torque));
    //writeln("rotation: " ~ to!string(m_rotation));
    //writeln("angle:    " ~ to!string(m_entity.angle));
    
    //writeln("force: " ~ m_entity.force.toString());
    //writeln("vel:   " ~ m_velocity.toString());
    //writeln("pos:   " ~ m_entity.position.toString());
    
    //writeln("time: " ~ to!string(p_time));
    
    m_velocity = m_velocity + m_force * p_time;
    m_entity.position = m_entity.position + m_velocity * p_time;
    
    m_rotation = m_rotation + m_torque * p_time;
    m_entity.angle = m_entity.angle + m_rotation * p_time;
    
    if (m_reload > 0.0)
      m_reload -= p_time;
  }
  
private:
  Entity m_entity;
  Vector m_velocity;
  Vector m_force;
  
  float m_rotation;
  float m_torque;
  
  float m_mass;
  
  float m_reload;
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
      component.force = component.force + (component.velocity * -0.15);
      component.torque = component.torque + (component.rotation * -2.5);
      
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
          float collisionForce = (component.velocity * component.mass + collisionPhysicsComponent.velocity * collisionPhysicsComponent.mass).length2d;

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
          
          newComponent.velocity = spawnerCandidate.velocity + kick;
          //newComponent.force = kick;
        }
      }
    }
    
    if (p_entity.getValue("velocity") == "randomize")
      newComponent.velocity = Vector(uniform(-1.5, 1.5), uniform(-1.5, 1.5));
    
    assert(p_entity.getValue("mass").length > 0, "couldn't find mass for physics component");
    newComponent.mass = to!float(p_entity.getValue("mass"));
    
    return newComponent;
  }
  
private:
}
