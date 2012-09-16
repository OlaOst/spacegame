vertex:
  layout(location = 0) in vec3 position;
  layout(location = 1) in vec2 texCoords;
  layout(location = 2) in vec3 colors;

  out vec2 coords;
  out vec3 colorIn;

  void main(void)
  {
    coords = texCoords.st;
    
    colorIn = colors;
    
    gl_Position = vec4(position, 1.0);
  }
  
fragment:
  uniform sampler2D colorMap;
  
  in vec2 coords;  
  
  in vec3 colorIn;
  out vec4 color;
  
  void main(void)
  {
    vec2 center = coords - vec2(0.5, 0.5);
    float d = sqrt(center.x*center.x + center.y*center.y) * 2.0;
    
    float b = max(abs(center.x), abs(center.y)) * 2.0;
    
    if (d < 1.0)
      color = vec4(colorIn, pow(d, 8));
    else if (b > 0.8)
      color = vec4(colorIn, pow(b, 16));
    else
      discard;
  }
