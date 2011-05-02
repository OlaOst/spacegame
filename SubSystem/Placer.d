module SubSystem.Placer;

import std.conv;
import std.stdio;

import common.Vector;
import SubSystem.Base;


struct PlaceComponent
{
  Vector position = Vector.origo;
  Vector velocity = Vector.origo;
  
  float angle = 0.0;
  float rotation = 0.0;
}


class Placer : public Base!(PlaceComponent)
{
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("position").length > 0;
  }
  
  
  PlaceComponent createComponent(Entity p_entity)
  {
    auto component = PlaceComponent();
    
    if (p_entity.getValue("position").length > 0)
      component.position = Vector.fromString(p_entity.getValue("position"));
    if (p_entity.getValue("velocity").length > 0)
      component.velocity = Vector.fromString(p_entity.getValue("velocity"));
      
    if (p_entity.getValue("angle").length > 0)
      component.angle = to!float(p_entity.getValue("angle"));
    if (p_entity.getValue("rotation").length > 0)
      component.rotation = to!float(p_entity.getValue("rotation"));
      
    return component;
  }
}
