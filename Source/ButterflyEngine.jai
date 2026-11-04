#import "Basic";
#import "Hash_Table";
#import "Math";

// Event :: struct {
//   encounter : Encounter;//Encounter struct is in gamedata.jai
// }

Memory :: struct {
  action    : string;//attack
  outcome   : string;//kill,lose,run,destroy
  target    : *Character;//who or what
  location  : string;
  witnessed : bool;
  delta     : Reputation;//likeability, competence, favor
}

MemoryCounter :: struct {//count together similar events
  count   : int;
  latest  : Memory;//maybe this can be the 5 latest?
  delta   : Reputation;//agregate delta of all past memories
  time    : int;//when last recorder to check recency againts CurrentTime
  mentioned : bool;//if already mentioned no need to do it again
}

//Event_Table : Table(*Location, Event);//Location struct is in gamedata.jai

check_grudges :: (loc : Location) {//this gets called on Set_Location and after winning an encounter
  chars : [..] Participant;
  for loc.Characters {
    if it.Grudge array_add(*chars, .{it, 1, true, .ALIVE});
  }
  if chars.count > 0 {
    enc := New(Encounter);
    name : string;
    if chars.count < 2 name = sprint("% attacks you",chars[0].char.name);
    else if same_jobs(chars) name = sprint("% %s attack you", chars.count, chars[0].char.Role);
    else name = "Some people attack you";
    enc.* = .{"attack",chars,sprint("%. They want revenge because you killed their friend.", name)};
    Start_Encounter(enc);
    //should action be attack when someone else attacks?
    return;
  }
}

same_jobs :: (arr : [] Participant) -> bool {
  first := arr[0].char.Role;
  for arr {
    if it.char.Role != first return false;
  }
  return true;
}

axis_sign :: (value: float, dead_zone: float) -> int {
    if value >  dead_zone return  1;
    if value < -dead_zone return -1;
    return 0;
}

reputation_label :: (r : Reputation) -> string {//need the neutral edge zones
    //print("like:%\ncomp:%\n",r.x,r.y);
    DEAD_ZONE :: 0.25;

    c := axis_sign(r.y, DEAD_ZONE);
    l := axis_sign(r.x, DEAD_ZONE);

    if c ==  1 && l ==  1 return "respect";//respected
    if c == 0 && l == 0 return "default";
    if c ==  1 && l <= 0 return "fear";
    if c < 0 && l ==  1 return "pity";
    if c <= 0 && l < 0 return "hate";

    return "default";
}

clear_scene_reputation :: () {//we already memorized in add_to_scene so just clear
  // for CurrentLocation.Characters {
  //   char := it;
  //   for CurrentSceneMem {
  //     Character_reputation_add(char, it);
  //   }
  // }
  fresh : [..] Memory;
  CurrentSceneMem = fresh;
}

add_to_scene :: (act : string, out : string, targ : *Character, loc : *Location, wit : bool, c : float, l : float) {//records memory to current scene
  delta : Reputation;
  delta.x = l;
  delta.y = c;

  mem : Memory = .{
    action = act,
    outcome = out,
    target = targ,
    location = loc.name,
    witnessed = wit,
    delta = delta
  };

  array_add(*CurrentSceneMem, mem);

  chars := loc.Characters;
  if CurrentEncounter {//add characters in encounters. we could make an argument that NPCs that are in an encounter are too busy to notice what you did
    for CurrentEncounter.Characters {
      array_add(*chars, it.char);
    }
  }

  for chars {//character tries to remember
    Character_reputation_add(it, mem);
  }
}

