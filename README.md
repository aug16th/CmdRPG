# CmdRPG
This is a really simple commandline game for windows. It reads all the world data in Data/Default World but you can make your own data file and set which folder to load in Data/Config.ini. You can have as many [Tags] as you want for [Areas], [Locations], [Characters] and [Interactables] so you can organize for files based on location or anything you need.

You can only have one [Start] tag and it's needed to determine the starting location.

You can define which file you want to load in Data/Config.ini. This means you can create multiple folders for different worlds and choose which folder to load.

# Exposed Functions

known_area_add(Area)

Adds an area to the player's list of known areas allowing them to travel there. The common usecase is when the player is told about the location, reading a map etc.

remove_from_location()

This removes the current interactable from the current location. Common usecase is when hitting something or interacting/eating/drinking something.

add_location_to_area(Area, Location)

Adds the Location to the Area. Common uses is when a hidden location is revealed to the player. Area needs to be included because sometimes you might want to reveal a hidden location in a different area from the current one you are at.

add_item_to_location(Location, Interactable)

Adds an item to the specified location. This can be used if the player orders something from the bartender. It can also be used to spawn objects after talking to someone.