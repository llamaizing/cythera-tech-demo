--[[ treasures.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script randomly selects a treasure from among a weighted list and spawns it after
	the player interacts with a destructible, chest, or enemy entity.
	
	Distributions for the items to be awarded are assigned in the treasures.dat file.
]]

local util = require"scripts/util.lua"
local treasure_sets, entity_sets = unpack(require"scripts/treasures.dat" or {})

--create function to randomly select treasure
for set_name,info in pairs(treasure_sets) do
	local total_count = 0
	local all_items = {}
	
	for i,item_info in ipairs(info) do
		local item_count = math.floor(tonumber(item_info[3] or 0))
		if item_count > 0 then
			total_count = total_count + item_count
			table.insert(all_items, {total_count, i})
		end
	end
	
	--arg1 entity: entity.set_treasure() must be defined (e.g. entity is a destructible, enemy or chest)
	function info.random_treasure(entity)
		assert(entity and type(entity.set_treasure)=="function", "Bad argument #1 to 'random_treasure' (must have a set_treasure method)")
		
		local item_index
		if total_count > 0 then
			local sel = util.random(total_count)
			for _,v in ipairs(all_items) do
				if sel <= v[1] then
					item_index = v[2]
					break
				end
			end
		end
		
		if item_index then
			local item_info = info[item_index] or {}
			local item_name = item_info[1] or nil
			local variant = item_name and item_info[2] or nil
			
			entity:set_treasure(item_name, variant)
		else entity:set_treasure() end --no treasure given
	end
end


--// Assigns a random treasure when a destructible entity is created
local destructible_meta = sol.main.get_metatable"destructible"
destructible_meta:register_event("on_created", function(self, ...)
	local name = self:get_name()
	if not name then return end
	
	local name_id = name:match"^([^%.]+)"
	if not name_id or name_id=="" then return end
	
	local set_name = entity_sets[name_id]
	
	assert(treasure_sets[set_name], "invalid destructible set name '"..tostring(set_name).."'")
	treasure_sets[set_name].random_treasure(self) --assigns random treasure to the destructible entity
end)


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
