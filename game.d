module Game;

import std.stdio;
import std.conv;

import derelict.sdl.sdl;

import Display;
import GraphicsSubSystem;
import InputHandler;
import IntentSubSystem;
import PhysicsSubSystem;
import Timer;


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
  assert(game.m_inputHandler.hasEvent(Event.UP), "Game didn't register input event");
  
  {
    game.update();
  }
  assert(!game.m_inputHandler.hasEvent(Event.UP), "Input didn't clear event after update");
  
  {
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    
    SDL_PushEvent(&quitEvent);

    game.update();
  }
  assert(!game.running, "Game didn't respond properly to quit event");
  
  {
    Entity entity = new Entity();
    
    game.m_graphics.registerEntity(entity);
  }
  
  {
    game.m_graphics.draw();
    game.m_physics.move(1.0);
  }
  
  
  // test that game moves entity according to input
  {
    Entity entity = new Entity();
    
    game.m_physics.registerEntity(entity);
    game.m_intentHandler.registerEntity(entity);
    
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    game.m_inputHandler.pollEvents();
    
    game.m_intentHandler.listen(game.m_inputHandler);
    
    game.m_physics.move(0.01);
    
    assert(entity.position.y > 0.0);
  }
}


class Game
{
invariant()
{
  assert(m_timer !is null, "Game didn't initialize timer");
  assert(m_inputHandler !is null, "Game didn't initialize input handler");
  assert(m_graphics !is null, "Game didn't initialize graphics");
  assert(m_intentHandler !is null, "Game didn't initialize intent handler");
  assert(m_physics !is null, "Game didn't initialize physics");
}

public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    
    m_timer = new Timer();
    
    m_inputHandler = new InputHandler();
    
    m_graphics = new GraphicsSubSystem();
    m_intentHandler = new IntentSubSystem();
    m_physics = new PhysicsSubSystem();
    
    Entity entity = new Entity();
    
    m_graphics.registerEntity(entity);
    m_physics.registerEntity(entity);
    m_intentHandler.registerEntity(entity);
    
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
    m_timer.start();
    
    m_updateCount++;
    
    swapBuffers();
    
    m_inputHandler.pollEvents();

    // TODO: figure out how much time elapsed since last update
    m_physics.move(elapsedTime);
    m_graphics.draw();
    
    // TODO: we need to know which context we are in - input events signify different intents depending on context
    // ie up event in a menu context (move cursor up) vs up event in a ship control context (accelerate ship)
    m_intentHandler.listen(m_inputHandler); 
    
    if (m_inputHandler.hasEvent(Event.ZOOMIN))
      m_graphics.zoomIn(elapsedTime);
    if (m_inputHandler.hasEvent(Event.ZOOMOUT))
      m_graphics.zoomOut(elapsedTime);
    
    if (m_inputHandler.hasEvent(Event.QUIT))
      m_running = false;
  }
  
  bool running()
  {
    return m_running;
  }

  
private:
  int m_updateCount;
  bool m_running;
  
  Timer m_timer;
  
  InputHandler m_inputHandler;
  
  GraphicsSubSystem m_graphics;
  IntentSubSystem m_intentHandler;
  PhysicsSubSystem m_physics;
}
