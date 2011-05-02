module CommsCentral;

import std.conv;
import std.stdio;

import SubSystem.Base;
import SubSystem.Physics;
import SubSystem.Graphics;
import SubSystem.Placer;
import SubSystem.Controller;


void mover(Physics physics, Placer placer)
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


void drawer(Placer placer, Graphics graphics)
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

void controller(Controller controller, Physics physics)
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
