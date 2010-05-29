module GraphicsSubSystem;

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
  
private:
  Entity m_entity;
}


class GraphicsSubSystem : public SubSystem.SubSystem!(GraphicsComponent)
{
public:

  void draw()
  {
    foreach (component; components)
    {
      glPushMatrix();
      scope(exit) glPopMatrix();
      
      glTranslatef(component.position.x, component.position.y, 0.0);
      //glRotatef(m_delta, 0.0, 0.0, 1.0);
      
      glBegin(GL_TRIANGLES);
        glColor3f(1.0, 0.0, 0.0);
        glVertex3f(0.0, 1.0, -2.0);
        
        glColor3f(0.0, 1.0, 0.0);
        glVertex3f(-0.87, -0.5, -2.0);
        
        glColor3f(0.0, 0.0, 1.0);
        glVertex3f(0.87, -0.5, -2.0);
      glEnd();
    }
  }
  
protected:
  GraphicsComponent createComponent(Entity p_entity)
  {
    return GraphicsComponent(p_entity);
  }
}
