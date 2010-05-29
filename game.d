module Game;

import derelict.sdl.sdl;

import Display;
import GraphicsSubSystem;
import Input;
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
  assert(game.m_input.hasEvent(Event.UP), "Game didn't register input event");
  
  {
    game.update();
  }
  assert(!game.m_input.hasEvent(Event.UP), "Input didn't clear event after update");
  
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
    game.m_world.handleEvents(game.m_input);
  }
}


class Game
{
invariant()
{
  assert(m_input !is null, "Game didn't initialize input");
  assert(m_world !is null, "Game didn't initialize world");
  assert(m_graphics !is null, "Game didn't initialize graphics");
}

public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    
    m_input = new Input();
    m_world = new World();
    m_graphics = new GraphicsSubSystem();
    
    Entity entity = new Entity();
    
    m_world.registerEntity(entity);
    m_graphics.registerEntity(entity);
    
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
    
    m_input.pollEvents();
    m_world.handleEvents(m_input);
      
    if (m_input.hasEvent(Event.QUIT))
      m_running = false;
  }
  
  bool running()
  {
    return m_running;
  }

  
private:
  int m_updateCount;
  bool m_running;
  
  Input m_input;
  World m_world;
  
  GraphicsSubSystem m_graphics;
}
