module InputContext;

import InputHandler;
import EnumGen;


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


mixin(genEnum("Intent", 
[
  "Unspecified",
  
  // ship specific intents
  "Accelerate", "Decelerate",
  "TurnLeft", "TurnRight",
  "ZoomIn", "ZoomOut",
  "Fire",
  
  // menu specific intents
  "Choose",
  "MoveUp", "MoveDown", "MoveLeft", "MoveRight"
]));


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
