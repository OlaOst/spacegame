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

import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.stdio;

import derelict.opengl.gl;
import derelict.freetype.ft;

import Display;
import Entity;
import EnumGen;
import SubSystem : SubSystem;
import Vector : Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  
  GraphicsSubSystem graphics = new GraphicsSubSystem(256, 128);
  
  Entity[] entitiesPointedAt = graphics.findEntitiesPointedAt(Vector.origo);
  assert(entitiesPointedAt.length == 0);

  Entity entity = new Entity();
  
  entity.setValue("drawsource", "Triangle");
  entity.setValue("radius", "1.0");
  entity.setValue("keepInCenter", "true");
  
  graphics.registerEntity(entity);
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector.origo);
  assert(entitiesPointedAt.length == 1);
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector(100, 100));
  assert(entitiesPointedAt.length == 0);
  
  
  Entity deleteTest = new Entity();
  
  deleteTest.setValue("drawsource", "Triangle");
  deleteTest.setValue("radius", "1.0");
  deleteTest.setValue("keepInCenter", "true");
  
  graphics.registerEntity(deleteTest);
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector.origo);
  assert(entitiesPointedAt.length == 2);
  
  graphics.draw();
  
  {
    graphics.removeEntity(deleteTest);
  
    graphics.draw();
  }
  
  Entity another = new Entity();
  
  another.setValue("drawsource", "Triangle");
  another.setValue("radius", "2.0");
  another.position = Vector(1.0, 0.0);
  
  graphics.registerEntity(another);
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector(0.5, 0.0));
  assert(entitiesPointedAt.length == 2, to!string(entitiesPointedAt.length));
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector(1.5, 0.0));
  assert(entitiesPointedAt.length == 1);
  
  entitiesPointedAt = graphics.findEntitiesPointedAt(Vector(3.5, 0.0));
  assert(entitiesPointedAt.length == 0, to!string(entitiesPointedAt.length));
  
  
  Entity text = new Entity();
  text.setValue("drawsource", "Text");
  text.setValue("radius", "3.0");
  text.setValue("text", "hello spacegame");
  
  graphics.registerEntity(text);
  
  graphics.draw();
}

mixin(genEnum("DrawSource",
[
  "Unknown",
  "Triangle",
  "Star",
  "Bullet",
  "Vertices",
  "Text"
]));

struct Vertex
{
  float x,y;
  float r,g,b;
  
  static Vertex fromString(string p_data)
  {
    auto comps = std.string.split(p_data, " ");
    
    assert(comps.length == 5);
    
    return Vertex(to!float(comps[0]), to!float(comps[1]), to!float(comps[2]), to!float(comps[3]), to!float(comps[4]));
  }
}

struct GraphicsComponent 
{
public:
  this(Entity p_entity, float p_radius)
  {
    entity = p_entity;
    drawSource = DrawSource.Unknown;
    radius = p_radius;
  }
  
  bool isPointedAt(Vector p_pos)
  {
    return ((entity.position - p_pos).length2d < radius);
  }
  
  DrawSource drawSource;
  float radius;
  
  Vertex[] vertices;
  Vector[] connectPoints;
  
private:
  Entity entity;
}


class GraphicsSubSystem : public SubSystem!(GraphicsComponent)
{
invariant()
{
  assert(m_zoom > 0.0);
  assert(m_mouseWorldPos.isValid());
}


public:
  this(int p_screenWidth, int p_screenHeight)
  {
    m_zoom = 0.02;
    
    m_mouseWorldPos = Vector.origo;
    
    initDisplay(p_screenWidth, p_screenHeight);
    
    DerelictFT.load();
    
    FT_Library lib;
    
    enforce(FT_Init_FreeType(&lib) == false, "Error initializing FreeType");
    
    auto fontError = FT_New_Face(lib, "./freesansbold.ttf", 0, &m_face);
    enforce(fontError != FT_Err_Unknown_File_Format, "Error, font format unsupported");
    enforce(fontError == false, "Error loading font file");
    
    FT_Set_Pixel_Sizes(m_face, 16, 16);
    /*
    auto glyphIndex = FT_Get_Char_Index(face, '?');
    FT_Load_Glyph(face, glyphIndex, 0);
    
    FT_Render_Glyph(face.glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL);

    writeln("glyph width: " ~ to!string(face.glyph.bitmap.width) ~ ", height:" ~ to!string(face.glyph.bitmap.rows));
    
    uint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
    glTexImage2D(GL_TEXTURE_2D, 0, 1, 16, 16, 0, GL_RGBA, GL_UNSIGNED_BYTE, face.glyph.bitmap.buffer);
    */
    /*
    bool Engine::ft_render_glyph(char c)
    {
      FT_UInt glyph_index = FT_Get_Char_Index(ft_face, c);	
      FT_UInt error = FT_Load_Glyph(ft_face, glyph_index, FT_LOAD_DEFAULT);	
      if (error)	{		return false;	}	
      error = FT_Render_Glyph(ft_face->glyph, FT_RENDER_MODE_NORMAL);	
      if (error)	{		return false;	}	
      int width  = power2(ft_face->glyph->bitmap.width);	
      int height = power2(ft_face->glyph->bitmap.rows);	
      
      glGenTextures(1, &texture);	
      glBindTexture(GL_TEXTURE_2D, texture);	
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
      glTexImage2D(GL_TEXTURE_2D, 0, 1, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, &ft_face->glyph->bitmap.buffer);	
      
      return true;
    }
    */
  }
  
