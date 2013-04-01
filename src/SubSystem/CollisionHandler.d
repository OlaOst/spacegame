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

import gl3n.aabb;
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
  
  Entity collide = new Entity(["radius":"2.0", "collisionType":"Bullet", "health":"1.0"]);

  sys.registerEntity(collide);
  
  assert(sys.entities.length == 2);

  sys.getComponent(collide).position = vec2(1.0, 0.0);

  assert(sys.collisions.length == 0);
  sys.determineCollisions();
  assert(sys.collisions.length == 1, "Expected 1 collision, got " ~ sys.collisions.length.to!string);
  
  //assert(sys.collisions[0].first == sys.getComponent(entity));
  //assert(sys.collisions[0].second == sys.getComponent(collide));
  
  
  Entity noCollide = new Entity(["radius":"2.0", "collisionType":"Asteroid", "position":"[10, 0]"]);
  
  sys.registerEntity(noCollide);
  
  assert(sys.entities.length == 3);
  
  sys.determineCollisions();
  assert(sys.collisions.length == 1, "Should be 1 collision, instead got " ~ sys.collisions.length.to!string);
  
  sys.determineCollisions();
  
  sys.executeCollisionResponses();
  
  assert(sys.getComponent(collide).health <= 0.0, "Collided bullet didn't get health zeroed: " ~ sys.getComponent(collide).health.to!string);
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
  Ball,
  Wall
}


class ColliderComponent
{
  this(float p_radius, CollisionType p_collisionType)
  {
    radius = p_radius;
    collisionType = p_collisionType;
    
    m_aabb = AABB(vec3(-radius, -radius, 0.0), vec3(radius, radius, 0.0));
    
    id = idCounter++;
  }
  
  this (AABB p_aabb, CollisionType p_collisionType)
  {
    collisionType = p_collisionType;
    
    id = idCounter++;
    
    m_aabb = p_aabb;
  }
  
  vec2 position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  
  float radius = -1.0;
  
  vec4 color = vec4(1, 1, 1, 1);
  
  vec2 force = vec2(0.0, 0.0);
  //vec2 torque = 0.0;
  
  CollisionType collisionType;
  
  //float lifetime = float.infinity;
  float health = float.infinity;
  
  AABB m_aabb;
  
  @property AABB aabb()
  {
    assert(m_aabb.min.ok);
    assert(m_aabb.max.ok);
    
    return AABB(m_aabb.min + vec3(position, 0.0), m_aabb.max + vec3(position, 0.0)); 
  }
  
  //AABB getAbsoluteAABB() { return AABB(aabb.min + vec3(position, 0.0), aabb.max + vec3(position, 0.0)); }
  
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
    
