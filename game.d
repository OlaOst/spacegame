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
import std.conv;
import std.math;
import std.random;
import std.stdio;

import derelict.sdl.sdl;

import CollisionSubSystem;
import ConnectionSubSystem;
import Display;
import GraphicsSubSystem;
import InputHandler;
import PhysicsSubSystem;
import SoundSubSystem;
import Starfield;
import Timer;
import Vector : Vector;


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
  
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    game.update();
  }
  assert(game.m_inputHandler.hasEvent(Event.UpKey), "Game didn't register input event");
  
  {
    SDL_Event upReleaseEvent;
    upReleaseEvent.type = SDL_KEYUP;
    upReleaseEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upReleaseEvent);
    
    game.update();
  }
  assert(!game.m_inputHandler.hasEvent(Event.UpKey), "Input didn't clear event after keyup event and update");
  
  {
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    
    SDL_PushEvent(&quitEvent);

    game.update();
  }
  assert(!game.running, "Game didn't respond properly to quit event");
  
  {
    Entity entity = new Entity();
    
    entity.setValue("drawtype", "triangle");
    entity.setValue("radius", "1.0");
    
    game.m_graphics.registerEntity(entity);
  }
  
  {
    game.m_graphics.draw();
    game.m_physics.move(1.0);
  }
  
  // test that game moves entity according to input
  {
    Entity ship = new Entity();
    ship.setValue("mass", "4.0");
    
    Entity engine = new Entity();
    engine.setValue("owner", to!string(ship.id));
    engine.setValue("relativePosition", "1 0");
    engine.setValue("mass", "2.0");
    engine.setValue("control", "playerEngine");
    
    game.m_physics.registerEntity(ship);
    game.m_connection.registerEntity(ship);
    game.m_connection.registerEntity(engine);
    
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    game.m_inputHandler.pollEvents();
    
    Entity[] spawnList;
    
    assert(game.m_connection.findComponents(engine)[0].owner == game.m_connection.findComponents(ship)[0]);
    
    game.m_connection.updateFromControllers();
    
    game.m_physics.move(0.1);
    game.m_connection.updateFromPhysics(0.1);
    
    assert(ship.position.x > 0.0);
  }
}


class Game
{
invariant()
{
  assert(m_timer !is null, "Game didn't initialize timer");
  assert(m_inputHandler !is null, "Game didn't initialize input handler");
  assert(m_graphics !is null, "Game didn't initialize graphics");
  assert(m_physics !is null, "Game didn't initialize physics");
  assert(m_collision !is null, "Game didn't initialize collision system");
  assert(m_connection !is null, "Game didn't initialize connection system");
  assert(m_sound !is null, "Game didn't initialize sound system");
}

public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    m_paused = false;
    
    m_timer = new Timer();
    
    m_inputHandler = new InputHandler();
    
    m_graphics = new GraphicsSubSystem();
    m_physics = new PhysicsSubSystem();
    m_collision = new CollisionSubSystem();
    m_connection = new ConnectionSubSystem(m_inputHandler, m_physics);
    m_sound = new SoundSubSystem(16);
    
    
    Entity startupDing = new Entity();
    startupDing.setValue("soundFile", "test.wav");
    m_sound.registerEntity(startupDing);
    
    Entity playerShip = new Entity("data/playership.txt");
    
    m_entities ~= playerShip;
    
    m_graphics.registerEntity(playerShip);
    m_physics.registerEntity(playerShip);
    //m_collision.registerEntity(playerShip);
    m_connection.registerEntity(playerShip);
    
    foreach (subSource; filter!("a.endsWith(\".source\")")(playerShip.values.keys))
    {
      Entity subEntity = new Entity("data/" ~ playerShip.getValue(subSource));
      
      auto subName = subSource[0..std.string.indexOf(subSource, ".source")];
      
      subEntity.setValue("owner", to!string(playerShip.id));
      
      foreach (subSourceValue; filter!(delegate(x) { return x.startsWith(subName ~ "."); })(playerShip.values.keys))
      {
        subEntity.setValue(subSourceValue[std.string.indexOf(subSourceValue, '.')+1..$], playerShip.getValue(subSourceValue));
      }

      m_graphics.registerEntity(subEntity);
      m_connection.registerEntity(subEntity);
      m_physics.registerEntity(subEntity);
    }

