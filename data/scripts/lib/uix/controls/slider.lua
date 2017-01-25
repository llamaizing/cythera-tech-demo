--[[ slider.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a slider control with a handle that can be dragged by the mouse to
	set its position. The slider can be linked to a control that uses a scrollable view in
	order for the slider to set the portion that is viewed.
	
	Depending on the style used for the slider, the handle may include text that gives the
	value of the slider's current position.
	
	Valid styles:
	  * verticalbar: Generic vertical slider (default)
	  * numberslider: Horizontal slider with number text for current position
]]

local sliderbar = {}

local ui_draw = require"scripts/lib/uix/ui_draw"
local styles = require"scripts/lib/uix/controls/slider.dat"

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
		--valid styles: "verticalbar", "numberslider"
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
function sliderbar.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "verticalbar"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local width = math.floor(tonumber(properties.width) or tonumber(style_info.width_bar) or 0)
	local height = math.floor(tonumber(properties.height) or tonumber(style_info.height_bar) or 0)
	local handle_width = tonumber(properties.width_handle) or tonumber(style_info.width_handle)
	if handle_width then handle_width = math.floor(handle_width) end
	local handle_height = tonumber(properties.height_handle) or tonumber(style_info.height_handle)
	if handle_height then handle_height = math.floor(handle_height) end
	local direction = properties.direction or style_info.direction
	local on_position_changed = properties.on_position_changed or nil
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	assert(not handle_width or handle_width>0, "Bad argument #1 to 'create' (width_handle value must be positive number)")
	assert(not handle_height or handle_height>0, "Bad argument #1 to 'create' (height_handle value must be positive number)")
	assert(direction=="horizontal" or direction=="vertical", "Bad argument #1 to 'create' (string 'horizontal' or 'vertical' expected)")
	assert(not on_position_changed or type(on_position_changed)=="function", "Bad argument #1 to 'create' (on_clicked value must be a funtion or nil)")
	
	local slider = {x=0, y=0} --table to be returned
	local menu
	local linked_view
	local surface = sol.surface.create(width, height)
	
	local scroll_timer
	local prev_mouse_position
	
	local is_resize_bar = style_info.is_resize_bar~=false
	local is_resize_handle = style_info.is_resize_handle~=false
	
	local handle_x, handle_y = 0, 0
	local min = style_info.min
	local max = style_info.max
	local value = max or 0 --TODO update (initialize) when linked with log
	local is_pressed = false
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	local needs_refresh = true
	
	local bar_surface = ui_draw.load_frame{
		path = style_info.img_bar,
		width = is_resize_bar and width,
		height = is_resize_bar and height,
		border = style_info.border_bar,
	}
	
	local bar_surface_disabled
	if style_info.img_bar_disabled then
		bar_surface_disabled = ui_draw.load_frame{
			path = style_info.img_bar_disabled,
			width = is_resize_bar and width,
			height = is_resize_bar and height,
			border = style_info.border_bar,
		}
	end
	
	local handle_surface = ui_draw.load_frame{
		path = style_info.img_handle,
		width = style_info.width_handle,
		height = style_info.height_handle,
		border = style_info.border_bar,
	}
	
	local length --length for handle to travel in pixels; multiply by value for position
	do 
		local w,h = bar_surface:get_size()
		local bar_length = direction=="vertical" and h or w
		w,h = handle_surface:get_size()
		local handle_length = directin=="vertical" and h or w
		length = bar_length - handle_length
	end
	
	slider.on_position_changed = on_position_changed --this function gets called when button is clicked
	
	--// Add drawable methods to button
	
	
	function slider:get_size() return surface:get_size() end
	
	
	function slider:get_xy() return self.x, self.y end
	function slider:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	
	function slider:get_blend_mode() return surface:get_blend_mode() end
	function slider:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	
	function slider:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function slider:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	
	--// Gets and sets menu where this text_prompt is used (determines lifetime of cursor_timer)
	function slider:get_menu() return menu end
	function slider:set_menu(new_menu) menu = new_menu end
	
	
	--// TODO desc
	function slider:link_view(new_view) linked_view = new_view end
	
	
	--// Returns true if button is visible, else returns false
	function slider:get_visible() return is_visible end
	--// Sets visibility of button
		--arg1 visible (boolean, default true): true for button to be visible, false for hidden
	function slider:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if button is enabled, else returns false
	function slider:get_enabled() return is_enabled end
	--// Enables/disables button (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for button to be enabled, false for disabled
	function slider:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			needs_refresh = true --disabled button may use different image (e.g. greyed out)
		end
	end
	
	
	--// Returns true if button is pressed, else returns false
	function slider:get_pressed() return is_pressed end
	--// Sets pressed state of button and flags for needing refresh
		--arg1 pressed (boolean, default false): true to use pressed button image, false to use unpressed button image
	function slider:set_pressed(pressed)
		pressed = not not pressed --force to boolean
		if pressed ~= is_pressed then --only update if pressed state changed
			is_pressed = pressed
			needs_refresh = true --may use different image for when pressed
		end
	end
	
	
	--// Returns value that the slider is currently set to
	function slider:get_value() return value end
	--// Sets a new value for the slider; on_position_changed(value) will be called if defined
	function slider:set_value(new_value)
		new_value = tonumber(new_value)
		assert(new_value, "Bad argument #1 to 'set_value' (number exected)")
		
		--force new_value to valid value
		if increment and increment~=0 then
			new_value = increment * math.floor(new_value/increment)
		end
		new_value = math.min(math.max(new_value, min), max)
		
		if value~=new_value then
			value = new_value
			needs_refresh = true
			
			if self.on_position_changed then self:on_position_changed(value) end
		end
	end
	
	
	--//
	local function mouse_update()
		local x,y = sol.input.get_mouse_position()
		local current_position = direction=="vertical" and y or x
		local delta = current_position - prev_mouse_position
		local new_value = (value * length + delta)/length
		
		prev_mouse_position = current_position
		slider:set_value(new_value)
		
		if linked_view and linked_view.scroll_percent then
			linked_view:scroll_percent(new_value)
		end
		
		return true
	end
	
	
	--// Called when mouse button is pressed while cursor is on control
		--arg1 mouse_button (string): name of the mouse button pressed
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of control
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of control
	function slider:on_mouse_pressed(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			--local percent = math.max(value - min, 0)/(max - min)
			--local slider_length = direction=="vertical" and height or width
			local handle_min = direction=="vertical" and handle_y or handle_x
			local handle_max = handle_min + (direction=="vertical" and handle_height or handle_width)
			local mouse_position = direction=="vertical" and y or x
			
			if mouse_position >= handle_min and mouse_position <= handle_max then
				--find current mouse position
				x,y = sol.input.get_mouse_position() --absolute position, not relative to menu
				prev_mouse_position = direction=="vertical" and y or x
				
				--abort previous timer if running
				if scroll_timer then scroll_timer:stop() end
				scroll_timer = sol.timer.start(menu, 100, mouse_update)
				
				self:set_pressed(true) --allow mouse to drag handle
				
				return true
			elseif mouse_position < handle_min and linked_view and linked_view.scroll_page then
				linked_view:scroll_page(1)
			elseif linked_view and linked_view.scroll_page then
				linked_view:scroll_page(-1)
			end
		end	
	end
	
	
	--// Called whenever mouse button is released. If mouse cursor is not over the control
	--// at time of release then x & y are nil
		--arg1 mouse_button (string): name of the mouse button released
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of button
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of button
	function slider:on_mouse_released(mouse_button, x, y)
		if scroll_timer then
			scroll_timer:stop()
			scroll_timer = nil
		end
		
		self:set_pressed(false)
		
		if not is_visible or not is_enabled then return false end
	end
	
	
	--// Regenerate surface images when button text has changed or when button changed pressed/non-pressed
	function slider:refresh()
		--determine which bg image to use to draw slider bar based on slider state
		local active_bar_surface
		if not is_enabled and bar_surface_disabled then
			active_bar_surface = bar_surface_disabled
		--[[elseif is_pressed and bar_surface_pressed then
			active_bar_surface = bar_surface_pressed]]
		else active_bar_surface = bar_surface end
		
		local active_handle_surface
		if not is_enabled then
			active_handle_surface = handle_surface_disabled
		elseif is_pressed and handle_surface_pressed then
			active_handle_surface = handle_surface_pressed
		else active_handle_surface = handle_surface end
		
		surface:clear() --clear old surface
		active_bar_surface:draw(surface, 0, 0) --draw bg image of slider bar
		
		--calculate handle position
		local position = value * length
		handle_x = direction=="vertical" and 0 or position
		handle_y = direction=="vertical" and position or 0
		
		if active_handle_surface then active_handle_surface:draw(surface, handle_x, handle_y) end
		
		needs_refresh = false
	end
	
	
	--// If needs refresh then returns true and does the refresh, else returns false
	function slider:is_refresh()
		if needs_refresh then
			self:refresh()
			return true
		else return false end
	end
	
	
	--// Replaces existing function; before draw, check if needs refresh first
	function slider:draw(dst_surface, x, y)
		if needs_refresh then self:refresh() end
		if is_visible then surface:draw(dst_surface, self.x+x, self.y+y) end
	end
	
	return slider
end

return sliderbar


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
