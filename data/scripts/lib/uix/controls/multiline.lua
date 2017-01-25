--[[ text_prompt.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script draws multiple lines of text onto a single surface. The dimensions and the
	number of lines are fixed. A shadow effect can be used when drawing the text. The text
	may also contain words designated as hyperlinks, which can have a different font color
	and will trigger an action when clicked on with the mouse.
	
	--TODO .dat file for multiple styles
]]

local multiline = {}

local styles = require"scripts/lib/uix/controls/multiline.dat"

function multiline.create(properties)
	local style = properties.style or "bodytext"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	local ml = {x=0, y=0}
	
	local surface
	
	local text = {} --text as displayed on screen (each line is table entry)
	local raw_text = {} --raw text for saving to log (each line is table entry)
	local hyperlinks = {} --list of hyperlinks and their position
		--keys: text (string), x_min (number), x_max (number), width (number)
	local line_index = 1 --keeps track of which line of the current paragraph is being processed
	local line_width = 0 --width in pixels of text that has been written to the current line
	local needs_refresh = false --if true then redraws text on surface during on_draw()
	
	local num_lines = math.floor(tonumber(properties.num_lines) or 1)
	local width = math.floor(tonumber(properties.width) or tonumber(style_info.width) or 128)
	local height = math.floor(tonumber(properties.height) or tonumber(style_info.height) or 80)
	local text_height = math.floor(tonumber(properties.text_height) or tonumber(style_info.text_height) or 20)
	local horz_alignment = properties.horizontal_alignment or style_info.horizontal_alignment or "left"
	local vert_alignment = properties.vertical_alignment or style_info.vertical_alignment or "top"
	local font_color = properties.font_color or style_info.font_color or {0, 0, 0}
	local hyperlink_color = properties.hyperlink_color or style_info.hyperlink_color
	local shadow_color = properties.shadow_color or style_info.shadow_color
	local is_visible = properties.is_visible~=false
	local is_hyperlinks = properties.is_hyperlinks~=false
	
	local hyperlink_list = {} --list of hyperlink titles added
	
	assert(num_lines>0, "Bad argument #1 to 'create' (num_lines value must be positive number)")
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	--initialize
	surface = sol.surface.create(width, height)
	
	local text_surface = sol.text_surface.create{ --text surface for drawing current line
		horizontal_alignment = "left",
		vertical_alignment = "top",
		
		font = properties.font or style_info.font or "librefranklin-bold",
		font_size = properties.font_size or style_info.font_size or 14,
		color = font_color,
		rendering_mode = properties.rendering_mode or style_info.rendering_mode or "solid",
	}
	
	local scratch_surface = sol.text_surface.create{ --temporary text surface for calculating word widths
		font = properties.font or style_info.font or "librefranklin-bold",
		font_size = properties.font_size or style_info.font_size or 14,
		rendering_mode = properties.rendering_mode or style_info.rendering_mode or "solid",
	}
	
	--// clears all multiline text and clears the surface
	function ml:clear()
		surface:clear()
		
		text = {}
		raw_text = {}
		hyperlinks = {}
		needs_refresh = false
		
		line_index = 1
		line_width = 0
		
		--create blank entries for each line
		for i=1,num_lines do
			table.insert(text, "")
			table.insert(raw_text, "")
			table.insert(hyperlinks, {})
		end
		hyperlink_list = {}
	end
	
	function ml:clear_line(line)
		line = tonumber(line)
		assert(line, "Bad argument #1 to 'clear_line' (number expected)")
		
		line=math.floor(line)
		assert(line>0 and line<=num_lines, "Bad argument #1 to 'clear_line' (number out of bounds)")
		
		if text[line] then
			table.remove(text, line)
			table.insert(text, "") --add entry at end to replace removed entry
		end
		if raw_text[line] then
			table.remove(raw_text, line)
			table.insert(raw_text, "") --add entry at end to replace removed entry
		end
		if hyperlinks[line] then
			table.remove(hyperlinks, line)
			table.insert(hyperlinks, {}) --add entry at end to replace removed entry
		end
		
		if line_index>=line then line_index = math.max(line_index - 1, 1) end
		
		needs_refresh = true
	end
	
	function ml:add_word(word, is_hyperlink, prefix)
		assert(type(word)=="string", "Bad argument #1 to 'add_word' (string expected, got "..type(word)..")")
		if word:len()<1 then return line_index end
		
		prefix = type(prefix)=="string" and prefix or ""
		
		local new_word,new_line = word:match"^(.-)(\n)$"
		if new_word and new_line then word = new_word end
		
		scratch_surface:set_text(prefix..word)
		local word_width = scratch_surface:get_size()
		
		--check if word fits on current line
		if not (line_width + word_width <= width) then --not enough room to fit word on current line
			--start new line
			line_index = line_index + 1
			line_width = 0
			
			if line_index > num_lines then return false end --no more lines available
			
			word = word:match"^%s*(.-)$" --don't carry leading whitespace to new line
			
			scratch_surface:set_text(prefix..word)
			word_width = scratch_surface:get_size()
		end --word contains everything if not starting new line
		
		--calculate and save hyperlink dimensions
		if is_hyperlink then --is hyperlink
			--get width of the topic word
			
			table.insert(hyperlinks[line_index], {
				text = word,
				x_min = line_width, --left bounds of hyperlink
				x_max = line_width + word_width, --right bounds of hyperlink
				width = word_width, --width of hyperlink
			})
			
			--add to list of hyperlinks in this paragraph
			if not hyperlink_list[word] then --not already in list
				hyperlink_list[word] = true --to check if hyperlink is already in list
				table.insert(hyperlink_list, word)
			end
		end
		
		--append new word to existing text for this line
		text[line_index] = (text[line_index] or "")..prefix..word
		
		--append new word to existing raw text for this line
		raw_text[line_index] = (raw_text[line_index] or "")..(is_hyperlink and "@" or "")..prefix..word
		
		if new_line then
			--start new line
			line_index = line_index + 1
			line_width = 0
		end
		
		--calculate new width of current line
		scratch_surface:set_text(text[line_index])
		line_width = scratch_surface:get_size()
		
		needs_refresh = true
		
		return line_index --successful
	end
	
	function ml:add_line(text)
		text = text or ""
		assert(type(text)=="string", "Bad argument #1 to 'add_line' (string or nil expected, got "..type(text)..")")
		
		local line_text = ""
		local word_it = text:gmatch"(%s*)(@?)([^%p%s]*)(%S*)"
		local word_width
		
		local spaces, is_topic, word, punctuation = word_it() --get first word of line
		while word do
			--determine how many pixels wide next word is including leading spaces
			scratch_surface:set_text(spaces..word..punctuation)
			word_width = scratch_surface:get_size()
			
			if line_width + word_width <= width then --enough room to fit word on current line
				self:add_word(spaces)
				self:add_word(word, is_topic=="@")
				self:add_word(punctuation)
			else --put word on new line omitting leading spaces
				--start new line
				line_index = line_index + 1
				line_width = 0
				
				if line_index <= num_lines then --still more lines available
					self:add_word(word, is_topic=="@")
					self:add_word(punctuation)
				else --no more lines available; save remaining text for later
					local overflow = {is_topic, word, punctuation}
					for a,b,c,d in word_it do --move unprocessed text to overflow
						table.insert(overflow, a)
						table.insert(overflow, b)
						table.insert(overflow, c)
						table.insert(overflow, d)
					end
					
					return table.concat(overflow, "") --remainder of text not yet processed
				end
			end
			
			spaces, is_topic, word, punctuation = word_it() --get next word of line
		end
		
		--start new line for next time
		line_index = line_index + 1
		line_width = 0
		
		return false --no overflow
	end
	
	function ml:get_max_lines() return num_lines end
	function ml:get_line_index() return line_index end
	function ml:is_full() return line_index > num_lines end
	
	function ml:get_text()
		local text = {}
		for _,line in ipairs(raw_text) do
			local line_text = line:match"^(%s*)(%.-)(%s*)$"
			if line_text~="" then table.insert(text, line) end
		end
		
		return table.concat(text, "\n")
	end
	
	function ml:get_hyperlinks() return hyperlink_list end --TODO return copy of table
	
	function ml:get_size() return surface:get_size() end
	
	function ml:on_mouse_released(button, x, y)
		if button=="left" and y then --only care if mouse released inside control bounds
			local line = math.floor(y/text_height)+1 --line the cursor clicked on
			local links = hyperlinks[line] --hyperlinks on clicked line
			
			for _,bounds in ipairs(links or {}) do
				if x >= bounds.x_min and x <= bounds.x_max then --mouse clicked on this hyperlink text
					if self.on_hyperlink then --only if control instance defines this function
						self:on_hyperlink(bounds.text)
					end
					
					return true --hyperlink found
				end
			end
		end
	end
	
	
	--multiply this value by the width of the text field to get horizontal origin for drawing text depending on horz alignment
	local alignment_offsets = {
		left = 0,
		center = 0.5,
		right = 1,
	}
	function ml:refresh()
		surface:clear()
		
		for i,text_line in ipairs(text) do
			text_surface:set_text(text_line) --put text for this line in text_surface
			local text_width = text_surface:get_size()
			
			--find coordinates of where to place text
			local x_offset = alignment_offsets[horz_alignment] * (width - text_width)
			local y_offset = (i-1) * text_height
			
			--create text shadow for entire line
			if shadow_color then
				text_surface:set_color(shadow_color)
				text_surface:draw(surface, x_offset+1, y_offset+1) --shadow is 1px down and to the right of text
			end
			
			local x_start = 0 --x position of first text to place
			local x_end, x_width
			if is_hyperlinks and hyperlink_color then
				--left to right, alternate in placing non-hyperlink and hyperlink text in different colors
				for _,hyper_info in ipairs(hyperlinks[i] or {}) do
					
					--// place non-hyperlink text up to next hyperlink
					
					x_end = hyper_info.x_min
					x_width = x_end - x_start
					
					text_surface:set_color(font_color)
					text_surface:draw_region(x_start, 0, x_width, text_height, surface, x_offset+x_start, y_offset)
					
					--// place this hyperlink text
					
					x_start = x_end
					x_end = hyper_info.x_max
					x_width = hyper_info.width
					
					text_surface:set_color(hyperlink_color)
					text_surface:draw_region(x_start, 0, x_width, text_height, surface, x_offset+x_start, y_offset)
					
					x_start = x_end --position to begin next iteration
				end
			end
			
			--place any non-hyperlink text after last hyperlink
			x_end = width
			x_width = x_end - x_start
			if x_width > 0 then
				text_surface:set_color(font_color)
				text_surface:draw_region(x_start, 0, x_width, text_height, surface, x_offset+x_start, y_offset)
			end
		end
		
		needs_refresh = false
	end
	
	function ml:draw(dst_surface, x, y)
		--if is_visible then --TODO
		if needs_refresh then self:refresh() end --don't redraw if nothing has changed since last draw
		surface:draw(dst_surface, self.x+x, self.y+y)
	end
	
	ml:clear()
	
	return ml
end

return multiline


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
