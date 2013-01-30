module CollisionResponse.BatBall;

import std.conv;
import std.random;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import SubSystem.CollisionHandler;


void batBallCollisionResponse(Collision collision, CollisionHandler collisionHandler)
{    
  if (collision.hasSpawnedParticles == false && (collision.first.hasCollided == false && collision.second.hasCollided == false))
  {
    ColliderComponent bat;
    ColliderComponent ball;
    
    if (collision.first.collisionType == CollisionType.Bat)
    {
      bat = collision.first;
      ball = collision.second;
    }
    else
    {
      bat = collision.second;
      ball = collision.first;
    }
  
    bat.hasCollided = true;
    ball.hasCollided = true;

    writeln("batBallCollisionResponse!");
    
    if (ball.velocity.y < 0.0)
      ball.velocity.y = -ball.velocity.y;
    //ball.velocity = vec2(0.0, 0.0);
    
    vec2 collisionPosition = (collision.first.position + collision.second.position) * 0.5 + collision.contactPoint;
    
    string[string] collisionSound;
    
    collisionSound["soundFile"] = "collision1.wav";
    collisionSound["position"] = collisionPosition.to!string;
    //collisionSound["velocity"] = ((collision.first.velocity * collision.first.radius + collision.second.velocity * collision.second.radius) * (1.0/(collision.first.radius + collision.second.radius))).to!string;
    
    collisionHandler.addSpawnParticle(collisionSound);
  }
}
