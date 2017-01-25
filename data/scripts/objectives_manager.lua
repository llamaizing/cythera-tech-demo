--[[ objectives_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script keeps track of the active list of objectives, and marks them as completed.
	Call objectives:refresh() to update the status of the objectives whenever any savegame
	variables change value.
]]

local objectives_manager = {}

local objectives_list = require"scripts/objectives.dat"
local uix = require"scripts/lib/uix/ui_express"

--TODO support for substitutions in objectives titles and update active objective titles when refreshed

--// Creates the objectives list
	--arg1 game (sol.game): The current game (used to check status of savegame variables)
	--arg2 list (table): list to display objectives
		--a button for each objective is created and added to the list by calling list:new_entry(button)
function objectives_manager.create(game, list)
	local objectives = {}
	local list = list or {}
	game.objectives = objectives
	
	local inactive_objectives = {}
	local active_objectives = {}
	local complete_objectives = {}
	
	
	---------------------
	-- Local Functions --
	---------------------
	
	local function is_active(obj)
		return game.expression_check(obj.availability, "save_val")
	end
	
	local function is_complete(obj)
		return game.expression_check(obj.requirements, "save_val")
	end
	
	local function print_objective(button)
		local id = button.id
		if not id then return end
		
		local desc = sol.language.get_string("objective."..id..".desc")
		if desc then console:print(desc) end
	end
	
	local function objectives_complete_dlg()
		game:start_dialog("question.objectives_complete", nil, function(button_pressed)
			game:set_paused(false) --unpause

			--if button_pressed==1 then --(do nothing)
			if button_pressed==3 then --new game
				game.new_game()
			end
		end)
	end
	
	--settings to use for buttons in objectives list
	local new_button_info = {
		style = "togglebutton",
		width = 264,
		height = 16,
		text = "",
		on_clicked = function(button, new_state)
			print_objective(button)
			return false --prevent button state from changing when clicked
		end,
	}
	local function new_button(obj)
		new_button_info.text = sol.language.get_string("objective."..obj.id..".title") or "???"
		local button = uix.button(new_button_info)
		button.id = obj.id
		
		return button
	end
	
	--// Initialization
	
	--start with all objectives inactive
	for id,obj in pairs(objectives_list) do
		obj.id = id --save reference to id inside objectives table
		obj.status = "INACTIVE"
		table.insert(inactive_objectives, id)
	end
	
	
	--------------------
	-- Implementation --
	--------------------
	
	--// Returns the description string for the objective with the specified id
		--arg1 id (string): id for the objective to get the description of
		--ret1 (string): description for objective; returns false if id is invalid
	function objectives:get_desc(id)
		if objectives_list[id] then --id is valid
			return sol.language.get_string("objective."..id..".desc")
			--TODO make any substitutions before returning desc
		else return false end
	end
	
	
	--// Returns the current status of the objective with the specified id
		--arg1 id (string): id for the objective to get the status of
		--ret1 (string): current status for objective
			--possible values are "INACTIVE", "ACTIVE" or "COMPLETE"
			--returns false if id is invalid
	function objectives:get_status(id)
		if objective_list[id] then --id is valid
			return objective_list[id].status
		else return false end
	end
	
	
	--// Updates objective list to show each objective if available, show checkmark if complete
	function objectives:refresh()
		--move newly available objectives from inactive to active
		for i=#inactive_objectives,1,-1 do --iterate backwards so entries can be removed
			local obj_id = inactive_objectives[i]
			local obj = objectives_list[obj_id]
			
			if is_active(obj) then
				table.insert(active_objectives, obj_id)
				table.remove(inactive_objectives, i)
				obj.status = "ACTIVE"
				
				obj.button = new_button(obj) --create button for this objective
				if list.new_entry then list:new_entry(obj.button) end --add button to list
				
				--print message to console that objective is started if string present in strings.dat
				local started_text = sol.language.get_string("objective."..obj.id..".started")
				if started_text then console:print(started_text) end
			end
		end
		
		--move newly complete objectives from active to complete
		for i=#active_objectives,1,-1 do --iterate backwards so entries can be removed
			local obj_id = active_objectives[i]
			local obj = objectives_list[obj_id]
			
			if is_complete(obj) then
				table.insert(complete_objectives, obj_id)
				table.remove(active_objectives, i)
				obj.status = "COMPLETE"
				
				obj.button:set_state(true) --marks objective complete with check mark
				
				--print message to console the objective is complete if string present in strings.dat
				local done_text = sol.language.get_string("objective."..obj.id..".done")
				if done_text then console:print(done_text) end
				
				if obj.on_complete then obj.on_complete(obj_id) end --call on_complete() callback
				
				local is_all_complete = true
				for _,obj in pairs(objectives_list) do
					if obj.status ~= "COMPLETE" then is_all_complete = false end
				end
				
				if is_all_complete then
					if game:is_dialog_enabled() then
						game:queue_dialog(objectives_complete_dlg)
					else objectives_complete_dlg() end
				end
			end
		end
		
		--TODO sort active_objectives and complete_objectives by weight
	end
	
	objectives:refresh() --refresh for first time during initialization
	
	return objectives
end

return objectives_manager


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
