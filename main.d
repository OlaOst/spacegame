module main;

import std.stdio;

import Game;

int main(char[][] args)
{
  bool runOnlyUnittests = false;
  version(D_Coverage)
  {
    version(unittest)
    {
      runOnlyUnittests = true;
      writeln("Checking unittest coverage - not running main program");
    }
  }
  
  if (!runOnlyUnittests)
  {
    Game game = new Game();
    game.run();
  }
  
  return 0;
}
