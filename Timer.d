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

module Timer;

import core.thread;
import std.conv;
import std.perf;


unittest
{
  Timer timer = new Timer();
  
  assert(timer.elapsedTime == 0.0);
  
  timer.start();
  Thread.sleep(100_000); // sleep 10 ms (lower causes isse with too low sleep time, probably multiprocessor issue)
  timer.stop();
  
  assert(timer.elapsedTime > 0.0099, "Timer reported too short time: " ~ to!string(timer.elapsedTime) ~ " seconds after sleeping 10 ms");
  assert(timer.elapsedTime < 0.015, "Timer reported too long time: " ~ to!string(timer.elapsedTime) ~ " seconds after sleeping 10 ms");
}


class Timer
{
invariant()
{
  assert(m_elapsedTime == m_elapsedTime);
}

public:
  this()
  {
    m_counter = new PerformanceCounter();
    m_elapsedTime = 0.0;
  }
  
  
  float elapsedTime()
  in
  {
    assert(m_isRunning == false, "Must stop timer before querying time");
  }
  body
  {
    return m_elapsedTime;
  }
  
  void start()
  in
  {
    assert(m_isRunning == false, "Must stop timer before starting it");
  }
  body
  {
    m_isRunning = true;
    m_counter.start();
  }
  
  void stop()
  in
  {
    //assert(m_isRunning == true, "Must start timer before stopping it");
  }
  body
  {
    m_counter.stop();
    m_elapsedTime = m_counter.microseconds * (1.0/1_000_000.0);
    
    m_isRunning = false;
  }
  
  
private:
  float m_elapsedTime;
  
  bool m_isRunning;
  
  PerformanceCounter m_counter;
}