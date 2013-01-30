module CollisionResponse.BatBall;

import std.conv;
import std.random;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import SubSystem.CollisionHandler;


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
      // TODO: proper reflection of velocity vector
      //ball.velocity = ball.velocity * -1;
      ball.velocity = ball.velocity - (2.0 * dot(ball.velocity, -contactPointRelativeToBall.normalized()).abs * -contactPointRelativeToBall.normalized());
    
      vec2 collisionPosition = (ball.position + other.position) * 0.5 + collision.contactPoint;
      
      string[string] collisionSound;
      
      collisionSound["soundFile"] = "bounce.wav";
      collisionSound["position"] = collisionPosition.to!string;
      
      collisionHandler.addSpawnParticle(collisionSound);
    }
  }
}
