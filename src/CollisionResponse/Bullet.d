module CollisionResponse.Bullet;

import std.conv;
import std.random;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import SubSystem.CollisionHandler;
import Utils;


void bulletBrickCollisionResponse(Collision collision, CollisionHandler collisionHandler)
{
  bulletCollisionResponse(collision, collisionHandler);
  
  // set color on bricks according to damage
  if (collision.first.collisionType == CollisionType.Brick)
  {
    collision.first.color.r = collision.first.color.r + 0.125;
    collision.first.color.g = collision.first.color.g - 0.25;
    
    //debug writeln(collision.first.color);
  }
  if (collision.second.collisionType == CollisionType.Brick)
  {
    collision.second.color.r = collision.second.color.r + 0.125;
    collision.second.color.g = collision.second.color.g - 0.25;
    
    //debug writeln(collision.second.color);
  }
}

void bulletCollisionResponse(Collision collision, CollisionHandler collisionHandler)
{    
  if (collision.hasSpawnedParticles == false && (collision.first.hasCollided == false && collision.second.hasCollided == false))
  {
    // bullets should disappear on contact - set health to zero
    if (collision.first.collisionType == CollisionType.Bullet)
    {
      collision.first.health = 0.0;
      collision.second.health -= 1.0;
    }
    if (collision.second.collisionType == CollisionType.Bullet)
    {
      collision.second.health = 0.0;
      collision.first.health -= 1.0;
    }
  
    if (collision.first.collisionType == CollisionType.Bullet)
      collision.first.hasCollided = true;
    if (collision.second.collisionType == CollisionType.Bullet)
      collision.second.hasCollided = true;
  
    //vec2 collisionPosition = (collision.first.position + collision.second.position) * 0.5 + collision.contactPoint;
    vec2 collisionPosition = collision.contactPoint;
    
    assert(collisionPosition.ok);
  
    //debug writeln("collision first pos: " ~ collision.first.position.to!string ~ ", second pos: " ~ collision.second.position.to!string ~ ", contact point: " ~ collision.contactPoint.to!string);
    //debug writeln("calculated collisionpos: " ~ collisionPosition.to!string);
  
    int particles = 10;
    for (int i = 0; i < particles; i++)
    {
      string[string] particleValues;
      
      vec2 collisionVelocity = (collision.first.velocity.length > collision.second.velocity.length ? collision.first.velocity : collision.second.velocity) * 
                               -0.1 + rotation(uniform(-PI, PI)) * vec2(0.0, 1.0) * 2.0;
      
      particleValues["position"] = collisionPosition.to!string;
      particleValues["rotation"] = uniform(-3600, 3600).to!string;
      particleValues["velocity"] = ((collision.first.velocity.length > collision.second.velocity.length ? collision.first.velocity : collision.second.velocity) * -0.1 + rotation(uniform(-PI, PI)) * vec2(0.0, 1.0) * 5.0).to!string;
      particleValues["drawsource"] = "Quad";
      particleValues["radius"] = ((collision.first.collisionType == CollisionType.Bullet) ? collision.first.radius : collision.second.radius).to!string; //to!string(uniform(0.15, 0.25));
      particleValues["mass"] = uniform(0.02, 0.1).to!string;
      particleValues["lifetime"] = uniform(0.5, 2.0).to!string;
      //particleValues["collisionType"] = "Particle";
      
      //m_spawnParticleValues ~= particleValues;
      collisionHandler.addSpawnParticle(particleValues);
      
      collision.hasSpawnedParticles = true;
    }
    
    for (int i = 0; i < particles; i++)
    {
      string[string] particleValues;
      
      vec2 collisionVelocity = (collision.first.velocity.length > collision.second.velocity.length ? collision.first.velocity : collision.second.velocity) * 
                               -0.5 + rotation(uniform(-PI, PI)) * vec2(0.0, 1.0) * 3.0;
      
      particleValues["position"] = collisionPosition.to!string;
      particleValues["angle"] = to!string(atan2(collisionVelocity.x, collisionVelocity.y) * _180_PI);
      particleValues["velocity"] = collisionVelocity.to!string;
      particleValues["drawsource"] = "Quad";
      particleValues["vertices"] = to!string(["0.0 0.25 1.0 1.0 1.0 0.0", 
                                              "-0.05 0.0 1.0 1.0 0.5 0.5", 
                                              "0.0 -0.25 1.0 1.0 0.0 0.0",
                                              "0.05 0.0 1.0 1.0 0.5 0.5"]);
      particleValues["radius"] = ((collision.first.collisionType == CollisionType.Bullet) ? collision.first.radius : collision.second.radius).to!string; //to!string(uniform(0.15, 0.25));
      particleValues["mass"] = to!string(uniform(0.02, 0.1));
      particleValues["lifetime"] = to!string(uniform(0.5, 2.0));
      //particleValues["collisionType"] = "Particle";
      
      //m_spawnParticleValues ~= particleValues;
      collisionHandler.addSpawnParticle(particleValues);
      
      collision.hasSpawnedParticles = true;
    }
    
    string[string] collisionSound;
    
    collisionSound["soundFile"] = "collision1.wav";
    collisionSound["position"] = collisionPosition.to!string;
    collisionSound["velocity"] = ((collision.first.velocity * collision.first.radius + collision.second.velocity * collision.second.radius) * (1.0/(collision.first.radius + collision.second.radius))).to!string;
    
    //m_spawnParticleValues ~= collisionSound;
    collisionHandler.addSpawnParticle(collisionSound);
  }
}
