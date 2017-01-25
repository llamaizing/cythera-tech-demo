--[[ text_label.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script draws a single line of text onto a surface of fixed width and height. Text
	exceeding the fixed dimensions will be clipped. An optional background image and color
	may also be drawn behind the text, where the image will be tiled to resize it to match
	the width and height of the surface.
	
	Valid styles:
	  * title: Font 8_bit used for text with label frame background image
	  * none: No stlye used and all properties must be specified manually (default)
	
	--TODO change instances of tv to tl (text_label, not text_view)
]]


local text_label = {}

local ui_draw = require"scripts/lib/uix/ui_draw"
local styles = require"scripts/lib/uix/controls/text_label.dat"

local alignment_offsets = {
	left = 0,
	center = 0.5,
	right = 1,
	top = 0,
	middle = 0.5,
	right = 1,
}

--TODO validation of properties
--// Creates a new text_label instance
	--arg1 properties (table): key/value pairs of the properties to set for the text view:
		--style (string, optional): Name of pre-defined style to use (see text_label.dat)
		--width (positive number, optional): width of control in pixels; if omitted then sized to fit initial text
			--width is fixed and cannot be changed later
		--max_width (positive number, optional): maximum width allowed when auto-sized to fit initial text
			--any text exceeding the maximum width will be clipped
			--max_width is meaningless if width is specified
		--height (positive number, optional): height of control in pixels; if omitted then sized to fit initial text
			--height is fixed and cannot be changed later
		--horizontal_alignment (string, default "left"): determines placement of origin in the horizontal direction ("left", "center" or "right")
		--vertical_alignment (string, default "top"): determines placement of origin in the vertical direction ("top", "middle" or "bottom")
		
	--* Surface background image/color:
		--bg_color (table, optional): table of 3 RGB or 4 RGBA color values (0-255) to fill the surface before drawing the background image or text
		--bg_img (string, optional): file path of image to draw on the control before drawing the text
			--image will be resized by tiling to fit the width and height of the control
		--img_x (number, default 0): x coordinate of top-left corner of region to use for bg_img
		--img_y (number, default 0): y coordinate of top-left corner of region to use for bg_img
		--img_width (number, optional): width of region to use for bg_img
		--img_height (number, optional): height of region to use for bg_img
		--border (number): number of pixels from edge to define regions of bg_img for tiling purposes
		
	--* Text Properties: (unless otherwise specified, defaults values are the same used by sol.text_surface)
		--font (string): Name of the font to use for the text
		--font_size (number): font size of text (outline fonts only)
		--font_color (table): table of 3 RGB color values (0-255) for text color (outline fonts only)
		--shadow_color (table, optional): If using an outline font then the text will be drawn 1 pixel to
			--the bottom-right in this color to create a shadow effect, with the actual text drawn on top.
			--Color is table of 3 RGB color values (0-255)
		--font_color_disabled (table, optional): If using an outline font, this color will
			--be used instead of font_color when the control is disabled.
			--Color is table of 3 RGB color values (0-255)
		--rendering_mode (string): "solid" (faster) or "antialiasing" (smooths edges) (outline fonts only)
		--text (string, optional): initial text to display
		--text_key (string, optional): key for localized text to display initially
		
		--margin_x (number): number of pixels to keep text away from surface edge in horizontal direction
			--if width is 16 and margin_x is 2 then the text can be up to 12 pixels wide (2 pixel border on left and right side)
		--margin_y (number): number of pixels to keep text away from surface edge in vertical direction
		
		--is_visible (boolean, optional): If false then control will not be drawn initially.
			--use the :set_visible(true) function to make the control visible later
		--is_enabled (boolean, optional): If false then the control will be disabled initially.
			--while disabled font_color_disabled color will be used for text instead of font_color
	--ret1 (table): the newly created text_label instance
