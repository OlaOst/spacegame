module IntentSubSystem;

import Entity;
import SubSystem;

unittest
{

}


struct IntentComponent {}


class IntentSubSystem : public SubSystem.SubSystem!(IntentComponent)
{
public:

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    return IntentComponent();
  }
}
