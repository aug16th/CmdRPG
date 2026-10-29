#import "Basic";
#import "Windows";

#load   "gamedata.jai";//data structs and loading
#load   "ButterflyEngine.jai";//this needs gamedata.jai
#load   "DialogueGenerator.jai";
#load   "random lib.jai";//randomization functions


State :: enum {
  WORLD;
  AREA;
  LOCATION;
  INTERACT;
  ENCOUNTER;
}

//Current Vars--------------------------------------------------------------//
KnownAreas : [] *Area;
CurrentState : State;
CurrentArea : *Area;
CurrentLocation : *Location;
CurrentInteract : *Interactable;
CurrentEncounter: *Encounter;
CurrentTime : int;
CurrentSceneMem : [..] Memory;

Add_Area :: (a : *Area){
  temparr : [..] *Area;
  if !array_find(KnownAreas, a){//check if area already known
    for KnownAreas{
        array_add(*temparr, it);
    }
    array_add(*temparr, a);
    KnownAreas = temparr;
  } //else print("\narea already known\n",);
}

Add_Location :: (a : *Area, l : *Location){
  if !array_find(a.Locations, l){
    temparr : [..] *Location;
    for a.Locations {
      array_add(*temparr, it);
    }
    array_add(*temparr, l);
    a.Locations = temparr;
  } //else print("\nlocation already known\n",);
}

Add_Interactable_To_Location :: (l : *Location, i : Interactable){
  result : [..] Interactable;
  for l.Interactables {
    array_add(*result, it);
  }
  array_add(*result, i);
  l.Interactables = result;
}

Start_Encounter :: (e : *Encounter){
  CurrentEncounter = e;
  CurrentState = .ENCOUNTER;
}

Set_Location :: (loc : *Location){
  CurrentState = .LOCATION;
  CurrentLocation = loc;
  check_grudges(loc);
  CurrentTime += 1;
}

main :: () {
  init_random_seed();//creates a random seed
  init_commands();   // now generated automatically from every @GameCommand-tagged proc

  config, config_success := read_entire_file("Data/Config.ini");

  if !config_success {
        print("Error: Could not read the config file!\n");
        return;
  }

  //right now config order is hardcoded
  gameconfig := trim(split(config, "\n")[0], " \t\r");
  dialogueconfig := trim(split(config, "\n")[1], " \t\r");
  

  Load_Game_Data(gameconfig);
  Load_Dialogue_Data(dialogueconfig);

  enc : Encounter = {
    action = "attack",
    Characters = .[.{CurrentLocation.Characters[0],1,false},.{CurrentLocation.Characters[1],2,false}],
    desc = "two drunks are in a fight"
  };
  add_encounter(CurrentLocation, enc);

  //print("%\n", generate_dialogue("Greetings",.[]));

  //Input loop
    stdin_handle := GetStdHandle(STD_INPUT_HANDLE);

    buffer: [256] u8;

    while true {
      if CurrentState == {
        case .WORLD;
          print("You are out in the world. Where do you go?\n");
          
        case .AREA;
          print("%. Where would you like to go?\n", CurrentArea.desc);

        case .LOCATION;
          print("%\n", CurrentLocation.desc);

        case .INTERACT;
          if CurrentInteract.Type == {
            case .OBJECT;
            print("What do you do with the %\n", CurrentInteract.name);

            case .CHARACTER;
            print("What do you do with %\n", CurrentInteract.name);
          }
        
        case .ENCOUNTER;
          print("%\n", CurrentEncounter.desc);
      }
      print("%>",CurrentTime);

        chars_read: u32;
        ok := ReadFile(stdin_handle, buffer.data, xx buffer.count, *chars_read, null);
        if ok == .FALSE break;       // read failed
        if chars_read == 0 break;    // EOF / pipe closed

        s: string;
        s.data  = buffer.data;
        s.count = xx chars_read;
        s = trim_right(s, "\r\n");   // strip the trailing newline

        if s == "exit" || s == "quit" break;

        if s == "perceive" || s == "look" {
          look_choice();
          print("\n");
        }

        else{
          has_choice(s);
          print("\n");
        } 
    }

    print("You exited the game\n");
}

