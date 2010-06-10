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
  UP, DOWN, LEFT, RIGHT,
  ZOOMIN, ZOOMOUT,
  CHOOSE
} 


class InputHandler
{
public:
  this()
  {
    clearEvents();
    
    m_eventMapping[SDLK_ESCAPE] = Event.QUIT;
    
    m_eventMapping[SDLK_LEFT] = Event.LEFT;
    m_eventMapping[SDLK_RIGHT] = Event.RIGHT;
    m_eventMapping[SDLK_UP] = Event.UP;
    m_eventMapping[SDLK_DOWN] = Event.DOWN;
    
    m_eventMapping[SDLK_PAGEUP] = Event.ZOOMIN;
    m_eventMapping[SDLK_PAGEDOWN] = Event.ZOOMOUT;
    
    m_eventMapping[SDLK_SPACE] = Event.CHOOSE;
  }
  
  void pollEvents()
  {
    //clearEvents();
    
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
        if (event.key.keysym.sym in m_eventMapping)
          m_events[m_eventMapping[event.key.keysym.sym]]++;
          
        break;
      }
      
      case SDL_KEYUP:
      {
        if (event.key.keysym.sym in m_eventMapping)
          if (m_events[m_eventMapping[event.key.keysym.sym]] > 0)
            m_events[m_eventMapping[event.key.keysym.sym]]--;

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
  
  static Event[SDLKey] m_eventMapping;
}
