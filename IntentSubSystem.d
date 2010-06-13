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
  
  entity.setValue("contextMappings", "5");
  
  entity.setValue("contextMapping.0", "UpKey = Accelerate");
  entity.setValue("contextMapping.1", "DownKey = Decelerate");
  entity.setValue("contextMapping.2", "LeftKey = TurnLeft");
  entity.setValue("contextMapping.3", "RightKey = TurnRight");
  entity.setValue("contextMapping.4", "Space = Fire");
  
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
    
    assert(spawnList.length > 0, "Fire intent didn't register");
  }
  
  
  {
    SDL_Event upEvent;
    
    upEvent.type = SDL_KEYUP;
    upEvent.key.keysym.sym = SDLK_SPACE;
    
    SDL_PushEvent(&upEvent);
    
    inputHandler.pollEvents();
    
    assert(!inputHandler.hasEvent(Event.Space), "Key release didn't register");
    
    Entity[] spawnList;
    
    intentHandler.listen(inputHandler, spawnList);
    
    assert(spawnList.length == 0, "Fire events registered when they shouldn't");
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
  @property void force(Vector p_force)
  {
    m_entity.force = p_force;
  }
  
  @property void torque(float p_torque)
  {
    m_entity.torque = p_torque;
  }
  
  @property Vector force()
  {
    return m_entity.force;
  }
  
  @property float torque()
  {
    return m_entity.torque;
  }
  
  @property float angle()
  {
    return m_entity.angle;
  }
  
  @property InputContext context()
  {
    return m_context;
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
      foreach (event; p_inputHandler.events.keys)
      {
        if (!p_inputHandler.hasEvent(event))
          continue;
        
        auto intent = component.context.getIntent(event);
        
        if (intent == Intent.Fire)
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
        
        if (intent == Intent.Accelerate)
        {
          // unit length force in right direction
          Vector force = Vector(cos(component.angle), sin(component.angle));
          
          force *= 2.0; // should be engine power from entity value
          
          component.force = component.force + force;
        }
        
        if (intent == Intent.Decelerate)
        {
          // unit length force in right direction
          Vector force = Vector(cos(component.angle), sin(component.angle));
          
          force *= -2.0; // should be engine power from entity value
          
          component.force = component.force + force;
        }
        
        if (intent == Intent.TurnLeft)
        {
          component.torque = component.torque + 2.0; // should be engine torque power from entity value
        }
        
        if (intent == Intent.TurnRight)
        {
          component.torque = component.torque - 2.0; // should be engine torque power from entity value
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
      
      Event event = eventFromString(strip(contextMapping[0]));
      Intent intent = intentFromString(strip(contextMapping[1]));
      
      context.addMapping(event, intent);
    }
    
    return IntentComponent(p_entity, context);
  }
}
