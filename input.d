module Input;

import derelict.sdl.sdl;


unittest
{
  Input input = new Input();

  // assert that input responds to input
  assert(input.countEvents() == 0, "Input not cleared on creation");
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    input.receiveEvent(upEvent);
  }
  assert(input.countEvents() == 1, "Input didn't register first event at all");
  assert(input.hasEvent(Event.UP), "Input didn't register first event correctly");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    input.receiveEvent(downEvent);
  }
  // TODO: do we need possible multiple inputs in an update? if so assert for UP input too here
  assert(input.countEvents() == 2, "Input didn't register second event at all");
  assert(input.hasEvent(Event.UP), "Input didn't register second event");
  assert(input.hasEvent(Event.DOWN), "Input lost first event when registering the second");
  

  {
    input.clearEvents();
  }
  assert(input.countEvents() == 0, "Input didn't clear events on request");
   
  // TODO: assert that both keyup and keydown events are handled properly
  
  {
    SDL_Event nadaEvent;
    input.receiveEvent(nadaEvent);
  }
  assert(input.countEvents() == 0, "Input registered an empty event");
  
  {
    SDL_Event nadaKeyEvent;
    nadaKeyEvent.type = SDL_KEYDOWN;
    input.receiveEvent(nadaKeyEvent);
  }
  assert(input.countEvents() == 0, "Input registered an empty event");
}


enum Event
{
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
  int[Event] m_events;
}
