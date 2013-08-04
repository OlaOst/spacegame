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
  auto testrun = executeShell("rdmd -debug -g -version=integrationtest src/main.d data/tests/testkinetics.txt 1> data/tests/testkinetics.txt.output");
  
  enforce(testrun.status == 0, "Failed to run integration test: " ~ testrun.output);
  
  string[][string] cache;
  
  auto result = EntityLoader.loadValues(cache, "data/tests/testkinetics.txt.result");
  auto expected = EntityLoader.loadValues(cache, "data/tests/testkinetics.txt.expected");

  foreach (key, value; expected)
  {
    enforce(key in result, "Did not find expected key in result: " ~ key);
    enforce(result[key] == value, "Value mismatch: Key " ~ key ~ " expected to be " ~ value ~ ", was " ~ result[key]);
  }
}
