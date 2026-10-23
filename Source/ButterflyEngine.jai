#import "Basic";
#import "Hash_Table";
#import "Math";

// Event :: struct {
//   encounter : Encounter;//Encounter struct is in gamedata.jai
// }

Memory :: struct {
  action    : string;//kill,lose,run,destroy
  target    : *Character;//who or what
  location  : string;
  witnessed : bool;
  delta     : Vector2;//likeability and competence
}

MemoryCounter :: struct {//count together similar events
  count   : int;
  latest  : Memory;//maybe this can be the 5 latest?
  delta   : Vector2;//agregate delta of all past memories
  time    : int;//when last recorder to check recency againts CurrentTime
  mentioned : bool;//if already mentioned no need to do it again
}

//Event_Table : Table(*Location, Event);//Location struct is in gamedata.jai

check_grudges :: (loc : Location) {//this gets called on Set_Location and after winning an encounter
  for loc.Characters {
    if it.Grudge {
      Start_Encounter(.{it,sprint("% attacks you. They want revenge because you killed their friend.", it.name) });
      return;
    }
  }
}

axis_sign :: (value: float, dead_zone: float) -> int {
    if value >  dead_zone return  1;
    if value < -dead_zone return -1;
    return 0;
}

reputation_label :: (r : Vector2) -> string {//need the neutral edge zones
    DEAD_ZONE :: 0.25;

    c := axis_sign(r.x, DEAD_ZONE);
    l := axis_sign(r.x, DEAD_ZONE);

    if c ==  1 && l ==  1 return "respect";//respected
    if c == 0 && l == 0 return "default";
    if c ==  1 && l <= 0 return "fear";
    if c < 0 && l ==  1 return "pity";
    if c <= 0 && l < 0 return "hate";

    return "default";
}

update_reputation :: () {
  for CurrentLocation.Characters {
    char := it;
    for CurrentSceneMem {
      Character_reputation_add(char, it);
    }
  }
  fresh : [..] Memory;
  CurrentSceneMem = fresh;
}

add_to_scene :: (act : string, targ : *Character, loc : Location, wit : bool, c : float, l : float) {//records memory to current scene
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

  array_add(*CurrentSceneMem, mem);
}

calculate_reputation_change :: (char : Character, mem : Memory)-> Vector2 {
  //add a check if we harmed or helped the person

  //default harmed/ did something bad
  //check if friends
  friend : int;
  if array_find(char.Acquaintances, mem.target) friend = 1;

  l := mem.delta.x;
  c := mem.delta.y;

  if friend == 1 && char.friendship > 0 {
    //ignore morality and scale based on friendship
    //after lerping vvm l might = c
    if l >= 0 l = l*-char.friendship;//if l is positive scale with negative friendship
    else l -= abs(l)*char.friendship;

  } else {
    //if 0 friendship or not a friend, apply morality
    l *= char.morality;

    if char.virtue_vs_might < 0 l = lerp(l, c, -char.virtue_vs_might);
    if char.virtue_vs_might > 0 c = lerp(c, l, char.virtue_vs_might);
  }

  l *= char.reactivity.x;
  c *= char.reactivity.y;

  return .{l,c};
}

Character_reputation_add :: (char : *Character, mem : Memory) {
  memo := mem;
  
  //calculate relative contextual perception
  memo.delta = calculate_reputation_change(char,mem);

  char.reputation.likeability = clamp(char.reputation.likeability + memo.delta.x, -1, 1);
  char.reputation.competence = clamp(char.reputation.competence + memo.delta.y, -1, 1);

  character_remember(char, memo);//tries to remember if big enough
}

character_remember :: (char : *Character, mem : Memory) {
  obj := find_or_add(*char.memcounter, mem.action);
  obj.count += 1;
  obj.latest = mem;
  obj.delta += mem.delta;
  obj.time = CurrentTime;
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

 character_recall :: (char : Character) -> bool, *MemoryCounter {
  rep : Vector2;
  rep.x = char.reputation.likeability;
  rep.y = char.reputation.competence;
  rep = normalize(rep);

  HighDelta := 0.0;
  chosen : *MemoryCounter;
  success : bool;

  for *char.memory {
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

 calculate_temp_reputation :: (char : Character) -> Vector2 {
  v : Vector2;
  for CurrentSceneMem {
    v += calculate_reputation_change(char, it);
  }

  v += .{char.reputation.likeability, char.reputation.competence};

  return v;
 }

 recall_currentscene :: (char : Character, tempdelta : Vector2) -> bool, MemoryCounter {
  temp : Table(string, MemoryCounter);
  

  for CurrentSceneMem {
    obj := find_or_add(*temp, it.action);
    obj.count += 1;
    obj.latest = it;
    obj.delta += calculate_reputation_change(char, it);
    obj.time = CurrentTime;
  }

  HighDelta := 0.0;
  chosen : MemoryCounter;
  success : bool;
  rep := normalize(tempdelta);

  for temp {
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