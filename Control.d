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

module Control;

import Entity;
import ConnectionSubSystem;
import InputHandler;
import Vector : Vector;


unittest
{
  auto connectionSystem = new ConnectionSubSystem(new InputHandler(), new PhysicsSubSystem());
  auto controlComponent = new ConnectionComponent(new Entity());
  
  class MockControl : public Control
  {
  public:
    void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents)
    {
    }
  }
  
  auto controller = new MockControl();
  
  ConnectionComponent[] components = [];
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 0);
  
  components ~= new ConnectionComponent(new Entity());
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  
  auto farAwayComponent = new ConnectionComponent(new Entity());
  
  farAwayComponent.entity.position(Vector(100.0, 100.0));
  components ~= farAwayComponent;
  
  assert(controller.nearbyEntities(controlComponent, components, 10.0).length == 1);
  assert(controller.nearbyEntities(controlComponent, components, 1000.0).length == 2);
}


abstract class Control
{
public:
  abstract void update(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_otherComponents);
  

protected:
  Entity[] nearbyEntities(ConnectionComponent p_sourceComponent, ConnectionComponent[] p_candidateComponents, float p_radius)
  in
  {
    assert(p_radius > 0.0);
  }
  body
  {
    Entity[] inRangeEntities = [];
    foreach (candidateComponent; p_candidateComponents)
    {
      if (candidateComponent != p_sourceComponent && (candidateComponent.entity.position - p_sourceComponent.entity.position).length2d < p_radius)
        inRangeEntities ~= candidateComponent.entity;
    }
    return inRangeEntities;
  }
}