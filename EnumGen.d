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

module EnumGen;


unittest
{
  mixin(genEnum("GenTest", 
  [
  "Default",
  "One", 
  "Two", 
  "Three"
  ]));
  
  GenTest e = GenTest.One;
  
  assert(toString(e) == "One");
  
  assert(GenTestFromString("Two") == GenTest.Two);
  
  assert(toString(GenTestFromString("Two")) == "Two");
  
  assert(GenTestFromString(toString(GenTest.Three)) == GenTest.Three);
  
  // defaults to the first enum value if it isn't found
  assert(GenTestFromString("nosuchenumvalue") == GenTest.Default);
}


pure string genEnum(string name, string[] values)
{
  string enumDef = "enum " ~ name ~ " { ";
  string toStrDef = "string toString(" ~ name ~ " value) { switch (value) {";
  string fromStrDef = name ~ " " ~ name ~ "FromString(string value) { switch (value) {";
  
  foreach (value; values)
  {
    enumDef ~= value ~ ",";
    toStrDef ~= "case " ~ name ~ "." ~ value ~ ": return \"" ~ value ~ "\"; ";
    fromStrDef ~= "case \"" ~ value ~ "\": return " ~ name ~ "." ~ value ~ "; ";
  }
  
  enumDef = enumDef[0..$-1] ~ "}";
  
  toStrDef ~= "} } ";
  fromStrDef ~= "default: return " ~ name ~ "." ~ values[0] ~ "; } } ";
  
  return enumDef ~ "\n" ~ toStrDef ~ "\n" ~ fromStrDef;
}
