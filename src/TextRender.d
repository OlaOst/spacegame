/*
 Copyright (c) 2011 Ola Øttveit

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

module TextRender;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.string;

import derelict.freetype.ft;
import derelict.opengl3.gl3;
import derelict.opengl3.glx;

import glamour.texture;
import gl3n.linalg;

import sprite;
import Utils;

unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  // renderText("blablabla") should display text at current position
  // either height of one character is 1 or the width of the entire string is 1
  
  auto textRender = new TextRender();
  
  // assert derelict freetype is loaded? supposed to be internal stuff, not part of interface
  // NOPE just load gl here if this file is unittested in isolation
  //DerelictGL3.load();
  
  //initDisplay(640, 480);
  
  //textRender.renderChar('1', false);
  //textRender.renderChar('1', false);
  
  //textRender.renderString("hello world");
  
  /*FT_vec2 kerningvec2;
  
  foreach (a; iota(cast(int)'a', cast(int)'z'))
  {
    foreach (b; iota(cast(int)'a', cast(int)'z'))
    {
      auto kerningError = FT_Get_Kerning(textRender.m_face, a, b, 0, &kerningvec2);
    
      assert(kerningError == 0, "Kerning error: " ~ to!string(kerningError));
    
      writeln("testing kerning, vec2 between " ~ cast(char)a ~ " and " ~ cast(char)b ~ " is " ~ to!string(kerningvec2.x) ~ "x" ~ to!string(kerningvec2.y));
    }
  }*/
}


class TextRender
{
public:
  this()
  {
    DerelictFT.load();
    
    FT_Library lib;
    
    enforce(FT_Init_FreeType(&lib) == false, "Error initializing FreeType");
    
    //defaultFont = "freesansbold.ttf";
    //defaultFont = "Inconsolata.otf";
    //defaultFont = "OxygenMono-Regular.otf";
    defaultFont = "telegrama_render.otf";
    
    auto fontError = FT_New_Face(lib, ("./" ~ defaultFont).toStringz(), 0, &m_face);
    enforce(fontError != FT_Err_Unknown_File_Format, "Error, font format unsupported");
    enforce(fontError == false, "Error loading font file");
    
    FT_Set_Pixel_Sizes(m_face, glyphSize, glyphSize);
    
    
    setupAtlas(defaultFont);
  }
  
  Sprite[] getStringSprites(string text, vec2 position, float scale)
  {
    Sprite[] stringSprites;
    
    vec3 cursor = vec3(position.xy, 0.0);
    
    auto lines = text.split("\\n");
    
    foreach (line; lines)
    {
      foreach (character; line)
      {
        auto glyph = loadGlyph(character);
      
        auto xCoord = cast(float)glyph.bitmap.width / cast(float)glyphSize;
        auto yCoord = cast(float)glyph.bitmap.rows / cast(float)glyphSize;
      
        Sprite sprite;
        
        sprite.scale = scale;
        sprite.position = cursor + vec3(glyph.offset.x * sprite.scale * 2, glyph.offset.y * sprite.scale * 2, 0.0);
        
        stringSprites ~= sprite;
        
        cursor += vec3(glyph.advance.x * sprite.scale * 2, glyph.advance.y * sprite.scale * 2, 0.0);
      }
      cursor = vec3(position.x, cursor.y - 1.0 * scale * 2, 0.0);
    }
    
    return stringSprites;
  }
  
