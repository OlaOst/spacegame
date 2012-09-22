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

module EntityConsole;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

import derelict.opengl3.gl3;
import gl3n.linalg;

import Console;
import Game;
import SubSystem.Graphics;


class EntityConsole : Console
{
public:
  this(Game p_game)
  {
    game = p_game;
    entity = null;
    
    executeCommand = &this.executeEntityCommand;
  }
  
  void setEntity(Entity p_entity)
  {
    entity = p_entity;
    
    if (entity !is null)
      active = true;
  }
  
  override bool isActive()
  {
    return entity !is null;
  }
  
  OutputLine[] executeEntityCommand(string command)
  {
    if (entity is null)
    {
      return [];
    }
    
    if (command == "help")
    {
      return [OutputLine("Commands available: ", vec3(1, 1, 1)),
              OutputLine("help                - shows this list", vec3(1, 1, 1)),
              OutputLine("exit/quit           - closes this console", vec3(1, 1, 1)),
              OutputLine("values              - list values in entity", vec3(1, 1, 1)),
              OutputLine("value key           - prints value of given key", vec3(1, 1, 1)),
              OutputLine("keys                - list keys in entity", vec3(1, 1, 1)),
              OutputLine("register            - registers entity", vec3(1, 1, 1)),
              OutputLine("set key value       - sets key to the given value", vec3(1, 1, 1)),
              OutputLine("Don't panic", vec3(0, 1, 0)),];
    }
    else if (command == "exit" || command == "quit")
    {
      entity = null;
      return [];
    }
    else if (command == "values")
    {
      OutputLine[] values;
      foreach (key, value; entity.values)
        values ~= OutputLine(key ~ ": " ~ to!string(value.until("\\n")), vec3(1, 1, 1));
      
      values ~= OutputLine("", vec3(1, 1, 1));
      
      return values;
    }
    else if (command.startsWith("value"))
    {
      command.skipOver("value");
      
      auto key = command.strip;
      
      return [OutputLine(entity.getValue(key), vec3(1, 1, 1))];
    }
    else if (command == "keys")
    {
      OutputLine[] lines;
      
      auto keys = entity.values.keys.dup;
      
      for (int n = 0; n < keys.length; n += 2)
        lines ~= OutputLine(to!string(keys[n..min(n+2, keys.length-1)]), vec3(1, 1, 1));
      
      lines ~= OutputLine("", vec3(1, 1, 1));
      
      return lines;
    }
    else if (command == "register")
    {
      game.registerEntity(entity);
      
      return [OutputLine("Registered entity " ~ to!string(entity.id), vec3(1, 1, 1))];
    }
    else if (command.startsWith("set"))
    {
      try
      {
        command.skipOver("set");
        
        auto parameters = command.strip.split(" ");
        
        string key = parameters[0];
        string value = reduce!((a, b) => (a ~= " " ~ b))(parameters[1..$]);
        
        entity.setValue(key, value);
      
        string text = to!string(entity.values);
        
        return [OutputLine(to!string(text.until("\\n")), vec3(1, 1, 1))];        
      }
      catch (ConvException e) {}
    }
    
    return [OutputLine("?? " ~ command, vec3(1, 0, 0))];
  }
  
  /*string output(float elapsedTime)
  {
    string[] output;
    
    if (to!int(elapsedTime*2) % 2 == 0)
      output ~= inputLine;
    else
      output ~= inputLine ~ "_";
      
    foreach (outputLine; take(outputBuffer.retro, 12))
    {
      //glTranslatef(0.0, 1.0, 0.0);
      //glColor3f(outputLine.color.r, outputLine.color.g, outputLine.color.b);
      output ~= outputLine.text;
    }
  }*/
  
  override void display(Graphics graphics, float elapsedTime)
  {
    if (!isActive() || entity is null)
      return;
      
    assert(entity !is null);
    assert(game !is null),
    assert(game.m_placer.hasComponent(entity));
    
    auto placerComponent = game.m_placer.getComponent(entity);
    
    /*glPushMatrix();
      glScalef(graphics.zoom, graphics.zoom, 1.0);
      glTranslatef(-graphics.getCenterEntityPosition.x, -graphics.getCenterEntityPosition.y, 0.0);
      glTranslatef(placerComponent.position.x, placerComponent.position.y, 0.0);
      glScalef(1.0 / graphics.zoom, 1.0 / graphics.zoom, 1.0);    
    
      glPushMatrix();
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

        foreach (outputLine; take(outputBuffer.retro, 12))
        {
          glTranslatef(0.0, 1.0, 0.0);
          glColor3f(outputLine.color.r, outputLine.color.g, outputLine.color.b);
          graphics.renderString(outputLine.text);
        }
      glPopMatrix();
    glPopMatrix();*/
  }
  

private:
  Game game;
  Entity entity;
}
