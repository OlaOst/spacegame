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
import std.exception;
import std.math;
import std.parallelism;
import std.random;
import std.range;
import std.stdio;
import std.string;

import derelict.sdl.sdl;

import gl3n.linalg;
import gl3n.math;

import Control.AiChaser;
import Control.AiGunner;
import Control.Dispenser;
import Control.PlayerEngine;
import Control.PlayerLauncher;
import Control.Flocker;

import CommsCentral;
import Console;
import Entity;
import EntityConsole;
import EntityGenerator;
import EntityLoader;
import GameConsole;
import InputHandler;
import Starfield;

import SubSystem.CollisionHandler;
import SubSystem.ConnectionHandler;
import SubSystem.Controller;
import SubSystem.Graphics;
import SubSystem.Physics;
import SubSystem.Placer;
import SubSystem.Sound;
import SubSystem.Spawner;
import SubSystem.Timer;


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
  
  game.m_placer.setTimeStep(0.1);
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

  CommsCentral.setGraphicsFromPlacer(game.m_placer, game.m_graphics);
  
  assert(game.m_graphics.getComponent(testGraphics).position == game.m_placer.getComponent(testGraphics).position);
  
  
  Entity testController = new Entity(["mass":"2.0", "control":"alwaysaccelerate", "thrustForce":"1.0"]);
  
  game.registerEntity(testController);
  assert(game.m_physics.hasComponent(testController));
  assert(game.m_controller.hasComponent(testController)); 
  
  assert(game.m_controller.getComponent(testController).control !is null);
  
  foreach (subSystem; game.m_subSystems)
    subSystem.update();
    
  assert(game.m_controller.getComponent(testController).force.length > 0.0, "Force of alwaysaccelerate controlcomponent should be nonzero, was " ~ to!string(game.m_controller.getComponent(testController).force));
  
  Entity owner = new Entity(["":""]);
  owner.setValue("owner", to!string(owner.id));
  Entity parent = new Entity(["connectpoint.lower.position" : "0 -1", "connectpoint.upper.position" : "0 1", "owner" : to!string(owner.id)]);
  Entity child = new Entity(["connection" : to!string(parent.id) ~ ".lower", "owner" : to!string(owner.id)]);
  
  game.registerEntity(owner);
  game.registerEntity(parent);
  game.registerEntity(child);
  
  assert(game.m_connector.hasComponent(parent));
  assert(game.m_connector.hasComponent(child));
}


class Game
{
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
    m_subSystems["controller"] = m_controller = new Controller();
    m_subSystems["collider"] = m_collider = new CollisionHandler();
    m_subSystems["connector"] = m_connector = new ConnectionHandler();
    m_subSystems["sound"] = m_sound = new Sound(64);
    m_subSystems["spawner"] = m_spawner = new Spawner();
    m_subSystems["timer"] = m_timer = new Timer();

    m_gameConsole = new GameConsole(this);
    m_entityConsole = new EntityConsole(this);
    
    assert(m_controller !is null);
    
    m_controller.controls["aigunner"] = new AiGunner();
    m_controller.controls["chaser"] = new AiChaser();
    m_controller.controls["dispenser"] = m_dispenser = new Dispenser(m_inputHandler);
    m_controller.controls["playerlauncher"] = new PlayerLauncher(m_inputHandler);
    m_controller.controls["playerengine"] = new PlayerEngine(m_inputHandler);
    
    SDL_EnableUNICODE(1);
    
    //loadWorldFromFile("data/simpleworld2.txt");
    //loadWorldFromFile("data/world.txt");
    
    //Entity station = loadShip("", getValues(cache, EntityGenerator.createStation()));
    
    //m_starfield = new Starfield(m_graphics, 1000.0);

