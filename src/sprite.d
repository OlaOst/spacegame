module sprite;

import std.algorithm;
import std.array;

import gl3n.linalg;


struct Sprite
{
  static immutable vec2[] texCoords = [vec2(0.0, 0.0),
                                       vec2(0.0, 1.0),
                                       vec2(1.0, 1.0),
                                       vec2(1.0, 0.0)];
                              
  static immutable vec3[] origo = [vec3(-1.0, -1.0, 0.0),
                                    vec3(-1.0,  1.0, 0.0),
                                    vec3( 1.0,  1.0, 0.0),
                                    vec3( 1.0, -1.0, 0.0)];
                                    
  vec3 position = vec3(0.0, 0.0, 0.0);
  float angle = 0.0;
  float scale = 1.0;
  
  vec3[] _vertices;
  
  @property vec3[] vertices()
  {
    transformVertices();
    return _vertices;
  }
  
  @property vec3[] verticesForQuadTriangles()
  {
    auto verts = vertices;
    return verts[0..3] ~ verts[0..1] ~ verts[2..4];
  }
  
  @property vec2[] texCoordsForQuadTriangles()
  {
    return (texCoords[0..3] ~ texCoords[0..1] ~ texCoords[2..4]).dup;
  }
  
  vec2[] frameCoordsForQuadTriangles(int frame, int size)
  {
    frame = (size*size - frame) % (size*size);
    int row = (frame / size) % size;
    int col = (size-frame-1) % size;
    
    auto frameCoords = [vec2(1.0/size * col, 1.0/size * row),
                        vec2(1.0/size * col, 1.0/size * (row+1)),
                        vec2(1.0/size * (col+1), 1.0/size * (row+1)),
                        vec2(1.0/size * (col+1), 1.0/size * row)];
    
    return (frameCoords[0..3] ~ frameCoords[0..1] ~ frameCoords[2..4]);
  }

  this(vec3 position, float angle, float scale)
  {
    this.position = position;
    this.angle = angle;
    this.scale = scale;
  }

  
  unittest
  {
    auto vecApproxEqual = function bool (vec3 lhs, vec3 rhs) { return approxEqual(lhs.x, rhs.x) && approxEqual(lhs.y, rhs.y) && approxEqual(lhs.z, rhs.z); };
    
    Sprite translateTest;
    translateTest.position = vec3(1.0, 0.0, 0.0);
    
    vec3[] translationExpected = translateTest.origo.dup.map!(vector => vector + translateTest.position).array();
    
    auto translationResult = translateTest.vertices;
    
    assert(equal!(vecApproxEqual)(translationResult, translationExpected), "expected " ~ translationExpected.to!string ~ ", got " ~ translationResult.to!string);
    
    
    Sprite rotateTest;
    rotateTest.angle = PI / 4.0;
    
    vec3[] rotateExpected = rotateTest.origo.dup.map!(vector => vec3(cos(rotateTest.angle) * vector.x - sin(rotateTest.angle) * vector.y, 
                                                                     sin(rotateTest.angle) * vector.x + cos(rotateTest.angle) * vector.y, 
                                                                     vector.z)).array();
    
    auto rotateResult = rotateTest.vertices;
    
    assert(equal!(vecApproxEqual)(rotateResult, rotateExpected), "expected " ~ rotateExpected.to!string ~ ", got " ~ rotateResult.to!string);
    
    
    Sprite translateAndRotateTest;
    translateAndRotateTest.position = vec3(10.0, 0.0, 0.0);
    translateAndRotateTest.angle = PI / 3.0;
    
    auto translateAndRotateExpected = translateAndRotateTest.origo.dup.map!(vector => vec3(cos(translateAndRotateTest.angle) * vector.x - sin(translateAndRotateTest.angle) * vector.y, 
                                                                                           sin(translateAndRotateTest.angle) * vector.x + cos(translateAndRotateTest.angle) * vector.y, 
                                                                                               vector.z))
                                                                      .map!(vector => vector + translateAndRotateTest.position).array();
    
    auto translateAndRotateResult = translateAndRotateTest.vertices;
   
    assert(equal!(vecApproxEqual)(translateAndRotateResult, translateAndRotateExpected), "expected " ~ translateAndRotateExpected.to!string ~ ", got " ~ translateAndRotateResult.to!string);
    
    
    Sprite translateRotateAndScaleTest;
    translateRotateAndScaleTest.position = vec3(10.0, 0.0, 0.0);
    translateRotateAndScaleTest.angle = PI / 2.0;
    translateRotateAndScaleTest.scale = 0.5;
    
    auto translateRotateAndScaleExpected = translateRotateAndScaleTest.origo.dup.map!(vector => vec3(cos(translateRotateAndScaleTest.angle) * vector.x - sin(translateRotateAndScaleTest.angle) * vector.y, 
                                                                                                     sin(translateRotateAndScaleTest.angle) * vector.x + cos(translateRotateAndScaleTest.angle) * vector.y, 
                                                                                                     vector.z))
                                                                                .map!(vector => vec3(vector.x * translateRotateAndScaleTest.scale, vector.y * translateRotateAndScaleTest.scale, vector.z))
                                                                                .map!(vector => vector + translateRotateAndScaleTest.position).array();
    
    auto translateRotateAndScaleResult = translateRotateAndScaleTest.vertices;
   
    assert(equal!(vecApproxEqual)(translateRotateAndScaleResult, translateRotateAndScaleExpected), "expected " ~ translateRotateAndScaleExpected.to!string ~ ", got " ~ translateRotateAndScaleResult.to!string);
  }
  void transformVertices()
  {
    auto transform = mat4.translation(position.x, position.y, position.z).rotatez(angle).scale(scale, scale, 1.0);
    
    _vertices = origo.dup;
    
    foreach (ref vertex; _vertices)
      vertex = vec3((vec4(vertex, 1.0) * transform));
      
    //for (int index = 0; index < origo.length; index++)
    //{
      //_vertices[index] = (vec4(vector, 1.0) * transform).xyz;
    //}
    
    //_vertices = origo.dup.map!(vector => (vec4(vector, 1.0) * transform).xyz).array().to!(Vector!(float,3)[]);
  }
}
