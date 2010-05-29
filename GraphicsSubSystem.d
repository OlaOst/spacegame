module GraphicsSubSystem;

import derelict.opengl.gl;

import Entity;


unittest
{
  GraphicsSubSystem graphics = new GraphicsSubSystem();
  
  assert(graphics.entities.length == 0);
  {
    graphics.registerEntity(new Entity());
  }
  assert(graphics.entities.length == 1);
}


class GraphicsSubSystem
{
public:

  void draw()
  {
    foreach (entity; m_entities)
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
    }
  }
  
  void registerEntity(Entity p_entity)
  {
    m_entities ~= p_entity;
  }

private:
  Entity[] entities()
  {
    return m_entities;
  }
  
  
private:
  Entity[] m_entities;
}
