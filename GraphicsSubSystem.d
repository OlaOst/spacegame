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
  
private:
  Entity m_entity;
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
      
      glBegin(GL_TRIANGLES);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
        {
          glColor3f(cos(angle*2), sin(angle/2), 0.0);
          glVertex3f(cos(angle), sin(angle), -2.0);
        }
      glEnd();
      
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
    return GraphicsComponent(p_entity);
  }
  
  
private:
  float m_zoom;
}
