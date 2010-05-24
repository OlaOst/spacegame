module Game;

import std.stdio;


unittest
{
  writeln("game unittests starting");
  
  Game game = new Game();

  // TODO: assert that Derelict SDL and GL loaded OK
  
  // assert that game responds to input
  assert(game.hasInput() == false);
  game.receiveInput();
  assert(game.hasInput() == true);

  writeln("game unittests finished");
}


class Game
{
public:
  this()
  {
    m_hasInput = false;
  }
  
private:
  void receiveInput()
  {
    m_hasInput = true;
  }
  
  bool hasInput()
  {
    return m_hasInput;
  }
  
private:
  bool m_hasInput;
}
