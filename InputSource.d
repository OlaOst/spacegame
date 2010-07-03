module InputSource;

import PhysicsSubSystem;


unittest
{
  class MockInputSource : public InputSource
  {
  public:
    void update(PhysicsComponent p_component)
    in
    {
      assert(p_component !is null);
    }
    body
    {
      
    }
  }
  
  InputSource source = new MockInputSource();
  
  source.update(new PhysicsComponent(new Entity()));
}


interface InputSource
{
public:
  void update(PhysicsComponent p_component)
  in
  {
    assert(p_component !is null);
  }
}