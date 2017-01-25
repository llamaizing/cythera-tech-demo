--[[ frame.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a surface image from a source file that gets resized and tiled for
	the repeating portions of the image. Up to two source images may be used (foreground &
	background), each with independent blend modes and/or opacity.
	
	Valid styles:
	  * simpleframe: basic border with no fill (default)
	  * dialogframe: semi-transparent blue background with border
	  * textframe: used in alert messages
	  * mapframe: border to draw around the map camera view
	  * titlebarframe:
	  * highlightframe:
]]

local frame = {}

local ui_draw = require"scripts/lib/uix/ui_draw"
local styles = require"scripts/lib/uix/controls/frame.dat"


--// Creates and returns a new frame object
	--arg1 properties (table): list of properties defining the frame; contains the following keys:
		--style (string, default "simpleframe"): style of the frame, uses pre-defined properties
		--img_x
		--img_y
		--img_width
		--img_height
		--width (number, positive, default 128): width of the frame in pixels
		--height (number, positive, default 24): height of the frame in pixels
		--is_visible (boolean, default true): if false then frame is not drawn
		--is_enabled (boolean, default true): --TODO currently has no effect
	--arg1 properties (sol.surface): equivalent to table that only uses the surface key
	--ret1 (table): the newly created frame object
function frame.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "simpleframe"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local width = math.floor(tonumber(properties.width) or 0)
	local height = math.floor(tonumber(properties.height) or 0)
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	local fm = {x=0, y=0} --table to be returned
	local surface = sol.surface.create(width, height)
	local surfaces = {} --intermediate surface for each layer
	
	--generate intermediate surfaces
	for i,surface_info in ipairs(style_info) do
		if surface_info.img then --create a surface from an image
			local is_hollow = surface_info.is_hollow
			if is_hollow==nil then is_hollow = style_info.is_hollow end
			
			table.insert(surfaces, ui_draw.load_frame{
				path = surface_info.img,
				src_x = surface_info.img_x or style_info.img_x or 0,
				src_y = surface_info.img_y or style_info.img_y or 0,
				src_width = surface_info.img_width or style_info.img_width,
				src_height = surface_info.img_height or style_info.img_height,
				width = width,
				height = height,
				border = surface_info.border or style_info.border,
				is_hollow = is_hollow,
			})
		elseif surface_info.color then --create a new surface and fill with color
			local new_surface = sol.surface.create(width, height)
			new_surface:fill_color(
				surface_info.color,
				surface_info.color_x,
				surface_info.color_y,
				surface_info.color_width,
				surface_info.color_height
			)
			
			table.insert(surfaces, new_surface)
		end
	end
	
	local parent
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	local needs_refresh = true
	
	--// Surface methods
	
	function fm:get_size() return surface:get_size() end
	
	function fm:get_xy() return self.x, self.y end
	function fm:set_xy(x, y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function fm:get_blend_mode() return surface:get_blend_mode() end
	function fm:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function fm:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function fm:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	function fm:get_movement() return surface:get_movement() end
	function fm:stop_movement() return surface:stop_movement() end
	function fm:start_movement(movement, callback)
		assert(sol.main.get_type(movement)=="movement", "Bad argument #1 to 'start_movement' (sol.movement expected, got "..sol.main.get_type(movement)..")")
		assert(not callback or type(callback)=="function", "Bad argument #2 to 'start_movement' (function or nil expected, got "..type(callback)..")")
		
		movement:start(surface, callback)
	end
	
	function fm:get_opacity() return surface:get_opacity() end
	function fm:set_opacity(opacity) return surface:set_opacity(opacity) end
	
	--//
	
	function fm:get_parent() return parent end
	function fm:set_parent(new_parent) parent = new_parent end
	
	--// Returns true if control is visible, else returns false
	function fm:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function fm:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if control is enabled, else returns false
	function fm:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function fm:set_enabled(enabled) --NOTE: enabling/disabling doesn't do anything
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out)
		end
	end
	
	
	--// Returns true if the control needs to be refreshed before next draw
	function fm:is_needs_refresh() return needs_refresh end
	--// Calling this function forces the control to be refreshed before the next draw
	function fm:needs_refresh()
		needs_refresh = true
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	function fm:refresh()
		surface:clear()
		
		for _,surface_i in ipairs(surfaces) do
			surface_i:draw(surface)
		end
	end
	
	function fm:draw(dst_surface, x, y)
		x = tonumber(x) or 0
		y = tonumber(y) or 0
		
		if needs_refresh then self:refresh() end --not really any ways to trigger refresh at present
		if is_visible then surface:draw(dst_surface, self.x + x, self.y + y) end
	end
	
	return fm
end

return frame


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
