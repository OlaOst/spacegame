module IntentSubSystem;

import std.stdio;
import std.conv;

import Entity;
import InputHandler;
import SubSystem;
import Vector : Vector;


unittest
{
  IntentSubSystem intentHandler = new IntentSubSystem();
  
  Entity entity = new Entity();
  
  intentHandler.registerEntity(entity);
  
  InputHandler inputHandler = new InputHandler();
  
  intentHandler.listen(inputHandler);
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
  
private:
  Entity m_entity;
}


class IntentSubSystem : public SubSystem.SubSystem!(IntentComponent)
{
public:

  void listen(InputHandler p_inputHandler)
  {
    foreach (component; components)
      component.force = getForceFromEvents(p_inputHandler);
  }
  

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    return IntentComponent(p_entity);
  }
  
  
private:
  Vector getForceFromEvents(InputHandler p_inputHandler)
  {
    Vector force = Vector.origo;

    foreach (event; p_inputHandler.events.keys)
    {
      float scalar = 1.0 * p_inputHandler.events[event];
      
      if (event == Event.UP)
        force += Vector(0.0, scalar);
      if (event == Event.DOWN)
        force += Vector(0.0, -scalar);
      if (event == Event.LEFT)
        force += Vector(-scalar, 0.0);
      if (event == Event.RIGHT)
        force += Vector(scalar, 0.0);     
    }
    return force;
  }
}