    // TODO: collision responses should be defined in a config file
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Bullet, CollisionType.NpcShip]] = &bulletBrickCollisionResponse;
    
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Bullet, CollisionType.Brick]] = &bulletBrickCollisionResponse;
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Ball, CollisionType.Wall]] = &ballCollisionResponse;
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Ball, CollisionType.Bat]] = &ballCollisionResponse;
    typesThatCanCollideAndWhatHappensThen[[CollisionType.Ball, CollisionType.Brick]] = &ballBrickCollisionResponse;
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
    //debug writeln("collider creating component from values " ~ to!string(p_entity.values));
  
    enforce("radius" in p_entity.values || 
            ("lowerleft" in p_entity.values && "upperright" in p_entity.values) ||
            ("width" in p_entity.values && "height" in p_entity.values), "Collider component must have either radius, width/height or lowerleft/upperright values");
  
    float radius = -1.0;
    AABB aabb;
    if ("radius" in p_entity)
    {
      radius = p_entity["radius"].to!float;
    
      enforce(radius >= 0.0, "Cannot create collider component with negative radius");
    }
    else if ("width" in p_entity && "height" in p_entity)
    {
      float width = p_entity["width"].to!float;
      float height = p_entity["height"].to!float;
      
      enforce(width >= 0.0 && height >= 0.0, "Cannot create collider component with negative width or height");
      
      aabb.min = vec3(-width/2.0, -height/2.0, 0.0);
      aabb.max = vec3(width/2.0, height/2.0, 0.0);
    }
    else if ("lowerleft" in p_entity && "upperright" in p_entity)
    {
      aabb.min = p_entity["lowerleft"].to!(float[])[0..2].vec3;
      aabb.max = p_entity["upperright"].to!(float[])[0..2].vec3;
    }
    
    auto collisionType = p_entity["collisionType"].to!CollisionType;
    enforce(collisionType != CollisionType.Unknown, "Tried to create collision component from entity with unknown collision type " ~ p_entity["collisionType"]);
    
    auto colliderComponent = (radius >= 0.0) ? new ColliderComponent(radius, collisionType) : new ColliderComponent(aabb, collisionType);
    
    if ("owner" in p_entity.values)
      colliderComponent.ownerId = p_entity.getValue("owner").to!int;
    
    if ("spawnedFrom" in p_entity.values)
      colliderComponent.spawnedFrom = p_entity["spawnedFrom"].to!int;
    if ("spawnedFromOwner" in p_entity.values)
      colliderComponent.spawnedFromOwner = p_entity["spawnedFromOwner"].to!int;
    
    if ("position" in p_entity.values)
      colliderComponent.position = vec2(p_entity.getValue("position").to!(float[])[0..2]);
    
    if ("velocity" in p_entity.values)
      colliderComponent.velocity = vec2(p_entity.getValue("velocity").to!(float[])[0..2]);
    
    //if ("lifetime" in p_entity.values)
      //colliderComponent.lifetime = to!float(p_entity.getValue("lifetime"));
      
    if ("health" in p_entity.values)
      colliderComponent.health = p_entity.getValue("health").to!float;
    
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
      
      //debug writeln("collisionchecking component with id " ~ component.id.to!string ~ " and CollisionType " ~ component.collisionType.to!string ~ " against " ~ candidates.array.length.to!string ~ " candidates");
      
      auto first = component;
      
      foreach (candidate; candidates)
      {
        auto second = candidate;

        assert(first.id != second.id);
        
        //debug writeln("distance to candidate " ~ candidate.id.to!string ~ " with type " ~ candidate.collisionType.to!string ~ ": " ~ (first.position - second.position).length.to!string);
        // check radius or AABB?
        
        bool intersection = false;
        bool leftIntersect = false;
        bool rightIntersect = false;
        bool downIntersect = false;
        bool upIntersect = false;
        
        if (first.radius >= 0.0 && second.radius >= 0.0)
        {
          intersection = (first.position - second.position).length < (first.radius + second.radius);
        }
        else if ((first.radius >= 0.0 && second.radius < 0.0) || (first.radius < 0.0 && second.radius >= 0.0))
        {
          auto circleComponent = (first.radius >= 0.0) ? first : second;
          auto aabbComponent = (first.radius >= 0.0) ? second : first;
          
          auto relativePosition = (circleComponent.position - (aabbComponent.aabb.center.vec2));
          auto relativeAABB = AABB.from_points(aabbComponent.aabb.vertices.map!(vert => vert - aabbComponent.aabb.center).array);
          
          intersection = relativePosition.x < (relativeAABB.max.x + circleComponent.radius) &&
                         relativePosition.x > (relativeAABB.min.x - circleComponent.radius) &&
                         relativePosition.y < (relativeAABB.max.y + circleComponent.radius) &&
                         relativePosition.y > (relativeAABB.min.y - circleComponent.radius);

          leftIntersect  = relativePosition.x < (relativeAABB.min.x + circleComponent.radius);
          rightIntersect = relativePosition.x > (relativeAABB.max.x - circleComponent.radius);
          downIntersect  = relativePosition.y < (relativeAABB.min.y + circleComponent.radius);
          upIntersect    = relativePosition.y > (relativeAABB.max.y - circleComponent.radius);
                         
          //intersection = rightIntersect && leftIntersect && downIntersect && upIntersect;
          
          //debug writeln("intersection " ~ (intersection?"true":"false") ~ " between circleComponent with radius " ~ circleComponent.radius.to!string ~ " and aabbComponent with " ~ relativeAABB.to!string ~ ", relative position " ~ relativePosition.to!string);
        }
        else
        {
          intersection = first.aabb.intersects(second.aabb);
        }
        
        //if ((first.position - second.position).length < (first.radius + second.radius))
        if (intersection)
        {
          // determine contact point
          vec2 normalizedContactPoint = (second.position - first.position).normalized(); // / (first.radius + second.radius); // * first.radius;

          //vec2 contactPoint = normalizedContactPoint * (1.0/(first.radius + second.radius)) * first.radius;
          vec2 contactPoint;
          if (first.radius >= 0.0 && second.radius >= 0.0)
          {
            contactPoint = normalizedContactPoint * (first.radius^^2 / (first.radius + second.radius));
          }
          else if ((first.radius >= 0.0 && second.radius < 0.0) || (first.radius < 0.0 && second.radius >= 0.0))
          {
            auto circleComponent = (first.radius >= 0.0) ? first : second;
            auto aabbComponent = (first.radius >= 0.0) ? second : first;
            
            //debug writeln(leftIntersect.to!string ~ " " ~ rightIntersect.to!string ~ " " ~ downIntersect.to!string ~ " " ~ upIntersect.to!string);
            
            // TODO: what about corner collisions, with multi-side intersections?
            if (leftIntersect)
              contactPoint = vec2(aabbComponent.aabb.min.x, circleComponent.position.y);
            else if (rightIntersect)
              contactPoint = vec2(aabbComponent.aabb.max.x, circleComponent.position.y);
            else if (downIntersect)
              contactPoint = vec2(circleComponent.position.x, aabbComponent.aabb.max.y);
            else if (upIntersect)
              contactPoint = vec2(circleComponent.position.x, aabbComponent.aabb.min.y);
            else // should not happen, just make a best effort instead of sending off a bogus contactPoint position
              contactPoint = (circleComponent.position + aabbComponent.position) * 0.5;
              
            assert(contactPoint.ok);
            
            //debug writeln("circle/aabb contactpoint " ~ contactPoint.to!string);
              
            //auto relativePosition = (circleComponent.position - (aabbComponent.aabb.center.vec2));
            //auto relativeAABB = AABB.from_points(aabbComponent.aabb.vertices.map!(vert => vert - aabbComponent.aabb.center).array);
          }
          
          //debug writeln("contactpoint: " ~ contactPoint.to!string ~ ", first radius: " ~ first.radius.to!string ~ ", second radius: " ~ second.radius.to!string);
          
          CollisionType[2] key = [candidate.collisionType, component.collisionType];
          
          // TODO: set up the components that the key is always in typesThatCanCollideAndWhatHappensThen - we should not check components that can not collide
          //assert(key in typesThatCanCollideAndWhatHappensThen, "Could not find collision type pair " ~ [candidate.collisionType, component.collisionType].to!string ~ " in typesThatCanCollideAndWhatHappensThen, containing " ~ typesThatCanCollideAndWhatHappensThen.keys.to!string);
          
          if (key in typesThatCanCollideAndWhatHappensThen)
            m_collisions ~= Collision(first, second, contactPoint, typesThatCanCollideAndWhatHappensThen[key]);
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
