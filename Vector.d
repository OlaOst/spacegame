module Vector;

import std.conv;
import std.math;
import std.string;


unittest
{
  Vector left = Vector(1.0, 0.0);
  Vector right = Vector(0.0, 1.0);
  
  assert(left.x == 1.0 && left.y == 0.0);
  assert(right.x == 0.0 && right.y == 1.0);
  
  assert(left.length2d == 1.0 && left.length3d == 1.0);
  assert(right.length2d == 1.0 && right.length3d == 1.0);
  
  assert(left.normalized.length2d == 1.0 && left.normalized.length3d == 1.0);
  assert(right.normalized.length2d == 1.0 && right.normalized.length3d == 1.0);
  
  Vector result = left + right;
  
  assert(result == Vector(1.0, 1.0));
  
  assert(result.normalized.length3d < 1.0001 && result.normalized.length3d > 0.9999, to!string(result.normalized.length3d));
  
  result += right;
  
  assert(result == Vector(1.0, 2.0));
  
  result = result * 2.0;
  
  assert(result == Vector(2.0, 4.0));
  
  assert(result.toString() == "2 4 0", "Vector.toString returned '" ~ result.toString() ~ "', should be '2 4 0'");
  
  
  Vector twodimensional = Vector(1.0, -1.0);
  
  assert(twodimensional.z == 0.0);
  
  Vector fromAngle = Vector.fromAngle(0.0);
  
  assert((fromAngle - Vector.fromAngle(PI*2)).length3d < 0.0001);
  
  Vector wrong = Vector(NaN(0), NaN(0));
  
  assert(wrong.isValid() == false);
  
  auto vectorFromString = Vector.fromString("1 2 3");
  
  assert(vectorFromString.x == 1 && vectorFromString.y == 2 && vectorFromString.z == 3);
}


struct Vector
{
  this(float p_x, float p_y)
  {
    x = p_x;
    y = p_y;
    z = 0.0;
  }
  
  this(float p_x, float p_y, float p_z)
  {
    x = p_x;
    y = p_y;
    z = p_z;
  }
  
  float x, y, z;
    
  Vector opBinary(string s)(Vector p_right) 
  if (s == "+") { return Vector(x + p_right.x, y + p_right.y, z + p_right.z); }
  
  Vector opBinary(string s)(Vector p_right) 
  if (s == "-") { return Vector(x - p_right.x, y - p_right.y, z - p_right.z); }
  
  Vector opBinary(string s)(float p_right) if (s == "*")
  {
    return Vector(x * p_right, y * p_right, z * p_right);
  }
  
  Vector opOpAssign(string s)(Vector p_right) 
  if (s == "+=") { return Vector(x += p_right.x, y += p_right.y, z += p_right.z); }
  
  Vector opOpAssign(string s)(Vector p_right) 
  if (s == "-=") { return Vector(x -= p_right.x, y -= p_right.y, z -= p_right.z); }
  
  Vector opOpAssign(string s)(float p_right) if (s == "*=")
  {
    return Vector(x *= p_right, y *= p_right, z *= p_right);
  }
  
  Vector normalized()
  out (result)
  {
    assert(result.isValid(), toString());
  }
  body
  {
    auto invLen = 1.0 / length3d;
    
    if (invLen < float.infinity)
      return Vector(x*invLen, y*invLen, z*invLen);
    else
      return Vector.origo;
  }  
  
  float length2d()
  {
    return sqrt(x*x + y*y);
  }
  
  float length3d()
  {
    return sqrt(x*x + y*y + z*z);
  }
  
  string toString()
  {
    return to!string(x) ~ " " ~ to!string(y) ~ " " ~ to!string(z);
  }
  
  
  bool isValid() const
  {
    return (x==x && y==y && z==z);
  }
  
  
  static Vector origo = Vector(0.0, 0.0, 0.0);
  
  
  static Vector fromAngle(float p_angle)
  {
    return Vector(cos(p_angle), sin(p_angle));
  }
  
  
  static Vector fromString(string p_values)
  {
    auto values = p_values.split();
    
    if (values.length == 3)
      return Vector(to!float(values[0]), to!float(values[1]), to!float(values[2]));
    else if (values.length == 2)
      return Vector(to!float(values[0]), to!float(values[1]));
      
      
    assert(false, "Vector fromString needs 2 or 3 values, " ~ p_values ~ " can't be parsed as a vector");
  }
}