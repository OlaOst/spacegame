module CommsCentral;

import std.conv;
import std.exception;
import std.stdio;

import common.Vector;
import SubSystem.Base;
import SubSystem.Physics;
import SubSystem.Graphics;
import SubSystem.Placer;
import SubSystem.Controller;
import SubSystem.ConnectionHandler;
import SubSystem.CollisionHandler;
import SubSystem.Spawner;


void setPlacerFromPhysics(Physics physics, Placer placer)
{
  foreach (entity; physics.entities)
  {
    if (placer.hasComponent(entity) && physics.hasComponent(entity))
    {
      auto physicsComponent = physics.getComponent(entity);
      auto placeComponent = placer.getComponent(entity);
      
      placeComponent.position = physicsComponent.position;
      placeComponent.velocity = physicsComponent.velocity;
      
      placeComponent.angle = physicsComponent.angle;
      placeComponent.rotation = physicsComponent.rotation;
      
      placer.setComponent(entity, placeComponent);
    }
  }
}


void setGraphicsFromPlacer(Placer placer, Graphics graphics)
{
  foreach (entity; graphics.entities)
  {
    if (graphics.hasComponent(entity) && placer.hasComponent(entity))
    {
      auto placerComponent = placer.getComponent(entity);
      auto graphicsComponent = graphics.getComponent(entity);
      
      assert(placerComponent.position.isValid());
      assert(placerComponent.velocity.isValid());
      
      graphicsComponent.position = placerComponent.position;
      graphicsComponent.velocity = placerComponent.velocity;
      
      graphicsComponent.angle = placerComponent.angle;
      graphicsComponent.rotation = placerComponent.rotation;
      
      graphics.setComponent(entity, graphicsComponent);
    }
  }
}

// update position of connected entities so they don't fly off on their own
void setPlacerFromConnector(ConnectionHandler connection, Placer placer)
{
  foreach (entity; connection.entities)
  {
    if (placer.hasComponent(entity) && connection.hasComponent(entity))
    {
      auto connectionComponent = connection.getComponent(entity);
      auto placerComponent = placer.getComponent(entity);
      
      // we don't need to do anything for connection targets/owners
      if (connectionComponent.owner == entity)
        continue;
      
      assert(connectionComponent.relativePosition.isValid());
      assert(connectionComponent.relativeAngle == connectionComponent.relativeAngle);
      
      enforce(connectionComponent.owner !is null, "Owner entity was null for connection component with entity " ~ to!string(entity.id));      
      enforce(placer.hasComponent(connectionComponent.owner), "owner entity " ~ to!string(connectionComponent.owner.id) ~ " did not have placer component");
      auto ownerComponent = placer.getComponent(connectionComponent.owner);
      
      //placerComponent.position = Vector.fromAngle(ownerComponent.angle + connectionComponent.relativePosition.) * connectionComponent.relativePosition.length2d();
      placerComponent.position = ownerComponent.position + connectionComponent.relativePosition.rotate(ownerComponent.angle);
      placerComponent.angle = ownerComponent.angle + connectionComponent.relativeAngle;
      
      placerComponent.velocity = ownerComponent.velocity;
      
      placer.setComponent(entity, placerComponent);
    }
  }
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
      
      assert(connectionComponent.relativePosition.isValid());
      assert(connectionComponent.relativeAngle == connectionComponent.relativeAngle);
      
      enforce(connectionComponent.owner !is null, "Owner entity was null for connection component with entity " ~ to!string(entity.id));      
      enforce(physics.hasComponent(connectionComponent.owner), "owner entity " ~ to!string(connectionComponent.owner.id) ~ " did not have physics component");
      auto ownerComponent = physics.getComponent(connectionComponent.owner);
      
      ownerComponent.force += physicsComponent.force.rotate(ownerComponent.angle);
      ownerComponent.torque += physicsComponent.torque;
      
      physics.setComponent(connectionComponent.owner, ownerComponent);
    }
  }
}

// controllers can add forces, for example engine exhaust or gun recoil
void setPhysicsFromController(Controller controller, Physics physics)
{
  foreach (entity; controller.entities)
  {
    if (physics.hasComponent(entity) && controller.hasComponent(entity))
    {
      auto controllerComponent = controller.getComponent(entity);
      auto physicsComponent = physics.getComponent(entity);
      
      physicsComponent.force += controllerComponent.force;
      physicsComponent.torque += controllerComponent.torque;
      
      physics.setComponent(entity, physicsComponent);
    }
  }
}

