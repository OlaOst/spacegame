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

import std.stdio;

import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  //struct MockComponent {}
  
  class MockSubSystem : public Base!(int)
  {
    private:
      int createComponent(Entity p_entity)
      {
        return 0;
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


class Base(ComponentType) : public IBase!(ComponentType, Entity[ComponentType])
{
  public final void registerEntity(Entity p_entity)
  {
    IregisterEntity(p_entity, m_store);
  }
  
  public final void removeEntity(Entity p_entity)
  {
    IremoveEntity(p_entity, m_store);
  }
  
  public final ComponentType[] findComponents(Entity p_entity)
  {
    // TODO: this could probably be rangified or lambdified
    
    ComponentType[] foundComponents;
    
    foreach (ComponentType component; m_store.keys)
      if (m_store[component] == p_entity)
        foundComponents ~= component;

    return foundComponents;
  }
  
  public final Entity getEntity(ComponentType p_component)
  {
    return m_store[p_component];
  }
  
  protected final ComponentType[] components()
  {
    return m_store.keys;
  }
  
  private Entity[ComponentType] m_store;
}


interface IBase(ComponentType, ComponentStore)
{
public:
  final void IregisterEntity(Entity p_entity, ComponentStore p_store)
  {
    auto component = createComponent(p_entity);
    p_store[component] = p_entity;
  }
  
  final void IremoveEntity(Entity p_entity, ComponentStore p_store)
  {
    foreach (ComponentType component; p_store.keys)
      if (p_store[component] == p_entity)
        p_store.remove(component);
  }
  
  ComponentType[] findComponents(Entity p_entity);
  
protected: 
  Entity getEntity(ComponentType p_component);  
  ComponentType[] components();

private:
  ComponentType createComponent(Entity p_entity);
}