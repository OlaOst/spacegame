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
import std.array;
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

import gl3n.math;
import gl3n.linalg;

import Display;
import Entity;
import EntityLoader;
import SubSystem.Base;
import TextRender;
import Utils;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  string[][string] dummyCache;
  
  Graphics graphics = new Graphics(dummyCache, 256, 128);
    
  GraphicsComponent[] componentsPointedAt = graphics.findComponentsPointedAt(vec2(0.0, 0.0));
  assert(componentsPointedAt.length == 0);

  Entity entity = new Entity(["drawsource":"Triangle","radius":"1.0","keepInCenter":"true"]);
    
  graphics.registerEntity(entity);
  assert(graphics.components.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(0.0, 0.0));
  assert(componentsPointedAt.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(100, 100));
  assert(componentsPointedAt.length == 0);
    
  Entity deleteTest = new Entity(["drawsource":"Triangle","radius":"1.0"]);
  
  graphics.registerEntity(deleteTest);
  assert(graphics.components.length == 2, "Expected 2 registered components, instead got " ~ to!string(graphics.components.length));
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(0.0, 0.0));
  assert(componentsPointedAt.length == 2, "Should have 2 components pointed at, instead got " ~ to!string(componentsPointedAt.length));
  
  graphics.update();
  
  {
    graphics.removeEntity(deleteTest);
  
    graphics.update();
  }  
  
  Entity another = new Entity(["drawsource":"Triangle","radius":"2.0","position":"1.0 0.0"]);
  
  graphics.registerEntity(another);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(0.5, 0.0));
  assert(componentsPointedAt.length == 2, to!string(componentsPointedAt.length));
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(1.5, 0.0));
  assert(componentsPointedAt.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(3.5, 0.0));
  assert(componentsPointedAt.length == 0, to!string(componentsPointedAt.length));
  
  Entity text = new Entity(["drawsource":"Text","radius":"3.0","text":"hello spacegame"]);
  
  graphics.registerEntity(text);
    
  graphics.update();
}


enum DrawSource
{
  Unknown,
  Invisible,
  Triangle,
  Quad,
  Star,
  Bullet,
  Vertices,
  Text,
  Texture,
  RadarDisplay
}


struct Vertex
{
  //float x = 0.0, y = 0.0;
  //float r = 1.0, g = 1.0, b = 1.0, a = 1.0;
  vec2 position = vec2(0.0, 0.0);
  vec4 color = vec4(1.0, 1.0, 1.0, 1.0);
  
  static Vertex fromString(string p_data)
  {
    auto comps = std.string.split(p_data, " ");
    
    assert(comps.length == 6, "should have 6 values in vertex data, got " ~ p_data ~ " instead");
    
    return Vertex(vec2(to!float(comps[0]), to!float(comps[1])), vec4(to!float(comps[2]), to!float(comps[3]), to!float(comps[4]), to!float(comps[5])));
  }
}

struct GraphicsComponent 
{
invariant()
{
  assert(position.ok);
  assert(velocity.ok);
  
  assert(isFinite(angle));
  assert(isFinite(rotation));
  
  assert(color.ok);
  
  assert(isFinite(drawSource));
  assert(radius >= 0.0);
}

public:
  this(float p_radius)
  {
    position = velocity = vec2(0.0, 0.0);
    angle = rotation = 0.0;
    
    drawSource = DrawSource.Unknown;
    radius = p_radius;
    
    color = vec4(1, 1, 1, 1);
  }
  
  bool isPointedAt(vec2 p_pos)
  {
    return ((position - p_pos).length < radius);
  }
  
  bool isOverlapping(GraphicsComponent p_other)
  {
    return ((position - p_other.position).length < (radius + p_other.radius));
  }
  
  DrawSource drawSource;
  float radius;
  AABB aabb;
  
  Vertex[] vertices;
  vec2[] connectPoints;
  vec4 color;
  
  int displayListId = -1;
  uint textureId = -1;
  
  vec2 position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  
  float angle = 0.0;
  float rotation = 0.0;
  
  float depth = 0.0;
  
  bool screenAbsolutePosition = false;
  bool hideFromRadar = false;
  
  string text;
}


