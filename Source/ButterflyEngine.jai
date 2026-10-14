#import "Basic";
#import "Hash_Table";

Event :: struct {
  encounter : Encounter;//Encounter struct is in gamedata.jai
}

Event_Table : Table(*Location, Event);//Location struct is in gamedata.jai

check_grudges :: (loc : Location) {//this gets called on Set_Location and after winning an encounter
  for loc.Characters {
    if it.Grudge {
      Start_Encounter(.{it,"Enemy",sprint("% attacks you. They want revenge because you killed their friend.", it.name) });
      return;
    }
  }
}

axis_sign :: (value: float, dead_zone: float) -> int {
    if value >  dead_zone return  1;
    if value < -dead_zone return -1;
    return 0;
}

reputation_label :: (r : Reputation) -> string {
    DEAD_ZONE :: 0.25;

    c := axis_sign(r.competence, DEAD_ZONE);
    l := axis_sign(r.likeability, DEAD_ZONE);

    if c ==  1 && l ==  1 return "default";//respected
    if c ==  1 && l == -1 return "fear";
    if c == -1 && l ==  1 return "pity";
    if c == -1 && l == -1 return "hate";

    return "default";
}

update_reputation :: (loc : Location, c : float, l : float) {
  for loc.Characters {
    it.reputation.competence  += c;
    it.reputation.likeability += l;
  }
}