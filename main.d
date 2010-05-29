module main;

import std.stdio;

import Game;

int main(char[][] args)
{
  version(unittestsOnly)
  {
    writeln("Checking unittest coverage - not running main program");
  }
  else
  {
    Game game = new Game();
    game.run();
  }
  
  return 0;
}
