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
    /*out  // contract in interface seems to fuck up things. try again with a dmd later than 2.054, crashes in the parallell forloop in game.d
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

  @property void isFiring(bool p_isFiring) { m_isFiring = p_isFiring; }
  @property bool isFiring() { return m_isFiring; }
  
private:
  Vector m_position = Vector.origo;
  float m_angle = 0.0;
  
  Vector m_force = Vector.origo;
  float m_torque = 0.0;
  
  float m_reload = 0.0;
  
  bool m_isFiring = false;
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
      
      component.isFiring = false;
      
      if (component.reload > 0.0)
        component.reload = component.reload - m_timeStep;
      
      component.control.update(component, components);
    }
  }
    
  
  void setTimeStep(float p_timeStep)
  out
  {
    assert(m_timeStep >= 0.0);
  }
  body
  {
    m_timeStep = p_timeStep;
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
      component.control = new FlockControl(10.0, 1.5,     // distance & weight for avoid rule
                                           50.0, 0.2);    // distance & weight for flock rule
    }
    
    assert(component.position.isValid());
    
    return component;
  }
    
private:
  InputHandler m_inputHandler;
  
  float m_timeStep;
}
