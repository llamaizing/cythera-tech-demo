--[[ scrollbar.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a scrollbar compound control comprised of a slider control and two
	arrow buttons, one at each end. The scrollbar control can be linked in the same manner
	as a slider control.
	
	Valid styles:
	  * vertical: verticalbar slider with scrollbutton buttons (default)
	
	--TODO
	The menu that uses the button has to keep track of
	mouse events and call button:set_pressed() to change the button state (which updates
	the image used automatically for when button:draw() is called).
]]

local scroll_bar = {}

local ui_draw = require"scripts/lib/uix/ui_draw"

--TODO move this to a dat file
--// Info for each scrollbar style
	--slider (uix.slider)
	--button1 (uix.button)
	--button2 (uix.button)
local scrollbars = {
	vertical = {
		direction = "vertical",
		slider = "verticalbar",
		button1 = "scrollbuttonup",
		button2 = "scrollbuttondown",
		width = 16,
	},
}

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
function scroll_bar.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "vertical"
	local style_info = scrollbars[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local width = math.floor(tonumber(properties.width) or style_info.width or 0) --TODO should this default to the style image size?
	local height = math.floor(tonumber(properties.height) or style_info.height or 0)
	local direction = style_info.direction or "vertical"
	local on_clicked1 = properties.on_clicked1 or nil
	local on_clicked2 = properties.on_clicked2 or nil
	local on_position_changed = properties.on_position_changed or nil
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	assert(not on_clicked1 or type(on_clicked1)=="function", "Bad argument #1 to 'create' (on_clicked1 value must be a funtion or nil)")
	assert(not on_clicked2 or type(on_clicked2)=="function", "Bad argument #1 to 'create' (on_clicked2 value must be a funtion or nil)")
	assert(not on_position_changed or type(on_position_changed)=="function", "Bad argument #1 to 'create' (on_position_changed value must be a funtion or nil)")
	
	local slider_width = direction=="vertical" and width or width - 2*height
	local slider_height = direction=="vertical" and height - 2*width or height
	local button_length = direction=="vertical" and width or height --both height and width of button
	
	local sb = {x=0, y=0} --table to be returned
	local surface = sol.surface.create(width, height)
	
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	
	--local on_position_changed = function(value) end
	
	local slider = scroll_bar.uix("slider", {
		style = style_info.slider,
		width = sider_width,
		height = slider_height,
		on_position_changed = on_position_changed,
	})
	local button1 = scroll_bar.uix("button", {
		style = style_info.button1,
		width = button_length,
		height = button_length,
		on_clicked = on_clicked1,
	})
	local button2 = scroll_bar.uix("button", {
		style = style_info.button2,
		width = button_length,
		height = button_length,
		on_clicked = on_clicked2,
	})
	
	--// Add drawable methods to scrollbar
	
	function sb:get_size() return surface:get_size() end
	
	function sb:get_xy() return self.x, self.y end
	function sb:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function sb:get_blend_mode() return surface:get_blend_mode() end
	function sb:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function sb:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function sb:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	
	--// Gets and sets menu where this text_prompt is used (determines lifetime of cursor_timer)
	function sb:get_menu() return slider:get_menu() end
	function sb:set_menu(new_menu) slider:set_menu(new_menu) end
	
	
	--// Gets and sets the value that the slider is currently set to
	function sb:get_value() return slider:get_value() end
	function sb:set_value(new_value) slider:set_value(new_value) end
	
	
	--// TODO desc
	function sb:link_view(new_view) slider:link_view(new_view) end
	
	
	--// Returns true if scrollbar is visible, else returns false
	function sb:get_visible() return is_visible end
	--// Sets visibility of scrollbar
		--arg1 visible (boolean, default true): true for scrollbar to be visible, false for hidden
	function sb:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if scrollbar is enabled, else returns false
	function sb:get_enabled() return is_enabled end
	--// Enables/disables button (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for button to be enabled, false for disabled
	function sb:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			
			--change enabled status of subcomponents too
			slider:set_enabled(enabled)
			button1:set_enabled(enabled)
			button2:set_enabled(enabled)
		end
	end
	
	
	--// Called when mouse button is pressed while cursor is on scrollbar
		--arg1 mouse_button (string): name of the mouse button pressed
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of scrollbar
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of scrollbar
	function sb:on_mouse_pressed(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			--send on_mouse_pressed event to subcomponent
			if direction=="vertical" then
				if y < button_length then
					button1:on_mouse_pressed(mouse_button, x, y)
				elseif y < button_length + slider_height then
					slider:on_mouse_pressed(mouse_button, x, y-button_length)
				else button2:on_mouse_pressed(mouse_button, x, y-button_length-slider_height) end
			else
				if x < button_length then
					button1:on_mouse_pressed(mouse_button, x, y)
				elseif x < button_length + slider_width then
					slider:on_mouse_pressed(mouse_button, x-button_length, y)
				else button2:on_mouse_pressed(mouse_button, x-button_length-slider_width, y) end
			end
			
			return true
		end	
	end
	
	
	--// Called whenever mouse button is released. If mouse cursor is not over the scrollbar
	--// at time of release then x & y are nil
		--arg1 mouse_button (string): name of the mouse button released
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of scrollbar
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of scrollbar
	function sb:on_mouse_released(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			if x and y then --mouse cursor within button bounds
				--send event to subcomponent
				if direction=="vertical" then
					if y < button_length then
						button1:on_mouse_released(mouse_button, x, y)
					elseif y < button_length + slider_height then
						slider:on_mouse_released(mouse_button, x, y-button_length)
					else button2:on_mouse_released(mouse_button, x, y-button_length-slider_height) end
				else
					if x < button_length then
						button1:on_mouse_released(mouse_button, x, y)
					elseif x < button_length + slider_width then
						slider:on_mouse_released(mouse_button, x-button_length, y)
					else button2:on_mouse_released(mouse_button, x-button_length-slider_width, y) end
				end
				
				return true
			else
				--send event to all subcomponents
				slider:on_mouse_released(mouse_button)
				button1:on_mouse_released(mouse_button)
				button2:on_mouse_released(mouse_button)
			end
		end
	end
	
	
	--// Replaces existing function; before draw, check if needs refresh first
	function sb:draw(dst_surface, x, y)
		if is_visible then
			--check if subcomponents need refresh
			local needs_refresh = button1:is_refresh()
			needs_refresh = slider:is_refresh() or needs_refresh
			needs_refresh = button2:is_refresh() or needs_refresh
			
			--redraw surface if there was a refresh
			if needs_refresh then
				surface:clear()
				
				button1:draw(surface, 0, 0)
				slider:draw(
					surface,
					direction=="vertical" and 0 or button_length,
					direction=="vertical" and button_length or 0
				)
				button2:draw(
					surface,
					direction=="vertical" and 0 or button_length+slider_height,
					direction=="vertical" and button_length+slider_height or 0
				)
			end
			
			surface:draw(dst_surface, self.x+x, self.y+y)
		end
	end
	
	return sb
end

return scroll_bar


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
