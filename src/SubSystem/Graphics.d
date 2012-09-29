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
import std.file;
import std.format;
import std.math;
import std.stdio;
import std.string;

import derelict.freetype.ft;
import derelict.opengl3.gl3;
import derelict.opengl3.glx;
import derelict.sdl2.image;
import derelict.sdl2.sdl;

import gl3n.math;
import gl3n.linalg;

import glamour.shader;
import glamour.texture;
import glamour.vbo;

import Entity;
import EntityLoader;
import sprite;
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
  
  Entity another = new Entity(["drawsource":"Triangle", "radius":"2.0", "position":"[1.0, 0.0]"]);
  
  graphics.registerEntity(another);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(0.5, 0.0));
  assert(componentsPointedAt.length == 2, to!string(componentsPointedAt.length));
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(1.5, 0.0));
  assert(componentsPointedAt.length == 1);
  
  componentsPointedAt = graphics.findComponentsPointedAt(vec2(3.5, 0.0));
  assert(componentsPointedAt.length == 0, to!string(componentsPointedAt.length));
  
  Entity text = new Entity(["drawsource":"Text", "radius":"3.0", "text":"hello spacegame"]);
  
  graphics.registerEntity(text);

  graphics.update();
}


enum DrawSource
{
  Unknown,
  Invisible,
  Triangle,
  Quad,
  Rectangle,
  Star,
  Bullet,
  Vertices,
  Text,
  Texture,
  RadarDisplay,
  TargetDisplay
}


struct GraphicsComponent 
{
invariant()
{
  assert(sprite.position.ok);
  assert(velocity.ok);
  
  assert(isFinite(sprite.angle));
  assert(isFinite(sprite.scale));
  assert(isFinite(rotation));
  
  assert(color.ok, color.to!string);
  
  assert(isFinite(drawSource));
  //assert(radius >= 0.0);
}

public:
  bool isPointedAt(vec2 p_pos)
  {
    return (position - p_pos).length < radius;
  }
  
  bool isOverlapping(GraphicsComponent p_other)
  {
    return ((position - p_other.position).length < (radius + p_other.radius));
  }
  
  DrawSource drawSource = DrawSource.Unknown;
  AABB!vec2 aabb;
  
  vec2[] connectPoints;
  vec4 color = vec4(1, 1, 1, 1);
  
  int displayListId = -1;
  Texture2D texture;
  string textureName;
  
  Sprite sprite;
  
  int frames;
  int currentFrame;
  float lifeTime = float.infinity;
  float timeLived = 0.0;
  
  @property vec2 position() { return vec2(sprite.position.xy); }
  @property void position(vec2 pos) { sprite.position.x = pos.x; sprite.position.y = pos.y; }
  
  @property float angle() { return sprite.angle; }
  @property void angle(float newAngle) { sprite.angle = newAngle; }
  
  @property float radius() { return sprite.scale; }
  @property void radius(float newRadius) { sprite.scale = newRadius; }
  
  vec2 velocity = vec2(0.0, 0.0);
  
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
    initDisplay(p_screenWidth, p_screenHeight);
  
    this.cache = cache;
    
    m_textRender = new TextRender();
    
    assert(DerelictGL3.loadedVersion != GLVersion.None);
    
    assert("shaders/texture.shader".exists);
    textureShader = new Shader("shaders/texture.shader");
    borderShader = new Shader("shaders/border.shader");
    quadShader = new Shader("shaders/quad.shader");
    
    vec3[] dummyVerts;
    dummyVerts.length = 1000 * 6;
    verticesVBO = new Buffer(dummyVerts);
    
    vec2[] dummyTex;
    dummyTex.length = 1000 * 6;
    texVBO = new Buffer(dummyTex);
    
    vec3[] dummyCols;
    dummyCols.length = 1000 * 6;
    dummyCols[] = vec3(0.0, 1.0, 1.0);
    colorVBO = new Buffer(dummyCols);
    
    m_zoom = 0.5;
    
    m_mouseWorldPos = vec2(0.0, 0.0);
    
