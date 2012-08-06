/*
 Copyright (c) 2012 Ola Østtveit

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

module Console;

import std.string;

import derelict.opengl3.gl3;
import derelict.sdl2.sdl;

import gl3n.linalg;

import InputHandler;
import SubSystem.Graphics;


unittest
{
  // a console is a command-like tool that can parse and execute debug commands, and display debug information
  
  // it needs to show the latest output
  
  // it should have an input line that the user can type commands into
  
  // it should hide and deactivate when the toggle console button is pressed
  
  // example debugging would be something like:
  // getValues(playerShip)              - prints all name/value pairs for the player ship entity
  // playerShip.position = 0 0          - set position value to 0 0
  // updateEntity(playerShip)           - updates player entity, will put the playership at 0 0
  // newShip.source = simpleship.txt    - creates a new entity if there is none named newShip
  // newShip.position = 10 10           - sets the position value of the new ship
  // newShip.control = NpcPilot         - sets the control value so the ship will be computer controlled
  // registerEntity(newShip)            - registers the new entity, spawning it at 10 10
}


struct OutputLine
{
  string text;
  vec3 color;
}


abstract class Console
{
public:
  this()
  {
    active = false;
  }
  
  abstract void display(Graphics graphics, float elapsedTime);
  
  void handleInput(InputHandler input)
  {
    if (input.eventState(Event.ToggleConsole) == EventState.Released)
      active = !active;
    
    if (active)
    {
      foreach (keysym; input.getKeysPressed())
      {
        auto key = keysym.sym;
        
        if (key == SDLK_KP_ENTER || key == SDLK_RETURN)
        {
          outputBuffer ~= OutputLine(inputLine.strip, vec3(0, 1, 0)); // echo the given command
          outputBuffer ~= executeCommand(inputLine.strip); // append result of the command, in form of zero or more output lines
          inputLine = "";
        }
        else if (key == SDLK_BACKSPACE && inputLine.length > 0)
          inputLine = inputLine[0..$-1];
        else if (keysym.unicode > 0 && key != SDLK_BACKQUOTE)
        {
          inputLine ~= to!dchar(keysym.unicode);
        }
      }
    }
  }
  
  bool isActive()
  {
    return active;
  }
  

protected:
  bool active;
  OutputLine[] delegate (string command) executeCommand;
  string inputLine;
  OutputLine[] outputBuffer;
}
