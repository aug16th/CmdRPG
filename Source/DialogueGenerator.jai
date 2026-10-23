Dialogue_Table : Table(string, Table(string, Table(string, [..] string)));

generate_dialogue :: (char : *Character, DType: string) -> string {//Todo: input witness bool
  //print("generating dialogue\n");
  temprep := calculate_temp_reputation(char);//temporary reputation combined with current scene
  tags : [] string = .[reputation_label(temprep)];//create our tags
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
      if it.text == "Reference" {
        //Current scene memory
        if CurrentSceneMem.count > 0 {
        //we need to generate a recall based on the current scene memories
        found, mem := recall_currentscene(char, temprep);
        if found {
          if !mem.mentioned && random_bool_weighted(it.chance) {
            if it_index > 0  append(*builder, " ");
            piece := generate_recall_dialogue(*mem, tags);
            append(*builder, piece);
            mem.mentioned = true;
          }
        }

        } else {
        //internal memory
        found, mem := character_recall(char);
        if found {
          if !mem.mentioned && mem.time<CurrentTime && random_bool_weighted(it.chance) {
            if it_index > 0  append(*builder, " ");
            piece := generate_recall_dialogue(mem, tags);
            append(*builder, piece);
            mem.mentioned = true;
          }
        }
      }
      
      }else if random_bool_weighted(it.chance){

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
DialogueRecipes : Table(string, [] DialoguePiece);

Load_Dialogue_Data :: (directory : string) {
  filelist := file_list(sprint("Data/%", directory));   // returns array of string of paths

  for path: filelist {
    dialogue_data := trim(path, " \t\r");

    file_contents, success := read_entire_file(dialogue_data);
    if !success {
      print("Error: Could not read the dialogue data file: %\n", dialogue_data);
      return;
    }

    lines := split(file_contents, "\n");
    if lines.count == 0 continue;   // empty file, nothing to load

    // strip_comment keeps every line (it only shortens them), so indexes stay
    // valid as line numbers for error messages.
    for * lines {
      it.* = strip_comment(it.*);
    }

    current_collection := trim(lines[0], " \t\r");

    dialogueset     : Table(string, Table(string, [..] string));
    current_table   : *Table(string, [..] string);
    current_section : string;
    current_event   : string;

    for raw, line_index: lines {
      line := trim(raw, " \t\r");
      if line.count == 0 continue;

      // Section header: [ must be the first character on the line
      if line[0] == #char "[" {
        close := find_index_from_right(line, "]");
        if close < 1 {
          print("%:%: header is missing its closing ]\n", dialogue_data, line_index + 1);
          current_section = "";
          current_event   = "";
          current_table   = null;
          continue;
        }

        current_section = trim(slice(line, 1, close - 1), " \t");
        current_event   = "";
        current_table   = null;

        // These sections pick their table from @labels (or are recipes).
        // Every other section is one plain tag table, as before.
        if current_section != "Recipes" && current_section != "Reference" && current_section != "Forms" {
          current_table = find_or_add(*dialogueset, current_section);
        }
        continue;
      }

      if current_section == "Recipes" {
        load_recipe_line(line, dialogue_data, line_index + 1);
        continue;
      }

      if current_section == "Reference" || current_section == "Forms" {
        // @slot label
        if line[0] == #char "@" {
          slot := lowered(trim(slice(line, 1, line.count - 1), " \t"));
          if slot.count == 0 {
            print("%:%: empty @label\n", dialogue_data, line_index + 1);
            current_table = null;
            continue;
          }

          key: string;
          if current_section == "Forms" {
            if current_event.count == 0 {
              print("%:%: @% appears before any EVENT in [Forms]\n", dialogue_data, line_index + 1, slot);
              current_table = null;
              continue;
            }
            key = sprint("Forms.%.%", current_event, slot);
          } else {
            key = sprint("Reference.%", slot);
          }

          current_table = find_or_add(*dialogueset, key);
          continue;
        }

        // EVENT line (Forms only): a bare all-caps word
        if current_section == "Forms" && is_event_name(line) {
          current_event = lowered(line);
          current_table = null;   // a slot label must come next
          continue;
        }

        if !current_table {
          print("%:%: line has no @label above it: %\n", dialogue_data, line_index + 1, line);
          continue;
        }
      }

      if current_table add_dialogue_line(current_table, line);
    }

    table_add(*Dialogue_Table, current_collection, dialogueset);
  }
}