function text_label.create(properties)
	assert(type(properties)=="table", "Bad argument #1 to 'create' (table expected, got "..type(properties)..")")
	
	local style = properties.style or "none"
	local style_info = styles[style] --convenience
	assert(style_info, "Bad argument #1 to 'create' (invalid value for style)")
	
	--create text surface with specified properties
	local text_surface = sol.text_surface.create{
		horizontal_alignment = "left",
		vertical_alignment = "top",
		
		font = properties.font or style_info.font,
		font_size = properties.font_size or style_info.font_size,
		color = properties.font_color or style_info.font_color,
		rendering_mode = properties.rendering_mode or style_info.rendering_mode,
		text = properties.text,
		text_key = properties.text_key,
	}
	
	local margin_x = tonumber(properties.margin_x) or tonumber(style_info.margin_x) or 0
	local margin_y = tonumber(properties.margin_y) or tonumber(style_info.margin_y) or 0
	
	local w,h = text_surface:get_size()
	local width = math.floor(tonumber(properties.width) or w + 2*margin_x)
	local height = math.floor(tonumber(properties.height) or h + 2*margin_y)
	
	local max_width = tonumber(properties.max_width)
	if max_width and max_width>0 then --ignore if negative number
		max_width = math.floor(max_width)
		width = math.min(width, max_width)
	end
	
	assert(width>0, "Bad argument #1 to 'create' (width value must be positive number)")
	assert(height>0, "Bad argument #1 to 'create' (height value must be positive number)")
	
	local tv = {x=0, y=0} --table to be returned
	local surface = sol.surface.create(width, height)
	
	--settings
	local horz_alignment = properties.horizontal_alignment or style_info.horizontal_alignment or "left"
	local vert_alignment = properties.vertical_alignment or style_info.vertical_alignment or "top"
	local text_horz_alignment = properties.text_horizontal_alignment or style_info.text_horizontal_alignment or horz_alignment
	local text_vert_alignment = properties.text_vertical_alignment or style_info.text_vertical_alignment or vert_alignment
	local font_color = properties.font_color or style_info.font_color
	local shadow_color = properties.shadow_color or style_info.shadow_color
	local bg_color = properties.bg_color or style_info.bg_color
	local bg_img = properties.bg_img or style_info.bg_img
	
	local parent
	local is_visible = properties.is_visible~=false
	local is_enabled = properties.is_enabled~=false
	local needs_refresh = true
	
	local bg_surface = bg_img and ui_draw.load_frame{
		path = bg_img,
		src_x = properties.img_x or style_info.img_x or 0,
		src_y = properties.img_y or style_info.img_y or 0,
		src_width = properties.img_width or style_info.img_width,
		src_height = properties.img_height or style_info.img_height,
		width = width,
		height = height,
		border = properties.border or style_info.border,
	}
	
	--// Surface methods
	
	function tv:get_size() return surface:get_size() end
	
	function tv:get_xy() return self.x, self.y end
	function tv:set_xy(x, y)
		self.x = tonumber(x)
		self.y = tonumber(y)
	end
	
	function tv:get_blend_mode() return surface:get_blend_mode() end
	function tv:set_blend_mode(blend_mode) surface:set_blend_mode(blend_mode) end
	
	function tv:fade_in(delay, callback) surface:fade_in(delay, callback) end
	function tv:fade_out(delay, callback) surface:fade_out(delay, callback) end
	
	function tv:get_movement() return surface:get_movement() end
	function tv:stop_movement() return surface:stop_movement() end
	function tv:start_movement(movement, callback)
		assert(sol.main.get_type(movement)=="movement", "Bad argument #1 to 'start_movement' (sol.movement expected, got "..sol.main.get_type(movement)..")")
		assert(not callback or type(callback)=="function", "Bad argument #2 to 'start_movement' (function or nil expected, got "..type(callback)..")")
		
		movement:start(surface, callback)
	end
	
	function tv:get_opacity() return surface:get_opacity() end
	function tv:set_opacity(opacity) return surface:set_opacity(opacity) end
	
	--// Text surface methods
	
	function tv:get_horizontal_alignment() return text_horz_alignment end
	function tv:set_horizontal_alignment(value)
		text_horz_alignment = value
		self:needs_refresh()
	end
	
	function tv:get_vertical_alignment() return vertical_alignment end
	function tv:set_vertical_alignment(value)
		vertical_alignment = value
		self:needs_refresh()
	end
	
	function tv:get_font() return text_surface:get_font() end
	function tv:set_font(font_id)
		text_surface:set_font(font_id)
		self:needs_refresh()
	end
	
	function tv:get_rendering_mode() return text_surface:get_rendering_mode() end
	function tv:set_rendering_mode(rendering_mode)
		text_surface:set_rendering_mode(rendering_mode)
		self:needs_refresh()
	end
	
	function tv:get_font_color() return text_surface:get_color() end
	function tv:set_font_color(color)
		text_surface:set_color(color)
		self:needs_refresh()
	end
	
	function tv:get_font_size() return text_surface:get_font_size() end
	function tv:set_font_size(font_size)
		text_surface:set_font_size(font_size)
		self:needs_refresh()
	end
	
	function tv:get_text() return text_surface:get_text() end
	function tv:set_text(text)
		text_surface:set_text(text)
		self:needs_refresh()
	end
	
	function tv:set_text_key(key)
		text_surface:set_text_key(key)
		self:needs_refresh()
	end
	
	function tv:get_text_size() return text_surface:get_size() end
	
	--// Implementation
	
	--// Parent control gets refreshed when this control is refreshed (compound controls only)
	function tv:get_parent() return parent end
	function tv:set_parent(new_parent) parent = new_parent end
	
	
	--// Returns true if control is visible, else returns false
	function tv:get_visible() return is_visible end
	--// Sets visibility of control
		--arg1 visible (boolean, default true): true for control to be visible, false for hidden
	function tv:set_visible(visible) is_visible = visible~=false end --refresh not necessary
	
	
	--// Returns true if control is enabled, else returns false
	function tv:get_enabled() return is_enabled end
	--// Enables/disables control (prevents mouse events when disabled)
		--arg1 enabled (boolean, default true): true for control to be enabled, false for disabled
	function tv:set_enabled(enabled)
		enabled = enabled~=false
		if enabled ~= is_enabled then --only update if enabled state changed
			is_enabled = enabled
			self:needs_refresh() --disabled control may use different image (e.g. greyed out)
		end
	end
	
	
	--// Returns true if the control needs to be refreshed before next draw
	function tv:is_needs_refresh() return needs_refresh end
	--// Calling this function forces the control to be refreshed before the next draw
	function tv:needs_refresh()
		needs_refresh = true
		if parent and parent.needs_refresh then parent.needs_refresh() end
	end
	
	
	--// Redraws primary surface whenever content changes
	function tv:refresh()
		surface:clear()
		
		if bg_color then surface:fill_color(bg_color) end
		if bg_surface then bg_surface:draw(surface) end
		
		local text_width,text_height = text_surface:get_size()
		
		if shadow_color then
			text_surface:set_color(shadow_color)
			text_surface:draw_region(
				text_width<=width and 0 or (text_width - width)*alignment_offsets[text_horz_alignment], --region_x
				text_height<=height and 0 or (text_height - height)*alignment_offsets[text_vert_alignment], --region_y
				text_width<=width and text_width or width, --region_width
				text_height<=height and text_height or height, --region_height
				surface,
				(text_width<=width and (width - text_width)*alignment_offsets[text_horz_alignment] or 0) + 1, --x
				(text_height<=height and (height - text_height)*alignment_offsets[text_vert_alignment] or 0) + 1 --y
			)
			text_surface:set_color(font_color)
		end
		
		text_surface:draw_region(
			text_width<=width and 0 or (text_width - width)*alignment_offsets[text_horz_alignment], --region_x
			text_height<=height and 0 or (text_height - height)*alignment_offsets[text_vert_alignment], --region_y
			text_width<=width and text_width or width, --region_width
			text_height<=height and text_height or height, --region_height
			surface,
			text_width<=width and (width - text_width)*alignment_offsets[text_horz_alignment] or 0, --x
			text_height<=height and (height - text_height)*alignment_offsets[text_vert_alignment] or 0 --y
		)
	end
	
	
	--// If needs refresh then returns true and does the refresh, else returns false
	function tv:is_refresh()
		if needs_refresh then
			self:refresh()
			return true
		else return false end
	end
	
	
	--// Draws primary surface on the destination surface each frame
	function tv:draw(dst_surface, x, y)
		x = tonumber(x) or 0
		y = tonumber(y) or 0
		
		if needs_refresh then self:refresh() end
		if is_visible then
			surface:draw(
				dst_surface,
				self.x + x - width*alignment_offsets[horz_alignment],
				self.y + y - height*alignment_offsets[vert_alignment]
			)
		end
	end
	
	return tv
end

return text_label


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
