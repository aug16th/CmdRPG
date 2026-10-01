#load "gameplayfuncs.jai";

Interact_Type :: enum {
  OBJECT;
  CHARACTER;
}

response :: struct {
  text : string;
  func : func_call;
}

Interactable :: struct {
  name : string;
  Hit_Text : string;//make this a dialogue struct that has string and proc pointer
  Int_Text : string;
  Int_Alias: string;//other commands to use for interacting
  Type : Interact_Type = .OBJECT;
}

Character :: struct {
  #as using base : Interactable;
  Int_Alias = "talk";
  Type = .CHARACTER;
}

Area :: struct {
  name : string;
  desc : string;
  Locations : [] *Location;
  Characters : [] Character; // this might need to be pointers so we can update the characters.
}

Location :: struct {
  name : string;
  desc : string;
  Interactables : [] Interactable;
  Characters : [] Character;
  Can_Leave : bool;
}

#import "File";
#import "File_Utilities";

Section :: struct {
    tag: string;
    lines: [..] string;
}

Load_Game_Data :: (){

  file_contents, success := read_entire_file("Data/Config.ini");

  if !success {
        print("Error: Could not read the config file!\n");
        return;
    }

  directory := trim(file_contents, " \t\r");

  filelist := file_list(sprint("Data/%",directory));//returns array of string of paths

  sections: [..] Section;
  current: *Section;
  start_loaded : bool;

  for filelist {
    //print("%\n",it);
    game_data := sprint(trim(it, " \t\r"));

    file_contents, success = read_entire_file(game_data);

    if !success {
          print("Error: Could not read the game data file!\n");
          return;
      }

      // Print the file text out to the console
      lines := split(file_contents, "\n");
      for * lines {
        it.* = strip_comment(it.*);
      }

      
      //used_tags : [..] string;
      for lines {
        if it.count >= 2 && it[0] == #char "["{
            new_section := array_add(*sections);
            new_section.tag = slice(it, find_index_from_left(it, "[")+1, find_index_from_left(it, "]")-1);  // strip the [ and ]
            // if array_find(used_tags, new_section.tag) {//check for duplicate tags
            //   print("Error: Duplicate tags found in game data!\n");
            //   return;
            // }
            // array_add(*used_tags, new_section.tag);
            current = new_section;
            continue;
        }

        if current {
            if it.count > 0 array_add(*current.lines, it);
        }
      }
    }
    //load everyting under tag
    location_secs : [..] Section;
    area_secs : [..] Section;
    start_sec : Section;
    for sections {
      if it.tag == {
        case "Characters";
         load_characters(it);
        case "Interactables";
         load_interactables(it);
        case "Locations";
          array_add(*location_secs, it);
         //load_locations(it);
        case "Areas";
          array_add(*area_secs, it);
         //load_areas(it);
        case ;
         if !start_loaded && it.tag != "Start"{
          print("Error: Unrecognized tag: %\n", it.tag);
      } else if !start_loaded {
          start_sec = it;
          start_loaded = true;
      } else {
        print("Error: Multiple start tags found\n",);
        return;
        }
      }
    }
    for location_secs {
      load_locations(it);
    }
    for area_secs {
      load_areas(it);
    }
    load_start(start_sec);
}

strip_comment :: (line: string) -> string {
    hash_index := find_index_from_left(line, "#");
    if hash_index == -1 return line;   // no '#' on this line — return as-is
    result := line;
    result.count = hash_index;
    return result;
}

#import "Hash_Table";
//Character Table-------------------------------------------//
Characters_Table: Table(string, *Character);//table of characters

load_characters :: (sec : Section){
  current: *Character;

    for sec.lines {
        colon_index := find_index_from_left(it, ":");

        if colon_index == -1 {
            // No colon means this line is a new record header (e.g. "Character1")
            current = New(Character);
            var := trim(it, " \t\r");   // strip leading/trailing whitespace and stray \r
            table_add(*Characters_Table, var, current);   // register once we know the name
            continue;
        }

        if !current continue;   // a field line appeared before any header — skip defensively

        key   := trim_right(slice(it, 0, colon_index), " \t");
        value := trim_left(slice(it, colon_index + 1, it.count - colon_index - 1), " \t");
        value = trim(value, " \t\r");
        if key == "name" {
            current.name = value;
        } else if key == "hit" {
            current.Hit_Text = value;
        } else if key == "interact" {
            current.Int_Text = value;
        } else if key == "interact command" {
            current.Int_Alias = value;
        }
    }
}

//Interactable Table-------------------------------------------//
Interactables_Table: Table(string, *Interactable);//table of characters

