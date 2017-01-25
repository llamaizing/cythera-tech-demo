--[[ text_prompt.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a text box (image and text) that monitors keyboard events to allow
	the player to enter text. Also includes a flashing cursor at the text entry point that
	flashes on and off every 500ms. The specified style sets the look of both the text box
	and its text.
	
	Valid styles:
	  * simpleprompt: white box with 1 px black outline (default)
	  * none: no stlye used and all properties must be specified manually
]]

local text_prompt = {}

local util = require"scripts/util.lua"
local styles = require"scripts/lib/uix/controls/text_prompt.dat" --TDOD replace hard-coded values


--// Creates and returns a new text prompt object
	--arg1 properties (table): list of properties defining the control; contains the following keys:
		--style (string, default "simpleprompt"): style of the control, determines image and text settings
			--valid styles: "simpleprompt", "none"
		--TODO additional properties
function text_prompt.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local width = math.floor(tonumber(properties.width) or 0)
	local height = math.floor(tonumber(properties.height) or 0)
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	local tp = {x=0, y=0} --table to be returned
	local menu --reference to the menu (table) that this control is added to (needed for timer context)
	
	local surface --primary surface
	local bg_surface --image to draw behind text
	local prompt_text --text surface
	local cursor_surface --flashing vertical bar at text entry point
	
	local text_width = 0
	
	local parent
	local is_visible = false --false so timer starts when made visible --TODO better implementation to start timer by default if visible
	local is_enabled = properties.is_enabled~=false --TODO deactivate flashing cursor if disabled
	local needs_refresh = true
	
	local cursor_timer
	local cursor_visible = false
	local cursor_color = properties.cursor or {100, 100, 100} --TODO verify valid color
	
	local box_color = properties.color or {255, 255, 255} --TODO verify valid color
	local outline_color = properties.outline or {0, 0, 0} --TODO verify valid color
	local horz_alignment = properties.horizontal_alignment or "left"
	local vert_alignment = properties.vertical_alignment or "top"
	
	prompt_text = sol.text_surface.create{
		horizontal_alignment = "left",
		vertical_alignment = "top",
		font = properties.font or "librefranklin-bold",
		font_size = properties.font_size or 14,
		color = properties.font_color or {0, 0, 0}, --black
		rendering_mode = properties.rendering_mode or "antialiasing",
		text = properties.text,
		text_key = properties.text_key
	}
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	--initialize
	surface = sol.surface.create(width, height)
	bg_surface = sol.surface.create(width, height)
	bg_surface:fill_color(outline_color)
	bg_surface:fill_color(box_color, 1, 1, width-2, height-2)
	cursor_surface = sol.surface.create(1, height-6)
	cursor_surface:fill_color(cursor_color)
	
	function tp:get_size() return width,height end
	
	function tp:get_xy() return self.x, self.y end
	function tp:set_xy(x,y)
		self.x = math.floor(tonumber(x))
		self.y = math.floor(tonumber(y))
	end
	
	--// Gets and sets menu where this text_prompt is used (determines lifetime of cursor_timer)
	function tp:get_menu() return menu end
	function tp:set_menu(new_menu) menu = new_menu end
	
	function tp:get_blend_mode() return surface:get_blend_mode() end
	function tp:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function tp:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function tp:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	function tp:get_movement() return surface:get_movement() end
	function tp:start_movement(movement, callback) movement:start(surface, callback) end
	function tp:stop_movement() return surface:stop_movement() end
	
	function tp:get_opacity() return surface:get_opacity() end
	function tp:set_opacity(opacity) return surface:set_opacity(opacity) end
	
	--TODO text surface functions for text
	
	--// Implementation
	
	--// Parent control gets refreshed when this control is refreshed (compound controls only)
	function tp:get_parent() return parent end
	function tp:set_parent(new_parent) parent = new_parent end
	
	--// Returns true if control is visible, else returns false
	function tp:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function tp:set_visible(visible)
		local visible_old = is_visible
		is_visible = visible~=false --force to boolean
		
		if is_visible~=visible_old then
			if is_visible then
				if not cursor_timer then --timer is not already running
					cursor_timer = sol.timer.start(menu, 500, function()
						cursor_visible = not cursor_visible
						return true --repeat until menu closes or until canceled when prompt not visible
					end)
					
					cursor_visible = true --start off with cursor shown
				end
			elseif cursor_timer then --if not visible then abort timer
				cursor_timer:stop()
				cursor_timer = nil
			end
		end
	end
	
	
	--// Returns true if control is enabled, else returns false
	function tp:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function tp:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out) --TODO all needs_refresh to use function
		end
	end
	
	
	--// Returns the current text of the prompt control
		--ret1 (string): prompt text, may be an empty string
	function tp:get_text()
		return prompt_text:get_text()
	end
	
	
	--// Sets the text for the prompt control and triggers a refresh
		--arg1 text (string, default ""): new text to use for prompt
	function tp:set_text(text)
		assert(not text or type(text)=="string" or type(text)=="number", "Bad argument #1 to 'set_text' (string, number or nil expected)")
		
		prompt_text:set_text(text or "")
		needs_refresh = true
	end
	
	
	--// Sets the text for the prompt control to a localized string in the current language using the specified key
		--arg1 text_key (string): key to specify which localized string to use
		--ret1 (string): the localized string that was set
	function tp:set_text_key(text_key)
		assert(type(text_key)=="string", "Bad argument #1 to 'set_text_key' (string expected, got "..type(text_key)..")")
		
		local text = sol.language.get_text(text_key) or ""
		self:set_text(text) --set_text() triggers refresh
		
		return text
	end
	
	
	--// Appends the specified text to the end of the prompt control and triggers a refresh
		--arg1 text (string, default ""): text to append
	function tp:add_text(text)
		assert(not text or type(text)=="string" or type(text)=="number", "Bad argument #1 to 'set_text' (string, number or nil expected)")
		
		text = prompt_text:get_text()..(text or "")
		prompt_text:set_text(text)
		
		needs_refresh = true
	end
	
	
	--// Deletes the last character of the prompt control text and triggers a refresh.
	--// For multibyte utf-8 characters, all bytes for that character are removed
	function tp:backspace()
		local prompt_string = self:get_text()
		local num_chars,num_bytes = util.char_count(prompt_string)
		num_chars,num_bytes = util.char_count(prompt_string, num_chars-1)
		local text = prompt_string:sub(1,num_bytes)
		
		self:set_text(text)
	end
	
	
	--// Deletes all text for the prompt control and triggers a refresh
	function tp:clear()
		self:set_text"" --set_text() triggers a refresh
	end
	
	
	--// Returns true if the control needs to be refreshed before next draw
	function tp:is_needs_refresh() return needs_refresh end
	--// Calling this function forces the control to be refreshed before the next draw
	function tp:needs_refresh()
		needs_refresh = true
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	--// Processes keyboard input to enter new characters in prompt control
	function tp:on_character_pressed(character)
		if is_visible then
			if character and character:len()>0 then
				local prompt_string = self:get_text()
				prompt_string = prompt_string..character
				self:set_text(prompt_string)
			end
			
			return true
		end
	end
	
	
	--// Processes keyboard input to handle non-character input (backspace, enter, etc.)
		--backspace: removes last character from control
		--enter: clears text and calls control's on_enter() function
		--escape: clears text
	function tp:on_key_pressed(key, modifiers)
		if is_visible then
			if key=="backspace" then
				if modifiers.control then
					self:clear()
				else self:backspace() end
				
				return true
			elseif key=="enter" or key=="return" then
				local prompt_string = self:get_text()
				self:set_text"" --clear text
				
				if self.on_enter and prompt_string:match"%S+" then --only process if non-empty string
					self:on_enter(prompt_string)
				end
				
				return true
			elseif key=="escape" then
				self:set_text"" --clear input text
				return true
			elseif key=="tab" then
				--TODO next topic
				return true
			end
			return true
		end
	end
	
	
	--// Redraws the surface for the control when the text content changes
	function tp:refresh()
		bg_surface:draw(surface, 0, 0)
		prompt_text:draw(surface, 4, 2) --TODO allow specifying custom x_margin instead of hardcode 4
		
		text_width = prompt_text:get_size()
		text_width = math.min(text_width, width-5)
		
		needs_refresh = false
	end
	
	
	--// Draws primary surface on the destination surface each frame
	function tp:draw(dst_surface, x, y)
		if needs_refresh then self:refresh() end
		
		if is_visible then
			surface:draw(dst_surface, x+self.x, y+self.y)
			if cursor_visible then
				cursor_surface:draw(
					dst_surface,
					x + self.x + text_width + 4,
					y + self.y + 3
				)
			end
		end
	end
	
	return tp
end

return text_prompt


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
