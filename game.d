module Game;

import derelict.sdl.sdl;

import std.stdio;


unittest
{
  Game game = new Game();

  // TODO: assert that Derelict SDL and GL loaded OK
  
  // assert that game responds to input
  assert(game.hasEvent(Game.Event.NOTHING), "Input not cleared on freshly created game");
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    game.receiveEvent(upEvent);
  }
  assert(game.hasEvent(Game.Event.UP), "Game didn't respond properly to input");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    game.receiveEvent(downEvent);
  }
  // TODO: do we need possible multiple inputs in an update? if so assert for UP input too here
  assert(game.hasEvent(Game.Event.DOWN), "Game didn't respond properly to input");
    
  {
    game.clearEvents();
  }
  assert(game.hasEvent(Game.Event.NOTHING), "Game didn't clear input on request");
  
  
  // TODO: assert that both keyup and keydown events are handled properly
  
  
  assert(game.updateCount == 0);
  {
    game.update();
  }
  assert(game.updateCount == 1);  
  
  {
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    
    game.receiveEvent(quitEvent);
    game.update();
  }
  assert(!game.running, "Game didn't respond properly to quit event");
  
  {
    game.clearEvents();
  }
  assert(game.hasEvent(Game.Event.NOTHING), "Game didn't clear events on clearEvents, while not running");
  assert(!game.running, "Game restarted on clearEvents..?");
  
  {
    SDL_Event escEvent;
    escEvent.type = SDL_KEYDOWN;
    escEvent.key.keysym.sym = SDLK_ESCAPE;
  
    game.receiveEvent(escEvent);
  }
  assert(game.hasEvent(Game.Event.QUIT), "Game didn't register escape keypress, while not running");
}


class Game
{
public:
  this()
  {
    clearEvents();
    m_updateCount = 0;
    m_running = true;
  }


private:
  enum Event
  {
    NOTHING,
    QUIT,
    UP, DOWN
  }  
 
  
private:  
  void receiveEvent(SDL_Event event)
  {
    switch (event.type)
    {
      case SDL_QUIT:
        m_event = Event.QUIT;
        break;
        
      case SDL_KEYDOWN:
      {
        switch (event.key.keysym.sym)
        {
          case SDLK_ESCAPE:
            m_event = Event.QUIT;
            break;
            
          case SDLK_DOWN:
            m_event = Event.DOWN;
            break;
            
          case SDLK_UP:
            m_event = Event.UP;
            break;
            
          default:
            break;
        }
        break;
      }
      
      default:
        break;
    }
  }
  
  void clearEvents()
  {
    m_event = Event.NOTHING;
  }
  
  bool hasEvent(const Event p_event)
  {
    return m_event == p_event;
  }
  
  int updateCount()
  {
    return m_updateCount;
  }
  
  void update()
  {
    m_updateCount++;
    
    if (hasEvent(Event.QUIT))
      m_running = false;
  }
  
  bool running()
  {
    return m_running;
  }
  
  
private:
  Event m_event;
  int m_updateCount;
  
  bool m_running;
}
