/*
 Copyright (c) 2011 Ola Østtveit

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

module Control.ControlBase;

import SubSystem.Controller;


interface ControlInterface
{
  public:
    void update(ref ControlComponent p_sourceComponent);
    /*out  // contract in interface seems to fuck up things. try again with a dmd later than 2.054, crashes in the parallell forloop in game.d
    {
      writeln("control.update in contract");
      
      assert(p_sourceComponent.position.ok);
      
      foreach (otherComponent; p_otherComponents)
      {
        assert(otherComponent.position.ok);
      }
    }*/
}


abstract class ControlBase : ControlInterface
{
  public:
    abstract void update(ref ControlComponent p_sourceComponent);
    bool consoleActive = false; // we want to block player input controls when console is active - we don't want to fire guns when pressing space for example
}