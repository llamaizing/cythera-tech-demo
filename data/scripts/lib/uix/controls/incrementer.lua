--[[ incrementer.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates an incrementer compound control comprised of a text_label with two
	arrow buttons, one at each end. The buttons increase or decrease the number value that
	is displayed by the text_label.
	
	Valid styles:
	  * TBD: 
]]

local incrementer = {}

local ui_draw = require"scripts/lib/uix/ui_draw"
local styles = require"scripts/lib/uix/controls/incrementer.dat"

local alignment_offsets = {
	left = 0,
	center = 0.5,
	right = 1,
	top = 0,
	middle = 0.5,
	right = 1,
}


--// Creates and returns a new button surface. properties is a table with the following keys:
	--style (string, default "textbutton"): style of button, determines image used
		--valid styles: "textbutton", "logbutton", "togglebutton"
	--width (number, positive, default 128): width of the button in pixels
	--height (number, positive, default 24): height of the button in pixels
	--is_set (boolean, default false): Toggle/radio buttons only, if true then button starts in set state
	--is_enabled (boolean, default true): Prevents interaction if false (disabled)
	--is_visible (boolean, default true): Button is not drawn if false (cannot interact with while hidden)
	--on_clicked (function): Action to perform when button clicked
	
	--The following properties are only used if the button uses text
	--horizontal_alignment (string, default center)
	--vertical_alignment (string, default middle)
	--font (string, default "librefranklin-bold")
	--font_size (number, default 14)
	--rendering_mode (string, default antialiasing)
	--color (table, default black)
	--text (string)
	--text_key (string)
function incrementer.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "textbox"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local width = math.floor(tonumber(properties.width) or tonumber(style_info.width) or 0) --TODO should this default to the style image size?
	local height = math.floor(tonumber(properties.height) or tonumber(style_info.height) or 0)
	local min = tonumber(properties.minimum)
	local max = tonumber(properties.maximum)
	local inc = tonumber(properties.increment) or 1
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
		
	local button_width = tonumber(properties.button_width) or tonumber(style_info.button_width) or 0
	local button_height = math.floor(height/2)
	
	local control = {x=0, y=0} --table to be returned
	local surface = sol.surface.create(width, height)
	
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	
	local value = tonumber(properties.value) or 0
	value = min and math.max(value, min) or value
	
	--local on_position_changed = function(value) end
	
	local text_box = incrementer.uix("text_label", {
		style = style_info.text_label,
		width = width - button_width,
		height = height,
		text = "1",
		on_position_changed = on_position_changed,
	})
	local button_up = incrementer.uix("button", {
		style = style_info.button_up,
		width = button_width,
		height = button_height,
		on_clicked = function() control:add(inc) end,
	})
	local button_down = incrementer.uix("button", {
		style = style_info.button_down,
		width = button_width,
		height = height-button_height, --to account for any rounding error
		on_clicked = function() control:add(-1*inc) end,
	})
	
	--// Add drawable methods to control
	
	function control:get_size() return surface:get_size() end
	
	function control:get_xy() return self.x, self.y end
	function control:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function control:get_blend_mode() return surface:get_blend_mode() end
	function control:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function control:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function control:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	
	--// Gets and sets menu where this text_prompt is used (determines lifetime of cursor_timer)
	--TODO needs own get/set_menu() functions?
	--function control:get_menu() return text_box:get_menu() end
	--function control:set_menu(new_menu) text_box:set_menu(new_menu) end
	
	
	--// Gets and sets the value that the slider is currently set to
	function control:get_value() return value end
	function control:set_value(new_value)
		--TODO set value function
	end
	
	
	--// Returns true if control is visible, else returns false
	function control:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function control:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if control is enabled, else returns false
	function control:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function control:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			
			--change enabled status of subcomponents too
			text_box:set_enabled(enabled)
			button_up:set_enabled(enabled)
			button_down:set_enabled(enabled)
		end
	end
	
	
	--//
	function control:get_value()
		return value
	end
	
	
	function control:set_value(new_value)
		new_value = tonumber(new_value)
		if new_value then
			value = math.min(math.max(new_value, min), max)
			text_box:set_text(value) --truncate if text exceeds bounds 
		end
	end
	
	
	--// Adds (or subtracts if negative) amount to value
	function control:add(amount)
		amount = tonumber(amount) --TODO force to be multiple of increment?
		if amount then
			value = value + amount
			
			if min then value = math.max(value, min) end
			if max then value = math.min(value, max) end
			
			text_box:set_text(value) --truncate if text exceeds bounds
		end
	end
	
	
	--// Called when mouse button is pressed while cursor is over control
		--arg1 mouse_button (string): name of the mouse button pressed
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of control
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of control
	function control:on_mouse_pressed(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			--send on_mouse_pressed event to subcomponent
			if x > width - button_width then --clicked a button
				if y > button_height then --clicked up button
					button_down:on_mouse_pressed(mouse_button, x - width + button_width, y - button_height)
				else --clicked down button
					button_up:on_mouse_pressed(mouse_button, x - width + button_width, y)
				end
				
				return true
			end
		end
	end
	
	
	--// Called whenever mouse button is released. If mouse cursor is not over the control
	--// at time of release then x & y are nil
		--arg1 mouse_button (string): name of the mouse button released
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of control
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of control
	function control:on_mouse_released(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			if x and y then --mouse cursor within button bounds
				--send event to subcomponent
				if x > width - button_width then
					if y > button_height then --clicked up button
						button_down:on_mouse_released(mouse_button, x - width + button_width, y - button_height)
					else --clicked down button
						button_up:on_mouse_released(mouse_button, x - width + button_width, y)
					end
					
					return true
				end
			else
				--send event to all subcomponents
				--text_box:on_mouse_released(mouse_button) --not necessary; does not handle mouse events
				button_up:on_mouse_released(mouse_button)
				button_down:on_mouse_released(mouse_button)
			end
		end
	end
	
	
	--// Replaces existing function; before draw, check if needs refresh first
	function control:draw(dst_surface, x, y)
		if is_visible then
			--check if subcomponents need refresh
			local needs_refresh = text_box:is_refresh()
			needs_refresh = button_up:is_refresh() or needs_refresh
			needs_refresh = button_down:is_refresh() or needs_refresh
			
			--redraw surface if there was a refresh
			if needs_refresh then
				surface:clear()
				
				text_box:draw(surface, 0, 0)
				button_up:draw(surface, width - button_width, 0)
				button_down:draw(surface, width - button_width, button_height)
			end
			
			surface:draw(dst_surface, self.x+x, self.y+y)
		end
	end
	
	return control
end

return incrementer


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
