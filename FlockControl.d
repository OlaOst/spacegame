module FlockControl;

import std.algorithm;

import Control;
import Entity;
import PhysicsSubSystem;
import Vector : Vector;


unittest
{
  FlockControl flock = new FlockControl(0.5, 0.5, 5.0, 0.3);
  
  // check that desired velocity is kept with no other boids in sight
  assert(flock.desiredVelocity(Vector.origo, []) == Vector.origo);
  assert(flock.desiredVelocity(Vector(0.0, 1.0), []) == Vector(0.0, 1.0));
  
  // check that desired velocity is kept with one boid outside both avoid and flock distances
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 10.0)]) == Vector(0.0, 1.0));
  
  // check that desired velocity is changed away with one boid inside avoid distance
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 0.3)]).y < 1.0);
  
  // check that desired velocity is changed towards with one boid outside avoid distance but inside flock distance
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 2.0)]).y > 1.0);
  
  // need alignment rule to harmonize headings
}


class FlockControl : public Control
{
invariant()
{
  assert(m_avoidDistance >= 0.0);
  assert(m_avoidWeight == m_avoidWeight); // negative weights should be possible, so we just check for NaNs
  
  assert(m_flockDistance >= 0.0);
  assert(m_flockWeight == m_flockWeight); // negative weights should be possible, so we just check for NaNs
}


public:
  this(float p_avoidDistance, float p_avoidWeight,
       float p_flockDistance, float p_flockWeight)
  {
    m_avoidDistance = p_avoidDistance;
    m_avoidWeight = p_avoidWeight;
    
    m_flockDistance = p_flockDistance;
    m_flockWeight = p_flockWeight;
  }
  
  
  void update(PhysicsComponent p_sourceComponent, PhysicsComponent[] p_otherComponents)
  out
  {
    assert(p_sourceComponent.force.isValid());
    assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    Vector[] otherPositions = [];
    
    foreach (entity; nearbyEntities(p_sourceComponent, p_otherComponents, 10.0))
      otherPositions ~= entity.position;

    auto desiredVel = desiredVelocity(p_sourceComponent.velocity, otherPositions);
    
    assert(desiredVel.isValid());

    p_sourceComponent.force = p_sourceComponent.force + desiredVel.normalized * 0.2;
  }

  
private:
  Vector desiredVelocity(Vector p_currentVelocity, Vector[] p_otherPositions)
  in
  {
    assert(p_currentVelocity.isValid());
    
    foreach (otherPos; p_otherPositions)
      assert(otherPos.isValid());
  }
  body
  {
    Vector desiredVelocity = p_currentVelocity;
    
    foreach (otherPosition; p_otherPositions)
    {
      assert(otherPosition.isValid());
      assert(otherPosition.normalized().isValid());
      
      if (otherPosition.length2d < m_avoidDistance)
        desiredVelocity -= otherPosition.normalized() * m_avoidWeight;
      
      assert(desiredVelocity.isValid());
      
      if (otherPosition.length2d < m_flockDistance)
        desiredVelocity += otherPosition.normalized() * m_flockWeight;
        
      assert(desiredVelocity.isValid());
    }
    
    return desiredVelocity;
  }
  

private:
  float m_avoidDistance;
  float m_avoidWeight;
  
  float m_flockDistance;
  float m_flockWeight;
}




/*module FlockInput;

import Vector : Vector;


unittest
{
  FlockInput flock = new FlockInput(0.5, 0.5, 5.0, 0.3);
  
  // check that desired velocity is kept with no other boids in sight
  assert(flock.desiredVelocity(Vector.origo, []) == Vector.origo);
  assert(flock.desiredVelocity(Vector(0.0, 1.0), []) == Vector(0.0, 1.0));
  
  // check that desired velocity is kept with one boid outside both avoid and flock distances
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 10.0)]) == Vector(0.0, 1.0));
  
  // check that desired velocity is changed away with one boid inside avoid distance
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 0.3)]).y < 1.0);
  
  // check that desired velocity is changed towards with one boid outside avoid distance but inside flock distance
  assert(flock.desiredVelocity(Vector(0.0, 1.0), [Vector(0.0, 2.0)]).y > 1.0);
  
  // need alignment rule to harmonize headings
}


class FlockInput
{
invariant()
{
  assert(m_avoidDistance >= 0.0);
  assert(m_avoidWeight == m_avoidWeight); // negative weights should be possible, so we just check for NaNs
}


public:
  this(float p_avoidDistance, float p_avoidWeight,
       float p_flockDistance, float p_flockWeight)
  {
    m_avoidDistance = p_avoidDistance;
    m_avoidWeight = p_avoidWeight;
    
    m_flockDistance = p_flockDistance;
    m_flockWeight = p_flockWeight;
  }
  
  
private:
  Vector desiredVelocity(Vector p_currentVelocity, Vector[] p_otherPositions)
  {
    Vector desiredVelocity = p_currentVelocity;
    
    foreach (otherPosition; p_otherPositions)
    {
      if (otherPosition.length2d < m_avoidDistance)
        desiredVelocity -= otherPosition.normalized() * m_avoidWeight;
        
      if (otherPosition.length2d < m_flockDistance)
        desiredVelocity += otherPosition.normalized() * m_flockWeight;
    }
    
    
    return desiredVelocity;
  }
  
  
private:
  float m_avoidDistance;
  float m_avoidWeight;
  
  float m_flockDistance;
  float m_flockWeight;
}*/