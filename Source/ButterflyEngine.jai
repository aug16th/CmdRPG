#import "Basic";
#import "Hash_Table";

Event :: struct {
  encounter : Encounter;//Encounter struct is in gamedata.jai
}

Event_Table : Table(*Location, Event);//Location struct is in gamedata.jai

check_grudges :: (loc : Location) {
  for loc.Characters {
    if it.Grudge {
      Start_Encounter(.{it,"Enemy",sprint("% attacks you. They want revenge because you killed their friend.", it.name) });
      return;
    }
  }
}