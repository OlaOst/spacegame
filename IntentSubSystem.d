module IntentSubSystem;

import InputHandler;
import SubSystem;


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
}


class IntentSubSystem : public SubSystem.SubSystem!(IntentComponent)
{
public:

  void listen(InputHandler p_inputHandler)
  {
    
  }
  

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    return IntentComponent();
  }
}
