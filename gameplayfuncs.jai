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
  print("number of available funcs %\n",function_Table.count);
  found, proc := table_find(*function_Table, func.fn);
    if found {
        proc(func.args);
    } else {
        print("Unknown function: %\n", func.fn);
    }
}

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
    if found Add_Area(area); else print("Error: Area not found\n",);
  }
}

remove_from_location :: (args : [] string){
  remove_interactable(CurrentInteract);
}