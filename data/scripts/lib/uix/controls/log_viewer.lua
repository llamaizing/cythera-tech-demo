--[[ log_viewer.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a scrollable text log with a fixed number of entries. As new lines
	are added, lines from the beginning will be removed.
	
	If a scrollable view is desired, then the control must be linked with a slider control
	using the link_slider() function.
]]

local log_viewer = {}

--[[ Properties for create():
	num_lines (number, default 6): how many lines of text are visible
	max_lines (number, default 50): how many lines of text to keep in buffer
	line_width (number, default 250): width of line of text in pixels
	line_height (number, default 16): height of line of text in pixels
	horz_margin (number, default 0): number of pixels for gap on left and right sides where text stops
	font (string): font id to use for text
	font_size (number, default 11): size of font to use
	font_color (table, default black): array of 4 RGBA values 0-255
	rendering_mode (string, default "solid"): "solid" or "antialiasing"
	blend_mode (string, default "none"): "none", "blend", "add", or "multiply"
	bg_color ((table, default clear): array of 4 RGBA values 0-255
	text (string, default ""): initial text to display
	prompt (string, default ""): text to preface each entry
]]

local integers = { --list of properties that are a number; value is the minimum allowed
	num_lines=1, max_lines=1, line_width=1, line_height=1, horz_margin=0, font_size=1
}
local enforce_types = { --these properties must have the type given as a value
	font_color="table", rendering_mode="string", blend_mode="string", bg_color="table",
	text="string", prompt="string",
}
function log_viewer.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	--// Coerce optional properties to valid values
	
	--convert properties values to positive integers
	local val
	for key,min in pairs(integers) do
		val = tonumber(properties[key])
		if val then properties[key] = math.max(math.floor(val), min) end
	end
	
	--any optional properties of wrong type make omitted instead
	for property,data_type in pairs(enforce_types) do
		if type(properties[property]) ~= data_type then
			properties[property] = nil
		end
	end
	
	--// Variables associated with the new instance
	
	local log = {} --table to return
	local linked_slider
	
	--settings
	local num_lines = properties.num_lines or 6
	local max_lines = properties.max_lines or 50
	local line_width = properties.line_width or 250
	local line_height = properties.line_height or 16
	local horz_margin = properties.horz_margin or 0
	local text_width = line_width - horz_margin*2
	local font = properties.font
	local font_size = properties.font_size or 11
	local font_color = properties.font_color or {0, 0, 0}
	local rendering_mode = properties.rendering_mode or "solid"
	local blend_mode = properties.blend_mode or "none"
	local bg_color = properties.bg_color
	local prompt = properties.prompt or ""
	
	--content
	local buffer --array of strings for each line (circular buffer)
	local line_index --index to overwrite next in buffer when adding new line to end
	local display_index --index of line at top of view
	local needs_redraw --true if text has changed but surface has not been redrawn
	
	--drawable content
	local log_surface = sol.surface.create(line_width, line_height*num_lines)
	log_surface:set_blend_mode(blend_mode)
	local line_text_surface = sol.text_surface.create{
		vertical_alignment = "top",
		horizontal_alignment = "left",
		font = font,
		font_size = font_size,
		color = font_color,
		rendering_mode = rendering_mode,
	}
	
	local function init()
		buffer = {}
		for i=1,max_lines do
			table.insert(buffer, "")
		end
		
		line_index = 1
		display_index = max_lines - num_lines + 1 --set view to very bottom
		
		if properties.text then
			log:print(properties.text)
		end
		
		needs_redraw = true
	end
	
	function log:get_index() return display_index end
	function log:get_num_visible_lines() return num_lines end
	function log:get_record_length() return max_lines end
	
	--// Returns length and width of visible portion of log
	function log:get_size()
		local width = line_width
		local height = line_height*num_lines
		
		return width, height
	end
	
	function log:link_slider(new_slider) linked_slider = new_slider end
	
	--// Returns text at specified line (string, each line separated by newline character)
		--omit the line number to return the entire text
	function log:get_text(n)
		local num = tonumber(n)
		assert(num or not n, "Bad argument #1 to 'get_text' (number or nil expected, got "..type(n)..")")
		
		if num then --get single line of text
			num = math.floor(num)
			assert(num>=1 and num<=max_lines, "Bad argument #1 to 'get_text' (number out of range: 1 to "..max_lines..")")
		
			local buffer_index = num + line_index - 1
			if buffer_index > max_lines then buffer_index = buffer_index - max_lines end --equivalent: buffer_index = (buffer_index - 1) % max_lines + 1
			
			return buffer[buffer_index] or ""
		else --get all text
			local text = {}
			
			local buffer_index
			for i = 1,max_lines do
				buffer_index = i + line_index - 1
				if buffer_index > max_lines then buffer_index = buffer_index - max_lines end --equivalent: buffer_index = (buffer_index - 1) % max_lines + 1
				
				table.insert(text, buffer[buffer_index] or "")
			end
			
			return table.concat(text, '\n')
		end
	end
	
	--// Resets all text to empty strings and flags surfaces as needing to be redrawn
	function log:clear()
		for i=1,max_lines do
			buffer[i] = ""
		end
		
		line_index = 1
		display_index = max_lines - num_lines + 1 --set view to very bottom
		needs_redraw = true
	end
	
	--// Adds one line of text (string); text already pre-formatted and verified to fit width
	local function add_line(text)
		buffer[line_index] = text --set text
		
		--advance line_index by one line
		if line_index==max_lines then --more efficient than % operation
			line_index = 1
		else line_index = line_index + 1 end
		
		--TODO update display_index so viewing same portion of log, unless at bottom then keep at bottom
		
		needs_redraw = true
	end
	
	--// Appends given text to bottom of viewer
		--arg1 text (string): Text to append (may contain \n for multiple lines
		--arg2 is_addendum (boolean, default false): if true then text is not appended by prompt
	function log:print(text, is_addendum)
		assert(type(text)~=nil, "Bad argument #1 to 'print' (string expected, got nil)")
		
		--reformat text
		text = tostring(text)
		local text_len = text:len()
		text = text:gsub("\r\n", "\n"):gsub("\r", "\n") --convert carriage return character(s) to new line character(s)
		if text:sub(text_len,text_len)~='\n' then text = text..'\n' end
		
		--set-up with initial values
		local line_it = text:gmatch"([^\n]*)\n"
		local current_line = is_addendum and "" or prompt
		local scratch_surface = sol.text_surface.create{ --to check text widths
			font = font,
			font_size = font_size,
			text = current_line
		}
		local current_width = scratch_surface:get_size()
		
		--locals for for loop
		local word_id
		local new_width
		
		--write each line of text to buffer; overflow text gets written to the next line
		for line in line_it do
			word_it = line:gmatch"(%s*)(%S+)"
			
			for space,word in word_it do
				--find width of new word
				scratch_surface:set_text(space..word)
				new_width = scratch_surface:get_size()
				
				if current_width + new_width <= text_width then --new word fits on current line
					current_line = current_line..space..word --append to current line, including leading space(s)
					current_width = current_width + new_width
				else --doesn't fit on current line; begin writing to new line
					add_line(current_line) --write current line to buffer
					
					current_line = word --start new line with current word; don't include leading space(s)
					scratch_surface:set_text(word)
					current_width = scratch_surface:get_size()
				end
			end
			
			--write remaining text for this line to buffer and reset for next line
			add_line(current_line)
			current_line = ""
			current_width = 0
			--don't need to set needs_redraw flag since it gets set by add_line()
		end
	end
	
	--// Scroll log viewer by n lines
		--arg1 (number): line number of top visible line (lower numbered lines are higher)
		--arg2 (number): number of lines to scroll; positive moves up, negative moves down
		--ret1 (number): percentage (value between 0 and 1) where 0 is at the very top and 1 is at the very bottom
	function log:scroll_line(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'scroll_line' (number expected)")
		
		n = math.floor(n) --only scroll in increments of one whole line
		local start_index = display_index --keep track of starting point, and if it doesn't change then don't redraw
		local max_index = max_lines - num_lines + 1
		
		display_index = display_index - n
		
		--force display_index to be within valid bounds
		if display_index<1 then
			display_index = 1
		elseif display_index > max_index then
			display_index =  max_index
		end
		
		if start_index~=display_index then --view moved
			if linked_slider and linked_slider.set_value then
				linked_slider:set_value((display_index-1)/(max_index-1))
			end
			
			needs_redraw = true
		end
		
		--calculate percentage of where view window is over whole buffer (0 = index of 1, 1 = max_index)
		return display_index, (display_index - 1)/max_index
	end
	
	--// Scroll log viewer by n pages (or n*num_lines lines)
		--arg1 (number): line number of top visible line (lower numbered lines are higher)
		--arg2 (number): number of lines to scroll; positive moves up, negative moves down
		--ret1 (number): percentage (value between 0 and 1) where 0 is at the very top and 1 is at the very bottom
	function log:scroll_page(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'scroll_page' (number expected)")
		
		return self:scroll_line(n*num_lines)
	end
	
	--// Scroll log viewer so that line n is at top of view
		--arg1 (number): line number of top visible line (lower numbered lines are higher)
		--arg2 (number): number of lines to scroll; positive moves up, negative moves down
		--ret1 (number): percentage (value between 0 and 1) where 0 is at the very top and 1 is at the very bottom
	function log:view_line(n)
		n = tonumber(n)
		assert(n, "Bad argument #1 to 'view_line' (number expected)")
		
		local start_index = display_index --keep track of starting point, and if it doesn't change then don't redraw
		local max_index = max_lines - num_lines + 1
		
		n = math.floor(n) --scroll in whole line increments
		n = math.min(math.max(n, 1), max_index) --force to valid bounds
		
		display_index = n
		
		if start_index~=display_index then needs_redraw=true end --view moved
		
		--calculate percentage of where view window is over whole buffer (0 = index of 1, 1 = max_index)
		return (display_index - 1)/(max_index - 1)
	end
	
	--// Scroll log viewer to percentage of scroll bar (0 is top, 1 is bottom)
	function log:scroll_percent(percent)
		percent = tonumber(percent)
		assert(percent, "Bad argument #1 to 'scroll_percent' (number expected)")
		
		local max_index = max_lines - num_lines + 1
		local new_index = math.floor(percent * max_index + 1.5) --round to nearest index
		
		return self:view_line(new_index)
	end
	
	--// Draws the log surface on dst_surface
		--arg1 (surface, optional): surface to draw the log surface on; if dst_surface is nil then the log surface is just rendered and returned
		--arg2 (number, optional): X coordinate of where to draw the log surface
		--arg3 (number, optional): Y coordinate of where to draw the log surface
		--ret1 (surface): log surface; only re-renders if text or viewing position has changed since last call of :draw()
	function log:draw(dst_surface, x, y)
		if needs_redraw then
			log_surface:clear()
			
			if bg_color then log_surface:fill_color(bg_color) end --keep transparent background if bg_color not specified
			
			--get top line viewed
			local i_start = display_index + line_index - 1
			if i_start > max_lines then i_start = i_start - max_lines end
			
			local i --buffer index of line to view
			for n=0,num_lines-1 do
				i = n+i_start
				if i>max_lines then i = i - max_lines end  --equivalent to: i = (i-1) % max_lines + 1
				
				line_text_surface:set_text(buffer[i])
				line_text_surface:draw(log_surface, horz_margin, n * line_height)
			end
		end
		
		if dst_surface then log_surface:draw(dst_surface, x, y) end
		
		return log_surface
	end
	
	init()
	
	return log
end

return log_viewer


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