calculate_reputation_change :: (char : *Character, mem : Memory)-> Reputation {
  //add a check if we harmed or helped the person

  //default harmed/ did something bad
  //check if friends
  friend : int;
  //print("friend found:%\n",array_find(char.Acquaintances, mem.target));
  if array_find(char.Acquaintances, mem.target) || char.name == mem.target.name friend = 1;//is friend or self
  inencounter : bool;
  self : *Participant;//can use this to check if self

  exist2 , targ := get_participant(mem.target);
  if CurrentEncounter {
    inencounter, self = get_participant(char);
    if inencounter {
      if self.side > 0 {//if not neutral
        if exist2 {
          if self.side == targ.side friend = 1;
          else friend = -1;
        }
      } else friend = 0;
    } else {//check for enemy of friend
      found : bool;
      acq : *Participant;
      for char.Acquaintances {
        found, acq = get_participant(it);
        if found break; 
      }
      if found && exist2 {
        if acq.side == targ.side friend = 1;
        else friend = -1;
      }
    }
  }

  l := mem.delta.x;//likeability
  c := mem.delta.y;//competence
  f := mem.delta.z;//favor

  BASE :: 0.3;
  good_sign : float;

  //likeability--------------------------------//
  lbase : float;
  if mem.action == {
    case "hit";
    good_sign = -1;
    //if friend != 0 l = lbase * friend;
    //else l = lbase;//set to default for now but set to chaos later

    case "gift";
    good_sign = 1;
    
    case "run";
    l = -0.3;
  }
  //if friend != 0 

  //good_term = good_sign * char.alignment.x;
  //calculate chaos here// order_term = order_sign * char.alignment.y;
  //l = BASE*good_term;// + BASE*order_term
//crazy math ---------------------------------//
  k :float;
  m := char.alignment.x;
  r := friend;
  A := BASE * good_sign;

  if m == 1 || self {//if ghandi
    l = A;
  } else if m > 0.5 {//if above average
    //
  } else { // everyone else
    if m > 0 k = (1+r)/2.0;
    else k = 1;

    l = max(A*m*k,A*(1+2*r));//add chaos to this later
  }

  //competence--------------------------------//
  cbase : float;
  if mem.outcome == {
    case "defeat";//defeat the enemy
    cbase = 0.3;

    case "lose";//lose to the enemy
    cbase = -0.3;

    case "kill";//kill the enemy
    cbase = 0.3;

    case "run";//run from the enemy
    cbase = -0.3;
  }

  c = cbase;

  //favor--------------------------------//
  fbase : float;
  if mem.action == {
    case "hit";
    fbase = -0.3;
    if friend != 0 f = fbase * friend;
    else f = 0;

    case "run";
    f = 0;
  }
  
  if char.alignment.z < 0 l = lerp(l, c, -char.alignment.z);
  if char.alignment.z > 0 c = lerp(c, l, char.alignment.z);


  /*
  if friend == 1 && char.friendship > 0 {
    //ignore morality and scale based on friendship
    //after lerping vvm l might = c
    //if this is a friend we need to apply favor
    if mem.outcome == "kill" || mem.outcome == "defeat" f = -0.3;
    else f = 0.3;//owe the player for saving friend

    if l >= 0 l = l*-char.friendship;//if l is positive scale with negative friendship
    else l -= abs(l)*char.friendship;

  } else if friend == -1 { //enemy
    if inencounter {//if helped in a fight Todo: make this a single calculation
      if mem.outcome == "kill" || mem.outcome == "defeat" f = 0.3;
      else f = -0.3;//despise player for helping enemy
    } else l *= -1;
  } else {
    //if 0 friendship or not a friend, apply morality(change this to check chaos)
    l *= char.morality;

    if char.virtue_vs_might < 0 l = lerp(l, c, -char.virtue_vs_might);
    if char.virtue_vs_might > 0 c = lerp(c, l, char.virtue_vs_might);
  }*/

  l *= char.reactivity.x;
  c *= char.reactivity.y;

  return .{l,c,f};
}

Character_reputation_add :: (char : *Character, mem : Memory) {
  memo := mem;
  
  //calculate relative contextual perception
  memo.delta = calculate_reputation_change(char,mem);

  char.reputation.x = clamp(char.reputation.x + memo.delta.x, -1, 1);
  char.reputation.y = clamp(char.reputation.y + memo.delta.y, -1, 1);
  char.reputation.z = clamp(char.reputation.z + memo.delta.z, -1, 1);

  character_remember(char, memo);//tries to remember if big enough
}

character_remember :: (char : *Character, mem : Memory) {
  obj := find_or_add(*char.memcounter, mem.outcome);
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

score_delta :: (v : Reputation) -> float {
  return abs(v.x) + abs(v.y) + abs(v.z);
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
  rep := char.reputation;
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

//  calculate_temp_reputation :: (char : *Character) -> Reputation {
//   v : Vector3;
//   for CurrentSceneMem {
//     v += calculate_reputation_change(char, it);
//   }

//   v += char.reputation;

//   return v;
//  }

//  recall_currentscene :: (char : Character, tempdelta : Reputation) -> bool, MemoryCounter {
//   temp : Table(string, MemoryCounter);
  

//   for CurrentSceneMem {
//     obj := find_or_add(*temp, it.outcome);
//     obj.count += 1;
//     obj.latest = it;
//     obj.delta += calculate_reputation_change(char, it);
//     obj.time = CurrentTime;
//   }

//   HighDelta := 0.0;
//   chosen : MemoryCounter;
//   success : bool;
//   rep := normalize(tempdelta);

//   for temp {
//     dot := dot_product(rep,it.delta);
//     //print("%\n",dot);
//     if dot >= HighDelta && dot > 0.0 {
//     HighDelta = dot;
//     chosen = it;
//     success = true;
//     }
//   }

//   return success, chosen;
//  }