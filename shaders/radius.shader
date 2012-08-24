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
  
  uniform vec2 position;
  uniform float radius;
  
  in vec2 coords;

  out vec4 color;

  float distance(vec2 one, vec2 two)
  {
    vec2 relative = one - two;
    
    return sqrt(relative.x * relative.x + relative.y * relative.y);
  }
  
  void main(void)
  {
    if (distance(coords, position) < radius)
    {
      float c = distance(coords, position) / radius;
      
      color = vec4(c, c, c, pow(c, 8));
    }
    else
      discard;
  }
