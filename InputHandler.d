module InputHandler;

import derelict.sdl.sdl;


unittest
{
  InputHandler inputHandler = new InputHandler();

  // assert that input responds to input
  assert(inputHandler.countEvents() == 0, "InputHandler not cleared on creation");
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    inputHandler.receiveEvent(upEvent);
  }
  assert(inputHandler.countEvents() == 1, "InputHandler didn't register first event at all");
  assert(inputHandler.hasEvent(Event.UP), "InputHandler didn't register first event correctly");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    inputHandler.receiveEvent(downEvent);
  }
  // TODO: do we need possible multiple inputs in an update? if so assert for UP input too here
  assert(inputHandler.countEvents() == 2, "InputHandler didn't register second event at all");
  assert(inputHandler.hasEvent(Event.UP), "InputHandler didn't register second event");
  assert(inputHandler.hasEvent(Event.DOWN), "InputHandler lost first event when registering the second");
  

  {
    inputHandler.clearEvents();
  }
  assert(inputHandler.countEvents() == 0, "InputHandler didn't clear events on request");
   
  // TODO: assert that both keyup and keydown events are handled properly
  
  {
    SDL_Event nadaEvent;
    inputHandler.receiveEvent(nadaEvent);
  }
  assert(inputHandler.countEvents() == 0, "InputHandler registered an empty event");
  
  {
    SDL_Event nadaKeyEvent;
    nadaKeyEvent.type = SDL_KEYDOWN;
    inputHandler.receiveEvent(nadaKeyEvent);
  }
  assert(inputHandler.countEvents() == 0, "InputHandler registered an empty event");
}


enum Event
{
  QUIT,
  UP, DOWN
} 


class InputHandler
{
public:
  this()
  {
    clearEvents();
  }
  
  void pollEvents()
  {
    clearEvents();
    
    SDL_Event event;
    
    // TODO: idiot check to make sure this doesn't go in infinite loop
    while (SDL_PollEvent(&event))    
    {
      receiveEvent(event);
    }
  }
  
  uint[Event] events()
  {
    return m_events;
  }
  
  bool hasEvent(const Event p_event)
  {
    return m_events.get(p_event, 0) > 0;
  }
  
private:
  void receiveEvent(SDL_Event event)
  {
    switch (event.type)
    {
      case SDL_QUIT:
        m_events[Event.QUIT]++;
        break;
        
      case SDL_KEYDOWN:
      {
        switch (event.key.keysym.sym)
        {
          case SDLK_ESCAPE:
            m_events[Event.QUIT]++;
            break;
            
          case SDLK_DOWN:
            m_events[Event.DOWN]++;
            break;
            
          case SDLK_UP:
            m_events[Event.UP]++;
            break;
            
          default:
            break;
        }
        break;
      }
      
      case SDL_KEYUP:
      {
        switch (event.key.keysym.sym)
        {
          case SDLK_ESCAPE:
            if (m_events[Event.QUIT] > 0)
              m_events[Event.QUIT]--;
            break;
            
          case SDLK_DOWN:
            if (m_events[Event.DOWN] > 0)
              m_events[Event.DOWN]--;
            break;
            
          case SDLK_UP:
            if (m_events[Event.UP] > 0)
              m_events[Event.UP]--;
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
    foreach (event; m_events.keys)
      m_events[event] = 0;
  }
  
  int countEvents()
  {
    int eventCount = 0;
    
    foreach (event; m_events.keys)
      eventCount += m_events[event];
      
    return eventCount;
  }
  
private:  
  uint[Event] m_events;
}
