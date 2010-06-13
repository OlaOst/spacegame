module IntentSubSystem;

import std.conv;
import std.math;
import std.stdio;
import std.string;

import derelict.sdl.sdl;

import Entity;
import InputContext;
import InputHandler;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  IntentSubSystem intentHandler = new IntentSubSystem();
  
  // smoke test
  Entity entity = new Entity();
  
  //entity.setValue("contextMappings", "1");
  
  InputHandler inputHandler = new InputHandler();
  {
    intentHandler.registerEntity(entity);
    
    Entity[] spawnList;
    
    intentHandler.listen(inputHandler, spawnList);
  }
  
  {
    SDL_Event chooseEvent;
    
    chooseEvent.type = SDL_KEYDOWN;
    chooseEvent.key.keysym.sym = SDLK_SPACE;
    
    SDL_PushEvent(&chooseEvent);
    
    inputHandler.pollEvents();
    
    assert(inputHandler.hasEvent(Event.Space));
    
    Entity[] spawnList;
    
    intentHandler.listen(inputHandler, spawnList);
    
    assert(spawnList.length == 1);
  }
}


struct IntentComponent 
{
invariant()
{
  assert(m_entity !is null, "Intent component got null entity");
}

public:
  this(Entity p_entity, InputContext p_context)
  {
    m_entity = p_entity;
    m_context = p_context;
  }
  
private:
  void force(Vector p_force)
  {
    m_entity.force = p_force;
  }
  
  void torque(float p_torque)
  {
    m_entity.torque = p_torque;
  }
  
  float angle()
  {
    return m_entity.angle;
  }
  
private:
  Entity m_entity;
  
  InputContext m_context;
}


class IntentSubSystem : public SubSystem!(IntentComponent)
{
public:

  void listen(InputHandler p_inputHandler, out Entity[] p_spawnList)
  {
    foreach (component; components)
    {
      // unit length force in right direction
      Vector force = Vector(cos(component.angle), sin(component.angle));
      
      // put correct length on vector
      force *= getForceMagnitudeFromEvents(p_inputHandler);
      
      component.force = force;
      component.torque = getTorqueFromEvents(p_inputHandler);
      
      if (Event.Space in p_inputHandler.events)
      {
        for (int n = 0; n < p_inputHandler.events[Event.Space]; n++)
        {
          Entity spawn = new Entity();
          
          spawn.lifetime = 2.0;
          
          spawn.setValue("drawtype", "bullet");
          
          // then the subsystems that need specific info, ie physics need to know velocity of spawnedFrom entity
          // then it can lookup its components for the spawnedFrom entity
          spawn.setValue("spawnedFrom", to!string(component.m_entity.id));
          
          spawn.position = component.m_entity.position;
          spawn.angle = component.m_entity.angle;
          
          p_spawnList ~= spawn;
        }
      }
    }
  }
  

protected:
  IntentComponent createComponent(Entity p_entity)
  {
    InputContext context = new InputContext();
    
    int contextMappings = 0;
    
    if (p_entity.getValue("contextMappings").length > 0)
      contextMappings = to!int(p_entity.getValue("contextMappings"));
    
    for (int n = 0; n < contextMappings; n++)
    {
      string contextMappingString = p_entity.getValue("contextMapping." ~ to!string(n));
      
      assert(contextMappingString.length > 0, "Found empty context mapping");
      
      string[] contextMapping = split(contextMappingString, "=");
      
      assert(contextMapping.length == 2, "Found invalid context mapping: " ~ contextMappingString);
      
      Event event = eventFromString(contextMapping[0]);
      Intent intent = intentFromString(contextMapping[1]);
      
      context.addMapping(event, intent);
    }
    
    return IntentComponent(p_entity, context);
  }
  
  
private:
  float getForceMagnitudeFromEvents(InputHandler p_inputHandler)
  {
    //Vector force = Vector.origo;
    float forceMagnitude = 0.0;
    
    foreach (event; p_inputHandler.events.keys)
    {
      float scalar = 2.0 * p_inputHandler.events[event];
      
      if (event == Event.UpKey)
        forceMagnitude += scalar;
      if (event == Event.DownKey)
        forceMagnitude -= scalar;
      //if (event == Event.LeftKey)
        //force += Vector(-scalar, 0.0);
      //if (event == Event.RightKey)
        //force += Vector(scalar, 0.0);
    }
    return forceMagnitude;
  }
  
  float getTorqueFromEvents(InputHandler p_inputHandler)
  {
    float torque = 0.0;

    foreach (event; p_inputHandler.events.keys)
    {
      float scalar = 2.0 * p_inputHandler.events[event];
      
      if (event == Event.LeftKey)
        torque += scalar;
      if (event == Event.RightKey)
        torque -= scalar;
    }
    return torque;
  }
}
