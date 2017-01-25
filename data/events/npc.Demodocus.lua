--npc.Demodocus Events
--Note: not used

--// Paths for NPC movements
local paths = {
	--map tavern paths
	bar_to_door = {6, 6, 6, 6, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6}, --62 steps
	door_to_bar = {2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2}, --62 steps
	
	--map cademia paths
	bar_door_to_east_exit = { --60 steps
		6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	},
	west_exit_to_bar_door = { --80 steps
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0,    0, 0, 0, 2, 2, 2, 2, 2, 2, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 2,    2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	},
}

--// Describes NPC's position on map at the start of an event
	--x,y (number) coordinates for NPC position from top left of map
	--layer (number) which map layer to put the NPC on
	--facing (number, 0-3) direction npc is facing at end of path movement (0=right, 1=up, 2=left, 3=down)
	--is_enabled (boolean, default true) if false then hide NPC while at this location
	--is_sleeping (boolean, default false) if true then cannot interact with NPC while at this location (also prevents bed from being used by player)
	
	--NOTE: each entry in the schedule table should reference a locations entry as a value for the location key
local locations = {
	--map cademia locations
	east_exit = { --beyond town edge, disabled (off-map)
		is_enabled = false,
		x = 96,
		y = 157,
		layer = 0,
		facing = 2,
	},
	west_exit = { --beyond town edge, disabled (off-map)
		is_enabled = false,
		x = -8,
		y = 277,
		layer = 0,
		facing = 0,
	},
	in_tavern = { --beyond doorway of tavern, disabled (off-map)
		is_enabled = true,
		x = 496,
		y = 141,
		layer = 0,
		facing = 3,
	},
	
	--map tavern locations
	outside = { --beyond doorway, disabled (off-map)
		is_enabled = false,
		x = 176,
		y = 237,
		layer = 1,
		facing = 1,
	},
	at_bar = { --sitting at bar
		is_enabled = true,
		x = 312,
		y = 125,
		layer = 1,
		facing = 1,
	},
}

local schedule = {
	cademia = {
		{	--off-map (hidden)
			start_time = "00:00",
			location = locations.west_exit,
			path = false,
		},
		{ --walking from west exit to tavern door in morning
			start_time = "09:00",
			location = locations.west_exit,
			path = paths.west_exit_to_bar_door,
		},
		{ --inside tavern
			start_time = "10:20",
			path = false,
			location = locations.in_tavern,
		},
		{ --walking from tavern door to east exit in evening
			start_time = "23:30",
			path = paths.bar_door_to_east_exit,
			location = locations.in_tavern,
		},
		{ --off-map (hidden)
			start_time = "17:38", --8 steps after 17:30
			path = false,
			location = locations.in_house,
		},
	},
	tavern = {
		{ --outside bar (hidden)
			start_time = "00:00",
			location = locations.outside,
			path = false,
		},
		{ --walking from door to bar in morning
			start_time = "10:19",
			location = locations.outside,
			path = paths.door_to_bar,
		},
		{ --sitting at bar
			start_time = "10:50",
			location = locations.at_bar,
			path = false,
		},
		{ --walking from bar to door in evening
			start_time = "23:00",
			location = locations.at_bar,
			path = paths.bar_to_door,
		},
		{ --outside bar (hidden)
			start_time = "23:31",
			location = locations.outside,
			path = false,
		},
	},
}

return schedule
