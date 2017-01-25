--[[ game_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script manages starting a game (new or savegame), loading pertinent game scripts,
	and managing savegame data.
]]

local game_manager = {}

require"scripts/multi_events"
require"scripts/treasures"
require"scripts/hud/hud"

--function stack() print(debug.traceback()) end --DEBUG


--// Starts the game from the specified savegame file and initializes it
	--arg1 file_name (string): The name of the savegame file to load, or if doesn't exist then create and use it
function game_manager:start_game(file_name)
	local exists = sol.game.exists(file_name)
	local game = sol.game.load(file_name)
	
	local journal_file_name = file_name:match"^(.+)%.dat$".."_log.dat"
	
	--functions to get/set gender
	local gender
	local genders = {male=true, female=true} --possible values for gender
	function game:get_gender() return gender end
	function game:set_gender(gender_name)
		if genders[gender_name] then gender = gender_name end
		return gender
	end
	
	if not exists then
		require"scripts/initial_game.lua":initialize(game) --Initialize a new game
	else require"scripts/savegame_manager":load(game) end --Initialize existing game from save data
	
	--function SaveVal(id, val) --DEBUG
	--	game:set_value(id, val)
	--end
	
	
	--// initialize new game
	game:register_event("on_started", function(self)
		--initialize scripts
		require"scripts/util.lua":initialize(self)
		require"scripts/game_clock":initialize(self)
		require"scripts/npc_manager":initialize(self)
		require"scripts/dialog_manager":initialize(self)
		game.conv = require"scripts/conversation_manager":initialize(self)
		require"scripts/menus/hud":initialize(self)
		
		--load any saved journal text
		if sol.file.exists(journal_file_name) then
			local journal_file = sol.file.open(journal_file_name, "r")
			local text = journal_file:read"*all"
			game.journal:new_entry(text)
		end
		
		--// refreshes objectives after game save values are updated
			--usage: check_objectives(game:set_value(savegame_variable, value))
		local function check_objectives(...) --... are returns from game:set_value()
			game.objectives:refresh() --check if any objectives now met
			return ...
		end
		
		--// Any time save value is set, check if any objectives are now met
		local game_set_value_old = game.set_value
		function game:set_value(savegame_variable, value, ...)
			return check_objectives(game_set_value_old(self, savegame_variable, value, ...))
		end
		
		--// Any time game is saved, call game:set_value() first to save current time
		local game_save_old = game.save
		function game:save(...)
			--save current time
			local day,hour,minute = self.clock:get_time()
			game_set_value_old(self, "day", day) --save current time
			game_set_value_old(self, "hour", hour) --save current time
			game_set_value_old(self, "minute", minute) --save current time
			
			--save journal log
			local journal_file = sol.file.open(journal_file_name, "w")
			journal_file:write(game.journal:get_text() or "")
			journal_file:close()
			
			console:print"Game saved"
			
			return game_save_old(self, ...) --original save function
		end
		
		--sol.video.set_window_size(640, 384)
	end)
	
	
	--// Brings up question dialog with 3 options (save, cancel, new game)
	function game:on_paused()
		self:start_dialog("question.save_game", nil, function(button_pressed)
			self:set_paused(false) --unpause
			
			if button_pressed==1 then --yes
				self:save()
			--elseif button_pressed==2 then --cancel (do nothing)
			elseif button_pressed==3 then --new game
				self.new_game()
			end
		end)
	end
	
	function game:on_unpaused()
	end
	
	--// Deletes save data and starts new game
	function game.new_game()
		if sol.game.exists(file_name) then sol.game.delete(file_name) end --delete save data
		if sol.game.exists(journal_file_name) then sol.game.delete(journal_file_name) end --deleted saved log data
		
		self:start_game(file_name) --begin new game
	end
	
	--function Game() return game end --DEBUG

	game:start()
end


--// Loads an existing savegame file only, without starting the game.
--// Allows access to reading state of saved game values
function game_manager:read_game(file_name)
	local exists = sol.game.exists(file_name)
	local game = sol.game.load(file_name)
	
	return exists and game
end


--// Setup the map to be displayed in the upper-right corner of the screen (all maps)
local map_meta = sol.main.get_metatable"map"
map_meta:register_event("on_started", function(self, ...)
	local camera = self:get_camera()
	camera:set_size(320, 240)
	camera:set_position_on_screen(304,16)
end)


setmetatable(game_manager, {__call = game_manager.start_game}) --convenience

return game_manager


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
