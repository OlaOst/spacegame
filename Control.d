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

module Control;

import std.conv;
import std.stdio;

import Entity;
import SubSystem.Controller;
import InputHandler;
import common.Vector;


unittest
{
  auto controlComponent = ControlComponent();
  
  class MockControl : public Control
  {
  public:
    void update(ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents)
    {
    }
  }
  
  auto controller = new MockControl();
  
  ControlComponent[] components = [];
  
  assert(controller.findComponentsPointedAt(controlComponent, components, 10.0).length == 0);
  
  components ~= ControlComponent();
  
  assert(controller.findComponentsPointedAt(controlComponent, components, 10.0).length == 1);
  
  auto farAwayComponent = ControlComponent();
  
  farAwayComponent.position = Vector(100.0, 100.0);
  components ~= farAwayComponent;
  
  assert(controller.findComponentsPointedAt(controlComponent, components, 10.0).length == 1);
  assert(controller.findComponentsPointedAt(controlComponent, components, 1000.0).length == 2);
}


abstract class Control
{
public:
  abstract void update(ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents);
}
