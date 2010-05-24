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
  }
}
