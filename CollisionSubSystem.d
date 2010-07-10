module CollisionSubSystem;

import std.algorithm;
import std.conv;

import Entity;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  auto sys = new CollisionSubSystem();
  
  Entity entity = new Entity();
  entity.setValue("radius", "2.0");
  
  sys.registerEntity(entity);
  
  assert(sys.collisions.length == 0);
  sys.calculateCollisions();
  assert(sys.collisions.length == 0);
  
  Entity collide = new Entity();
  collide.setValue("radius", "2.0");
  collide.position = Vector(1.0, 0.0);
  
  sys.registerEntity(collide);
  
  assert(sys.collisions.length == 0);
  sys.calculateCollisions();
  assert(sys.collisions.length == 1);
  
  assert(sys.collisions[0].first.entity == entity);
  assert(sys.collisions[0].second.entity == collide);
  
  
  Entity noCollide = new Entity();
  noCollide.setValue("radius", "2.0");
  noCollide.position = Vector(10.0, 0.0);
  
  sys.calculateCollisions();
  assert(sys.collisions.length == 1);
}


class CollisionComponent
{
invariant()
{
  assert(m_entity !is null);
  assert(m_radius >= 0.0);
}

public:
  this(Entity p_entity, float p_radius)
  {
    m_entity = p_entity;
    m_radius = p_radius;
  }
  
  Entity entity()
  {
    return m_entity;
  }
  
  float radius()
  {  
    return m_radius;
  }

private:
  Entity m_entity;
  float m_radius;
}


struct Collision
{
  CollisionComponent first;
  CollisionComponent second;
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
  
  void calculateCollisions()
  {
    m_collisions.length = 0;
    
    //foreach (first; components)
    for (uint firstIndex = 0; firstIndex < components.length-1; firstIndex++)
    {
      CollisionComponent first = components[firstIndex];
      
      //foreach (second; components)
      for (uint secondIndex = firstIndex + 1; secondIndex < components.length; secondIndex++)
      {
        CollisionComponent second = components[secondIndex];
        
        assert(first != second);

        if ((first.entity.position - second.entity.position).length2d < (first.radius + second.radius))
        {
          m_collisions ~= Collision(first, second);
        }
      }
    }
  }
  

protected:
  CollisionComponent createComponent(Entity p_entity)
  {
    float radius = to!float(p_entity.getValue("radius"));
    
    return new CollisionComponent(p_entity, radius);
  }
  
  
private:
  Collision[] m_collisions;
}
