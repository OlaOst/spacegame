/*
 Copyright (c) 2010 Ola Østtveit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

module InputHandler;

import std.stdio;
import std.conv;

import derelict.sdl.sdl;

import EnumGen;
import Vector : Vector;


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
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register first event correctly");

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    inputHandler.receiveEvent(downEvent);
  }
  assert(inputHandler.countEvents() == 2, "InputHandler didn't register second event at all");
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register second event");
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost first event when registering the second");
  

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
  
  
  // test pixel coords to viewport coords
  inputHandler.setScreenResolution(100, 100);
  assert(inputHandler.pixelToViewPort(50, 50) == Vector(0, -0.0), "50, 50 => " ~ inputHandler.pixelToViewPort(50, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == Vector(-1, 1), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(100, 100) == Vector(1, -1), "100, 100 => " ~ inputHandler.pixelToViewPort(100, 100).toString());
  
  // test nonsquare resolutions, they will have the width or height beyond -1,1 if it's wider or taller than square
  inputHandler.setScreenResolution(200, 100); // -1,-1 to 1,1 defines a square area centered on the screen, with 50 px extra to the left and right
  assert(inputHandler.pixelToViewPort(100, 50) == Vector(0, -0.0), "100, 50 => " ~ inputHandler.pixelToViewPort(100, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == Vector(-2, 1), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(200, 100) == Vector(2, -1), "200, 100 => " ~ inputHandler.pixelToViewPort(200, 100).toString());
  
  inputHandler.setScreenResolution(100, 300); // -1,-1 to 1,1 defines a square area centered on the screen, with 50 px extra to the left and right
  assert(inputHandler.pixelToViewPort(50, 150) == Vector(0, -0.0), "100, 50 => " ~ inputHandler.pixelToViewPort(100, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == Vector(-1, 3), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(100, 300) == Vector(1, -3), "200, 100 => " ~ inputHandler.pixelToViewPort(200, 100).toString());
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
  "LeftButton",
  "RightButton",
  "MiddleButton",
  "WheelUp",
  "WheelDown",
  "Pause"
]));


enum EventState
{
  Unchanged,
  Pressed,
  Released
}


class InputHandler
{
invariant()
{
  assert(m_mousePos.isValid());
}

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
    
    m_keyEventMapping[SDLK_PAUSE] = Event.Pause;
    
    m_buttonEventMapping[SDL_BUTTON_LEFT] = Event.LeftButton;
    m_buttonEventMapping[SDL_BUTTON_MIDDLE] = Event.MiddleButton;
    m_buttonEventMapping[SDL_BUTTON_RIGHT] = Event.RightButton;
    
    m_buttonEventMapping[SDL_BUTTON_WHEELUP] = Event.WheelUp;
    m_buttonEventMapping[SDL_BUTTON_WHEELDOWN] = Event.WheelDown;
    
    m_mousePos = Vector.origo;
  }
  
  void pollEvents()
  {
    //clearEvents();
    //foreach (event; m_events.keys)
      //m_events[event] = 0;
    
    // clear button event here
    // for now we just register buttonup events, because 
    // wheel events are registered both up and down in the same game update
    foreach (buttonEvent; m_buttonEventMapping.values)
      m_events[buttonEvent] = EventState.Unchanged;
    
    SDL_Event event;
    
    // TODO: idiot check to make sure this doesn't go in infinite loop
    while (SDL_PollEvent(&event))    
    {
      receiveEvent(event);
    }
  }
  
  EventState[Event] events()
  {
    return m_events;
  }
  
  EventState eventState(const Event p_event)
  {
    return m_events.get(p_event, EventState.Unchanged);
  }
  
  bool isPressed(const Event p_event)
  {
    return eventState(p_event) == EventState.Pressed;
  }
  
  bool isReleased(const Event p_event)
  {
    return eventState(p_event) == EventState.Released;
  }
  
  void setScreenResolution(int p_screenWidth, int p_screenHeight)
  {
    m_screenWidth = p_screenWidth;
    m_screenHeight = p_screenHeight;
  }
  
  Vector mousePos()
  {
    return m_mousePos;
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
          m_events[m_keyEventMapping[event.key.keysym.sym]] = EventState.Pressed;
          
        break;
      }
      
      case SDL_KEYUP:
      {
        if (event.key.keysym.sym in m_keyEventMapping)
          if (m_events[m_keyEventMapping[event.key.keysym.sym]] > 0)
            m_events[m_keyEventMapping[event.key.keysym.sym]] = EventState.Released;

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
      
      case SDL_MOUSEBUTTONUP:
      {
        writeln("got mousebuttonup event with button " ~ to!string(event.button.button));
      
        if (event.button.button in m_buttonEventMapping)
          m_events[m_buttonEventMapping[event.button.button]]++;
          
        break;
      }
      
      case SDL_MOUSEMOTION:
      {
        //writeln("detected mouse motion, pixelpos: "  ~ Vector(event.motion.x, event.motion.y).toString() ~ ", screenpos: " ~ pixelToViewPort(event.motion.x, event.motion.y).toString());
        m_mousePos = pixelToViewPort(event.motion.x, event.motion.y);
      }
      
      default:
        break;
    }
  }
  
  void clearEvents()
  {
    foreach (event; m_events.keys)
      m_events[event] = EventState.Unchanged;
  }
  
  int countEvents()
  {
    int eventCount = 0;
    
    foreach (event; m_events.keys)
    {
      if (m_events[event] != EventState.Unchanged)
        eventCount++;
    }
      
    return eventCount;
  }
  
  Vector pixelToViewPort(int p_x, int p_y)
  {
    int extraWidth = (m_screenWidth > m_screenHeight ? (m_screenWidth - m_screenHeight) : 0);
    int extraHeight = (m_screenHeight > m_screenWidth ? (m_screenHeight - m_screenWidth) : 0);
    
    return Vector((cast(float)(p_x - extraWidth/2) / cast(float)(m_screenWidth-extraWidth) - 0.5) * 2.0,
                 -(cast(float)(p_y - extraHeight/2) / cast(float)(m_screenHeight-extraHeight) - 0.5) * 2.0);
  }
  
  
private:  
  EventState[Event] m_events;
  
  static Event[SDLKey] m_keyEventMapping;
  static Event[SDLKey] m_buttonEventMapping;
  
  int m_screenWidth;
  int m_screenHeight;
  
  Vector m_mousePos;
}
