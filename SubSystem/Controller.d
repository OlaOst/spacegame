module SubSystem.Controller;

import std.conv;
import std.exception;
import std.math;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import FlockControl;
import InputHandler;
import PlayerEngineControl;
import PlayerLauncherControl;
import SubSystem.Base;


interface Control
{
  public:
    void update(ref ControlComponent p_sourceComponent);
    /*out  // contract in interface seems to fuck up things. try again with a dmd later than 2.054, crashes in the parallell forloop in game.d
    {
      writeln("control.update in contract");
      
      assert(p_sourceComponent.position.ok);
      
      foreach (otherComponent; p_otherComponents)
      {
        assert(otherComponent.position.ok);
      }
    }*/
}


class ControlComponent
{
  Control control;
  
  vec2 position = vec2(0.0, 0.0);
  float angle = 0.0;
  
  vec2 velocity = vec2(0.0, 0.0);
  float rotation = 0.0;
  
  vec2 impulse = vec2(0.0, 0.0);
  
  vec2 force = vec2(0.0, 0.0);
  float torque = 0.0;
  
  float thrustForce = 0.0;
  float torqueForce = 0.0;
  float slideForce = 0.0;
  float reload = 0.0;
  float reloadTimeLeft = 0.0;
  
  bool isFiring = false;
  
  float maxSpeed = float.infinity;
  
  string target;
  vec2 targetPosition;
  vec2 targetVelocity;
}


class Controller : public Base!(ControlComponent)
{
public:
  this(InputHandler p_inputHandler)
  {
    m_inputHandler = p_inputHandler;
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
      component.torque = 0.0;
      
      component.isFiring = false;
      
      if (component.reloadTimeLeft > 0.0)
        component.reloadTimeLeft -= m_timeStep;
      
      assert(component.control !is null, "Could not find control when updating controller component");
      
      component.control.update(component);
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
    return (p_entity.getValue("control").length > 0);
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
    //writeln(name ~ " setting angle to " ~ to!string(component.angle) ~ " from " ~ p_entity.getValue("angle"));
    
    if ("target" in p_entity.values)
      component.target = p_entity.getValue("target");
    
    if ("maxSpeed" in p_entity.values)
      component.maxSpeed = to!float(p_entity.getValue("maxSpeed"));
    
    if (p_entity.getValue("control").length > 0)
    {
      switch (p_entity.getValue("control"))
      {
        case "playerEngine":
          component.control = new PlayerEngineControl(m_inputHandler);
          break;
        
        case "playerLauncher":
          component.control = new PlayerLauncherControl(m_inputHandler);
          break;
        
        case "chaser":
          component.control = aiControls["chaser"];
          break;
        
        case "aigunner":        
          component.control = aiControls["aigunner"];
          break;
        
        case "alwaysfire":
          component.control = new class() Control 
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
          break;
        
        case "alwaysaccelerate":
          component.control = new class() Control 
          { 
            override void update(ref ControlComponent p_sourceComponent) 
            { 
              p_sourceComponent.force += vec2(0.0, 1.0 * p_sourceComponent.thrustForce);
            }
          };
          break;

        case "nothing":
          component.control = new class () Control { override void update(ref ControlComponent p_sourceComponent) {} };
          break;
        
        default:
          enforce(false, "Error registering control component, " ~ p_entity.getValue("control") ~ " is an unknown control.");
      }
    }
    
    assert(component.position.ok);
    
    return component;
  }
    
    
public:
  Control[string] aiControls;
  
private:
  InputHandler m_inputHandler;
  
  float m_timeStep;
}
