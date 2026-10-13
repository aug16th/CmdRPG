Dialogue_Set :: struct {
  Opener  : Table(string, [..] string);
  Address : Table(string, [..] string);
  Closer  : Table(string, [..] string);
}

Dialogue_Table : Table(string, Dialogue_Set);

generate_dialogue :: (DType: string, tags : [] string) -> string {
  //print("generating dialogue\n");
  op : string;
  ad : string;
  cl : string;

  succ, obj := table_find(*Dialogue_Table, DType);
  if succ {
    if tags.count > 0 {
      //compare tags
      print("comparing tags\n");
    } else {
      succ1, arr1 := table_find(*obj.Opener, "default");
      if succ1 && arr1.count > 0 op = array_random(arr1);

      succ2, arr2 := table_find(*obj.Address, "default");
      if succ2 && arr2.count > 0 ad = array_random(arr2);

      succ3, arr3 := table_find(*obj.Closer, "default");
      if succ3 && arr3.count > 0 cl = array_random(arr3);
    }
  }

  generated := sprint("% %, %", op, ad, cl);
  return generated;
}

Load_Dialogue_Data :: (directory : string) {
  filelist := file_list(sprint("Data/%", directory));   // returns array of string of paths

  for filelist {
    dialogue_data := sprint(trim(it, " \t\r"));

    file_contents, success := read_entire_file(dialogue_data);

    if !success {
      print("Error: Could not read the dialogue data file!\n");
      return;
    }

    lines := split(file_contents, "\n");
    if lines.count == 0 continue;   // empty file, nothing to load

    for * lines {
      it.* = strip_comment(it.*);
    }

    current_collection := trim(lines[0], " \t\r");

    current_category : string;
    dialogueset : Dialogue_Set;
    current_table : *Table(string, [..] string);

    for lines {
      has_tag := find_index_from_left(it, "[") != -1;

      if has_tag {
        current_category = trim(trim(it, " \t\r"), "[");
        current_category = trim(current_category, "]");
        if current_category == "Opener"  current_table = *dialogueset.Opener;
        if current_category == "Address" current_table = *dialogueset.Address;
        if current_category == "Closer"  current_table = *dialogueset.Closer;
      } else {
        // Add current line to category
        if current_table {
          current_string := trim(it, " \t\r");
          if current_string.count == 0 continue;   // skip blank lines

          if find_index_from_left(it, "(") != -1 {
            //get the tags inside
          } else {
            // use default tag. find_or_add returns a pointer to the stored
            // [..] string, creating an empty entry if the key is new.
            arr := find_or_add(current_table, "default");
            array_add(arr, current_string);
          }
        }
      }
    }

    table_add(*Dialogue_Table, current_collection, dialogueset);
  }
}