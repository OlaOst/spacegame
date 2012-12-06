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

module SubSystem.Timer;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.stdio;

import SubSystem.Base;


class TimerComponent
{
  float lifetime = float.infinity;
}


class Timer : Base!(TimerComponent)
{
public:
  this()
  {
    m_totalTime = 0.0;
    m_elapsedTime = 0.001;
    
    m_timer.reset();
    m_timer.start();
    m_timer.stop();
  }
  
  @property float totalTime()
  {
    return m_totalTime;
  }
  
  @property float elapsedTime()
  {
    assert(m_elapsedTime > 0.0);
    return m_elapsedTime;
  }
  
  void update() 
  {
    m_timer.stop();
    
    m_elapsedTime = m_timer.peek.msecs * 0.001;
    m_totalTime += m_elapsedTime;
    
    if (m_elapsedTime <= 0)
      m_elapsedTime = 0.001;
    
    m_timer.reset();
    m_timer.start();
    
    foreach (ref component; components)
    {
      component.lifetime -= m_elapsedTime;
    }
  }
  
  Entity[] getTimeoutEntities()
  {
    return filter!(entity => getComponent(entity).lifetime <= 0.0)(entities).array;
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return p_entity.getValue("lifetime").length > 0;
  }
  
  TimerComponent createComponent(Entity p_entity)
  {
    auto component = new TimerComponent();
      
    if (p_entity.getValue("lifetime").length > 0)
      component.lifetime = to!float(p_entity.getValue("lifetime"));
      
    //writeln("timer registered " ~ p_entity["name"] ~ " with lifetime " ~ component.lifetime.to!string);
      
    return component;
  }
  
  
private:
  float m_totalTime;
  float m_elapsedTime;
  
  StopWatch m_timer;
}
