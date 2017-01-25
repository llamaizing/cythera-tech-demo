-- Lua script of map inn.2.
-- This script is executed every time the hero enters this map.

local map = ...
local game = map:get_game()

map.lighting = "inside"
map.music = {
	day = "village",
	night = "credits",
}
