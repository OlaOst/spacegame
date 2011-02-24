module ShaderHandler;

import std.conv;
import std.exception;
import std.math;
import std.stdio;
import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;


unittest
{
  debug writeln("Can use glCreateShaderObjectARB : " ~ to!string(glCreateShaderObjectARB !is null));
  debug writeln("Can use glCreateShader: " ~ to!string(glCreateShader !is null));
  
  debug writeln("are GL_ARB_shader_objects supported? " ~ to!string(DerelictGL.isExtensionSupported("GL_ARB_shader_objects")));
}

GLhandleARB program;

void shadify()
{
  string fragSource = "
    uniform vec4 color;
    varying vec4 vColor;
    void main(void)
    {
      gl_FragColor = vColor ; //+ color; //vec4(0.0, 1.0, 0.0, 1.0);      
    }
  ";
  
  string vertexSource = "
    varying vec4 vColor;
    void main(void)
    {
      vec4 a = gl_Vertex;
      
      vColor = gl_Color.rgba;
      
      //a.x = a.x * 0.5;
      //a.y = a.y * 0.5;
      
      gl_Position = gl_ModelViewProjectionMatrix * a;
    }
  ";
    
  program = glCreateProgramObjectARB();
  
  createShader(fragSource, true, program);
  createShader(vertexSource, false, program);
  
  glLinkProgramARB(program);
  
  glUseProgramObjectARB(program);
}


void createShader(string shaderSource, bool isFragmentShader, GLuint program)
{
  auto shader = glCreateShaderObjectARB(isFragmentShader ? GL_FRAGMENT_SHADER : GL_VERTEX_SHADER);
  
  auto cstr = toStringz(shaderSource);
  int clen = shaderSource.length;
  
  glShaderSourceARB(shader, 1, &cstr, &clen);
  
  glCompileShaderARB(shader);
  
  GLint loglen;
  debug
  {
    glGetObjectParameterivARB(shader, GL_OBJECT_INFO_LOG_LENGTH_ARB, &loglen);
    
    if (loglen >= 0)
    {
      GLchar[] infoLog;
      infoLog.length = loglen;
      glGetInfoLogARB(shader, loglen, &loglen, infoLog.ptr);
      
      writeln(to!string(infoLog));
    }
  }
  
  glGetObjectParameterivARB(shader, GL_OBJECT_COMPILE_STATUS_ARB, &loglen);
  enforce(loglen != 0, "Error compiling shader");
  
  glAttachObjectARB(program, shader);
}


float wavy = 0.0;
void changeStuff()
{
  GLint loc = glGetUniformLocationARB(program, "color");

  wavy += 0.01;
  
  if (loc != -1)
    glUniform4fARB(loc, (cos(wavy)+1.0)/2, 0.0, (sin(wavy)+1.0)/2, 0.0);
}