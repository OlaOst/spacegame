/*
 Copyright (c) 2010 Ola Østtveit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

module Display;

import std.conv;
import std.stdio;
import std.string;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;


void initDisplay(int p_screenWidth, int p_screenHeight)
{
  DerelictSDL.load();
  DerelictGL.load();
  DerelictGLU.load();
  
  SDL_Init(SDL_INIT_VIDEO);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  
  SDL_SetVideoMode(p_screenWidth, p_screenHeight, 24, SDL_OPENGL);
  SDL_WM_SetCaption(toStringz("hello world"), null);
  
  DerelictGL.loadExtensions();
  
  debug writeln("OpenGL version: " ~ to!string(glGetString(GL_VERSION)));
  debug writeln("OpenGL renderer: " ~ to!string(glGetString(GL_RENDERER)));
  debug writeln("OpenGL vendor: " ~ to!string(glGetString(GL_VENDOR)));
  /*debug writeln("Extensions: " ~ to!string(glGetString(GL_EXTENSIONS)));
  
  string[] loaded = DerelictGL.loadedExtensionNames;
  string[] notLoaded = DerelictGL.notLoadedExtensionNames;
   
  writeln("Loaded extensions:");
  foreach (n; loaded)
    writeln(n);
   
  writeln("Not loaded extensions:");
  foreach (n; notLoaded)
    writeln(n); */
  
  //auto shader = glCreateShader(GL_FRAGMENT_SHADER);
   
  setupGL(p_screenWidth, p_screenHeight);
}

void setupGL(int p_screenWidth, int p_screenHeight)
{
  glMatrixMode(GL_PROJECTION);
  
  glLoadIdentity();
  
  gluPerspective(90.0, cast(float)p_screenWidth / cast(float)p_screenHeight, 0.1, 100.0);
  
  glMatrixMode(GL_MODELVIEW);
  
  glLoadIdentity();
  
  glEnable(GL_DEPTH_TEST);

  //uint texture;
  //glGenTextures(1, &texture);
  //glBindTexture(GL_TEXTURE_2D, texture);
  //glTexImage2D(GL_TEXTURE_2D, 0, 1, 16, 16, 0, GL_ALPHA, GL_UNSIGNED_BYTE, face.glyph.bitmap.buffer);
  
  //glCreateShader(GL_VERTEX_SHADER);
  
  //string[] sources = ["return;"];
  
  //glShaderSource(shaderid, 1, sources, null);
}

void swapBuffers()
{
  SDL_GL_SwapBuffers();
  
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}