--[[ image_view.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a drawable object that gets linked to another surface to be drawn.
	The linked surface can be swapped out for a different one dynamically at run-time. The
	control can be hidden/shown by using the :set_visible() function.
]]

local image_view = {}

--// Creates and returns a new image_view instance
	--arg1 properties (table): list of properties defining the image_view; contains the following keys:
		--surface (sol.surface, default nil): source surface to use for image
		--width (number, positive, default source image width): width of image in pixels
		--height (number, positive, default source image height): height of image in pixels
		--x (number, positive, default 0): x coordinate of where to get the upper-left corner of the source image
		--y (number, positive, default 0): y coordinate of where to get the upper-left corner of the source image
		--on_clicked (function): action to perform when control clicked with mouse
	--arg1 properties (sol.surface): equivalent to table that only uses the surface key
	--ret1 (table): the newly created image_view object
function image_view.create(properties)
	--if arg1 is a surface, convert to table format
	if sol.main.get_type(properties)=="surface" then
		properties = {surface=properties}
	end
	
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local surface = properties.surface
	assert(not surface or sol.main.get_type(surface)=="surface", "Bad argument #1 to 'create' (surface value must be a sol.surface or nil)")
	
	local surface_width,surface_height
	if surface then surface_width,surface_height = surface:get_size() end
	
	local offset_x = math.floor(tonumber(properties.x) or 0)
	local offset_y = math.floor(tonumber(properties.y) or 0)
	local width = math.floor(tonumber(properties.width) or surface_width)
	local height = math.floor(tonumber(properties.height) or surface_height)
	
	assert(offset_x>=0, "Bad argument #1 to 'create' (x value must be positive number)")
	assert(offset_y>=0, "Bad argument #1 to 'create' (y value must be positive number)")
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	local on_clicked = properties.on_clicked or nil
	assert(not on_clicked or type(on_clicked)=="function", "Bad argument #1 to 'create' (on_clicked value must be a function or nil)")
	
	local iv = {x=0, y=0} --table to be returned
	
	local parent
	is_visible = properties.is_visible~=false
	is_enabled = properties.is_enabled~=false 
	is_mouse_down = false --true while mouse pressed over control
	
	iv.on_clicked = on_clicked --this function gets called when the control is clicked with mouse
	
	
	--// Gets the linked surface to draw
		--ret1 (sol.surface): surface to draw
	function iv:get_surface() return surface end
	--// Sets the linked surface to draw
		--arg1 new_surface (sol.surface): new surface to use
	function iv:set_surface(new_surface)
		assert(not new_surface or sol.main.get_type(new_surface)=="surface", "Bad argument #1 to 'set_surface' (sol.surface or nil expected, got "..sol.main.get_type(new_surface)..")")
		surface = new_surface
	end
	
	--// Add drawable methods to control
	
	function iv:get_size() return width,height end
	
	function iv:get_xy() return self.x, self.y end
	function iv:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function iv:get_blend_mode()
		if surface then return surface:get_blend_mode() end
	end
	function iv:set_blend_mode(blend_mode)
		if surface then surface:set_blend_mode(blend_mode) end
	end
	
	function iv:fade_in(delay, callback)
		if surface then surface:fade_in(delay, callback) end
	end
	function iv:fade_out(delay, callback)
		if surface then surface:fade_out(delay, callback) end
	end
	
	function iv:get_movement()
		if surface then return surface:get_movement() end
	end
	function iv:start_movement(movement, callback)
		if surface then movement:start(surface, callback) end
	end
	function iv:stop_movement()
		if surface then return surface:stop_movement() end
	end
	
	function iv:get_opacity()
		if surface then return surface:get_opacity() end
	end
	function iv:set_opacity(opacity)
		if surface then return surface:set_opacity(opacity) end
	end
	
	--// Implementation
	
	function iv:get_bounds() return offset_x, offset_y, width, height end
	function iv:set_bounds(new_width, new_height, x, y)
		--TODO nil values should not change value
		local surface_width,surface_height = surface:get_size()
		if surface then surface_width,surface_height = surface:get_size() end
		
		local new_width = math.floor(tonumber(new_width) or surface_width or 32)
		local new_height = math.floor(tonumber(new_height) or surface_height or 32)
		local x = math.floor(tonumber(x) or 0)
		local y = math.floor(tonumber(y) or 0)
		
		assert(new_width>0, "Bad argument #1 to 'set_bounds' (width value must be positive number)")
		assert(new_height>0, "Bad argument #2 to 'set_bounds' (height value must be positive number)")
		assert(x>0, "Bad argument #3 to 'set_bounds' (x value must be positive number)")
		assert(y>0, "Bad argument #4 to 'set_bounds' (y value must be positive number)")
		
		width, height, offset_x, offset_y = new_width, new_height, x, y
	end
	
	
	--// Parent control gets refreshed when this control is refreshed (compound controls only)
	function iv:get_parent() return parent end
	function iv:set_parent(new_parent) parent = new_parent end
	
	
	--// This control will not be drawn if not visible
		--ret1 (boolean): True if control is visible, else false
	function iv:get_visible() return is_visible end
		--arg1 visible (boolean, default true)
	function iv:set_visible(visible) is_visible = visible~=false end
	
	
	--// Returns true if control is enabled, else returns false
	function iv:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function iv:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out)
		end
	end
	
	--// Returns true if the control needs to be refreshed before next draw
	function iv:is_needs_refresh() return false end --never needs refresh
	--// Calling this function forces the control to be refreshed before the next draw
	function iv:needs_refresh()
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	--// Called when mouse button is pressed while cursor is on control
		--arg1 mouse_button (string): name of the mouse button pressed
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of the control
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of the control
	function iv:on_mouse_pressed(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		if mouse_button=="left" then is_mouse_down = true end	
	end
	
	
	--// Called whenever mouse button is released. If mouse cursor is not over the button
	--// at time of release then x & y are nil
		--arg1 mouse_button (string): name of the mouse button released
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of button
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of button
	function iv:on_mouse_released(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		local ret_val = false --assume false until proven otherwise
		if mouse_button=="left" then
			if x and y and is_mouse_down and self.on_clicked then --mouse cursor within bounds of control
				self:on_clicked()
				ret_val = true
			end
		
			is_mouse_down = false
		end
		
		return ret_val
	end
	
	
	--// Removes image surface so that nothing will be drawn
	function iv:clear() surface = nil end
	
	
	--// This control does not need to be refreshed and thus does nothing
	function iv:refresh() end
	
	
	--// Draws linked surface on the destination surface each frame
	function iv:draw(dst_surface, x, y)
		x = tonumber(x) or 0
		y = tonumber(y) or 0
		
		if not surface or not is_visible then return end
		surface:draw_region(offset_x, offset_y, width, height, dst_surface, x+self.x, y+self.y)
	end
	
	return iv
end

return image_view


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
