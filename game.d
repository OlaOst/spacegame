module Game;

import std.stdio;


unittest
{
  Game game = new Game();

  // TODO: assert that Derelict SDL and GL loaded OK
  
  // assert that game responds to input
  assert(game.hasInput() == false);
  game.receiveInput();
  assert(game.hasInput() == true);

  game.clearInput();
  assert(game.hasInput() == false);
  
  assert(game.updateCount == 0);
  game.update();
  assert(game.updateCount == 1);
}


class Game
{
public:
  this()
  {
    m_hasInput = false;
    m_updateCount = 0;
  }
  
  
private:
  void receiveInput()
  {
    m_hasInput = true;
  }
  
  void clearInput()
  {
    m_hasInput = false;
  }
  
  bool hasInput()
  {
    return m_hasInput;
  }
  
  int updateCount()
  {
    return m_updateCount;
  }
  
  void update()
  {
    m_updateCount++;
  }
  
  
private:
  bool m_hasInput;
  int m_updateCount;
}
