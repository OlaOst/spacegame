module Game;

import derelict.sdl.sdl;

import Display;
import GraphicsSubSystem;
import InputHandler;
import IntentSubSystem;
import World;


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
    game.m_world.registerEntity(entity);
  }
  
  {
    game.m_graphics.draw();
    game.m_world.handleEvents(game.m_inputHandler);
  }
}


class Game
{
invariant()
{
  assert(m_inputHandler !is null, "Game didn't initialize input handler");
  assert(m_world !is null, "Game didn't initialize world");
  assert(m_graphics !is null, "Game didn't initialize graphics");
  assert(m_intentHandler !is null, "Game didn't initialize intent handler");
}

public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    
    m_inputHandler = new InputHandler();
    m_world = new World();
    
    m_graphics = new GraphicsSubSystem();
    m_intentHandler = new IntentSubSystem();
    
    Entity entity = new Entity();
    
    m_world.registerEntity(entity);
    m_graphics.registerEntity(entity);
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
    m_updateCount++;
    
    //m_world.draw();
    swapBuffers();
    
    m_inputHandler.pollEvents();
    m_world.handleEvents(m_inputHandler);
      
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
  
  InputHandler m_inputHandler;
  World m_world;
  
  GraphicsSubSystem m_graphics;
  IntentSubSystem m_intentHandler;
}
