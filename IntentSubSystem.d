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
  Vector force()
  {
    return m_entity.force;
  }
  
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
    foreach (event; p_inputHandler.events.keys)
    {
      handleEvent(event, p_inputHandler.events[event]);
    }
  }
  

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    return IntentComponent(p_entity);
  }
  
  
private:
  void handleEvent(InputHandler.Event p_event, uint num)
  {
    foreach (component; components)
    {      
      if (p_event == Event.UP)
        component.force = /*component.force +*/ Vector(0.0, cast(float)(num));
      if (p_event == Event.DOWN)
        component.force = /*component.force +*/ Vector(0.0, -cast(float)(num));
    }
  }  
}