class Graphics : Base!(GraphicsComponent)
{
invariant()
{
  assert(m_textRender !is null);
  assert(m_zoom > 0.0);
  assert(m_mouseWorldPos.ok);
}


public:
  this(ref string[][string] cache, int p_screenWidth, int p_screenHeight)
  {
    this.cache = cache;
    
    m_textRender = new TextRender();
    
    m_zoom = 0.1;
    
    m_mouseWorldPos = vec2(0.0, 0.0);
    
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
    
    glDisable(GL_TEXTURE_2D);
    
    glTranslatef(0.0, 0.0, -32768.0);
    
    int drawnComponents = 0;
    
    // stable sort sometimes randomly crashes, phobos bug or float fuckery with lots of similar floats?
    // haven't seen any crashes so far with dmd 2.058
    foreach (component; sort!((left, right) => left.depth < right.depth, SwapStrategy.stable)(components))
    //foreach (component; components)
    {
      glPushMatrix();
      
      assert(component.position.ok);
      
      if (component.screenAbsolutePosition == false)
      {
        glScalef(m_zoom, m_zoom, 1.0);
      
        auto centerComponent = GraphicsComponent();
        assert(centerComponent.position.ok);
        if (hasComponent(m_centerEntity))
        {
          centerComponent = getComponent(m_centerEntity);
          assert(centerComponent.position.ok);
          
          // cull stuff that won't be shown on screen
          if ((component.position - centerComponent.position).magnitude > (1.0 / m_zoom * 2.0))
          {
            glPopMatrix();
            continue;
          }
          else
          {
            drawnComponents++;
          }
        
          glTranslatef(-centerComponent.position.x, -centerComponent.position.y, 0.0);
        }
      }
      
      glTranslatef(component.position.x, component.position.y, component.depth * 0.001);
      
      if (component.drawSource == DrawSource.Text && component.text.length > 0 && component.screenAbsolutePosition == false)
      {
        glPushMatrix();
          glTranslatef(0.0, component.radius*2, 0.0);
          glColor4f(component.color.r, component.color.g, component.color.b, component.color.a);
          m_textRender.renderString(component.text);
        glPopMatrix();
      }
      glDisable(GL_TEXTURE_2D);
      
      glRotatef(component.angle * _180_PI, 0.0, 0.0, -1.0);
      
      // draw connectpoints
      foreach (connectPoint; component.connectPoints)
      {
        glPointSize(4.0);
        glColor3f(1.0, 1.0, 1.0);
        glBegin(GL_POINTS);
          glVertex3f(connectPoint.x, connectPoint.y, component.depth + 1);
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
      
        if (component.screenAbsolutePosition == false && component.drawSource != DrawSource.Text)
        {
          if (component.isPointedAt(m_mouseWorldPos))
            glColor3f(1.0, 0.0, 0.0);
          else
            glColor3f(1.0, 1.0, 1.0);
          
          glBegin(GL_LINE_LOOP);
          for (float angle = 0.0; angle < (PI*2); angle += (PI*2) / 16)
          {
            glVertex3f(cos(angle) * component.radius, sin(angle) * component.radius, 100.0);
          }
          glEnd();
        }
      }

      glPopMatrix();
    }
    
    glPopMatrix();
  }
  
