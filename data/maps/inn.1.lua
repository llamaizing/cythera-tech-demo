-- Lua script of map tavern.
-- This script is executed every time the hero enters this map.

local map = ...
local game = map:get_game()

map.lighting = "inside"
map.music = {
	day = "village",
	night = "credits",
}

map:register_event("on_started", function()
	if game:get_value"possession_bottle_1" then bottle:set_enabled(false) end
end)

function map:on_obtaining_treasure(treasure_item, treasure_variant, treasure_savegame_variable)
	if treasure_item:get_name() == "bottle_1" and treasure_variant==1 then
		bottle:set_enabled(false)
	end
end