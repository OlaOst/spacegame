module InputContext;

import InputHandler;


unittest
{
  // an inputcontext provides mappings from input events to intents
  // for example an engine will listen to a shipcontrol context, which will map Up events to Accelerate intents
  // or a menucontext that will map up/down events to move highlighted line up or down
  InputContext context = new InputContext();
  
  context.addMapping(Event.UpKey, Intent.Accelerate);
  
  assert(context.getIntent(Event.UpKey) == Intent.Accelerate);
  
  assert(context.getIntent(Event.Escape) == Intent.Unspecified);
}


enum Intent
{
  Unspecified,
  
  // ship specific intents
  Accelerate, Decelerate,
  TurnLeft, TurnRight,
  ZoomIn, ZoomOut,
  Fire,
  
  // menu specific intents
  Choose,
  MoveUp, MoveDown, MoveLeft, MoveRight
}

Intent intentFromString(string p_string)
{
  switch (p_string)
  {
    case "Accelerate" : return Intent.Accelerate; break;
    case "Decelerate" : return Intent.Decelerate; break;
    case "TurnLeft" : return Intent.TurnLeft; break;
    case "TurnRight" : return Intent.TurnRight; break;
    case "ZoomIn" : return Intent.ZoomIn; break;
    case "ZoomOut" : return Intent.ZoomOut; break;
    case "Fire" : return Intent.Fire; break;
    case "Choose" : return Intent.Choose; break;
    case "MoveUp" : return Intent.MoveUp; break;
    case "MoveDown" : return Intent.MoveDown; break;
    case "MoveLeft" : return Intent.MoveLeft; break;
    case "MoveRight" : return Intent.MoveRight; break;
  }
}


class InputContext
{
public:
  void addMapping(Event p_event, Intent p_intent)
  {
    m_eventMapping[p_event] = p_intent;
  }
  
  Intent getIntent(Event p_event)
  {
    if (p_event in m_eventMapping)
      return m_eventMapping[p_event];
    else
      return Intent.Unspecified;
  }
  
  
private:
  Intent[Event] m_eventMapping;
}
