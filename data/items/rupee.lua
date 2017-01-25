-- Lua script of item rupee
-- This script is executed only once for the whole game

local item = ...
local game = item:get_game()

-- Called when script is created
function item:on_created()
	self:set_shadow"small"
	self:set_can_disappear(true)
	self:set_brandish_when_picked(false)
	self:set_sound_when_picked"picked_rupee"
end

function item:on_obtaining(variant, savegame_variable)
	local amounts = {1, 5, 20}
	local amount = amounts[variant]
	assert(amount, "Invalid variant '"..tostring(variant).."' for item 'rupee'")
	
	game:add_money(amount)
end