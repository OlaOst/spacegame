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
  foreach (entity; placer.entities)
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

void setPlacerFromConnector(ConnectionHandler connection, Placer placer)
{
  foreach (entity; connection.entities)
  {
    if (placer.hasComponent(entity) && connection.hasComponent(entity))
    {
      auto connectionComponent = connection.getComponent(entity);
      auto placerComponent = placer.getComponent(entity);
      
      // we don't need to do anything for connection targets
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
