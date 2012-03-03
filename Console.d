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

import std.algorithm;
import std.conv;
import std.range;
import std.stdio;
import std.string;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import gl3n.linalg;

import SubSystem.Graphics;
//import SubSystem.Placer;
import InputHandler;

public import Game;


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
    m_active = false;
  }
  
  abstract void display(Graphics graphics, float elapsedTime);
  
  
  void handleInput(InputHandler input)
  {
    if (input.eventState(Event.ToggleConsole) == EventState.Released)
      m_active = !m_active;
    
    if (m_active)
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
    return m_active;
  }
  
private:
  string inputLine;
  
  OutputLine[] outputBuffer;
  
  bool m_active;
  
  OutputLine[] delegate (string command) executeCommand;
}


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
    if (!m_active)
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


class EntityConsole : Console
{
public:
  this(Game p_game)
  {
    game = p_game;
    m_entity = null;
    
    executeCommand = &this.executeEntityCommand;
  }
  
  void setEntity(Entity p_entity)
  {
    m_entity = p_entity;
    
    if (m_entity !is null)
      m_active = true;
  }
  
  override bool isActive()
  {
    return m_entity !is null;
  }
  
  OutputLine[] executeEntityCommand(string command)
  {
    if (command == "help")
    {
      return [OutputLine("Commands available: ", vec3(1, 1, 1)),
              OutputLine("help                - shows this list", vec3(1, 1, 1)),
              OutputLine("exit/quit           - closes this console", vec3(1, 1, 1)),
              OutputLine("values              - list values in entity", vec3(1, 1, 1)),
              OutputLine("register            - registers entity", vec3(1, 1, 1)),
              OutputLine("set key value       - sets key to the given value", vec3(1, 1, 1)),
              OutputLine("Don't panic", vec3(0, 1, 0)),];
    }
    else if (command == "exit" || command == "quit")
    {
      m_entity = null;
      return [];
    }
    else if (command == "values")
    {
      OutputLine[] values;
      foreach (key, value; m_entity.values)
        values ~= OutputLine(key ~ ": " ~ to!string(value.until("\\n")), vec3(1, 1, 1));
      
      values ~= OutputLine("", vec3(1, 1, 1));
      
      return values;
    }
    else if (command.startsWith("register"))
    {
      game.registerEntity(m_entity);
      
      return [OutputLine("Registered entity " ~ to!string(m_entity.id), vec3(1, 1, 1))];
    }
    else if (command.startsWith("set"))
    {
      try
      {
        command.skipOver("set");
        
        auto parameters = command.strip.split(" ");
        
        string key = parameters[0];
        string value = reduce!((a, b) => (a ~= " " ~ b))(parameters[1..$]);
        
        m_entity.setValue(key, value);
      
        string text = to!string(m_entity.values);
        
        return [OutputLine(to!string(text.until("\\n")), vec3(1, 1, 1))];        
      }
      catch (ConvException e) {}
    }
    
    return [OutputLine("?? " ~ command, vec3(1, 0, 0))];
  }
  
  override void display(Graphics graphics, float elapsedTime)
  {
    if (!isActive() || m_entity is null)
      return;
      
    assert(m_entity !is null);
    assert(game !is null),
    assert(game.m_placer.hasComponent(m_entity));
    
    auto placerComponent = game.m_placer.getComponent(m_entity);
    
    glPushMatrix();
      //glScalef(graphics.zoom, graphics.zoom, 1.0);
      //glTranslatef(placerComponent.position.x, placerComponent.position.y, 0.0);
      //glScalef(1.0 / graphics.zoom, 1.0 / graphics.zoom, 1.0);    
    
      glColor4f(0.0, 0.5, 0.5, 0.8);
      glBegin(GL_QUADS);
        glVertex2f( 0.0, -0.2);
        glVertex2f( 0.0,  0.5);
        glVertex2f( 0.9,  0.5);
        glVertex2f( 0.9, -0.2);
      glEnd();
    glPopMatrix();
    
    glPushMatrix();
      glTranslatef(0.05, -0.15, 0.0);
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
  //Placer placer;
  Entity m_entity;
}