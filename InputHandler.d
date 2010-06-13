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
  assert(inputHandler.hasEvent(Event.UpKey), "InputHandler didn't register first event correctly");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    inputHandler.receiveEvent(downEvent);
  }
  assert(inputHandler.countEvents() == 2, "InputHandler didn't register second event at all");
  assert(inputHandler.hasEvent(Event.UpKey), "InputHandler didn't register second event");
  assert(inputHandler.hasEvent(Event.DownKey), "InputHandler lost first event when registering the second");
  

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
  Escape,
  UpKey, 
  DownKey, 
  LeftKey, 
  RightKey,
  PageUp, 
  PageDown,
  Space
} 

Event eventFromString(string p_value)
{
  switch (p_value)
  {
    case "Escape" : return Event.Escape; break;
    case "UpKey" : return Event.UpKey; break;
    case "DownKey" : return Event.DownKey; break;
    case "LeftKey" : return Event.LeftKey; break;
    case "RightKey" : return Event.RightKey; break;
    case "PageUp" : return Event.PageUp; break;
    case "PageDown" : return Event.PageDown; break;
    case "Space" : return Event.Space; break;
  }
}


class InputHandler
{
public:
  this()
  {
    clearEvents();
    
    m_eventMapping[SDLK_ESCAPE] = Event.Escape;
    
    m_eventMapping[SDLK_LEFT] = Event.LeftKey;
    m_eventMapping[SDLK_RIGHT] = Event.RightKey;
    m_eventMapping[SDLK_UP] = Event.UpKey;
    m_eventMapping[SDLK_DOWN] = Event.DownKey;
    
    m_eventMapping[SDLK_PAGEUP] = Event.PageUp;
    m_eventMapping[SDLK_PAGEDOWN] = Event.PageDown;
    
    m_eventMapping[SDLK_SPACE] = Event.Space;
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
        m_events[Event.Escape]++;
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