    m_inputHandler.setScreenResolution(xres, yres);
  }
 
 
  void loadWorldFromFile(string p_fileName)
  {
    if (p_fileName.startsWith("data/") == false)
      p_fileName = "data/" ~ p_fileName;

    Entity worldEntity = new Entity(loadValues(cache, p_fileName));

    string[] orderedEntityNames;
    
    auto file = File(p_fileName);
    foreach (string line; lines(file))
    {
      line = line.strip;
      
      if (line.length > 0 && line.startsWith("#") == false)
        if (orderedEntityNames.find(line.split(".")[0]) == [])
          orderedEntityNames ~= line.split(".")[0];
    }
    
    // go through world entity values, put values for child entities in this AA
    string[string][string] spawnNameWithValues;
    
    // we go only 1 level deep - child entities inside child entities are not registered here
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

        //writeln("loadworld, loading from source " ~ to!string(worldEntity.getValue(spawnName ~ ".source")) ~ " with extravalues " ~ to!string(extraValues));
        
        if (spawnName ~ ".collectionSource" in worldEntity.values)
          loadEntityCollection(worldEntity.getValue(spawnName ~ ".collectionSource"), extraValues);
        else
          spawn = loadShip(worldEntity.getValue(spawnName ~ ".source"), extraValues);
      }
    }
  }
 
 
  void run()
  {  
    while (m_running)
    {
      update();
    }
  }
  
 
  OutputLine[] executeCommand(string command)
  {
    if (command == "help")
    {
      return [OutputLine("Commands available: ", vec3(1, 1, 1)),
              OutputLine("help                - shows this list", vec3(1, 1, 1)),
              OutputLine("exit/quit           - exits the program", vec3(1, 1, 1)),
              OutputLine("loadworld world.txt - loads world from given file" , vec3(1, 1, 1)),
              OutputLine("clearworld          - clears all entities", vec3(1, 1, 1)),
              OutputLine("entities            - list of entity ids", vec3(1, 1, 1)),
              OutputLine("values n            - list values in entity with id n", vec3(1, 1, 1)),
              OutputLine("systems n           - list subsystems entity with id n is registered in", vec3(1, 1, 1)),
              OutputLine("register n          - registers entity with id n", vec3(1, 1, 1)),
              OutputLine("set n key value     - for entity with id n, sets key to the given value", vec3(1, 1, 1)),
              OutputLine("new name            - creates a new entity with the given name", vec3(1, 1, 1)),
              OutputLine("Don't panic", vec3(0, 1, 0)),];
    }
    else if (command == "exit" || command == "quit")
    {
      m_running = false;
      return [];
    }
    else if (command.startsWith("loadworld"))
    {
      command.skipOver("loadworld");
      
      string fileName = command.strip;
      
      loadWorldFromFile(fileName);
      
      return [OutputLine("Loading world from " ~ fileName, vec3(1, 1, 1))];
    }
    else if (command == "clearworld")
    {
      m_playerShip = null;
      m_trashBin = null;
      m_dragEntity = null;
      m_debugDisplay = null;
      m_closestShipDisplay = null;
      m_dashboard = null;
      
      m_entities = null;
      
      foreach (subSystem; m_subSystems)
        subSystem.clearEntities();
        
      return [];
    }
    else if (command == "entities")
    {
      OutputLine[] lines;
      
      auto ids = m_entities.keys.dup;
      
      for (int n = 0; n < ids.length; n += 20)
        lines ~= OutputLine(to!string(ids[n..min(n+20, ids.length-1)]), vec3(1, 1, 1));
      
      lines ~= OutputLine("", vec3(1, 1, 1));
      
      return lines;
    }
    else if (command.startsWith("values"))
    {
      try
      {
        command.skipOver("values");
        
        int entityId = to!int(command.strip);
        
        if (entityId in m_entities)
        {
          string text = to!string(m_entities[entityId].values);
          
          OutputLine[] values;
          foreach (key, value; m_entities[entityId].values)
            values ~= OutputLine(key ~ ": " ~ to!string(value.until("\\n")), vec3(1, 1, 1));
          
          values ~= OutputLine("", vec3(1, 1, 1));
          
          return values;
        }
        else
          return [OutputLine("No entity with id " ~ to!string(entityId), vec3(1, 0.5, 0))];
      }
      catch (ConvException e)
      {
        return [OutputLine("Conversion error", vec3(1, 0, 0))];
      }
    }
    else if (command.startsWith("systems"))
    {
      try
      {
        command.skipOver("systems");
        
        int entityId = to!int(command.strip);
        
        if (entityId in m_entities)
        {
          string text = to!string(m_entities[entityId].values);
          
          auto entity = m_entities[entityId];
          
          OutputLine[] values;
          
          values ~= OutputLine("Entity " ~ to!string(entityId) ~ " is registered in: ", vec3(1, 1, 1));
          foreach (subSystem; m_subSystems)
          {
            auto name = subSystem.name;
            
            name.findSkip("SubSystem.");
            name.findSkip(".");
            
            if (subSystem.hasComponent(entity))
              values ~= OutputLine(name, vec3(1, 1, 1));
          }
          
          values ~= OutputLine("", vec3(1, 1, 1));
          
          return values;
        }
        else
          return [OutputLine("No entity with id " ~ to!string(entityId), vec3(1, 0.5, 0))];
      }
      catch (ConvException e)
      {
        return [OutputLine("Conversion error", vec3(1, 0, 0))];
      }
    }
    else if (command.startsWith("register"))
    {
      try
      {
        command.skipOver("register");
        
        int entityId = to!int(command.strip);
        
        if (entityId in m_entities)
        {
          registerEntity(m_entities[entityId]);
          
          return [OutputLine("Registered entity " ~ to!string(entityId), vec3(1, 1, 1))];
        }
        else
          return [OutputLine("No entity with id " ~ to!string(entityId), vec3(1, 0.5, 0))];
      }
      catch (ConvException e)
      {
        return [OutputLine("Conversion error", vec3(1, 0, 0))];
      }
    }
    else if (command.startsWith("set"))
    {
      try
      {
        command.skipOver("set");
        
        auto parameters = command.strip.split(" ");
        
        int entityId = to!int(parameters[0]);
        string key = parameters[1];
        string value = reduce!((a, b) => (a ~= " " ~ b))(parameters[2..$]);
        
        if (entityId in m_entities)
        {
          m_entities[entityId].setValue(key, value);
        
          string text = to!string(m_entities[entityId].values);
          
          return [OutputLine(to!string(text.until("\\n")), vec3(1, 1, 1))];
        }
        else
          return [OutputLine("No entity with id " ~ to!string(entityId), vec3(1, 0.5, 0))];
      }
      catch (ConvException e)
      {
        return [OutputLine("Conversion error", vec3(1, 0, 0))];
      }
    }
    else if (command.startsWith("new"))
    {
      command.skipOver("new");
      auto name = command.strip;
      
      auto newEntity = new Entity(["name": name]);
      
      m_entities[newEntity.id] = newEntity;
      
      return [OutputLine("Created new entity with id " ~ to!string(newEntity.id), vec3(1, 1, 1))];
    }
    
    return [OutputLine("?? " ~ command, vec3(1, 0, 0))];
  }

  
