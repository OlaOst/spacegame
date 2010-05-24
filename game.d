module Game;

import derelict.sdl.sdl;

import std.stdio;


unittest
{
  Game game = new Game();

  // TODO: assert that Derelict SDL and GL loaded OK
  
  // assert that game responds to input
  assert(game.hasInput(Game.Input.NOTHING), "Input not cleared on freshly created game");
  
  SDL_Event upEvent;
  upEvent.type = SDL_KEYDOWN;
  upEvent.key.keysym.sym = SDLK_UP;
  
  game.receiveInput(upEvent);
  
  assert(game.hasInput(Game.Input.UP), "Game didn't respond properly to input");

  SDL_Event downEvent;
  downEvent.type = SDL_KEYDOWN;
  downEvent.key.keysym.sym = SDLK_DOWN;
  
  game.receiveInput(downEvent);
  
  // TODO: do we need possible multiple inputs in an update? if so assert for UP input too here
  
  assert(game.hasInput(Game.Input.DOWN), "Game didn't respond properly to input");
  
  game.clearInput();
  assert(game.hasInput(Game.Input.NOTHING), "Game didn't clear input on request");
  
  assert(game.updateCount == 0);
  game.update();
  assert(game.updateCount == 1);
  
  
  SDL_Event quitEvent;
  quitEvent.type = SDL_QUIT;
  
  game.receiveInput(quitEvent);
  game.update();
  
  assert(!game.running, "Game didn't respond properly to quit event");
}


class Game
{
public:
  this()
  {
    clearInput();
    m_updateCount = 0;
    m_running = true;
  }


  private:
  enum Input
  {
    NOTHING,
    QUIT,
    UP, DOWN
  }  
 
  
private:  
  void receiveInput(SDL_Event event)
  {
    switch (event.type)
    {
      case SDL_QUIT:
        m_input = Input.QUIT;
        break;
        
      case SDL_KEYDOWN:
      {
        switch (event.key.keysym.sym)
        {
          case SDLK_DOWN:
            m_input = Input.DOWN;
            break;
            
          case SDLK_UP:
            m_input = Input.UP;
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
  
  void clearInput()
  {
    m_input = Input.NOTHING;
  }
  
  bool hasInput(const Input p_input)
  {
    return m_input == p_input;
  }
  
  int updateCount()
  {
    return m_updateCount;
  }
  
  void update()
  {
    m_updateCount++;
    
    if (hasInput(Input.QUIT))
      m_running = false;
  }
  
  bool running()
  {
    return m_running;
  }
  
  
private:
  Input m_input;
  int m_updateCount;
  
  bool m_running;
}
