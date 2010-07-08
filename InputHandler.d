module InputHandler;

import std.stdio;
import std.conv;

import derelict.sdl.sdl;

import EnumGen;


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
  
  
  /*{
    SDL_Event wheelUpEvent;
    wheelUpEvent.type = SDL_MOUSEBUTTONDOWN;
    wheelUpEvent.button.button = SDL_BUTTON_WHEELUP;
    
    SDL_PushEvent(&wheelUpEvent);
    
    inputHandler.receiveEvent(wheelUpEvent);
  }
  assert(inputHandler.hasEvent(Event.WheelUp), "InputHandler didn't register mouse wheel event");*/
  
  
  inputHandler.clearEvents();
  
  
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


mixin(genEnum("Event",
[
  "Escape",
  "UpKey", 
  "DownKey", 
  "LeftKey", 
  "RightKey",
  "PageUp", 
  "PageDown",
  "Space",
  "WheelUp",
  "WheelDown"
]));


class InputHandler
{
public:
  this()
  {
    clearEvents();
    
    m_keyEventMapping[SDLK_ESCAPE] = Event.Escape;
    
    m_keyEventMapping[SDLK_LEFT] = Event.LeftKey;
    m_keyEventMapping[SDLK_RIGHT] = Event.RightKey;
    m_keyEventMapping[SDLK_UP] = Event.UpKey;
    m_keyEventMapping[SDLK_DOWN] = Event.DownKey;
    
    m_keyEventMapping[SDLK_PAGEUP] = Event.PageUp;
    m_keyEventMapping[SDLK_PAGEDOWN] = Event.PageDown;
    
    m_keyEventMapping[SDLK_SPACE] = Event.Space;
    
    m_buttonEventMapping[SDL_BUTTON_WHEELUP] = Event.WheelUp;
    m_buttonEventMapping[SDL_BUTTON_WHEELDOWN] = Event.WheelDown;
  }
  
  void pollEvents()
  {
    //clearEvents();
    //foreach (event; m_events.keys)
      //m_events[event] = 0;
      
    //static Event[SDLKey] m_buttonEventMapping;
    
    // clear button event here
    // for now we just register buttonup events, because 
    // wheel events are registered both up and down in the same game update
    foreach (buttonEvent; m_buttonEventMapping.values)
      m_events[buttonEvent] = 0;
    
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
        if (event.key.keysym.sym in m_keyEventMapping)
          m_events[m_keyEventMapping[event.key.keysym.sym]]++;
          
        break;
      }
      
      case SDL_KEYUP:
      {
        if (event.key.keysym.sym in m_keyEventMapping)
          if (m_events[m_keyEventMapping[event.key.keysym.sym]] > 0)
            m_events[m_keyEventMapping[event.key.keysym.sym]]--;

        break;
      }
      
      /*case SDL_MOUSEBUTTONDOWN:
      {
        writeln("got mousebuttondown event with button " ~ to!string(event.button.button));
        
        //writeln("buttonmapping: " ~ to!string(m_buttonEventMapping));
        writeln("button in mapping: " ~ to!string(event.button.button in m_buttonEventMapping));
        
        if (event.button.button in m_buttonEventMapping)
          m_events[m_buttonEventMapping[event.button.button]]++;

        assert(hasEvent(Event.WheelUp));

        break;
      }*/
      
      case SDL_MOUSEBUTTONDOWN:
      {
        //writeln("got mousebuttonup event with button " ~ to!string(event.button.button));
      
        if (event.button.button in m_buttonEventMapping)
          m_events[m_buttonEventMapping[event.button.button]]++;
          
          //if (m_events[m_buttonEventMapping[event.button.button]] > 0)
            //m_events[m_buttonEventMapping[event.button.button]]--;
            
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
  
  static Event[SDLKey] m_keyEventMapping;
  static Event[SDLKey] m_buttonEventMapping;
}
