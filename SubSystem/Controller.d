module SubSystem.Controller;

import std.conv;
import std.stdio;

import FlockControl;
import InputHandler;
import PlayerEngineControl;
import PlayerLauncherControl;
import SubSystem.Base;
import common.Vector;


interface Control
{
  public:
    void update(ref ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents);
    /*in //contract in interface seems to fuck up things. try again with a dmd later than 2.052
    {
      writeln("control.update in contract");
      
      assert(p_sourceComponent.position.isValid());
      
      foreach (otherComponent; p_otherComponents)
      {
        assert(otherComponent.position.isValid());
      }
    }*/
}


class ControlComponent
{
invariant()
{
  assert(m_position.isValid(), "ControlComponent position not valid: " ~ m_position.toString());
  assert(m_force.isValid());
  assert(m_angle == m_angle);
  assert(m_torque == m_torque);
}

public:
  Control control;
  
  @property void position(Vector p_position) { m_position = p_position; }
  @property Vector position() { return m_position; }
    
  @property void angle(float p_angle) { m_angle = p_angle; }
  @property float angle() { return m_angle; }
    
  @property void force(Vector p_force) { m_force = p_force; }
  @property Vector force() { return m_force; }
  
  @property void torque(float p_torque) { m_torque = p_torque; }
  @property float torque() { return m_torque; }
  
  @property void reload(float p_reload) { m_reload = p_reload; }
  @property float reload() { return m_reload; }
    
private:
  Vector m_position = Vector.origo;
  float m_angle = 0.0;
  
  Vector m_force = Vector.origo;
  float m_torque = 0.0;
  
  float m_reload = 0.0;
}


class Controller : public Base!(ControlComponent)
{
public:
  this(InputHandler p_inputHandler)
  {
    m_inputHandler = p_inputHandler;
  }
  
  void update()
  in
  {
    foreach (component; components)
      assert(component.position.isValid());
  }
  body
  {
    foreach (component; components)
    {
      // reset component force and torque before update
      component.force = Vector.origo;
      component.torque = 0.0;
      
      component.control.update(component, components);
    }
  }
    
    
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("control").length > 0;
  }
   
  ControlComponent createComponent(Entity p_entity)
  {
    auto component = new ControlComponent();
    
    if (p_entity.getValue("control") == "playerEngine")
    {
      component.control = new PlayerEngineControl(m_inputHandler);
    }
    if (p_entity.getValue("control") == "playerLauncher")
    {
      component.control = new PlayerLauncherControl(m_inputHandler);
    }
    
    if (p_entity.getValue("control") == "flocker")
    {
      component.control = new FlockControl(2.5, 0.5, 20.0, 0.3);
    }
    
    assert(component.position.isValid());
    
    return component;
  }
    
private:
  InputHandler m_inputHandler;
}
