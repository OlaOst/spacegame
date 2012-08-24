vertex:
  layout(location = 0) in vec3 position;
  layout(location = 1) in vec2 texCoords;

  out vec2 coords;

  void main(void)
  {
    coords = texCoords.st;
    
    gl_Position = vec4(position, 1.0);
  }
  
fragment:
  uniform sampler2D colorMap;
  in vec2 coords;
  out vec4 color;

  void main(void)
  {  
    color = texture2D(colorMap, coords.st).rgba;
  }
