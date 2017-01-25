--[[ savegame_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/

	This script initializes a game loaded from a save file.
]]

local savegame = {}

local initial = require"scripts/initial_game.dat" or {}

function savegame:load(game)
	local time = initial.starting_time or {} --convenience; default starting time
	
	--use saved time values instead of default if they exist
	time.day = game:get_value"day" or time.day
	time.hour = game:get_value"hour" or time.hour
	time.minute = game:get_value"minute" or time.minute
	
	game.starting_time = time --save reference to starting time for when game clock is initialized
	
	--validate and set language
	local language = game:get_value"language"
	local is_valid_language = pcall(sol.language.get_language_name, language)
	assert(is_valid_language, "Invalid savedata value for 'language'")
	sol.language.set_language(language)
	
	--validate and set player gender
	local gender = game:get_value"player_gender"
	assert(game:set_gender(gender), "Invalid savedata value for 'player_gender'")
end


setmetatable(savegame, {__call = savegame.load}) --convenience

return savegame


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
