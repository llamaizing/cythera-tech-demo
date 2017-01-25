-- Lua script of map shack.
-- This script is executed every time the hero enters this map.

local map = ...
local game = map:get_game()

map.lighting = "inside"
map.music = {
	day = "village",
	night = "credits",
}

map:register_event("on_started", function()
	if game:get_value"possession_candle" then candle:set_enabled(false) end
end)

function candle:on_interaction()
	hero:start_treasure"candle"
	
	local text = sol.language.get_string"item.candle.obtained"
	if text then console:print(text) end
	
	candle:set_enabled(false)
end