module PlayerLauncherControl;

import std.conv;
import std.stdio;

import Control;
import InputHandler;
import ConnectionSubSystem;
import Vector : Vector;


unittest
{
  auto playerControl = new PlayerLauncherControl(new InputHandler());
  
}


class PlayerLauncherControl : public Control
{
invariant()
{
  assert(m_inputHandler !is null);
}


public:
  this(InputHandler p_inputHandler)
  {
    m_inputHandler = p_inputHandler;
  }
  
  
  void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents)
  out
  {
    //assert(p_sourceComponent.force.isValid());
    //assert(p_sourceComponent.torque == p_sourceComponent.torque);
  }
  body
  {
    //auto dir = Vector.fromAngle(p_sourceComponent.entity.angle);
    
    //auto force = p_sourceComponent.force;
    //auto torque = p_sourceComponent.torque;
    
    if (m_inputHandler.hasEvent(Event.Space))
    {
      if (p_sourceComponent.reload <= 0.0)
      {
        Entity bullet = new Entity();

        bullet.setValue("drawtype", "bullet");
        bullet.setValue("collisionType", "bullet");
        bullet.setValue("radius", "0.1");
        bullet.setValue("mass", "0.2");
        bullet.setValue("spawnedFrom", to!string(p_sourceComponent.entity.id));
        
        //bullet.setValue("velocity", 

        bullet.position = p_sourceComponent.entity.position;
        bullet.angle = p_sourceComponent.entity.angle;
        
        bullet.lifetime = 5.0;
                
        p_sourceComponent.entity.addSpawn(bullet);
        
        p_sourceComponent.reload = 0.1;
      }
    }
    
    //p_sourceComponent.force = force;
    //p_sourceComponent.torque = torque;
  }
  
  
private:
  InputHandler m_inputHandler;
}