  AABB!vec2 getStringBox(string text, float scale)
  {
    AABB!vec2 box;
    
    vec2 cursor = vec2(0.0, 0.0);
    
    auto lines = text.split("\\n");
    
    float width = 0.0;
    
    foreach (line; lines)
    {
      foreach (character; line)
      {
        auto glyph = loadGlyph(character);
      
        auto xCoord = cast(float)glyph.bitmap.width / cast(float)glyphSize;
        auto yCoord = cast(float)glyph.bitmap.rows / cast(float)glyphSize;
      
        /*Sprite sprite;
        
        sprite.scale = scale;
        sprite.position = cursor + vec3(glyph.offset.x * sprite.scale * 2, glyph.offset.y * sprite.scale * 2, 0.0);
        
        stringSprites ~= sprite;*/
        
        cursor += vec2(glyph.advance.x * scale * 2, glyph.advance.y * scale * 2);
        
        width = max(width, cursor.x);
      }
      cursor = vec2(0.0, cursor.y - 1.0 * scale * 2);
    }
    
    cursor.x = width;
    
    box.lowerleft = cursor * -0.5;
    box.upperright = cursor * 0.5;
    
    /*
    auto lines = text.split("\\n");
    
    auto width = lines.map!(line => line.length).minPos!("a > b")[0];
    auto height = lines.length;
    
    box.lowerleft = vec2(-(width*scale), -(height*scale));
    box.upperright = vec2((width*scale), (height*scale));
    */
    return box;
  }
  
