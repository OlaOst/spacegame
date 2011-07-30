module TextRender;

import std.conv;
import std.exception;
import std.range;
import std.stdio;

import derelict.freetype.ft;
import derelict.opengl.gl;
import derelict.opengl.glu;

import Display;
import common.Vector;


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
  
  initDisplay(640, 480);
  
  textRender.renderChar('1', false);
  textRender.renderChar('1', false);
  
  textRender.renderString("hello world");
  
  /*FT_Vector kerningVector;
  
  foreach (a; iota(cast(int)'a', cast(int)'z'))
  {
    foreach (b; iota(cast(int)'a', cast(int)'z'))
    {
      auto kerningError = FT_Get_Kerning(textRender.m_face, a, b, 0, &kerningVector);
    
      assert(kerningError == 0, "Kerning error: " ~ to!string(kerningError));
    
      writeln("testing kerning, vector between " ~ cast(char)a ~ " and " ~ cast(char)b ~ " is " ~ to!string(kerningVector.x) ~ "x" ~ to!string(kerningVector.y));
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
    
    auto fontError = FT_New_Face(lib, "./freesansbold.ttf", 0, &m_face);
    enforce(fontError != FT_Err_Unknown_File_Format, "Error, font format unsupported");
    enforce(fontError == false, "Error loading font file");
    
    FT_Set_Pixel_Sizes(m_face, 32, 32);
  }
  
  
  void renderChar(char p_char, bool p_translate)
  {
    glEnable(GL_TEXTURE_2D);
    
    auto glyph = loadGlyph(p_char);
    
    auto xCoord = cast(float)glyph.bitmap.width / 32.0;
    auto yCoord = cast(float)glyph.bitmap.rows / 32.0;
    
    glBindTexture(GL_TEXTURE_2D, glyph.textureId);

    // translate the glyph so that its 'origin' matches the pen position
    glPushMatrix();
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
      glTranslatef(glyph.advance.x, glyph.advance.y, 0.0);
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
    
    GlyphTexture glyph;

    glyph.data = new GLubyte[4 * glyphWidth * glyphHeight];
    glyph.bitmap = m_face.glyph.bitmap;
    
    glyph.advance = Vector(m_face.glyph.advance.x / (64.0 * 32.0), m_face.glyph.advance.y / (64.0 * 32.0));
    glyph.offset = Vector(m_face.glyph.bitmap_left / 32.0, -(m_face.glyph.bitmap.rows - m_face.glyph.bitmap_top) / 32.0);
    
    auto unalignedGlyph = m_face.glyph.bitmap.buffer;
    
    debug writeln("glyph " ~ p_char ~ 
                  ", buffer is " ~ to!string(m_face.glyph.bitmap.width) ~ "x" ~ to!string(m_face.glyph.bitmap.rows) ~ 
                  ", pitch is " ~ to!string(m_face.glyph.bitmap.pitch) ~ 
                  ", metric is " ~ to!string(m_face.glyph.metrics.width/64) ~ "x" ~ to!string(m_face.glyph.metrics.height/64) ~ 
                  ", horizontal advance is " ~ to!string(m_face.glyph.metrics.horiAdvance/64) ~ 
                  ", bearing is " ~ to!string(m_face.glyph.bitmap_left) ~ "x" ~ to!string(m_face.glyph.bitmap_top));
    
    auto widthOffset = (glyphWidth - m_face.glyph.bitmap.width) / 2;
    auto heightOffset = (glyphHeight - m_face.glyph.bitmap.rows) / 2;
    
    debug writeln("bitmap for " ~ p_char);
    for (int y = 0; y < m_face.glyph.bitmap.rows; y++)
    {
      for (int x = 0; x < m_face.glyph.bitmap.width; x++)
      {
        int coord = 4 * (x + y*glyphHeight);
        
        glyph.data[coord] = unalignedGlyph[x + y*m_face.glyph.bitmap.width];
        
        debug write(glyph.data[coord]>0?(to!string(glyph.data[coord]/26)):".");
      }
      debug write("\n");
    }
    debug writeln("");
    
    glGenTextures(1, &glyph.textureId);
    assert(glyph.textureId > 0, "Failed to generate texture id: " ~ to!string(glGetError()));
    
    glBindTexture(GL_TEXTURE_2D, glyph.textureId);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);	
    glTexImage2D(GL_TEXTURE_2D, 0, 1, glyphWidth, glyphHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, glyph.data.ptr);
    //glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, glyphWidth, glyphHeight, 0, GL_ALPHA, GL_UNSIGNED_BYTE, glyph.data.ptr);
    
    assert(glyph.data.length > 0, "Failed to fill glyph texture");
    
    return glyph;
  }
  

private:
  struct GlyphTexture
  {
    uint textureId;
    FT_Bitmap bitmap;
    
    Vector offset; // offset for this glyph, so for example lowercase 'g' will be drawn slightly lower
    Vector advance; // how much should we move to the right and down when drawing this glyph before another one (when drawing strings)
    
    GLubyte[] data;
  };
  
  
private:
  FT_Face m_face;
  
  GlyphTexture[char] m_glyphs;
};

