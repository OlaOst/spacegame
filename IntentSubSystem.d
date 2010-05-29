module IntentSubSystem;

import Entity;

unittest
{
  IntentSubSystem intentHandler = new IntentSubSystem();
  
  assert(intentHandler.entities.length == 0);
  {
    Entity entity = new Entity();
    intentHandler.registerEntity(entity);
  }
  assert(intentHandler.entities.length == 1);
}


class IntentSubSystem
{
public:

  Entity[] entities()
  {
    return m_entities;
  }
  
  void registerEntity(Entity p_entity)
  {
    m_entities ~= p_entity;
  }
  
  
private:
  Entity[] m_entities;
}