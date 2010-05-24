module test;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;

import Display;
import Game;


void main()
{
  Game game = new Game();
  
  initDisplay();

  SDL_Event event;

  bool wannaQuit = false;

  while (!wannaQuit)
  {
    while (SDL_PollEvent(&event))
    {
      switch (event.type)
      {
        case SDL_KEYDOWN:
        {
          switch (event.key.keysym.sym)
          {
            case SDLK_ESCAPE:
              wannaQuit = true;
              
            default:
              break;
          }
        }
        
        case SDL_QUIT:
          wannaQuit = true;
          
        default:
          break;
      }
    }
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    glBegin(GL_TRIANGLES);
      glColor3f(1.0, 0.0, 0.0);
      glVertex3f(0.0, 1.0, -2.0);
      
      glColor3f(0.0, 1.0, 0.0);
      glVertex3f(-0.87, -0.5, -2.0);
      
      glColor3f(0.0, 0.0, 1.0);
      glVertex3f(0.87, -0.5, -2.0);
    glEnd();
    SDL_GL_SwapBuffers();
  }
}
