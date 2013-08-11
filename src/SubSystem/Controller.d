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

module SubSystem.Controller;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import Control.ControlBase;
import SubSystem.Base;


class ControlComponent
{
  this()
  {
      id = idCounter++;
  }
    
  ControlBase control;
  
  //bool updatedPosition = false;
  
  vec2 position = vec2(0.0, 0.0);
  float angle = 0.0;
  
  vec2 velocity = vec2(0.0, 0.0);
  float rotation = 0.0;
  
  vec2 impulse = vec2(0.0, 0.0);
  float angularImpulse = 0.0;
  
  vec2 force = vec2(0.0, 0.0);
  float torque = 0.0;
  
  float thrustForce = 0.0;
  float torqueForce = 0.0;
  float slideForce = 0.0;
  float reload = 0.0;
  float reloadTimeLeft = 0.0;
  
  float radius = 1.0;
  
  bool isFiring = false;
  
  float maxSpeed = float.infinity;
  
  string target;
  vec2 targetPosition;
  vec2 targetVelocity;
  
  override int opCmp(Object other)
  {
    return id - (cast(ControlComponent)other).id;
  }
  
  immutable int id;

  
private:
  shared synchronized static int idCounter;
}


class Controller : Base!(ControlComponent)
{
public:
  this()
  {
  }
  
  void update()
  in
  {
    foreach (ref component; components)
      assert(component.position.ok);
  }
  body
  {
    foreach (ref component; components)
    {
      // reset component force and torque before update
      component.force = vec2(0.0, 0.0);
      component.impulse = vec2(0.0, 0.0);
      component.angularImpulse = 0.0;
      component.torque = 0.0;
      
      //component.updatedPosition = false;
      
      component.isFiring = false;
      
      if (component.reloadTimeLeft > 0.0)
        component.reloadTimeLeft -= m_timeStep;
      
      assert(component.control !is null, "Could not find control when updating controller component");
      
      component.control.update(component);
      
      debug writeln("updated controlcomp pos: " ~ component.position.to!string);
      //debug writeln("updated controlcomp isFiring: " ~ component.isFiring.to!string);
    }
  }
  
  void setTimeStep(float p_timeStep)
  out
  {
    assert(m_timeStep >= 0.0);
  }
  body
  {
    m_timeStep = p_timeStep;
  }
   
   
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return ("control" in p_entity.values) !is null;
  }
   
  ControlComponent createComponent(Entity p_entity)
  {
    auto component = new ControlComponent();
    
    if (p_entity.getValue("thrustForce").length > 0)
      component.thrustForce = to!float(p_entity.getValue("thrustForce"));
    
    if (p_entity.getValue("torqueForce").length > 0)
      component.torqueForce = to!float(p_entity.getValue("torqueForce"));
    
    if (p_entity.getValue("slideForce").length > 0)
      component.slideForce = to!float(p_entity.getValue("slideForce"));

    if (p_entity.getValue("angle").length > 0)
      component.angle = to!float(p_entity.getValue("angle")) * PI_180;
      
    if (p_entity.getValue("reloadTime").length > 0)
    {
      component.reloadTimeLeft = component.reload = to!float(p_entity.getValue("reloadTime"));
    }
    
    if ("target" in p_entity.values)
      component.target = p_entity.getValue("target");
    
    if ("maxSpeed" in p_entity.values)
      component.maxSpeed = to!float(p_entity.getValue("maxSpeed"));
    
    if ("radius" in p_entity.values)
      component.radius = to!float(p_entity.getValue("radius"));
    
    if ("control" in p_entity.values)
    {
      if (p_entity["control"] in controls)
      {
        component.control = controls[p_entity["control"]];      
      }
      
      // TODO: put these controls in their separate files for better discovery?
      else if (p_entity["control"] == "AlwaysFire")
      {
        component.control = new class() ControlBase
        { 
          override void update(ref ControlComponent p_sourceComponent) 
          { 
            p_sourceComponent.isFiring = false;
  
            if (p_sourceComponent.reloadTimeLeft <= 0.0)
            {
              p_sourceComponent.isFiring = true;
              p_sourceComponent.reloadTimeLeft = p_sourceComponent.reload;
            }
          }
        };
      }
      
      else if (p_entity["control"] == "AlwaysAccelerate")
      {
        component.control = new class() ControlBase
        { 
          override void update(ref ControlComponent p_sourceComponent) 
          {
            p_sourceComponent.force += vec2(0.0, 1.0 * p_sourceComponent.thrustForce);
          }
        };
      }
      
      else if (p_entity["control"] == "KeepPosition")
      {
        auto positionToKeep = vec2(p_entity["positionToKeep"].to!(float[])[0..2]);
        component.control = new class(positionToKeep) ControlBase
        {
          this(vec2 positionToKeep)
          {
            this.positionToKeep = positionToKeep;
          }
          
          override void update(ref ControlComponent p_sourceComponent)
          {
            //debug writeln("KeepPosition update setting position from " ~ p_sourceComponent.position.to!string ~ " to " ~ positionToKeep.to!string);
            p_sourceComponent.position = positionToKeep;
          }
          
          private vec2 positionToKeep;
        };
      }
        
      else if (p_entity["control"] == "nothing")
      {
        component.control = new class () ControlBase { override void update(ref ControlComponent p_sourceComponent) {} };
      } 
      else
      {
        enforce(false, "Error registering control component, " ~ p_entity.getValue("control") ~ " is an unknown control.");
      }
    }
    
    assert(component.position.ok);
    
    return component;
  } 
  
  void updateEntity(Entity entity)
  {
  if (hasComponent(entity))
    {
      auto component = getComponent(entity);
      
      entity.values["isFiring"] = component.isFiring.to!string;
    }
  }
  
public:
  ControlBase[string] controls;
  
private:
  float m_timeStep;
}
