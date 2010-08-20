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

module CollisionSubSystem;

import std.algorithm;
import std.conv;
import std.stdio;

import Entity;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new CollisionSubSystem();
  
  Entity entity = new Entity();
  entity.setValue("radius", "2.0");
  entity.setValue("collisionType", "ship");
  
  sys.registerEntity(entity);
  
  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 0);
  
  Entity collide = new Entity();
  collide.setValue("radius", "2.0");
  collide.setValue("collisionType", "bullet");
  collide.position = Vector(1.0, 0.0);
  
  sys.registerEntity(collide);
  
  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 1);
  
  assert(sys.collisions[0].first.entity == entity);
  assert(sys.collisions[0].second.entity == collide);
  
  
  Entity noCollide = new Entity();
  noCollide.setValue("radius", "2.0");
  noCollide.setValue("collisionType", "asteroid");
  noCollide.position = Vector(10.0, 0.0);
  
  sys.determineCollisions();
  assert(sys.collisions.length == 1);
  
  sys.calculateCollisionResponse();
  
  assert(collide.lifetime <= 0.0);
}


enum CollisionType
{
  Unknown,
  Ship,
  Asteroid,
  Bullet
}


class CollisionComponent
{
invariant()
{
  assert(m_entity !is null);
  assert(m_radius >= 0.0);
}

public:
  this(Entity p_entity, float p_radius, CollisionType p_collisionType)
  {
    m_entity = p_entity;
    m_radius = p_radius;
    m_collisionType = p_collisionType;
  }
  
  Entity entity()
  {
    return m_entity;
  }
  
  float radius()
  {  
    return m_radius;
  }
  
  CollisionType collisionType()
  {
    return m_collisionType;
  }

private:
  Entity m_entity;
  float m_radius;
  CollisionType m_collisionType;
}


struct Collision
{
  CollisionComponent first;
  CollisionComponent second;
  Vector contactPoint;
}


class CollisionSubSystem : public SubSystem!(CollisionComponent)
{
public:
  this()
  {
  }
  
  Collision[] collisions()
  {
    return m_collisions;
  }
  
  void update()
  {
    determineCollisions();
    calculateCollisionResponse();
  }
  

protected:
  CollisionComponent createComponent(Entity p_entity)
  {
    float radius = to!float(p_entity.getValue("radius"));
    
    assert(radius >= 0.0);
    
    CollisionType collisionType = CollisionType.Unknown;
    
    switch (p_entity.getValue("collisionType"))
    {
      case "ship":
        collisionType = CollisionType.Ship;
        break;
      case "asteroid":
        collisionType = CollisionType.Asteroid;
        break;
      case "bullet":
        collisionType = CollisionType.Bullet;
        break;        
        
      default:
        assert("Tried to create collision component from entity without collision type");
        break;
    }
    
    return new CollisionComponent(p_entity, radius, collisionType);
  }
  
  
private:
  void determineCollisions()
  {
    m_collisions.length = 0;

    if (components.length <= 1)
      return;
    
    // TODO: de-O^2 this, spatial hash or something
    for (uint firstIndex = 0; firstIndex < components.length-1; firstIndex++)
    {
      CollisionComponent first = components[firstIndex];
      
      for (uint secondIndex = firstIndex + 1; secondIndex < components.length; secondIndex++)
      {
        CollisionComponent second = components[secondIndex];
        
        assert(first != second);

        if ((first.entity.position - second.entity.position).length2d < (first.radius + second.radius))
        {
          // determine contact point
          Vector normalizedContactVector = (second.entity.position - first.entity.position).normalized(); // / (first.radius + second.radius); // * first.radius;
      
          Vector contactPoint = normalizedContactVector * (1.0/(first.radius + second.radius)) * first.radius;
          
          m_collisions ~= Collision(first, second, contactPoint);
        }
      }
    }
  }
  
  void calculateCollisionResponse()
  {
    foreach (collision; m_collisions)
    {
      // bullets should disappear on contact - set lifetime to zero
      if (collision.first.collisionType == CollisionType.Bullet)
      {
        collision.first.entity.lifetime = 0.0;
      }
      if (collision.second.collisionType == CollisionType.Bullet)
      {
        collision.second.entity.lifetime = 0.0;
      }
      
      Entity collisionSound = new Entity();
      collisionSound.setValue("soundFile", "mgshot3.wav");
      collisionSound.setValue("onlySound", "true");
      collision.first.entity.addSpawn(collisionSound);
      collision.second.entity.addSpawn(collisionSound);

      collision.first.entity.addCollision(collision);
      collision.second.entity.addCollision(Collision(collision.second, collision.first, collision.contactPoint * -1));
    }
  }
  
private:
  Collision[] m_collisions;
}
