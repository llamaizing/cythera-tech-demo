--[[ npc_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script adds custom functions to the npc metatable to handle interactions with the
	player and to check the NPC's name. Also adds custom functions to the map metatable to
	create text bubbles above the head of an NPC.
]]

local npc_manager = {}

local util = require"scripts/util.lua"
local text_bubble = require"scripts/text_bubble"
local npcs = require"scripts/npcs.dat"

local current_game

function npc_manager:initialize(game)
	local game_type = sol.main.get_type(game)
	assert(game_type=="game", "Bad argument #1 to 'initialize' (sol.game expected, got "..game_type..")")
	
	current_game = game
	
	
	-------------------
	-- NPC Metatable --
	-------------------
	
	local npc_meta = sol.main.get_metatable"npc"
	
	
	--// Returns a table with entries containing the NPC name split at each period character
	function npc_meta:split_names()
		local full_name = self:get_name()
	
		--separate npc name at periods and store in array
		local names = {}
		local name_it = full_name:gmatch"%.?([^%.]*)"
		for sub_name in name_it do
			table.insert(names, sub_name)
		end
	
		return names
	end
	
	
	--// Returns first part of NPC name up to first period charcter
	function npc_meta:get_name_id()
		local full_name = self:get_name()
		return full_name:match"^(.+)%.%d+$" or full_name
	end
	
	
	--// Creates a text bubble displayed above NPC's head with text given by text_key.
	--// Text bubble is removed after 2.5 seconds
		--arg1 text_key (string): strings.dat key to get native language text to display in bubble
	function npc_meta:bubble_text(text_key)
		assert(type(text_key)=="string", "Bad argument #1 to 'bubble_text' (string expected, got "..type(text_key)..")")
		local text = sol.language.get_text(text_key) or text_key
		
		local map = self:get_map()
		if not map then return end
		
		local bubble = text_bubble.create(text)
		
		map:add_bubble(self, bubble) --replaces existing
	end
	

	--// Returns the npc name (string) that "owns" this npc (e.g. if interacting with a bed, returns the name of the npc who sleeps there)
	local slave_names = {proxy=true, bed=true} --full names beginning with these sub_names have an owner npc as the second sub_name
	function npc_meta:get_owner_name()
		local names = self:split_names()
	
		if slave_names[ names[1] ] then --has owner
			local owner_name = names[2]
			if npcs[owner_name] then return owner_name end
		end
	
		return false --valid owner name not found
	end
	
	
	--// Returns display name (string) for NPC
		--arg1 is_substitution (boolean, default false): if false then substitutes for $a or $A article(s) now
		--ret1 (string): NPC display name
	function npc_meta:get_display_name(is_substitution)
		local full_name = self:get_name()
		local name_id = self:get_name_id()
		local info = npcs[name_id] or {}
		
		--determine which string_id to use for name (depending on whether NPC is a stranger or not)
		local string_id
		if type(info.stranger_save_val)=="string" and game.expression_check(info.stranger_save_val, "save_val") then --use info.stranger_name
			string_id = info.stranger_name or "NPC.name."..name_id
		else string_id = "NPC.name."..name_id end
		
		local display_name
		if is_substitution then
			display_name = sol.language.get_string(string_id)
		else display_name = util.get_string_article(string_id) end
		if not display_name then return false end
		
		return display_name
	end
	
	
	--// Returns path for image file to use as this NPC's portrait
		--ret1 (string): file name including path (.png file)
	function npc_meta:get_portrait()
		local name_id = self:get_name_id()
	
		local portrait = npcs[name_id] and npcs[name_id].portrait
		if not portrait then
			local owner_name = self:get_owner_name()
			portrait = npcs[owner_name] and npcs[owner_name].portrait
		end
	
		return type(portrait)=="string" and string.format("npc/portraits/%s.png", portrait)
	end
	
	
	--// Called when the player interacts with this NPC.
	--// Determines which action to take, such as starting the conversation dialog.
	local sleep_bubble --save reference to text_bubble so only loaded once ("Hey! Out of my bed!")
	function npc_meta:on_interaction()
		local npc_id = self:get_name_id()
		local entity = self --the entity the player is interacting with; redefine later if interacting with proxy
		
		if not npcs[npc_id] then --not interacting with a person
			local split_names = self:split_names()
			local owner_name = split_names[2]
			
			local map = game:get_map()
			local npc_owner = map and map:get_entity(owner_name)
			if npc_owner then
				if split_names[1]=="proxy" then
					if not npc_owner or not npc_owner:is_enabled() then return end --owner isn't around to interact with
					
					npc_id = owner_name
					entity = npc_owner
				end
			end
		end
		
		if npcs[npc_id] then --this is a person; if previously interacting with proxy, npc_id may now be valid person
			if not entity.is_sleeping then
				local npc_name = entity:get_display_name(true)
				
				--print message to console that the player is talking to npc
				local console_str = util.get_string_article("console.interact_npc", npc_name)
				if console_str then console:print(console_str) end
				
				local dlg = game.conv:get_topic_response(entity)
				game:start_dialog(dlg)
			else console:print(sol.language.get_string"console.sleeping") end --cannot interact if sleeping
		end
	end
	
	
	-----------------------------
	-- Custom Entity Metatable --
	-----------------------------

	local custom_entity_meta = sol.main.get_metatable"custom_entity"

	custom_entity_meta.split_names = npc_meta.split_names
	custom_entity_meta.get_name_id = npc_meta.get_name_id
	
	
	--// Called when the player interacts with this custom entity.
	--// Determines which action to take (e.g. opens sleep dialog when interacting with a bed)
	function custom_entity_meta:on_interaction()
		local npc_id = self:get_name_id()
		local entity = self
	
		if not npcs[npc_id] then --not interacting with a person
			local split_names = self:split_names()
			local owner_name = split_names[2]
		
			local map = game:get_map()
			local npc_owner = map and map:get_entity(owner_name)
			if split_names[1]=="bed" then --interacting with bed
				if npc_owner and npc_owner.is_sleeping then --can't use bed because the owner is sleeping there
					console:print(sol.language.get_string"console.bed_occupied")
				elseif owner_name == "inn" and not game:get_value"crito_bed_pending" then --inn bed that player hasn't paid for
					console:print(sol.language.get_string"console.bed_unpaid")
				else --player can use bed
					local console_str = util.get_string_article("console.interact_item", sol.language.get_string"item.bed" or "???")
					console:print(console_str)
				
					--show sleep dialog to choose how long to sleep in bed
					game:start_dialog("sleep.use_bed", nil, function(new_time)
						if not new_time then return end
					
						local new_time_num = game.clock:next_time(new_time)
						local sleep_time = npcs[owner_name] and npcs[owner_name].sleep_time --time bed owner returns to bed
					
						--// first check if npc who owns the bed will return before player's chosen time
					
						if sleep_time then
							local sleep_time_num = game.clock:next_time(sleep_time)
							sleep_time_num = game.clock:get_time_val(sleep_time_num)
						
							if game.clock:get_time_val(new_time_num) >= sleep_time_num then --owner will interrupt sleep
								game.clock:set_time(sleep_time) --advance time only to when owner appears
								console:print(sol.language.get_string"console.bed_kicked")
							
								sleep_bubble = sleep_bubble or text_bubble.create(sol.language.get_string"bubble.out_of_bed" or "#@$!")
								local map = self:get_map()
								if not map then return end
							
								sol.timer.start(map, 1000, function() map:add_bubble(self, sleep_bubble) end) --wait until after fade in/out to display
							
								return
							end
						end
					
						--// otherwise player sleeps until their chosen time
					
						game.clock:set_time(new_time) --advance time
					
						local sleep_str --string to display in console describing how player slept
						if owner_name == "inn" then --player slept in inn bed
							sleep_str = sol.language.get_string"console.bed_inn"
							game:set_value("crito_bed_pending", nil)
						else sleep_str = sol.language.get_string"console.bed_unrest" end
					
						sol.timer.start(map, 1000, function() console:print(sleep_str, true) end) --wait until after fade in/out to display
					end)
				end
			end
		end
	end
