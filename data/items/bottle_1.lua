-- Lua script of item bottle
-- This script is executed only once for the whole game

local item = ...
local game = item:get_game()

-- Called when script is created
function item:on_created()
	self:set_shadow(nil)
	self:set_can_disappear(false)
	self:set_brandish_when_picked(true)
	self:set_sound_when_picked"treasure"
end
