module SubSystem.Spawner;

import std.algorithm;
import std.conv;
import std.exception;
import std.math;
import std.random;
import std.stdio;

import gl3n.math;
import gl3n.linalg;

import Entity;

import SubSystem.Base;


unittest
{
  //scope(success) writeln(__FILE__ ~ " unittests succeeded");
  scope(failure) writeln(__FILE__ ~ " unittests failed");

  auto sys = new Spawner();
  
  Entity spawner = new Entity(["spawn.bullets.source":"type=bullets"]);
  
  sys.registerEntity(spawner);
  
  assert(sys.hasComponent(spawner));
  
  auto spawnComp = sys.getComponent(spawner);
  
  // simulates CommsCentral setting stuff from Placer and Physics subsystems
  spawnComp.position = vec2(0.0, 0.0);
  spawnComp.velocity = vec2(0.0, 0.0);
  spawnComp.angle = 0.0;
  
  // simulates controller subsystem signalling the spawner entity to fire
  spawnComp.isSpawning = true;
  
  sys.setComponent(spawner, spawnComp);
  
  assert(sys.m_spawnValues.length == 0);
  
  sys.update();

  assert(sys.m_spawnValues.length > 0);
}

struct SpawnerComponent
{
  //Entity spawnBlueprint;
  string[string][string] spawnValuesNames; // we can have multiple spawns, each with a name : spawnName[spawnKey] = spawnValue
  float[string] timeSinceLastSpawn;
  
  vec2 position = vec2(0.0, 0.0);
  vec2 velocity = vec2(0.0, 0.0);
  vec2 force = vec2(0.0, 0.0);
  
  float angle = 0.0;
  float torque = 0.0;
  
  // these are relative
  //vec2 spawnPoint = vec2(0.0, 0.0);
  //vec2 spawnVelocity = vec2(0.0, 0.0);
  
  //float spawnForce = 0.0; // goes in the direction of spawnAngle
  
  //float spawnAngle = 0.0;
  //string spawnAngle = "0.0";
  //float spawnRotation = 0.0;
  
  int entityId;
  int ownerId;
  
  bool startSpawning = false;
  bool isSpawning = false;
  bool stopSpawning = false;
}


class Spawner : Base!(SpawnerComponent)
{
public:

  void update() 
  {
    m_spawnValues.length = 0;
    
    //foreach (ref component; components)
    foreach (ref component; entityToComponent.byValue())
    {
      //writeln("spawner.update: " ~ to!string(component.entityId) ~ ": " ~ to!string(component.isSpawning));
      
      foreach (spawnName, spawnValuesOriginal; component.spawnValuesNames)
      {
        component.timeSinceLastSpawn[spawnName] += m_timeStep;
        
        if ((component.isSpawning && ("trigger" !in spawnValuesOriginal || spawnValuesOriginal["trigger"] == "isSpawning")) ||
            (component.startSpawning && "trigger" in spawnValuesOriginal && spawnValuesOriginal["trigger"] == "startSpawning") ||
            (component.stopSpawning && "trigger" in spawnValuesOriginal && spawnValuesOriginal["trigger"] == "stopSpawning"))
        {
          if ("spawnsPerSecond" in spawnValuesOriginal && component.timeSinceLastSpawn[spawnName] < 1.0 / spawnValuesOriginal["spawnsPerSecond"].to!float)
            continue;
        
          component.timeSinceLastSpawn[spawnName] = 0.0;
        
          string[string] spawnValues = spawnValuesOriginal.dup;

          float spawnAngle = component.angle;
          /*if (component.spawnAngle.find("to").length > 0)
          {
            auto angleData = component.spawnAngle.split(" ");
            
            assert(angleData.length == 3, "Problem parsing angle data with from/to values: " ~ to!string(angleData));
            
            auto fromAngle = to!float(angleData[0]);
            auto toAngle = to!float(angleData[2]);
            
            spawnAngle += uniform(fromAngle, toAngle);
          }
          else
          {
            spawnAngle += to!float(component.spawnAngle);
          }*/
          
          //auto spawnAngle = component.angle + component.spawnAngle;
          
          assert(component.velocity.ok);
          
          // should be impulse not force... or should it?
          //auto spawnForce = vec2.fromAngle(spawnAngle) * component.spawnForce;
          //auto spawnVelocity = component.velocity + spawnForce;
          
          vec2 spawnForce = vec2(0.0, 0.0);
          if ("spawnForce" in spawnValues)
            spawnForce = mat2.rotation(-spawnAngle) * vec2(0.0, 1.0) * to!float(spawnValues["spawnForce"]);
            
          auto spawnVelocity = component.velocity + spawnForce;
          
          // spawning component gets some recoil force
          //auto recoilDamping = 0.0;
          //auto force = component.force;
          //force -= spawnForce * (1.0 - recoilDamping);
          //component.force = force;
          
          spawnValues["spawnedFrom"] = to!string(component.entityId);
          spawnValues["spawnedFromOwner"] = to!string(component.ownerId);
          
          spawnValues["*.spawnedFrom"] = to!string(component.entityId);
          spawnValues["*.spawnedFromOwner"] = to!string(component.ownerId);

          if ("position" in spawnValues)
            spawnValues["position"] = to!string(spawnValues["position"]);
          else if ("spawnPoint" in spawnValues)
            spawnValues["position"] = (component.position + mat2.rotation(-component.angle) * vec2(spawnValues["spawnPoint"].to!(float[])[0..2])).to!string;
          else
            spawnValues["position"] = component.position.to!string;
          
          if ("angle" !in spawnValues)
            spawnValues["angle"] = to!string(spawnAngle * _180_PI);
          
          spawnValues["velocity"] = spawnVelocity.toString();
          spawnValues["force"] = spawnForce.toString();
          
          spawnValues["name"] = spawnName;
          
          m_spawnValues ~= spawnValues;
        }
      }
    }
  }
  
  
  string[string][] getAndClearSpawnValues()
  out
  {
    assert(m_spawnValues.length == 0);
  }
  body
  {
    string[string][] tmp = m_spawnValues;
    
    m_spawnValues.length = 0;
    
    return tmp;
  }

