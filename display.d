module Display;

import std.conv;
import std.stdio;
import std.string;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;


void initDisplay()
{
  DerelictSDL.load();
  DerelictGL.load();
  DerelictGLU.load();
  
  SDL_Init(SDL_INIT_VIDEO);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  
  SDL_SetVideoMode(800, 600, 24, SDL_OPENGL);
  SDL_WM_SetCaption(toStringz("hello world"), null);
  
  DerelictGL.loadExtensions();
  
  //debug writeln("OpenGL version: " ~ to!string(glGetString(GL_VERSION)));
  //debug writeln("OpenGL renderer: " ~ to!string(glGetString(GL_RENDERER)));
  //debug writeln("OpenGL vendor: " ~ to!string(glGetString(GL_VENDOR)));
  //debug writeln("Extensions: " ~ to!string(glGetString(GL_EXTENSIONS)));
  
  //auto shader = glCreateShader(GL_FRAGMENT_SHADER);
   
  setupGL();
}

void setupGL()
{
  glMatrixMode(GL_PROJECTION);
  
  glLoadIdentity();
  
  gluPerspective(90.0, 800.0 / 600.0, 0.1, 100.0);
  
  glMatrixMode(GL_MODELVIEW);
  
  glLoadIdentity();
  
  //glCreateShader(GL_VERTEX_SHADER);
  
  //string[] sources = ["return;"];
  
  //glShaderSource(shaderid, 1, sources, null);
}
