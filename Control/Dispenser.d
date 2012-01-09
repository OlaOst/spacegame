/*
 Copyright (c) 2011 Ola Østtveit

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

module Control.Dispenser;

import std.stdio;

import gl3n.linalg;

import Control.ControlBase;
import InputHandler;
import SubSystem.Controller;


class Dispenser : public ControlBase
{
public:
  this(InputHandler p_inputHandler)
  {
    inputHandler = p_inputHandler;
  }
  
  override void update(ref ControlComponent sourceComponent)
  {
    if (inputHandler.isPressed(Event.LeftButton))
    {
      writeln("source - mouse pos length: " ~ to!string((sourceComponent.position - mouseWorldPos).length) ~ ", sourcecomp radius: " ~ to!string(sourceComponent.radius));
      if ((sourceComponent.position - mouseWorldPos).length < sourceComponent.radius)
      {
        writeln("spawnOnClick controller detected mouse button press on component");
      
        sourceComponent.isFiring = true;
      }
      else
      {
        sourceComponent.isFiring = false;
      }
    }
  }
  
  void setMouseWorldPos(vec2 p_mouseWorldPos)
  {
    mouseWorldPos = p_mouseWorldPos;
  }
  
private:
  InputHandler inputHandler;
  
  vec2 mouseWorldPos;
}