  void renderChar(FT_Face face, char c)
  {
    glEnable(GL_TEXTURE_2D);
    
    auto glyphIndex = FT_Get_Char_Index(face, c);
    
    FT_Load_Glyph(face, glyphIndex, 0);
    
    FT_Render_Glyph(face.glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL);

    //writeln("glyph width: " ~ to!string(face.glyph.bitmap.width) ~ ", height:" ~ to!string(face.glyph.bitmap.rows));
    
    uint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
    glTexImage2D(GL_TEXTURE_2D, 0, 1, 16, 16, 0, GL_RGBA, GL_UNSIGNED_BYTE, face.glyph.bitmap.buffer);
  }
  
  void draw()
  {
    swapBuffers();
  
    glPushMatrix();
    
    glScalef(m_zoom, m_zoom, 1.0);
    
    // pull back camera a bit so we can see entities with z=0.0
    glTranslatef(0.0, 0.0, -1.0);
    
    renderChar(m_face, '?');
    glBegin(GL_QUADS);
      glNormal3f(0.0, 0.0, 0.5);
      glTexCoord2f(0.0, 0.0); glVertex3f(-1.0, -1.0, 0.0);
      glTexCoord2f(1.0, 0.0); glVertex3f( 1.0, -1.0, 0.0);
      glTexCoord2f(1.0, 1.0); glVertex3f( 1.0,  1.0, 0.0);
      glTexCoord2f(0.0, 1.0); glVertex3f(-1.0,  1.0, 0.0);
    glEnd();
    
    if (m_centerEntity !is null)
      glTranslatef(-m_centerEntity.position.x, -m_centerEntity.position.y, 0.0);
    
    foreach (component; components)
    {
      glPushMatrix();
      
      assert(component.entity.position.isValid());
      
      glTranslatef(component.entity.position.x, component.entity.position.y, component.entity.position.z);
      glRotatef(component.entity.angle * (180.0 / PI), 0.0, 0.0, 1.0);
      
      // draw connectpoinst
      glDisable(GL_DEPTH_TEST);
      foreach (connectPoint; component.connectPoints)
      {
        glPointSize(4.0);
        glColor3f(1.0, 1.0, 1.0);
        glBegin(GL_POINTS);
          glVertex3f(connectPoint.x, connectPoint.y, 0.0);
        glEnd();
      }
      glEnable(GL_DEPTH_TEST);
      
      
      if (component.drawSource == DrawSource.Triangle)
      {
        glBegin(GL_TRIANGLES);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
          {
            glColor3f(cos(angle*2), sin(angle/2), 0.0);
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
        glEnd();
      }
      else if (component.drawSource == DrawSource.Star)
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
      else if (component.drawSource == DrawSource.Bullet)
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
      else if (component.drawSource == DrawSource.Vertices)
      {
        glBegin(GL_POLYGON);
        foreach (vertex; component.vertices)
        {
          glColor3f(vertex.r, vertex.g, vertex.b);
          glVertex3f(vertex.x, vertex.y, 0.0);
        }
        glEnd();
      }
      else if (component.drawSource == DrawSource.Text)
      {
        auto text = component.entity.getValue("text");
        
        
      }
      else if (component.drawSource == DrawSource.Unknown)
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
        if (component.isPointedAt(m_mouseWorldPos))
          glColor3f(1.0, 1.0, 0.0);
        else
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
    
    glColor3f(1.0, 0.0, 0.0);
    glBegin(GL_LINE);
      glVertex2f(0.0, 0.0);
      glVertex2f(m_mouseWorldPos.x, m_mouseWorldPos.y);
    glEnd();
    
    glPopMatrix();
  }
  
  Entity[] findEntitiesPointedAt(Vector p_pos)
  {
    Entity[] foundEntities;
    foreach (component; components)
    {
      if ((component.entity.position - p_pos).length2d < component.radius)
        foundEntities ~= component.entity;
    }
    
    return foundEntities;
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
  
  // figure out world coords of the mouse pointer, from viewport coords
  void calculateMouseWorldPos(Vector p_mouseScreenPos)
  {
    m_mouseWorldPos = p_mouseScreenPos / m_zoom + m_centerEntity.position;
  }
  
  Vector mouseWorldPos()
  {
    return m_mouseWorldPos;
  }
  
protected:
  GraphicsComponent createComponent(Entity p_entity)
  {
    if (p_entity.getValue("keepInCenter") == "true")
    {
      m_centerEntity = p_entity;
    }
    
    //enforce(p_entity.getValue("radius").length > 0, "Couldn't find radius for graphics component");
    float radius = 1.0;
    if (p_entity.getValue("radius").length > 0)
      radius = to!float(p_entity.getValue("radius"));
    
    GraphicsComponent component = GraphicsComponent(p_entity, radius);
    
    if (looksLikeAFile(p_entity.getValue("drawsource")))
    {
      component.drawSource = DrawSource.Vertices;
      
      // (ab)use entity to just get out data here, since it has loading and caching capabilities
      Entity drawfile = new Entity("data/" ~ p_entity.getValue("drawsource"));
      
      foreach (vertexData; drawfile.values)
      {
        component.vertices ~= Vertex.fromString(vertexData);
      }
    }
    else
    {
      component.drawSource = DrawSourceFromString(p_entity.getValue("drawsource"));
    }
    
    foreach (value; p_entity.values.keys)
    {
      if (std.algorithm.startsWith(value, "connectpoint") > 0)
      {
        component.connectPoints ~= Vector.fromString(p_entity.getValue(value));
      }
    }
    
    return component;
  }

private:
  bool looksLikeAFile(string p_txt)
  {
    return endsWith(p_txt, ".txt") > 0;
  }
  
private:
  float m_zoom;
  
  Vector m_mouseWorldPos;
  
  Entity m_centerEntity;
  
  FT_Face m_face;
}
