module World;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import Entity;
import Input;


unittest
{
  World world = new World();
  
  assert(world.m_entities.length == 0);
  {
    Entity entity = new Entity();
    
    world.registerEntity(entity);
  }
  assert(world.m_entities.length == 1);
  
  assert(world.m_entities[0].position == Position.origo);
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    Input input = new Input();
    
    input.pollEvents();
    
    world.handleEvents(input);
  }
  assert(world.m_entities[0].position.y > 0.0);
}


class World
{
public:
    
  void handleEvents(Input p_input)
  {
    foreach (event; p_input.events.keys)
      handleEvent(event, p_input.events[event]);
  }
  
  void registerEntity(Entity p_entity)
  {
    m_entities ~= p_entity;
  }

private:
  void handleEvent(Input.Event p_event, uint num)
  {
    foreach (entity; m_entities)
    {
      if (p_event == Event.UP)
        entity.addPosition(Position(0.0, num));
      if (p_event == Event.DOWN)
        entity.addPosition(Position(0.0, -num));
    }
  }  
  
private:
  Entity[] m_entities;
}
