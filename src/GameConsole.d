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

module GameConsole;

import std.range;

import derelict.opengl.gl;
import gl3n.linalg;

import Console;
import Game;
import SubSystem.Graphics;


class GameConsole : Console
{
public:
  this(Game p_game)
  {
    game = p_game;
    
    executeCommand = &game.executeCommand;
  }
  
  
  override void display(Graphics graphics, float elapsedTime)
  {
    if (!active)
      return;
      
    glPushMatrix();
      glColor4f(0.0, 0.0, 0.5, 0.8);
      glBegin(GL_QUADS);
        glVertex2f(-1.3, -0.95);
        glVertex2f(-1.3,  0.95);
        glVertex2f( 1.3,  0.95);
        glVertex2f( 1.3, -0.95);
      glEnd();
    glPopMatrix();
      
    glPushMatrix();
      glTranslatef(-1.2, -0.9, 0.0);
      glScalef(0.05, 0.05, 1.0);      
      
      glColor3f(0.2, 1.0, 0.4);
      
      if (to!int(elapsedTime*2) % 2 == 0)
        graphics.renderString(inputLine);
      else
        graphics.renderString(inputLine ~ "_");

      foreach (outputLine; take(outputBuffer.retro, 34))
      {
        glTranslatef(0.0, 1.0, 0.0);
        glColor3f(outputLine.color.r, outputLine.color.g, outputLine.color.b);
        graphics.renderString(outputLine.text);
      }
    glPopMatrix();
  }
  

private:
  Game game;
}
