module SoundSubSystem;

import std.conv;
import std.stdio;

import derelict.openal.al;
import derelict.openal.alut;

import Entity;
import SubSystem : SubSystem;


unittest
{
  auto sys = new SoundSubSystem();
}


class SoundComponent 
{
public:
}


class SoundSubSystem : public SubSystem!(SoundComponent)
{
invariant()
{
  assert(alGetError() == AL_NO_ERROR);
}


public:
  this()
  {
    DerelictAL.load();
    DerelictALUT.load();
    
    alutInit(null, null);
  
    auto buffer = alutCreateBufferHelloWorld();
      
    assert(alGetError() == AL_NO_ERROR);
  
    //ALuint source;
    alGenSources(1, &source);
    alSourcei(source, AL_BUFFER, buffer);
    
    assert(alGetError() == AL_NO_ERROR);
    
    alSourcePlay(source);
  }
  
  void soundOff()
  {
    //writeln("playing sound source " ~ to!string(source));
    //alSourcePlay(source);
  }
    
protected:
  SoundComponent createComponent(Entity p_entity)
  {
    return new SoundComponent();
  }
  
  
private:
  ALuint source;
}
