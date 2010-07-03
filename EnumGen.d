module EnumGen;


unittest
{
  mixin(genEnum("GenTest", 
  [
  "One", 
  "Two", 
  "Three"
  ]));
  
  GenTest e = GenTest.One;
  
  assert(toString(e) == "One");
  
  assert(GenTestFromString("Two") == GenTest.Two);
  
  assert(toString(GenTestFromString("Two")) == "Two");
  
  assert(GenTestFromString(toString(GenTest.Three)) == GenTest.Three);
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
  fromStrDef ~= "} } ";
  
  return enumDef ~ "\n" ~ toStrDef ~ "\n" ~ fromStrDef;
}
