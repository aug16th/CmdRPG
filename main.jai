#import "Basic";
#import "Windows";

#load   "gamedata.jai";//data structs and loading

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
CurrentInteract : Interactable;

Add_Area :: (a : *Area){
  temparr : [..] *Area;
  if !array_find(KnownAreas, a){//check if area already known
    for KnownAreas{
        array_add(*temparr, it);
    }
    array_add(*temparr, a);
    KnownAreas = temparr;
  } //else print("area already known\n",);
}

Set_Location :: (loc : *Location){
  CurrentState = .LOCATION;
  CurrentLocation = loc;
  drefloc := loc.*;
}
//test func ----------------------------------//
test : func_call : .{
  fn = "gameplay_func"
};

main :: () {
  //init_commands();   // now generated automatically from every @GameCommand-tagged proc
  register_command("gameplay_func", gameplay_func);
  register_command("known_area_add", known_area_add);
  register_command("remove_from_location", remove_from_location);

  Load_Game_Data();
  //run_func(test);

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
          print("What do you do with the %\n", CurrentInteract.name);
      }
      print(">");

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
    for CurrentLocation.Interactables{
      print("%\n", it.name);
    }
    for CurrentLocation.Characters{
      print("%\n", it.name);
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
          return;
        }
      }
 //Area-----------------------------------------------------------------//   
    case .AREA;
      if same_string(s, "leave"){
        CurrentState = .WORLD;
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
        CurrentState = .AREA;
        return;
      }
      for CurrentLocation.Interactables{
        if same_string(s, it.name) {
          CurrentState = .INTERACT;
          CurrentInteract = it;
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
 //Interact------------------------------------------------------------//   
    case .INTERACT;
    success := false;
      if same_string(s, "hit") {
        print("%", CurrentInteract.Hit_Text.text);
        for CurrentInteract.Hit_Text.func {
          run_func(it);
        }
        //remove_interactable(CurrentInteract);
        success = true;
      }
      if same_string(s, "interact") || same_string(s, CurrentInteract.Int_Alias){
        if CurrentInteract.Type == .CHARACTER {
          print("\"%\"", CurrentInteract.Int_Text.text);
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
      CurrentState = .LOCATION;
      return;
      }
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
  }
}

remove_interactable :: (i : Interactable){
  temparr : [..] Interactable;
  for CurrentLocation.Interactables{
    if it.name != i.name {
      array_add(*temparr, it);
    }
  }
  CurrentLocation.Interactables = temparr;

  temparr2 : [..] Character;
  for CurrentLocation.Characters{
    if it.name != i.name {
      array_add(*temparr2, it);
    }
  }
  CurrentLocation.Characters = temparr2;
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