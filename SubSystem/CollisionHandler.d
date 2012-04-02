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
import std.random;
import std.stdio;

import gl3n.linalg;

import Entity;
import SpatialIndex;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new CollisionHandler();
  
  assert(sys.entities.length == 0);
  
  Entity entity = new Entity(["radius":"2.0", "collisionType":"NpcShip"]);
  
  sys.registerEntity(entity);
  
  assert(sys.entities.length == 1);
  
  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 0);
  
  Entity collide = new Entity(["radius":"2.0", "collisionType":"Bullet"]);

  sys.registerEntity(collide);
  
  assert(sys.entities.length == 2);

  sys.getComponent(collide).position = vec2(1.0, 0.0);

  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 1);
  
  //assert(sys.collisions[0].first == sys.getComponent(entity));
  //assert(sys.collisions[0].second == sys.getComponent(collide));
  
  
  Entity noCollide = new Entity(["radius":"2.0", "collisionType":"Asteroid", "position":"10 0"]);
  
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
  Bullet,
  Particle
}


class ColliderComponent
{
  this(float p_radius, CollisionType p_collisionType)
  {
    radius = p_radius;
    collisionType = p_collisionType;
    
    id = idCounter++;
    
    setAABB(m_position);
  }
  
  vec2 m_position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  
  @property vec2 position() { return m_position; }
  
  @property vec2 position(vec2 p_position)
  {
    setAABB(p_position);
    
    return m_position = p_position;
  }
  
  void setAABB(vec2 position)
  {
    vec2i pos = vec2i(cast(int)position.x, cast(int)position.y);
    
    int rad = radius < 1.0 ? 1 : cast(int)radius;
    
    aabb = AABB(vec2i(pos.x - rad, pos.y - rad), vec2i(pos.x + rad, pos.y + rad));
  }
  
  float radius;
  
  vec2 force = vec2(0.0, 0.0);
  //vec2 torque = 0.0;
  
  CollisionType collisionType;
  
  float lifetime = float.infinity;
  float health = float.infinity;
  
  AABB aabb;
  
  // we might not want stuff to collide from the entity it spawned from
  int spawnedFrom;
  int entityId;
  
  // we also might not want stuff to collide with any entities sharing owner with the entity it spawned from
  int spawnedFromOwner;
  int ownerId;
  
  static int idCounter = 0;
  int id;
  
  bool hasCollided = false;
}


struct Collision
{
  ColliderComponent first;
  ColliderComponent second;
  vec2 contactPoint;
  
  bool hasSpawnedParticles = false;
}


class CollisionHandler : Base!(ColliderComponent)
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
  
  string[string][] getAndClearSpawnParticleValues()
  out
  {
    assert(m_spawnParticleValues.length == 0);
  }
  body
  {
    string[string][] tmp = m_spawnParticleValues;
    
    m_spawnParticleValues.length = 0;
    
    return tmp;
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
    
    if ("owner" in p_entity.values)
      colliderComponent.ownerId = to!int(p_entity.getValue("owner"));
    
    if ("spawnedFrom" in p_entity.values)
      colliderComponent.spawnedFrom = to!int(p_entity.getValue("spawnedFrom"));
    if ("spawnedFromOwner" in p_entity.values)
      colliderComponent.spawnedFromOwner = to!int(p_entity.getValue("spawnedFromOwner"));
    
    if ("position" in p_entity.values)
      colliderComponent.position = vec2.fromString(p_entity.getValue("position"));
    
    if ("lifetime" in p_entity.values)
      colliderComponent.lifetime = to!float(p_entity.getValue("lifetime"));
      
    if ("health" in p_entity.values)
      colliderComponent.health = to!float(p_entity.getValue("health"));
    
    return colliderComponent;
  }
  
  
private:
  void determineCollisions()
  {
    m_collisions.length = 0;
    
    index.clear();    
    
    // for now, only bullets can collide, so we only put bullets in the index first - and only if they haven't collided yet
    foreach (component; filter!(component => component.collisionType == CollisionType.Bullet && component.hasCollided == false)(components))
    //foreach (component; components)
    {
      index.insert(component);
    }
    
    // for now, bullets can't collide with freefloating modules or other bullets, so we filter them out
    foreach (component; filter!(component => component.collisionType != CollisionType.FreeFloatingModule &&
                                             component.collisionType != CollisionType.Particle &&
                                             component.collisionType != CollisionType.Bullet)(components))
    {
      auto candidates = index.findNearbyContent(component);
      
      auto first = component;
      
      foreach (candidate; candidates)
      {
        auto second = candidate;

        assert(first.id != second.id);
          
        // bullets should not collide with the entity that spawned them, or any entities that has the same owner... or should they?
        // in other words, should it be possible for your bullets to hit modules on your own ship?
        if ((first.spawnedFromOwner > 0 && second.ownerId > 0 && first.spawnedFromOwner == second.ownerId) || 
            (first.ownerId > 0 && second.spawnedFromOwner > 0 && first.ownerId == second.spawnedFromOwner))
          continue;
        
        if ((first.position - second.position).length < (first.radius + second.radius))
        {
          // determine contact point
          vec2 normalizedContactPoint = (second.position - first.position).normalized(); // / (first.radius + second.radius); // * first.radius;

          vec2 contactPoint = normalizedContactPoint * (1.0/(first.radius + second.radius)) * first.radius;
          
          /*if (first.collisionType == CollisionType.Bullet)
            first.hasCollided = true;
          if (second.collisionType == CollisionType.Bullet)
            second.hasCollided = true;*/
          
          m_collisions ~= Collision(first, second, contactPoint);
        }
      }
    }
  }
  
  void calculateCollisionResponse()
  {
    // physics response is handled in CommsCentral, since we don't know about other types of components here
  
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
      
      if (collision.hasSpawnedParticles == false && (collision.first.hasCollided == false && collision.second.hasCollided == false))
      {
        if (collision.first.collisionType == CollisionType.Bullet)
          collision.first.hasCollided = true;
        if (collision.second.collisionType == CollisionType.Bullet)
          collision.second.hasCollided = true;
      
        int particles = 2;
        for (int i = 0; i < particles; i++)
        {
          string[string] particleValues;
          
          particleValues["position"] = to!string((collision.first.position + collision.second.position) * 0.5 + collision.contactPoint);
          particleValues["rotation"] = to!string(uniform(-3600, 3600));
          particleValues["velocity"] = to!string((collision.first.velocity + collision.second.velocity) * 0.5 + vec2.fromAngle(uniform(-PI, PI)) * 25.0);
          particleValues["drawsource"] = "Star";
          particleValues["radius"] = to!string(uniform(0.15, 0.25));
          particleValues["mass"] = to!string(uniform(0.02, 0.1));
          particleValues["lifetime"] = to!string(uniform(0.5, 2.0));
          particleValues["collisionType"] = "Particle";
          
          m_spawnParticleValues ~= particleValues;
          
          collision.hasSpawnedParticles = true;
        }
      }
      
      //Entity collisionSound = new Entity(["soundFile":"mgshot3.wav"]);
    }
  }
  
  
private:
  Collision[] m_collisions;
  
  Index!ColliderComponent index;
  
  string[string][] m_spawnParticleValues;
}
