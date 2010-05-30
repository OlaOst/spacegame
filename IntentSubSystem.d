module IntentSubSystem;

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
  
  Entity entity()
  {
    return m_entity;
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
        component.entity.force = component.entity.force + Vector(0.0, num);
      if (p_event == Event.DOWN)
        component.entity.force = component.entity.force + Vector(0.0, -num);
    }
  }  
}
