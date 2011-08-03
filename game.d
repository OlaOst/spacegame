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
import SubSystem.DragDropHandler;
import SubSystem.Graphics;
import SubSystem.Physics;
import SubSystem.Placer;
import SubSystem.Sound;
import SubSystem.Spawner;

import CommsCentral;
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
  testGraphics.setValue("drawsource", "star");
  
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
    m_subSystems["dragdropper"] = m_dragdropper = new DragDropHandler();
    
    //m_mouseEntity = new Entity();
    //m_mouseEntity.setValue("drawsource", "star");
    //m_mouseEntity.setValue("radius", "2.0");
    //m_mouseEntity.setValue("mass", "1.0");
    //m_mouseEntity.setValue("position", "5 0");
    
    //registerEntity(m_mouseEntity);
    //m_draggables ~= m_mouseEntity;
    
    Entity dragEngine = new Entity("data/engine.txt");
    dragEngine.setValue("position", "5 0 0");
    
    registerEntity(dragEngine);
    m_draggables ~= dragEngine;
    
    m_testSkeleton = new Entity("data/skeleton.txt");
    m_testSkeleton.setValue("position", "0 -5 0");
    
    registerEntity(m_testSkeleton);
    
    assert(m_connector.hasComponent(m_testSkeleton));
    
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
      Entity npcShip = loadShip("npcship.txt", ["position" : Vector(uniform(-12.0, 12.0), uniform(-12.0, 12.0)).toString(), "angle" : to!string(uniform(0.0, PI*2))]);
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
    
    
    Entity[] spawnList;
    
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
      
      if (entity.lifetime <= 0.0 || entity.health <= 0.0 || removeEntity)
      {
        foreach (subSystem; m_subSystems)
          subSystem.removeEntity(entity);
        
        entitiesToRemove ~= entity;
      }
    }
    
    foreach (entityToRemove; entitiesToRemove)
    {
      m_entities.remove(entityToRemove.id);
    }
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      assert(elapsedTime > 0.0);
      m_physics.setTimeStep(elapsedTime);
      m_controller.setTimeStep(elapsedTime);
      
      // the sdl/gl stuff in the graphics subsystem needs to run in the main thread for stuff to be shown on the screen
      // so we filter the graphics subsystem out of the subsystem list 
      // and explicitly update it outside the parallel foreach to ensure it runs in the main thread
      m_graphics.update();
      foreach (subSystem; taskPool.parallel(filter!(delegate (SubSystem.Base.SubSystem sys) { return sys !is m_graphics; })(m_subSystems.values)))
      {
        subSystem.update();
      }
      //foreach (subSystem; m_subSystems.values)
        //subSystem.update();
      
      CommsCentral.setPlacerFromPhysics(m_physics, m_placer);
      CommsCentral.setPlacerFromConnector(m_connector, m_placer);
      
      if (m_dragEntity !is null)
      {
        auto dragComp = m_placer.getComponent(m_dragEntity);
        dragComp.position = m_graphics.mouseWorldPos;
        m_placer.setComponent(m_dragEntity, dragComp);
      }
      
      CommsCentral.setPhysicsFromController(m_controller, m_physics);
      CommsCentral.setSpawnerFromController(m_controller, m_spawner);
      
      CommsCentral.setPhysicsFromConnector(m_connector, m_physics);
      
      CommsCentral.setControllerFromPlacer(m_placer, m_controller);
      CommsCentral.setCollidersFromPlacer(m_placer, m_collider);
      CommsCentral.setSpawnerFromPlacer(m_placer, m_spawner);
      
      CommsCentral.calculateCollisionResponse(m_collider, m_physics);
    }
    CommsCentral.setGraphicsFromPlacer(m_placer, m_graphics);
    
    m_fpsBuffer[m_updateCount % m_fpsBuffer.length] = floor(1.0 / elapsedTime);
    
    auto fpsDisplayComponent = m_graphics.getComponent(m_fpsDisplay);
    fpsDisplayComponent.text = "FPS: " ~ to!string(cast(int)(reduce!"a+b"(m_fpsBuffer)/m_fpsBuffer.length));
    m_graphics.setComponent(m_fpsDisplay, fpsDisplayComponent);
    
    m_graphics.calculateMouseWorldPos(m_inputHandler.mousePos);
    
    // TODO: we need to know what context we are in - input events signify different intents depending on context
    // ie up event in a menu context (move cursor up) vs up event in a ship control context (accelerate ship)
    
    foreach (Entity spawn; m_spawner.getAndClearSpawns())
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
      //auto mouseComp = m_placer.getComponent(m_mouseEntity);
      //auto mouseComp = m_graphics.getComponent(m_mouseEntity);
      
      foreach (draggable; m_draggables)
      {
        auto dragComp = m_graphics.getComponent(draggable);
        
        if ((dragComp.position - m_graphics.mouseWorldPos).length2d < dragComp.radius)
        {
          m_dragEntity = draggable;
          
          // break eventual connection of drag entity
          if (m_connector.hasComponent(m_dragEntity))
            m_connector.removeEntity(m_dragEntity);
          
          break;
        }
      }
    }
    
    if (m_inputHandler.eventState(Event.LeftButton) == EventState.Released)
    {
      // if drag entity close to testskeleton contact point then connect to it
      
      if (m_dragEntity !is null)
      {
        assert(m_placer.hasComponent(m_dragEntity));
        assert(m_placer.hasComponent(m_testSkeleton));
        
        auto dragPos = m_placer.getComponent(m_dragEntity).position;
        auto testSkelPos = m_placer.getComponent(m_testSkeleton).position;
        
        auto connectPoints = m_connector.getComponent(m_testSkeleton).connectPoints;

        foreach (connectPoint; connectPoints)
        {
          auto connectPointPos = testSkelPos + connectPoint.position;
          
          if (connectPoint.empty && (dragPos - connectPointPos).length2d < 1.0)
          {
            // set up mouseentity to be connected to mouseskeleton, then duplicate it
            
            m_dragEntity.setValue("position", connectPointPos.toString());
            m_dragEntity.setValue("owner", to!string(m_testSkeleton.id));
            m_dragEntity.setValue("connection", m_testSkeleton.getValue("name") ~ "." ~ connectPoint.name);
            
            registerEntity(m_dragEntity);
            
            
            // TODO: create duplicate of drag entity
            /*m_mouseEntity = new Entity();
            m_mouseEntity.setValue("drawsource", "star");
            m_mouseEntity.setValue("radius", "2.0");
            m_mouseEntity.setValue("position", "5 0");
            
            registerEntity(m_mouseEntity);*/
            
            break;
          }
        }
        m_dragEntity = null;
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
    Entity ship = new Entity("data/" ~ p_file);
    
    foreach (extraParam; p_extraParams.keys)
    {
      ship.setValue(extraParam, p_extraParams[extraParam]);
    }
    
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
    m_entities[p_entity.id] = p_entity;
    
    foreach (subSystem; m_subSystems)
      subSystem.registerEntity(p_entity);
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
  DragDropHandler m_dragdropper; 
  
  Starfield m_starfield;
  
  Entity[int] m_entities;

  Entity m_playerShip;
  
  //Entity m_mouseEntity;
  Entity m_testSkeleton;
  
  Entity[] m_draggables;
  Entity m_dragEntity;
  
  Entity m_fpsDisplay;
  float[20] m_fpsBuffer;
}