// Adds one dialogue line to a tag table. "text(a, b)" is stored under tags a and b.
// A line with no tag group at the very end goes under "default".
add_dialogue_line :: (table: *Table(string, [..] string), line: string) {
  if line[line.count - 1] == #char ")" {
    open := find_index_from_right(line, "(");
    if open > 0 {
      text  := trim(slice(line, 0, open), " \t\r");
      inner := slice(line, open + 1, line.count - open - 2);

      added := 0;
      for split(inner, ",") {
        tag := lowered(trim(it, " \t\r"));
        if tag.count == 0 continue;

        arr := find_or_add(table, tag);
        array_add(arr, text);
        added += 1;
      }

      if added > 0 return;
    }
  }

  arr := find_or_add(table, "default");
  array_add(arr, line);
}

// "fear | Reaction 100 | Stance 90" -> DialogueRecipes["fear"]
load_recipe_line :: (line: string, file: string, line_number: int) {
  parts := split(line, "|");
  if parts.count < 2 {
    print("%:%: recipe needs a tag and at least one piece\n", file, line_number);
    return;
  }

  tag := lowered(trim(parts[0], " \t\r"));
  arr : [..] DialoguePiece;

  for i: 1..parts.count-1 {
    s := trim(parts[i], " \t\r");
    space := find_index_from_right(s, " ");
    if space == -1 {
      print("%:%: recipe piece '%' needs a name and a number\n", file, line_number, s);
      continue;
    }

    piece : DialoguePiece;
    piece.text = trim(slice(s, 0, space), " \t\r");
    num := to_integer(trim(slice(s, space + 1, s.count - space - 1), " \t\r"));
    piece.chance = num / 100.0;
    array_add(*arr, piece);
  }

  table_add(*DialogueRecipes, tag, arr);
}

// An event name is one all-caps word: starts with a capital letter, then only
// capitals, digits or underscores. "KILL" and "KILL_ALLY" qualify; "NO." and
// "HELP ME" don't, so they stay dialogue.
is_event_name :: (s: string) -> bool {
  if s.count < 2 return false;
  if s[0] < #char "A" || s[0] > #char "Z" return false;

  for i: 0..s.count-1 {
    c := s[i];
    ok := (c >= #char "A" && c <= #char "Z") || (c >= #char "0" && c <= #char "9") || c == #char "_";
    if !ok return false;
  }
  return true;
}

lowered :: (s: string) -> string {
  if s.count == 0 return s;
  result := copy_string(s);
  for i: 0..result.count-1  result[i] = to_lower(result[i]);
  return result;
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

generate_recall_dialogue :: (mem : *MemoryCounter, tags : [] string) -> string {//Todo: check memcounter count for repeat offender. for now does not differentiate if it happened to multiple targets or the same one.
  
  targ := mem.latest.target.name;
  self := CurrentInteract.name == targ;
  act := mem.latest.action;
  wit : string;
  if mem.latest.witnessed wit = "saw";
  else wit = "heard";

  objsuc, obj := table_find(*Dialogue_Table,"Greetings");//hardcoded greetings for now
  refsuc : bool;
  ref : Table(string, [..] string);
  if objsuc refsuc, ref = table_find(*obj, sprint("Reference.%",wit));

  recall := pick_by_tags(*ref, tags);
  recall = fill_placeholder(recall, *obj, act, tags, targ, self);//fill in the placeholder
  //recall = fill_placeholder(recall, targ, self);//fill in target if any
  //maybe later we make a function that checks character relation so we can build what they call another character
  return recall;
  
}

fill_placeholder :: (in : string, table : *Table(string, Table(string, [..] string)), action : string, tags : [] string,targ : string, self :bool) -> string {
  index := find_index_from_left(in,"{");
  if index == -1 return in;

  close := find_index_from_right(in,"}");
  front := slice(in, 0, index);
  slot  := slice(in, index+1, close- index -1);
  end   := slice(in, close+1, in.count - close);

  succ, obj := table_find(table, sprint("Forms.%.%", action, slot));
  if succ {
    fill := fill_placeholder(pick_by_tags(*obj, tags),targ,self);
    return sprint("%%%",front, fill, end);//might want to use a default spacer defined in "join"
  }else return "failed to fill placeholder";
}

fill_placeholder :: (in : string, target : string, self : bool) -> string {
  index := find_index_from_left(in,"{");
  if index == -1 return in;

  close := find_index_from_right(in,"}");
  front := slice(in, 0, index);
  end   := slice(in, close+1, in.count - close);

  if self {
    if front.count > end.count return sprint("%%%",front, "me", end);
    else return sprint("%%%",front, "I", end);
  }

  return sprint("%%%",front, target, end);
}