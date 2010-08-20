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

module GraphicsSubSystem;

import std.conv;
import std.math;
import std.stdio;

import derelict.opengl.gl;

import Entity;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  
  GraphicsSubSystem graphics = new GraphicsSubSystem();
  
  Entity deleteTest = new Entity();
  
  deleteTest.setValue("drawtype", "triangle");
  deleteTest.setValue("radius", "1.0");
  deleteTest.setValue("keepInCenter", "true");
  
  graphics.registerEntity(deleteTest);
  
  graphics.draw();
  
  {
    // will cause access violation, but we're not supposed to delete objects anyway - use removeEntity instead
    //delete deleteTest;
    
    graphics.removeEntity(deleteTest);
  
    graphics.draw();
  }
}


enum Drawtype
{
  Unknown,
  Triangle,
  Star,
  Bullet
}

struct GraphicsComponent 
{
public:
  this(Entity p_entity, Drawtype p_drawType, float p_radius)
  {
    entity = p_entity;
    drawType = p_drawType;
    radius = p_radius;
  }
  
  Vector position()
  {
    return entity.position;
  }
  
  float angle()
  {
    return entity.angle;
  }
  
  Drawtype drawType;
  float radius;
  
private:
  Entity entity;  
}


class GraphicsSubSystem : public SubSystem!(GraphicsComponent)
{
invariant()
{
  assert(m_zoom > 0.0);
}


public:
  this()
  {
    m_zoom = 0.02;
  }
  
  
  void draw()
  {
    glPushMatrix();
    
    glScalef(m_zoom, m_zoom, 1.0);
    
    // pull back camera a bit so we can see entities with z=0.0
    glTranslatef(0.0, 0.0, -1.0);
    
    if (m_centerEntity !is null)
      glTranslatef(-m_centerEntity.position.x, -m_centerEntity.position.y, 0.0);
    
    foreach (component; components)
    {
      glPushMatrix();
      
      assert(component.position.isValid());
      
      glTranslatef(component.position.x, component.position.y, component.position.z);
      glRotatef(component.angle * (180.0 / PI), 0.0, 0.0, 1.0);
      
      if (component.drawType == Drawtype.Triangle)
      {
        glBegin(GL_TRIANGLES);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
          {
            glColor3f(cos(angle*2), sin(angle/2), 0.0);
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
        glEnd();
      }
      else if (component.drawType == Drawtype.Star)
      {
        glBegin(GL_TRIANGLE_FAN);
          glColor3f(1.0, 1.0, 1.0);
          glVertex3f(0.0, 0.0, 0.0);
          glColor3f(0.0, 0.5, 1.0);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 5)
          {
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
          glVertex3f(cos(0.0) * component.radius, sin(0.0) * component.radius, 0.0);
        glEnd();
      }
      else if (component.drawType == Drawtype.Bullet)
      {
        glBegin(GL_TRIANGLE_FAN);
          glColor3f(1.0, 1.0, 0.0);
          glVertex3f(0.0, 0.0, 0.0);
          glColor3f(1.0, 0.5, 0.0);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 4)
          {
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
          glVertex3f(cos(0.0) * component.radius, sin(0.0) * component.radius, 0.0);
        glEnd();
      }
      else if (component.drawType == Drawtype.Unknown)
      {
        // TODO: should just draw a big fat question mark here
        // or a cow
        
        glBegin(GL_TRIANGLE_FAN);
          glColor3f(0.0, 0.0, 0.0);
          glVertex3f(0.0, 0.0, 0.0);
          glColor3f(1.0, 0.0, 0.0);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 4)
          {
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
          glVertex3f(cos(0.0) * component.radius, sin(0.0) * component.radius, 0.0);
        glEnd();
      }
      
      // draw circle indicating radius in debug mode
      debug
      {
        glColor3f(1.0, 1.0, 1.0);
        glBegin(GL_LINE_LOOP);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 16)
        {
          glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
        }
        glEnd();
      }
      
      glPopMatrix();
    }
    
    glPopMatrix();
  }
  
  void zoomIn(float p_time)
  {
    m_zoom += m_zoom * p_time;
  }
  
  void zoomOut(float p_time)
  {
    m_zoom -= m_zoom * p_time;
  }
  
  float zoom()
  {
    return m_zoom;
  }
  
protected:
  GraphicsComponent createComponent(Entity p_entity)
  {
    if (p_entity.getValue("keepInCenter") == "true")
    {
      m_centerEntity = p_entity;
    }
    
    assert(p_entity.getValue("radius").length > 0, "Couldn't find radius for graphics component");
    float radius = to!float(p_entity.getValue("radius"));
    
    if (p_entity.getValue("drawtype") == "star")
      return GraphicsComponent(p_entity, Drawtype.Star, radius);
    else if (p_entity.getValue("drawtype") == "triangle")
      return GraphicsComponent(p_entity, Drawtype.Triangle, radius);
    else if (p_entity.getValue("drawtype") == "bullet")
      return GraphicsComponent(p_entity, Drawtype.Bullet, radius);
    //else
      //return GraphicsComponent(p_entity, Drawtype.Unknown);
      
    assert(0, "Tried to create graphics component from entity without drawtype value");
  }
  
  
private:
  float m_zoom;
  
  Entity m_centerEntity;
}
