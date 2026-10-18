Dialogue_Set :: struct {
  Opener  : Table(string, [..] string);
  Address : Table(string, [..] string);
  Closer  : Table(string, [..] string);
}

Dialogue_Table : Table(string, Dialogue_Set);

generate_dialogue :: (DType: string, tags : [] string) -> string {//Todo: input witness bool
  //print("generating dialogue\n");
  generated : string;
  op : string;
  ad : string;
  cl : string;

  succ, obj := table_find(*Dialogue_Table, DType);
  if succ {
    if tags.count > 0 {
      //compare tags
      op = pick_by_tags(*obj.Opener,  tags);
      ad = pick_by_tags(*obj.Address, tags);
      cl = pick_by_tags(*obj.Closer,  tags);
    } else {
      succ1, arr1 := table_find(*obj.Opener, "default");
      if succ1 && arr1.count > 0 op = array_random(arr1);

      succ2, arr2 := table_find(*obj.Address, "default");
      if succ2 && arr2.count > 0 ad = array_random(arr2);

      succ3, arr3 := table_find(*obj.Closer, "default");
      if succ3 && arr3.count > 0 cl = array_random(arr3);
    }
  }
  if ad.count > 0 {
    generated = sprint("% %, %", op, ad, cl);
  } else {
    generated = sprint("% %", op, cl);
  }

  
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
          open := find_index_from_left(it, "(");
          close := find_index_from_right(current_string, ")");

          if open != -1 && close > open {
            text  := trim(slice(current_string, 0, open), " \t\r");
            inner := slice(current_string, open + 1, close - open - 1);

            for split(inner, ",") {
              arr := find_or_add(current_table, trim(it, " \t\r"));
              array_add(arr, text); 
            }
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

pick_by_tags :: (table: *Table(string, [..] string), tags: [] string) -> string {
  counts: Table(string, int);
  defer deinit(*counts);

  // Tally: how many of the requested tags' arrays contain each line
  for tag: tags {
    found, arr := table_find(table, trim(tag, " \t\r"));
    if !found continue;

    for line: arr {
      c := find_or_add(*counts, line);
      c.* += 1;
    }
  }

  // Collect every line tied for the highest tally
  best := 0;
  candidates: [..] string;
  defer array_reset(*candidates);

  for count, line: counts {
    if count > best {
      best = count;
      candidates.count = 0;      // new leader, drop the old ties
      array_add(*candidates, line);
    } else if count == best {
      array_add(*candidates, line);
    }
  }

  if candidates.count > 0  return array_random(candidates);

  // No requested tag had any lines, so fall back to the default pool
  found, defaults := table_find(table, "default");
  if found && defaults.count > 0  return array_random(defaults);

  return "";
}

generate_recall_dialogue :: (mem : MemoryCounter) -> string {//Tdod: check memcounter count for repeat offender
  targ : string;
  if mem.count < 1 targ = mem.latest.target;
  else targ = "all those people";
  //print("action count:%\n",mem.count);

  if mem.latest.action == {
    case "kill";
    return sprint("You killed %.", targ);

    case "lose";
    return sprint("You got your ass kicked by %.", targ);

    case "run";
    return sprint("You ran away from %.", targ);

    case "destroy";
    if mem.count > 1 return sprint("You destroyed all those things.");
    else return sprint("You destroyed that %.", targ);

    case ;
    return "wow";
  }
}