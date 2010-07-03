module Vector;

import std.conv;
import std.math;


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
  
  assert(result.normalized.length3d == 1.0);
  
  result += right;
  
  assert(result == Vector(1.0, 2.0));
  
  result = result * 2.0;
  
  assert(result == Vector(2.0, 4.0));
  
  assert(result.toString() == "2 4 0", "Vector.toString returned '" ~ result.toString() ~ "', should be '2 4 0'");
  
  
  Vector twodimensional = Vector(1.0, -1.0);
  
  assert(twodimensional.z == 0.0);
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
  {
    auto invLen = 1.0 /length3d;
    return Vector(x*invLen, y*invLen, z*invLen);
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
  
  static Vector origo = Vector(0.0, 0.0, 0.0);
}