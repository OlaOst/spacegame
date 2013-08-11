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
import std.range;
import std.stdio;
import std.string;

import derelict.sdl2.sdl;

import gl3n.linalg;
import gl3n.math;

import Control.AiChaser;
import Control.AiGunner;
import Control.Flocker;
import Control.Dispenser;
import Control.MouseFollower;
import Control.PlayerEngine;
import Control.PlayerLauncher;
import Control.RiftTracker;

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
import SubSystem.Controller;
import SubSystem.Graphics;
import SubSystem.Kinetics;
import SubSystem.Physics;
import SubSystem.Placer;
import SubSystem.RelationHandler;
import SubSystem.Sound;
import SubSystem.Spawner;
import SubSystem.Timer;


// Game class has too many dependencies at the moment for unittesting to make sense
/*unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
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
}*/


class Game
{
public:
  this()
  {
    version (integrationtest)    
      rootDir = "tests/";
    else
      rootDir = "data/";
    
    m_updateCount = 0;
    m_running = true;
    m_paused = false;
    
    m_inputHandler = new InputHandler();
    
    int xres = 1280;
    int yres = 800;

    
    m_subSystems["Placer"] = m_placer = new Placer();
    m_subSystems["Kinetics"] = m_kinetics = new Kinetics();
    m_subSystems["Graphics"] = m_graphics = new Graphics(cache, xres, yres);
    m_subSystems["Physics"] = m_physics = new Physics();
    m_subSystems["Controller"] = m_controller = new Controller();
    m_subSystems["CollisionHandler"] = m_collisionHandler = new CollisionHandler();
    m_subSystems["Sound"] = m_sound = new Sound(64);
    m_subSystems["Spawner"] = m_spawner = new Spawner();
    m_subSystems["Timer"] = m_timer = new Timer();
    m_subSystems["RelationHandler"] = m_relationHandler = new RelationHandler();

    m_gameConsole = new GameConsole(this);
    m_entityConsole = new EntityConsole(this);
    
    assert(m_controller !is null);
    
    m_controller.controls["AiGunner"] = new AiGunner();
    m_controller.controls["Chaser"] = new AiChaser();
    m_controller.controls["Dispenser"] = m_dispenser = new Dispenser(m_inputHandler);
    m_controller.controls["PlayerLauncher"] = new PlayerLauncher(m_inputHandler);
    m_controller.controls["PlayerEngine"] = new PlayerEngine(m_inputHandler);
    m_controller.controls["MouseFollower"] = m_mouseFollower = new MouseFollower(m_inputHandler);
    m_controller.controls["RiftTracker"] = m_riftTracker = new RiftTracker(m_inputHandler);
    
    //SDL_EnableUNICODE(1);
    
    //m_starfield = new Starfield(m_graphics, 1000.0);

    m_inputHandler.setScreenResolution(xres, yres);
  }
 
