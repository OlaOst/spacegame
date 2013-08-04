module tester;

import std.conv;
import std.exception;
import std.file;
import std.process;
import std.stdio;
import std.string;

import EntityLoader;


void main(string args[])
{
  if (args.length == 1)
  {
    foreach (string file; dirEntries("data/tests/", "*.txt", SpanMode.shallow))
    {
      runTest(file);
    }
  }
  else
  {
    runTest(args[1]);
  }
}


void runTest(string file)
{
  scope(failure) writeln(file ~ " failed");

  string[][string] cache;

  auto expected = EntityLoader.loadValues(cache, file ~ ".expected");

  auto testrun = executeShell("rdmd -debug -g -version=integrationtest src/main.d " ~ file ~ " 1> " ~ file ~ ".output");
  
  //enforce(testrun.status == 0, "Failed to run integration test: " ~ testrun.output);
  enforce(testrun.status == 0, "Failed to run integration test: " ~ readText(file ~ ".output"));
  
  auto result = EntityLoader.loadValues(cache, file ~ ".result");

  foreach (key, value; expected)
  {
    enforce(key in result, "Did not find expected key in result: " ~ key);
    enforce(result[key] == value, "Value mismatch: Key " ~ key ~ " expected to be " ~ value ~ ", was " ~ result[key]);
  }
}
