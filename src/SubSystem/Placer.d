
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

import gl3n.linalg;
import gl3n.math;

import SubSystem.Base;


class PlacerComponent
{
  vec2 position = vec2(0.0, 0.0);  
  float angle = 0.0;
}


class Placer : Base!(PlacerComponent)
{
public:
  this()
  {
    m_timeStep = 0.0;
  }
  
  
  void update() 
  {
    foreach (component; components)
    {
      // wraparound/clamp component positions
      //if (component.position.length > 100.0)
        //component.position = component.position * -1;
      /*if (abs(component.position.x) > 100.0)
        component.position = vec2(component.position.x * -1, component.position.y);
      if (abs(component.position.y) > 100.0)
        component.position = vec2(component.position.x, component.position.y * -1);*/
    }
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return "position" in p_entity || 
           "relativePosition" in p_entity;
  }
  
  
  PlacerComponent createComponent(Entity p_entity)
  {
    auto component = new PlacerComponent();
    
    if (p_entity.getValue("position").length > 0)
      component.position = vec2(p_entity.getValue("position").to!(float[])[0..2]);
      
    if (p_entity.getValue("angle").length > 0)
      component.angle = to!float(p_entity.getValue("angle")) * PI_180;
    
    //writeln("creating placercomponent, angle is " ~ to!string(component.angle) ~ ", created from " ~ to!string(p_entity.values));
      
    return component;
  }
  
  override void updateEntity(Entity entity)
  {
    if (hasComponent(entity))
    {
      auto component = getComponent(entity);
      
      //debug writeln("placer setting entity " ~ entity.values.to!string ~ " position to " ~ component.position.to!string);
      
      entity.values["position"] = component.position.to!string;
      entity.values["angle"] = component.angle.to!string;
    }
  }
  
private:
  float m_timeStep;
}
