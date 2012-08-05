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

module SubSystem.Sound;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;

import derelict.ogg.ogg;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;
import derelict.openal.al;
import derelict.openal.alut;

import gl3n.linalg;
import gl3n.math;

import AudioStream;
import Entity;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  auto sys = new Sound(8);
}


class SoundComponent 
{
public:
  this(ALuint p_buffer)
  {
    buffer = p_buffer;
  }
  
  this(AudioStream p_stream)
  {
    stream = p_stream;
  }

  ALuint buffer;
  bool shouldStartPlaying = false;
  bool isPlaying = false;
  bool finishedPlaying = false;
  
  bool repeat = false;
  
  bool streaming = false;
  AudioStream stream = null;
  
  vec2 position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  float angle = 0.0;
}


class Sound : Base!(SoundComponent)
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
    DerelictOgg.load();
    DerelictVorbis.load();
    DerelictVorbisFile.load();
    
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
    auto centerComponent = new SoundComponent(-1);
    assert(centerComponent.position.ok);
    
    if (hasComponent(m_centerEntity))
    {
      centerComponent = getComponent(m_centerEntity);
      assert(centerComponent.position.ok);
    }
    
    alListener3f(AL_POSITION, centerComponent.position.x, centerComponent.position.y, 0.0);
    alListener3f(AL_VELOCITY, centerComponent.velocity.x, centerComponent.velocity.y, 0.0);
    
    //writeln("shouldstartplaying: " ~ to!string(filter!(c => c.shouldStartPlaying)(components).array.length));
    //writeln("isplaying:          " ~ to!string(filter!(c => c.isPlaying)(components).array.length));
    //writeln("finishedplaying:    " ~ to!string(filter!(c => c.finishedPlaying)(components).array.length));
    
    foreach (component; components)
    {
      if (component.stream !is null)
      {
        if (component.isPlaying == false)
        {
          component.isPlaying = true;
          component.stream.startPlaybackThread();
        }
      }
      else if (component.shouldStartPlaying)
      {
        ALuint source;
        
        source = m_sources[(m_lastSourcePlayed++) % m_sources.length];
        
        // hold on - did we just grab a source in the process of playing?
        // in that case we should set finishedPlaying on the soundcomponent that was already playing in that source
        // so that the soundcomponent can be cleaned up properly
        if (source in m_sourceToComponent)
        {
          //if (m_sourceToComponent[source].isPlaying)
            m_sourceToComponent[source].finishedPlaying = true;
        }
        
        alSource3f(source, AL_POSITION, component.position.x, component.position.y, 0.0);
        alSource3f(source, AL_VELOCITY, component.velocity.x, component.velocity.y, 0.0);
        
        //alSourcef(source, AL_GAIN, 0.1);
        
        // we need to check if this source is playing
        ALenum state;
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        
        if (state != AL_PLAYING)
        {
          alSourcei(source, AL_BUFFER, component.buffer);
          
          if (component.repeat)
            alSourcei(source, AL_LOOPING, AL_TRUE);
          
          alSourcePlay(source);
          
          component.shouldStartPlaying = false;
          component.isPlaying = true;
          
          m_componentToSource[component] = source;
          m_sourceToComponent[source] = component;
        }
        else
        {
          component.shouldStartPlaying = false;
          component.isPlaying = false;
        }
      }
      else if (component in m_componentToSource) //if (component.isPlaying)
      {
        auto source = m_componentToSource[component];
        
        ALenum state;
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        
        if (state != AL_PLAYING)
        {
          /*if (component.repeat)
          {
            alSourceRewind(source);
            component.shouldStartPlaying = true;
          }
          else*/
          {
            component.finishedPlaying = true;
          }
        }
      }
      else if (component.shouldStartPlaying == false && component.isPlaying == false && component.finishedPlaying == false)
      {
        component.finishedPlaying = true;
      }
    }
  }
  
  Entity[] getFinishedPlayingEntities()
  {
    return filter!(entity => entity != m_centerEntity && getComponent(entity).finishedPlaying)(entities).array;
  }
  

protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("soundFile").length > 0 ||
           p_entity.getValue("keepInCenter").length > 0;
  }
  
  SoundComponent createComponent(Entity p_entity)
  {
    if (p_entity.getValue("keepInCenter") == "true")
    {
      m_centerEntity = p_entity;
      
      if ("soundFile" !in p_entity.values)
      {
        return new SoundComponent(-1);
      }
    }
      
    auto soundFile = p_entity.getValue("soundFile");
    
    if (soundFile.startsWith("data/sounds/") == false)
      soundFile = "data/sounds/" ~ soundFile;

    if ("streaming" in p_entity.values)
    {
      return new SoundComponent(new AudioStream(soundFile));
    }
    else if (soundFile !in m_fileToBuffer)
    {
      if (soundFile.find(".ogg") != [])
      {
        byte[] buffer;
        ALenum format;
        ALsizei frequency;
        
        loadOgg(soundFile, buffer, format, frequency);
        
        enforce(buffer.length < 4194304, "Soundfile buffer too big, try setting 'streaming = true' to play it");
        
        //writeln("read in " ~ to!string(buffer.length) ~ " bytes from oggfile " ~ soundFile);
        
        ALuint bufferId;
        alGenBuffers(1, &bufferId);
        
        alBufferData(bufferId, format, buffer.ptr, buffer.length, frequency);
        
        m_fileToBuffer[soundFile] = bufferId;
      }
      else if (soundFile.find(".wav") != [])
      {
        m_fileToBuffer[soundFile] = alutCreateBufferFromFile(cast(char*)soundFile);
      }
      
      enforce(alGetError() == AL_NO_ERROR, "error code " ~ to!string(alGetError()));
    }

    assert(soundFile in m_fileToBuffer);
    
    auto component = new SoundComponent(m_fileToBuffer[soundFile]);
    
    if ("position" in p_entity.values)
      component.position = vec2.fromString(p_entity.getValue("position"));
    if ("velocity" in p_entity.values)
      component.velocity = vec2.fromString(p_entity.getValue("velocity"));
    if ("angle" in p_entity.values)
      component.angle = to!float(p_entity.getValue("angle")) * PI_180;
    
    if ("repeat" in p_entity.values)
      component.repeat = p_entity.getValue("repeat") == "true";
    
    component.shouldStartPlaying = true;
    
    return component;
  }
  
  
private:
  void loadOgg(string fileName, ref byte[] buffer, ref ALenum format, ref ALsizei frequency)
  {
    File file = File(fileName);
    
    OggVorbis_File oggFile;
    
    ov_open(file.getFP(), &oggFile, null, 0);
    
    // get some info about the ogg file
    auto info = ov_info(&oggFile, -1);
    
    //writeln("ogg file info: " ~ to!string(*info));
    
    if (info.channels == 1)
      format = AL_FORMAT_MONO16;
    else
      format = AL_FORMAT_STEREO16;
      
    frequency = info.rate;
    

    int endian = 0;       // 0 for Little-Endian, 1 for Big-Endian
    int bitStream;
    byte[32768] array;    // Local fixed size array
    
    for (int bytesRead = ov_read(&oggFile, array.ptr, array.length, endian, 2, 1, &bitStream); 
             bytesRead > 0; 
             bytesRead = ov_read(&oggFile, array.ptr, array.length, endian, 2, 1, &bitStream))
    {
      buffer ~= array[0..bytesRead];
    } 
    
    //ov_clear(&oggFile);
  }
  

private:
  ALuint[] m_sources;
  ALuint[SoundComponent] m_componentToSource;
  SoundComponent[ALuint] m_sourceToComponent;
  
  ALuint[string] m_fileToBuffer;
  
  uint m_lastSourcePlayed;
  
  Entity m_centerEntity;
}
