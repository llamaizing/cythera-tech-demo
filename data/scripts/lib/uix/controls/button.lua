--[[ button.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a surface behaving as a button. The following states are possible,
	each having its own image: unpressed, pressed, disabled and set (toggle buttons only).
	Push buttons are pressed while the mouse button is held down and when released trigger
	an action. Toggle buttons alternate state each time clicked by the mouse. Clicking the
	button executes its on_clicked() function.
	
	Text may be drawn on the button depending on its style.
	
	Valid styles:
	  * textbutton: standard button with text
	  * togglebutton: checkbox 14x14 with text
	  * radiobutton: round radio button 14x14 with text
	  * logbutton: small logbook icon, size 24x24, no text
	  * scrollbuttonup: up arrow used for scrollbars, 16x16, no text
	  * scrollbuttondown: down arrow button used for scrollbars, 16x16, no text
]]

local push_button = {}

local ui_draw = require"scripts/lib/uix/ui_draw"
local styles = require"scripts/lib/uix/controls/button.dat"

--multipliers for text alignment
local alignment_offsets = {
	left = 0,
	center = 0.5,
	right = 1,
	top = 0,
	middle = 0.5,
	right = 1,
}


--// Generates a frame image to use for one of the button's states (pressed, unpressed, etc.)
local function make_button_image(properties, width, height)
	if not properties then return end
	if type(properties)=="string" then properties = {path=properties} end
	assert(type(properties)=="table", "Bad argument #1 to 'make_button_image' (table, string or nil expected, got "..type(properties)..")")
	
	local surface = ui_draw.load_frame{
		path = properties.path,
		src_x = properties.x,
		src_y = properties.y,
		src_width = properties.width,
		src_height = properties.height,
		width = width,
		height = height,
		border = properties.border,
	}
	
	local blend_mode = properties.blend_mode
	if blend_mode then surface:set_blend_mode(blend_mode) end
	
	--TODO fill color
	
	return surface
end


--// Creates and returns a new button object
	--arg1 properties (table): list of properties defining the button; contains the following keys:
		--style (string, default "textbutton"): style of button, determines image used
			--valid styles: "textbutton", "logbutton", "togglebutton"
		--width (number, positive, default 128): width of the button in pixels
		--height (number, positive, default 24): height of the button in pixels
		--is_set (boolean, default false): Toggle/radio buttons only, if true then button starts in set state
		--is_visible (boolean, default true): if false then button is not drawn (no interaction possible)
		--is_enabled (boolean, default true): if false then button is disabled, preventing interaction
		--on_clicked (function): Action to perform when button clicked with mouse
	
		--The following properties are only used if the button uses text
		--horizontal_alignment (string, default center)
		--vertical_alignment (string, default middle)
		--font (string, default "librefranklin-bold")
		--font_size (number, default 14)
		--rendering_mode (string, default antialiasing)
		--color (table, default black)
		--text (string)
		--text_key (string)
	--ret1 (table): the newly created button object
