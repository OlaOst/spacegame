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

module SubSystem.DragDropHandler;

import std.stdio;

import common.Vector;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  // we have a list of entities that can be dragged
  
  // if we have left mouse click and mouse position is over a draggable entity
  //   then that entity will follow the mouse position until left mouse button is released
  //   if the entity is connected to something we must disconnect it - something like connectionHander.removeEntity(dragEntity) might be enough?
  
  auto sys = new DragDropHandler();
  
  Entity draggable = new Entity();
  draggable.setValue("isBluePrint", "true");
  
  sys.registerEntity(draggable);
  
  assert(sys.hasComponent(draggable));
  
    
}


struct DragDropComponent
{

}


class DragDropHandler : public Base!(DragDropComponent)
{
public:
  void update()
  {
  
  }
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("isBluePrint") == "true";
  }
  
  DragDropComponent createComponent(Entity p_entity)
  {
    return DragDropComponent();
  }
}
