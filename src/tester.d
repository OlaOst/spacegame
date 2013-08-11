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
    foreach (string file; dirEntries("tests/", "test*.txt", SpanMode.shallow))
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

  string fixedFile = file.startsWith("tests/") ? file : "tests/" ~ file;
  
  string[][string] cache;

  auto expected = EntityLoader.loadValues(cache, fixedFile ~ ".expected", "tests/");

  auto testCommand = "rdmd -debug -g -version=integrationtest src/main.d " ~ fixedFile ~ " 1> " ~ fixedFile ~ ".output" ~ " 2> " ~ fixedFile ~ ".error";
  auto testRun = executeShell(testCommand);
  
  enforce(testRun.status == 0, "Failed to run integration test with command:\n" ~ testCommand ~ "\nOutput:\n" ~ readText(fixedFile ~ ".output") ~ "\nError message:\n" ~ readText(fixedFile ~ ".error"));
  
  auto result = EntityLoader.loadValues(cache, fixedFile ~ ".result", "tests/");

  foreach (key, value; expected)
  {
    enforce(key in result, "Did not find expected key in result: " ~ key ~ "\nOutput:\n" ~ readText(fixedFile ~ ".output"));
    enforce(result[key] == value, "Value mismatch: Key " ~ key ~ " expected to be " ~ value ~ ", was " ~ result[key] ~ "\nOutput:\n" ~ readText(fixedFile ~ ".output"));
  }
}

