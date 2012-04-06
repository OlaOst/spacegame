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
import std.exception;
import std.stdio;
import std.string;

import derelict.sdl.image;
import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  initDisplay(1, 1);
  teardownDisplay();
}

void teardownDisplay()
{
  //SDL_Quit();
}

void initDisplay(int p_screenWidth, int p_screenHeight)
{
  //version(DerelictGL_ALL) debug writeln("DerelictGL_ALL defined");
  //version(DerelictGL_ARB) debug writeln("DerelictGL_ARB defined");
  //version(DerelictGL_EXT) debug writeln("DerelictGL_EXT defined");
  
  DerelictSDL.load();
  DerelictSDLImage.load();
  DerelictGL.load();
  DerelictGLU.load();
  
  enforce(SDL_Init(SDL_INIT_VIDEO) == 0, "Failed to initialize SDL: " ~ to!string(SDL_GetError()));
  enforce(IMG_Init(IMG_INIT_PNG) == IMG_INIT_PNG, "Error initializing png loader: " ~ to!string(IMG_GetError()));
  
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  SDL_SetVideoMode(p_screenWidth, p_screenHeight, 24, SDL_OPENGL);
  //SDL_WM_SetCaption(toStringz("hello world"), null);
  
  //DerelictGL.loadExtensions();
  
  //debug writeln("OpenGL version: " ~ to!string(glGetString(GL_VERSION)));
  //debug writeln("DerelictGL.maxVersion: " ~ to!string(DerelictGL.maxVersion));
  //debug writeln("OpenGL renderer: " ~ to!string(glGetString(GL_RENDERER)));
  //debug writeln("OpenGL vendor: " ~ to!string(glGetString(GL_VENDOR)));
  
  //string[] loaded = DerelictGL.loadedExtensionNames();
  
  //shadify();
  
  setupGL(p_screenWidth, p_screenHeight);
}


void setupGL(int p_screenWidth, int p_screenHeight)
{
  glMatrixMode(GL_PROJECTION);
  
  glLoadIdentity();
  
  //gluPerspective(90.0, cast(float)p_screenWidth / cast(float)p_screenHeight, 0.1, 100.0);
  
  float widthHeightRatio = cast(float)p_screenWidth / cast(float)p_screenHeight;
  
  //gluOrtho2D(-widthHeightRatio, widthHeightRatio, -1.0, 1.0);
  glOrtho(-widthHeightRatio, widthHeightRatio, -1.0, 1.0, 0.0, 65536.0);
  
  // make textures show up in the expected direction (stuff pointing up in image edit program should be pointing up in the game)
  //glMatrixMode(GL_TEXTURE);
  //glRotatef(180.0, 0.0, 0.0, 1.0);
  //glScalef(-1.0, 1.0, 1.0);
  
  glMatrixMode(GL_MODELVIEW);
  
  glLoadIdentity();
  
  //glEnable(GL_DEPTH_TEST);
  glDisable(GL_DEPTH_TEST);
  
  //glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}


void swapBuffers()
{
  SDL_GL_SwapBuffers();
  
  //changeStuff();
  
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();
}
