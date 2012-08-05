module MouseInput;

import std.algorithm;
import std.conv;

import Entity;
import InputHandler;


class MouseInput
{
public:

  void handleMouseInput(InputHandler inputHandler, Entity[] draggables)
  {
    if (inputHandler.isPressed(Event.LeftButton))
    {
      // TODO: if we have a dragentity we must ensure it stops getting dragged before it's destroyed or removed by something - lifetime expiration for bullets for example
      if (m_dragEntity is null)
      {
        //foreach (draggable; filter!((Entity entity) { return entity.getValue("draggable") == "true" && m_graphics.hasComponent(entity); })(m_entities.values))
        foreach (draggable; draggables)
        {
          assert(m_graphics.hasComponent(draggable), "Couldn't find graphics component for draggable entity " ~ to!string(draggable.values) ~ " with id " ~ to!string(draggable.id));
          
          auto dragGfxComp = m_graphics.getComponent(draggable);
          // screenAbsolutePosition is true for GUI and screen elements - we don't want to drag them
          if (dragGfxComp.screenAbsolutePosition)
            continue;
          
          if ((dragGfxComp.position - m_graphics.mouseWorldPos).length < dragGfxComp.radius)
          {
            //writeln("mouseover on draggable entity " ~ to!string(draggable.id) ~ " with " ~ to!string(m_connector.getConnectedEntities(draggable).length) ~ " connected entities and " ~ to!string(m_connector.getOwnedEntities(draggable).length) ~ " owned entities");
            
            // we don't want to drag something if it has stuff connected to it, or owns something. 
            // if you want to drag a skeleton module, you should drag off all connected modules first
            // TODO: should be possible to drag stuff with connected stuff, but drag'n'drop needs to be more robust first            
            if (m_connector.getConnectedEntities(draggable).length > 0 || m_connector.getOwnedEntities(draggable).length > 0)
              continue;

            m_dragEntity = draggable;
            
            break;
          }
        }

        if (m_dragEntity !is null)
        {
          if (m_connector.hasComponent(m_dragEntity))
          {
            auto ownerEntity = m_connector.getComponent(m_dragEntity).owner;

            // TODO: disconnectEntity sets the component owner to itself - might cause trouble if we assume it has a separate owner entity when floating around on its own
            m_connector.disconnectEntity(m_dragEntity);
            
            updateOwnerEntity(ownerEntity);
            
            // double check connect point for disconnection
            debug
            {
              assert(m_connector.hasComponent(m_dragEntity));
              
              if (m_dragEntity.getValue("connection").length > 0)
              {
                auto dragEntityConnection = extractEntityIdAndConnectPointName(m_dragEntity.getValue("connection"));
                
                Entity connectEntity;
                
                // TODO: this syntax should work in dmd version 2.058+
                //find!(entity => entity.id == to!int(dragEntityConnection[0]))(m_entities.values);
                
                foreach (entity; m_entities)
                {
                  if (entity.id == to!int(dragEntityConnection[0]))
                  {
                    connectEntity = entity;
                    break;
                  }
                }
                
                assert(connectEntity !is null);
                assert(m_connector.hasComponent(connectEntity), "expected connection comp of entity with values " ~ to!string(connectEntity.values));
                auto comp = m_connector.getComponent(connectEntity);
                
                assert(dragEntityConnection[1] in comp.connectPoints, "Couldn't find connectpoint " ~ dragEntityConnection[1] ~ " in component whose entity has values " ~ to!string(connectEntity.values));
                assert(comp.connectPoints[dragEntityConnection[1]].connectedEntity is null, "Disconnected connectpoint still not empty: " ~ to!string(comp.connectPoints[dragEntityConnection[1]]));
              }
            }
            
            m_dragEntity.values.remove("connection");  
          }
          
          // we don't want dragged entities to be controlled
          if (m_controller.hasComponent(m_dragEntity) && m_dragEntity.getValue("control").length > 0)
          {
            m_dragEntity.setValue("control", "nothing");
            
            m_controller.removeEntity(m_dragEntity);
            
            assert(m_controller.hasComponent(m_dragEntity) == false);
          }

          // TODO: reset physics forces, velocity and other stuff?
        }
      }
    }
  }
Entity m_dragEntity;
}
