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

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.math;
import std.stdio;

import Entity;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");
  
  struct MockComponent { int uniqueId; }
  
  class MockSubSystem : Base!(MockComponent)
  {
    public:
      void update() {}
      
    protected:
      bool canCreateComponent(Entity p_entity) { return true; }
      
      MockComponent createComponent(Entity p_entity)
      {
        return MockComponent(uniqueComponentId++);
      }
      
    private:
      int uniqueComponentId;
  }
  MockSubSystem sys = new MockSubSystem();
  
  Entity entity = new Entity(["":""]);
  
  assert(sys.components.length == 0);
  {
    sys.registerEntity(entity);
  }
  assert(sys.components.length == 1);
  
  // it shouldn't be possible to double-register the same entity to a system
  sys.registerEntity(entity);
  assert(sys.components.length == 1);
  
  Entity anotherEntity = new Entity(["":""]);
  sys.registerEntity(anotherEntity);
  assert(sys.components.length == 2, "Expected 2 components after registering a second one, got " ~ to!string(sys.components.length) ~ " instead");
  
  assert(sys.components[0] != sys.components[1]);
  
  assert(sys.components[0] == sys.getComponent(entity));
  assert(sys.components[1] == sys.getComponent(anotherEntity));
  
  {
    sys.removeEntity(entity);
  }
  assert(sys.components.length == 1);
  assert(sys.hasComponent(entity) == false);
  
  
  sys.update();
  assert(sys.components.length == 1);
  
  sys.update();
  assert(sys.components.length == 1);
}


abstract class Base(ComponentType) : SubSystem, ComponentFactory!(ComponentType)
{
invariant()
{
  //assert(m_componentArray.length == m_entityToComponent.length, "component array length is " ~ to!string(m_componentArray.length) ~ ", differs from entityToComponent length: " ~ to!string(m_entityToComponent.length));
  
  //auto sortedEntities = sort!((left, right) { return left.id < right.id; })(m_entityToComponent.keys);
  
  /*int index = 0;
  foreach (Entity entity; sortedEntities)
  {
    assert(m_entityToComponent[entity] == m_componentArray[index]);
    
  }*/
  
  //assert(m_componentArray == sort!((left, right) { return left.id < right.id; })(m_entityToComponent.keys));
}


public:
  void registerEntity(Entity p_entity)
  {
    scope(failure) writeln(to!string(this) ~ " failed loading entity: " ~ to!string(p_entity.values));
    
    // if the entity is already registered, the component will be overwritten
    if (canCreateComponent(p_entity))
    {
      auto component = createComponent(p_entity);
        
      m_entityToComponent[p_entity] = component;
      
      //writeln("registering entity " ~ to!string(p_entity.id) ~ " on " ~ name());
    }
    
    //assert(m_componentArray == array(map!((entity) { return m_entityToComponent[entity]; })(sort!((left, right) { return left.id < right.id; })(m_entityToComponent.keys))));
  }
  
  void removeEntity(Entity p_entity)
  {
    if (p_entity !in m_entityToComponent)
      return;
    
    auto componentToRemove = m_entityToComponent[p_entity];
    
    m_entityToComponent.remove(p_entity);
  }
  
  final bool hasComponent(Entity p_entity)
  {
    return (p_entity in m_entityToComponent) !is null;
  }
  
  final ComponentType getComponent(Entity p_entity) 
  in
  {
    assert(p_entity in m_entityToComponent, "Could not find component for entity " ~ p_entity.getValue("name") ~ " with id " ~ to!string(p_entity.id) ~ " in " ~ to!string(this));
  }
  body
  {
    assert(p_entity in m_entityToComponent, "Could not find component for entity " ~ p_entity.getValue("name") ~ " with id " ~ to!string(p_entity.id) ~ " in " ~ to!string(this));
    return m_entityToComponent[p_entity];
  }
  
  final void setComponent(Entity p_entity, ComponentType p_component)
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

  @property final string name()
  {
    return this.classinfo.name;
  }
  
  void updateWithTiming()
  {
    m_timer.reset();
    m_timer.start();
    
    update();
    
    m_timer.stop();
    
    auto timeSpent = m_timer.peek.usecs / 1_000_000.0;
    assert(isFinite(timeSpent));
    m_timeSpentBuffer[(m_updateCount++) % m_timeSpentBuffer.length] = timeSpent;
  }
  
  float timeSpent()
  {
    auto avgTime = reduce!"a+b"(m_timeSpentBuffer)/m_timeSpentBuffer.length;
    
    assert(isFinite(avgTime), "avg subsystem time not finite, buffer is " ~ to!string(m_timeSpentBuffer));
    
    return avgTime;
  }
  
  override string debugInfo(float subSystemTime)
  {
    return to!string(components.length) ~ " components, " ~ to!string(roundTo!int((timeSpent/subSystemTime) * 100)) ~ "%";
  }
  
  void clearEntities()
  {
    m_entityToComponent = null;
  }
  
public:
  float[60] m_timeSpentBuffer = 0.0;
  
private:
  int m_updateCount = 0;
  
  StopWatch m_timer;
  
  ComponentType[Entity] m_entityToComponent;
}


interface ComponentFactory(ComponentType)
{
public:
  bool hasComponent(Entity p_entity);
  ComponentType getComponent(Entity p_entity);
  
  ComponentType[] components();
  
protected:
  bool canCreateComponent(Entity p_entity);
  ComponentType createComponent(Entity p_entity);
}


interface SubSystem
{
 public:
  void registerEntity(Entity p_entity);
  void removeEntity(Entity p_entity);  
  
  bool hasComponent(Entity p_entity);
  
  void update();
  void updateWithTiming();
  float timeSpent();
  
  string name();
  
  string debugInfo(float subSystemTime);
  
  void clearEntities();
}


// used in CommsCentral to set up how sub systems communicate with each other.
// for example when the physics system needs to tell the placer system the newly calculated positions
void subSystemCommunication(ReadComponent, WriteComponent)(Base!(ReadComponent) read, Base!(WriteComponent) write, WriteComponent delegate(ReadComponent, WriteComponent) componentTransform)
{
  foreach (ref entity; read.entities)
  {
    if (read.hasComponent(entity) && write.hasComponent(entity))
    {
      auto readComponent = read.getComponent(entity);
      auto writeComponent = write.getComponent(entity);
      
      auto newComponent = componentTransform(readComponent, writeComponent);
      
      write.setComponent(entity, newComponent);
    }
  }
}