function push_button.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "textbutton"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local width = tonumber(properties.width)
	if width then width = math.floor(width) end
	local height = tonumber(properties.height)
	if height then height = math.floor(height) end
	
	assert(not width or width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(not height or height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	local on_clicked = properties.on_clicked or nil
	assert(not on_clicked or type(on_clicked)=="function", "Bad argument #1 to 'create' (on_clicked value must be a function or nil)")
	
	local is_resize = style_info.is_resize~=false
	
	local button_surface = make_button_image(style_info.img, is_resize and width, is_resize and height)
	
	local w,h = button_surface:get_size()
	width = width or w
	height = height or h
	
	local button = {x=0, y=0} --table to be returned
	local surface = sol.surface.create(width, height)
	
	local button_type = style_info.type or "push"
	local origin_x = 0
	local origin_y = 0
	
	local parent
	local is_pressed = false
	local is_set = style=="toggle" and not not properties.is_set
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	local needs_refresh = true
	
	local button_surface_pressed = make_button_image(style_info.img_pressed, is_resize and width, is_resize and height)
	local button_surface_set = make_button_image(style_info.img_set, is_resize and width, is_resize and height)
	local button_surface_disabled = make_button_image(style_info.img_disabled, is_resize and width, is_resize and height)
	local button_surface_overlay = make_button_image(style_info.img_overlay, is_resize and width, is_resize and height) --TODO not currently used
	
	button.on_clicked = on_clicked --this function gets called when the control is clicked with mouse
	
	--// Add drawable methods to control
	
	function button:get_size() return surface:get_size() end
	
	function button:get_origin() return origin_x,origin_y end
	function button:set_orign(x,y)
		origin_x = tonumber(x) or 0
		origin_y = tonumber(y) or 0
	end
	
	function button:get_bounding_box() return origin_x,origin_y,self:get_size() end
	
	function button:get_xy() return self.x, self.y end
	function button:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function button:get_blend_mode() return surface:get_blend_mode() end
	function button:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function button:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function button:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	function button:get_movement() return surface:get_movement() end
	function button:start_movement(movement, callback) movement:start(surface, callback) end
	function button:stop_movement() return surface:stop_movement() end
	
	function button:get_opacity() return surface:get_opacity() end
	function button:set_opacity(opacity) return surface:set_opacity(opacity) end
	
	--Only create text functions if button style has is_text enabled
	local horz_alignment, vert_alignment, text_surface
	if style_info.is_text then
		horz_alignment = properties.horizontal_alignment or style_info.horizontal_alignment or "center"
		vert_alignment = properties.vertical_alignment or style_info.vertical_alignment or "middle"
		
		assert(alignment_offsets[horz_alignment], "Bad argument #1 to 'create' (invalid value for horizontal_alignment)")
		assert(alignment_offsets[vert_alignment], "Bad argument #1 to 'create' (invalid value for vertical_alignment)")
		
		text_surface = sol.text_surface.create{
			horizontal_alignment = "left",
			vertical_alignment = "top",
			font = properties.font or style_info.font,
			font_size = tonumber(properties.font_size) or style_info.font_size,
			rendering_mode = properties.rendering_mode or style_info.rendering_mode,
			color = properties.color or style_info.font_color or {0, 0, 0},
			text = properties.text,
			text_key = properties.text_key,
		}
		
		--// Add text_surface methods to button
		
		function button:get_horizontal_alignment() return horz_alignment end
		function button:set_horizontal_alignment(horizontal_alignment)
			horz_alignment = horizontal_alignment
			self:needs_refresh()
		end
		
		function button:get_vertical_alignment() return vert_alignment end
		function button:set_vertical_alignment(vertical_alignment)
			vert_alignment = vertical_alignment
			self:needs_refresh()
		end
		
		function button:get_font() return text_surface:get_font() end
		function button:set_font(font_id)
			text_surface:set_font(font_id)
			self:needs_refresh()
		end
		
		function button:get_rendering_mode() return text_surface:get_rendering_mode() end
		function button:set_rendering_mode(rendering_mode)
			text_surface:set_rendering_mode(rendering_mode)
			self:needs_refresh()
		end
		
		function button:get_font_color() return text_surface:get_color() end
		function button:set_font_color(color)
			text_surface:set_color(color)
			self:needs_refresh()
		end
		
		function button:get_font_size() return text_surface:get_font_size() end
		function button:set_font_size(font_size)
			text_surface:set_font_size(font_size)
			self:needs_refresh()
		end
		
		function button:get_text() return text_surface:get_text() end
		function button:set_text(text)
			text_surface:set_text(text)
			self:needs_refresh()
		end
		
		function button:set_text_key(key)
			text_surface:set_text_key(key)
			self:needs_refresh()
		end
		
		function button:get_text_size() return text_surface:get_size() end
	end
	
	--// Implementation
	
	--// Parent control gets refreshed when this control is refreshed (compound controls only)
	function button:get_parent() return parent end
	function button:set_parent(new_parent) parent = new_parent end
	
	
	--// Returns true if control is visible, else returns false
	function button:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function button:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if control is enabled, else returns false
	function button:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function button:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out)
		end
	end
	
	
	--// Returns true if button is pressed, else returns false
	function button:get_pressed() return is_pressed end
	--// Sets pressed state of button and flags for needing refresh
		--arg1 pressed (boolean, default false): true to use pressed button image, false to use unpressed button image
	function button:set_pressed(pressed)
		pressed = not not pressed --force to boolean
		if pressed ~= is_pressed then --only update if pressed state changed
			is_pressed = pressed
			self:needs_refresh() --may use different image for when pressed
		end
	end
	
	
	--// Returns true if button is set, else returns false (only applies to radio and toggle buttons)
	function button:get_state() return is_set end
	--// Sets state of button and flags for needing refresh
	--// Only applies to toggle and radio buttons (otherwise no effect)
		--arg1 set (boolean, default false): true to use set state, false to use unset state
	function button:set_state(set)
		set = not not set --force to boolean
		if set ~= is_set then --only update if pressed state changed
			is_set = set
			self:needs_refresh() --may use different image for when set
		end
	end
	
	
	--// Toggles set state of button and flags for needing refresh
	--// Equivalent to button:set_state(not button:get_state())
		--ret1 (boolean): The pressed state of the button after this function is finished (true is pressed)
	function button:toggle()
		if button_type=="toggle" then
			is_set = not is_set
			self:needs_refresh()
		end
		
		return is_set
	end
	
	
	--// Returns true if the control needs to be refreshed before next draw
	function button:is_needs_refresh() return needs_refresh end
	--// Calling this function forces the control to be refreshed before the next draw
	function button:needs_refresh()
		needs_refresh = true
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	--// Called when mouse button is pressed while cursor is on button
		--arg1 mouse_button (string): name of the mouse button pressed
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of button
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of button
	function button:on_mouse_pressed(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		if mouse_button=="left" then
			self:set_pressed(true)
		end	
	end
	
	
	--// Called whenever mouse button is released. If mouse cursor is not over the button
	--// at time of release then x & y are nil
		--arg1 mouse_button (string): name of the mouse button released
		--arg2 x (number): X coordinate of cursor relative to upper-left corner of button
		--arg3 y (number): Y coordinate of cursor relative to upper-left corner of button
	function button:on_mouse_released(mouse_button, x, y)
		if not is_visible or not is_enabled then return false end
		
		local ret_val = false --assume false until proven otherwise
		if mouse_button=="left" then
			if x and y and is_pressed then --mouse cursor within button bounds
				if button_type=="push" then
					if self.on_clicked then self:on_clicked() end
					ret_val = true
				elseif button_type=="toggle" then
					if self.on_clicked then
						if self:on_clicked(not is_set)~=false then self:toggle() end --only toggle if on_clicked() returns something other than false
					else self:toggle() end --if no on_clicked fuction assigned then just toggle state
					ret_val = true
				end
			end
		
			self:set_pressed(false)
		end
		
		return ret_val
	end
	
	
	--// Regenerate surface images when button text has changed or when button changed pressed/non-pressed
	function button:refresh()
		--determine which bg image to use to draw button based on button state
		local active_surface
		if not is_enabled and button_surface_disabled then
			active_surface = button_surface_disabled
		elseif is_pressed and button_surface_pressed then
			active_surface = button_surface_pressed
		else active_surface = is_set and button_surface_set or button_surface end
		
		surface:clear() --clear old surface
		active_surface:draw(surface, 0, 0) --draw bg image onto button
		
		if button_surface_overlay then button_surface_overlay:draw(surface, 0, 0) end --draw overlay image
		
		--draw button text onto button
		if text_surface then --button style may not use text
			local margin_x = style_info.margin_x or 0
			local margin_y = style_info.margin_y or 0
			local text_width,text_height = text_surface:get_size()
			local dst_width,dst_height = width - margin_x*2, height - margin_y*2
			
			--amount of text to be truncated in pixels
			local overflow_x = math.max(text_width - dst_width, 0)
			local overflow_y = math.max(text_height - dst_height, 0)
			
			--truncate text to fit button
			text_width = math.min(text_width, dst_width)
			text_height = math.min(text_height, dst_height)
			
			--TODO change font color if button disabled
			
			text_surface:draw_region(
				overflow_x * alignment_offsets[horz_alignment],
				overflow_y * alignment_offsets[vert_alignment],
				text_width,
				text_height,
				surface,
				margin_x + (dst_width - text_width)*alignment_offsets[horz_alignment],
				margin_y + (dst_height - text_height)*alignment_offsets[horz_alignment]
			)
		end
		
		needs_refresh = false
	end
	
	
	--// If needs refresh then returns true and does the refresh, else returns false
	function button:is_refresh()
		if needs_refresh then
			self:refresh()
			return true
		else return false end
	end
	
	
	--// Replaces existing function; before draw, check if needs refresh first
	function button:draw(dst_surface, x, y)
		x = tonumber(x) or 0
		y = tonumber(y) or 0
		
		if needs_refresh then self:refresh() end
		if is_visible then surface:draw(dst_surface, self.x+x, self.y+y) end
	end
	
	return button
end

return push_button


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
