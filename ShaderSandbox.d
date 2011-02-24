module ShaderSandbox;

import derelict.opengl.gl;
import derelict.opengl.glext;

import Display;
import InputHandler;
import ShaderHandler;


void main(string args[])
{
  InputHandler input = new InputHandler();
  initDisplay(800, 600);
  
  makeShader();
  
  while (input.eventState(Event.Escape) != EventState.Released)
  {
    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_QUADS);
      glVertex3f(-1.0, -1.0, -1.0);
      
      glVertex3f(-1.0, 1.0, -1.0);
      
      glVertex3f(1.0, 1.0, -1.0);
      
      glVertex3f(1.0, -1.0, -1.0);
    glEnd();
    
    swapBuffers();
    input.pollEvents();
  }
}


void makeShader()
{
  string fragSource = "
    //uniform sampler2D mytex;
    //varying vec2 texCoord;
    
    void main(void)
    {
      //vec4 pixel_color = texture2D(tex, texCoord);
      
      vec2 pos = mod(gl_FragCoord.xy, vec2(50.0)) - vec2(25.0);
      float dist_squared = dot(pos, pos);
      
      gl_FragColor = (dist_squared < 400.0) ? vec4(0.9, dist_squared/400.0, 0.9, 1.0) : vec4(dist_squared/1800.0, 0.2, 0.4, 1.0);
    }
  ";
  
  string vertexSource = "
    varying vec2 texCoord;
    
    void main(void)
    {      
      gl_Position = vec4(gl_Vertex.xy, 0.0, 1.0);
      texCoord = 0.5 * gl_Position.xy + vec2(0.5);
    }
  ";
    
  program = glCreateProgramObjectARB();
  
  createShader(vertexSource, false, program);
  createShader(fragSource, true, program);
  
  glLinkProgramARB(program);
  
  glUseProgramObjectARB(program);
}