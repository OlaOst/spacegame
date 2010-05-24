module Game;

import derelict.sdl.sdl;

import std.stdio;

import Display;
import Input;


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
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    
    game.m_input.receiveEvent(quitEvent);
    game.update();
  }
  assert(!game.running, "Game didn't respond properly to quit event");
}


class Game
{
public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    
    m_input = new Input();
    
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
    
    draw();
    
    m_input.pollEvents();
    
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
}
