module Starfield;

import std.random;

import Entity;
import GraphicsSubSystem;
import Vector : Vector;


unittest
{
  GraphicsSubSystem graphics = new GraphicsSubSystem();
  
  Starfield starfield = new Starfield(graphics, 20);
}


// TODO: parallax scrolling stuff
class Starfield
{
public:
  // density - avg stars per square 'meter'
  this(GraphicsSubSystem p_graphics, int p_density)
  {
    for (int n = 0; n < p_density; n++)
    {
      Entity star = new Entity(true);
      
      star.position = Vector(uniform(-1.0, 1.0), uniform(-1.0, 1.0));
      
      p_graphics.registerEntity(star);
    }
  }

private:
}
