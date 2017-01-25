--[[ text_bubble.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a text bubble to place over the head of an NPC so that they appear
	to be talking. Create a bubble instance with text_bubble.create(), and then draw it on
	the map with map:draw_visual(drawable, x, y), where the text_bubble instance is passed
	as the drawable parameter.
]]

local text_bubble = {}

local bubble_left = sol.surface.create"/menus/bubble_left.png"
local bubble_right = sol.surface.create"/menus/bubble_right.png"
local offset_x,size_y = bubble_right:get_size()
local _,height = bubble_left:get_size()


--// Creates and returns a surface with the bubble image and text pre-drawn
	--arg1 text (string): text to display in the text bubble
	--arg1 can also be a table with properties matching sol.text_surface.create()
	--ret1 (sol.surface): pre-drawn text bubble
function text_bubble.create(text)
	assert(type(text)=="string" or type(text)=="table", "Bad argument #1 to 'create' (string expected, got "..type(text)..")")
	
	local bubble_text --text surface containing the bubble text
	if type(text)=="string" then
		bubble_text= sol.text_surface.create{
			vertical_alignment = "top",
			horizontal_alignment = "center",
			font = "minecraftia",
			font_size = 7,
			color = {0, 0, 0},
			text = text,
		}
	else bubble_text = sol.text_surface.create(text) end
	
	local text_width = bubble_text:get_size()
	local text_bg = sol.surface.create(text_width, size_y) --rectangular image between end pieces that text is overlayed on
	
	--fill white with 1px black border top and bottom
	text_bg:fill_color{0,0,0}
	text_bg:fill_color({255, 255, 255}, 0, 1, text_width, size_y-2)
	
	local bubble = sol.surface.create(2*offset_x + text_width, height) --surface containing entire bubble and text
	
	bubble_left:draw(bubble)
	bubble_right:draw(bubble, offset_x + text_width, 0)
	bubble_text:draw(text_bg, math.floor(text_width/2),1)
	text_bg:draw(bubble, offset_x, 0)
	
	return bubble
end

return text_bubble

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
