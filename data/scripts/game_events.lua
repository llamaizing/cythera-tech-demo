--[[ event_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script manages events in accordance with the current time, which determines where
	NPCs will be located on the map. Note that the game_clock.lua script loads this script
	automatically, with the scripts working in tandem to manage time and events.
	
	NPCs with events to be scheduled by the event_manager.lua script need a data file that
	is located in the data/events/ directory.

	Rate of Game Time
		Real Time	:	Game Time
		12 minutes	:	24 Hours
		6 minutes	:	12 hours
		3 minutes	:	6 hours
		1 minute	:	2 hours
		30 seconds	:	1 hour
		15 seconds	:	30 minutes
		7.5 seconds	:	15 minutes
		5 seconds	:	10 minutes
		0.5 seconds	:	1 minute
	
		Walk speed: 1 tile per real-time second using npc:set_speed(16)
]]

local event_manager = {}

local night_overlay = require"scripts/menus/night_overlay.lua"

local directions = {
	[0] = {x=8, y=0},
	[1] = {x=8, y=-8},
	[2] = {x=0, y=-8},
	[3] = {x=-8, y=-8},
	[4] = {x=-8, y=0},
	[5] = {x=-8, y=8},
	[6] = {x=0, y=8},
	[7] = {x=8, y=8},
}

--TODO function to load all data files in events directory
local schedule = {
	Neoptolemus = require"events/npc.Neoptolemus",
}