// controllers often need to know where they are, especially AI controllers
void setControllerFromPlacer(Placer placer, Controller controller)
{
  foreach (entity; controller.entities)
  {
    if (controller.hasComponent(entity) && placer.hasComponent(entity))
    {
      auto placerComponent = placer.getComponent(entity);
      auto controllerComponent = controller.getComponent(entity);
      
      controllerComponent.position = placerComponent.position;
      controllerComponent.angle = placerComponent.angle;
      
      controller.setComponent(entity, controllerComponent);
    }
  }
}

// collider components must know their position to know if they're colliding with something
void setCollidersFromPlacer(Placer placer, CollisionHandler collisionHandler)
{
  foreach (entity; collisionHandler.entities)
  {
    if (collisionHandler.hasComponent(entity) && placer.hasComponent(entity))
    {
      auto placerComponent = placer.getComponent(entity);
      auto colliderComponent = collisionHandler.getComponent(entity);
      
      colliderComponent.position = placerComponent.position;
      //ColliderComponent.angle = placerComponent.angle;
      
      collisionHandler.setComponent(entity, colliderComponent);
    }
  }
}


void calculateCollisionResponse(CollisionHandler collisionHandler, Physics physics)
{
  Entity[ColliderComponent] colliderToEntities;
  
  foreach (entity; collisionHandler.entities)
  {
    if (collisionHandler.hasComponent(entity))
    {
      colliderToEntities[collisionHandler.getComponent(entity)] = entity;
    }
  }

  foreach (collision; collisionHandler.collisions)
  {
    auto firstEntity = colliderToEntities[collision.first];
    auto secondEntity = colliderToEntities[collision.second];
    
    // this physics component might have collided with a non-physics component, i.e. ship moving over and lighting up something in the background or the hud, like a targeting reticle 
    // we only do something physical with the collision if both collision components have corresponding physics components
    if (physics.hasComponent(firstEntity) && physics.hasComponent(secondEntity))
    {
      auto firstPhysicsComponent = physics.getComponent(firstEntity);
      auto secondPhysicsComponent = physics.getComponent(secondEntity);
      
      // determine collision force
      float collisionForce = (firstPhysicsComponent.velocity * firstPhysicsComponent.mass + secondPhysicsComponent.velocity * secondPhysicsComponent.mass).length2d;

      // give a kick from the contactpoint
      firstPhysicsComponent.force = firstPhysicsComponent.force + (collision.contactPoint.normalized() * -collisionForce);
      secondPhysicsComponent.force = secondPhysicsComponent.force + (collision.contactPoint.normalized() * collisionForce);
      
      physics.setComponent(firstEntity, firstPhysicsComponent);
      physics.setComponent(secondEntity, secondPhysicsComponent);
      
    }
    
    // reduce health for certain collisiontypes (should only be done if entity has component in HealthHandler or something - HealthHandler is not implemented yet
    /*if (self.collisionType == CollisionType.NpcShip && other.collisionType == CollisionType.Bullet)
    {
      debug write("reducing npc ship health from " ~ to!string(self.entity.health) ~ " to ");
      // TODO: don't substract health, instead add damage with decals and effects
      self.entity.health -= otherPhysicsComponent.mass * (other.entity.velocity.length2d() - self.entity.velocity.length2d());
      debug writeln(to!string(self.entity.health));
    }*/    
  }
}

void setSpawnerFromController(Controller controller, Spawner spawner)
{
  foreach (entity; spawner.entities)
  {
    if (controller.hasComponent(entity) && spawner.hasComponent(entity))
    {
      auto controllerComponent = controller.getComponent(entity);
      auto spawnerComponent = spawner.getComponent(entity);
      
      spawnerComponent.isSpawning = controllerComponent.isFiring;
      
      spawner.setComponent(entity, spawnerComponent);
    }
  }
}


void setSpawnerFromPlacer(Placer placer, Spawner spawner)
{
  foreach (entity; spawner.entities)
  {
    if (placer.hasComponent(entity) && spawner.hasComponent(entity))
    {
      auto placerComponent = placer.getComponent(entity);
      auto spawnerComponent = spawner.getComponent(entity);
      
      spawnerComponent.position = placerComponent.position;
      spawnerComponent.velocity = placerComponent.velocity;
      spawnerComponent.angle = placerComponent.angle;
      
      spawner.setComponent(entity, spawnerComponent);
    }
  }
}