look_choice :: (){
  if CurrentState == {
    case .WORLD;
      for KnownAreas{
        print("%\n", it.name);
      }
    case .AREA;
     for CurrentArea.Locations{
      print("%\n", it.name);
    } 
    case .LOCATION;
    if CurrentLocation.Interactables.count == 0 && CurrentLocation.Characters.count == 0 {
      print("This place seems empty. You can't see anyone or anything in here.\n");
      return;
    }
    i :int;
    for CurrentLocation.Interactables{
      print("[%]%\n",i, it.name);
      i += 1;
    }
    for CurrentLocation.Characters{
      print("[%]%\n",i, character_fulladdress(it));
      i += 1;
    }
    for CurrentLocation.Encounters{
      print("[%]%\n",i, it.desc);
      i += 1;
    }
    case .ENCOUNTER;
    for CurrentEncounter.Characters {
      print("%\n", character_fulladdress(it.char));
    }
  }
}

//Process choices
has_choice :: (s : string){
  //Check which state the player is in.
  if same_string(s, "commands") {
    default_commands();
    return;
  }
  if CurrentState == {
 //World----------------------------------------------------------------//
    case .WORLD;
      for KnownAreas{
        if same_string(s, it.name){
          CurrentArea = it;
          CurrentState = .AREA;
          CurrentTime += 1;
          return;
        }
      }
 //Area-----------------------------------------------------------------//   
    case .AREA;
      if same_string(s, "leave"){
        CurrentState = .WORLD;
        CurrentTime += 1;
        return;
      }
      for CurrentArea.Locations{
        if same_string(s, it.name){
          Set_Location(it);
          return;
        }
      }
 //Location-------------------------------------------------------------//   
    case .LOCATION;
      if same_string(s, "leave") {
        update_reputation();
        CurrentState = .AREA;
        CurrentTime += 1;
        return;
      }
      for CurrentLocation.Interactables{
        if same_string(s, it.name) {
          CurrentState = .INTERACT;
          CurrentInteract = *it;
          return;
        }
      } 
      for CurrentLocation.Characters{
        if same_string(s, it.name) {
          CurrentState = .INTERACT;
          CurrentInteract = it;
          return;
        }
      } 
      ind := string_to_int(s);
      icount := CurrentLocation.Interactables.count;
      ccount := CurrentLocation.Characters.count;
      ecount := CurrentLocation.Encounters.count;
      if ind > -1 && ind < (icount + ccount + ecount) {
        CurrentState = .INTERACT;
        //print("valid index\n");
        if ind < icount {
          CurrentInteract = *CurrentLocation.Interactables[ind]; 
          return;
        }
        if ind < icount+ccount {
          CurrentInteract = CurrentLocation.Characters[ind-icount]; 
          return;
        }
        if ind < icount+ccount+ecount {
          Start_Encounter(CurrentLocation.Encounters[ind-icount-ccount]);
          return;
        }
      }
 //Interact------------------------------------------------------------//   
    case .INTERACT;
    success := false;
      if same_string(s, "hit") {
        success = true;
        if CurrentInteract.Type == .CHARACTER {//if character
          c := cast(*Character)CurrentInteract;
          if CurrentEncounter {//if in the middle of an encounter
          //print("already in an encounter\n");
            if random_bool_weighted(0.7) {//randomly win
              for c.Acquaintances {
              it.Grudge = true;
              }
              add_to_scene(CurrentEncounter.action,"kill", c, CurrentLocation, true, 0.3, -0.3);
              remove_interactable(CurrentInteract);
              print("you won\n");
            } else {
              //lose
              print("you lost.\n");
              for CurrentEncounter.Characters {
                it.char.Grudge = false;
              }
              add_to_scene(CurrentEncounter.action,"lose", c, CurrentLocation, true, -0.3, -0.3);
              end_encounter();
            }
          } else {//create a new encounter
          //print("starting new enounter\n");
            tmp : [] Participant = .[.{c,1,true}];
            chars := array_copy(tmp);//copy to the heap
            enc := New(Encounter);
            enc.* = .{"attack", chars,sprint("You are now in an encouter against a %",c.Role)};
            Start_Encounter(enc);
          }
        } else {// if not character
          print("%", CurrentInteract.Hit_Text.text);
          for CurrentInteract.Hit_Text.func {
          run_func(it);
          }
        }
        //remove_interactable(CurrentInteract);
      }
      if same_string(s, "interact") || same_string(s, CurrentInteract.Int_Alias){
        if CurrentInteract.Type == .CHARACTER {
          i := CurrentInteract;
          c := cast(*Character) i;
          print("%\n", reputation_label(calculate_temp_reputation(c)));//print current reputation
          print("\"");
          print("%", generate_dialogue(c, "Greetings"));
          print("\"");
        } else {
            print("%", CurrentInteract.Int_Text.text);
        }
        for CurrentInteract.Int_Text.func {
          run_func(it);
        }
        success = true;
        
      }
      if same_string(s, "leave") {
        print("You leave the %", CurrentInteract.name);
        success = true;
      }
      print("\n");
      if success {
        //if encounter still exists, return to it
        if CurrentEncounter && CurrentEncounter.Characters.count > 0 {
          CurrentState = .ENCOUNTER;
          return;
        }
        else {
          if CurrentEncounter {
           end_encounter(); 
          }
          CurrentState = .LOCATION;
          check_grudges(CurrentLocation);
          return;
        }
      }
  //Encounter------------------------------------------------------------//   
    case .ENCOUNTER;
      if same_string(s, "leave"){
        if ran_away(CurrentEncounter) {
          print("You ran away\n");
          add_to_scene(CurrentEncounter.action,"run", CurrentEncounter.Characters[0].char, CurrentLocation, true, -0.3, -0.3);
          CurrentState = .LOCATION;
          end_encounter();
          return;
        }
        print("You leave the encounter\n");
        //update_reputation("run", CurrentEncounter.char, CurrentLocation, true, -0.3, -0.3);
        
        //update_reputation();
        CurrentState = .LOCATION;
        end_encounter();
        return;
      }   
      for CurrentEncounter.Characters{
        //print("%\n",it.name);
        if same_string(s, it.char.name) {
          CurrentState = .INTERACT;
          CurrentInteract = it.char;
          return;
        }
      }
      /*if same_string(s, "fight"){
        if random_bool_weighted(0.7) {//randomly win
          print("You defeat %\n", character_fulladdress(CurrentEncounter.char));
          for CurrentEncounter.char.Acquaintances {
            it.Grudge = true;
          }
          //update_reputation("kill", CurrentEncounter.char, CurrentLocation, true, 0.3, -0.3);//hardcoded that you start the fight
          add_to_scene(CurrentEncounter.action,"kill", CurrentEncounter.char, CurrentLocation, true, 0.3, -0.3);
          remove_interactable(CurrentEncounter.char);
        } else {//randomly lose
          print("You lost to %\n", character_fulladdress(CurrentEncounter.char));
          //update_reputation("lose", CurrentEncounter.char, CurrentLocation, true, -0.3, -0.3);
          add_to_scene(CurrentEncounter.action,"lose", CurrentEncounter.char, CurrentLocation, true, -0.3, -0.3);
        }
        CurrentState = .LOCATION;
        fresh : Encounter;
        CurrentEncounter = fresh;
        check_grudges(CurrentLocation);//check if someone else joins because you killed their friend
        return;
      }*/
  }
  print("Unknown command: %\n", s);
  default_commands();
}