private:
  int updateCount()
  {
    return m_updateCount;
  }
  
  
  void update()
  {
    m_updateCount++;
    
    // TODO: make subsystem dedicated to removing entities. it should be responsible for values like lifetime and health 
    // TODO: ideally all this code should be handled by just setting values on the entity and then re-register it
    foreach (entity; filter!(entity => m_collider.hasComponent(entity))(m_entities.values))
    {
      auto colliderComponent = m_collider.getComponent(entity);

      // disconnect if no health left
      if (colliderComponent.health <= 0.0 && m_connector.hasComponent(entity))
      {
        writeln("no health left, disconnecting entity " ~ to!string(entity.id) ~ " with values " ~ to!string(entity.values));
        
        // de-control entity and all connected entities
        entity.setValue("control", "nothing");
        entity.setValue("collisionType", "FreeFloatingModule");
        entity.setValue("position", m_placer.getComponent(entity).position.toString());
        entity.setValue("angle", to!string(m_placer.getComponent(entity).angle));
        //entity.setValue("velocity", vec2(0.0, 0.0).toString());
        entity.setValue("force", vec2(0.0, 0.0).toString());
        
        m_controller.removeEntity(entity);
        m_spawner.removeEntity(entity);
        m_collider.registerEntity(entity);
        
        m_physics.registerEntity(entity);
        
        assert(m_collider.getComponent(entity).force.ok);
        assert(m_physics.getComponent(entity).force.ok);
        
        // disconnect all connected entities
        foreach (connectedEntity; m_connector.getConnectedEntities(entity))
        {
          connectedEntity.setValue("control", "nothing");
          connectedEntity.setValue("collisionType", "FreeFloatingModule");
          connectedEntity.setValue("owner", to!string(connectedEntity.id));
          m_controller.removeEntity(connectedEntity);
          m_spawner.removeEntity(entity);
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
        if ("health" in entity.values)
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
    
    auto entitiesToRemove = m_timer.getTimeoutEntities() ~ 
                            m_sound.getFinishedPlayingEntities() ~ 
                            m_collider.getNoHealthEntities();
    
    foreach (entityToRemove; entitiesToRemove)
      removeEntity(entityToRemove);
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      m_placer.setTimeStep(m_timer.elapsedTime);
      m_physics.setTimeStep(m_timer.elapsedTime);
      m_controller.setTimeStep(m_timer.elapsedTime);
      
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
      CommsCentral.setSoundFromPlacer(m_placer, m_sound);
      CommsCentral.setSoundFromSpawner(m_spawner, m_sound);
      //CommsCentral.setTimerFromCollider(m_collider, m_timer);
      //CommsCentral.setTimerFromSound(m_sound, m_timer);
      
      //CommsCentral.calculateCollisionResponse(m_collider, m_physics);
    }
    CommsCentral.setGraphicsFromPlacer(m_placer, m_graphics);
    
    m_fpsBuffer[m_updateCount % m_fpsBuffer.length] = floor(1.0 / m_timer.elapsedTime);
    
    if (m_graphics.hasComponent(m_debugDisplay))
    {
      auto debugDisplayComponent = m_graphics.getComponent(m_debugDisplay);
      
      if ("elements" in m_debugDisplay.values)
      {
        string elements = m_debugDisplay.getValue("elements");
        
        m_debugInfo = "";
        
        if (elements.find("FPS") != [])
        {
          int fpsValue = cast(int)(reduce!"a+b"(m_fpsBuffer)/m_fpsBuffer.length);
      
          if (fpsValue > 0)
            m_debugInfo ~= "FPS: " ~ to!string(fpsValue);
        }
        
        if (elements.find("entityCount") != [])
        {
          m_debugInfo ~= "\\nEntities: " ~ to!string(m_entities.length);
        }
        
        if (elements.find("subsystemTimings") != [])
        {
          m_debugInfo ~= m_timingInfo;
        }
        
        debugDisplayComponent.text = m_debugInfo;
      }
        
      m_graphics.setComponent(m_debugDisplay, debugDisplayComponent);
    }
    
    if (m_graphics.hasComponent(m_closestShipDisplay))
    {
      if (m_playerShip !is null)
      {
        auto playerPos = m_placer.getComponent(m_playerShip).position;        

        //auto closestEntity = findClosestEnemyShip(m_playerShip);
        auto closestEntity = findClosestShipGivenKeyValue(m_playerShip, "type", "enemy ship");
        
        if (closestEntity !is null)
        {
          auto closestEntityPosition = m_placer.getComponent(closestEntity).position - playerPos;
          auto closestEntityDistance = closestEntityPosition.length;
          
          auto closestShipDisplayComponent = m_graphics.getComponent(m_closestShipDisplay);
          
          auto pos = closestEntityPosition.normalized() * 0.9;
          auto txt = to!string(floor(closestEntityDistance));
          
          auto poscomp = m_placer.getComponent(m_closestShipDisplay);
          auto gfxcomp = m_graphics.getComponent(m_closestShipDisplay);
          
          poscomp.position = closestEntityPosition.normalized() * 0.9;
          gfxcomp.position = closestEntityPosition.normalized() * 0.9;
          gfxcomp.text = to!string(floor(closestEntityDistance));
          
          m_placer.setComponent(m_closestShipDisplay, poscomp);
          m_graphics.setComponent(m_closestShipDisplay, gfxcomp);
          
          auto ownedEntitiesWithGraphics = m_connector.getOwnedEntities(closestEntity).filter!(e => m_graphics.hasComponent(e));
          
          if (ownedEntitiesWithGraphics.empty == false)
            m_graphics.setTargetEntity(ownedEntitiesWithGraphics.front);
        }
      }
    }
    
    if (m_graphics.hasComponent(m_dashboard))
    {
      auto dashboardComponent = m_graphics.getComponent(m_dashboard);
      
      string dashboardText;
      
      if (m_playerShip !is null)
      {
        auto placerComponent = m_placer.getComponent(m_playerShip);
        dashboardText ~= "Position: " ~ to!string(round(placerComponent.position.x)) ~ " " ~ to!string(round(placerComponent.position.y)) ~ "\\n";
        dashboardText ~= "Speed: " ~ to!string(round(placerComponent.velocity.length)) ~ " m/s\\n";
        dashboardText ~= "Mass: " ~ to!string(m_physics.getComponent(m_playerShip).mass) ~ " tons";
      }
      
      dashboardComponent.text = dashboardText;
      
      m_graphics.setComponent(m_dashboard, dashboardComponent);
    }
    
    m_graphics.calculateMouseWorldPos(m_inputHandler.mousePos);
    m_dispenser.setMouseWorldPos(m_graphics.mouseWorldPos);
    
    foreach (spawnValues; m_spawner.getAndClearSpawnValues())
    {
      //assert("source" in spawnValues, "Could not find source value in spawnvalues: " ~ to!string(spawnValues));
      
      if ("source" in spawnValues)
        loadShip(spawnValues["source"], spawnValues);
      else
      {
        //writeln("loading values " ~ to!string(spawnValues));
        //loadEntityCollection("", spawnValues);
        loadEntity("", spawnValues);
      }
    }
    
    foreach (spawnParticleValues; m_collider.getAndClearSpawnParticleValues())
    {
      Entity particle = new Entity(spawnParticleValues);
      
      registerEntity(particle);
    }
    
    // update target values for control components
    foreach (entity; m_entities)
    {
      if (m_controller.hasComponent(entity))
      {
        auto controlComponent = m_controller.getComponent(entity);
        
        string target = controlComponent.target;
        
        if (target == "closestEnemy")
        {
          auto closestEnemy = findClosestShipGivenKeyValue(entity, "type", "enemy ship");
          
          if (closestEnemy !is null)
          {
            auto closestEnemyComponent = m_placer.getComponent(closestEnemy);
            
            controlComponent.targetPosition = closestEnemyComponent.position;
            controlComponent.targetVelocity = closestEnemyComponent.velocity;
          }
        }
        else if (target == "player")
        {
          if (m_playerShip !is null)
          {
            controlComponent.targetPosition = m_placer.getComponent(m_playerShip).position;
            controlComponent.targetVelocity = m_placer.getComponent(m_playerShip).velocity;
          }
        }
        else if (target.startsWith("closestTeam."))
        {
          target.skipOver("closestTeam.");
          
          auto closestShip = findClosestShipGivenKeyValue(entity, "team", target);
          
          if (closestShip !is null)
          {
            auto closestShipComponent = m_placer.getComponent(closestShip);
            
            controlComponent.targetPosition = closestShipComponent.position;
            controlComponent.targetVelocity = closestShipComponent.velocity;
          }
        }
      }
    }
    
    m_entityConsole.display(m_graphics, m_timer.totalTime);
    m_gameConsole.display(m_graphics, m_timer.totalTime);
    
    handleInput(m_timer.elapsedTime);
    
    SDL_Delay(10);
  }
  
  
  void handleInput(float p_elapsedTime)
  {
    m_gameConsole.handleInput(m_inputHandler);
    m_entityConsole.handleInput(m_inputHandler);

    foreach (control; m_controller.controls.values)
    {
      control.consoleActive = m_gameConsole.isActive() || m_entityConsole.isActive();
    }
  
    if (m_inputHandler.isPressed(Event.LeftButton))
    {
      // TODO: if we have a dragentity we must ensure it stops getting dragged before it's destroyed or removed by something - lifetime expiration for bullets for example
      if (m_dragEntity is null)
      {
        foreach (draggable; filter!(entity => entity.getValue("draggable") == "true" && 
                                    m_graphics.hasComponent(entity) &&
                                    m_graphics.getComponent(entity).screenAbsolutePosition == false)(m_entities.values))
        {
          assert(m_graphics.hasComponent(draggable), "Couldn't find graphics component for draggable entity " ~ to!string(draggable.values) ~ " with id " ~ to!string(draggable.id));
          
          auto dragGfxComp = m_graphics.getComponent(draggable);
          
          if ((dragGfxComp.position - m_graphics.mouseWorldPos).length < dragGfxComp.radius)
          {
            //writeln("mouseover on draggable entity " ~ to!string(draggable.id) ~ " with " ~ to!string(m_connector.getConnectedEntities(draggable).length) ~ " connected entities and " ~ to!string(m_connector.getOwnedEntities(draggable).length) ~ " owned entities");
            
            // we don't want to drag something if it has stuff connected to it, or owns something. 
            // if you want to drag a skeleton module, you should drag off all connected modules first
            // TODO: should be possible to drag stuff with connected stuff, but drag'n'drop needs to be more robust first            
            if (m_connector.getConnectedEntities(draggable).length > 0 || m_connector.getOwnedEntities(draggable).length > 0)
              continue;

            m_dragEntity = draggable;
            
            break;
          }
        }

        // ok, we picked up an entity. now what do we do with it?
        if (m_dragEntity !is null)
        {
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
                
                auto match = find!(entity => entity.id == to!int(dragEntityConnection[0]))(m_entities.values);
                
                if (match.empty == false)
                {
                  connectEntity = match.front;
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
        
        // delete entities dropped in the trashbin, but don't delete the trashbin...
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
                
              // in case the module launches missiles, set target so that missiles will have a target to home in to
              m_dragEntity.setValue("spawn.*.target", "closestEnemy");
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
    
    if (m_inputHandler.eventState(Event.RightButton) == EventState.Released)
    {
      /*auto clickedEntities = find!(entity => entity != m_playerShip && 
                                   entity.getValue("radius").length > 0 &&
                                   entity.getValue("ScreenAbsolutePosition") != "true" &&
                                   m_placer.hasComponent(entity) && 
                                   (m_placer.getComponent(entity).position - m_graphics.mouseWorldPos).length < to!float(entity.getValue("radius")) &&
                                   m_connector.hasComponent(entity))(m_entities.values);*/
    
      auto clickedEntities = find!(entity => entity.getValue("ScreenAbsolutePosition") != "true" &&
                                             entity.getValue("radius").length > 0 &&
                                             m_placer.hasComponent(entity) && 
                                             (m_placer.getComponent(entity).position - m_graphics.mouseWorldPos).length < to!float(entity.getValue("radius")))
                                  (m_entities.values);

                                  
      if (!clickedEntities.empty)
      {
        auto entity = clickedEntities[0];
        
        m_entityConsole.setEntity(entity);
      }
      else
      {
        m_entityConsole.setEntity(null);
      }
    
      /*foreach (entity; filter!(entity => entity != m_playerShip && 
                                         entity.getValue("radius").length > 0 &&
                                         m_placer.hasComponent(entity) && 
                                         (m_placer.getComponent(entity).position - m_graphics.mouseWorldPos).length < to!float(entity.getValue("radius")) &&
                                         m_connector.hasComponent(entity))(m_entities.values))
      {
        /*auto entityOwner = m_connector.getComponent(entity).owner;
        
        // we don't want to control modules floating by themself not connected to anything... or do we?
        if (entityOwner.id == entity.id)
          continue;
        
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
          if (ownedEntity.getValue("source").find("engine.txt").empty == false)
            ownedEntity.setValue("control", "playerEngine");

          if (ownedEntity.getValue("source").find("cannon.txt").empty == false || ownedEntity.getValue("source").find("launcher.txt").empty == false)
            ownedEntity.setValue("control", "playerLauncher");

          //registerEntity(ownedEntity);
          m_controller.registerEntity(ownedEntity);
        }
        
        break;
      }*/
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
  
  void loadEntity(string p_fileName, string[string] p_extraParams = null)
  {
    string[string] values;
    
    if (p_fileName.length > 0)
      values = loadValues(cache, p_fileName);
      
    foreach (extraKey, extraValue; p_extraParams)
      values[extraKey] = extraValue;
      
    registerEntity(new Entity(values));
  }
  
  void loadEntityCollection(string p_fileName, string[string] p_extraParams = null)
  {
    //writeln("loading entity collection from " ~ p_fileName ~ " with extravalues " ~ to!string(p_extraParams));
    
    Entity[] entities;
    
    string[string] values;
    
    if (p_fileName.length > 0)
      values = loadValues(cache, p_fileName);
      
    foreach (extraKey, extraValue; p_extraParams)
      values[extraKey] = extraValue;
      
    auto childrenValues = findChildrenValues(cache, values);
    
    values = parseRandomizedValues(values);
    
    // no need for mainentity, they should not be connected in this case
    
    foreach (childName, childValues; childrenValues)
    {
      childValues = parseRandomizedValues(childValues);
      
      registerEntity(new Entity(childValues));
    }

    //return entities;
  }
  
  Entity loadShip(string p_fileName, string[string] p_extraParams = null)
  {
    //debug writeln("loading ship from file " ~ p_fileName ~ ", with extraparams " ~ to!string(p_extraParams));
    
    string[string] values;

    if (p_fileName.length > 0)
      values = loadValues(cache, p_fileName);
    
    //writeln("values after load: " ~ to!string(values));
    
    foreach (extraKey, extraValue; p_extraParams)
      values[extraKey] = extraValue;
    
    auto childrenValues = findChildrenValues(cache, values);
    
    values = parseRandomizedValues(values);
    
    auto mainEntity = new Entity(values);
    
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
      if ("position" !in childEntities[childName].values)
        childEntities[childName].setValue("position", mainEntity.getValue("position"));
    }
    
    assert(accumulatedMass >= 0.0);
    
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
    
    if (childEntities.length > 0)
      mainEntity.setValue("owner", to!string(mainEntity.id));
    
    registerEntity(mainEntity);
    
    foreach (childEntityName, childEntity; childEntities)
    {
      if (childEntityName !in childDependency)
      {
        registerEntity(childEntity);
      }
    }
    
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
  

  public void registerEntity(Entity p_entity)
  {
    //assert(p_entity.id !in m_entities, "Tried registering entity " ~ to!string(p_entity.id) ~ " that was already registered");
    
    m_entities[p_entity.id] = p_entity;
    
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with name " ~ p_entity.getValue("name"));
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with values " ~ to!string(p_entity.values));
    
    if (p_entity.getValue("name") == "Debug display")
      m_debugDisplay = p_entity;
      
    if (p_entity.getValue("name") == "trashbin")
      m_trashBin = p_entity;
    
    if (p_entity.getValue("name") == "playership")
      m_playerShip = p_entity;
      
    if (p_entity.getValue("name") == "Closest ship display")
      m_closestShipDisplay = p_entity;
      
    if (p_entity.getValue("name") == "Dashboard")
      m_dashboard = p_entity;
    
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
  // TODO: ConnectionHandler should handle this
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
    //writeln("setting accumulated mass to " ~ to!string(accumulatedMass));
    assert(isFinite(physComp.mass));
    m_physics.setComponent(p_ownerEntity, physComp);
    
    auto ownerConnectComp = m_connector.getComponent(p_ownerEntity);
    auto originalCenterOfMass = ownerConnectComp.relativePositionToCenterOfMass;
    
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
    
    writeln("centerofmass: " ~ to!string(centerOfMass) ~ ", original com: " ~ to!string(originalCenterOfMass) ~ ", physcomp position: " ~ to!string(physComp.position));
    
    //ownerConnectComp.relativePositionToCenterOfMass = ownerConnectComp.position - centerOfMass;
    //m_placer.getComponent(p_ownerEntity).position = ownerConnectComp.position + (centerOfMass - originalCenterOfMass);
    //physComp.position += (centerOfMass - originalCenterOfMass);
    //physComp.position -= originalCenterOfMass;
    
    //ownerConnectComp.relativePositionToCenterOfMass = centerOfMass;
  }
  
  
private:
  void updateSubSystems()
  {
    // the sdl/gl stuff in the graphics subsystem needs to run in the main thread for stuff to be shown on the screen
    // so we filter the graphics subsystem out of the subsystem list 
    // and explicitly update it outside the parallel foreach to ensure it runs in the main thread
    //debug
    //{
      StopWatch subSystemTimer;
      subSystemTimer.reset();
      subSystemTimer.start();
    //}
    
    //debug m_graphics.updateWithTiming();
    //else  m_graphics.update();
    m_graphics.updateWithTiming();
    foreach (subSystem; taskPool.parallel(filter!(sys => sys !is m_graphics)(m_subSystems.values), 1))
    //foreach (subSystem; filter!(sys => sys !is m_graphics)(m_subSystems.values))
    {
      //debug subSystem.updateWithTiming();
      //else  subSystem.update();
      subSystem.updateWithTiming();
    }
    //debug
    {
      subSystemTimer.stop();
      float timeSpent = subSystemTimer.peek.usecs / 1_000_000.0;
    
      float subSystemTime = reduce!((total, sys) => total + sys.timeSpent)(0.0, m_subSystems.values);
    
      static float[60] subSystemTimeBuffer = 0.0;
      
      subSystemTimeBuffer[m_updateCount % subSystemTimeBuffer.length] = subSystemTime;
    
      float avgSubSystemTime = reduce!"a+b"(subSystemTimeBuffer) / subSystemTimeBuffer.length;
    
      m_timingInfo = "";
    
      m_timingInfo ~= "\\nSubsystem update spent " ~ to!string(roundTo!int(avgSubSystemTime*1000)) ~ "ms"; //, time saved parallelizing: " ~ to!string(roundTo!int((subSystemTime - timeSpent)*1000));
          
      foreach (name, sys; m_subSystems)
        //m_timingInfo ~= "\\n  " ~ name ~ ": " ~ to!string(sys.components.length) ~ ", " ~ to!string(roundTo!int((sys.timeSpent/subSystemTime) * 100)) ~ "%";
        m_timingInfo ~= "\\n  " ~ name ~ ": " ~ sys.debugInfo(subSystemTime);
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
    
    if ("team" in inValues && inValues["team"].find("to").length > 0)
    {
      auto teamData = inValues["team"].split(" ");
      
      assert(teamData.length == 3, "Problem parsing team data with from/to values: " ~ to!string(teamData));
      
      int minTeam = to!int(teamData[0]);
      int maxTeam = to!int(teamData[2]);
      
      auto team = uniform(minTeam, maxTeam+1);
      
      outValues["team"] = to!string(team);
    }
    
    return outValues;
  }
    
  
  Entity findClosestShipGivenKeyValue(Entity p_entity, string key, string value)
  {
    auto entityPosition = m_placer.getComponent(p_entity).position;
    
    auto candidates = filter!(entity => entity.id != p_entity.id && entity.getValue(key) == value)(m_entities.values);
    
    //writeln("closestshipgivenkeyvalue candidates: " ~ to!string(candidates.array.length));
    
    if (candidates.empty)
      return null;
      
    Entity closestEntity = reduce!((closestSoFar, entity) =>
      ((m_connector.getComponent(closestSoFar).position - entityPosition).length < 
       (m_connector.getComponent(entity).position - entityPosition).length) ? closestSoFar : entity)
    (candidates);

    return closestEntity;
  }
  
  
private:
  int m_updateCount;
  bool m_running;
  
  bool m_paused;
  
  InputHandler m_inputHandler;
  
  GameConsole m_gameConsole;
  EntityConsole m_entityConsole;
  
  SubSystem.Base.SubSystem[string] m_subSystems;
  public Placer m_placer;
  Physics m_physics;
  Graphics m_graphics;
  Controller m_controller;
  ConnectionHandler m_connector;
  CollisionHandler m_collider;
  Spawner m_spawner;
  Sound m_sound;
  Timer m_timer;
  
  Starfield m_starfield;
  
  Entity[int] m_entities;
  
  // special entities.. do they really need to be hardcoded?
  Entity m_playerShip;
  Entity m_trashBin;
  Entity m_dragEntity;
  Entity m_debugDisplay;
  Entity m_closestShipDisplay;
  Entity m_dashboard;
  
  float[60] m_fpsBuffer;
  
  string m_debugInfo;
  string m_timingInfo;
  
  Dispenser m_dispenser;
  
  string[][string] cache;
}
