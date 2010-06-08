module Vector;

import std.conv;
import std.math;


unittest
{
  Vector left = { 1.0, 0.0, 0.0 };
  Vector right = { 0.0, 1.0, 0.0 };
  
  Vector result = left + right;
  
  assert(result == Vector(1.0, 1.0, 0.0));
  
  result += right;
  
  assert(result == Vector(1.0, 2.0, 0.0));
  
  result = result * 2.0;
  
  assert(result == Vector(2.0, 4.0, 0.0));
  
  assert(result.toString() == "2 4 0", "Vector.toString returned '" ~ result.toString() ~ "', should be '2 4 0'");
}


struct Vector
{
  float x, y, z;
    
  Vector opBinary(string s)(Vector p_right) if (s == "+")
  {
    return Vector(x + p_right.x, y + p_right.y, z+ p_right.z);
  }
  
  Vector opBinary(string s)(float p_right) if (s == "*")
  {
    return Vector(x * p_right, y * p_right, z * p_right);
  }
  
  Vector opOpAssign(string s)(Vector p_right) if (s == "+=")
  {
    return Vector(x += p_right.x, y += p_right.y, z += p_right.z);
  }
  
  Vector opOpAssign(string s)(float p_right) if (s == "*=")
  {
    return Vector(x *= p_right, y *= p_right, z *= p_right);
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
  
  static Vector origo = { x:0.0, y:0.0, z:0.0 };
}