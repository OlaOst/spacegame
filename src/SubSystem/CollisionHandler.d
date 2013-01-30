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
import std.array;
import std.conv;
import std.exception;
import std.random;
import std.stdio;
import std.string;

import gl3n.linalg;
import gl3n.math;

import CollisionResponse.Bullet;
import CollisionResponse.BatBall;

import Entity;
import SpatialIndex;
import SubSystem.Base;
import Utils;


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
  
  assert(sys.getComponent(collide).health <= 0.0, "Collided bullet didn't get health zeroed: " ~ to!string(sys.getComponent(collide).health));
}


alias void function (Collision collision, CollisionHandler collisionHandler) CollisionResponseFunction;


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
  Particle,
  Brick,
  Bat,
  Ball
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
    
    aabb = AABB!vec2i(vec2i(pos.x - rad, pos.y - rad), vec2i(pos.x + rad, pos.y + rad));
  }
  
  float radius;
  
  vec4 color = vec4(1, 1, 1, 1);
  
  vec2 force = vec2(0.0, 0.0);
  //vec2 torque = 0.0;
  
  CollisionType collisionType;
  
  //float lifetime = float.infinity;
  float health = float.infinity;
  
  AABB!vec2i aabb;
  
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
  
  CollisionResponseFunction response;
  
  bool hasSpawnedParticles = false;
}


class CollisionHandler : Base!(ColliderComponent)
{
public:
  this()
  {
    CollisionResponseFunction bulletHit = function (collision, this) { writeln("collision between " ~ collision.first.collisionType.to!string ~ " and " ~ collision.second.collisionType.to!string); };
    //typesThatCanCollideAndWhatHappensThen[[CollisionType.Bullet, CollisionType.Brick]] = bulletHit;
    
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Bullet, CollisionType.Brick]] = &bulletBrickCollisionResponse;
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Bat, CollisionType.Ball]] = &batBallCollisionResponse;
  }
  
  Collision[] collisions()
  {
    return m_collisions;
  }
  
  void update()
  {
    determineCollisions();
    executeCollisionResponses();
  }
  
  void addSpawnParticle(string[string] values)
  {
    m_spawnParticleValues ~= values;
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
  
  Entity[] getNoHealthEntities()
  {
    return filter!(entity => getComponent(entity).health <= 0.0)(entities).array();
  }
  

protected:
  bool canCreateComponent(Entity p_entity)
  {
    return (p_entity.getValue("collisionType").length > 0) && 
           //(p_entity.getValue("radius").length > 0) &&
           (p_entity.getValue("isBlueprint") != "true");
  }
  
  
  ColliderComponent createComponent(Entity p_entity)
  {
    //writeln("collider creating component from values " ~ to!string(p_entity.values));
  
    enforce("radius" in p_entity.values, "Cannot create collider component without radius");
  
    float radius = to!float(p_entity.getValue("radius"));
    
    enforce(radius >= 0.0, "Cannot create collider component with negative radius");
    
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
      colliderComponent.position = vec2(p_entity.getValue("position").to!(float[])[0..2]);
    
    if ("velocity" in p_entity.values)
      colliderComponent.velocity = vec2(p_entity.getValue("velocity").to!(float[])[0..2]);
    
    //if ("lifetime" in p_entity.values)
      //colliderComponent.lifetime = to!float(p_entity.getValue("lifetime"));
      
    if ("health" in p_entity.values)
      colliderComponent.health = to!float(p_entity.getValue("health"));
    
    if ("color" in p_entity)
      colliderComponent.color = p_entity["color"].to!(float[])[0..4].vec4;
      
    
    return colliderComponent;
  }
  
  
private:
  void determineCollisions()
  {
    m_collisions.length = 0;
    
    index.clear();
    
    bool[CollisionType] addedTypes;
    foreach (CollisionType[2] typePair; typesThatCanCollideAndWhatHappensThen.keys)
    {
      auto firstType = typePair[0];
      
      if (firstType !in addedTypes)
      {
        auto firstTypeComponents = components.filter!(component => component.collisionType == firstType);
        
        //debug writeln("putting " ~ firstTypeComponents.count.to!string ~ " components with CollisionType " ~ firstType.to!string ~ " in index");
        
        foreach (component; firstTypeComponents)
          index.insert(component);
        
        //debug writeln("index length: " ~ index.indicesForContent.length.to!string ~ " / " ~ index.contentsInIndex.length.to!string);
        
        addedTypes[firstType] = true;
      }
    }
    
    foreach (component; components.filter!(component => typesThatCanCollideAndWhatHappensThen.keys.map!(typePair => typePair[1]).canFind(component.collisionType)))
    {
      auto candidates = index.findNearbyContent(component).uniq;
      
      //debug writeln("candidates: " ~ candidates.map!(candidate => candidate.id.to!string).to!string);
      
      //debug writeln("collisionchecking component with id " ~ component.id.to!string ~ " and CollisionType " ~ component.collisionType.to!string ~ " against " ~ candidates.length.to!string ~ " candidates");
      
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
        
        //debug writeln("distance to candidate " ~ candidate.id.to!string ~ ": " ~ (first.position - second.position).length.to!string);
        
        if ((first.position - second.position).length < (first.radius + second.radius))
        {
          // determine contact point
          vec2 normalizedContactPoint = (second.position - first.position).normalized(); // / (first.radius + second.radius); // * first.radius;

          //vec2 contactPoint = normalizedContactPoint * (1.0/(first.radius + second.radius)) * first.radius;
          vec2 contactPoint = normalizedContactPoint * (first.radius^^2 / (first.radius + second.radius));
          
          //debug writeln("contactpoint: " ~ contactPoint.to!string ~ ", first radius: " ~ first.radius.to!string ~ ", second radius: " ~ second.radius.to!string);
          
          //assert([candidate.collisionType, component.collisionType] in typesThatCanCollideAndWhatHappensThen, "Could not find collision type pair " ~ [candidate.collisionType, component.collisionType].to!string ~ " in typesThatCanCollideAndWhatHappensThen, containing " ~ typesThatCanCollideAndWhatHappensThen.keys.to!string);
          
          m_collisions ~= Collision(first, second, contactPoint, typesThatCanCollideAndWhatHappensThen[[candidate.collisionType, component.collisionType]]);
        }
      }
    }
  }
  
  void executeCollisionResponses()
  {
    foreach (ref collision; m_collisions)
    {
      collision.response(collision, this);
    }
  }
  
  
private:
  Collision[] m_collisions;
  
  Index!ColliderComponent index;
  
  string[string][] m_spawnParticleValues;
  
  CollisionResponseFunction[CollisionType[2]] typesThatCanCollideAndWhatHappensThen;
}
