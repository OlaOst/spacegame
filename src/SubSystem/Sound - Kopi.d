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
  }

  ALuint buffer;
  bool shouldStartPlaying = false;
  bool isPlaying = false;
  bool isMusic = false;
}


class SoundSubSystem : Base!(SoundComponent)
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
  
    m_musicSources.length = 3;
    for (int n = 0; n < m_musicSources.length; n++)
      alGenSources(1, &m_musicSources[n]);
  
    m_sources.length = p_sources - m_musicSources.length;
    for (int n = 0; n < p_sources - m_musicSources.length; n++)
      alGenSources(1, &m_sources[n]);
    
    m_lastSourcePlayed = 0;
  }
  
  void update()
  {
    foreach (component; components)
    {
      if (component.shouldStartPlaying)
      {
        ALuint source;
        
        if (component.isMusic)
          source = m_musicSources[0];
        else
          source = m_sources[m_lastSourcePlayed];
        
        alSourcei(source, AL_BUFFER, component.buffer);
        alSourcePlay(source);

        component.shouldStartPlaying = false;
        component.isPlaying = true;
        
        if (component.isMusic == false)
          m_lastSourcePlayed = (m_lastSourcePlayed + 1) % m_sources.length;
      }
      
      if (component.isPlaying)
      {
        if (component.isMusic)
        {
          ALint state;
          alGetSourcei(m_musicSources[0], AL_SOURCE_STATE, &state);
          
          if (state == AL_STOPPED)
            component.shouldStartPlaying = true;
        }
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
      if (soundFile.find(".ogg") != [])
      {
        byte[] buffer;
        ALenum format;
        ALsizei frequency;
        
        loadOgg(soundFile, buffer, format, frequency);
        
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
    
    auto newComponent = new SoundComponent(m_fileToBuffer[soundFile]);
    
    newComponent.shouldStartPlaying = true;
    
    if ("isMusic" in p_entity.values)
      newComponent.isMusic = true;
    
    return newComponent;
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
    
    writeln("loading ogg file with playback time " ~ to!string(ov_time_total(&oggFile, -1) * 1.0) ~ " seconds");
    
    for (int bytesRead = ov_read(&oggFile, array.ptr, array.length, endian, 2, 1, &bitStream); 
             bytesRead > 0; 
             bytesRead = ov_read(&oggFile, array.ptr, array.length, endian, 2, 1, &bitStream))
    {
      buffer ~= array[0..bytesRead];
    } 
    
    //ov_clear(&oggFile);
  }
  
  
  //void streamOgg(ALuint buffer, OggVorbis_File oggFile)
  void fillBuffer(OggVorbis_File oggFile, ref byte[] buffer, uint offset)
  {
    int size = 0;
    int bytesRead;
    
    int endian = 0;       // 0 for Little-Endian, 1 for Big-Endian
    int bitStream;
    byte[32768] array;    // Local fixed size array
    
    while (size < m_streamBufferSize)
    {
      //result = ov_read(&oggFile, data + size, m_streamBufferSize - size, endian, 2, 1, &bitStream);
      bytesRead = ov_read(&oggFile, array.ptr + size, m_streamBufferSize - size, endian, 2, 1, &bitStream);
      
      if (bytesRead > 0)
      {
        size += bytesRead;
      }
      else
      {
        if (bytesRead < 0) 
          return;
        else
          break;
      }
    }
    
    if (size == 0)
    {
      //bActive = false;
      return;
    }
    
    //alBufferData(streamBufferId, format, array.ptr, size, frequency);
  }
  

private:
  ALuint[] m_sources;
  ALuint[] m_musicSources;
  
  ALuint[string] m_fileToBuffer;
  
  uint m_lastSourcePlayed;
  
  immutable int m_streamBufferSize = 65536;
}


class Stream
{
  immutable int streamBufferSize = 32768;
  
  File file;
  File.ByChunk fileChunks;
  
  int format;
  int frequency;
  
  uint[3] bufferList;
  
  this(string fileName)
  {
    file = File(fileName);
    fileChunks = file.byChunk(streamBufferSize);
    
    foreach (ref buffer; bufferList)
    {
      alGenBuffers(1, &buffer);
    }
  }
  
  void play()
  {
    // find the buffer we want to play
    //bufferIndex = (bufferIndex + 1) % bufferList.length;
    
    // find an available source
    uint sourceId = 0; // TODO: should probably not be 0
    alSourcei(sourceId, AL_BUFFER, 0);
    
    foreach (buffer; bufferList)
    {
      loadNextStreamingBufferForSound(buffer);
      
      alSourceQueueBuffers(sourceId, 1, &buffer);
      
      auto error = alGetError();
      enforce(error == 0);
    }
    
    //alSourcef(sourceId, AL_PITCH, pitch);
    //alSourcef(sourceId, AL_GAIN, gain);
    
    alSourcei(sourceId, AL_LOOPING, AL_FALSE);
    
    alSourcePlay(sourceId);
  }
  
  void loadNextStreamingBufferForSound(uint buffer)
  {
    int fileSize;
    int bufferIndex;
    
    //OggVorbis_File oggFile;
    
    //ov_open(file.getFP(), &oggFile, null, 0);
    
    ulong totalChunks = file.size / streamBufferSize;
    
    if (bufferIndex > totalChunks)
      return;
      
    uint startOffset = bufferIndex * streamBufferSize;
    
    /*if (bufferIndex == totalChunks)
    {
      int leftOverBytes = file.size - (streamBufferSize * totalChunks);
      bufferSize = leftOverBytes;
    }*/
    
    // chunk should be ubyte[]
    auto chunk = fileChunks.front;
    fileChunks.popFront();
    
    if (chunk.empty)
      return;
 
    //alBufferData(bufferId, format, buffer.ptr, buffer.length, frequency); 
    alBufferData(buffer, format, chunk, streamBufferSize, frequency);
  }
}