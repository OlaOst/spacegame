module GraphicsSubSystem;

import derelict.opengl.gl;

import Entity;
import SubSystem;


unittest
{
  GraphicsSubSystem graphics = new GraphicsSubSystem();
}


struct GraphicsComponent {}


class GraphicsSubSystem : public SubSystem.SubSystem!(GraphicsComponent)
{
public:

  void draw()
  {
    /*foreach (entity; m_entities)
    {
      glPushMatrix();
      scope(exit) glPopMatrix();
      
      glTranslatef(entity.position.x, entity.position.y, 0.0);
      //glRotatef(m_delta, 0.0, 0.0, 1.0);
      
      glBegin(GL_TRIANGLES);
        glColor3f(1.0, 0.0, 0.0);
        glVertex3f(0.0, 1.0, -2.0);
        
        glColor3f(0.0, 1.0, 0.0);
        glVertex3f(-0.87, -0.5, -2.0);
        
        glColor3f(0.0, 0.0, 1.0);
        glVertex3f(0.87, -0.5, -2.0);
      glEnd();
    }*/
  }
  
protected:
  GraphicsComponent createComponent(Entity p_entity)
  {
    return GraphicsComponent();
  }
}
