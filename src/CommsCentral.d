﻿/*
 Copyright (c) 2011 Ola Østtveit

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

module CommsCentral;

import std.conv;
import std.exception;
import std.stdio;

import gl3n.linalg;
import SubSystem.Base;
import SubSystem.Physics;
import SubSystem.Graphics;
import SubSystem.Placer;
import SubSystem.Controller;
import SubSystem.ConnectionHandler;
import SubSystem.CollisionHandler;
import SubSystem.Sound;
import SubSystem.Spawner;
import SubSystem.Timer;


unittest
{
  auto placer = new Placer();
  auto physics = new Physics();
  
  Entity entity = new Entity(["position":"1 2", "mass":"1"]);
  
  placer.registerEntity(entity);
  physics.registerEntity(entity);
  
  assert(placer.hasComponent(entity));
  assert(physics.hasComponent(entity));
  
  auto placerComp = placer.getComponent(entity);
  placerComp.position = vec2(5, 6);
  
  placer.setComponent(entity, placerComp);
  
  assert(physics.getComponent(entity).position == vec2(1, 2), physics.getComponent(entity).position.toString());
  
  subSystemCommunication!(PlacerComponent, PhysicsComponent)(placer, physics, (PlacerComponent placeComp, PhysicsComponent physComp){ physComp.position = placeComp.position; return physComp; });
  
  assert(physics.getComponent(entity).position == vec2(5, 6), physics.getComponent(entity).position.toString());
}


void setPlacerFromPhysics(Physics physics, Placer placer)
{
  subSystemCommunication!(PhysicsComponent, PlacerComponent)(physics, placer, (PhysicsComponent physicsComponent, PlacerComponent placerComponent)
  {
    placerComponent.position = physicsComponent.position;
    placerComponent.velocity = physicsComponent.velocity;
    
    placerComponent.angle = physicsComponent.angle;
    placerComponent.rotation = physicsComponent.rotation;
    
    return placerComponent;
  });
}


void setGraphicsFromPlacer(Placer placer, Graphics graphics)
{
  subSystemCommunication!(PlacerComponent, GraphicsComponent)(placer, graphics, (PlacerComponent placerComponent, GraphicsComponent graphicsComponent)
  {
    assert(placerComponent.position.ok);
    assert(placerComponent.velocity.ok);
    
    graphicsComponent.position = placerComponent.position;
    graphicsComponent.velocity = placerComponent.velocity;
    
    graphicsComponent.angle = placerComponent.angle;
    graphicsComponent.rotation = placerComponent.rotation;
    
    //writeln("graphics from placer, pos is " ~ graphicsComponent.position.toString());
    
    return graphicsComponent;
  });
}

void setSoundFromPlacer(Placer placer, Sound sound)
{
  subSystemCommunication!(PlacerComponent, SoundComponent)(placer, sound, (PlacerComponent placerComponent, SoundComponent soundComponent)
  {
    assert(placerComponent.position.ok);
    assert(placerComponent.velocity.ok);
    
    soundComponent.position = placerComponent.position;
    soundComponent.velocity = placerComponent.velocity;
    
    soundComponent.angle = placerComponent.angle;
    //soundComponent.rotation = placerComponent.rotation;
    
    //writeln("sound from placer, pos is " ~ soundComponent.position.toString());
    
    return soundComponent;
  });
}

// update position of connected entities so they don't fly off on their own
void setPlacerFromConnector(ConnectionHandler connection, Placer placer)
{
  subSystemCommunication!(ConnectionComponent, PlacerComponent)(connection, placer, (ConnectionComponent connectionComponent, PlacerComponent placerComponent)
  {
    // we don't need to do anything for connection targets/owners
    //if (connectionComponent.owner == entity)
      //continue;
    
    //writeln("setting placercomp from connectioncomp with relative position " ~ to!string(connectionComponent.relativePosition) ~ " and owner " ~ to!string(connectionComponent.owner.id));
    
    assert(connectionComponent.relativePosition.ok);
    assert(connectionComponent.relativeAngle == connectionComponent.relativeAngle);
    
    //enforce(connectionComponent.owner !is null, "Owner entity was null for connection component with entity " ~ to!string(entity.id));
    assert(connectionComponent.owner !is null, "Owner entity was null for connection component");
    assert(placer.hasComponent(connectionComponent.owner), "owner entity " ~ to!string(connectionComponent.owner.id) ~ " did not have placer component");
    auto ownerComponent = placer.getComponent(connectionComponent.owner);
    
    // need to rotate around middle of mass point
    placerComponent.position = ownerComponent.position + mat2.rotation(-ownerComponent.angle) * connectionComponent.relativePositionToCenterOfMass;
    placerComponent.angle = ownerComponent.angle + connectionComponent.relativeAngle;
    
    placerComponent.velocity = ownerComponent.velocity;
    placerComponent.rotation = ownerComponent.rotation;
    
    //writeln("placer from connector, pos is " ~ placerComponent.position.toString());
    
    return placerComponent;
  });
}

void setConnectorFromPlacer(Placer placer, ConnectionHandler connection)
{
  subSystemCommunication!(PlacerComponent, ConnectionComponent)(placer, connection, (PlacerComponent placerComponent, ConnectionComponent connectionComponent)
  {
    connectionComponent.position = placerComponent.position;
    connectionComponent.angle = placerComponent.angle;
    
    return connectionComponent;
  });
}

// engines etc needs to transfer force and torque correctly to the owner ship entity
void setPhysicsFromConnector(ConnectionHandler connection, Physics physics)
{
  foreach (entity; connection.entities)
  {
    if (physics.hasComponent(entity) && connection.hasComponent(entity))
    {
      auto connectionComponent = connection.getComponent(entity);
      auto physicsComponent = physics.getComponent(entity);
      
      // we don't need to do anything for connection targets
      if (connectionComponent.owner == entity)
        continue;
      
      assert(connectionComponent.relativePosition.ok);
      assert(connectionComponent.relativeAngle == connectionComponent.relativeAngle);
      
      enforce(connectionComponent.owner !is null, "Owner entity was null for connection component with entity " ~ to!string(entity.id));      
      enforce(physics.hasComponent(connectionComponent.owner), "owner entity " ~ to!string(connectionComponent.owner.id) ~ " did not have physics component");
      auto ownerComponent = physics.getComponent(connectionComponent.owner);
      
      //ownerComponent.force += physicsComponent.force.rotate(ownerComponent.angle);
      ownerComponent.force += mat2.rotation(-ownerComponent.angle) * physicsComponent.force;
      ownerComponent.impulse += physicsComponent.impulse;
      ownerComponent.angularImpulse += physicsComponent.angularImpulse;
      ownerComponent.torque += physicsComponent.torque;
      
      physics.setComponent(connectionComponent.owner, ownerComponent);
    }
  }
}


// controllers can add forces, for example engine exhaust or gun recoil
void setPhysicsFromController(Controller controller, Physics physics)
{
  subSystemCommunication!(ControlComponent, PhysicsComponent)(controller, physics, (ControlComponent controllerComponent, PhysicsComponent physicsComponent)
  {
    physicsComponent.force += controllerComponent.force;
    physicsComponent.torque += controllerComponent.torque;
    
    physicsComponent.impulse += controllerComponent.impulse;
    physicsComponent.angularImpulse += controllerComponent.angularImpulse;
    
    return physicsComponent;
  });
}

// controllers often need to know where they are, especially AI controllers
void setControllerFromPlacer(Placer placer, Controller controller)
{
  subSystemCommunication!(PlacerComponent, ControlComponent)(placer, controller, (PlacerComponent placerComponent, ControlComponent controllerComponent)
  {
    controllerComponent.position = placerComponent.position;
    controllerComponent.velocity = placerComponent.velocity;
    controllerComponent.angle = placerComponent.angle;
    controllerComponent.rotation = placerComponent.rotation;
    
    return controllerComponent;
  });
}

// collider components must know their position to know if they're colliding with something
void setCollidersFromPlacer(Placer placer, CollisionHandler collisionHandler)
{
  subSystemCommunication!(PlacerComponent, ColliderComponent)(placer, collisionHandler, (PlacerComponent placerComponent, ColliderComponent colliderComponent)
  {
    colliderComponent.position = placerComponent.position;
    colliderComponent.velocity = placerComponent.velocity;
    //ColliderComponent.angle = placerComponent.angle;
    
    return colliderComponent;
  });
}


void calculateCollisionResponse(CollisionHandler collisionHandler, Physics physics)
{
  Entity[int] colliderToEntities;
  
  foreach (entity; collisionHandler.entities)
  {
    if (collisionHandler.hasComponent(entity))
    {
      //writeln("entity " ~ to!string(entity.id) ~ " has collision component " ~ to!string(collisionHandler.getComponent(entity).id));
      colliderToEntities[collisionHandler.getComponent(entity).id] = entity;
    }
  }

  //writeln("collidertoentities: " ~ to!string(colliderToEntities.length));
  
  foreach (collision; collisionHandler.collisions)
  {
    //writeln("checking collision between collisioncomponent " ~ to!string(collision.first.id) ~ " and " ~ to!string(collision.second.id));
    auto firstEntity = colliderToEntities[collision.first.id];
    auto secondEntity = colliderToEntities[collision.second.id];
    
    // this physics component might have collided with a non-physics component, i.e. ship moving over and lighting up something in the background or the hud, like a targeting reticle 
    // we only do something physical with the collision if both collision components have corresponding physics components
    if (physics.hasComponent(firstEntity) && physics.hasComponent(secondEntity))
    {
      auto firstPhysicsComponent = physics.getComponent(firstEntity);
      auto secondPhysicsComponent = physics.getComponent(secondEntity);
      
      // determine collision force
      float collisionForce = (firstPhysicsComponent.velocity * firstPhysicsComponent.mass + secondPhysicsComponent.velocity * secondPhysicsComponent.mass).length;

      // give a kick from the contactpoint
      firstPhysicsComponent.force = firstPhysicsComponent.force + (collision.contactPoint.normalized() * -collisionForce);
      secondPhysicsComponent.force = secondPhysicsComponent.force + (collision.contactPoint.normalized() * collisionForce);
      
      physics.setComponent(firstEntity, firstPhysicsComponent);
      physics.setComponent(secondEntity, secondPhysicsComponent);
    }
  }
}

void setSpawnerFromController(Controller controller, Spawner spawner)
{
  subSystemCommunication!(ControlComponent, SpawnerComponent)(controller, spawner, (ControlComponent controllerComponent, SpawnerComponent spawnerComponent)
  {
    spawnerComponent.startSpawning = (spawnerComponent.isSpawning == false && 
                                      controllerComponent.isFiring && 
                                      spawnerComponent.startSpawning == false);
      
    spawnerComponent.isSpawning = controllerComponent.isFiring;
    
    spawnerComponent.stopSpawning = (spawnerComponent.isSpawning && 
                                     controllerComponent.isFiring == false && 
                                     spawnerComponent.stopSpawning == false);
    
    return spawnerComponent;
  });
}


void setSpawnerFromPlacer(Placer placer, Spawner spawner)
{
  subSystemCommunication!(PlacerComponent, SpawnerComponent)(placer, spawner, (PlacerComponent placerComponent, SpawnerComponent spawnerComponent)
  {
    spawnerComponent.position = placerComponent.position;
    spawnerComponent.velocity = placerComponent.velocity;
    spawnerComponent.angle = placerComponent.angle;
    
    //writeln("setspawnerfromplacer, pos is " ~ to!string(spawnerComponent.pos));
    
    return spawnerComponent;
  });
}


void setSpawnerFromPhysics(Physics physics, Spawner spawner)
{
  subSystemCommunication!(PhysicsComponent, SpawnerComponent)(physics, spawner, (PhysicsComponent physicsComponent, SpawnerComponent spawnerComponent)
  {
    spawnerComponent.force = physicsComponent.force;
    //spawnerComponent.velocity = physicsComponent.velocity;
    spawnerComponent.torque = physicsComponent.torque;
    
    return spawnerComponent;
  });
}

void setPhysicsFromSpawner(Spawner spawner, Physics physics)
{
  subSystemCommunication!(SpawnerComponent, PhysicsComponent)(spawner, physics, (SpawnerComponent spawnerComponent, PhysicsComponent physicsComponent)
  {
    physicsComponent.force = spawnerComponent.force;
    //spawnerComponent.velocity = placerComponent.velocity;
    
    physicsComponent.torque = spawnerComponent.torque;
    
    return physicsComponent;
  });
}

void setSoundFromSpawner(Spawner spawner, Sound sound)
{
  subSystemCommunication!(SpawnerComponent, SoundComponent)(spawner, sound, (SpawnerComponent spawnerComponent, SoundComponent soundComponent)
  {
    if (spawnerComponent.stopSpawning)
      soundComponent.repeat = false;
    
    return soundComponent;
  });
}