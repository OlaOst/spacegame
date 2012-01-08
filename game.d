/*
 Copyright (c) 2010 Ola Østtveit

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

module Game;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.exception;
import std.math;
import std.parallelism;
import std.random;
import std.stdio;
import std.string;

import derelict.sdl.sdl;

import gl3n.linalg;
import gl3n.math;

import SubSystem.CollisionHandler;
import SubSystem.ConnectionHandler;
import SubSystem.Controller;
import SubSystem.Graphics;
import SubSystem.Physics;
import SubSystem.Placer;
import SubSystem.Sound;
import SubSystem.Spawner;

import AiChaser;
import AiGunner;
import CommsCentral;
import Entity;
import EntityLoader;
import FlockControl;
import InputHandler;
import Starfield;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Game game = new Game();
  
  // TODO: assert that Derelict SDL and GL loaded OK
  
  assert(game.updateCount == 0);
  {
    game.update();
  }  
  assert(game.updateCount == 1);
  
  Entity testPhysics = new Entity(["position":"1 0", "mass":"1.0"]);
  
  game.registerEntity(testPhysics);
  assert(game.m_placer.hasComponent(testPhysics));
  assert(game.m_physics.hasComponent(testPhysics));
  assert(game.m_graphics.hasComponent(testPhysics) == false);
  
  game.m_physics.getComponent(testPhysics).force = vec2(0.0, 1.0);
  
  assert(game.m_physics.getComponent(testPhysics).force == vec2(0.0, 1.0));
  
  game.m_physics.setTimeStep(0.1);
  game.m_controller.setTimeStep(0.1);
  foreach (subSystem; game.m_subSystems)
    subSystem.update();
    
  assert(game.m_physics.getComponent(testPhysics).position.y > 0.0);
  
  setPlacerFromPhysics(game.m_physics, game.m_placer);
  
  assert(game.m_placer.getComponent(testPhysics).position == game.m_physics.getComponent(testPhysics).position);
  
  
  Entity testGraphics = new Entity(["position":"0 1", "drawsource":"Star"]);
  
  game.registerEntity(testGraphics);
  assert(game.m_graphics.hasComponent(testGraphics));
  assert(game.m_placer.hasComponent(testGraphics));
  assert(game.m_physics.hasComponent(testGraphics) == false);

  setGraphicsFromPlacer(game.m_placer, game.m_graphics);
  
  assert(game.m_graphics.getComponent(testGraphics).position == game.m_placer.getComponent(testGraphics).position);
  
  
  Entity testController = new Entity(["mass":"2.0","control":"chaser"]);
  
  game.registerEntity(testController);
  assert(game.m_physics.hasComponent(testController));
  assert(game.m_controller.hasComponent(testController)); 
  
  game.m_controller.getComponent(testController).control = 
      new class () Control 
      {
        override void update(ref ControlComponent p_sourceComponent) 
        {
          p_sourceComponent.force = vec2(1.0, 1.0);
        }
      };
  
  assert(game.m_controller.getComponent(testController).control !is null);
  
  foreach (subSystem; game.m_subSystems)
    subSystem.update();
    
  assert(game.m_controller.getComponent(testController).force.length > 0.0);
}


class Game
{
invariant()
{

}


public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    m_paused = false;
    
    m_inputHandler = new InputHandler();
    
    int xres = 1024;
    int yres = 768;
    
    m_subSystems["placer"] = m_placer = new Placer();
    m_subSystems["graphics"] = m_graphics = new Graphics(cache, xres, yres);
    m_subSystems["physics"] = m_physics = new Physics();
    m_subSystems["controller"] = m_controller = new Controller(m_inputHandler);
    m_subSystems["collider"] = m_collider = new CollisionHandler();
    m_subSystems["connector"] = m_connector = new ConnectionHandler();
    m_subSystems["sound"] = new SoundSubSystem(16);    
    m_subSystems["spawner"] = m_spawner = new Spawner();

    assert(m_controller !is null);
    
    m_controller.aiControls["aigunner"] = m_aiGunner = new AiGunner();
    m_controller.aiControls["chaser"] = m_aiChaser = new AiChaser();
    
    //loadWorldFromFile("data/simpleworld.txt");
    loadWorldFromFile("data/world.txt");
    
    //m_starfield = new Starfield(m_graphics, 10.0);

    m_inputHandler.setScreenResolution(xres, yres);
  }
 
 
  void loadWorldFromFile(string p_fileName)
  {
    Entity worldEntity = new Entity(loadValues(cache, p_fileName));

    string[] orderedEntityNames;
    
    auto file = File(p_fileName);
    foreach (string line; lines(file))
    {
      if (line.strip.length > 0 && line.strip.startsWith("#") == false)
        if (orderedEntityNames.find(line.strip.split(".")[0]) == [])
          orderedEntityNames ~= line.strip.split(".")[0];
    }
    
    string[string][string] spawnNameWithValues;
    
    foreach (key; worldEntity.values.keys)
    {
      auto sourceAndKey = key.split(".");
      
      if (sourceAndKey.length >= 2)
      {
        auto sourceName = sourceAndKey[0];
        auto sourceKey = join(sourceAndKey[1..$], ".");
        
        spawnNameWithValues[sourceName][sourceKey] = worldEntity.getValue(key);
      }
    }
    
    foreach (orderedEntityName; orderedEntityNames)
    {
      auto spawnName = orderedEntityName;
      
      int spawnCount = 1;
      if ("spawnCount" in spawnNameWithValues[spawnName])
        spawnCount = to!int(spawnNameWithValues[spawnName]["spawnCount"]);

      for (int count = 0; count < spawnCount; count++)
      {
        auto extraValues = spawnNameWithValues[spawnName].dup;
        
        extraValues = parseRandomizedValues(extraValues);      
        
        Entity spawn;

        spawn = loadShip(worldEntity.getValue(spawnName ~ ".source"), extraValues);
        
        if (spawn.getValue("name") == "FPS display")
          m_fpsDisplay = spawn;
          
        if (spawn.getValue("name") == "trashbin")
          m_trashBin = spawn;
        
        if (spawn.getValue("name") == "playership")
          m_playerShip = spawn;
          
        if (spawn.getValue("name") == "Closest ship display")
          m_closestShipDisplay = spawn;
      }
    }
  }
 
 
  void run()
  {
    m_timer.reset();
    m_timer.start();
    m_timer.stop();
  
    while (m_running)
    {
      update();
    }
  }
  
  
private:
  int updateCount()
  {
    return m_updateCount;
  }
  
  
  void update()
  {
    m_timer.stop();
    
    float elapsedTime = m_timer.peek.msecs * 0.001;
    
    if (elapsedTime <= 0)
      elapsedTime = 0.001;
    
    m_timer.reset();
    m_timer.start();
    
    m_updateCount++;
    
    Entity[] entitiesToRemove;
    
    foreach (entity; m_entities)
    {
      // TODO: make subsystem dedicated to removing entities. it should be responsible for values like lifetime and health 
      // TODO: ideally all this code should be handled by just setting values on the entity and then re-register it
      if (m_collider.hasComponent(entity))
      {
        auto colliderComponent = m_collider.getComponent(entity);
        
        colliderComponent.lifetime -= elapsedTime;
        
        if (colliderComponent.lifetime <= 0.0)
          entitiesToRemove ~= entity;
          
        // disconnect if no health left
        if (colliderComponent.health <= 0.0)
        {
          writeln("no health left, disconnecting entity " ~ to!string(entity.id) ~ " named " ~ entity.getValue("name"));
          
          // de-control entity and all connected entities
          entity.setValue("control", "nothing");
          entity.setValue("collisionType", "FreeFloatingModule");
          entity.setValue("position", m_placer.getComponent(entity).position.toString());
          entity.setValue("angle", to!string(m_placer.getComponent(entity).angle));
          entity.setValue("velocity", vec2(0.0, 0.0).toString());
          entity.setValue("force", vec2(0.0, 0.0).toString());
          
          m_controller.removeEntity(entity);
          m_collider.registerEntity(entity);
          
          foreach (connectedEntity; m_connector.getConnectedEntities(entity))
          {
            connectedEntity.setValue("control", "nothing");
            connectedEntity.setValue("collisionType", "FreeFloatingModule");
            connectedEntity.setValue("owner", to!string(connectedEntity.id));
            m_controller.removeEntity(connectedEntity);
            m_connector.removeEntity(connectedEntity);
            m_collider.registerEntity(connectedEntity);
            
            if (m_collider.hasComponent(connectedEntity))
            {
              auto connectedColliderComponent = m_collider.getComponent(connectedEntity);
              connectedColliderComponent.health = to!float(connectedEntity.getValue("health"));
              
              if (m_physics.hasComponent(connectedEntity))
              {
                auto connectedPhysComp = m_physics.getComponent(connectedEntity);
                connectedPhysComp.position = connectedColliderComponent.position;
                connectedPhysComp.force = vec2(0.0, 0.0);
                
                m_physics.setComponent(connectedEntity, connectedPhysComp);
              }
            }
          }
        
          // TODO: figure out why entity is getting reconnected later on
          entity.setValue("owner", to!string(entity.id));
          m_connector.removeEntity(entity);
          
          writeln("disconnecting entity " ~ to!string(entity.id) ~ " with position " ~ colliderComponent.position.toString());
          colliderComponent.health = to!float(entity.getValue("health"));
          
          assert(m_connector.hasComponent(entity) == false);
          
          if (m_physics.hasComponent(entity))
          {
            auto physComp = m_physics.getComponent(entity);
            physComp.position = colliderComponent.position;
            physComp.force = vec2(0.0, 0.0);
            
            m_physics.setComponent(entity, physComp);
          }
        }
      }
    }
    
    foreach (entityToRemove; entitiesToRemove)
      removeEntity(entityToRemove);
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      assert(elapsedTime > 0.0);
      m_physics.setTimeStep(elapsedTime);
      m_controller.setTimeStep(elapsedTime);
      
      CommsCentral.setPlacerFromPhysics(m_physics, m_placer);
      CommsCentral.setPlacerFromConnector(m_connector, m_placer);
      
      // this block should be handled in DragDropHandler
      if (m_dragEntity !is null)
      {
        assert(m_placer.hasComponent(m_dragEntity));
        
        if (m_placer.hasComponent(m_dragEntity))
        {
          auto dragPosComp = m_placer.getComponent(m_dragEntity);
          dragPosComp.position = m_graphics.mouseWorldPos;
          
          m_placer.setComponent(m_dragEntity, dragPosComp);
        }
      }
      
      CommsCentral.setPhysicsFromController(m_controller, m_physics);
      CommsCentral.setSpawnerFromController(m_controller, m_spawner);
      
      CommsCentral.setPhysicsFromConnector(m_connector, m_physics);
      CommsCentral.setPhysicsFromSpawner(m_spawner, m_physics);
      
      updateSubSystems();
      
      CommsCentral.setControllerFromPlacer(m_placer, m_controller);
      CommsCentral.setCollidersFromPlacer(m_placer, m_collider);
      CommsCentral.setSpawnerFromPlacer(m_placer, m_spawner);
      CommsCentral.setConnectorFromPlacer(m_placer, m_connector);
      
      //CommsCentral.calculateCollisionResponse(m_collider, m_physics);
    }
    CommsCentral.setGraphicsFromPlacer(m_placer, m_graphics);
    
    m_fpsBuffer[m_updateCount % m_fpsBuffer.length] = floor(1.0 / elapsedTime);
    
    if (m_graphics.hasComponent(m_fpsDisplay))
    {
      auto fpsDisplayComponent = m_graphics.getComponent(m_fpsDisplay);
      
      int fpsValue = cast(int)(reduce!"a+b"(m_fpsBuffer)/m_fpsBuffer.length);
      
      if (fpsValue < 0)
        fpsDisplayComponent.text = "FPS: ??";
      else
        fpsDisplayComponent.text = "FPS: " ~ to!string(fpsValue);
        
      m_graphics.setComponent(m_fpsDisplay, fpsDisplayComponent);
    }
    
    if (m_graphics.hasComponent(m_closestShipDisplay))
    {
      if (m_playerShip !is null)
      {
        auto playerPos = m_placer.getComponent(m_playerShip).position;        

        auto closestEntity = findClosestEnemyShip(m_playerShip);
        
        if (closestEntity !is null)
        {
          auto closestEntityPosition = m_placer.getComponent(closestEntity).position - playerPos;
          auto closestEntityDistance = closestEntityPosition.length;
          
          auto closestShipDisplayComponent = m_graphics.getComponent(m_closestShipDisplay);
          
          m_closestShipDisplay.setValue("position", (closestEntityPosition.normalized() * 0.9).toString());
          m_closestShipDisplay.setValue("text", to!string(floor(closestEntityDistance)));
          m_closestShipDisplay.setValue("color", "1 0 0");
          
          registerEntity(m_closestShipDisplay);
        }
      }
    }
    
    m_graphics.calculateMouseWorldPos(m_inputHandler.mousePos);
    
    foreach (spawnValues; m_spawner.getAndClearSpawnValues())
    {
      assert("source" in spawnValues, to!string(spawnValues));
      
      loadShip(spawnValues["source"], spawnValues);
    }
    
    // update target values for control components
    foreach (entity; m_entities)
    {
      if (m_controller.hasComponent(entity))
      {
        auto controlComponent = m_controller.getComponent(entity);
        
        if (controlComponent.target == "closestEnemy")
        {
          auto closestEnemy = findClosestEnemyShip(entity);
          
          if (closestEnemy !is null)
          {
            auto closestEnemyComponent = m_placer.getComponent(closestEnemy);
            
            controlComponent.targetPosition = closestEnemyComponent.position;
            controlComponent.targetVelocity = closestEnemyComponent.velocity;
          }
        }
        else if (controlComponent.target == "player")
        {
          if (m_playerShip !is null)
          {
            controlComponent.targetPosition = m_placer.getComponent(m_playerShip).position;
            controlComponent.targetVelocity = m_placer.getComponent(m_playerShip).velocity;
          }
        }
      }
    }
    
    handleInput(elapsedTime);
    
    SDL_Delay(10);
  }
  
  
  void handleInput(float p_elapsedTime)
  {
    if (m_inputHandler.isPressed(Event.LeftButton))
    {
      // TODO: if we have a dragentity we must ensure it stops getting dragged before it's destroyed or removed by something - lifetime expiration for bullets for example
      if (m_dragEntity is null)
      {
        foreach (draggable; filter!((Entity entity) { return entity.getValue("draggable") == "true" && m_graphics.hasComponent(entity); })(m_entities.values))
        {
          assert(m_graphics.hasComponent(draggable), "Couldn't find graphics component for draggable entity " ~ to!string(draggable.values) ~ " with id " ~ to!string(draggable.id));
          
          auto dragGfxComp = m_graphics.getComponent(draggable);
          
          // screenAbsolutePosition is true for GUI and screen elements - we don't want to drag them
          if (dragGfxComp.screenAbsolutePosition)
            continue;
          
          if ((dragGfxComp.position - m_graphics.mouseWorldPos).length < dragGfxComp.radius)
          {
            // we don't want to drag something if it has stuff connected to it, or owns something. 
            // if you want to drag a skeleton module, you should drag off all connected modules first
            // TODO: should be possible to drag stuff with connected stuff, but drag'n'drop needs to be more robust first            
            if (m_connector.getConnectedEntities(draggable).length > 0 || m_connector.getOwnedEntities(draggable).length > 0)
              continue;

            m_dragEntity = draggable;
            
            break;
          }
        }

        if (m_dragEntity !is null)
        {
          // create copy of drag entity if it's a blueprint
          if (m_dragEntity.getValue("isBlueprint") == "true")
          {
            writeln("creating copy of blueprint entity " ~ m_dragEntity.getValue("name"));
            
            m_dragEntity = m_dragEntity.dup; //new Entity(getValues(cache, m_dragEntity.values));
            m_dragEntity.setValue("isBlueprint", "false");
            //m_dragEntity.setValue("name", m_dragEntity.getValue("source") ~ ":" ~ to!string(m_dragEntity.id));
            
            registerEntity(m_dragEntity);
          }
          
          if (m_connector.hasComponent(m_dragEntity))
          {
            auto ownerEntity = m_connector.getComponent(m_dragEntity).owner;

            // TODO: disconnectEntity sets the component owner to itself - might cause trouble if we assume it has a separate owner entity when floating around on its own
            m_connector.disconnectEntity(m_dragEntity);
            
            updateOwnerEntity(ownerEntity);
            
            // double check connect point for disconnection
            debug
            {
              assert(m_connector.hasComponent(m_dragEntity));
              
              if (m_dragEntity.getValue("connection").length > 0)
              {
                auto dragEntityConnection = extractEntityIdAndConnectPointName(m_dragEntity.getValue("connection"));
                
                Entity connectEntity;
                foreach (entity; m_entities)
                {
                  if (entity.id == to!int(dragEntityConnection[0]))
                  {
                    connectEntity = entity;
                    break;
                  }
                }
                
                assert(connectEntity !is null);
                assert(m_connector.hasComponent(connectEntity), "expected connection comp of entity with values " ~ to!string(connectEntity.values));
                auto comp = m_connector.getComponent(connectEntity);
                
                assert(dragEntityConnection[1] in comp.connectPoints, "Couldn't find connectpoint " ~ dragEntityConnection[1] ~ " in component whose entity has values " ~ to!string(connectEntity.values));
                assert(comp.connectPoints[dragEntityConnection[1]].connectedEntity is null, "Disconnected connectpoint still not empty: " ~ to!string(comp.connectPoints[dragEntityConnection[1]]));
              }
            }
            
            m_dragEntity.values.remove("connection");  
          }
          
          // we don't want dragged entities to be controlled
          if (m_controller.hasComponent(m_dragEntity) && m_dragEntity.getValue("control").length > 0)
          {
            m_dragEntity.setValue("control", "nothing");
            
            m_controller.removeEntity(m_dragEntity);
            
            assert(m_controller.hasComponent(m_dragEntity) == false);
          }
              
          // TODO: reset physics forces, velocity and other stuff?
        }
      }
    }
    
    if (m_inputHandler.eventState(Event.LeftButton) == EventState.Released)
    {
      if (m_dragEntity !is null)
      {
        assert(m_placer.hasComponent(m_dragEntity));
        auto dragPos = m_placer.getComponent(m_dragEntity).position;
        
        assert(m_placer.hasComponent(m_trashBin));
        auto trashBinPos = m_placer.getComponent(m_trashBin).position;
        
        assert(m_dragEntity.getValue("radius").length > 0, "Couldn't find radius for drag entity " ~ m_dragEntity.getValue("name"));
        
        // trash entities dropped in the trashbin, but don't trash the trashbin...
        if (m_dragEntity != m_trashBin && (dragPos - trashBinPos).length < to!float(m_trashBin.getValue("radius")))
        {
          removeEntity(m_dragEntity);
        }
        else
        {
          // if drag entity is close to an empty skeleton contact point then connect to it
          auto overlappingEmptyConnectPointsWithPosition = m_connector.findOverlappingEmptyConnectPointsWithPosition(m_dragEntity, dragPos);
        
          ConnectPoint closestConnectPoint;
          auto closestPosition = vec2(float.infinity, float.infinity);
        
          // connect to the closest one
          foreach (ConnectPoint connectPoint, vec2 position; overlappingEmptyConnectPointsWithPosition)
          {
            if (position.length < closestPosition.length)
            {
              closestConnectPoint = connectPoint;
              closestPosition = position;
            }
          }
          
          if (closestPosition.length < float.infinity)
          {
            assert(closestConnectPoint.owner !is null);
            assert(m_connector.hasComponent(closestConnectPoint.owner));
            
            auto connectEntity = closestConnectPoint.owner;
            auto ownerEntity = m_connector.getComponent(connectEntity).owner;
            
            m_dragEntity.setValue("owner", to!string(ownerEntity.id));
            m_dragEntity.setValue("connection", to!string(connectEntity.id) ~ "." ~ closestConnectPoint.name);
            
            if (ownerEntity == m_playerShip)
            {
              //if (m_dragEntity.getValue("source") == "data/engine.txt" || m_dragEntity.getValue("source") == "engine.txt")
              if (m_dragEntity.getValue("thrustForce").length > 0)
                m_dragEntity.setValue("control", "playerEngine");
              
              //if (m_dragEntity.getValue("source") == "data/cannon.txt" || m_dragEntity.getValue("source") == "cannon.txt")
              if (m_dragEntity.getValue("spawn.source").length > 0)
                m_dragEntity.setValue("control", "playerLauncher");
            }
            registerEntity(m_dragEntity);
            
            assert(m_connector.hasComponent(connectEntity));
            assert(m_connector.getComponent(connectEntity).connectPoints[closestConnectPoint.name].connectedEntity !is null, 
                   "Connectpoint " ~ closestConnectPoint.name ~ 
                   " on " ~ connectEntity.getValue("name") ~ 
                   " with id " ~ to!string(connectEntity.id) ~ 
                   " still empty after connecting entity " ~ m_dragEntity.getValue("name") ~ 
                   " with values " ~ to!string(m_dragEntity.values));
            
            updateOwnerEntity(ownerEntity);
          }
        }
        
        // create a new owner entity if the dragentity owns itself
        // the dragentity is a module, the owner is supposed to be like a ship entity aggregating the module entities making up the ship
        if (m_connector.hasComponent(m_dragEntity))
        {
          auto dragConnectComp = m_connector.getComponent(m_dragEntity);
          
          if (dragConnectComp.owner == m_dragEntity)
          {
            //auto ownerEntity = new Entity();
            string[string] ownerEntityValues;
            
            // TODO: set up values in ownerEntity so that it can recreate the ship with modules if it's saved and loaded again
            // look in playership.txt for how values should be set up

            if (m_placer.hasComponent(m_dragEntity))
              ownerEntityValues["position"] = m_placer.getComponent(m_dragEntity).position.toString();
              
            if (m_placer.hasComponent(m_dragEntity))
              ownerEntityValues["angle"] = to!string(m_placer.getComponent(m_dragEntity).angle * (_180_PI));
              
            if (m_physics.hasComponent(m_dragEntity))
              ownerEntityValues["mass"] = to!string(m_physics.getComponent(m_dragEntity).mass);
            
            Entity ownerEntity = new Entity(ownerEntityValues);
            
            ownerEntity.setValue("owner", to!string(ownerEntity.id));
            
            m_dragEntity.setValue("owner", to!string(ownerEntity.id));
            
            registerEntity(ownerEntity);
            registerEntity(m_dragEntity);
          }
        }
        
        m_dragEntity = null;
      }
    }
    
    // transfer ship control with rightclick
    if (m_inputHandler.eventState(Event.RightButton) == EventState.Released)
    {
      foreach (entity; m_entities)
      {
        if (entity != m_playerShip && m_placer.hasComponent(entity) && entity.getValue("radius").length > 0)
        {
          auto position = m_placer.getComponent(entity).position;
          
          if ((position - m_graphics.mouseWorldPos).length < to!float(entity.getValue("radius")))
          {
            if (m_connector.hasComponent(entity))
            {
              auto entityOwner = m_connector.getComponent(entity).owner;
              
              // we don't want to control modules floating by themself not connected to anything... or do we?
              //if (entityOwner.id == entity.id)
                //continue;
              
              // remove control from eventual old playership so we don't end up controlling multiple ships at once
              if (m_playerShip !is null && m_playerShip != entityOwner)
              {
                foreach (oldOwnedEntity; m_connector.getOwnedEntities(m_playerShip))
                {
                  m_controller.removeEntity(oldOwnedEntity);
                }
              }
              
              m_playerShip = m_connector.getComponent(entity).owner;
              
              // disable eventual old center entity
              auto oldCenterEntity = m_graphics.getCenterEntity();
              
              if (oldCenterEntity !is null)
                oldCenterEntity.setValue("keepInCenter", "false");
              
              m_playerShip.setValue("keepInCenter", "true");
              m_playerShip.setValue("drawsource", "Invisible");
              
              // also set as center
              m_graphics.registerEntity(m_playerShip);
              
              // give player control to new playership
              foreach (ownedEntity; m_connector.getOwnedEntities(m_playerShip))
              {
                if (ownedEntity.getValue("source") == "data/engine.txt" || ownedEntity.getValue("source") == "engine.txt")
                  ownedEntity.setValue("control", "playerEngine");

                if (ownedEntity.getValue("source") == "data/cannon.txt" || ownedEntity.getValue("source") == "cannon.txt")
                  ownedEntity.setValue("control", "playerLauncher");


                //registerEntity(ownedEntity);
                m_controller.registerEntity(ownedEntity);
              }
              
              break;
            }
          }
        }
      }
    }  
  
    if (m_inputHandler.isPressed(Event.PageUp))
    {
      m_graphics.zoomIn(p_elapsedTime * 2.0);
    }
    if (m_inputHandler.isPressed(Event.WheelUp))
    {
      m_graphics.zoomIn(p_elapsedTime * 15.0);
    }
    if (m_inputHandler.isPressed(Event.PageDown))
    {
      m_graphics.zoomOut(p_elapsedTime * 2.0);
    }
    if(m_inputHandler.isPressed(Event.WheelDown))
    {
      m_graphics.zoomOut(p_elapsedTime * 15.0);
    }

    if (m_inputHandler.eventState(Event.Escape) == EventState.Released)
      m_running = false;

    if (m_inputHandler.eventState(Event.Pause) == EventState.Released)
    {
      m_paused = !m_paused;
    }
  }
  
  
  Entity loadShip(string p_fileName, string[string] p_extraParams = null)
  {
    //debug writeln("loading ship from file " ~ p_fileName ~ ", with extraparams " ~ to!string(p_extraParams));
    
    string[string] values;

    if (p_fileName.length > 0)
      values = loadValues(cache, p_fileName);
    
    foreach (extraKey, extraValue; p_extraParams)
      values[extraKey] = extraValue;
    
    auto childrenValues = findChildrenValues(cache, values);
    
    values = parseRandomizedValues(values);
    
    auto mainEntity = new Entity(values);
    
    mainEntity.setValue("owner", to!string(mainEntity.id));
    
    float accumulatedMass = 0.0;
    if ("mass" in mainEntity.values)
      accumulatedMass += to!float(mainEntity.getValue("mass"));
    
    Entity[string] childEntities;
    foreach (childName, childValues; childrenValues)
    {
      childValues = parseRandomizedValues(childValues);
      
      childEntities[childName] = new Entity(childValues);
      
      if ("mass" in childValues)
        accumulatedMass += to!float(childValues["mass"]);
      
      childEntities[childName].setValue("owner", to!string(mainEntity.id));
      
      // position value is required for registering entities to connection subsystem
      childEntities[childName].setValue("position", mainEntity.getValue("position"));
    }
    
    string[string] childDependency;
    // replace connect entity names with ids, because names are not unique but ids are
    foreach (childName, childValues; childrenValues)
    {
      foreach (childKey, childValue; childValues)
      {
        if (childKey == "connection")
        {
          auto connectEntityName = to!string(childValue.until("."));
          auto connectPointName = childValue.find(".")[1..$];
          
          childDependency[childName] = connectEntityName;
          
          if (connectEntityName in childEntities)
          {
            childEntities[childName].setValue("connection", to!string(childEntities[connectEntityName].id) ~ "." ~ connectPointName);
          }
        }
      }
    }
    
    if (accumulatedMass > 0.0)
      mainEntity.setValue("mass", to!string(accumulatedMass));
    
    registerEntity(mainEntity);
    
    foreach (childEntityName, childEntity; childEntities)
      if (childEntityName !in childDependency)
        registerEntity(childEntity);
    
    // loop over dependent entities until all are registered
    while (childDependency.length > 0)
    {
      string[string] newChildDependency;
      
      foreach (childName; childDependency.keys)
      {
        assert(childName in childDependency);
        assert(childDependency[childName] in childEntities, "Could not find entity " ~ to!string(childDependency[childName]) ~ " in " ~ to!string(childEntities));
        
        if (m_connector.hasComponent(childEntities[childDependency[childName]]))
          registerEntity(childEntities[childName]);
        else
          newChildDependency[childName] = childDependency[childName];
      }
      
      // if no entities were registered and all were put in newChildDependency, we have a cycle or something
      enforce(newChildDependency.length < childDependency.length, "Could not resolve entity dependencies when loading " ~ p_fileName);
      
      childDependency = newChildDependency;
    }
    
    return mainEntity;    
  }
  

  void registerEntity(Entity p_entity)
  {
    //assert(p_entity.id !in m_entities, "Tried registering entity " ~ to!string(p_entity.id) ~ " that was already registered");
    
    m_entities[p_entity.id] = p_entity;
    
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with name " ~ p_entity.getValue("name"));
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with values " ~ to!string(p_entity.values));
    
    foreach (subSystem; m_subSystems)
      subSystem.registerEntity(p_entity);
  }
  
  
  void removeEntity(Entity p_entity)
  {
    foreach (subSystem; m_subSystems)
      subSystem.removeEntity(p_entity);
    
    if (m_connector.hasComponent(p_entity))
    {
      auto owner = m_connector.getComponent(p_entity).owner;
      auto ownedEntities = m_connector.getOwnedEntities(owner);
      
      // we don't want owner entities without owned entities hanging around
      // so if the entity we remove is the last owned entity, we also remove the owner entity
      if (ownedEntities.length == 1 && ownedEntities[0] == p_entity)
      {
        writeln("removing owner entity " ~ to!string(owner.id));
        removeEntity(owner);
      }
    }
    
    m_entities.remove(p_entity.id);
  }
  
  
  // update mass, center of mass etc
  // called when entities are added or removed to a owner entity, which means the owner entity must update its accumulated stuff
  void updateOwnerEntity(Entity p_ownerEntity)
  {
    float accumulatedMass = 0.0;
    foreach (ownedEntity; m_connector.getOwnedEntities(p_ownerEntity))
    {
      if (m_physics.hasComponent(ownedEntity))
      {
        auto physComp = m_physics.getComponent(ownedEntity);
        accumulatedMass += physComp.mass;
      }
    }
    if (accumulatedMass <= 0.0)
      return;
      
    auto physComp = m_physics.getComponent(p_ownerEntity);
    physComp.mass = accumulatedMass;
    writeln("setting accumulated mass to " ~ to!string(accumulatedMass));
    assert(physComp.mass == physComp.mass);
    m_physics.setComponent(p_ownerEntity, physComp);
    
    // recalculate relative position to center of mass for all owned entities
    vec2 centerOfMass = vec2(0.0, 0.0);
    float totalMass = 0.0;
    foreach (ownedEntity; m_connector.getOwnedEntities(p_ownerEntity))
    {
      auto ownedComponent = m_connector.getComponent(ownedEntity);
      centerOfMass += ownedComponent.relativePosition * ownedComponent.mass;
      totalMass += ownedComponent.mass;
    }
    centerOfMass *= (1.0/totalMass);
    
    foreach (ownedEntity; m_connector.getOwnedEntities(p_ownerEntity))
    {
      auto ownedComponent = m_connector.getComponent(ownedEntity);
      ownedComponent.relativePositionToCenterOfMass = ownedComponent.relativePosition - centerOfMass;
    }
  }
  
  
private:
  void updateSubSystems()
  {
    // the sdl/gl stuff in the graphics subsystem needs to run in the main thread for stuff to be shown on the screen
    // so we filter the graphics subsystem out of the subsystem list 
    // and explicitly update it outside the parallel foreach to ensure it runs in the main thread
    debug
    {
      StopWatch subSystemTimer;
      subSystemTimer.reset();
      subSystemTimer.start();
    }
    
    debug m_graphics.updateWithTiming();
    else  m_graphics.update();
    //foreach (subSystem; taskPool.parallel(filter!(delegate (SubSystem.Base.SubSystem sys) { return sys !is m_graphics; })(m_subSystems.values), 1))
    foreach (subSystem; filter!(delegate (SubSystem.Base.SubSystem sys) { return sys !is m_graphics; })(m_subSystems.values))
    {
      debug subSystem.updateWithTiming();
      else  subSystem.update();
    }
    debug
    {
      subSystemTimer.stop();
      float timeSpent = subSystemTimer.peek.usecs / 1_000_000.0;
    
      auto timeSpents = map!((SubSystem.Base.SubSystem sys) { return sys.timeSpent;} )(m_subSystems.values);
      float subSystemTime = reduce!"a+b"(timeSpents);
    
      //debug writeln("Subsystem update spent " ~ to!string(timeSpent) ~ ", time saved parallelizing: " ~ to!string(subSystemTime - timeSpent));
    }
  }
  
  string[string] parseRandomizedValues(string[string] inValues)
  {
    string[string] outValues = inValues.dup;
    
    if ("position" in inValues && inValues["position"].find("to").length > 0)
    {
      auto positionData = inValues["position"].split(" ");
      
      assert(positionData.length == 5, "Problem parsing position data with from/to values: " ~ to!string(positionData));
      
      auto fromX = to!float(positionData[0]);
      auto fromY = to!float(positionData[1]);
      auto toX = to!float(positionData[3]);
      auto toY = to!float(positionData[4]);
      
      auto x = (fromX == toX) ? fromX : uniform(fromX, toX);
      auto y = (fromY == toY) ? fromY : uniform(fromY, toY);
      
      auto position = vec2(x, y);
      
      outValues["position"] = position.toString();
    }
    
    if ("angle" in inValues && inValues["angle"].find("to").length > 0)
    {
      auto angleData = inValues["angle"].split(" ");
      
      assert(angleData.length == 3, "Problem parsing angle data with from/to values: " ~ to!string(angleData));
      
      auto fromAngle = to!float(angleData[0]);
      auto toAngle = to!float(angleData[2]);
      
      auto angle = uniform(fromAngle, toAngle);
      
      outValues["angle"] = to!string(angle);
    }
    
    return outValues;
  }
  
  Entity findClosestEnemyShip(Entity p_entity)
  {
    auto entityPosition = m_placer.getComponent(p_entity).position;
    
    auto candidates = filter!((entity) { return (entity.id != p_entity.id && entity.getValue("type") == "enemy ship"); } )(m_entities.values);
    
    //writeln("closestenemyship candidates: " ~ to!string(array(candidates).length));
    
    if (candidates.empty)
      return null;
      
    Entity closestEntity = reduce!((closestSoFar, entity)
    {
      return ((m_connector.getComponent(closestSoFar).position - entityPosition).length < 
              (m_connector.getComponent(entity).position - entityPosition).length) ? closestSoFar : entity;
    })(candidates);

    return closestEntity;
  }
  
private:
  int m_updateCount;
  bool m_running;
  
  bool m_paused;
  
  StopWatch m_timer;
  
  InputHandler m_inputHandler;
  
  SubSystem.Base.SubSystem[string] m_subSystems;
  Placer m_placer;
  Physics m_physics;
  Graphics m_graphics;
  Controller m_controller;
  ConnectionHandler m_connector;
  CollisionHandler m_collider;
  Spawner m_spawner;
  
  Starfield m_starfield;
  
  Entity[int] m_entities;

  // special entities.. do they really need to be hardcoded?
  Entity m_playerShip;
  Entity m_trashBin;
  Entity m_dragEntity;
  Entity m_fpsDisplay;
  Entity m_closestShipDisplay;
  
  float[20] m_fpsBuffer;
  
  AiGunner m_aiGunner;
  AiChaser m_aiChaser;
  
  string[][string] cache;
}
