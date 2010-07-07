module Timer;

import core.thread;
import std.conv;
import std.perf;


unittest
{
  Timer timer = new Timer();
  
  assert(timer.elapsedTime == 0.0);
  
  timer.start();
  Thread.sleep(50_000); // sleep 5 ms
  timer.stop();
  
  assert(timer.elapsedTime > 0.0049, "Timer reported too short time: " ~ to!string(timer.elapsedTime) ~ " seconds after sleeping 5 ms");
  assert(timer.elapsedTime < 0.01, "Timer reported too long time: " ~ to!string(timer.elapsedTime) ~ " seconds after sleeping 5 ms");
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