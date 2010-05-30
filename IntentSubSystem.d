module IntentSubSystem;

import std.conv;
import std.math;
import std.stdio;

import Entity;
import InputHandler;
import SubSystem;
import Vector : Vector;


unittest
{
  IntentSubSystem intentHandler = new IntentSubSystem();
  
  // smoke test
  Entity entity = new Entity();
  InputHandler inputHandler = new InputHandler();
  {
    intentHandler.registerEntity(entity);
    intentHandler.listen(inputHandler);
  }
  
  {
    //Event upEvent = Event.UP;
  }
}


struct IntentComponent 
{
invariant()
{
  assert(m_entity !is null, "Intent component had null entity");
}

public:
  this(Entity p_entity)
  {
    m_entity = p_entity;
  }
  
private:
  void force(Vector p_force)
  {
    m_entity.force = p_force;
  }
  
  void torque(float p_torque)
  {
    m_entity.torque = p_torque;
  }
  
  float angle()
  {
    return m_entity.angle;
  }
  
private:
  Entity m_entity;
}


class IntentSubSystem : public SubSystem.SubSystem!(IntentComponent)
{
public:

  void listen(InputHandler p_inputHandler)
  {
    foreach (component; components)
    {
      //Vector force = getForceFromEvents(p_inputHandler);
      
      Vector force = Vector(cos(component.angle), sin(component.angle));
      
      force *= getForceMagnitudeFromEvents(p_inputHandler);
      
      component.force = force;
      component.torque = getTorqueFromEvents(p_inputHandler);
    }
  }
  

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    return IntentComponent(p_entity);
  }
  
  
private:
  float getForceMagnitudeFromEvents(InputHandler p_inputHandler)
  {
    //Vector force = Vector.origo;
    float forceMagnitude = 0.0;
    
    foreach (event; p_inputHandler.events.keys)
    {
      float scalar = 1.0 * p_inputHandler.events[event];
      
      if (event == Event.UP)
        forceMagnitude += scalar;
      if (event == Event.DOWN)
        forceMagnitude -= scalar;
      //if (event == Event.LEFT)
        //force += Vector(-scalar, 0.0);
      //if (event == Event.RIGHT)
        //force += Vector(scalar, 0.0);
    }
    return forceMagnitude;
  }
  
  float getTorqueFromEvents(InputHandler p_inputHandler)
  {
    float torque = 0.0;

    foreach (event; p_inputHandler.events.keys)
    {
      float scalar = 1.0 * p_inputHandler.events[event];
      
      if (event == Event.LEFT)
        torque += scalar;
      if (event == Event.RIGHT)
        torque -= scalar;
    }
    return torque;
  }
}