    m_widthHeightRatio = cast(float)p_screenWidth / cast(float)p_screenHeight;
    
    m_screenBox.lowerleft = vec2((-1.0 / m_zoom) * m_widthHeightRatio, -1.0 / m_zoom);
    m_screenBox.upperright = vec2((1.0 / m_zoom) * m_widthHeightRatio, 1.0 / m_zoom);
  }
  
  ~this()
  {
    //teardownDisplay();
  }

  GraphicsComponent[] getComponentsInBox(vec2 center, float scale, AABB!vec2 drawBox)
  {
    GraphicsComponent[] componentsInBox;
    
    // this filter code gives an internal compiler error on 2.060 :(
    /*return components.filter!(component => !component.screenAbsolutePosition && 
                                          !(component.position - center).x < m_screenBox.lowerleft.x - component.radius ||
                                           (component.position - center).x > m_screenBox.upperright.x + component.radius ||
                                           (component.position - center).y < m_screenBox.lowerleft.y - component.radius ||
                                           (component.position - center).y > m_screenBox.upperright.y + component.radius).array();*/
    
    foreach (ref component; components)
    {
      if (component.screenAbsolutePosition || 
          !((component.position - center).x < drawBox.lowerleft.x  - component.radius ||
            (component.position - center).x > drawBox.upperright.x + component.radius ||
            (component.position - center).y < drawBox.lowerleft.y  - component.radius ||
            (component.position - center).y > drawBox.upperright.y + component.radius))
      {
        componentsInBox ~= component;
      }
    }
    
    return componentsInBox;
  }
  
  void draw(vec2 center, float scale, AABB!vec2 drawBox)
  {
    glClear(GL_COLOR_BUFFER_BIT);
    
    drawTextures(center, scale, drawBox);
    
    drawQuads(center, scale, drawBox);
    
    drawText(center, scale, drawBox);
    
    // draw circle around stuff in debug mode
    debug
    {
      drawDebugCircles(center, scale, drawBox);
    }
  }
  
  void drawTextures(vec2 center, float scale, AABB!vec2 drawBox)
  {
    textureShader.bind();
  
    GraphicsComponent[][string] componentsForTexture;
    foreach (ref component; getComponentsInBox(center, scale, drawBox))
      componentsForTexture[component.textureName] ~= component;
    
    foreach (textureName; m_imageToTexture.keys)
    {
      if (textureName !in componentsForTexture)
        continue;
      
      assert(textureName in m_imageToTexture, "Could not find texture " ~ textureName ~ " in imageToTexture");
      assert(textureName in componentsForTexture, "Could not find texture " ~ textureName ~ " in componentsForTexture");
      
      auto texture = m_imageToTexture[textureName];
      
      auto componentsWithSameTexture = componentsForTexture[textureName];
      
      //writeln(componentsWithSameTexture[0].radius);
      
      vec3[] verts;
      //verts = verts.reduce!((arr, component) => arr ~ component.sprite.verticesForQuadTriangles(component.texture).map!(vertex => vertex - vec3(center, 0.0)).array())(componentsWithSameTexture);
      
      foreach (component; componentsWithSameTexture)
      {
        auto componentVerts = component.sprite.verticesForQuadTriangles(component.texture);
        
        if (component.screenAbsolutePosition == false)
        {
          foreach (ref vert; componentVerts)
          {
            vert -= vec3(center, 0.0);
            vert *= scale;
          }
        }
        
        verts ~= componentVerts;
      }
      
      verticesVBO.update(verts, 0);
      
      vec2[] texs;        
      texs = texs.reduce!((arr, component) => arr ~ ((component.frames > 0) ? component.sprite.frameCoordsForQuadTriangles(component.currentFrame, sqrt(component.frames.to!float).to!int, true) : 
                                                                              component.sprite.texCoordsForQuadTriangles))(componentsWithSameTexture);
      texVBO.update(texs, 0);
      
      verticesVBO.bind(0, GL_FLOAT, 3);
      texVBO.bind(1, GL_FLOAT, 2);
      texture.bind_and_activate();
      
      //writeln("drawing " ~ componentsWithSameTexture.length.to!string ~ " comps with " ~ verts.length.to!string ~ " vertices and texture " ~ textureName);
      
      glDrawArrays(GL_TRIANGLES, 0, verts.length);
      
      texture.unbind();
      texVBO.unbind();
      verticesVBO.unbind();
    }
    
    textureShader.unbind();
  }
  
  
  void drawQuads(vec2 center, float scale, AABB!vec2 drawBox)
  {
    quadShader.bind();
      
    vec3[] verts;
    vec4[] colors;
      
    foreach (component; getComponentsInBox(center, scale, drawBox).filter!(component => component.drawSource == DrawSource.Quad || component.drawSource == DrawSource.Rectangle))
    {
      //verts = verts.reduce!((arr, component) => arr ~ component.sprite.verticesForQuadTriangles(component.texture))(components.filter!(component => component.frames == 0));
      //foreach (component; components.filter!(component => component.frames == 0 && component.drawSource != DrawSource.Text && component.screenAbsolutePosition == false))
      {
        auto componentVerts = component.sprite.verticesForQuadTriangles(component.texture);
        
        if (component.drawSource == DrawSource.Rectangle)
          componentVerts = component.sprite.verticesForQuadTriangles(component.aabb);
        
        foreach (ref vert; componentVerts)
        {
          vert -= vec3(center, 0.0);
          
          vert *= scale;
          
          colors ~= component.color;
        }
        
        verts ~= componentVerts;
      }
    }
    
    verticesVBO.update(verts, 0);
    colorVBO.update(colors, 0);
    
    //vec2[] texs;
    //texs = texs.reduce!((arr, component) => arr ~ component.sprite.texCoordsForQuadTriangles)(components.filter!(component => component.frames == 0));
    //texVBO.update(texs, 0);
    
    verticesVBO.bind(0, GL_FLOAT, 3);
    //texVBO.bind(1, GL_FLOAT, 2);
    colorVBO.bind(2, GL_FLOAT, 4);
    
    glDrawArrays(GL_TRIANGLES, 0, verts.length);
    
    texVBO.unbind();
    verticesVBO.unbind();
    colorVBO.unbind();
    
    quadShader.unbind();
  }
  
  
  void drawText(vec2 center, float scale, AABB!vec2 drawBox)
  {
    textureShader.bind();
    
    foreach (component; getComponentsInBox(center, scale, drawBox).filter!(component => component.drawSource == DrawSource.Text))
    {
      auto stringSprites = m_textRender.getStringSprites(component.text, component.position, component.radius);
      
      vec3[] verts;
      vec2[] texs;
      
      auto text = component.text.replace("\\n", "");
      
      foreach (int index, Sprite sprite; stringSprites)
      {
        auto spriteVerts = sprite.verticesForQuadTriangles(m_textRender.atlas);
        
        if (component.screenAbsolutePosition == false)
        {        
          foreach (ref vert; spriteVerts)
          {
            vert -= vec3(center, 0.0);
            
            vert *= scale;
          }
        } 
        else
        {
          foreach (ref vert; spriteVerts)
          {
            vert += vec3(component.position.x / 0.03, component.position.y / 0.03, 0.0);
            vert *= 0.02;
          }
        }
        verts ~= spriteVerts;
        
        texs ~= sprite.frameCoordsForQuadTriangles(text[index].to!int, 16, false);
      }
      
      verticesVBO.update(verts, 0);
      texVBO.update(texs, 0);
      
      verticesVBO.bind(0, GL_FLOAT, 3);
      texVBO.bind(1, GL_FLOAT, 2);
      m_textRender.atlas.bind_and_activate();
      
      glDrawArrays(GL_TRIANGLES, 0, verts.length);
      
      m_textRender.atlas.unbind();
      texVBO.unbind();
      verticesVBO.unbind();
      
      //writeln("got " ~ stringSprites.to!string ~ " stringsprites for text " ~ component.text);
    }  
    
    textureShader.unbind();
  }
  
  void drawDebugCircles(vec2 center, float scale, AABB!vec2 drawBox)
  {
    borderShader.bind();
    
    vec3[] verts;
    vec3[] colors;
    //verts = verts.reduce!((arr, component) => arr ~ component.sprite.verticesForQuadTriangles(component.texture))(components.filter!(component => component.frames == 0));
    foreach (component; components.filter!(component => component.frames == 0 && 
                                           //component.drawSource != DrawSource.Text && 
                                           component.drawSource != DrawSource.Quad && 
                                           component.drawSource != DrawSource.Rectangle && 
                                           component.screenAbsolutePosition == false))
    {
      auto componentVerts = component.sprite.verticesForQuadTriangles(component.texture);
      
      foreach (ref vert; componentVerts)
      {
        vert -= vec3(center, 0.0);
        
        vert *= scale;
        
        if (component.isPointedAt(m_mouseWorldPos))
          colors ~= vec3(1.0, 0.5, 0.0);
        else
          colors ~= vec3(1.0, 1.0, 1.0);
      }
      
      verts ~= componentVerts;
    }
    verticesVBO.update(verts, 0);
    colorVBO.update(colors, 0);
    
    vec2[] texs;
    texs = texs.reduce!((arr, component) => arr ~ component.sprite.texCoordsForQuadTriangles)(components.filter!(component => component.frames == 0));
    texVBO.update(texs, 0);
    
    verticesVBO.bind(0, GL_FLOAT, 3);
    texVBO.bind(1, GL_FLOAT, 2);
    colorVBO.bind(2, GL_FLOAT, 3);
    
    glDrawArrays(GL_TRIANGLES, 0, verts.length);
    
    texVBO.unbind();
    verticesVBO.unbind();
    colorVBO.unbind();
    
    borderShader.unbind();
  }
  
  void update() 
  {
    int index = 0;
    
    foreach (ref component; entityToComponent.byValue())
    {
      component.timeLived += m_timeStep;
      
      if (component.frames > 0)
      {
        component.currentFrame = (((component.lifeTime - component.timeLived) / component.lifeTime) * component.frames).to!int;
      }
    }
  
    draw(getCenterEntityPosition(), m_zoom, m_screenBox);
    
    swapBuffers();
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
    
    m_screenBox.lowerleft = vec2((-1.0 / m_zoom) * m_widthHeightRatio, -1.0 / m_zoom);
    m_screenBox.upperright = vec2((1.0 / m_zoom) * m_widthHeightRatio, 1.0 / m_zoom);
  }
  
  void zoomOut(float p_time)
  {
    m_zoom -= m_zoom * p_time;
    
    m_screenBox.lowerleft = vec2((-1.0 / m_zoom) * m_widthHeightRatio, -1.0 / m_zoom);
    m_screenBox.upperright = vec2((1.0 / m_zoom) * m_widthHeightRatio, 1.0 / m_zoom);
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
    m_mouseWorldPos = p_mouseScreenPos * (1.0 / m_zoom) * 0.75 + centerComponent.position;
    
    //writeln("scale: " ~ m_zoom.to!string ~ ", screenpos: " ~ p_mouseScreenPos.to!string ~ ", worldpos: " ~ m_mouseWorldPos.to!string);
  }
  
  vec2 mouseWorldPos()
  {
    return m_mouseWorldPos;
  }
  
  void setTargetEntity(Entity p_entity)
  {
    //assert(hasComponent(p_entity));
    m_targetEntity = p_entity;
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
  
  void setTimeStep(float p_timeStep)
  {
    m_timeStep = p_timeStep;
  }
  
  AABB!vec2 getStringBox(string text, float scale)
  {
    return m_textRender.getStringBox(text, scale);
  }
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return "drawsource" in p_entity || "keepInCenter" in p_entity || "text" in p_entity;
  
    /*return (p_entity["drawsource"].length > 0 ||
            p_entity["keepInCenter"].length > 0 ||
            p_entity["text"].length > 0);*/
  }
  
  GraphicsComponent createComponent(Entity p_entity)
  {
    //writeln("graphics creating component from values " ~ to!string(p_entity.values));
    
    //enforce(p_entity.["radius"].length > 0, "Couldn't find radius for graphics component");
    float radius = 1.0;
    if ("radius" in p_entity)
      radius = to!float(p_entity["radius"]);
    
    GraphicsComponent component; // = GraphicsComponent(radius);
    
    float width = 0.0;
    float height = 0.0;
    if ("width" in p_entity)
      width = to!float(p_entity["width"]);
    if ("height" in p_entity)
      height = to!float(p_entity["height"]);
    
    component.aabb.lowerleft = vec2(-width/2.0, -height/2.0);
    component.aabb.upperright = vec2(width/2.0, height/2.0);
    
    if ("lowerleft" in p_entity)
      component.aabb.lowerleft = p_entity["lowerleft"].to!(float[])[0..2].vec2;
    if ("upperright" in p_entity)
      component.aabb.upperright = p_entity["upperright"].to!(float[])[0..2].vec2;
    
    if ("keepInCenter" in p_entity && p_entity["keepInCenter"] == "true")
    {
      m_centerEntity = p_entity;
    }
    
    if ("hideFromRadar" in p_entity && p_entity["hideFromRadar"] == "true")
    {
      component.hideFromRadar = true;
    }
    
    if ("drawsource" in p_entity && p_entity["drawsource"].looksLikeATextFile())
    {
      component.drawSource = DrawSource.Vertices;
      
      // (ab)use entity to just get out data here, since it has loading and caching capabilities
      Entity drawfile = new Entity(loadValues(cache, "data/" ~ p_entity["drawsource"]));
      
      foreach (vertexName, vertexData; drawfile.values)
      {
        //if (vertexName.startsWith("vertex"))
          //component.vertices ~= Vertex.fromString(vertexData);
      }
    }
    else if (p_entity["drawsource"].endsWith(".png") || 
             p_entity["drawsource"].endsWith(".jpg"))
    {
      component.drawSource = DrawSource.Texture;
      
      auto imageFile = "data/" ~ p_entity["drawsource"];
      
      if (imageFile !in m_imageToTexture)
      {
        //loadTexture(imageFile);
        auto texture = Texture2D.from_image(imageFile);
        
        m_imageToTexture[imageFile] = texture;
      }
      
      assert(imageFile in m_imageToTexture, "Problem with imageToTexture cache");
      component.texture = m_imageToTexture[imageFile];
      
      component.textureName = imageFile;
      //m_componentsForTexture[imageFile] ~= component;
    }
    else
    {
      if ("drawsource" in p_entity)
      {
        component.drawSource = to!DrawSource(p_entity["drawsource"]);
      }
      else if ("text" in p_entity)
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
        string[] verticesData = p_entity["vertices"].to!(string[]);
        
        /*foreach (vertexData; verticesData)
          component.vertices ~= Vertex.fromString(vertexData);*/
          
        //writeln("comp vertices is " ~ component.vertices.to!string);
      }
    }
    
    foreach (value; p_entity.keys)
    {
      //if (std.algorithm.startsWith(value, "connectpoint") > 0)
      if (value.startsWith("connectpoint") > 0)
      {
        //component.connectPoints ~= vec2.fromString(p_entity.getValue(value)) * radius;
        //component.connectPoints ~= vec2(p_entity[value].to!(float[])[0..2]) * radius;
        component.connectPoints ~= p_entity[value].to!(float[])[0..2].vec2 * radius;
      }
    }
    
    if ("position" in p_entity)
    {
      assert(p_entity["position"].length > 0);
      component.position = p_entity["position"].to!(float[])[0..2].vec2;
    }
    
    if ("radius" in p_entity)
    {
      assert(p_entity["radius"].length > 0);
      component.radius = p_entity["radius"].to!float;
    }
    
    component.depth = p_entity.id.to!float;
    if ("depth" in p_entity)
    {
      if (p_entity["depth"] == "bottom")
        component.depth -= 100;
      else if (p_entity["depth"] == "top")
        component.depth += 200;
      else
        component.depth = p_entity["depth"].to!float;
    }
    
    if ("angle" in p_entity)
      component.angle = p_entity["angle"].to!float * PI_180;
    
    if ("screenAbsolutePosition" in p_entity)
    {
      component.screenAbsolutePosition = true;
    }
    
    if ("text" in p_entity)
    {
      component.text = p_entity["text"];
    }
    
    if ("color" in p_entity)
    {
      string colorString = p_entity["color"];
      
      if (colorString.strip.startsWith("["))
      {
        component.color = colorString.to!(float[])[0..4].vec4;
      }
      else
      {      
        assert(colorString.split(" ").length >= 3);
        
        auto colorComponents = colorString.split(" ");
        
        if (colorComponents.length == 3)
          colorComponents ~= "1"; // default alpha is 1

        component.color = colorComponents.map!(to!float).array().vec4;
      }
    }
    
    if ("frames" in p_entity)
    {
      component.frames = p_entity["frames"].to!int;
    }
    
    if ("lifetime" in p_entity)
    {
      component.lifeTime = p_entity["lifetime"].to!float;
    }
    
    /*if (component.drawSource != DrawSource.Text && 
        component.drawSource != DrawSource.RadarDisplay &&
        component.drawSource != DrawSource.TargetDisplay)
      component.createDisplayList;*/
    
    return component;
  }

