vertex:
  layout(location = 0) in vec3 position;
  layout(location = 2) in vec4 colors;

  out vec4 colorIn;

  void main(void)
  {
    colorIn = colors;
    
    gl_Position = vec4(position, 1.0);
  }
  
fragment:
  in vec4 colorIn;
  out vec4 color;
  
  void main(void)
  {
    color = colorIn;
  }
