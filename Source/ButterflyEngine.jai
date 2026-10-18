#import "Basic";
#import "Hash_Table";
#import "Math";

Event :: struct {
  encounter : Encounter;//Encounter struct is in gamedata.jai
}

Memory :: struct {
  action    : string;//kill,lose,run,destroy
  target    : string;//who or what
  location  : string;
  witnessed : bool;
  delta     : Vector2;//likeability and competence
}

MemoryCounter :: struct {//count together similar events
  count   : int;
  latest  : Memory;//maybe this can be the 5 latest?
  delta   : Vector2;//agregate delta of all past memories
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

reputation_label :: (r : Reputation) -> string {//need the neutral edge zones
    DEAD_ZONE :: 0.25;

    c := axis_sign(r.competence, DEAD_ZONE);
    l := axis_sign(r.likeability, DEAD_ZONE);

    if c ==  1 && l ==  1 return "default";//respected
    if c ==  1 && l < 0 return "fear";
    if c < 0 && l ==  1 return "pity";
    if c < 0 && l < 0 return "hate";

    return "default";
}

update_reputation :: (act : string, targ : string, loc : Location, wit : bool, c : float, l : float) {
  delta : Vector2;
  delta.x = l;
  delta.y = c;

  mem : Memory = .{
    action = act,
    target = targ,
    location = loc.name,
    witnessed = wit,
    delta = delta
  };
  
  for loc.Characters {
    it.reputation.competence  += c;
    it.reputation.likeability += l;
    character_remember(it, mem);//tries to remeber if big enough.
  }
}

character_remember :: (char : *Character, mem : Memory) {
  obj := find_or_add(*char.memcounter, mem.action);
  obj.count += 1;
  obj.latest = mem;
  obj. delta += mem.delta;
  deltascore := score_delta(obj.delta);
  i := get_lowest_delta_index(char.memory);
  lowscore := score_delta(char.memory[i].delta);
  if deltascore >= lowscore {
  char.memory[i] = obj;
  //print("% will remember this\n", char.name);
  }
}

score_delta :: (v : Vector2) -> float {
  return abs(v.x) + abs(v.y);
}

get_lowest_delta_index :: (arr : [] MemoryCounter) -> int {
  lowest := 100.0;
  i : int = -1;
  for arr {
    score := score_delta(it.delta);
    if score < lowest {
      lowest = score;
      i = it_index;
    }
  }
  return i;
 }

 get_highest_delta_index :: (arr : [] Memory) -> int {
  highest := 0.0;
  i : int = -1;
  for arr {
    score := score_delta(it.delta);
    if score > highest {
      highest = score;
      i = it_index;
    }
  }
  return i;
 }

 character_recall :: (char : Character) -> bool, MemoryCounter {
  rep : Vector2;
  rep.x = char.reputation.likeability;
  rep.y = char.reputation.competence;
  rep = normalize(rep);

  HighDelta := 0.0;
  chosen : MemoryCounter;
  success : bool;

  for char.memory {
    dot := dot_product(rep,it.delta);
    //print("%\n",dot);
    if dot >= HighDelta && dot > 0.0 {
    HighDelta = dot;
    chosen = it;
    success = true;
    }
  }

  return success, chosen;
 }