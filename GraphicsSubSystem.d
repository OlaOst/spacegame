module GraphicsSubSystem;

import std.math;

import derelict.opengl.gl;

import Entity;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  GraphicsSubSystem graphics = new GraphicsSubSystem();
  
  Entity deleteTest = new Entity();
  
  deleteTest.setValue("drawtype", "triangle");
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
  this(Entity p_entity, Drawtype p_drawType)
  {
    entity = p_entity;
    drawType = p_drawType;
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
      
      assert(component.position.x == component.position.x);
      assert(component.position.y == component.position.y);
      assert(component.position.z == component.position.z);
      
      glTranslatef(component.position.x, component.position.y, component.position.z);
      glRotatef(component.angle * (180.0 / PI), 0.0, 0.0, 1.0);
      
      if (component.drawType == Drawtype.Triangle)
      {
        glBegin(GL_TRIANGLES);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
          {
            glColor3f(cos(angle*2), sin(angle/2), 0.0);
            glVertex3f(cos(angle), sin(angle), 0.0);
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
            glVertex3f(cos(angle)*.05, sin(angle)*.05, 0.0);
          }
          glVertex3f(cos(0.0)*.05, sin(0.0)*.05, 0.0);
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
            glVertex3f(cos(angle)*.05, sin(angle)*.05, 0.0);
          }
          glVertex3f(cos(0.0)*.05, sin(0.0)*.05, 0.0);
        glEnd();
      }
      else if (component.drawType == Drawtype.Unknown)
      {
        // TODO: should just draw a big fat question mark here
        
        glBegin(GL_TRIANGLE_FAN);
          glColor3f(0.0, 0.0, 0.0);
          glVertex3f(0.0, 0.0, 0.0);
          glColor3f(1.0, 0.0, 0.0);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 4)
          {
            glVertex3f(cos(angle)*.05, sin(angle)*.05, 0.0);
          }
          glVertex3f(cos(0.0)*.05, sin(0.0)*.05, 0.0);
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
    
    if (p_entity.getValue("drawtype") == "star")
      return GraphicsComponent(p_entity, Drawtype.Star);
    else if (p_entity.getValue("drawtype") == "triangle")
      return GraphicsComponent(p_entity, Drawtype.Triangle);
    else if (p_entity.getValue("drawtype") == "bullet")
      return GraphicsComponent(p_entity, Drawtype.Bullet);
    //else
      //return GraphicsComponent(p_entity, Drawtype.Unknown);
      
    assert(0, "Tried to create graphics component from entity without drawtype value");
  }
  
  
private:
  float m_zoom;
  
  Entity m_centerEntity;
}
