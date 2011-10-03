﻿/*
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

module SubSystem.Sound;

import std.algorithm;
import std.conv;
import std.stdio;

import derelict.openal.al;
import derelict.openal.alut;

import Entity;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new SoundSubSystem(8);
}


class SoundComponent 
{
public:
  this(ALuint p_buffer)
  {
    buffer = p_buffer;
    shouldPlay = false;
  }

  ALuint buffer;
  bool shouldPlay;
}


class SoundSubSystem : public Base!(SoundComponent)
{
invariant()
{
  //assert(alGetError() == AL_NO_ERROR, "error code " ~ to!string(alGetError()));
}


public:
  this(uint p_sources)
  {
    DerelictAL.load();  
    DerelictALUT.load();
    
    alutInit(null, null);
  
    m_sources.length = p_sources;
  
    for (int n = 0; n < p_sources; n++)
    {
      alGenSources(1, &m_sources[n]);
    }
    
    m_lastSourcePlayed = 0;
  }
  
  void update()
  {
    foreach (component; components)
    {
      if (component.shouldPlay)
      {
        alSourcei(m_sources[m_lastSourcePlayed], AL_BUFFER, component.buffer);
        
        //writeln("source " ~ to!string(m_source) ~ " playing buffer " ~ to!string(component.buffer));
        alSourcePlay(m_sources[m_lastSourcePlayed]);

        component.shouldPlay = false;
        
        m_lastSourcePlayed = (m_lastSourcePlayed + 1) % m_sources.length;
      }
    }
  }

protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("soundFile").length > 0;
  }
  
  SoundComponent createComponent(Entity p_entity)
  {
    auto soundFile = p_entity.getValue("soundFile");
    
    if (soundFile.startsWith("data/sounds/") == false)
      soundFile = "data/sounds/" ~ soundFile;
      
    if (soundFile !in m_fileToBuffer)
    {
      m_fileToBuffer[soundFile] = alutCreateBufferFromFile(cast(char*)soundFile);
      assert(alGetError() == AL_NO_ERROR, "error code " ~ to!string(alGetError()));
    }

    auto newComponent = new SoundComponent(m_fileToBuffer[soundFile]);
    
    newComponent.shouldPlay = true;
    
    return newComponent;
  }
  
  
private:
  ALuint[] m_sources;
  
  ALuint[string] m_fileToBuffer;
  
  uint m_lastSourcePlayed;
}
