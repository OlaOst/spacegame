module World;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import Input;


unittest
{
  World world = new World();
  
  assert(world.m_delta == 0.0);
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    Input input = new Input();
    
    input.pollEvents();
    
    world.handleEvents(input);
  }
  assert(world.m_delta > 0.0);
}


class World
{
public:
  this()
  {
    m_delta = 0.0;
  }
  
  void draw()
  {
    glRotatef(m_delta, 0.0, 0.0, 1.0);
    
    glBegin(GL_TRIANGLES);
      glColor3f(1.0, 0.0, 0.0);
      glVertex3f(0.0, 1.0, -2.0);
      
      glColor3f(0.0, 1.0, 0.0);
      glVertex3f(-0.87, -0.5, -2.0);
      
      glColor3f(0.0, 0.0, 1.0);
      glVertex3f(0.87, -0.5, -2.0);
    glEnd();
  }
  
  void handleEvents(Input p_input)
  {
    foreach (event; p_input.events.keys)
      handleEvent(event, p_input.events[event]);
  }
  
private:
  void handleEvent(Input.Event p_event, int num)
  {
    if (p_event == Event.UP)
      m_delta += num;
    if (p_event == Event.DOWN)
      m_delta -= num;
  }
  
private:
  float m_delta;
}
