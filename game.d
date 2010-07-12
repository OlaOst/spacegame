module Game;

import std.conv;
import std.math;
import std.random;
import std.stdio;

import derelict.sdl.sdl;

import CollisionSubSystem;
import Display;
import GraphicsSubSystem;
import InputHandler;
import PhysicsSubSystem;
import Starfield;
import Timer;
import Vector : Vector;


unittest
{
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
    Entity entity = new Entity();
    
    entity.setValue("control", "player");
    entity.setValue("mass", "4.0");
    
    game.m_physics.registerEntity(entity);
    
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    game.m_inputHandler.pollEvents();
    
    Entity[] spawnList;
        
    game.m_physics.move(0.01);
    
    assert(entity.position.x > 0.0);
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
    m_physics = new PhysicsSubSystem(m_inputHandler);
    m_collision = new CollisionSubSystem();
    
    Entity player = new Entity();

    player.setValue("control", "player");
    player.setValue("drawtype", "triangle");
    player.setValue("collisionType", "ship");
    player.setValue("keepInCenter", "true");
    player.setValue("radius", "2.0");
    player.setValue("mass", "4.0");
    
    m_entities ~= player;
    
    m_graphics.registerEntity(player);
    m_physics.registerEntity(player);
    //m_collision.registerEntity(player);
    
    for (int n = 0; n < 40; n++)
    {
      Entity npc = new Entity();

      //npc.setValue("control", "flocker");
      npc.setValue("drawtype", "triangle");
      npc.setValue("collisionType", "ship");
      npc.setValue("velocity", "randomize");
      npc.setValue("radius", "1.0");
      npc.setValue("mass", "1.0");
      
      npc.position = Vector(uniform(-12.0, 12.0), uniform(-12.0, 12.0));
      npc.angle = uniform(0.0, PI*2);
      
      m_entities ~= npc;
    
      m_graphics.registerEntity(npc);
      m_physics.registerEntity(npc);
      m_collision.registerEntity(npc);
    }
    
    m_starfield = new Starfield(m_graphics, 10.0);
    
    initDisplay();
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
        }
      }
    }
    
    swapBuffers();
    
    m_inputHandler.pollEvents();

    if (!m_paused)
    {
      // collision must be updated before physics to make sure both entities in collisions are updated properly
      m_collision.update();
      m_physics.move(elapsedTime);
    }
    
    m_graphics.draw();
    
    // TODO: we need to know what context we are in - input events signify different intents depending on context
    // ie up event in a menu context (move cursor up) vs up event in a ship control context (accelerate ship)
    
    foreach (Entity spawn; spawnList)
    {
      m_entities ~= spawn;
      m_graphics.registerEntity(spawn);
      m_physics.registerEntity(spawn);
      m_collision.registerEntity(spawn);
    }
    
    if (m_inputHandler.hasEvent(Event.PageUp))
    {
      m_graphics.zoomIn(elapsedTime * 2.0);
      //m_starfield.populate(20.0);
    }
    if (m_inputHandler.hasEvent(Event.WheelUp))
    {
      m_graphics.zoomIn(elapsedTime * 5.0);
      //m_starfield.populate(20.0);
    }
    if (m_inputHandler.hasEvent(Event.PageDown)) 
    {
      m_graphics.zoomOut(elapsedTime * 2.0);
      //m_starfield.populate(20.0);
    }
    if(m_inputHandler.hasEvent(Event.WheelDown))
    {
      m_graphics.zoomOut(elapsedTime * 5.0);
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
  
  Starfield m_starfield;
  
  Entity[] m_entities;
}
