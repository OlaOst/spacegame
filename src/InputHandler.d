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
import std.exception;
import std.conv;

import derelict.ovr.ovr;
import derelict.sdl2.sdl;

import gl3n.linalg;

//pragma(lib, "DerelictSDL.lib");
//pragma(lib, "DerelictUtil.lib");


// TODO: remove dependencies to SDL to make proper unittests of this stuff
/+unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  DerelictSDL2.load();
  
  enforce(SDL_Init(SDL_INIT_VIDEO) == 0, "Failed to initialize SDL: " ~ to!string(SDL_GetError()));
  
  InputHandler inputHandler = new InputHandler();

  // assert that input responds to input
  assert(inputHandler.countEvents() == 0, "InputHandler not cleared on creation");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    inputHandler.receiveEvent(upEvent);
  }
  assert(inputHandler.countEvents() == 1, "InputHandler didn't register first event at all");
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register first event correctly");
  assert(inputHandler.eventState(Event.UpKey) == EventState.Pressed);

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    inputHandler.receiveEvent(downEvent);
  }
  assert(inputHandler.countEvents() == 2, "InputHandler didn't register second event at all");
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register second event correctly");
  assert(inputHandler.eventState(Event.UpKey) == EventState.Pressed);
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost first event when registering the second");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Pressed);
  
  {
    SDL_Event upReleaseEvent;
    upReleaseEvent.type = SDL_KEYUP;
    upReleaseEvent.key.keysym.sym = SDLK_UP;
    
    inputHandler.receiveEvent(upReleaseEvent);
  }
  assert(inputHandler.countEvents() == 2, "InputHandler didn't register key release event at all");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Released);
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost event when registering key release");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Pressed);
  

  {
    inputHandler.clearEventStates();
  }
  assert(inputHandler.countEvents() == 0, "InputHandler didn't clear event states on request");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost pressed state when clearing event states");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Unchanged);
  
  {
    inputHandler.clearEvents();
  }
  assert(inputHandler.countEvents() == 0, "InputHandler didn't clear event states on request");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  assert(inputHandler.isPressed(Event.DownKey) == false, "InputHandler didn't clear pressed state when clearing all events");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Unchanged);
  
  /*{
    SDL_Event wheelUpEvent;
    wheelUpEvent.type = SDL_MOUSEBUTTONDOWN;
    wheelUpEvent.button.button = SDL_BUTTON_WHEELUP;
    
    SDL_PushEvent(&wheelUpEvent);
    
    inputHandler.receiveEvent(wheelUpEvent);
  }
  assert(inputHandler.eventState(Event.WheelUp) == EventState.Pressed);
  assert(inputHandler.isPressed(Event.WheelUp), "InputHandler didn't register mouse wheel event");*/
  
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
  assert(inputHandler.countEvents() == 0, "InputHandler registered an empty key event");
  
  
  inputHandler.pollEvents();
  inputHandler.clearEvents();
  
  
  // assert that input responds to input
  assert(inputHandler.countEvents() == 0, "InputHandler not cleared on creation");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  
  inputHandler.pollEvents();

  assert(inputHandler.countEvents() == 0, "InputHandler registered events when polling no events");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    inputHandler.pollEvents();
  }
  assert(inputHandler.countEvents() == 1, "InputHandler didn't register first event at all, events registered: " ~ to!string(inputHandler.countEvents()));
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register first event correctly");
  assert(inputHandler.eventState(Event.UpKey) == EventState.Pressed);

  {
    SDL_Event downEvent;
    downEvent.type = SDL_KEYDOWN;
    downEvent.key.keysym.sym = SDLK_DOWN;
    
    SDL_PushEvent(&downEvent);
    inputHandler.pollEvents();
  }
  assert(inputHandler.countEvents() == 1, "InputHandler didn't register second event at all, events registered: " ~ to!string(inputHandler.countEvents()));
  assert(inputHandler.isPressed(Event.UpKey), "InputHandler didn't register second event correctly");
  assert(inputHandler.eventState(Event.UpKey) == EventState.Unchanged);
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost first event when registering the second");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Pressed);
  
  {
    SDL_Event upReleaseEvent;
    upReleaseEvent.type = SDL_KEYUP;
    upReleaseEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upReleaseEvent);
    inputHandler.pollEvents();
  }
  assert(inputHandler.countEvents() == 1, "InputHandler didn't register key release event at all");
  assert(inputHandler.isPressed(Event.UpKey) == false);
  assert(inputHandler.eventState(Event.UpKey) == EventState.Released);
  assert(inputHandler.isPressed(Event.DownKey), "InputHandler lost event when registering key release");
  assert(inputHandler.eventState(Event.DownKey) == EventState.Unchanged);
  
  /*{
    SDL_Event wheelUpEvent;
    wheelUpEvent.type = SDL_MOUSEBUTTONDOWN;
    wheelUpEvent.button.button = SDL_BUTTON_WHEELUP;
    
    SDL_PushEvent(&wheelUpEvent);
    inputHandler.pollEvents();
  }
  assert(inputHandler.eventState(Event.WheelUp) == EventState.Pressed);
  assert(inputHandler.isPressed(Event.WheelUp), "InputHandler didn't register mouse wheel event");*/
  
  /*inputHandler.pollEvents();
  assert(inputHandler.eventState(Event.WheelUp) == EventState.Unchanged);
  assert(inputHandler.isPressed(Event.WheelUp));*/
  
  /*{
    SDL_Event wheelUpReleaseEvent;
    wheelUpReleaseEvent.type = SDL_MOUSEBUTTONUP;
    wheelUpReleaseEvent.button.button = SDL_BUTTON_WHEELUP;
    
    SDL_PushEvent(&wheelUpReleaseEvent);
    inputHandler.pollEvents();
  }
  assert(inputHandler.eventState(Event.WheelUp) == EventState.Released);
  assert(inputHandler.isPressed(Event.WheelUp) == false, "InputHandler didn't register mouse wheel event");*/
  
  // TODO: mouse wheel events get press and release in the same update, so we don't really register it properly
  // need some way to tell that something was pushed and released in the same update
  
  
  // test pixel coords to viewport coords
  inputHandler.setScreenResolution(100, 100);
  assert(inputHandler.pixelToViewPort(50, 50) == vec2(0, -0.0), "50, 50 => " ~ inputHandler.pixelToViewPort(50, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == vec2(-1, 1), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(100, 100) == vec2(1, -1), "100, 100 => " ~ inputHandler.pixelToViewPort(100, 100).toString());
  
  // test nonsquare resolutions, they will have the width or height beyond -1,1 if it's wider or taller than square
  inputHandler.setScreenResolution(200, 100); // -1,-1 to 1,1 defines a square area centered on the screen, with 50 px extra to the left and right
  assert(inputHandler.pixelToViewPort(100, 50) == vec2(0, -0.0), "100, 50 => " ~ inputHandler.pixelToViewPort(100, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == vec2(-2, 1), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(200, 100) == vec2(2, -1), "200, 100 => " ~ inputHandler.pixelToViewPort(200, 100).toString());
  
  inputHandler.setScreenResolution(100, 300); // -1,-1 to 1,1 defines a square area centered on the screen, with 50 px extra to the left and right
  assert(inputHandler.pixelToViewPort(50, 150) == vec2(0, -0.0), "100, 50 => " ~ inputHandler.pixelToViewPort(100, 50).toString());
  assert(inputHandler.pixelToViewPort(0, 0) == vec2(-1, 3), "0, 0 => " ~ inputHandler.pixelToViewPort(0, 0).toString());
  assert(inputHandler.pixelToViewPort(100, 300) == vec2(1, -3), "200, 100 => " ~ inputHandler.pixelToViewPort(200, 100).toString());
  
  
  SDL_Quit();
}+/


enum Event
{
  Escape,
  UpKey, 
  DownKey, 
  LeftKey, 
  RightKey,
  PageUp, 
  PageDown,
  Space,
  LeftButton,
  RightButton,
  MiddleButton,
  //WheelUp,
  //WheelDown,
  Pause,
  ToggleConsole,
  
  StrafeLeft,
  StrafeRight,
  Brake,
}


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
  assert(m_mousePos.ok);
  assert(m_riftOrientation.ok);
  
  //assert(m_screenWidth > 0);
  //assert(m_screenHeight > 0);
}

