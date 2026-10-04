func_call :: struct {
  fn : string;
  args : []string;
}

//All gameplay functions need to have this signature
Command_Proc :: #type (args: [] string);

function_Table: Table(string, Command_Proc);//table of functions

register_command :: (name: string, fn: Command_Proc) {
    table_add(*function_Table, name, fn);
}

run_func :: (func : func_call){
  found, proc := table_find(*function_Table, func.fn);
    if found {
        proc(func.args);
    } else {
        print("Unknown function: %\n", func.fn);
    }
}

//Exposed Gameplay functions -----------------------------------//
gameplay_func :: (args : [] string){
  print("Function executed\n",);
  return;
}


known_area_add :: (args : [] string){
  if args.count < 1 {
    print("Error: not enough arguments\n",);
    return;
  } else {
    var := args[0];
    found, area := table_find(*Areas_Table, var);
    if found{
      Add_Area(area);
      print("\n- You now know where % is -\n", area.name);
      //maybe eventually expose this in config so designer can decide what should print when player unlocks location
    }else print("Error: Area not found\n",);
  }
} @GameCommand 


remove_from_location :: (args : [] string){
  remove_interactable(CurrentInteract);
} @GameCommand


add_location_to_area :: (args : [] string){
  if args.count < 2 {
    print("Error: not enough arguments\n",);
    return;
  } else {
    a := args[0];
    l := args[1];
    found, area := table_find(*Areas_Table, a);
    found2, loc := table_find(*Locations_Table, l);
    if found && found2 {
      Add_Location(area, loc);
      print("\n- You now know where % is -\n", loc.name);
    } else print("Error: Area or location not found\n",);
  }
} @GameCommand

add_item_to_location :: (args : [] string){
  if args.count < 2 {
    print("Error: not enough arguments\n",);
    return;
  } else {
    l := args[0];
    i := args[1];
    found, loc := table_find(*Locations_Table, l);
    found2, inte := table_find(*Interactables_Table, i);
    if found && found2 {
      Add_Interactable_To_Location(loc, inte.*);
      print("\n- There is now a % here -\n", inte.name);
    } else print("Error: location or interactable not found\n",);
  } 
} @GameCommand