  void setTimeStep(float p_timeStep)
  {
    m_timeStep = p_timeStep;
  }  
  
protected:
  bool canCreateComponent(Entity p_entity)
  {
    auto spawnKeys = filter!(key => key.startsWith("spawn."))(p_entity.values.keys);
    
    return spawnKeys.empty == false;
  }
  
  
  SpawnerComponent createComponent(Entity p_entity)
  {
    auto component = SpawnerComponent();
    
    foreach (key, value; p_entity.values)
    {
      string originalKey = key;
      
      if (key.skipOver("spawn."))
      {
        enforce(key.find(".").length > 0, "Missing spawn name for " ~ originalKey ~ ", spawn values must be on the form spawn.<spawnname>.<spawnkey>");
        
        string spawnName = to!string(key.until("."));
        
        //if (spawnName == "*")
          //continue;
        
        enforce(key.skipOver(spawnName ~ "."), "Could not parse spawn value for " ~ originalKey ~ ", spawn values must be on the form spawn.<spawnname>.<spawnkey>");
        
        component.spawnValuesNames[spawnName][key] = value;
        component.timeSinceLastSpawn[spawnName] = float.infinity;
        
        //writeln("spawnname " ~ spawnName ~ " setting key " ~ key ~ " to value " ~ value);
      }
    }
    
    if ("*" in component.spawnValuesNames)
    {
      foreach (spawnName; component.spawnValuesNames.keys.filter!(name => name != "*"))
      {
        foreach (wildcardKey, wildcardValue; component.spawnValuesNames["*"])
        {
          if (wildcardKey !in component.spawnValuesNames[spawnName])
          {
            //debug writeln("setting " ~ wildcardKey ~ " to " ~ wildcardValue ~ " in " ~ spawnName);
            component.spawnValuesNames[spawnName][wildcardKey] = wildcardValue;
          }
        }
      }
      
      component.spawnValuesNames.remove("*");
    }
    
    component.entityId = p_entity.id;
    
    if (p_entity.getValue("owner").length > 0)
      component.ownerId = to!int(p_entity.getValue("owner"));

    return component;
  }  

  void updateEntity(Entity entity)
  {
    if (hasComponent(entity))
    {
      auto component = getComponent(entity);
    }
  }
  

private:
  bool looksLikeAFile(string p_txt)
  {
    return endsWith(p_txt, ".txt") > 0;
  }
  
  
private:
  string[string][] m_spawnValues;
  
  float m_timeStep = 0.0;
}