public:
  this()
  {
    DerelictOVR.load();
    
    initRift(cast(char*)"test".ptr);
    
    clearEventStates();
    
    foreach (event; m_events.keys)
    {
      m_pressedEvents[event] = false;
    }
    
    m_keyEventMapping[SDLK_ESCAPE] = Event.Escape;
    
    m_keyEventMapping[SDLK_LEFT] = Event.LeftKey;
    m_keyEventMapping[SDLK_RIGHT] = Event.RightKey;
    m_keyEventMapping[SDLK_UP] = Event.UpKey;
    m_keyEventMapping[SDLK_DOWN] = Event.DownKey;
    
    m_keyEventMapping[SDLK_z] = Event.StrafeLeft;
    m_keyEventMapping[SDLK_x] = Event.Brake;
    m_keyEventMapping[SDLK_c] = Event.StrafeRight;
    
    m_keyEventMapping[SDLK_PAGEUP] = Event.PageUp;
    m_keyEventMapping[SDLK_PAGEDOWN] = Event.PageDown;
    
    m_keyEventMapping[SDLK_SPACE] = Event.Space;
    
    m_keyEventMapping[SDLK_PAUSE] = Event.Pause;
    
    m_keyEventMapping[SDLK_BACKQUOTE] = Event.ToggleConsole;
    
    m_buttonEventMapping[SDL_BUTTON_LEFT] = Event.LeftButton;
    m_buttonEventMapping[SDL_BUTTON_MIDDLE] = Event.MiddleButton;
    m_buttonEventMapping[SDL_BUTTON_RIGHT] = Event.RightButton;
    
    //m_buttonEventMapping[SDL_BUTTON_WHEELUP] = Event.WheelUp;
    //m_buttonEventMapping[SDL_BUTTON_WHEELDOWN] = Event.WheelDown;
    
    m_mousePos = vec2(0.0, 0.0);
    m_riftOrientation = vec3(0.0, 0.0, 0.0);
  }
  
  void pollEvents()
  {
    clearEventStates();
    
    // clear button event here
    // for now we just register buttonup events, because 
    // wheel events are registered both up and down in the same game update
    foreach (buttonEvent; m_buttonEventMapping.values)
      m_events[buttonEvent] = EventState.Unchanged;
    
    m_keysPressed.length = 0;
    
    SDL_Event event;
    
    // TODO: idiot check to make sure this doesn't go in infinite loop
    while (SDL_PollEvent(&event))    
    {
      receiveEvent(event);
    }
    
    // TODO: hacking in oculus rift tracking here, needs a proper home
    float roll;
    float pitch;
    float yaw;
    float x;
    float y;
    float z;
    
    readRift(&roll, &pitch, &yaw, &x, &y, &z);
    
    m_riftOrientation = vec3(roll, pitch, yaw);
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
    return m_pressedEvents.get(p_event, false);
  }
  
  void setScreenResolution(int p_screenWidth, int p_screenHeight)
  {
    m_screenWidth = p_screenWidth;
    m_screenHeight = p_screenHeight;
  }
  
  vec2 mousePos()
  {
    return m_mousePos;
  }
  
  vec3 riftOrientation()
  {
    return m_riftOrientation;
  }
  
  SDL_Keysym[] getKeysPressed()
  {
    return m_keysPressed;
  }
  
