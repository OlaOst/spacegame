module SubSystem.Spawner;

import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.random;
import std.stdio;

import gl3n.linalg;
import SubSystem.Base;


unittest
{
  scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  auto sys = new Spawner();
  
  Entity spawner = new Entity();
  spawner.setValue("spawns", "bullets");
  
  sys.registerEntity(spawner);
  
  auto spawnComp = sys.getComponent(spawner);
  
  // simulates CommsCentral setting stuff from Placer and Physics subsystems
  spawnComp.position = vec2(0.0, 0.0);
  spawnComp.velocity = vec2(0.0, 0.0);
  spawnComp.angle = 0.0;
  
  // simulates controller subsystem signalling the spawner entity to fire
  spawnComp.isSpawning = true;
  
  sys.setComponent(spawner, spawnComp);
  
  assert(sys.m_spawns.length == 0);
  
  sys.update();

  assert(sys.m_spawns.length > 0);
}

struct SpawnerComponent
{
  Entity spawnBlueprint;
  
  vec2 position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  vec2 force = vec2(0.0, 0.0);
  
  float angle = 0.0;
  float torque = 0.0;
  
  // these are relative
  vec2 spawnPoint = vec2(0.0, 0.0);
  vec2 spawnVelocity = vec2(0.0, 0.0);
  
  float spawnForce = 0.0; // goes in the direction of spawnAngle
  
  float spawnAngle = 0.0;
  float spawnRotation = 0.0;
  
  int entityId;
  int ownerId;
  
  bool isSpawning = false;
}


class Spawner : public Base!(SpawnerComponent)
{
public:
  void update() 
  {
    m_spawns.length = 0;
    
    foreach (ref component; components)
    {
      //writeln("spawner.update: " ~ to!string(component.entityId) ~ ": " ~ to!string(component.isSpawning));
    
      if (component.isSpawning)
      {
        Entity spawn;
        if (component.spawnBlueprint !is null)
        {
          spawn = new Entity(component.spawnBlueprint.values);
        }
        
        auto spawnAngle = component.angle + component.spawnAngle;
        
        assert(component.velocity.ok);
        
        // should be impulse not force... or should it?
        auto spawnForce = vec2.fromAngle(spawnAngle) * component.spawnForce;
        auto spawnVelocity = component.velocity + spawnForce;
        
        // spawning component gets some recoil force
        auto recoilDamping = 0.0;
        auto force = component.force;
        force -= spawnForce * (1.0 - recoilDamping);
        component.force = force;
        
        spawn.setValue("spawnedFrom", to!string(component.entityId));
        spawn.setValue("spawnedFromOwner", to!string(component.ownerId));
        
        spawn.setValue("position", to!string(component.position + component.spawnPoint));
        spawn.setValue("angle", to!string(spawnAngle * (180.0 / PI)));
        
        spawn.setValue("velocity", spawnVelocity.toString());
        spawn.setValue("force", spawnForce.toString());
        
        immutable string[4] sounds = ["mgshot1.wav", "mgshot2.wav", "mgshot3.wav", "mgshot4.wav"];
        
        // we should have two entity spawns here, one for the muzzle flash effect (which also will handle the sound)
        // and another for the actual spawn entity
        spawn.setValue("soundFile", sounds[uniform(0, sounds.length)]);
        //spawn.setValue("soundFile", sounds[0]);
        
        m_spawns ~= spawn;
      }
    }
  }
  
  
  Entity[] getAndClearSpawns()
  out
  {
    assert(m_spawns.length == 0);
  }
  body
  {
    Entity[] tmp = m_spawns;
    
    m_spawns.length = 0;
    
    return tmp;
  }
  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    return (p_entity.getValue("spawnSource").length > 0 ||
            looksLikeAFile(p_entity.getValue("spawnSource")));
  }
  
  
  SpawnerComponent createComponent(Entity p_entity)
  {
    auto component = SpawnerComponent();
    
    if (looksLikeAFile(p_entity.getValue("spawnSource")))
    {
      component.spawnBlueprint = new Entity(p_entity.getValue("spawnSource"));
      component.spawnBlueprint.setValue("name", p_entity.getValue("spawnSource"));
    }
    
    component.entityId = p_entity.id;
    
    if (p_entity.getValue("owner").length > 0)
      component.ownerId = to!int(p_entity.getValue("owner"));
    
    if (p_entity.getValue("spawnPoint").length > 0)
      component.spawnPoint = vec2.fromString(p_entity.getValue("spawnPoint"));
    if (p_entity.getValue("spawnVelocity").length > 0)
      component.spawnVelocity = vec2.fromString(p_entity.getValue("spawnVelocity"));
    
    if (p_entity.getValue("spawnForce").length > 0)
      component.spawnForce = to!float(p_entity.getValue("spawnForce"));
    
    if (p_entity.getValue("spawnAngle").length > 0)
      component.spawnAngle = to!float(p_entity.getValue("spawnAngle")) * (PI / 180.0);
    if (p_entity.getValue("spawnRotation").length > 0)
      component.spawnRotation = to!float(p_entity.getValue("spawnRotation"));
      
    return component;
  }


private:
  bool looksLikeAFile(string p_txt)
  {
    return endsWith(p_txt, ".txt") > 0;
  }
  
  
private:
  Entity[] m_spawns;
}
