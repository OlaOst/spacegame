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

module SubSystem;

import std.stdio;

import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  struct MockComponent {}
  
  class MockSubSystem : public SubSystem!(MockComponent)
  {
    protected:
      MockComponent createComponent(Entity p_entity)
      {
        return MockComponent();
      }
  }
  MockSubSystem sys = new MockSubSystem();
  
  Entity entity = new Entity();
  
  assert(sys.components.length == 0);
  {
    sys.registerEntity(entity);
  }
  assert(sys.components.length == 1);  
  assert(sys.findComponents(entity).length == 1);  
  assert(sys.getEntity(sys.findComponents(entity)[0]) == entity);
  
  {
    sys.removeEntity(entity);
  }
  assert(sys.components.length == 0);  
  assert(sys.findComponents(entity).length == 0);
}


abstract class SubSystem(ComponentType)
{
public:
  void registerEntity(Entity p_entity)
  {
    auto component = createComponent(p_entity);
    m_components[component] = p_entity;
  }
  
  void removeEntity(Entity p_entity)
  {
    foreach (ComponentType component; m_components.keys)
      if (m_components[component] == p_entity)
        m_components.remove(component);
  }
  

//protected:
  ComponentType[] findComponents(Entity p_entity)
  {
    // TODO: this could problably be rangified or lambdified
    
    ComponentType[] foundComponents;
    
    foreach (ComponentType component; m_components.keys)
      if (m_components[component] == p_entity)
        foundComponents ~= component;
        
    return foundComponents;
  }
  
protected:
  
  Entity getEntity(ComponentType p_component)
  {
    return m_components[p_component];
  }
  
  abstract ComponentType createComponent(Entity p_entity);
  
  ComponentType[] components()
  {
    return m_components.keys;
  }
  
  
private:
  Entity[ComponentType] m_components;
}