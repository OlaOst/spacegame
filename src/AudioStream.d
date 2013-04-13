/*
 Copyright (c) 2012 Ola Østtveit

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

module AudioStream;

import std.algorithm;
import std.conv;
import std.exception;
import std.parallelism;
import std.stdio;

import derelict.ogg.ogg;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;
import derelict.openal.al;
import derelict.openal.alut;


// this code made possible by http://devmaster.net/posts/openal-lesson-8-oggvorbis-streaming-using-the-source-queue

unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  // first initialize openal and oggvorbis
  DerelictAL.load();  
  DerelictALUT.load();
  DerelictOgg.load();
  DerelictVorbis.load();
  DerelictVorbisFile.load();
  
  alutInit(null, null);  
  
  auto stream = new AudioStream("data/sounds/orbitalelevator.ogg");
  
  //stream.printInfo();
  
  // this will continue playing until ctrl-c
  /*while (stream.update())
  {
    if (stream.playing() == false)
    {
      enforce(stream.playback(), "Ogg abruptly stopped");
      
      writeln("Ogg stream interrupted");
    }
  }*/
}


class AudioStream
{
public:
  this(string filename)
  in
  {
    // TODO: assert that openal and ogg libraries are loaded
  }
  body
  {
    file = File(filename);
    auto result = ov_open(file.getFP(), &oggFile, null, 0);
    
    enforce(result == 0, "Error opening Ogg stream: " ~ to!string(result));
    
    info = *ov_info(&oggFile, -1);
    comment = *ov_comment(&oggFile, -1);
    
    format = (info.channels == 1) ? AL_FORMAT_MONO16 : AL_FORMAT_STEREO16;
    
    alGenBuffers(buffers.length, buffers.ptr);
    check();
    
    alGenSources(1, &source);
    check();
  }
  
  void startPlaybackThread()
  {
    auto playbackTask = task(&this.playbackLoop);
    
    playbackTask.executeInNewThread();
  }
  
  void printInfo()
  {
    writeln("version:         " ~ to!string(info._version));
    writeln("channels:        " ~ to!string(info.channels));
    writeln("rate (hz):       " ~ to!string(info.rate));
    writeln("bitrate upper:   " ~ to!string(info.bitrate_upper));
    writeln("bitrate nominal: " ~ to!string(info.bitrate_nominal));
    writeln("bitrate lower:   " ~ to!string(info.bitrate_lower));
    writeln("bitrate window:  " ~ to!string(info.bitrate_window));
    writeln("vendor:          " ~ to!string(comment.vendor));
    
    writeln("comments: ");
    for (int i = 0; i < comment.comments; i++)
    {
      writeln("  " ~ to!string(comment.user_comments[i]));
    }
  }
  
  
private:
  void playbackLoop()
  {
    while (update())
    {
      if (playing() == false)
      {
        enforce(playback(), "Ogg abruptly stopped");
        
        //writeln("Ogg stream interrupted");
      }
    }
  }
  
  bool playback()
  {
    if (playing())
      return true;
    
    foreach (buffer; buffers)
    {
      if (stream(buffer) == false)
        return false;
    }
    
    alSourceQueueBuffers(source, buffers.length, buffers.ptr);
    alSourcePlay(source);
    
    return true;
  }
  
  bool playing()
  {
    ALenum state;
    alGetSourcei(source, AL_SOURCE_STATE, &state);
    
    return state == AL_PLAYING;
  }
    
  bool update()
  {
    int buffersProcessed;
    bool active = true;
    
    alGetSourcei(source, AL_BUFFERS_PROCESSED, &buffersProcessed);
    
    while (buffersProcessed--)
    {
      ALuint buffer;
      
      alSourceUnqueueBuffers(source, 1, &buffer);
      check();
      
      active = stream(buffer);
      
      alSourceQueueBuffers(source, 1, &buffer);
      check();
    }
    
    return active;
  }
  
  bool stream(ALuint buffer)
  {
    int size = 0;
    int section;
    int bytesRead;
    
    byte[bufferSize] data;
    
    while (size < bufferSize)
    {
      bytesRead = ov_read(&oggFile, data.ptr + size, bufferSize - size, 0, 2, 1, &section);
      
      enforce(bytesRead >= 0, "Error streaming Ogg file: " ~ to!string(bytesRead));
      
      if (bytesRead > 0)
        size += bytesRead;
      else
        break;
    }
    
    if (size == 0)
      return false;
      
    alBufferData(buffer, format, data.ptr, size, info.rate);
    check();
    
    return true;
  }
  
  void check()
  {
    int error = alGetError();
    enforce(error == AL_NO_ERROR, "OpenAL error " ~ to!string(error));
  }
  
  
private:
  immutable int bufferSize = 32768;

  File file;
  OggVorbis_File oggFile;
  
  vorbis_info info;
  vorbis_comment comment;

  ALenum format;
 
  ALuint[3] buffers;
  ALuint source;
}
