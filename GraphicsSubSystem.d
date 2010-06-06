module GraphicsSubSystem;

import std.math;

import derelict.opengl.gl;

import Entity;
import SubSystem;
import Vector : Vector;


unittest
{
  GraphicsSubSystem graphics = new GraphicsSubSystem();
}


enum Drawtype
{
  Triangle,
  Star
}

struct GraphicsComponent 
{
public:
  Vector position()
  {
    return m_entity.position;
  }
  
  float angle()
  {
    return m_entity.angle;
  }
  
  Drawtype drawType()
  {
    return m_drawType;
  }
  
  
private:
  Entity m_entity;
  
  Drawtype m_drawType;
}


class GraphicsSubSystem : public SubSystem.SubSystem!(GraphicsComponent)
{
invariant()
{
  assert(m_zoom > 0.0);
}


public:
  this()
  {
    m_zoom = 1.0;
  }
  
  
  void draw()
  {
    glPushMatrix();
    
    glScalef(m_zoom, m_zoom, 1.0);
    
    foreach (component; components)
    {
      glPushMatrix();      
      
      glTranslatef(component.position.x, component.position.y, 0.0);
      glRotatef(component.angle * (180.0 / PI), 0.0, 0.0, 1.0);
      
      if (component.drawType == Drawtype.Triangle)
      {
        glBegin(GL_TRIANGLES);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
          {
            glColor3f(cos(angle*2), sin(angle/2), 0.0);
            glVertex3f(cos(angle), sin(angle), -2.0);
          }
        glEnd();
      }
      else if (component.drawType == Drawtype.Star)
      {
        glBegin(GL_TRIANGLE_FAN);
          glColor3f(1.0, 1.0, 1.0);
          glVertex3f(0.0, 0.0, -2.0);
          glColor3f(0.0, 0.5, 1.0);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 5)
          {
            glVertex3f(cos(angle)*.05, sin(angle)*.05, -2.0);
          }
          glVertex3f(cos(0.0)*.05, sin(0.0)*.05, -2.0);
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
  
  
protected:
  GraphicsComponent createComponent(Entity p_entity)
  {
    return GraphicsComponent(p_entity, p_entity.isStar ? Drawtype.Star : Drawtype.Triangle);
  }
  
  Drawtype drawtype()
  {
    return m_drawtype;
  }
  
private:
  float m_zoom;
  
  Drawtype m_drawtype;
}