end


-------------------
-- Map Metatable --
-------------------

local map_meta = sol.main.get_metatable"map"


--// Draws a text bubble over specified NPC's head
	--arg1 npc (sol.npc): npc entity to draw the text bubble above
	--arg2 bubble
	--arg3 is_overwrite (boolean, default true): If false and there is already a speech bubble then does nothing
		--if true then the new bubble replaces the old bubble
function map_meta:add_bubble(npc, bubble, is_overwrite)
	if not self:get_game() then return end --exit if map is not running
	
	self.bubbles = self.bubbles or {} --list of text bubbles displayed on this map
	local bubbles = self.bubbles --convenience
	
	--abort previous timer if running
	if bubbles[npc] then
		if is_overwrite==false then return end --skip bubble creation if one already exists for this npc
		if bubbles[npc].timer then bubbles[npc].timer:stop() end
	end
	
	bubbles[npc] = { --replace existing entry
		bubble = bubble,
		timer = sol.timer.start(self, 2500, function()
			bubbles[npc] = nil --remove bubble
		end),
	}
end


--// Draw function to handle drawing text bubbles
map_meta:register_event("on_draw", function(self, dst_surface, ...)
	for npc,bubble_info in pairs(self.bubbles or {}) do
		local pos_x,pos_y = npc:get_position() --get origin
		if bubble_info.bubble and npc.is_enabled and npc:is_enabled() then
			self:draw_visual(bubble_info.bubble, pos_x, pos_y-36)
		end
	end
end)


setmetatable(npc_manager, {__call = npc_manager.initialize}) --convenience

return npc_manager


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
