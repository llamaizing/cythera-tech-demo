--[[ draw_view.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script displays a scrollable view that is comprised of multiple lines, where each
	line contains a sol.surface or uix.control. Drawable objects added must have a :draw()
	function. Must be linked to a scrollbar to allow for scrolling.
]]

local draw_view = {}

function draw_view.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local dv = {}
	local surface
	
	local num_lines = properties.num_lines or 6 --number of visible lines
	local line_width = properties.line_width or 256
	local line_height = properties.line_height or 16
	local horz_margin = properties.horz_margin or 0
	local horz_alignment = properties.horizontal_alignment or "left"
	local vert_alignment = properties.vertical_alignment or "middle"
	local bg_color = properties.bg_color or {255, 255, 255}
	
	local parent
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	local needs_refresh = true --True if needs to be redrawn when scrolling
	
	local entries --array of entries
	local display_index --index of line at top of view
	
	surface = sol.surface.create(line_width, line_height*num_lines)
	
	function dv:get_size() return surface:get_size() end
	
	function dv:get_xy() return self.x, self.y end
	function dv:set_xy(x,y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function dv:get_blend_mode() return surface:get_blend_mode() end
	function dv:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function dv:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function dv:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	function dv:get_movement() return surface:get_movement() end
	function dv:start_movement(movement, callback) movement:start(surface, callback) end
	function dv:stop_movement() return surface:stop_movement() end
	
	function dv:get_opacity() return surface:get_opacity() end
	function dv:set_opacity(opacity) return surface:set_opacity(opacity) end
	
	--// Implementation
	
	--// Parent control gets refreshed when this control is refreshed (compound controls only)
	function dv:get_parent() return parent end
	function dv:set_parent(new_parent) parent = new_parent end
	
	--// Returns true if control is visible, else returns false
	function dv:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function dv:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if control is enabled, else returns false
	function dv:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function dv:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out)
		end
	end
	
	function dv:get_index() return display_index end
	function dv:get_num_visible_lines() return num_lines end
	function dv:get_record_length() return #entries end
	
	
	function dv:clear()
		entries = {}
		display_index = 1
		self:needs_refresh()
	end
	
	
	function dv:get_entry(n)
		return entries[n]
	end
	
	
	function dv:new_entry(entry)
		assert(type(entry)~=nil, "Bad argument #1 to 'new_entry' (table expected, got nil)")
		
		table.insert(entries, entry)
		
		if entry.set_parent then entry:set_parent(self) end
		
		--TODO update display_index so viewing same portion of log unless at bottom
		
		self:needs_refresh()
	end
	
	
	--// Returns true if the control needs to be refreshed before next draw
	function dv:is_needs_refresh() return needs_refresh end
	--// Calling this function forces the control to be refreshed before the next draw
	function dv:needs_refresh()
		needs_refresh = true
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	function dv:scroll_line(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'scroll_line' (number expected)")
		
		n = math.floor(n) --only scroll in increments of one whole line
		local start_index = display_index --keep track of starting point, and if it doesn't change then don't refresh
		local max_index = #entries - num_lines + 1
		
		display_index = display_index - n
		
		--force display index to be within valid bounds
		if display_index < 1 then
			display_index = 1
		elseif display_index > max_index then
			display_index = max_index
		end
		
		if start_index~=display_index then self:needs_refresh() end --view moved
		
		--calculate percentage of where view window is over whole buffer (0 = index of 1, 1 = max_index)
		return display_index, (display_index - 1)/max_index
	end
	
	
	function dv:scroll_page(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'scroll_page' (number expected)")
		
		return self:scroll_line(n*num_lines)
	end
	
	
	function dv:view_line(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'view_line' (number expected)")
		
		local start_index = display_index
		local max_index = #entries - num_lines + 1
		
		n = math.floor(n) --scroll in whole line increments
		n = math.min(math.max(n, 1), max_index) --force to valid bounds
		
		display_index = n
		
		if start_index~=display_index then self:needs_refresh() end
		
		--calculate percentage of where view window is over whole buffer (0 = index of 1, 1 = max_index)
		return (display_index - 1)/(max_index - 1)
	end
	
	
	function dv:scroll_percent(percent)
		percent = tonumber(percent)
		assert(percent, "Bad argument #1 to 'scroll_percent' (number expected)")
		
		local max_index = #entries - num_lines + 1
		local new_index = math.floor(percent * max_index + 1.5) --round to nearest index
		
		return self:view_line(new_index)
	end
	
	
	--------------------
	-- Control Events --
	--------------------
	
	function dv:on_mouse_pressed(mouse_button, x, y)
		local line_index = math.floor(y/line_height) + display_index
		if entries[line_index] and entries[line_index].on_mouse_pressed then
			local y = y - (line_index - display_index)*line_height
			entries[line_index]:on_mouse_pressed(mouse_button, x, y)
		end
	end
	
	
	function dv:on_mouse_released(mouse_button, x, y)
		if not x or not y then --released outside of draw view; send event to all visible entries
			for i = 0,num_lines-1 do
				if entries[display_index + i] and entries[display_index + i].on_mouse_released then
					entries[display_index + i]:on_mouse_released(mouse_button)
				end
			end
		else --released within draw view; send only to entry at mouse location
			local line_index = math.floor(y/line_height) + display_index
			if entries[line_index] and entries[line_index].on_mouse_released then
				local y = y - (line_index - display_index)*line_height
				entries[line_index]:on_mouse_released(mouse_button, x, y)
			end
		end
	end
	
	
	function dv:refresh()
		surface:clear()
					
		if bg_color then surface:fill_color(bg_color) end --keep transparent background if bg_color not specified
		
		local i --buffer index of line to view
		for n=0,num_lines-1 do
			i = display_index + n
			entries[i]:draw(surface, horz_margin, n * line_height) --TODO alignment --TODO don't exceed width/height
		end
		
		needs_refresh = false
	end
	
	
	function dv:draw(dst_surface, x, y)
		if needs_refresh then self:refresh() end
		surface:draw(dst_surface, x, y)
	end
	
	dv:clear()
	
	return dv
end

return draw_view


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
