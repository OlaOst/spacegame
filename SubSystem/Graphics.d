/*
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

module SubSystem.Graphics;

import std.algorithm;
import std.conv;
import std.exception;
import std.format;
import std.math;
import std.stdio;
import std.string;

import derelict.freetype.ft;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.sdl.image;
import derelict.sdl.sdl;

import Display;
import Entity;
import SubSystem.Base;
import TextRender;
import common.Vector;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  Graphics graphics = new Graphics(256, 128);
    
  GraphicsComponent[] componentsPointedAt = graphics.findComponentsPointedAt(Vector.origo);
  assert(componentsPointedAt.length == 0);

  Entity entity = new Entity();
  
  entity.setValue("drawsource", "Triangle");
  entity.setValue("radius", "1.0");
  entity.setValue("keepInCenter", "true");
    
  graphics.registerEntity(entity);
  assert(graphics.components.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector.origo);
  assert(componentsPointedAt.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector(100, 100));
  assert(componentsPointedAt.length == 0);
    
  Entity deleteTest = new Entity();
  
  deleteTest.setValue("drawsource", "Triangle");
  deleteTest.setValue("radius", "1.0");
  
  graphics.registerEntity(deleteTest);
  assert(graphics.components.length == 2, "Expected 2 registered components, instead got " ~ to!string(graphics.components.length));
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector.origo);
  assert(componentsPointedAt.length == 2, "Should have 2 components pointed at, instead got " ~ to!string(componentsPointedAt.length));
  
  graphics.update();
  
  {
    graphics.removeEntity(deleteTest);
  
    graphics.update();
  }  
  
  Entity another = new Entity();
  
  another.setValue("drawsource", "Triangle");
  another.setValue("radius", "2.0");
  another.setValue("position", "1.0 0.0");
  
  graphics.registerEntity(another);
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector(0.5, 0.0));
  assert(componentsPointedAt.length == 2, to!string(componentsPointedAt.length));
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector(1.5, 0.0));
  assert(componentsPointedAt.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(Vector(3.5, 0.0));
  assert(componentsPointedAt.length == 0, to!string(componentsPointedAt.length));
  
  Entity text = new Entity();
  text.setValue("drawsource", "Text");
  text.setValue("radius", "3.0");
  text.setValue("text", "hello spacegame");
  
  graphics.registerEntity(text);
    
  graphics.update();
}


enum DrawSource
{
  Unknown,
  Invisible,
  Triangle,
  Star,
  Bullet,
  Vertices,
  Text,
  Texture
}


struct Vertex
{
  float x,y;
  float r,g,b;
  
  static Vertex fromString(string p_data)
  {
    auto comps = std.string.split(p_data, " ");
    
    assert(comps.length == 5, "should have 5 values in vertex data, got " ~ p_data ~ " instead");
    
    return Vertex(to!float(comps[0]), to!float(comps[1]), to!float(comps[2]), to!float(comps[3]), to!float(comps[4]));
  }
}

struct GraphicsComponent 
{
public:
  this(float p_radius)
  {
    position = velocity = Vector.origo;
    angle = rotation = 0.0;
    
    drawSource = DrawSource.Unknown;
    radius = p_radius;
  }
  
  bool isPointedAt(Vector p_pos)
  {
    return ((position - p_pos).length2d < radius);
  }
  
  bool isOverlapping(GraphicsComponent p_other)
  {
    return ((position - p_other.position).length2d < (radius + p_other.radius));
  }
  
  DrawSource drawSource;
  float radius;
  
  Vertex[] vertices;
  Vector[] connectPoints;
  Vertex color;
  
  @property Vector position() { return m_position; }
  @property Vector position(Vector p_position) in { assert(p_position.isValid()); } body { return m_position = p_position; }
  
  @property Vector velocity() { return m_velocity; }
  @property Vector velocity(Vector p_velocity) in { assert(p_velocity.isValid()); } body { return m_velocity = p_velocity; }
  
  @property float angle() { return m_angle; }
  @property float angle(float p_angle) in { assert(p_angle == p_angle); } body { return m_angle = p_angle; }
  
  @property float rotation() { return m_rotation; }
  @property float rotation(float p_rotation) in { assert(p_rotation == p_rotation); } body { return m_rotation = p_rotation; }
  
  @property bool screenAbsolutePosition() { return m_screenAbsolutePosition; }
  @property bool screenAbsolutePosition(bool p_screenAbsolutePosition) { return m_screenAbsolutePosition = p_screenAbsolutePosition; }
  
  @property string text() { return m_text; }
  @property string text(string p_text) { return m_text = p_text; }
  
  int displayListId = -1;
  uint textureId = -1;
  
private:
  Vector m_position = Vector.origo;
  Vector m_velocity = Vector.origo;
  
  float m_angle = 0.0;
  float m_rotation = 0.0;
  
  bool m_screenAbsolutePosition = false;
  
  string m_text;
}


class Graphics : public Base!(GraphicsComponent)
{
invariant()
{
  assert(m_textRender !is null);
  assert(m_zoom > 0.0);
  assert(m_mouseWorldPos.isValid());
}


public:
  this(int p_screenWidth, int p_screenHeight)
  {
    m_textRender = new TextRender();
    
    m_zoom = 0.1;
    
    m_mouseWorldPos = Vector.origo;
    
    initDisplay(p_screenWidth, p_screenHeight);
  }
  
  ~this()
  {
    teardownDisplay();
  }

  void update() 
  {
    swapBuffers();
  
    glPushMatrix();
    
    glScalef(m_zoom, m_zoom, 1.0);

    glTranslatef(0.0, 0.0, -512.0);
    
    auto centerComponent = GraphicsComponent();
    assert(centerComponent.position.isValid());
    if (hasComponent(m_centerEntity))
    {
      centerComponent = getComponent(m_centerEntity);
      assert(centerComponent.position.isValid());
    
      glTranslatef(-centerComponent.position.x, -centerComponent.position.y, 0.0);
    }
    
    glDisable(GL_TEXTURE_2D);

    //foreach (component; sort!((left, right) { return left.position.z < right.position.z; })(components))
    foreach (component; components)
    {
      glPushMatrix();
      
      if (component.screenAbsolutePosition)
      {
        glTranslatef(centerComponent.position.x, centerComponent.position.y, 0.0);
          
        glScalef(1.0/m_zoom, 1.0/m_zoom, 1.0);
      }
      
      assert(component.position.isValid());
      
      glTranslatef(component.position.x, component.position.y, component.position.z);
      
      // show some data for entities, unrotated
      if (component.text.length > 0)
      {
        glPushMatrix();
          glTranslatef(0.0, component.radius*2, 0.0);
          //m_textRender.renderString(to!string(component.velocity.length2d()));
          m_textRender.renderString(to!string(component.text));
        glPopMatrix();
      }
      glDisable(GL_TEXTURE_2D);
      
      glRotatef(component.angle * (180.0 / PI), 0.0, 0.0, 1.0);
      
      // draw connectpoints
      foreach (connectPoint; component.connectPoints)
      {
        glPointSize(4.0);
        glColor3f(1.0, 1.0, 1.0);
        glBegin(GL_POINTS);
          glVertex3f(connectPoint.x, connectPoint.y, 1.0);
        glEnd();
      }
      
      if (component.displayListId > 0)
        glCallList(component.displayListId);
      else
        drawComponent(component);
      

      // draw circle indicating radius in debug mode
      debug
      {
        glDisable(GL_TEXTURE_2D);
      
        if (component.m_screenAbsolutePosition == false)
        {
          if (component.isPointedAt(m_mouseWorldPos))
            glColor3f(1.0, 0.0, 0.0);
          else
            glColor3f(1.0, 1.0, 1.0);
          
          glBegin(GL_LINE_LOOP);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 16)
          {
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 0.0);
          }
          glEnd();
        }
      }
      
      
      glPopMatrix();
    }
    
    glPopMatrix();
  }
  
  GraphicsComponent[] findComponentsPointedAt(Vector p_pos)
  {
    GraphicsComponent[] foundComponents;
    foreach (component; components)
    {
      if ((component.position - p_pos).length2d < component.radius)
        foundComponents ~= component;
    }
    
    return foundComponents;
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
    assert(p_mouseScreenPos.isValid());
    
    auto centerComponent = GraphicsComponent();
    if (hasComponent(m_centerEntity))
      centerComponent = getComponent(m_centerEntity);
      
    assert(centerComponent.position.isValid(), "Invalid center component position: " ~ centerComponent.position.toString());
    m_mouseWorldPos = p_mouseScreenPos / m_zoom + centerComponent.position;
  }
  
  Vector mouseWorldPos()
  {
    return m_mouseWorldPos;
  }
  
  void setCenterEntity(Entity p_entity)
  {
    m_centerEntity = p_entity;
  }
  
  Entity getCenterEntity()
  {
    return m_centerEntity;
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return (p_entity.getValue("drawsource").length > 0 ||
            p_entity.getValue("keepInCenter").length > 0 ||
            p_entity.getValue("text").length > 0);
  }
  
  GraphicsComponent createComponent(Entity p_entity)
  {
    //enforce(p_entity.getValue("radius").length > 0, "Couldn't find radius for graphics component");
    float radius = 1.0;
    if (p_entity.getValue("radius").length > 0)
      radius = to!float(p_entity.getValue("radius"));
    
    GraphicsComponent component = GraphicsComponent(radius);
    
    if (p_entity.getValue("keepInCenter") == "true")
    {
      m_centerEntity = p_entity;
    }
    
    if (looksLikeATextFile(p_entity.getValue("drawsource")))
    {
      component.drawSource = DrawSource.Vertices;
      
      // (ab)use entity to just get out data here, since it has loading and caching capabilities
      Entity drawfile = new Entity("data/" ~ p_entity.getValue("drawsource"));
      
      foreach (vertexName, vertexData; drawfile.values)
      {
        if (vertexName.startsWith("vertex"))
          component.vertices ~= Vertex.fromString(vertexData);
      }
    }
    else if (p_entity.getValue("drawsource").endsWith(".png") || 
             p_entity.getValue("drawsource").endsWith(".jpg"))
    {
      component.drawSource = DrawSource.Texture;
      
      auto imageFile = "data/" ~ p_entity.getValue("drawsource");
      
      if (imageFile !in m_imageToTextureId)
      {
        SDL_Surface* imageSurface = IMG_Load(imageFile.toStringz);
        
        enforce(imageSurface !is null, "Error loading image " ~ imageFile ~ ": " ~ to!string(IMG_GetError()));
        enforce(imageSurface.pixels !is null);
        
        int textureWidth = to!int(pow(2, ceil(log(imageSurface.w) / log(2)))); // round up to nearest power of 2
        int textureHeight = to!int(pow(2, ceil(log(imageSurface.h) / log(2)))); // round up to nearest power of 2
        
        // we don't support alpha channels yet, ensure the image is 100% opaque
        SDL_SetAlpha(imageSurface, 0, 255);
        
        static if (SDL_BYTEORDER == SDL_BIG_ENDIAN)
          SDL_Surface* textureSurface = SDL_CreateRGBSurface(0, textureWidth, textureHeight, 32, 0xff000000, 0x00ff0000, 0x0000ff00, 0x000000ff);
        else
          SDL_Surface* textureSurface = SDL_CreateRGBSurface(0, textureWidth, textureHeight, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
        
        // copy the image surface into the middle of the texture surface
        SDL_BlitSurface(imageSurface, null, textureSurface, &SDL_Rect(to!short((textureWidth-imageSurface.w)/2), to!short((textureHeight-imageSurface.h)/2), 0, 0));
        
        enforce(textureSurface !is null, "Error creating texture surface: " ~ to!string(IMG_GetError()));
        enforce(textureSurface.pixels !is null);
        
        auto format = (textureSurface.format.BytesPerPixel == 4 ? GL_RGBA : GL_RGB);
        
        uint textureId;
        
        glGenTextures(1, &textureId);
        enforce(textureId > 0, "Failed to generate texture id: " ~ to!string(glGetError()));
        
        m_imageToTextureId[imageFile] = textureId;
        
        glBindTexture(GL_TEXTURE_2D, textureId);
        //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, textureSurface.format.BytesPerPixel, textureSurface.w, textureSurface.h, 0, format, GL_UNSIGNED_BYTE, textureSurface.pixels);
        
        auto error = glGetError();
        enforce(error == GL_NO_ERROR, "Error texturizing image " ~ imageFile ~ ": " ~ to!string(gluErrorString(error)));
      }
      component.textureId = m_imageToTextureId[imageFile];
    }
    else
    {
      if (p_entity.getValue("drawsource").length > 0)
      {
        component.drawSource = to!DrawSource(p_entity.getValue("drawsource"));
      }
      else if (p_entity.getValue("text").length > 0)
      {
        component.drawSource = DrawSource.Text;
      }
      else
      {
        // we might have a keepInCenter entity that's not supposed to be drawn (for example the owner entity for the player ship)
        assert(m_centerEntity == p_entity, "Tried to register graphics component without drawsource and also not with keepInCenter attribute");
        
        component.drawSource = DrawSource.Invisible;
      }
    }
    
    foreach (value; p_entity.values.keys)
    {
      if (std.algorithm.startsWith(value, "connectpoint") > 0)
      {
        component.connectPoints ~= Vector.fromString(p_entity.getValue(value));
      }
    }
    
    if (p_entity.getValue("position").length > 0)
    {
      component.position = Vector.fromString(p_entity.getValue("position"));
    }
    
    if (p_entity.getValue("screenAbsolutePosition").length > 0)
    {
      component.screenAbsolutePosition = true;
    }
    
    if (p_entity.getValue("text").length > 0)
    {
      component.text = p_entity.getValue("text");
    }
    
    if (p_entity.getValue("color").length > 0)
    {
      component.color = Vertex.fromString("0 0 " ~ p_entity.getValue("color"));
    }
    
    if (component.drawSource != DrawSource.Text)
      createDisplayList(component);
    
    return component;
  }

private:
  bool looksLikeATextFile(string p_txt)
  {
    return endsWith(p_txt, ".txt") > 0;
  }
  
  
  void createDisplayList(ref GraphicsComponent p_component)
  {
    // TODO: make sure we don't create completely similar display lists
    
    p_component.displayListId = glGenLists(1);
    
    enforce(p_component.displayListId > 0, "Could not create display list id");
    
    glNewList(p_component.displayListId, GL_COMPILE);
      drawComponent(p_component);
    glEndList();
  }


  void drawComponent(GraphicsComponent p_component)
  {
    if (p_component.drawSource == DrawSource.Invisible)
    {
    }
    if (p_component.drawSource == DrawSource.Triangle)
    {
      glBegin(GL_TRIANGLES);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 3)
        {
          glColor3f(cos(angle*2), sin(angle/2), 0.0);
          glVertex3f(cos(angle) * p_component.radius, sin(angle) * p_component.radius, 0.0);
        }
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Star)
    {
      glBegin(GL_TRIANGLE_FAN);
        glColor3f(1.0, 1.0, 1.0);
        glVertex3f(0.0, 0.0, 0.0);
        glColor3f(0.0, 0.5, 1.0);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 5)
        {
          glVertex3f(cos(angle) * p_component.radius, sin(angle) * p_component.radius, 0.0);
        }
        glVertex3f(cos(0.0) * p_component.radius, sin(0.0) * p_component.radius, 0.0);
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Bullet)
    {
      glBegin(GL_TRIANGLE_FAN);
        glColor3f(1.0, 1.0, 0.0);
        glVertex3f(0.0, 0.0, 0.0);
        glColor3f(1.0, 0.5, 0.0);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 4)
        {
          glVertex3f(cos(angle) * p_component.radius, sin(angle) * p_component.radius, 0.0);
        }
        glVertex3f(cos(0.0) * p_component.radius, sin(0.0) * p_component.radius, 0.0);
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Vertices)
    {
      glBegin(GL_POLYGON);
      foreach (vertex; p_component.vertices)
      {
        glColor3f(vertex.r, vertex.g, vertex.b);
        glVertex3f(vertex.x, vertex.y, 0.0);
      }
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Text)
    {
      glScalef(0.05, 0.05, 1.0);
      
      glColor3f(p_component.color.r, p_component.color.g, p_component.color.b);
      m_textRender.renderString(p_component.text);
    }
    else if (p_component.drawSource == DrawSource.Texture)
    {
      assert(p_component.textureId > 0);
      
      glEnable(GL_TEXTURE_2D);
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      
      auto size = 1.0 * p_component.radius;
      
      glBindTexture(GL_TEXTURE_2D, p_component.textureId);
      glBegin(GL_QUADS);
        glNormal3f(0.0, 0.0, 1.0);
        glTexCoord2f(0.0, 0.0); glVertex3f(-size, -size, 0.0);
        glTexCoord2f(0.0, 1.0); glVertex3f(size, -size, 0.0);
        glTexCoord2f(1.0, 1.0); glVertex3f(size, size, 0.0);
        glTexCoord2f(1.0, 0.0); glVertex3f(-size, size, 0.0);
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Unknown)
    {
      // TODO: should just draw a big fat question mark here
      // or a cow
      
      glBegin(GL_TRIANGLE_FAN);
        glColor3f(0.0, 0.0, 0.0);
        glVertex3f(0.0, 0.0, 0.0);
        glColor3f(1.0, 0.0, 0.0);
        for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 4)
        {
          glVertex3f(cos(angle) * p_component.radius, sin(angle) * p_component.radius, 0.0);
        }
        glVertex3f(cos(0.0) * p_component.radius, sin(0.0) * p_component.radius, 0.0);
      glEnd();
    }
  }
  
private:
  TextRender m_textRender;
  
  uint[string] m_imageToTextureId;
  
  float m_zoom;
  
  Vector m_mouseWorldPos;
  
  Entity m_centerEntity;
}
