module ShaderHandler;

import std.conv;
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

void shadify()
{
  string fragSource = "
    void main(void)
    {
      gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
    }
  ";
  
  string vertexSource = "
    void main(void)
    {
      vec4 a = gl_Vertex;
      
      a.x = a.x * 0.5;
      a.y = a.y * 1.5;
      
      gl_Position = gl_ModelViewProjectionMatrix * a;
    }
  ";
    
  auto program = glCreateProgramObjectARB();
  
  createShader(fragSource, true, program);
  //createShader(vertexSource, true, program);
  
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
  
  glAttachObjectARB(program, shader);
}