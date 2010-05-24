module Input;

import derelict.sdl.sdl;


unittest
{
  Input input = new Input();

  // assert that input responds to input
  assert(input.hasEvent(Event.NOTHING), "Input not cleared on freshly created input");
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    input.receiveEvent(upEvent);
  }
  assert(input.hasEvent(Event.UP), "input didn't respond properly to input");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    input.receiveEvent(downEvent);
  }
  // TODO: do we need possible multiple inputs in an update? if so assert for UP input too here
  assert(input.hasEvent(Event.DOWN), "input didn't respond properly to input");
    
  {
    input.clearEvents();
  }
  assert(input.hasEvent(Event.NOTHING), "input didn't clear input on request");
   
  // TODO: assert that both keyup and keydown events are handled properly
}


enum Event
{
  NOTHING,
  QUIT,
  UP, DOWN
} 


class Input
{
public:
  this()
  {
    clearEvents();
  }
  
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
  
  bool hasEvent(const Event p_event)
  {
    return m_event == p_event;
  }
  
private:
  void clearEvents()
  {
    m_event = Event.NOTHING;
  }
  
private: 
  Event m_event;
}
