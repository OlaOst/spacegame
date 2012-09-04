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

import derelict.freetype.ft;
import derelict.opengl3.gl3;
import derelict.opengl3.glx;

import glamour.texture;
import gl3n.linalg;

import sprite;


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
  
  textRender.renderChar('1', false);
  textRender.renderChar('1', false);
  
  textRender.renderString("hello world");
  
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
    
    defaultFont = "freesansbold.ttf";
    
    auto fontError = FT_New_Face(lib, ("./" ~ defaultFont).toStringz(), 0, &m_face);
    enforce(fontError != FT_Err_Unknown_File_Format, "Error, font format unsupported");
    enforce(fontError == false, "Error loading font file");
    
    FT_Set_Pixel_Sizes(m_face, 32, 32);
    
    
    setupAtlas(defaultFont);
  }
  
  
  void renderChar(char p_char, bool p_translate)
  {
    //glEnable(GL_TEXTURE_2D);
    
    auto glyph = loadGlyph(p_char);
    
    auto xCoord = cast(float)glyph.bitmap.width / 32.0;
    auto yCoord = cast(float)glyph.bitmap.rows / 32.0;
    
    //glBindTexture(GL_TEXTURE_2D, glyph.textureId);

    // translate the glyph so that its 'origin' matches the pen position
    /*glPushMatrix();
    glTranslatef(glyph.offset.x, glyph.offset.y, 0.0);
    
    glBegin(GL_QUADS);
      glNormal3f(0.0, 0.0, 1.0);
      
      glTexCoord2f(0.0,    yCoord); glVertex3f(0.0,    0.0,    0.0);
      glTexCoord2f(xCoord, yCoord); glVertex3f(xCoord, 0.0,    0.0);
      glTexCoord2f(xCoord, 0.0);    glVertex3f(xCoord, yCoord, 0.0);
      glTexCoord2f(0.0,    0.0);    glVertex3f(0.0,    yCoord, 0.0);
    glEnd();
    
    glPopMatrix();
    
    // here we increment the pen position by the glyph's advance, when drawing strings
    if (p_translate)
      glTranslatef(glyph.advance.x, glyph.advance.y, 0.0);*/
  }

  
  void renderString(string p_string)
  {
    //glPushMatrix();
    
    bool nextLetterIsControlCharacter = false;
    
    foreach (letter; p_string)
    {
      if (letter == '\\')
        nextLetterIsControlCharacter = true;
      else
      {
        if (nextLetterIsControlCharacter)
        {
          if (letter == 'n')
          {
            //glPopMatrix(); // simulates carriage return
            //glTranslatef(0.0, -1.0, 0.0); // simulates newline
            //glPushMatrix(); // ready to write on new line
          }
          if (letter == '\\')
            renderChar(letter, true);
            
          nextLetterIsControlCharacter = false;
        }
        else
          renderChar(letter, true);
      }
    }
      
    //glPopMatrix();
    
    //glDisable(GL_TEXTURE_2D);
  }
    
  Sprite[] getStringSprites(string text, vec2 position, float scale)
  {
    Sprite[] stringSprites;
    
    vec3 cursor = vec3(position.xy, 0.0);
    
    foreach (character; text)
    {
      auto glyph = loadGlyph(character);
      
      auto xCoord = cast(float)glyph.bitmap.width / 32.0;
      auto yCoord = cast(float)glyph.bitmap.rows / 32.0;
    
      Sprite sprite;
      
      sprite.scale = scale;
      sprite.position = cursor + vec3(glyph.offset.x * sprite.scale, glyph.offset.y * sprite.scale, 0.0);
      
      stringSprites ~= sprite;
      
      cursor += vec3(glyph.advance.x * sprite.scale * 2, glyph.advance.y * sprite.scale * 2, 0.0);
    }
    
    return stringSprites;
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
    enum int glyphWidth = 32;
    enum int glyphHeight = 32;
    
    //glEnable(GL_TEXTURE_2D);
    
    auto glyphIndex = FT_Get_Char_Index(m_face, p_char);
    
    FT_Load_Glyph(m_face, glyphIndex, 0);
    FT_Render_Glyph(m_face.glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL);
    
    GlyphTexture glyph;

    glyph.data = new GLubyte[4 * glyphWidth * glyphHeight];
    glyph.bitmap = m_face.glyph.bitmap;
    
    glyph.advance = vec2(m_face.glyph.advance.x / (64.0 * 32.0), m_face.glyph.advance.y / (64.0 * 32.0));
    glyph.offset = vec2(m_face.glyph.bitmap_left / 32.0, -(m_face.glyph.bitmap.rows - m_face.glyph.bitmap_top) / 32.0);
    
    auto unalignedGlyph = m_face.glyph.bitmap.buffer;
    
    /*debug writeln("glyph " ~ p_char ~ 
                  ", buffer is " ~ to!string(m_face.glyph.bitmap.width) ~ "x" ~ to!string(m_face.glyph.bitmap.rows) ~ 
                  ", pitch is " ~ to!string(m_face.glyph.bitmap.pitch) ~ 
                  ", metric is " ~ to!string(m_face.glyph.metrics.width/64) ~ "x" ~ to!string(m_face.glyph.metrics.height/64) ~ 
                  ", horizontal advance is " ~ to!string(m_face.glyph.metrics.horiAdvance/64) ~ 
                  ", bearing is " ~ to!string(m_face.glyph.bitmap_left) ~ "x" ~ to!string(m_face.glyph.bitmap_top));*/
    
    auto widthOffset = (glyphWidth - m_face.glyph.bitmap.width) / 2;
    auto heightOffset = (glyphHeight - m_face.glyph.bitmap.rows) / 2;
    
    //debug writeln("bitmap for " ~ p_char);
    for (int y = 0; y < m_face.glyph.bitmap.rows; y++)
    {
      for (int x = 0; x < m_face.glyph.bitmap.width; x++)
      {
        int coord = 4 * (x + y*glyphWidth);
        
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
    data.length = ((16 * 32) ^^ 2) * 4;
    
    foreach (index; iota(0, 256))
    {
      auto glyph = loadGlyph(index.to!char);
      
      int row = index / 16;
      int col = index % 16;
      
      foreach (y; iota(0, 32))
      {
        foreach (x; iota(0, 32))
        {
          /*data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 0] = glyph.data[((31-y) * 32 + x)*4 + 0];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 1] = glyph.data[((31-y) * 32 + x)*4 + 1];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 2] = glyph.data[((31-y) * 32 + x)*4 + 2];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 3] = glyph.data[((31-y) * 32 + x)*4 + 3];*/
          
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 0] = glyph.data[(y * 32 + x)*4 + 0];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 1] = glyph.data[(y * 32 + x)*4 + 1];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 2] = glyph.data[(y * 32 + x)*4 + 2];
          data[(col*32 + row*32*16*32 + x + y*32*16)*4 + 3] = glyph.data[(y * 32 + x)*4 + 3];
        }
      }
    }
    
    m_atlas[font] = new Texture2D();
    m_atlas[font].set_data(data, GL_RGBA, 16*32, 16*32, GL_RGBA, GL_UNSIGNED_BYTE);
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
};
