module SubSystem.Spawner;

import std.conv;
import std.exception;
import std.math;
import std.random;
import std.stdio;

import common.Vector;
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
  spawnComp.position = Vector.origo;
  spawnComp.velocity = Vector.origo;
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
  Entity spawn;
  
  Vector position = Vector.origo;
  Vector velocity = Vector.origo;
  Vector force = Vector.origo;
  
  float angle = 0.0;
  float torque = 0.0;
  
  // these are relative
  Vector spawnPoint = Vector.origo;
  Vector spawnVelocity = Vector.origo;
  
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
      if (component.isSpawning)
      {
        Entity bullet = new Entity();

        bullet.setValue("drawsource", "Bullet");
        bullet.setValue("collisionType", "Bullet");
        bullet.setValue("radius", "0.1");
        bullet.setValue("mass", "0.2");
        
        auto spawnAngle = component.angle + component.spawnAngle;
        
        assert(component.velocity.isValid());
        
        // should be impulse not force
        auto spawnForce = Vector.fromAngle(spawnAngle) * component.spawnForce;
        auto spawnVelocity = component.velocity + spawnForce;
        
        // spawning component gets some recoil force
        auto recoilDamping = 0.0;
        auto force = component.force;
        force -= spawnForce * (1.0 - recoilDamping);
        component.force = force;
        
        bullet.setValue("spawnedFrom", to!string(component.entityId));
        bullet.setValue("spawnedFromOwner", to!string(component.ownerId));
        
        bullet.setValue("position", to!string(component.position + component.spawnPoint));
        bullet.setValue("angle", to!string(spawnAngle));
        
        bullet.setValue("velocity", spawnVelocity.toString());
        bullet.setValue("force", spawnForce.toString());
        
        bullet.setValue("lifetime", "5.0");
        
        immutable string[4] sounds = ["mgshot1.wav", "mgshot2.wav", "mgshot3.wav", "mgshot4.wav"];
        
        // we should have two entity spawns here, one for the muzzle flash effect (which also will handle the sound)
        // and another for the actual bullet entity
        
        bullet.setValue("soundFile", sounds[uniform(0, sounds.length)]);
        //bullet.setValue("soundFile", sounds[0]);
        
        m_spawns ~= bullet;
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
    return p_entity.getValue("spawns").length > 0;
  }
  
  
  SpawnerComponent createComponent(Entity p_entity)
  {
    auto component = SpawnerComponent();
    
    enforce(p_entity.getValue("spawns") == "bullets", "Spawner subsystem only knows how to spawn bullets, not " ~ p_entity.getValue("spawns"));
    
    component.entityId = p_entity.id;
    
    if (p_entity.getValue("owner").length > 0)
      component.ownerId = to!int(p_entity.getValue("owner"));
    
    if (p_entity.getValue("spawnPoint").length > 0)
      component.spawnPoint = Vector.fromString(p_entity.getValue("spawnPoint"));
    if (p_entity.getValue("spawnVelocity").length > 0)
      component.spawnVelocity = Vector.fromString(p_entity.getValue("spawnVelocity"));
    
    if (p_entity.getValue("spawnForce").length > 0)
      component.spawnForce = to!float(p_entity.getValue("spawnForce"));
    
    if (p_entity.getValue("spawnAngle").length > 0)
      component.spawnAngle = to!float(p_entity.getValue("spawnAngle"));
    if (p_entity.getValue("spawnRotation").length > 0)
      component.spawnRotation = to!float(p_entity.getValue("spawnRotation"));
      
    return component;
  }

private:
  Entity[] m_spawns;
}
