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
  assert(sys.findComponents(entity).length == 1);  
  assert(sys.getEntity(sys.findComponents(entity)[0]) == entity);
  
  {
    sys.removeEntity(entity);
  }
  assert(sys.components.length == 0);  
  assert(sys.findComponents(entity).length == 0);
  
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
  

//protected:
  ComponentType[] findComponents(Entity p_entity)
  {
    // TODO: this could problably be rangified or lambdified
    
    ComponentType[] foundComponents;
    
    foreach (ComponentType component; m_components.keys)
      if (m_components[component] == p_entity)
        foundComponents ~= component;
        
    return foundComponents;
  }
  
protected:
  
  Entity getEntity(ComponentType p_component)
  {
    return m_components[p_component];
  }
  
  abstract ComponentType createComponent(Entity p_entity);
  
  ComponentType[] components()
  {
    return m_components.keys;
  }
  
  
private:
  Entity[ComponentType] m_components;
}