private:
  void drawComponent(GraphicsComponent p_component)
  {
    /*if (p_component.drawSource == DrawSource.Invisible)
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
        glColor4f(vertex.color.r, vertex.color.g, vertex.color.b, vertex.color.a);
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
  
      assert(p_component.texture > 0);
      
      glEnable(GL_TEXTURE_2D);
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      
      auto size = 1.0 * p_component.radius;
      
      glColor4f(1.0, 1.0, 1.0, 1.0);
      
      glBindTexture(GL_TEXTURE_2D, p_component.texture);
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
    else if (p_component.drawSource == DrawSource.TargetDisplay)
    {
      drawTargetDisplay(p_component);
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
    }*/
  }
  
  void drawRadar(GraphicsComponent radarComponent)
  {
    // draw radar circle
    /*glPushMatrix();
    
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
    // line 686 with dmd 2.059....
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
    glPopMatrix();*/
  }
  
  
  void drawTargetDisplay(GraphicsComponent p_displayComponent)
  {
    // TODO: draw the entire scene, just make sure there's a proper AABB culling unnecessary stuff
    // drawing just the target entity won't work since it's probably a ship composite entity - only the module entities of the ship have actual graphics
    //if (m_targetEntity !is null)
    //glPushMatrix();
    {
      /*
      auto targetComponent = getComponent(m_targetEntity);
      
      if (targetComponent.displayListId > 0)
        glCallList(targetComponent.displayListId);
      else
        drawComponent(targetComponent);
      */

      auto targetComponent = GraphicsComponent();
      
      string targetText = "No target";
      if (m_targetEntity !is null)
        targetText = "Targeting " ~ to!string(m_targetEntity.id);
      
      if (m_targetEntity !is null && hasComponent(m_targetEntity))
        targetComponent = getComponent(m_targetEntity);
      
      int drawnComponents = 0;      
      
      float targetZoom = 0.05;
      
      AABB!vec2 displayBox = AABB!vec2(p_displayComponent.position - vec2(4.0, 4.0), p_displayComponent.position + vec2(2.0, 2.0));
      
      /*glPushMatrix();
        glScalef(targetZoom, targetZoom, 1.0);
        glTranslatef(displayBox.lowerleft.x, displayBox.lowerleft.y, 0.0);
        
        //glTranslatef(0.0, component.radius*2, 0.0);
        //glColor4f(component.color.r, component.color.g, component.color.b, component.color.a);
        m_textRender.renderString(targetText);
      glPopMatrix();*/
      
      // stable sort sometimes randomly crashes, phobos bug or float fuckery with lots of similar floats?
      // haven't seen any crashes so far with dmd 2.058
      foreach (component; sort!((left, right) => left.depth < right.depth, SwapStrategy.stable)(components))
      //foreach (component; components)
      {
        //glPushMatrix();
        
        assert(component.position.ok);
        
        if (component.screenAbsolutePosition == false)
        {
          //glScalef(targetZoom, targetZoom, 1.0);
            
          // cull stuff that won't be shown on screen
          if ((component.position - targetComponent.position).x < displayBox.lowerleft.x - component.radius ||
              (component.position - targetComponent.position).x > displayBox.upperright.x + component.radius ||
              (component.position - targetComponent.position).y < displayBox.lowerleft.y - component.radius ||
              (component.position - targetComponent.position).y > displayBox.upperright.y + component.radius)
          {
            //glPopMatrix();
            continue;
          }
          else
          {
            drawnComponents++;
          }
          
          //glTranslatef(-targetComponent.position.x, -targetComponent.position.y, 0.0);
          
          //glTranslatef(-p_targetComponent.position.x, -p_targetComponent.position.y, 0.0);
          //glTranslatef(component.position.x, component.position.y, component.depth * 0.001);
                
          //glDisable(GL_TEXTURE_2D);
          
          //glRotatef(component.angle * _180_PI, 0.0, 0.0, -1.0);
          
          /*if (component.displayListId > 0)
            glCallList(component.displayListId);
          else*/
            drawComponent(component);
        }
        
        //glPopMatrix();
      }
      
      //writeln("targetdisplay drew " ~ to!string(drawnComponents) ~ " components, targetcomp is at " ~ to!string(p_targetComponent.position));
    }
    //glPopMatrix();
  }  


  void initDisplay(int screenWidth, int screenHeight)
  {
    DerelictSDL2.load();
    DerelictSDL2Image.load();
    DerelictGL3.load();
   
    enforce(SDL_Init(SDL_INIT_VIDEO) == 0, "Failed to initialize SDL: " ~ to!string(SDL_GetError()));
    
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    
    window = SDL_CreateWindow("spacegame", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, screenWidth, screenHeight, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN);
    enforce(window !is null, "Error creating window");
    
    auto context = SDL_GL_CreateContext(window);
    SDL_GL_SetSwapInterval(1);
    
    setupGL(screenWidth, screenHeight);
    
    DerelictGL3.reload();
  }


  void setupGL(int p_screenWidth, int p_screenHeight)
  {  
    glClearColor(0.0, 0.0, 0.5, 1.0);
    
    float widthHeightRatio = cast(float)p_screenWidth / cast(float)p_screenHeight;
    
    if (p_screenWidth > p_screenHeight)
      glViewport(0, -(p_screenWidth - p_screenHeight) / 2, p_screenWidth, p_screenWidth);
    else
      glViewport(-(p_screenHeight - p_screenWidth) / 2, 0, p_screenHeight, p_screenHeight);
      
    //glEnable(GL_DEPTH_TEST);
    //glDepthFunc(GL_LEQUAL);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  }


  void swapBuffers()
  {
    SDL_GL_SwapWindow(window);
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  }
  
private:
  SDL_Window* window;

  Shader textureShader;
  Shader borderShader;
  Shader quadShader;
  
  TextRender m_textRender;
  
  Texture2D[string] m_imageToTexture;
  
  Buffer verticesVBO;
  Buffer texVBO;
  Buffer colorVBO;
  
  float m_widthHeightRatio;
  AABB!vec2 m_screenBox;
  float m_zoom;
  
  vec2 m_mouseWorldPos;
  
  Entity m_centerEntity;
  
  Entity m_targetEntity;
  
  string[][string] cache;
  
  float m_timeStep = 0.0;
}


private:
  bool looksLikeATextFile(string p_txt)
  {
    return endsWith(p_txt, ".txt") > 0;
  }
