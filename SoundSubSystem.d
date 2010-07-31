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
  this(ALuint p_buffer)
  {
    buffer = p_buffer;
    shouldPlay = false;
  }

  ALuint buffer;
  bool shouldPlay;
}


class SoundSubSystem : public SubSystem!(SoundComponent)
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
  
  void soundOff()
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
  SoundComponent createComponent(Entity p_entity)
  {
    assert(p_entity.getValue("soundFile").length > 0);
    
    auto buffer = alutCreateBufferFromFile(cast(char*)p_entity.getValue("soundFile"));
    
    auto newComponent = new SoundComponent(buffer);
    
    newComponent.shouldPlay = p_entity.getValue("shouldPlay") == "true";
    
    return newComponent;
  }
  
  
private:
  ALuint[] m_sources;
  
  uint m_lastSourcePlayed;
}
