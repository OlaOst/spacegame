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

module SubSystem.CollisionHandler;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import Entity;
import SubSystem.Base;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new CollisionHandler();
  
  assert(sys.entities.length == 0);
  
  Entity entity = new Entity();
  entity.setValue("radius", "2.0");
  entity.setValue("collisionType", "NpcShip");
  
  sys.registerEntity(entity);
  
  assert(sys.entities.length == 1);
  
  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 0);
  
  Entity collide = new Entity();
  collide.setValue("radius", "2.0");
  collide.setValue("collisionType", "Bullet");  

  sys.registerEntity(collide);
  
  assert(sys.entities.length == 2);

  sys.getComponent(collide).position = Vector(1.0, 0.0);

  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 1);
  
  assert(sys.collisions[0].first == sys.getComponent(entity));
  assert(sys.collisions[0].second == sys.getComponent(collide));
  
  
  Entity noCollide = new Entity();
  noCollide.setValue("radius", "2.0");
  noCollide.setValue("collisionType", "Asteroid");
  noCollide.setValue("position", "10 0");
  
  sys.registerEntity(noCollide);
  
  assert(sys.entities.length == 3);
  
  sys.determineCollisions();
  assert(sys.collisions.length == 1, "Should be 1 collision, instead got " ~ to!string(sys.collisions.length));
  
  sys.calculateCollisionResponse();
  
  assert(sys.getComponent(collide).lifetime <= 0.0, "Collided bullet didn't get lifetime zeroed: " ~ to!string(sys.getComponent(collide).lifetime));
}


enum CollisionType
{
  Unknown,
  NpcShip,
  NpcModule,
  PlayerShip,
  PlayerModule,
  FreeFloatingModule,
  Asteroid,
  Bullet
}


class ColliderComponent
{
  this(float p_radius, CollisionType p_collisionType)
  {
    position = Vector.origo;
    radius = p_radius;
    collisionType = p_collisionType;
    lifetime = float.infinity;
    
    id = idCounter++;
  }
  
  Vector position;
  float radius;
  
  Vector force;
  Vector torque;
  
  CollisionType collisionType;
  
  float lifetime;
  float health = float.infinity;
  
  // we might not want stuff to collide from the entity it spawned from
  int spawnedFrom;
  int entityId;
  
  // we also might not want stuff to collide with any entities sharing owner with the entity it spawned from
  int spawnedFromOwner;
  int ownerId;
  
  static int idCounter = 0;
  int id;
}


struct Collision
{
  ColliderComponent first;
  ColliderComponent second;
  Vector contactPoint;
}


class CollisionHandler : public Base!(ColliderComponent)
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
  bool canCreateComponent(Entity p_entity)
  {
    return (p_entity.getValue("collisionType").length > 0) && 
           (p_entity.getValue("radius").length > 0) &&
           (p_entity.getValue("isBlueprint") != "true");
  }
  
  
  ColliderComponent createComponent(Entity p_entity)
  {
    float radius = to!float(p_entity.getValue("radius"));
    
    enforce(radius >= 0.0);
    
    auto collisionType = to!CollisionType(p_entity.getValue("collisionType"));
    enforce(collisionType != CollisionType.Unknown, "Tried to create collision component from entity with unknown collision type " ~ p_entity.getValue("collisionType"));
    
    auto colliderComponent = new ColliderComponent(radius, collisionType);
    
    if (p_entity.getValue("owner").length > 0)
      colliderComponent.ownerId = to!int(p_entity.getValue("owner"));
    
    if (p_entity.getValue("spawnedFrom").length > 0)
      colliderComponent.spawnedFrom = to!int(p_entity.getValue("spawnedFrom"));
    if (p_entity.getValue("spawnedFromOwner").length > 0)
      colliderComponent.spawnedFromOwner = to!int(p_entity.getValue("spawnedFromOwner"));
    
    if (p_entity.getValue("position").length > 0)
      colliderComponent.position = Vector.fromString(p_entity.getValue("position"));
    
    if (p_entity.getValue("lifetime").length > 0)
      colliderComponent.lifetime = to!float(p_entity.getValue("lifetime"));
      
    if (p_entity.getValue("health").length > 0)
      colliderComponent.health = to!float(p_entity.getValue("health"));
    
    return colliderComponent;
  }
  
  
private:
  void determineCollisions()
  {
    m_collisions.length = 0;
    
    if (components.length <= 1)
      return;
    
    // for now, we only consider collisions between bullets and not-bullets. this makes it possible to have more than 10 guns shooting without FPS dropping below 5
    // optimizing with spatial hash or similar could speed things up a bit further
    auto bulletComponents = filter!((ColliderComponent component){return component.collisionType == CollisionType.Bullet;})(components);
    auto notBulletComponents = filter!((ColliderComponent component){return component.collisionType != CollisionType.Bullet;})(components);
    
    foreach (bulletComponent; bulletComponents)
    {
      ColliderComponent first = bulletComponent;
      foreach (notBulletComponent; notBulletComponents)
      {
        ColliderComponent second = notBulletComponent;
        
        assert(first != second, "collider component with id " ~ to!string(first.id) ~ " is equal to component with id " ~ to!string(second.id));

        // bullets should not collide with the entity that spawned them, or any entities that has the same owner... or should they?
        if ((first.spawnedFromOwner > 0 && second.ownerId > 0 && first.spawnedFromOwner == second.ownerId) || 
            (first.ownerId > 0 && second.spawnedFromOwner > 0 && first.ownerId == second.spawnedFromOwner))
          continue;
        
        if ((first.position - second.position).length2d < (first.radius + second.radius))
        {
          // determine contact point
          Vector normalizedContactVector = (second.position - first.position).normalized(); // / (first.radius + second.radius); // * first.radius;

          Vector contactPoint = normalizedContactVector * (1.0/(first.radius + second.radius)) * first.radius;
          
          m_collisions ~= Collision(first, second, contactPoint);
        }
      }
    }
  }
  
  void calculateCollisionResponse()
  {
    foreach (ref collision; m_collisions)
    {
      // bullets should disappear on contact - set lifetime to zero
      if (collision.first.collisionType == CollisionType.Bullet)
      {
        collision.first.lifetime = 0.0;
        
        collision.second.health -= 1.0;
      }
      if (collision.second.collisionType == CollisionType.Bullet)
      {
        collision.second.lifetime = 0.0;
        
        collision.first.health -= 1.0;
      }
      
      //Entity collisionSound = new Entity();
      //collisionSound.setValue("soundFile", "mgshot3.wav");
    }
  }
  
private:
  Collision[] m_collisions;
}
