Dialogue_Set :: struct {
  Opener  : Table(string, [..] string);
  Address : Table(string, [..] string);
  Closer  : Table(string, [..] string);
}

Dialogue_Table : Table(string, Table(string, Table(string, [..] string)));

generate_dialogue :: (DType: string, tags : [] string) -> string {//Todo: input witness bool
  //print("generating dialogue\n");
  generated : string;
  piece : string;
  succ0 :bool;
  builder : String_Builder;
  DR : [] DialoguePiece;
  if tags.count > 0 succ0, DR = table_find(*DialogueRecipes, tags[0]);//hard code for now
  else succ0, DR = table_find(*DialogueRecipes, "default");

  succ, obj := table_find(*Dialogue_Table, DType);//Load Dialogue table

  if succ0 && succ {
    for DR {
      if random_bool_weighted(it.chance){

        if it_index > 0  append(*builder, " ");
        succ1, DC := table_find(*obj, it.text);
        
        if succ1 {
        piece = pick_by_tags(*DC, tags);
        append(*builder, piece);
        }
      }
    }
    generated = builder_to_string(*builder);
  }
  return generated;
}

DialoguePiece :: struct {
  text   : string;
  chance : float;
}
DialogueRecipes : Table(string, [] DialoguePiece);//

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
    dialogueset : Table(string,Table(string, [..] string));
    current_table : *Table(string, [..] string);

    for lines {
      has_tag := find_index_from_left(it, "[") != -1;

      if has_tag {
        current_category = trim(trim(it, " \t\r"), "[");
        current_category = trim(current_category, "]");
        if current_category == "Recipes" continue;
        else current_table = find_or_add(*dialogueset, current_category);

      } else {
        //load recipes
        if current_category == "Recipes" {
          tag : string;
          arr : [..] DialoguePiece;
          current_string := trim(it, " \t\r");
          recipe := split(current_string, "|");
          for * recipe {
            it.* =  trim(it.*," \t\r");
            if it_index == 0 tag = it.*;
            else {
              s := it.*;
              space := find_index_from_right(s, " ");
              //if space == -1 return it, 0, false;
              piece : DialoguePiece;

              piece.text   = trim(slice(s, 0, space), " \t\r");
              num := to_integer(trim(slice(s, space + 1, s.count - space - 1), " \t\r"));
              piece.chance = num/100.0;
              array_add(*arr, piece);
            }
          }
          table_add(*DialogueRecipes, tag, arr);
        }
        // Add current line to category
        else if current_table {
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

generate_recall_dialogue :: (mem : *MemoryCounter) -> string {//Todo: check memcounter count for repeat offender. for now does not differentiate if it happened to multiple targets or the same one.
  
  targ : string;
  if mem.count < 2 targ = mem.latest.target;
  else targ = "all those people";
  //print("action count:%\n",mem.count);
  if mem.mentioned return "";//return empty if already mentioned
  if mem.time == CurrentTime {//is recent so return reaction instead of recall
     
  }

  mem.mentioned = true; //if not returned yet set mentioned to true

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