function event_manager:initialize(game)
	game.events = {}
	
	local collision_check_timer --nil if timer not running
	local events_list = {} --list of all events associated with NPCs on the current map
	local npcs_with_movement = {} --keep track of NPCs that have been assigned a movement to easily cancel all movements
		--key is the npc entity with value set to true
	local queued_movements = {} --table of movement paths to start on next call of next_time()
		--key:npc entity, value:path movement table
	
	--// Checks if entity1 & entity2 are overlapping and if not makes entity1 non-traversable
	--// If they are overlapping then starts a timer to re-test again later (indefinite loop)
		--if entity2 is not specified then the hero is used
	local function collision_check(entity1, entity2)
		if not entity2 then entity2 = game:get_hero() end
		if not entity1 or not entity2 then return end
		
		--abort previous timer if running
		if entity1.collision_check_timer then
			entity1.collision_check_timer:stop()
			entity1.collision_check_timer = nil
		end
		
		--tests if entities overlap
		local function do_check()
			if entity2:overlaps(entity1, "overlapping") then
				return true --repeat timer then do another check
			else entity1:set_traversable(false) end --make entity traversable and don't restart timer
		end
		
		if do_check then sol.timer.start(entity1, 200, do_check) end --do first check, start timer to check again later if overlapping
	end
	
	--// After loading a map checks which event(s) are active and moves NPCs around accordingly.
	--// Also triggered when skipping ahead in time
	function game.events:load_map_events()
		local map = game:get_map()
		if not map then return end
		local map_id = map:get_id()
		
		--stop any pre-existing movements for all npcs
		for npc,_ in pairs(npcs_with_movement) do
			local mov = npc:get_movement()
			if mov then npc:stop_movement() end
			
			--in case walking animation is active, change it to stopped animation
			local sprite = npc:get_sprite()
			if sprite then sprite:set_animation"stopped" end
		end
		npcs_with_movement = {} --clear table
		
		events_list = {} --clear out events from previous map
		
		local current_time = game.clock:get_time_str() or "00:00" --time right now (string, "HH:MM")
		local current_time_num = current_time:gsub(":",".") --change colon to period and convert to number
		current_time_num = tonumber(current_time_num) --need to put on second line to drop second return from gsub()
		
		night_overlay:initialize(map, current_time)
		if not sol.menu.is_started(night_overlay) then
			sol.menu.start(map, night_overlay, false)
		end
		
		local start_time --time the event starts (string, "HH:MM")
		local start_time_num --converted to number
		local active_event --the event that is active right now for the given NPC
		local map_events --all events for the given NPC on this map
		for npc_id,npc_events in pairs(schedule) do
			active_event = nil --reset for this npc
			map_events = npc_events[map_id] or {}
			
			for _,event in ipairs(map_events) do
				start_time = event.start_time
				
				--create list of all events for this map
				event.npc_id = npc_id --add reference to the NPC in the event --TODO this should be done only once while loading the game
				events_list[start_time] = events_list[start_time] or {} --create new entry if necessary
				table.insert(events_list[start_time], event)
				
				--find active event for this npc
				--TODO binary search for better efficiency
				start_time_num = start_time:gsub(":",".") --change colon to period and convert to number
				start_time_num = tonumber(start_time_num) --need to put on second line to drop second return from gsub()
				if start_time_num<=current_time_num then
					--TODO check if event is active (based on save game values, etc)
					active_event = event --for now assume all events are active
				end
			end
			
			--find and set NPC location for the current time and start path movement
			if active_event then
				--recalculate start_time_num for active event --TODO better implementation
				start_time_num = active_event.start_time:gsub(":",".") --change colon to period and convert to number
				start_time_num = tonumber(start_time_num) --need to put on second line to drop second return from gsub()
				
				local npc_loc = active_event.location
				if npc_loc then
					local npc_x,npc_y = npc_loc.x, npc_loc.y
					local npc_facing = npc_loc.facing
					
					local new_path = {}
					if type(active_event.path)=="table" and npc_x and npc_y then
						local min_delta = current_time_num - start_time_num
						local hrs = math.floor(min_delta)
						min_delta = math.floor((min_delta - hrs)*100 + 0.5) + hrs*60 --how many minutes into the event it is right now
						
						--find new position for npc by stepping through path up until present time
						local num_steps = min_delta+1
						for i,path_i in ipairs(active_event.path) do --for each step in path
							if i<=num_steps then --account for steps that happened in past
								local dir = directions[path_i] --get x/y position offset given path direction
								if dir then --calculate new position after this path step
									npc_x = npc_x + (dir.x or 0)
									npc_y = npc_y + (dir.y or 0)
									npc_facing = math.floor(path_i/2) --convert dir8 to dir4
								end
							else table.insert(new_path, path_i) end --save remaining (future) path entries to new path
						end
					end
					
					--update NPC's location and enable/disable
					local npc = map:get_entity(npc_id)
					if npc then
						npc:set_position(npc_x, npc_y, npc_loc.layer)
						if npc_facing then npc:get_sprite():set_direction(npc_facing) end
						
						npc:set_enabled(npc_loc.is_enabled)
						npc.is_sleeping = not not npc_loc.is_sleeping
						
						--npc should be sleeping if current time is beyond sleep_time
						if active_event.sleep_time then
							local sleep_time_num = active_event.sleep_time:gsub(":",".") --change colon to period and convert to number
							sleep_time_num = tonumber(start_time_num) --need to put on second line to drop second return from gsub()
							
							if sleep_time_num <= start_time_num then npc.is_sleeping = true end
						end
						
						if active_event.is_sleeping==false then npc.is_sleeping = false end --wake the NPC up in the morning
						
						if #new_path>0 then --still future path steps for npc; start movement
							npc:set_enabled(true)
							--npc.is_sleeping = nil --no sleepwalking! --TODO should disable if there is any (past) path present
							npc:set_traversable(true)
							
							--TODO common function to create NPC movement
							local mov = sol.movement.create"path"
							mov:set_path(new_path)
							mov:set_speed(16)
							mov:set_ignore_obstacles(true)
							mov:set_loop(false)
							
							function mov:on_finished()
								collision_check(npc)
								if active_event.end_facing then npc:get_sprite():set_direction(active_event.end_facing) end
							end
							
							--function mov:on_position_changed() --DEBUG
							--	local x,y = npc:get_position()
							--end
							
							queued_movements[npc] = mov --this movement will start on next call of next_time(); hold off to synchronize with game clock
						end
					end
				end
			end
		end
	end
	
	--// At the start of every in-game minute, checks to see it there are any events that
	--// need to be started and will move NPCs around accordingly.
		--time_str (string): current time in format "HH:MM"
	function game.events:new_time(time_str)
		local map = game:get_map()
		if not map then return end
		local map_id = map:get_id()
		
		--print("Time:", time_str, sol.main.get_elapsed_time()) --DEBUG clock update
		
		night_overlay:update(time_str)
		
		--// Begin all NPC events that start now (move npc locations and give movements)
		
		for _,event in ipairs(events_list[time_str] or {}) do
			local npc_id = event.npc_id
			local npc_loc = event.location
		
			if npc_id and npc_loc then
				local npc = map:get_entity(npc_id)
				if npc then
					--stop existing movement if it exists
					local old_mov = npc:get_movement()
					if old_mov then
						if old_mov.on_finished then old_mov:on_finished() end
						old_mov:stop() --incase previous movement still active
					end
					
					if queued_movements[npc] then
						queued_movements[npc]:on_finished() --call the movement on_finished function now since it won't be applied
						queued_movements[npc] = nil --ignore queued movement for this npc; new event overrides it
					end
					
					npc:set_position(npc_loc.x, npc_loc.y, npc_loc.layer)
					
					local npc_sprite = npc:get_sprite()
					npc_sprite:set_animation"stopped"
					if npc_loc.facing then npc_sprite:set_direction(npc_loc.facing) end
					
					npc:set_enabled(npc_loc.is_enabled)
					npc.is_sleeping = not not npc_loc.is_sleeping
					
					--npc should be sleeping if current time is beyond sleep_time
					if event.sleep_time then
						local current_time_num = time_str:gsub(":",".") --change colon to period and convert to number
						current_time_num = tonumber(current_time_num) --need to put on second line to drop second return from gsub()
						
						local sleep_time_num = event.sleep_time:gsub(":",".") --change colon to period and convert to number
						sleep_time_num = tonumber(start_time_num) --need to put on second line to drop second return from gsub()
						
						if sleep_time_num <= current_time_num then npc.is_sleeping = true end
					end
					
					if event.is_sleeping==false then npc.is_sleeping = false end --wake the NPC up in the morning
					
					--start movement for NPC if path present for this event
					if type(event.path)=="table" then
						npc:set_enabled(true) --always enable when giving movement (overrides above)
						--npc.is_sleeping = nil --no sleepwalking!
						npc:set_traversable(true)
					
						local mov = sol.movement.create"path"
						mov:set_path(event.path)
						mov:set_speed(16)
						mov:set_ignore_obstacles(true)
						mov:set_loop(false)

						mov:start(npc)
						npcs_with_movement[npc] = true
						function mov:on_finished()
							collision_check(npc)
							if event.end_facing then npc:get_sprite():set_direction(event.end_facing) end
						end
					end
				end
			end
		end
		
		--// Now start previously queued movements
		
		for npc,mov in pairs(queued_movements) do
			mov:start(npc)
			npcs_with_movement[npc] = true
		end
		queued_movements = {} --movements have been processed, clear table
	end
end

setmetatable(event_manager, {__call = event_manager.initialize}) --convenience

return event_manager


--[[ Copyright 2016 Llamazing
  [[ 
  [[ This program is free software: you can redistribute it and/or modify it under the
  [[ terms of the GNU General Public License as published by the Free Software Foundation,
  [[ either version 3 of the License, or (at your option) any later version.
  [[ 
  [[ It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
  [[ without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
  [[ PURPOSE.  See the GNU General Public License for more details.
  [[ 
  [[ You should have received a copy of the GNU General Public License along with this
  [[ program.  If not, see <http://www.gnu.org/licenses/>.
  ]]
