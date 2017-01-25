-- Lua script of item candle.

local item = ...
local game = item:get_game()

function item:on_created()
	self:set_savegame_variable"possession_candle"
	self:set_assignable(false) --passive usage
end

function item:on_obtained(variant, savegame_variable)
end
