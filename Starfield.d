module Starfield;

import std.random;

import Entity;
import GraphicsSubSystem;
import Vector : Vector;


unittest
{
  Starfield starfield = new Starfield(new GraphicsSubSystem(), 20);
  
  assert(starfield.m_stars.length > 0);
}


// TODO: parallax scrolling stuff
class Starfield
{
invariant()
{
  assert(m_graphics !is null);
}

public:
  // density - avg stars per square 'meter'
  this(GraphicsSubSystem p_graphics, float p_density)
  {
    m_graphics = p_graphics;
    populate(p_density);
  }

  void populate(float p_density)
  {
    foreach (entity; m_stars)
    {
      m_graphics.removeEntity(entity);
    }
    
    m_stars.length = 0;
    
    int stars = cast(int)(p_density / m_graphics.zoom);
    
    if (stars > 1000)
      stars = 1000;
    
    m_stars.length = stars;
    
    for (int n = 0; n < stars; n++)
    {
      Entity star = new Entity();
      
      star.setValue("drawtype", "star");
      star.setValue("radius", "0.15");
      
      star.angle = uniform(-3.14, 3.14);
      
      star.position = Vector(uniform(-3.0/m_graphics.zoom, 3.0/m_graphics.zoom), 
                             uniform(-3.0/m_graphics.zoom, 3.0/m_graphics.zoom),
                             uniform(-5.0, -3.0));
      
      m_stars[n] = star;
      
      m_graphics.registerEntity(star);
    }
  }
  
  
  void draw()
  {
    m_graphics.draw();
  }
  
private:
  GraphicsSubSystem m_graphics;
  Entity[] m_stars;
}
