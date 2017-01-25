-- Lua script of map neoptolemus_house.
-- This script is executed every time the hero enters this map.

local map = ...
local game = map:get_game()

map.lighting = "inside"
map.music = {
	day = "village",
	night = "credits",
}


--------------------
-- Input Handling --
--------------------

function map:on_mouse_pressed(button, x, y)
	if button=="left" and not game:is_suspended() then
		--// See if clicked on camera view
		
		--get camera coordinates
		local camera = map:get_camera()
		local cam_x,cam_y = camera:get_position_on_screen()
		local cam_offset_x,cam_offset_y,cam_w,cam_h = camera:get_bounding_box()
		
		--mouse coordinates relative to camera view
		local cx = x - cam_x
		local cy = y - cam_y
		
		--check if clicked on camera view
		if cx>=0 and cx<cam_w and cy>=0 and cy<cam_h then
			local map_x,map_y = cx + cam_offset_x, cy + cam_offset_y
			--local entity = self:get_entities_in_rectangle(map_x, map_y, 1, 1)() --only want top-most entity
			for entity in map:get_entities_in_rectangle(map_x, map_y, 1, 1) do
				print("clicked entity:", entity:get_name(), entity:get_type())
			end
		end
		
	end
end

local masks = {dim={}, dark={}}
for i=1,3 do
	table.insert(masks.dark, sol.surface.create("masks/lamp_96."..i..".png"))
	table.insert(masks.dim, sol.surface.create("masks/lamp_176."..i..".png"))
end
table.insert(masks.dark, sol.surface.create("masks/lamp_96.2.png"))
table.insert(masks.dim, sol.surface.create("masks/lamp_176.2.png"))

local bg = sol.surface.create(320,240)
bg:set_blend_mode"multiply"
local bg_edge  = sol.surface.create(320,240)
bg_edge:fill_color{0,0,0}
bg_edge:fill_color({255,255,255}, 16, 16, 288, 208)
bg_edge:set_blend_mode"multiply"
