module CollisionSubSystem;

import Entity;
import SubSystem : SubSystem;


unittest
{
  auto sys = new CollisionSubSystem();
}


class CollisionComponent
{

}


class CollisionSubSystem : public SubSystem!(CollisionComponent)
{
protected:
  CollisionComponent createComponent(Entity p_entity)
  {
    return new CollisionComponent();
  }
}
