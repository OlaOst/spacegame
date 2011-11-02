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

module SubSystem.Placer;

import std.conv;
import std.math;
import std.stdio;

import common.Vector;
import SubSystem.Base;


struct PlacerComponent
{
  Vector position = Vector.origo;
  Vector velocity = Vector.origo;
  
  float angle = 0.0;
  float rotation = 0.0;
}


class Placer : public Base!(PlacerComponent)
{
public:
  void update() 
  {
    foreach (component; components)
    {
      // do wraparound stuff
      //if (component.position.length2d > 100.0)
        //component.position = component.position * -1;
      if (abs(component.position.x) > 100.0)
        component.position = Vector(component.position.x * -1, component.position.y);
      if (abs(component.position.y) > 100.0)
        component.position = Vector(component.position.x, component.position.y * -1);
    }
  }
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("position").length > 0;
  }
  
  
  PlacerComponent createComponent(Entity p_entity)
  {
    auto component = PlacerComponent();
    
    if (p_entity.getValue("position").length > 0)
      component.position = Vector.fromString(p_entity.getValue("position"));
    if (p_entity.getValue("velocity").length > 0)
      component.velocity = Vector.fromString(p_entity.getValue("velocity"));
      
    if (p_entity.getValue("angle").length > 0)
      component.angle = to!float(p_entity.getValue("angle")) * (PI / 180.0);
    if (p_entity.getValue("rotation").length > 0)
      component.rotation = to!float(p_entity.getValue("rotation"));
      
    return component;
  }
}
