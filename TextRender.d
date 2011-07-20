module TextRender;

import std.conv;
import std.exception;
import std.stdio;

import derelict.freetype.ft;
import derelict.opengl.gl;

import Display;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  // renderText("blablabla") should display text at current position
  // either height of one character is 1 or the width of the entire string is 1
  
  auto textRender = new TextRender();
  
  // assert derelict freetype is loaded? supposed to be internal stuff, not part of interface
  // NOPE just load gl here if this file is unittested in isolation
  DerelictGL.load();
  
  
  textRender.renderChar('1', false);
  textRender.renderChar('1', false);
  
  textRender.renderString("hello world");
}


class TextRender
{
public:
  this()
  {
    DerelictFT.load();
    
    FT_Library lib;
    
    enforce(FT_Init_FreeType(&lib) == false, "Error initializing FreeType");
    
    auto fontError = FT_New_Face(lib, "./freesansbold.ttf", 0, &m_face);
    enforce(fontError != FT_Err_Unknown_File_Format, "Error, font format unsupported");
    enforce(fontError == false, "Error loading font file");
    
    FT_Set_Pixel_Sizes(m_face, 32, 32);
  }
  
  
  void renderChar(char p_char, bool p_translate)
  {
    /*glEnable(GL_TEXTURE_2D);
    
    auto glyph = loadGlyph(p_char);
        
    assert(glyph);
    
    auto xCoord = cast(float)glyph.bitmap.width / 32.0;
    auto yCoord = cast(float)glyph.bitmap.rows / 32.0;
    
    //xCoord = yCoord = 1.0;
    
    glBindTexture(GL_TEXTURE_2D, glyph.textureId);

    glBegin(GL_QUADS);
      glNormal3f(0.0, 0.0, 1.0);
      //glTexCoord2f(0.0,    yCoord); glVertex3f(-(xCoord/yCoord), -1.0, 0.0);
      //glTexCoord2f(xCoord, yCoord); glVertex3f( (xCoord/yCoord), -1.0, 0.0);
      //glTexCoord2f(xCoord, 0.0);    glVertex3f( (xCoord/yCoord),  1.0, 0.0);
      //glTexCoord2f(0.0,    0.0);    glVertex3f(-(xCoord/yCoord),  1.0, 0.0);
      
      glTexCoord2f(0.0,    yCoord); glVertex3f(0.0,    0.0,    0.0);
      glTexCoord2f(xCoord, yCoord); glVertex3f(xCoord, 0.0,    0.0);
      glTexCoord2f(xCoord, 0.0);    glVertex3f(xCoord, yCoord, 0.0);
      glTexCoord2f(0.0,    0.0);    glVertex3f(0.0,    yCoord, 0.0);
    glEnd();
    
    if (p_translate)
      glTranslatef(1.0 * xCoord/yCoord, 0.0, 0.0);*/
  }

  
  void renderString(string p_string)
  {
    glPushMatrix();
    
    foreach (letter; p_string)
      renderChar(letter, true);
      
    glPopMatrix();
  }
  
private:
  GlyphTexture loadGlyph(char p_char)
  {
    if (p_char !in m_glyphs)
      m_glyphs[p_char] = createGlyphTexture(p_char);
    
    assert(m_glyphs[p_char]);
    
    return m_glyphs[p_char];
  }
  
  
  GlyphTexture createGlyphTexture(char p_char)
  {
    enum int glyphWidth = 32;
    enum int glyphHeight = 32;
    
    glEnable(GL_TEXTURE_2D);
    
    auto glyphIndex = FT_Get_Char_Index(m_face, p_char);
    
    FT_Load_Glyph(m_face, glyphIndex, 0);
    FT_Render_Glyph(m_face.glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL);
    
    GlyphTexture glyph = new GlyphTexture();

    glyph.data = new GLubyte[4 * glyphWidth * glyphHeight];
    glyph.bitmap = m_face.glyph.bitmap;
    
    auto unalignedGlyph = m_face.glyph.bitmap.buffer;
    
    //debug writeln("glyph " ~ p_char ~ " buffer is " ~ to!string(m_face.glyph.bitmap.width) ~ "x" ~ to!string(m_face.glyph.bitmap.rows) ~ ", pitch is " ~ to!string(m_face.glyph.bitmap.pitch));
    
    auto widthOffset = (glyphWidth - m_face.glyph.bitmap.width) / 2;
    auto heightOffset = (glyphHeight - m_face.glyph.bitmap.rows) / 2;
    
    for (int y = 0; y < m_face.glyph.bitmap.rows; y++)
    {
      for (int x = 0; x < m_face.glyph.bitmap.width; x++)
      {
        //int coord = 4 * (x+widthOffset + (y+heightOffset)*glyphHeight);
        int coord = 4 * (x + y*glyphHeight);
        
        glyph.data[coord] = unalignedGlyph[x + y*m_face.glyph.bitmap.width];
      }
    }

    glGenTextures(1, &glyph.textureId);
    glBindTexture(GL_TEXTURE_2D, glyph.textureId);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
    glTexImage2D(GL_TEXTURE_2D, 0, 1, glyphWidth, glyphHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, glyph.data.ptr);
    
    return glyph;
  }
  

private:
  class GlyphTexture
  {
    invariant()
    {
      assert(textureId > 0);
      assert(data.length > 0);
    }
    
    uint textureId;
    FT_Bitmap bitmap;
    GLubyte[] data;
  };
  
  
private:
  FT_Face m_face;
  
  GlyphTexture[char] m_glyphs;
};

