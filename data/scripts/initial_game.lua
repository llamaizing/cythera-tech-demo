--[[ initial_game.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script loads initial_game.dat, which is used to specify the initial conditions of
	the player when starting a new game.
]]

local initial_game = {}

--TODO magic, max_magic, and items table
--// Sets the starting conditions of the player
	--arg1 game (sol.game): the current game
function initial_game:initialize(game)
	--// Load inital values from initial_game.dat
	
	local data = require"scripts/initial_game.dat" or {}
	
	--validate language value
	assert(type(data.language)=="string", "Value for 'language' in 'initial.dat' is wrong type (string expected, got "..type(data.language)..")")
	local is_valid_language = pcall(sol.language.get_language_name, data.language)
	assert(is_valid_language, "Value for 'language' in 'initial.dat' is not a valid language code")
	
	--set language
	sol.language.set_language(data.language)
	game:set_value("language", data.language)
	
	--validate and set player gender
	assert(type(data.player_gender)=="string", "Value for 'player_gender' in 'initial.dat' is wrong type (string expected, got"..type(data.player_gender)..")") 
	assert(game:set_gender(data.player_gender), "Value for 'player_gender' is not valid")
	game:set_value("player_gender", data.player_gender)
	
	--set default name for player
	game:set_value("player_name", sol.language.get_string"player.default_name")
	
	--validate and set starting location
	assert(type(data.starting_map)=="string", "Value for 'starting_map' in 'initial.dat' is wrong type (string expected)")
	assert(type(data.starting_location)=="string","Value for 'starting_location' in 'initial.dat' is wrong type (string expected)")
	game:set_starting_location(data.starting_map, data.starting_location)
	
	--validate and set max life
	local max_life = tonumber(data.max_life)
	assert(max_life, "Value for 'max_life' in 'initial.dat' is wrong type (number expected)")
	max_life = math.max(math.floor(max_life), 1)
	game:set_max_life(max_life)
	
	--set life
	data.life = math.floor(tonumber(data.life) or max_life)
	game:set_life(data.life)
	
	--validate and set max money
	local max_money = tonumber(data.max_money)
	assert(max_money, "Value for 'max_money' in 'initial.dat' is wrong type (number expected)")
	max_money = math.max(math.floor(max_money), 0)
	game:set_max_money(max_money)
	
	--set money
	data.money = math.floor(tonumber(data.money) or 0)
	game:set_money(data.money)
	
	--set starting time
	game.starting_time = data.starting_time or {} --save reference to starting time for when game clock is initialized
	
	--set values
	for savegame_variable,value in pairs(data.values or {}) do
		game:set_value(savegame_variable, value)
	end
	
	--set abilities
	for ability,value in pairs(data.abilities or {}) do
		game:set_ability(ability, value)
	end
end

setmetatable(initial_game, {__call = initial_game.initiialize}) --convenience

return initial_game


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
