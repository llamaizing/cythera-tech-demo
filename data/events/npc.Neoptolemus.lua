--[[ npc.Neoptolemus.dat		1/24/2016
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This data file describes events governing the behavior of this NPC, including the time
	when the event begins, the map where the event occurs, and a description for the NPC's
	movements during the event.
	
	The only table returned is the schedule table, which for the purposes of organization,
	may reference additional local tables.
	
	The name of this file must be "npc.NPC_NAME", where NPC_NAME is the entity name of the
	NPC (case sensitive). The file extension can be either ".lua" or ".dat".
]]

--// Paths for NPC movements (See the Solarus Lua scripting API entry for path movement)
--// The format of this table is irrelevant; the schedule table references each entry.
local paths = {
	--map cademia paths
	outside_to_door = {4, 4, 4, 2, 2, 2, 2, 2}, --8 steps
	door_to_outside = {6, 6, 6, 6, 6, 0, 0, 0}, --8 steps
	
	--map neoptolemus_house paths
	door_to_table = {2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0}, --23 steps
	table_to_door = {4, 4, 4, 4, 4, 4, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6}, --23 steps
	table_to_bed = {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 2, 2, 2, 2, 2, 4, 4, 4}, --24 steps
	bed_to_table = {0, 0, 0, 6, 6, 6, 6, 6, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, --24 steps
}

--// Describes NPC's position on map at the start of an event.
--// The names (keys) for each location entry are irrelevant and for organizational purposes only.
--// The schedule table references each location entry.
	--x,y (number) coordinates for NPC position from top left of map
	--layer (number) which map layer to put the NPC on
	--facing (number, 0-3) direction npc is facing at end of path movement (0=right, 1=up, 2=left, 3=down)
	--is_enabled (boolean, default true) if false then hide NPC while at this location
	--is_sleeping (boolean, default false) if true then cannot interact with NPC while at this location
		--(also prevents bed from being used by player)
local locations = {
	--map cademia locations
	in_house = { --beyond doorway to house, disabled (off-map)
		is_enabled = false,
		x = 96,
		y = 157,
		layer = 0,
		facing = 3,
	},
	waiting = { --standing outside house
		is_enabled = true,
		x = 120,
		y = 197,
		layer = 0,
		facing = 3,
	},
	
	--map neoptolemus_house locations
	outside = { --beyond doorway, disabled (off-map)
		is_enabled = false,
		x = 160,
		y = 237,
		layer = 1,
		facing = 1,
	},
	eating = { --sitting at table
		is_enabled = true,
		x = 216,
		y = 109,
		layer = 1,
		facing = 3,
	},
	sleeping = { --in bed sleeping
		is_sleeping = true,
		x = 72,
		y = 61,
		layer = 1,
		facing = 1,
	},
}

--// Table with keys for each map_id that this NPC can be present on. The value is an array
--// of events that affect this NPC (i.e. when the NPC should follow a pre-determined route
--// or when the NPC should wait and do nothing). The events must be arranged in chronological
--// order as determined by the value of the start_time key that must be present in each event
--// Contents (keys) of each event table:
	--start_time (string): Time to start the event, format "HH:MM", where HH is 0-23 and MM is 0-59
	--sleep_time (string): Time when NPC begins sleeping (player can no longer interact), format "HH:MM"
	--location (table): Table describing the NPC's location at the event start (see locations table above)
	--path (table, optional): Movement path for the NPC to follow during the event
		--if no table is specified then the NPC will remain stationary for the duration of the event
	--end_facing (number 0-3, optional): The facing direction to give the NPC after completing the path movement
	
--// NOTE: Each map listed should have an instance of the NPC (named correctly) in the map .dat file.
--// It is okay to place the NPC outside of the map bounds; the NPC's position will be calculated
--// and moved dynamically whenever the map is loaded (or as events get triggered).
local schedule = {
	cademia = {
		{	--waiting inside house in morning (hidden)
			start_time = "00:00",
			location = locations.in_house,
			path = false,
		},
		{ --walking from house to outside
			start_time = "08:22", --8 steps before 8:30
			location = locations.in_house,
			path = paths.door_to_outside,
			end_facing = 3,
		},
		{ --waiting outside until evening
			start_time = "08:30",
			path = false,
			location = locations.waiting,
		},
		{ --walking from outside to house
			start_time = "17:30",
			path = paths.outside_to_door,
			location = locations.waiting,
		},
		{ --waiting inside house at night (hidden)
			start_time = "17:38", --8 steps after 17:30
			path = false,
			location = locations.in_house,
		},
	},
	neoptolemus_house = {
		{ --sleeping in bed in the morning
			start_time = "00:00",
			location = locations.sleeping,
			path = false,
		},
		{ --walking from bed to table in morning
			start_time = "06:30",
			is_sleeping = false,
			location = locations.sleeping,
			path = paths.bed_to_table,
			end_facing = 3,
		},
		{ --eating at table in morning
			start_time = "06:54",
			location = locations.eating,
			path = false,
		},
		{ --walking from table to door in morning
			start_time = "08:00",
			location = locations.eating,
			path = paths.table_to_door,
		},
		{ --outside of house (hidden)
			start_time = "08:23",
			location = locations.outside,
			path = false,
		},
		{ --walking from door to table in evening
			start_time = "17:37",
			location = locations.outside,
			path = paths.door_to_table,
			end_facing = 3,
		},
		{ --eating at table in evening
			start_time = "18:00",
			location = locations.eating,
			path = false,
		},
		{ --walking from table to bed in evening
			start_time = "21:00",
			sleep_time = "21:20",
			location = locations.eating,
			path = paths.table_to_bed,
			end_facing = 1,
		},
		{ --sleeping in bed in the evening
			start_time = "21:24",
			location = locations.sleeping,
			path = false,
		},
	},
}

return schedule
