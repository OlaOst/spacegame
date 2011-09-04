﻿/*
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
import std.math;
import std.parallelism;
import std.random;
import std.stdio;

import derelict.sdl.sdl;

import SubSystem.CollisionHandler;
import SubSystem.ConnectionHandler;
import SubSystem.Controller;
import SubSystem.Graphics;
import SubSystem.Physics;
import SubSystem.Placer;
import SubSystem.Sound;
import SubSystem.Spawner;

import CommsCentral;
import DragDropHandler;
import InputHandler;
import Starfield;
import common.Vector;


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
  
  
  Entity testPhysics = new Entity();
  testPhysics.setValue("position", "1 0 0");
  testPhysics.setValue("mass", "1.0");
  
  game.registerEntity(testPhysics);
  assert(game.m_placer.hasComponent(testPhysics));
  assert(game.m_physics.hasComponent(testPhysics));
  assert(game.m_graphics.hasComponent(testPhysics) == false);
  
  game.m_physics.getComponent(testPhysics).force = Vector(0.0, 1.0, 0.0);
  
  assert(game.m_physics.getComponent(testPhysics).force == Vector(0.0, 1.0, 0.0));
  
  game.m_physics.setTimeStep(0.1);
  game.m_controller.setTimeStep(0.1);
  foreach (subSystem; game.m_subSystems)
    subSystem.update();
    
  assert(game.m_physics.getComponent(testPhysics).position.y > 0.0);
  
  setPlacerFromPhysics(game.m_physics, game.m_placer);
  
  assert(game.m_placer.getComponent(testPhysics).position == game.m_physics.getComponent(testPhysics).position);
  
  
  Entity testGraphics = new Entity();
  testGraphics.setValue("position", "0 1 0");
  testGraphics.setValue("drawsource", "Star");
  
  game.registerEntity(testGraphics);
  assert(game.m_graphics.hasComponent(testGraphics));
  assert(game.m_placer.hasComponent(testGraphics));
  assert(game.m_physics.hasComponent(testGraphics) == false);

  setGraphicsFromPlacer(game.m_placer, game.m_graphics);
  
  assert(game.m_graphics.getComponent(testGraphics).position == game.m_placer.getComponent(testGraphics).position);
  
  
  Entity testController = new Entity();
  testController.setValue("mass", "2.0");
  testController.setValue("control", "flocker");
  
  game.registerEntity(testController);
  assert(game.m_physics.hasComponent(testController));
  assert(game.m_controller.hasComponent(testController)); 
  
  game.m_controller.getComponent(testController).control = 
      new class () Control 
      {
        override void update(ref ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents) 
        {
          p_sourceComponent.force = Vector(1.0, 1.0, 0.0);
        }
      };
  
  assert(game.m_controller.getComponent(testController).control !is null);
  
  foreach (subSystem; game.m_subSystems)
    subSystem.update();
    
  assert(game.m_controller.getComponent(testController).force.length2d > 0.0);
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
    
    int xres = 800;
    int yres = 600;
    
    
    m_subSystems["placer"] = m_placer = new Placer();
    m_subSystems["graphics"] = m_graphics = new Graphics(xres, yres);
    m_subSystems["physics"] = m_physics = new Physics();
    m_subSystems["controller"] = m_controller = new Controller(m_inputHandler);
    m_subSystems["collider"] = m_collider = new CollisionHandler();
    m_subSystems["connector"] = m_connector = new ConnectionHandler();
    m_subSystems["sound"] = new SoundSubSystem(16);    
    m_subSystems["spawner"] = m_spawner = new Spawner();
    
    m_trashBin = new Entity();
    m_trashBin.setValue("name", "trashbin");
    m_trashBin.setValue("position", "-5 0 0");
    m_trashBin.setValue("drawsource", "Unknown");
    m_trashBin.setValue("radius", "1");
    registerEntity(m_trashBin);
    
    
    Entity engineBlueprint = new Entity("data/engine.txt");
    engineBlueprint.setValue("source", "data/engine.txt");
    engineBlueprint.setValue("isBlueprint", "true");
    engineBlueprint.setValue("position", "5 0 0");
    engineBlueprint.setValue("name", "engineBlueprint");
    registerEntity(engineBlueprint);
    
    Entity cannonBlueprint = new Entity("data/cannon.txt");
    cannonBlueprint.setValue("source", "data/cannon.txt");
    cannonBlueprint.setValue("isBlueprint", "true");
    cannonBlueprint.setValue("position", "7 0 0");
    cannonBlueprint.setValue("name", "cannonBlueprint");
    registerEntity(cannonBlueprint);
    
    Entity horizontalSkeletonBlueprint = new Entity("data/horizontalskeleton.txt");
    horizontalSkeletonBlueprint.setValue("source", "data/horizontalskeleton.txt");
    horizontalSkeletonBlueprint.setValue("isBlueprint", "true");
    horizontalSkeletonBlueprint.setValue("position", "9 0 0");
    horizontalSkeletonBlueprint.setValue("name", "horizontalSkeletonBlueprint");
    registerEntity(horizontalSkeletonBlueprint);
    
    Entity verticalSkeletonBlueprint = new Entity("data/verticalskeleton.txt");
    verticalSkeletonBlueprint.setValue("source", "data/verticalskeleton.txt");
    verticalSkeletonBlueprint.setValue("isBlueprint", "true");
    verticalSkeletonBlueprint.setValue("position", "11 0 0");
    verticalSkeletonBlueprint.setValue("name", "verticalSkeletonBlueprint");
    registerEntity(verticalSkeletonBlueprint);

    
    Entity startupDing = new Entity();
    startupDing.setValue("soundFile", "test.wav");
    
    registerEntity(startupDing);
    
    
    m_fpsDisplay = new Entity();
    m_fpsDisplay.setValue("drawsource", "Text");
    m_fpsDisplay.setValue("text", "here we should see fps");
    m_fpsDisplay.setValue("screenAbsolutePosition", "true");
    m_fpsDisplay.setValue("position", "-1.0 0.7");
    m_fpsDisplay.setValue("color", "1.0 1.0 1.0");
    
    registerEntity(m_fpsDisplay);
    
    
    m_playerShip = loadShip("playership.txt", ["position" : "0 0 0"]);
    
    for (int n = 0; n < 0; n++)
    {
      Entity npcShip = loadShip("npcship.txt", ["position" : Vector(uniform(-12.0, 12.0), uniform(-12.0, 12.0)).toString(), 
                                                "angle" : to!string(uniform(0.0, PI*2))]);
    }
    
    //m_starfield = new Starfield(m_graphics, 10.0);

    m_inputHandler.setScreenResolution(xres, yres);
  }
 
 
  void run()
  {
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
      entity.lifetime = entity.lifetime - elapsedTime;

      bool removeEntity = false;
      
      if (m_collider.hasComponent(entity))
      {
        if (m_collider.getComponent(entity).lifetime <= 0.0)
          removeEntity = true;
      }
      
      // can't directly call removeEntity here since it touches m_entities and we're looping inside it
      if (entity.lifetime <= 0.0 || entity.health <= 0.0 || removeEntity)
        entitiesToRemove ~= entity;
    }
    
    foreach (entityToRemove; entitiesToRemove)
      removeEntity(entityToRemove);
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      assert(elapsedTime > 0.0);
      m_physics.setTimeStep(elapsedTime);
      m_controller.setTimeStep(elapsedTime);
      
      // the sdl/gl stuff in the graphics subsystem needs to run in the main thread for stuff to be shown on the screen
      // so we filter the graphics subsystem out of the subsystem list 
      // and explicitly update it outside the parallel foreach to ensure it runs in the main thread
      //m_graphics.update();
      //foreach (subSystem; taskPool.parallel(filter!(delegate (SubSystem.Base.SubSystem sys) { return sys !is m_graphics; })(m_subSystems.values)))
      //{
      //  subSystem.update();
      //}
      foreach (subSystem; m_subSystems.values)
      {
        subSystem.update();
      }
      
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
        
        if (m_graphics.hasComponent(m_dragEntity))
        {
          auto dragGfxComp = m_graphics.getComponent(m_dragEntity);
          dragGfxComp.position = m_graphics.mouseWorldPos;
          
          m_graphics.setComponent(m_dragEntity, dragGfxComp);
        }
        
        if (m_physics.hasComponent(m_dragEntity))
        {
          auto dragPhysComp = m_physics.getComponent(m_dragEntity);
          dragPhysComp.position = m_graphics.mouseWorldPos;
          
          m_physics.setComponent(m_dragEntity, dragPhysComp);
        }
      }
      
      
      CommsCentral.setPhysicsFromController(m_controller, m_physics);
      CommsCentral.setSpawnerFromController(m_controller, m_spawner);
      
      CommsCentral.setPhysicsFromConnector(m_connector, m_physics);
      
      CommsCentral.setControllerFromPlacer(m_placer, m_controller);
      CommsCentral.setCollidersFromPlacer(m_placer, m_collider);
      CommsCentral.setSpawnerFromPlacer(m_placer, m_spawner);
      CommsCentral.setConnectorFromPlacer(m_placer, m_connector);
      
      CommsCentral.calculateCollisionResponse(m_collider, m_physics);
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
    
    m_graphics.calculateMouseWorldPos(m_inputHandler.mousePos);
    
    foreach (spawn; m_spawner.getAndClearSpawns())
    {
      registerEntity(spawn);
    }
    
    handleInput(elapsedTime);
    
    SDL_Delay(20);
  }
  
  
  void handleInput(float p_elapsedTime)
  {
    if (m_inputHandler.isPressed(Event.LeftButton))
    {
      if (m_dragEntity is null)
      {
        foreach (draggable; m_entities)
        {
          if (m_graphics.hasComponent(draggable) == false)
            continue;
          
          assert(m_graphics.hasComponent(draggable), "Couldn't find graphics component for draggable entity " ~ to!string(draggable.values) ~ " with id " ~ to!string(draggable.id));
          
          auto dragGfxComp = m_graphics.getComponent(draggable);
          
          // screenAbsolutePosition is true for GUI and screen elements - we don't want to drag them
          if (dragGfxComp.screenAbsolutePosition)
            continue;
          
          if ((dragGfxComp.position - m_graphics.mouseWorldPos).length2d < dragGfxComp.radius)
          {
            // we don't want to drag something if it has stuff connected to it. 
            // if you want to drag a skeleton module, you should drag off all connected modules first
            // TODO: should be possible to drag stuff with connected stuff, but drag'n'drop needs to be more robust first
            if (m_connector.getConnectedEntities(draggable).length > 0)
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
            m_dragEntity = new Entity(m_dragEntity.getValue("source"), m_dragEntity.values);
            m_dragEntity.setValue("isBlueprint", "false");
            m_dragEntity.setValue("name", m_dragEntity.getValue("source") ~ ":" ~ to!string(m_dragEntity.id));
            
            registerEntity(m_dragEntity);
          }
          
          if (m_connector.hasComponent(m_dragEntity))
          {
            // TODO: disconnectEntity sets the component owner to itself - might cause trouble if we assume it has a separate owner entity when floating around on its own
            m_connector.disconnectEntity(m_dragEntity);
            
            // double check connect point for disconnection
            debug
            {
              assert(m_connector.hasComponent(m_dragEntity));
              
              if (m_dragEntity.getValue("connection").length > 0)
              {
                auto stuff = extractEntityAndConnectPointName(m_dragEntity.getValue("connection"));
                
                Entity connectEntity;
                foreach (entity; m_entities)
                {
                  if (entity.getValue("name") == stuff[0])
                  {
                    connectEntity = entity;
                    break;
                  }
                }
                
                assert(connectEntity !is null);
                assert(m_connector.hasComponent(connectEntity), "expected connection comp of entity with values " ~ to!string(connectEntity.values));
                auto comp = m_connector.getComponent(connectEntity);
                
                assert(comp.connectPoints[stuff[1]].connectedEntity is null, "Disconnected connectpoint still not empty: " ~ to!string(comp.connectPoints[stuff[1]]));
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
        if (m_dragEntity != m_trashBin && (dragPos - trashBinPos).length2d < to!float(m_dragEntity.getValue("radius")))
        {
          removeEntity(m_dragEntity);
        }
        else
        {
          // if drag entity is close to an empty skeleton contact point then connect to it
          auto overlappingEmptyConnectPointsWithPosition = m_connector.findOverlappingEmptyConnectPointsWithPosition(m_dragEntity, dragPos);
        
          ConnectPoint closestConnectPoint;
          auto closestPosition = Vector(float.infinity, float.infinity);
        
          // connect to the closest one
          foreach (ConnectPoint connectPoint, Vector position; overlappingEmptyConnectPointsWithPosition)
          {
            if (position.length2d < closestPosition.length2d)
            {
              closestConnectPoint = connectPoint;
              closestPosition = position;
            }
          }
          
          if (closestPosition.length2d < float.infinity)
          {
            assert(closestConnectPoint.owner !is null);
            assert(m_connector.hasComponent(closestConnectPoint.owner));
            
            auto connectEntity = closestConnectPoint.owner;
            auto ownerEntity = m_connector.getComponent(connectEntity).owner;
            
            m_dragEntity.setValue("owner", to!string(ownerEntity.id));
            m_dragEntity.setValue("connection", connectEntity.getValue("name") ~ "." ~ closestConnectPoint.name);
            
            if (ownerEntity == m_playerShip)
            {
              if (m_dragEntity.getValue("source") == "data/engine.txt")
                m_dragEntity.setValue("control", "playerEngine");
              
              if (m_dragEntity.getValue("source") == "data/cannon.txt")
                m_dragEntity.setValue("control", "playerLauncher");
            }
            registerEntity(m_dragEntity);
            
            assert(m_connector.hasComponent(connectEntity));
            assert(m_connector.getComponent(connectEntity).connectPoints[closestConnectPoint.name].connectedEntity !is null, "Connectpoint " ~ closestConnectPoint.name ~ " on " ~ connectEntity.getValue("name") ~ " with id " ~ to!string(connectEntity.id) ~ " still empty after connecting entity " ~ m_dragEntity.getValue("name") ~ " with values " ~ to!string(m_dragEntity.values));
            
            // update mass on owner entity, figure out center of mass etc
            auto physicsOwnerComp = m_physics.getComponent(ownerEntity);
            physicsOwnerComp.mass += to!float(m_dragEntity.getValue("mass"));
          }
        }
        
        // create a new owner entity if the dragentity owns itself
        // the dragentity is a module, the owner is supposed to be like a ship entity aggregating the module entities making up the ship
        if (m_connector.hasComponent(m_dragEntity))
        {
          auto dragConnectComp = m_connector.getComponent(m_dragEntity);
          
          if (dragConnectComp.owner == m_dragEntity)
          {
            auto ownerEntity = new Entity();
            
            // TODO: set up values in ownerEntity so that it can recreate the ship with modules if it's saved and loaded again
            // look in playership.txt for how values should be set up
            
            ownerEntity.setValue("owner", to!string(ownerEntity.id));
            
            if (m_placer.hasComponent(m_dragEntity))
              ownerEntity.setValue("position", m_placer.getComponent(m_dragEntity).position.toString());
              
            if (m_physics.hasComponent(m_dragEntity))
              ownerEntity.setValue("mass", to!string(m_physics.getComponent(m_dragEntity).mass));
            
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
          
          if ((position - m_graphics.mouseWorldPos).length2d < to!float(entity.getValue("radius")))
          {
            if (m_connector.hasComponent(entity))
            {
              auto entityOwner = m_connector.getComponent(entity).owner;
              
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
  
  
  Entity loadShip(string p_file, string[string] p_extraParams = null)
  {
    Entity ship = new Entity("data/" ~ p_file, p_extraParams);
    
    if (ship.getValue("health"))
      ship.health = to!float(ship.getValue("health"));
    
    // need to add sub entities after they're loaded
    // since the ship entity needs accumulated values from sub entities
    // and sub entities must have the ship registered before they can be registered themselves
    Entity[] subEntitiesToAdd;
    float accumulatedMass = 0.0;
    
    // load in submodules, signified by <modulename>.source = <module source filename>
    foreach (subSource; filter!("a.endsWith(\".source\")")(ship.values.keys))
    {
      Entity subEntity = new Entity("data/" ~ ship.getValue(subSource));
      
      auto subName = subSource[0..std.string.indexOf(subSource, ".source")];
      
      subEntity.setValue("name", subName);
      
      subEntity.setValue("owner", to!string(ship.id));
      
      // inital position of submodules are equal to owner module position
      subEntity.setValue("position", ship.getValue("position"));

      // set extra values on submodule from the module that loads them in
      foreach (subSourceValue; filter!(delegate(x) { return x.startsWith(subName ~ "."); })(ship.values.keys))
      {
        subEntity.setValue(subSourceValue[std.string.indexOf(subSourceValue, '.')+1..$], ship.getValue(subSourceValue));
      }
      
      if (subEntity.getValue("mass").length > 0)
      {
        accumulatedMass += to!float(subEntity.getValue("mass"));
      }
      
      subEntitiesToAdd ~= subEntity;
    }
    
    if (accumulatedMass > 0.0)
      ship.setValue("mass", to!string(accumulatedMass));
    
    // ship entity is its own owner, this is also needed to register it to connection system
    ship.setValue("owner", to!string(ship.id));
    
    registerEntity(ship);
    
    foreach (subEntity; subEntitiesToAdd)
      registerEntity(subEntity);

    return ship;
  }
  

  void registerEntity(Entity p_entity)
  {
    //debug writeln("Registering entity " ~ to!string(p_entity.id) ~ " with values " ~ to!string(p_entity.values));
    m_entities[p_entity.id] = p_entity;
    
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
        removeEntity(owner);
      }
    }
    
    m_entities.remove(p_entity.id);
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

  Entity m_playerShip;
  
  Entity m_trashBin;
  Entity m_dragEntity;
  
  Entity m_fpsDisplay;
  float[20] m_fpsBuffer;
}
