module CollisionResponse.BatBall;

import std.conv;
import std.random;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import SubSystem.CollisionHandler;


void ballBrickCollisionResponse(Collision collision, CollisionHandler collisionHandler)
{
  ballCollisionResponse(collision, collisionHandler);
  
  ColliderComponent ball;
  ColliderComponent brick;
  vec2 contactPointRelativeToBall = collision.contactPoint;
  
  if (collision.first.hasCollided == false && collision.second.hasCollided == false)
  {
    if (collision.first.collisionType == CollisionType.Ball)
    {
      ball = collision.first;
      brick = collision.second;
      
      contactPointRelativeToBall *= -1;
    }
    else
    {
      ball = collision.second;
      brick = collision.first;
    }
  }
  
  // TODO: why do we get triple collisions here when we should only get one?
  if (collision.hasSpawnedParticles == false)
  {
    brick.health -= 1.0;
    
    brick.color.r = brick.color.r + 0.125;
    brick.color.g = brick.color.g - 0.25;
    
    if (collision.hasSpawnedParticles == false)
    {
      vec2 collisionPosition = (ball.position + brick.position) * 0.5 + collision.contactPoint;
    
      int particles = (brick.health > 0.0) ? 3 : 10;
      for (int i = 0; i < particles; i++)
      {
        string[string] particleValues;
        
        vec2 collisionVelocity = (collision.first.velocity.length > collision.second.velocity.length ? collision.first.velocity : collision.second.velocity) * 
                                 -0.1 + mat2.rotation(uniform(-PI, PI)) * vec2(0.0, 1.0) * 2.0;
        
        particleValues["position"] = to!string(collisionPosition);
        particleValues["rotation"] = to!string(uniform(-3600, 3600));
        particleValues["velocity"] = to!string((collision.first.velocity.length > collision.second.velocity.length ? collision.first.velocity : collision.second.velocity) * -0.1 + mat2.rotation(uniform(-PI, PI)) * vec2(0.0, 1.0) * 5.0);
        particleValues["drawsource"] = "Quad";
        particleValues["radius"] = to!string(uniform(0.015, 0.025));
        particleValues["mass"] = to!string(uniform(0.02, 0.1));
        particleValues["lifetime"] = to!string(uniform(0.5, 2.0));
        //particleValues["collisionType"] = "Particle";
        
        collisionHandler.addSpawnParticle(particleValues);
        
        collision.hasSpawnedParticles = true;
      }
    }
  }
}

void ballCollisionResponse(Collision collision, CollisionHandler collisionHandler)
{    
  if (collision.first.hasCollided == false && collision.second.hasCollided == false)
  {
    ColliderComponent other;
    ColliderComponent ball;
    
    vec2 contactPointRelativeToBall = collision.contactPoint;
    
    if (collision.first.collisionType == CollisionType.Ball)
    {
      ball = collision.first;
      other = collision.second;
      
      contactPointRelativeToBall *= -1;
    }
    else
    {
      ball = collision.second;
      other = collision.first;
    }
  
    if (dot(ball.velocity, contactPointRelativeToBall) < 0.0)
    {
      ball.velocity = ball.velocity - (2.0 * dot(ball.velocity, -contactPointRelativeToBall.normalized()).abs * -contactPointRelativeToBall.normalized());
    
      vec2 collisionPosition = (ball.position + other.position) * 0.5 + collision.contactPoint;
      
      string[string] collisionSound;
      
      collisionSound["soundFile"] = "bounce.wav";
      collisionSound["position"] = collisionPosition.to!string;
      
      collisionHandler.addSpawnParticle(collisionSound);
    }
  }
}