  void loadWorldFromFile(string p_fileName)
  {
    auto fixedFileName = p_fileName;
    if (fixedFileName.startsWith(rootDir) == false)
      fixedFileName = rootDir ~ p_fileName;
    
    string[] fileLines;
    foreach (string line; fixedFileName.File.lines)
      fileLines ~= line;
    
    string[] orderedEntityNames;
    auto entities = EntityLoader.loadEntityCollection("world", fileLines, orderedEntityNames, rootDir);

    foreach (name; orderedEntityNames)
    {
      assert(name in entities, "Could not find entity named " ~ name ~ ", existing entity names: " ~ entities.keys.to!string);
      
      //debug writeln("registering entity " ~ name ~ " with values " ~ entities[name].values.to!string);
      
      registerEntity(entities[name]);
    }
  }
 
 
  void run()
  {  
    while (m_running)
    {
      update(m_timer.elapsedTime);
    }
  }
  
  
  void runIntegrationTest(string outputFile)
  {
    update(1.0); // update 1 second
    
    auto output = File(outputFile, "w");
    
    foreach (entity; m_entities)
    {
      foreach (subSystem; m_subSystems)
      {
        subSystem.updateEntity(entity);
      }
      
      foreach (key, value; entity.values)
      {
        string name = "name" in entity.values ? entity["name"] : entity.id.to!string;
        output.writeln(name ~ "." ~ key ~ " = " ~ value);
      }
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
      m_debugDisplay = null;
      m_entityMatrix = null;
      m_closestShipDisplay = null;
      m_dashboard = null;
      m_mouseCursor = null;
      
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
  
  
  string getEntityMatrix()
  {
    int colWidth = 8;
    string text;

    foreach (subSystem; m_subSystems)
    {
      auto name = subSystem.name;
      
      while (name.findSkip(".")) {}
      
      text ~= name[0..min(colWidth, $)].leftJustify(colWidth, ' ') ~ " ";
    }
    
    text ~= "\n";
    
    foreach (entity; sort!((left, right) => left.id > right.id)(m_entities.values))
    {
      foreach (subSystem; m_subSystems)
      {
        if (subSystem.hasComponent(entity))
          text ~= "X".leftJustify(colWidth, ' ') ~ " ";
        else
          text ~= "_".leftJustify(colWidth, ' ') ~ " ";
      }
        
      text ~= " - ";
        
      if ("name" in entity)
        text ~= entity["name"];
      else
        text ~= entity.id.to!string;
        
      text ~= "\n";
    }
    
    text ~= "\n";
    
    foreach (entity; sort!((left, right) => left.id > right.id)(m_entities.values))
    {
      text ~= entity.values.to!string ~ "\n";
    }
    
    return text;
  }
  
  void update(float elapsedTime)
  {
    m_updateCount++;
    
    // TODO: make subsystem dedicated to removing entities. it should be responsible for values like lifetime and health 
    // TODO: ideally all this code should be handled by just setting values on the entity and then re-register it
    /+foreach (entity; filter!(entity => m_collisionHandler.hasComponent(entity))(m_entities.values))
    {
      auto colliderComponent = m_collisionHandler.getComponent(entity);
    }+/
    
    auto entitiesToRemove = m_timer.getTimeoutEntities() ~ 
                            m_sound.getFinishedPlayingEntities() ~ 
                            m_collisionHandler.getNoHealthEntities();
    
    foreach (entityToRemove; entitiesToRemove)
      removeEntity(entityToRemove);
    
    m_inputHandler.pollEvents();

    //debug writeln("game update " ~ m_updateCount.to!string);
    
    if (!m_paused)
    {
      m_kinetics.setTimeStep(elapsedTime);
      m_physics.setTimeStep(elapsedTime);
      m_controller.setTimeStep(elapsedTime);
      m_graphics.setTimeStep(elapsedTime);
      m_spawner.setTimeStep(elapsedTime);
      
      // TODO: rename Placer to Kinetics?
      
      // alternate update loop:
      // update controllers
      // set force/torque from controllers to physics
      // set triggers from controllers to spawners
      // update spawners
      // set force/torque from spawners to physics
      // update physics
      // set position/velocity/force/torque from physics to collision
      // set position/velocity from physics to placer
      // update collision
      // set force/torque from collision to physics
      // set position/velocity from collision to placer
      // update placer
      // set position/velocity from placer to controllers
      
      // alternative 2 update loop:
      // update all systems that can set forces
      // transfer forces from those subsystems, most significant last, to overwrite force values properly (should we overwrite or append?)
      // update all systems that can set velocities
      // transfer velocities to systems that need them, in specified order
      // update all systems that can set positions
      
      m_spawner.updateWithTiming();
      
      CommsCentral.setPhysicsFromSpawner(m_spawner, m_physics);
      CommsCentral.setSoundFromSpawner(m_spawner, m_sound);
      
      m_physics.updateWithTiming();
      
      CommsCentral.setKineticsFromPhysics(m_physics, m_kinetics);
      CommsCentral.setCollisionHandlerFromPhysics(m_physics, m_collisionHandler);
      CommsCentral.setSpawnerFromPhysics(m_physics, m_spawner);
      
      m_collisionHandler.updateWithTiming();
      
      CommsCentral.setPlacerFromCollisionHandler(m_collisionHandler, m_placer);
      CommsCentral.setKineticsFromCollisionHandler(m_collisionHandler, m_kinetics);
      CommsCentral.setPhysicsFromCollisionHandler(m_collisionHandler, m_physics);
      debug CommsCentral.setGraphicsFromCollisionHandler(m_collisionHandler, m_graphics);
      
      m_controller.updateWithTiming();
      
      CommsCentral.setPlacerFromController(m_controller, m_placer);
      CommsCentral.setPhysicsFromController(m_controller, m_physics);
      CommsCentral.setSpawnerFromController(m_controller, m_spawner);
      
      m_relationHandler.updateWithTiming();
      
      CommsCentral.setControllerFromRelation(m_relationHandler, m_controller);
      CommsCentral.setPlacerFromRelation(m_relationHandler, m_placer);
      CommsCentral.setPhysicsFromRelation(m_relationHandler, m_physics);
      
      m_kinetics.updateWithTiming();
      
      CommsCentral.setPlacerFromKinetics(m_kinetics, m_placer);
      
      m_placer.updateWithTiming();

      CommsCentral.setControllerFromPlacer(m_placer, m_controller);
      CommsCentral.setCollisionHandlerFromPlacer(m_placer, m_collisionHandler);
      CommsCentral.setSpawnerFromPlacer(m_placer, m_spawner);
      CommsCentral.setSoundFromPlacer(m_placer, m_sound);
      CommsCentral.setRelationFromPlacer(m_placer, m_relationHandler);
      
      m_sound.updateWithTiming();
      m_timer.updateWithTiming();
      
      ///m_subSystems["Placer"] = m_placer = new Placer();
      ///m_subSystems["Graphics"] = m_graphics = new Graphics(cache, xres, yres);
      ///m_subSystems["Physics"] = m_physics = new Physics();
      ///m_subSystems["Controller"] = m_controller = new Controller();
      ///m_subSystems["CollisionHandler"] = m_collisionHandler = new CollisionHandler();
      ///m_subSystems["Sound"] = m_sound = new Sound(64);
      ///m_subSystems["Spawner"] = m_spawner = new Spawner();
      ///m_subSystems["Timer"] = m_timer = new Timer();
      ///m_subSystems["RelationHandler"] = m_relationHandler = new RelationHandler();
      
      /+updateSubSystems();
      
      CommsCentral.setSpawnerFromController(m_controller, m_spawner);
      
      //setSoundFromControl
      CommsCentral.setSoundFromSpawner(m_spawner, m_sound);
      //setSoundFromCollision
      
      CommsCentral.setPhysicsFromController(m_controller, m_physics);
      CommsCentral.setPhysicsFromSpawner(m_spawner, m_physics);
      CommsCentral.setPhysicsFromCollisionHandler(m_collisionHandler, m_physics);
      
      CommsCentral.setPlacerFromPhysics(m_physics, m_placer);
      CommsCentral.setPlacerFromCollisionHandler(m_collisionHandler, m_placer);
      CommsCentral.setPlacerFromRelation(m_relationHandler, m_placer);
      CommsCentral.setPlacerFromController(m_controller, m_placer);
      
      CommsCentral.setCollisionHandlerFromPhysics(m_physics, m_collisionHandler);
      
      CommsCentral.setControllerFromPlacer(m_placer, m_controller);
      CommsCentral.setCollisionHandlerFromPlacer(m_placer, m_collisionHandler);
      CommsCentral.setSpawnerFromPlacer(m_placer, m_spawner);
      CommsCentral.setSoundFromPlacer(m_placer, m_sound);
      CommsCentral.setRelationFromPlacer(m_placer, m_relationHandler);
      
      //CommsCentral.setTimerFromCollider(m_collider, m_timer);
      //CommsCentral.setTimerFromSound(m_sound, m_timer);
      
      //CommsCentral.calculateCollisionResponse(m_collider, m_physics);+/
    }
    CommsCentral.setGraphicsFromPlacer(m_placer, m_graphics);
    CommsCentral.setGraphicsFromCollisionHandler(m_collisionHandler, m_graphics);
    
    m_graphics.updateWithTiming();
    
    
    m_fpsBuffer[m_updateCount % m_fpsBuffer.length] = floor(1.0 / elapsedTime);
    
    if (m_graphics.hasComponent(m_debugDisplay))
    {
      auto debugDisplayComponent = m_graphics.getComponent(m_debugDisplay);
      
      if ("elements" in m_debugDisplay.values)
      {
        string elements = m_debugDisplay.getValue("elements");
        
        string debugInfo = "";
        
        if (elements.find("FPS") != [])
        {
          int avgFps = cast(int)(reduce!"a+b"(m_fpsBuffer)/m_fpsBuffer.length);
          int maxFps = cast(int)(m_fpsBuffer[].minCount!"a > b"[0]);
          int minFps = cast(int)(m_fpsBuffer[].minCount!"a < b"[0]);
          
          if (avgFps > 0)
            debugInfo ~= "FPS: " ~ avgFps.to!string ~ ", min/max: " ~ minFps.to!string ~ "/" ~ maxFps.to!string;
            //m_debugInfo ~= "FPS: " ~ avgFps.to!string ~ ", buffer: " ~ m_fpsBuffer.to!string;
        }
        
        if (elements.find("entityCount") != [])
        {
          debugInfo ~= "\\nEntities: " ~ to!string(m_entities.length);
        }
        
        if (elements.find("subsystemTimings") != [])
        {
          debugInfo ~= m_timingInfo;
        }
        
        debugDisplayComponent.text = debugInfo;
      }
        
      m_graphics.setComponent(m_debugDisplay, debugDisplayComponent);
    }
    
    if (m_graphics.hasComponent(m_entityMatrix))
    {
      auto entityMatrixComponent = m_graphics.getComponent(m_entityMatrix);
      
      /*string text;
      
      foreach (subSystem; m_subSystems)
      {
        auto name = subSystem.name;
        
        while (name.findSkip(".")) {}
        
        text ~= name[0..1] ~ " ";
      }
      
      text ~= "\\n";
      
      foreach (entity; sort!((left, right) => left.id > right.id)(m_entities.values))
      {
        foreach (subSystem; m_subSystems)
        {
          if (subSystem.hasComponent(entity))
            text ~= "X ";
          else
            text ~= "_ ";
        }
          
        text ~= " - ";
          
        if ("name" in entity)
          text ~= entity["name"];
        else
          text ~= entity.id.to!string();
          
        text ~= "\\n";
      }*/
      
      //writeln("text length: " ~ text.length.to!string);
      
      auto text = getEntityMatrix();
      
      entityMatrixComponent.text = text[0..min(text.length, 1000)];
      
      m_graphics.setComponent(m_entityMatrix, entityMatrixComponent);
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
          
          //auto ownedEntitiesWithGraphics = m_connector.getOwnedEntities(closestEntity).filter!(e => m_graphics.hasComponent(e));
          
          //if (ownedEntitiesWithGraphics.empty == false)
            //m_graphics.setTargetEntity(ownedEntitiesWithGraphics.front);
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
        auto kineticsComponent = m_kinetics.getComponent(m_playerShip);
        
        dashboardText ~= "Position: " ~ to!string(round(placerComponent.position.x)) ~ " " ~ to!string(round(placerComponent.position.y)) ~ "\\n";
        dashboardText ~= "Speed: " ~ to!string(round(kineticsComponent.velocity.length)) ~ " m/s\\n";
        dashboardText ~= "Mass: " ~ to!string(m_physics.getComponent(m_playerShip).mass) ~ " tons";
      }
      
      dashboardComponent.text = dashboardText;
      
      m_graphics.setComponent(m_dashboard, dashboardComponent);
    }
    
    m_graphics.calculateMouseWorldPos(m_inputHandler.mousePos);
    
    m_mouseFollower.setMouseWorldPos(m_graphics.mouseWorldPos);
    m_dispenser.setMouseWorldPos(m_graphics.mouseWorldPos);
    
    foreach (spawnValues; m_spawner.getAndClearSpawnValues())
    {
      //assert("source" in spawnValues, "Could not find source value in spawnvalues: " ~ to!string(spawnValues));
      
      /*if ("source" in spawnValues)
        loadShip(spawnValues["source"], spawnValues);
      else
      {
        //writeln("loading values " ~ to!string(spawnValues));
        //loadEntityCollection("", spawnValues);
        loadEntity("", spawnValues);
      }*/
      
      string[] orderedEntityNames;
      
      //debug writeln("spawnvalues: " ~ spawnValues.to!string);
      
      auto entities = loadEntityCollection("spawnstuff", spawnValues, orderedEntityNames, rootDir);
      
      foreach (name; orderedEntityNames)
      {
        if (name == "spawnstuff.*") continue;
        
        //debug writeln("spawning " ~ name ~ " with values " ~ entities[name].values.to!string);
        registerEntity(entities[name]);
      }
    }
    
    foreach (spawnParticleValues; m_collisionHandler.getAndClearSpawnParticleValues())
    {
      Entity particle = new Entity(spawnParticleValues);
      
      //debug writeln("spawning particle with values " ~ particle.values.to!string);
      
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
            //controlComponent.targetVelocity = closestEnemyComponent.velocity;
          }
        }
        else if (target == "player")
        {
          if (m_playerShip !is null)
          {
            controlComponent.targetPosition = m_placer.getComponent(m_playerShip).position;
            //controlComponent.targetVelocity = m_placer.getComponent(m_playerShip).velocity;
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
            //controlComponent.targetVelocity = closestShipComponent.velocity;
          }
        }
      }
    }
    
    //m_entityConsole.display(m_graphics, m_timer.totalTime);
    //m_gameConsole.display(m_graphics, m_timer.totalTime);
    
    handleInput(elapsedTime);
    
    SDL_Delay(5);
  }
  
  
  void handleInput(float p_elapsedTime)
  {
    m_gameConsole.handleInput(m_inputHandler);
    m_entityConsole.handleInput(m_inputHandler);

    foreach (control; m_controller.controls.values)
    {
      control.consoleActive = m_gameConsole.isActive() || m_entityConsole.isActive();
    }
  
    // mousecursor entities should set control to MouseFollower, no need to do stuff here then
    /*if (m_mouseCursor !is null)
    {
      //m_mouseCursor.values["position"] = m_graphics.mouseWorldPos.to!string;
      m_mouseCursor.values["position"] = m_inputHandler.mousePos.to!string;
      
      registerEntity(m_mouseCursor);
    }*/
    
    if (m_inputHandler.eventState(Event.RightButton) == EventState.Released)
    {
      /*auto clickedEntities = find!(entity => entity != m_playerShip && 
                                   entity.getValue("radius").length > 0 &&
                                   entity.getValue("ScreenAbsolutePosition") != "true" &&
                                   m_placer.hasComponent(entity) && 
                                   (m_placer.getComponent(entity).position - m_graphics.mouseWorldPos).length < to!float(entity.getValue("radius")) &&
                                   m_connector.hasComponent(entity))(m_entities.values);*/
    
      auto infoEntities = m_entities.values.filter!(entity => "infoentity" in entity);
      foreach (infoEntity; infoEntities)
        removeEntity(infoEntity);
    
      auto clickedEntities = find!(entity => entity.getValue("screenAbsolutePosition") != "true" &&
                                             entity.getValue("radius").length > 0 &&
                                             m_placer.hasComponent(entity) && 
                                             (m_placer.getComponent(entity).position - m_graphics.mouseWorldPos).length < entity.getValue("radius").to!float)
                                  (m_entities.values);
      
      if (!clickedEntities.empty)
      {
        auto entity = clickedEntities[0];
        
        //m_entityConsole.setEntity(entity);
        
        string[string] infoText;
        infoText["name"] = "infotext";
        infoText["infoentity"] = "text";
        infoText["isRelation"] = "true";
        infoText["position"] = m_graphics.mouseWorldPos.to!string;
        infoText["control"] = "MouseFollower";
        infoText["radius"] = 0.05.to!string;
        infoText["text"] = "";
        foreach (key, value; entity.values)
          infoText["text"] ~= key ~ ": " ~ value ~ "\\n";
        
        auto infoTextEntity = new Entity(infoText);
        
        string[string] infoBox;
        infoBox["name"] = "infobox";
        infoBox["infoentity"] = "box";
        
        auto textboxsize = 0.05;
        infoBox["color"] = vec4(0.0, 0.0, 0.0, 0.75).to!string;
        infoBox["drawsource"] = "Rectangle";
        auto textBox = m_graphics.getStringBox(infoText["text"], infoText["radius"].to!float);
        infoBox["lowerleft"] = textBox.min.to!string;
        infoBox["upperright"] = textBox.max.to!string;
        infoBox["position"] = (m_graphics.mouseWorldPos + textBox.half_extent.xy.vec2 + vec2(-textboxsize, textboxsize)).to!string;
        infoBox["owner"] = infoTextEntity.id.to!string;
        infoBox["relationName"] = infoText["name"];
        infoBox["relativePosition"] = (textBox.half_extent.xy.vec2 + vec2(-textboxsize, textboxsize)).to!string;
        //infoBox["radius"] = textboxsize.to!string;
        
        //writeln("infobox relative pos: " ~ infoBox["relativePosition"]);
        //writeln(textBox.to!string);
        
        auto infoBoxEntity = new Entity(infoBox);
        
        registerEntity(infoTextEntity);
        registerEntity(infoBoxEntity);
      }
    }  
  
    if (m_inputHandler.isPressed(Event.PageUp))
    {
      m_graphics.zoomIn(p_elapsedTime * 2.0);
    }
    /*if (m_inputHandler.isPressed(Event.WheelUp))
    {
      m_graphics.zoomIn(p_elapsedTime * 15.0);
    }*/
    if (m_inputHandler.isPressed(Event.PageDown))
    {
      m_graphics.zoomOut(p_elapsedTime * 2.0);
    }
    /*if(m_inputHandler.isPressed(Event.WheelDown))
    {
      m_graphics.zoomOut(p_elapsedTime * 15.0);
    }*/

    if (m_inputHandler.eventState(Event.Escape) == EventState.Released)
      m_running = false;

    if (m_inputHandler.eventState(Event.Pause) == EventState.Released)
    {
      m_paused = !m_paused;
    }
  }
  
  public void registerEntity(Entity p_entity)
  {
    //assert(p_entity.id !in m_entities, "Tried registering entity " ~ to!string(p_entity.id) ~ " that was already registered");
    
    //if (p_entity["name"] != "Mouse cursor")
      //writeln("registering entity " ~ p_entity["name"] ~ " with values " ~ p_entity.values.to!string);
    
    m_entities[p_entity.id] = p_entity;
    
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with name " ~ p_entity.getValue("name"));
    //debug writeln("registering entity " ~ to!string(p_entity.id) ~ " with values " ~ to!string(p_entity.values));
    
    if (p_entity.getValue("name") == "Debug display")
      m_debugDisplay = p_entity;
      
    if (p_entity.getValue("name") == "Entity matrix")
      m_entityMatrix = p_entity;
      
    if (p_entity.getValue("name") == "trashbin")
      m_trashBin = p_entity;
    
    if (p_entity.getValue("name") == "playership")
      m_playerShip = p_entity;
      
    if (p_entity.getValue("name") == "Closest ship display")
      m_closestShipDisplay = p_entity;
      
    if (p_entity.getValue("name") == "Dashboard")
      m_dashboard = p_entity;
    
    if (p_entity.getValue("name") == "Mouse cursor")
      m_mouseCursor = p_entity;
    
    foreach (subSystem; m_subSystems)
      subSystem.registerEntity(p_entity);
  }
  
  
  void removeEntity(Entity p_entity)
  {
    //writeln("removing entity " ~ p_entity["name"]);
    
    foreach (subSystem; m_subSystems)
      subSystem.removeEntity(p_entity);
    
    m_entities.remove(p_entity.id);
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
    foreach (subSystem; taskPool.parallel(m_subSystems.values.filter!(sys => sys !is m_graphics), 1))
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
  
  
  Entity findClosestShipGivenKeyValue(Entity p_entity, string key, string value)
  {
    auto entityPosition = m_placer.getComponent(p_entity).position;
    
    auto candidates = filter!(entity => entity.id != p_entity.id && entity.getValue(key) == value)(m_entities.values);
    
    //writeln("closestshipgivenkeyvalue candidates: " ~ to!string(candidates.array.length));
    
    if (candidates.empty)
      return null;
      
    Entity closestEntity = reduce!((closestSoFar, entity) =>
      ((m_placer.getComponent(closestSoFar).position - entityPosition).length < 
       (m_placer.getComponent(entity).position - entityPosition).length) ? closestSoFar : entity)
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
  Placer m_placer;
  Kinetics m_kinetics;
  Physics m_physics;
  Graphics m_graphics;
  Controller m_controller;
  CollisionHandler m_collisionHandler;
  Spawner m_spawner;
  Sound m_sound;
  Timer m_timer;
  RelationHandler m_relationHandler;
  
  Starfield m_starfield;
  
  Entity[int] m_entities;
  
  // special entities.. do they really need to be hardcoded?
  Entity m_playerShip;
  Entity m_trashBin;
  Entity m_debugDisplay;
  Entity m_entityMatrix;
  Entity m_closestShipDisplay;
  Entity m_dashboard;
  Entity m_mouseCursor;
  
  float[60] m_fpsBuffer;
  
  //string m_debugInfo;
  string m_timingInfo;
  
  Dispenser m_dispenser;
  MouseFollower m_mouseFollower;
  RiftTracker m_riftTracker;
  
  string[][string] cache;
  
  string rootDir;
}
