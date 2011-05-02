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

module SubSystem.Base;

import std.conv;
import std.stdio;

import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  struct MockComponent { }
  
  class MockSubSystem : public Base!(MockComponent)
  {
    protected:
      bool canCreateComponent(Entity p_entity) { return true; }
      
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
  
  Entity anotherEntity = new Entity();
  sys.registerEntity(anotherEntity);
  assert(sys.components.length == 2);
  
  
  {
    sys.removeEntity(entity);
  }
  assert(sys.components.length == 1);  
  assert(sys.hasComponent(entity) == false);
}


abstract class Base(ComponentType) : public IBase!(ComponentType)
{
public:
  final void registerEntity(Entity p_entity)
  {
    scope(failure) writeln(to!string(this) ~ " failed loading entity: " ~ to!string(p_entity.values));
    
    if (canCreateComponent(p_entity))
    {
      auto component = createComponent(p_entity);
    
      m_entityToComponent[p_entity] = component;
    }
  }
  
  final void removeEntity(Entity p_entity)
  {
    m_entityToComponent.remove(p_entity);
  }
  
  final bool hasComponent(Entity p_entity)
  {
    return (p_entity in m_entityToComponent) !is null;
  }
  
  final ref ComponentType getComponent(Entity p_entity)
  in
  {
    assert(hasComponent(p_entity), "couldn't find component for entity " ~ to!string(p_entity.id) ~ " in " ~ to!string(this));
  }
  body
  {
    return m_entityToComponent[p_entity];
  }
  
  void setComponent(Entity p_entity, ComponentType p_component)
  {
    m_entityToComponent[p_entity] = p_component;
  }  
  
  final ComponentType[] components()
  {
    return m_entityToComponent.values;
  }
  
  final Entity[] entities()
  {
    return m_entityToComponent.keys;
  }
  
  
private:
  ComponentType[Entity] m_entityToComponent;
}


interface IBase(ComponentType)
{
public:
  void registerEntity(Entity p_entity);
  void removeEntity(Entity p_entity);  
  
  bool hasComponent(Entity p_entity);
  ref ComponentType getComponent(Entity p_entity);
  
  ComponentType[] components();
  Entity[] entities();  
  
protected:
  bool canCreateComponent(Entity p_entity);
  ComponentType createComponent(Entity p_entity);
}
