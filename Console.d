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

import std.conv;
import std.range;
import std.stdio;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import SubSystem.Graphics;
import InputHandler;


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


class Console
{
public:
  void display(Graphics graphics, float elapsedTime)
  {
    glPushMatrix();
      glTranslatef(-0.9, -0.9, 0.0);
      glScalef(0.1, 0.1, 1.0);      
      
      glColor3f(0.2, 1.0, 0.4);
      
      if (to!int(elapsedTime*2) % 2 == 0)
        graphics.renderString(inputLine);
      else
        graphics.renderString(inputLine ~ "_");
        
      glColor3f(1.0, 1.0, 1.0);
      foreach (outputLine; take(outputBuffer.retro,10))
      {
        glTranslatef(0.0, 1.0, 0.0);
        graphics.renderString(outputLine);
      }
    glPopMatrix();
    
    
    glPushMatrix();
      glColor4f(0.0, 0.0, 0.5, 0.5);
      glBegin(GL_QUADS);
        glVertex2f(-1.0, -0.95);
        glVertex2f(-1.0,  0.3);
        glVertex2f( 0.9,  0.3);
        glVertex2f( 0.9, -0.95);
      glEnd();
    glPopMatrix();
  }
  
  void handleInput(InputHandler input)
  {
    foreach (key; input.getNonMappedKeys)
    {
      if (key == SDLK_KP_ENTER || key == SDLK_RETURN)
      {
        outputBuffer ~= inputLine;
        inputLine = "";
      }
      else if (key == SDLK_BACKSPACE && inputLine.length > 0)
        inputLine = inputLine[0..$-1];
      else if (key >= SDLK_SPACE && key <= 255)
        inputLine ~= to!char(key);
    }
  }
  
private:
  string inputLine;
  
  string[] outputBuffer;
}
