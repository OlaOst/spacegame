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
  
  assert(sys.m_components.length == 0);
  {
    Entity entity = new Entity();
    
    sys.registerEntity(entity);
  }
  assert(sys.m_components.length == 1);
}


abstract class SubSystem(ComponentType)
{
public:
  void registerEntity(Entity p_entity)
  {
    auto component = createComponent(p_entity);
    m_components ~= component;
  }
  
  
protected:
  abstract ComponentType createComponent(Entity p_entity);
  
  
private:
  ComponentType[] m_components;
}