load_interactables :: (sec : Section){
  current: *Interactable;

    for sec.lines {
        colon_index := find_index_from_left(it, ":");

        if colon_index == -1 {
            // No colon means this line is a new record header (e.g. "Character1")
            current = New(Interactable);
            var := trim(it, " \t\r");   // strip leading/trailing whitespace and stray \r
            table_add(*Interactables_Table, var, current);   // register once we know the name
            continue;
        }

        if !current continue;   // a field line appeared before any header — skip defensively

        key   := trim_right(slice(it, 0, colon_index), " \t");
        value := trim_left(slice(it, colon_index + 1, it.count - colon_index - 1), " \t");
        value = trim(value, " \t\r");
        if key == "name" {
            current.name = value;
        } else if key == "hit" {
            current.Hit_Text = value;
        } else if key == "interact" {
            current.Int_Text = value;
        } else if key == "interact command" {
            current.Int_Alias = value;
        }
    }
}

//Locations Table-------------------------------------------//
Locations_Table: Table(string, *Location);//table of characters

load_locations :: (sec : Section){
  current: *Location;

    for sec.lines {
        colon_index := find_index_from_left(it, ":");

        if colon_index == -1 {
            // No colon means this line is a new record header (e.g. "Character1")
            current = New(Location);
            var := trim(it, " \t\r");   // strip leading/trailing whitespace and stray \r
            table_add(*Locations_Table, var, current);   // register once we know the name
            continue;
        }

        if !current continue;   // a field line appeared before any header — skip defensively

        key   := trim_right(slice(it, 0, colon_index), " \t");
        value := trim_left(slice(it, colon_index + 1, it.count - colon_index - 1), " \t");
        value = trim(value, " \t\r");
        if key == "name" {
            current.name = value;
        } else if key == "description" {
            current.desc = value;
        } else if key == "interactables" {
          arr := split(value,",");
          objarr : [..] Interactable;
          for arr {
            succ, obj := table_find(*Interactables_Table, trim(it, " \t\r"));
            if succ array_add(*objarr, obj);
          }
            current.Interactables = objarr;
        } else if key == "characters" {
          arr := split(value,",");
          objarr : [..] Character;
          for arr {
            succ, obj := table_find(*Characters_Table, trim(it, " \t\r"));
            if succ array_add(*objarr, obj);
          }
            current.Characters = objarr;
        }
    }
}

//Area Table-------------------------------------------//
Areas_Table: Table(string, *Area);//table of characters

load_areas :: (sec : Section){
  current: *Area;

    for sec.lines {
        colon_index := find_index_from_left(it, ":");

        if colon_index == -1 {
            // No colon means this line is a new record header (e.g. "Character1")
            current = New(Area);
            var := trim(it, " \t\r");   // strip leading/trailing whitespace and stray \r
            table_add(*Areas_Table, var, current);   // register once we know the name
            continue;
        }

        if !current continue;   // a field line appeared before any header — skip defensively

        key   := trim_right(slice(it, 0, colon_index), " \t");
        value := trim_left(slice(it, colon_index + 1, it.count - colon_index - 1), " \t");
        value = trim(value, " \t\r");
        if key == "name" {
            current.name = value;
        } else if key == "description" {
            current.desc = value;
        } else if key == "locations" {
          arr := split(value,",");
          objarr : [..] *Location;
          for arr {
            succ, obj := table_find(*Locations_Table, trim(it, " \t\r"));
            if succ array_add(*objarr, obj);
          }
            current.Locations = objarr;
        } else if key == "characters" {
          arr := split(value,",");
          objarr : [..] Character;
          for arr {
            succ, obj := table_find(*Characters_Table, trim(it, " \t\r"));
            if succ array_add(*objarr, obj);
          }
            current.Characters = objarr;
        }
    }
}
//Load Start------------------------------------------//
load_start :: (sec : Section){
  
  for sec.lines {
    colon_index := find_index_from_left(it, ":");
    if colon_index == -1 continue;

    key   := trim_right(slice(it, 0, colon_index), " \t");
    value := trim_left(slice(it, colon_index + 1, it.count - colon_index - 1), " \t");
    value = trim(value, " \t\r");

    if key == "area" {
      succ, obj := table_find(*Areas_Table, trim(value, " \t\r"));
      if succ CurrentArea = obj;
    } else if key == "location" {
      succ, obj := table_find(*Locations_Table, trim(value, " \t\r"));
      if succ Set_Location(obj);
    } else if key == "known areas" {
        arr := split(value,",");
          for arr {
            succ, obj := table_find(*Areas_Table, trim(it, " \t\r"));
            if succ Add_Area(obj);
          } 
    }
  }
}