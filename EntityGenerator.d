/*
 Copyright (c) 2012 Ola Øttveit

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

module EntityGenerator;

import std.conv;
import std.math;
import std.random;
import std.stdio;


int counter = 0;
string[] connectpoints = ["upperleft","upperright","lowerleft","lowerright"];


string[] createStation()
{
  string[] values;
  
  values ~= "position = -1 -1";
  
  values ~= "root.source = stationplate.txt";
  
  values ~= createStationPart("root", 8);
  
  return values;
}

string[] createStationPart(string parent, int depth)
{
  string[] values;
  
  if (depth <= 0)
    return values;
  
  foreach (connectpoint; randomSample(connectpoints, dice(0.0, 1.0, 0.5, 0.25, 0.125)))
  {
    int armLength = uniform(1,10);
    
    for (int i = 0; i < armLength; i++)
    {
      string childId = to!string(counter++);
      values ~= childId ~ ".source = stationplate.txt";    
      values ~= childId ~ ".connection = " ~ parent ~  "." ~ connectpoint;
      
      parent = childId;
    }
    
    values ~= createStationPart(parent, depth-1);
  }
  
  return values;
}