private:
  void receiveEvent(SDL_Event event)
  {
    switch (event.type)
    {
      case SDL_QUIT:
        m_events[Event.Escape] = EventState.Released;
        break;
        
      case SDL_KEYDOWN:
      {
        if (event.key.keysym.sym in m_keyEventMapping)
        {
          m_events[m_keyEventMapping[event.key.keysym.sym]] = EventState.Pressed;
          m_pressedEvents[m_keyEventMapping[event.key.keysym.sym]] = true;
        }
        
        m_keysPressed ~= event.key.keysym;
        
        break;
      }
      
      case SDL_KEYUP:
      {
        if (event.key.keysym.sym in m_keyEventMapping)
        {
          m_events[m_keyEventMapping[event.key.keysym.sym]] = EventState.Released;
          m_pressedEvents[m_keyEventMapping[event.key.keysym.sym]] = false;
        }
        break;
      }
      
      case SDL_MOUSEBUTTONDOWN:
      {
        if (event.button.button in m_buttonEventMapping)
        {
          m_events[m_buttonEventMapping[event.button.button]] = EventState.Pressed;
          m_pressedEvents[m_buttonEventMapping[event.button.button]] = true;
        }
          
        break;
      }
      
      case SDL_MOUSEBUTTONUP:
      {
        if (event.button.button in m_buttonEventMapping)
        {
          m_events[m_buttonEventMapping[event.button.button]] = EventState.Released;
          m_pressedEvents[m_buttonEventMapping[event.button.button]] = false;
        }
        break;
      }
      
      case SDL_MOUSEMOTION:
      {
        //debug writeln("mouse motion: " ~ event.motion.to!string),
        
        m_mousePos = pixelToViewPort(event.motion.x, event.motion.y);
        
        break;
      }
      
      default:
        break;
    }
  }
  
  void clearEventStates()
  {
    foreach (event; m_events.keys)
      m_events[event] = EventState.Unchanged;
  }
  
  void clearEvents()
  {
    foreach (event; m_events.keys)
    {
      m_events[event] = EventState.Unchanged;
      m_pressedEvents[event] = false;
    }
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
  
  vec2 pixelToViewPort(int p_x, int p_y)
  {
    scope(failure) return vec2(0.0, 0.0);
    
    int extraWidth = (m_screenWidth > m_screenHeight ? (m_screenWidth - m_screenHeight) : 0);
    int extraHeight = (m_screenHeight > m_screenWidth ? (m_screenHeight - m_screenWidth) : 0);
    
    assert((cast(float)(m_screenWidth - extraWidth) - 0.5) > 0, "div by 0, m_screenWidth: " ~ to!string(m_screenWidth) ~ ", extraWidth: " ~ to!string(extraWidth));
    assert((cast(float)(m_screenHeight - extraHeight) - 0.5) > 0, "div by 0, m_screenHeight: " ~ to!string(m_screenHeight) ~ ", extraHeight: " ~ to!string(extraHeight));
    
    return vec2((cast(float)(p_x - extraWidth/2)  / cast(float)(m_screenWidth-extraWidth)   - 0.5) * 2.0,
               -(cast(float)(p_y - extraHeight/2) / cast(float)(m_screenHeight-extraHeight) - 0.5) * 2.0);
  }    
  
  
private:  
  EventState[Event] m_events;
  bool[Event] m_pressedEvents;
  
  SDL_Keysym[] m_keysPressed;
  
  // TODO: SDL_Keycode or SDL_Scancode?
  static Event[SDL_Keycode] m_keyEventMapping;
  static Event[SDL_Keycode] m_buttonEventMapping;
  
  
  int m_screenWidth;
  int m_screenHeight;
  
  vec2 m_mousePos;
  
  vec3 m_riftOrientation;
}
