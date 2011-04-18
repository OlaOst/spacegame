/*
 Copyright (c) 2010 Ola Østtveit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

module Starfield;

import std.random;

import Entity;
import SubSystem.Graphics;
import Vector : Vector;


unittest
{
  Starfield starfield = new Starfield(new Graphics(256, 128), 20);
  
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
  this(Graphics p_graphics, float p_density)
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
      
      star.setValue("drawsource", "Star");
      star.setValue("radius", "0.25");
      
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
  Graphics m_graphics;
  Entity[] m_stars;
}
