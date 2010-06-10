module SubSystem;

import Entity;


unittest
{
  struct MockComponent {}
  
  class MockSubSystem : public SubSystem!(MockComponent)
  {
    protected:
      MockComponent createComponent(Entity p_entity)
      {
        return MockComponent();
      }
  }
  MockSubSystem sys = new MockSubSystem();
  
  Entity entity = new Entity();
  
  assert(sys.components.length == 0);
  {
    sys.registerEntity(entity);
  }
  assert(sys.components.length == 1);
  
  {
    sys.removeEntity(entity);
  }
  assert(sys.components.length == 0);
  
}


abstract class SubSystem(ComponentType)
{
public:
  void registerEntity(Entity p_entity)
  {
    auto component = createComponent(p_entity);
    m_components[component] = p_entity;
  }
  
  void removeEntity(Entity p_entity)
  {
    foreach (ComponentType component; m_components.keys)
      if (m_components[component] == p_entity)
        m_components.remove(component);
  }
  
  ComponentType[] findComponents(Entity p_entity)
  {
    // TODO: this could problaby be rangified
    
    ComponentType[] foundComponents;
    
    foreach (ComponentType component; m_components.keys)
      if (m_components[component] == p_entity)
        foundComponents ~= component;
        
    return foundComponents;
  }
  
  
protected:
  abstract ComponentType createComponent(Entity p_entity);
  
  ComponentType[] components()
  {
    return m_components.keys;
  }
  
  
private:
  Entity[ComponentType] m_components;
}