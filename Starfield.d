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
  this(GraphicsSubSystem p_graphics, float p_density)
  {
    populate(p_graphics, p_density);
  }

  void populate(GraphicsSubSystem p_graphics, float p_density)
  {
    foreach (entity; m_stars)
    {
      p_graphics.removeEntity(entity);
    }
    
    m_stars.length = 0;
    
    int stars = cast(int)(p_density / p_graphics.zoom);
    
    if (stars > 1000)
      stars = 1000;
    
    m_stars.length = stars;
    
    for (int n = 0; n < stars; n++)
    {
      Entity star = new Entity();
      
      star.setValue("drawtype", "star");
      
      star.position = Vector(uniform(-2.0/p_graphics.zoom, 2.0/p_graphics.zoom), 
                             uniform(-2.0/p_graphics.zoom, 2.0/p_graphics.zoom));
      
      m_stars[n] = star;
      
      p_graphics.registerEntity(star);
    }
  }
  
private:
  Entity[] m_stars;
}
