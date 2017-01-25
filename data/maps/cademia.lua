-- Lua script of map cademia.
-- This script is executed every time the hero enters this map.

local map = ...
local game = map:get_game()

map.lighting = "outside"
map.music = {
	day = "village",
	night = "credits",
}

local text_bubble = require"scripts/text_bubble"
local ui_draw = require"scripts/lib/uix/ui_draw"

local bubble_go_away --surface containing Neoptolemus' speech bubble; create once when map loaded
local is_bubble --Show Neoptolemus' speech bubble while true
local repeat_timer --shows bubble again after delay if player doesn't leave yard


----------------
-- Map Events --
----------------

--// Event called at initialization time, as soon as this map is loaded
map:register_event("on_started", function()
	--create bubble text for Neoptolemus
	local go_away_text = sol.language.get_dialog"Neoptolemus.go_away" --"Get off my yard!"
	go_away_text = go_away_text and go_away_text.text:match"^([^\n]*)" or "@#$!" --get first line of text
	bubble_go_away = text_bubble.create(go_away_text)
end)


-------------------
-- Sensor Events --
-------------------

--// Player entered Neoptolemus' yard
function yard:on_activated()
	--display bubble text if Neoptolemus is present on the map
	if Neoptolemus:is_enabled() then
		map:add_bubble(Neoptolemus, bubble_go_away, false) --replaces existing
	end
end

--// While player stays in Neoptolemus' yard, periodically restart his speech bubble
function yard:on_activated_repeat()
	if not repeat_timer and Neoptolemus:is_enabled() then
		repeat_timer = sol.timer.start(map, 8000, function()
			self:on_activated()
			repeat_timer = nil
		end)
	end
end

--// When player leaves Neoptolemus' yard, stop repeat_timer
function yard:on_left()
	if repeat_timer then repeat_timer:stop() end
	repeat_timer = nil
end