  GraphicsComponent[] findComponentsPointedAt(vec2 p_pos)
  {
    GraphicsComponent[] foundComponents;
    foreach (component; components)
    {
      if ((component.position - p_pos).length < component.radius)
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
  void calculateMouseWorldPos(vec2 p_mouseScreenPos)
  {
    assert(p_mouseScreenPos.ok);
    
    auto centerComponent = GraphicsComponent();
    if (hasComponent(m_centerEntity))
      centerComponent = getComponent(m_centerEntity);
      
    assert(centerComponent.position.ok, "Invalid center component position: " ~ centerComponent.position.toString());
    m_mouseWorldPos = p_mouseScreenPos * (1.0 / m_zoom) + centerComponent.position;
  }
  
  vec2 mouseWorldPos()
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
  
  vec2 getCenterEntityPosition()
  {
    if (hasComponent(m_centerEntity))
      return getComponent(m_centerEntity).position;
    else
      return vec2(0,0);
  }
  
  void renderString(string text)
  {
    m_textRender.renderString(text);
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
    //writeln("graphics creating component from values " ~ to!string(p_entity.values));
    
    //enforce(p_entity.getValue("radius").length > 0, "Couldn't find radius for graphics component");
    float radius = 1.0;
    if ("radius" in p_entity.values)
      radius = to!float(p_entity.getValue("radius"));
    
    GraphicsComponent component = GraphicsComponent(radius);
    
    if (p_entity.getValue("keepInCenter") == "true")
    {
      m_centerEntity = p_entity;
    }
    
    if (p_entity.getValue("hideFromRadar") == "true")
    {
      component.hideFromRadar = true;
    }
    
    if (looksLikeATextFile(p_entity.getValue("drawsource")))
    {
      component.drawSource = DrawSource.Vertices;
      
      // (ab)use entity to just get out data here, since it has loading and caching capabilities
      Entity drawfile = new Entity(loadValues(cache, "data/" ~ p_entity.getValue("drawsource")));
      
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
        auto rect = SDL_Rect(to!short((textureWidth-imageSurface.w)/2), to!short((textureHeight-imageSurface.h)/2), 0, 0);
        SDL_BlitSurface(imageSurface, null, textureSurface, &rect);
        
        enforce(textureSurface !is null, "Error creating texture surface: " ~ to!string(IMG_GetError()));
        enforce(textureSurface.pixels !is null, "Texture surface pixels are NULL!");
        
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
        enforce(error == GL_NO_ERROR, "Error texturizing image " ~ imageFile ~ ": " ~ to!string(gluErrorString(error)) ~ " (errorcode " ~ to!string(error) ~ ")");
      }
      component.textureId = m_imageToTextureId[imageFile];
    }
    else
    {
      if ("drawsource" in p_entity.values)
      {
        component.drawSource = to!DrawSource(p_entity.getValue("drawsource"));
      }
      else if ("text" in p_entity.values)
      {
        component.drawSource = DrawSource.Text;
      }
      else
      {
        // we might have a keepInCenter entity that's not supposed to be drawn (for example the owner entity for the player ship)
        assert(m_centerEntity == p_entity, "Tried to register graphics component without drawsource and also not with keepInCenter attribute");
        
        component.drawSource = DrawSource.Invisible;
      }
      
      if (component.drawSource == DrawSource.Vertices && "vertices" in p_entity.values)
      {
        string[] verticesData = to!(string[])(p_entity.getValue("vertices"));
        
        foreach (vertexData; verticesData)
          component.vertices ~= Vertex.fromString(vertexData);
          
        //writeln("comp vertices is " ~ to!string(component.vertices));
      }
    }
    
    foreach (value; p_entity.values.keys)
    {
      if (std.algorithm.startsWith(value, "connectpoint") > 0)
      {
        component.connectPoints ~= vec2.fromString(p_entity.getValue(value)) * radius;
      }
    }
    
    if ("position" in p_entity.values)
    {
      assert(p_entity.getValue("position").length > 0);
      component.position = vec2.fromString(p_entity.getValue("position"));
    }
    
    component.depth = to!float(p_entity.id);
    if ("depth" in p_entity.values)
    {
      if (p_entity.getValue("depth") == "bottom")
        component.depth -= 100;
      else if (p_entity.getValue("depth") == "top")
        component.depth += 200;
      else
        component.depth = to!float(p_entity.getValue("depth"));
    }
    
    if ("angle" in p_entity.values)
      component.angle = to!float(p_entity.getValue("angle")) * PI_180;
    
    if ("screenAbsolutePosition" in p_entity.values)
    {
      component.screenAbsolutePosition = true;
    }
    
    if ("text" in p_entity.values)
    {
      component.text = p_entity.getValue("text");
    }
    
    if ("color" in p_entity.values)
    {
      string colorString = p_entity.getValue("color");
      
      assert(colorString.split(" ").length >= 3);
      
      auto colorComponents = colorString.split(" ");
      
      if (colorComponents.length == 3)
        colorComponents ~= "1"; // default alpha is 1
        
      component.color = vec4(map!(to!float)(colorComponents).array);
    }
    
    if (component.drawSource != DrawSource.Text && component.drawSource != DrawSource.RadarDisplay)
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
    else if (p_component.drawSource == DrawSource.Quad)
    {
      glColor4f(p_component.color.r, p_component.color.g, p_component.color.b, p_component.color.a);
      
      float halfLength = p_component.radius * 0.5;
      
      glBegin(GL_QUADS);
        glVertex3f(-halfLength, -halfLength, p_component.depth);
        glVertex3f(-halfLength,  halfLength, p_component.depth);
        glVertex3f( halfLength,  halfLength, p_component.depth);
        glVertex3f( halfLength, -halfLength, p_component.depth);
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
        glColor3f(vertex.color.r, vertex.color.g, vertex.color.b);
        glVertex3f(vertex.position.x, vertex.position.y, 0.0);
      }
      glEnd();
    }
    else if (p_component.drawSource == DrawSource.Text && p_component.screenAbsolutePosition == true)
    {
      glScalef(0.05, 0.05, 1.0);
      
      //writeln("rendering text: " ~ p_component.text);
      
      glColor4f(p_component.color.r, p_component.color.g, p_component.color.b, p_component.color.a);
      m_textRender.renderString(p_component.text);
    }
    else if (p_component.drawSource == DrawSource.Texture)
    {
      // make the texture point in the right way and not mirrored
      // (doing this in the texture matrixmode in display.d will mysteriously fuck up font textures)
      glPushMatrix();
      glRotatef(90.0, 0.0, 0.0, 1.0);
      glScalef(-1.0, 1.0, 1.0);
  
      assert(p_component.textureId > 0);
      
      glEnable(GL_TEXTURE_2D);
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      
      auto size = 1.0 * p_component.radius;
      
      glColor4f(1.0, 1.0, 1.0, 1.0);
      
      glBindTexture(GL_TEXTURE_2D, p_component.textureId);
      glBegin(GL_QUADS);
        glNormal3f(0.0, 0.0, 1.0);
        glTexCoord2f(0.0, 0.0); glVertex3f(-size, -size, 0.0);
        glTexCoord2f(0.0, 1.0); glVertex3f(size, -size, 0.0);
        glTexCoord2f(1.0, 1.0); glVertex3f(size, size, 0.0);
        glTexCoord2f(1.0, 0.0); glVertex3f(-size, size, 0.0);
      glEnd();
      
      glPopMatrix();
    }
    else if (p_component.drawSource == DrawSource.RadarDisplay)
    {
      drawRadar(p_component);
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
  
  void drawRadar(GraphicsComponent radarComponent)
  {
    // draw radar circle
    glPushMatrix();
    
    glScalef(radarComponent.radius, radarComponent.radius, 1.0);
    
    auto centerComponent = GraphicsComponent();
    if (hasComponent(m_centerEntity))
      centerComponent = getComponent(m_centerEntity);
    
    // the radar circle is slightly transparent
    glColor4f(0.0, 0.0, 0.0, 0.9);
    glBegin(GL_TRIANGLE_FAN);
    glVertex2f(0.0, 0.0);
    for (float angle = 0.0; angle < PI*2.0; angle += (PI*2.0) / 32.0)
      glVertex2f(sin(angle) * 1.25, cos(angle) * 1.25);
    glVertex2f(sin(0.0) * 1.25, cos(0.0) * 1.25);
    glEnd();
    
    // draw white radar circle
    glColor3f(1.0, 1.0, 1.0);
    glBegin(GL_LINE_LOOP);
    for (float angle = 0.0; angle < PI*2.0; angle += (PI*2.0) / 32.0)
      glVertex2f(sin(angle) * 1.25, cos(angle) * 1.25);
    glEnd();
    
    // draw radar blips - with logarithmic distance and redshifted
    
    // when the foreach with the length check is compiled, we get a Assertion failure: '!vthis->csym' on line 681 in file 'glue.c' when using dmd 2.058
    //foreach (component; filter!(component => component.hideFromRadar == false && (centerComponent.position - component.position).length < 3500.0)(components))
    
    //writeln("radar drawing " ~ to!string(filter!(component => component.hideFromRadar == false)(components).array.length) ~ " entities");
    
    foreach (component; filter!(component => component.hideFromRadar == false)(components))
    {
      glPointSize(max((1+component.radius)*2-1, 1.0));
      
      vec2 relativePos = component.position - centerComponent.position;
      vec2 relativeVel = component.velocity - centerComponent.velocity;
      
      vec2 pos = relativePos.normalized * log(relativePos.length + 1) * 0.15;
      vec2 vel = relativeVel.normalized * log(relativeVel.length + 1) * 0.25;
      
      // figure out if the component is moving towards or away from the centercomponent, so we can redshift-colorize
      if ((relativePos + relativeVel).length > relativePos.length)
        glColor3f(vel.length, 1.0 - vel.length, 1.0 - vel.length);
      else
        glColor3f(1.0 - vel.length, 1.0 - vel.length, vel.length);
        
      glBegin(GL_POINTS);
        glVertex2f(pos.x, pos.y);
      glEnd();
    }
    glPopMatrix();
  }
  
private:
  TextRender m_textRender;
  
  uint[string] m_imageToTextureId;
  
  float m_zoom;
  
  vec2 m_mouseWorldPos;
  
  Entity m_centerEntity;
  
  string[][string] cache;
}