default_commands :: (){
  print("Available commands:\n",);
  if CurrentState == {
    case .WORLD;
      print("look\n");
    
    case .AREA;
      print("look\n");
      print("leave\n");
    
    case .LOCATION;
      print("look\n");
      print("leave\n");

    case .INTERACT;
      print("hit\n");
      print("leave\n");
      print("interact\n");
      if CurrentInteract.Int_Alias.count > 0 print("%\n", CurrentInteract.Int_Alias);

    case .ENCOUNTER;
      print("leave\n");
      print("look\n");
  }
}

remove_interactable :: (i : Interactable){
  temparr : [..] Interactable;
  removed : bool;
  for CurrentLocation.Interactables{
    if it.name != i.name || removed {
      array_add(*temparr, it);
    } else removed = true;
  }
  CurrentLocation.Interactables = temparr;

  temparr2 : [..] *Character;
  for CurrentLocation.Characters{
    if it.name != i.name {
      array_add(*temparr2, it);
    }
  }
  CurrentLocation.Characters = temparr2;

  if CurrentEncounter{//remove from encounter
    temparr3 : [..] Participant;
    for CurrentEncounter.Characters{
      if it.char.name != i.name {
        array_add(*temparr3, it);
      }
    }
  CurrentEncounter.Characters = temparr3;
  }
}

#import "String";
// case insensitive string check
same_string :: (a : string, b : string) -> bool {
  if a.count != b.count return false;

    for 0..a.count-1 {
        if to_lower(a[it]) != to_lower(b[it]) return false;
    }

    return true;
}