  @property Texture2D atlas()
  {
    return m_atlas[defaultFont];
  }
  
  
private:
  GlyphTexture loadGlyph(char p_char)
  {
    if (p_char !in m_glyphs)
      m_glyphs[p_char] = createGlyphTexture(p_char);

    return m_glyphs[p_char];
  }
  
  
  GlyphTexture createGlyphTexture(char p_char)
  {
    // TODO: what to do if these aren't large enough? glyph width and rows MUST fit inside these
    enum int glyphWidth = glyphSize;
    enum int glyphHeight = glyphSize;
    
    //glEnable(GL_TEXTURE_2D);
    
    auto glyphIndex = FT_Get_Char_Index(m_face, p_char);
    
    FT_Load_Glyph(m_face, glyphIndex, 0);
    FT_Render_Glyph(m_face.glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL);
    
    GlyphTexture glyph;

    glyph.data = new GLubyte[4 * glyphWidth * glyphHeight];
    glyph.bitmap = m_face.glyph.bitmap;
    
    glyph.advance = vec2(m_face.glyph.advance.x / (64.0 * cast(float)glyphSize), m_face.glyph.advance.y / (64.0 * cast(float)glyphSize));
    glyph.offset = vec2(m_face.glyph.bitmap_left / cast(float)glyphSize, -(m_face.glyph.bitmap.rows - m_face.glyph.bitmap_top) / cast(float)glyphSize);
    
    auto unalignedGlyph = m_face.glyph.bitmap.buffer;
    
    /*debug writeln("glyph " ~ p_char ~ 
                  ", buffer is " ~ to!string(m_face.glyph.bitmap.width) ~ "x" ~ to!string(m_face.glyph.bitmap.rows) ~ 
                  ", pitch is " ~ to!string(m_face.glyph.bitmap.pitch) ~ 
                  ", metric is " ~ to!string(m_face.glyph.metrics.width/64) ~ "x" ~ to!string(m_face.glyph.metrics.height/64) ~ 
                  ", horizontal advance is " ~ to!string(m_face.glyph.metrics.horiAdvance/64) ~ 
                  ", bearing is " ~ to!string(m_face.glyph.bitmap_left) ~ "x" ~ to!string(m_face.glyph.bitmap_top));*/
    
    auto widthOffset = (glyphWidth - m_face.glyph.bitmap.width) / 2;
    auto heightOffset = (glyphHeight - m_face.glyph.bitmap.rows) / 2;
    
    //debug writeln("bitmap for " ~ p_char ~ " with " ~ m_face.glyph.bitmap.rows.to!string ~ " rows and " ~ m_face.glyph.bitmap.width.to!string ~ " width");
    for (int y = 0; y < m_face.glyph.bitmap.rows; y++)
    {
      for (int x = 0; x < m_face.glyph.bitmap.width; x++)
      {
        int coord = 4 * (x + y*glyphWidth);
        
        if (glyph.data.length <= coord+3)
        {
          writeln("Out of bounds error when creating glyph texture for character " ~ p_char);
          break;
        }
          
        assert(glyph.data.length > coord+3, "Coord " ~ coord.to!string ~ " is out of bounds issues with " ~ p_char ~ ". x is " ~ x.to!string ~ ", y is " ~ y.to!string ~ ", glyphWidth is " ~ glyphWidth.to!string);
        
        glyph.data[coord+0] = unalignedGlyph[x + (m_face.glyph.bitmap.rows-1-y)*m_face.glyph.bitmap.width];
        glyph.data[coord+1] = unalignedGlyph[x + (m_face.glyph.bitmap.rows-1-y)*m_face.glyph.bitmap.width];
        glyph.data[coord+2] = unalignedGlyph[x + (m_face.glyph.bitmap.rows-1-y)*m_face.glyph.bitmap.width];
        glyph.data[coord+3] = unalignedGlyph[x + (m_face.glyph.bitmap.rows-1-y)*m_face.glyph.bitmap.width];
        
        //debug write(glyph.data[coord]>0?(to!string(glyph.data[coord]/26)):".");
      }
      //debug write("\n");
    }
    //debug writeln("");

    /*glGenTextures(1, &glyph.textureId);
    assert(glyph.textureId > 0, "Failed to generate texture id: " ~ to!string(glGetError()));
    
    glBindTexture(GL_TEXTURE_2D, glyph.textureId);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, glyphWidth, glyphHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, glyph.data.ptr);*/
    
    //glyph.texture = new Texture2D();
    //glyph.texture.set_data(glyph.data, GL_RGBA, glyphWidth, glyphHeight, GL_RGBA, GL_UNSIGNED_BYTE);
    
    assert(glyph.data.length > 0, "Failed to fill glyph texture");
    
    return glyph;
  }
  
  
  void setupAtlas(string font)
  {
    GLubyte[] data;
    data.length = ((16 * glyphSize) ^^ 2) * 4 + (16*glyphSize*4*4);
    
    foreach (index; iota(0, 256))
    {
      auto glyph = loadGlyph(index.to!char);
      
      int row = index / 16;
      int col = index % 16;
      
      foreach (y; iota(0, glyphSize))
      {
        foreach (x; iota(0, glyphSize))
        {
          /*data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 0] = glyph.data[((31-y) * 32 + x)*4 + 0];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 1] = glyph.data[((31-y) * 32 + x)*4 + 1];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 2] = glyph.data[((31-y) * 32 + x)*4 + 2];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 3] = glyph.data[((31-y) * 32 + x)*4 + 3];*/
          
          data[4 + (4*16*glyphSize) + (col*glyphSize + row*glyphSize*16*glyphSize + x + y*glyphSize*16)*4 + 0] = glyph.data[(y * glyphSize + x)*4 + 0];
          data[4 + (4*16*glyphSize) + (col*glyphSize + row*glyphSize*16*glyphSize + x + y*glyphSize*16)*4 + 1] = glyph.data[(y * glyphSize + x)*4 + 1];
          data[4 + (4*16*glyphSize) + (col*glyphSize + row*glyphSize*16*glyphSize + x + y*glyphSize*16)*4 + 2] = glyph.data[(y * glyphSize + x)*4 + 2];
          data[4 + (4*16*glyphSize) + (col*glyphSize + row*glyphSize*16*glyphSize + x + y*glyphSize*16)*4 + 3] = glyph.data[(y * glyphSize + x)*4 + 3];
        }
      }
    }
    
    //glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, [1.0f, 0.0f, 0.0f, 0.0f].ptr);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    //glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    
    m_atlas[font] = new Texture2D();
    m_atlas[font].set_data(data, GL_RGBA, 16*glyphSize, 16*glyphSize, GL_RGBA, GL_UNSIGNED_BYTE);
  }

private:
  struct GlyphTexture
  {
    //uint textureId;
    //Texture2D texture;
    
    FT_Bitmap bitmap;
    
    vec2 offset; // offset for this glyph, so for example lowercase 'g' will be drawn slightly lower
    vec2 advance; // how much should we move to the right and down when drawing this glyph before another one (when drawing strings)
    
    GLubyte[] data;
  };
  
  
private:
  FT_Face m_face;
  
  GlyphTexture[char] m_glyphs;
  
  string defaultFont;
  
  Texture2D[string] m_atlas;
  
  static enum glyphSize = 32;
};
