module SubSystem.Controller;

import FlockControl;
import InputHandler;
import PlayerEngineControl;
import PlayerLauncherControl;
import SubSystem.Base;
import common.Vector;


interface Control
{
  public:
    void update(ControlComponent p_sourceComponent, ControlComponent[] p_otherComponents);
}


struct ControlComponent
{
  this(Control p_control)
  {
    control = p_control;
  }
  
  Control control;
  
  Vector position;
  float angle;
  
  Vector force;
  float torque;
  
  float reload;
}


class Controller : public Base!(ControlComponent)
{
public:
  this(InputHandler p_inputHandler)
  {
    m_inputHandler = p_inputHandler;
  }
  
  void update()
  {
    foreach (component; components)
    {
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
    auto component = ControlComponent();
    
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
    
    return component;
  }
    
private:
  InputHandler m_inputHandler;
}