module Game;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import Display;
import Input;
import World;


unittest
{
  Game game = new Game();

  // TODO: assert that Derelict SDL and GL loaded OK
  
  assert(game.updateCount == 0);
  {
    game.update();
  }
  assert(game.updateCount == 1);
  
  assert(game.delta == 0.0);
  {
    SDL_Event upEvent;
    upEvent.type = SDL_KEYDOWN;
    upEvent.key.keysym.sym = SDLK_UP;
    
    SDL_PushEvent(&upEvent);
    
    game.update();
  }
  assert(game.m_input.hasEvent(Event.UP));
  assert(game.delta > 0.0);
  
  {
    game.update();
  }
  assert(!game.m_input.hasEvent(Event.UP), "Input didn't clear event after update");
  
  {
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    
    SDL_PushEvent(&quitEvent);

    game.update();
  }
  assert(!game.running, "Game didn't respond properly to quit event");
}


class Game
{
public:
  this()
  {
    m_updateCount = 0;
    m_running = true;
    
    m_input = new Input();
    m_world = new World();
    
    initDisplay();
    
    delta = 0.0;
  }
 
  void run()
  {
    while (m_running)
    {
      update();
    }
  }
  
private:
  int updateCount()
  {
    return m_updateCount;
  }
  
  void update()
  {
    m_updateCount++;
    
    draw();
    swapBuffers();
    
    m_input.pollEvents();
    
    if (m_input.hasEvent(Event.UP))
      delta += 1.0;
    if (m_input.hasEvent(Event.DOWN))
      delta -= 1.0;
      
    if (m_input.hasEvent(Event.QUIT))
      m_running = false;
  }
  
  bool running()
  {
    return m_running;
  }
    
    
  void draw()
  {
    glRotatef(delta, 0.0, 0.0, 1.0);
    
    glBegin(GL_TRIANGLES);
      glColor3f(1.0, 0.0, 0.0);
      glVertex3f(0.0, 1.0, -2.0);
      
      glColor3f(0.0, 1.0, 0.0);
      glVertex3f(-0.87, -0.5, -2.0);
      
      glColor3f(0.0, 0.0, 1.0);
      glVertex3f(0.87, -0.5, -2.0);
    glEnd();
  }
  
private:
  int m_updateCount;
  bool m_running;
  
  Input m_input;
  World m_world;
  
  float delta;
}