    for (int n = 0; n < 1; n++)
    {
      Entity npcShip = new Entity("data/npcship.txt");
      
      npcShip.position = Vector(uniform(-12.0, 12.0), uniform(-12.0, 12.0));
      npcShip.angle = uniform(0.0, PI*2);
      
      m_entities ~= npcShip;
      
      m_graphics.registerEntity(npcShip);
      m_physics.registerEntity(npcShip);
      m_collision.registerEntity(npcShip);
      m_connection.registerEntity(npcShip);
      
      foreach (subSource; filter!("a.endsWith(\".source\")")(npcShip.values.keys))
      {
        Entity subEntity = new Entity("data/" ~ npcShip.getValue(subSource));
        
        auto subName = subSource[0..std.string.indexOf(subSource, ".source")];
        
        subEntity.setValue("owner", to!string(npcShip.id));

        foreach (subSourceValue; filter!(delegate(x) { return x.startsWith(subName ~ "."); })(npcShip.values.keys))
        {
          subEntity.setValue(subSourceValue[std.string.indexOf(subSourceValue, '.')+1..$], npcShip.getValue(subSourceValue));
        }
        
        m_graphics.registerEntity(subEntity);
        m_connection.registerEntity(subEntity);
        m_physics.registerEntity(subEntity);
      }
    }
    
    m_starfield = new Starfield(m_graphics, 10.0);
    
    initDisplay(800, 600);
    m_inputHandler.setScreenResolution(800, 600);
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
    float elapsedTime = m_timer.elapsedTime;
    if (m_updateCount == 0)
      elapsedTime = 0.0;
    m_timer.start();
    
    m_updateCount++;
    
    
    Entity[] spawnList;
    
    if (!m_paused)
    {
      foreach (Entity entity; m_entities)
      {
        spawnList ~= entity.getAndClearSpawns();
        
        entity.lifetime = entity.lifetime - elapsedTime;

        if (entity.lifetime < 0.0)
        {        
          m_physics.removeEntity(entity);
          m_graphics.removeEntity(entity);
          m_collision.removeEntity(entity);
          m_sound.removeEntity(entity);
        }
      }
    }
    
    swapBuffers();
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      m_connection.updateFromControllers();
    
      // collision must be updated before physics to make sure both entities in collisions are updated properly
      m_collision.update();
      m_physics.move(elapsedTime);
      
      m_connection.updateFromPhysics(elapsedTime);
    }
    
    m_graphics.draw();
    m_sound.soundOff();
    
    // TODO: we need to know what context we are in - input events signify different intents depending on context
    // ie up event in a menu context (move cursor up) vs up event in a ship control context (accelerate ship)
    
    foreach (Entity spawn; spawnList)
    {      
      m_entities ~= spawn;
      
      if (spawn.getValue("onlySound") != "true")
      {
        m_graphics.registerEntity(spawn);
        m_physics.registerEntity(spawn);
        m_collision.registerEntity(spawn);
      }
      
      m_sound.registerEntity(spawn);
    }
    
    if (m_inputHandler.hasEvent(Event.PageUp))
    {
      m_graphics.zoomIn(elapsedTime * 2.0);
      //m_starfield.populate(20.0);
    }
    if (m_inputHandler.hasEvent(Event.WheelUp))
    {
      m_graphics.zoomIn(elapsedTime * 15.0);
      //m_starfield.populate(20.0);
    }
    if (m_inputHandler.hasEvent(Event.PageDown)) 
    {
      m_graphics.zoomOut(elapsedTime * 2.0);
      //m_starfield.populate(20.0);
    }
    if(m_inputHandler.hasEvent(Event.WheelDown))
    {
      m_graphics.zoomOut(elapsedTime * 15.0);
      //m_starfield.populate(20.0);
    }
    
    if (m_inputHandler.hasEvent(Event.Escape))
      m_running = false;
      
    m_paused = false;
    if (m_inputHandler.hasEvent(Event.Pause))
      m_paused = true;
  }
  
  bool running()
  {
    return m_running;
  }

  
private:
  int m_updateCount;
  bool m_running;
  
  bool m_paused;
  
  Timer m_timer;
  
  InputHandler m_inputHandler;
  
  GraphicsSubSystem m_graphics;
  PhysicsSubSystem m_physics;
  CollisionSubSystem m_collision;
  ConnectionSubSystem m_connection;
  SoundSubSystem m_sound;
    
  Starfield m_starfield;
  
  Entity[] m_entities;
}
