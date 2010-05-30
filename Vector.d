module Vector;

import std.conv;
import std.math;


unittest
{
  Vector left = { 1.0, 0.0 };
  Vector right = { 0.0, 1.0 };
  
  Vector result = left + right;
  
  assert(result == Vector(1.0, 1.0));
  
  result += right;
  
  assert(result == Vector(1.0, 2.0));
  
  result = result * 2.0;
  
  assert(result == Vector(2.0, 4.0));
  
  assert(result.toString() == "2 4", "Vector.toString returned '" ~ result.toString() ~ "', should be '2 4'");
}


struct Vector
{
  float x, y;
    
  Vector opBinary(string s)(Vector p_right) if (s == "+")
  {
    return Vector(x + p_right.x, y + p_right.y);
  }
  
  Vector opBinary(string s)(float p_right) if (s == "*")
  {
    return Vector(x * p_right, y * p_right);
  }
  
  Vector opOpAssign(string s)(Vector p_right) if (s == "+=")
  {
    return Vector(x += p_right.x, y += p_right.y);
  }
  
  Vector opOpAssign(string s)(float p_right) if (s == "*=")
  {
    return Vector(x *= p_right, y *= p_right);
  }
  
  float length()
  {
    return sqrt(x*x + y*y);
  }
  
  string toString()
  {
    return to!string(x) ~ " " ~ to!string(y);
  }
  
  static Vector origo = { x:0.0, y:0.0 };
}