--[[ ui_draw.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script automates various ui drawing tasks.
]]

local ui_draw = {}

--// Draws a source surface onto a destination surface, resizing the source image to fit
--// the destination dimension by tiling the middle segment as necessary
	--arg1 src: sol.surface or table defining source image to use
		--(sol.surface):
		--(table): table containing the following keys:
			--surface (sol.surface) --surface with source image to use
			--x (number, default 0): x coordinate of region to use from src surface
			--y (number, default 0): y coordinate of region to use from src surface
			--width (positive number, default width of src surface): width of source region to use
			--height (positive number, default height of src surface): height of source region to use
			--border (number, default 0): distance from edges of drawable region denoting the non-repeating section of the image
	--arg2 dst: sol.surface or table defining destination surface to draw on
		--(sol.surface):
		--(table): table containing the following keys:
			--surface (sol.surface or nil) --surface to draw to
				--if omitted then a new surface will be created with specified width/height
			--x (number, default 0): x coordinate of where to draw on dst surface
			--y (number, default 0): y coordinate of where to draw on dst surface
			--width (positive number, default width of dst surface): width of destination region to draw
			--height (positive number, default height of dst surface): height of destination region to draw
	--arg3 is_hollow (boolean, default false): if true then middle part of frame not drawn, only edges and corners
function ui_draw.draw_frame(src, dst, is_hollow)
	--// Convert src and dst arguments to table format, validate values and assign defaults for omitted values
	
	assert(sol.main.get_type(src)=="surface" or type(src)=="table", "Bad argument #1 to 'draw_frame' (table or sol.surface expected, got "..sol.main.get_type(src)..")")
	assert(sol.main.get_type(dst)=="surface" or type(src)=="table", "Bad argument #2 to 'draw_frame' (table or sol.surface expected, got "..sol.main.get_type(dst)..")")
	
	local src_surface
	local src_width, src_height
	local src_x, src_y
	
	local dst_surface
	local dst_width, dst_height
	local dst_x, dst_y
	
	local border
	
	--validate and reformat src
	if sol.main.get_type(src)=="surface" then
		src_surface = src
		src_x = 0
		src_y = 0
		src_width,src_height = src:get_size()
		border = 0
	else
		assert(sol.main.get_type(src.surface)=="surface", "Bad value for 'surface' of argument #1 to 'draw_frame' (sol.surface expected, got "..sol.main.get_type(src.surface)..")")
		src_width,src_height = src.surface:get_size()
		
		src_surface = src.surface
		src_x = math.floor(tonumber(src.x) or 0)
		src_y = math.floor(tonumber(src.y) or 0)
		src_width = math.floor(tonumber(src.width) or src_width)
		src_height = math.floor(tonumber(src.height) or src_height)
		border = math.floor(tonumber(src.border) or 0)
	end
	
	--validate and reformat dst
	if sol.main.get_type(dst)=="surface" then
		dst_surface = dst
		dst_x = 0
		dst_y = 0
		dst_width,dst_height = dst:get_size()
	else
		assert(not dst.surface or sol.main.get_type(dst.surface)=="surface", "Bad value for 'surface' of argument #2 to 'draw_frame' (sol.surface or nil expected, got "..sol.main.get_type(dst.surface)..")")
		
		if dst.surface then
			dst_width,dst_height = dst.surface:get_size()
			
			dst_surface = dst.surface
			dst_x = math.floor(tonumber(dst.x) or 0)
			dst_y = math.floor(tonumber(dst.y) or 0)
			dst_width = math.floor(tonumber(dst.width) or dst_width)
			dst_height = math.floor(tonumber(dst.height) or dst_height)
		else
			dst_width = math.floor(tonumber(dst.width) or 0)
			dst_height = math.floor(tonumber(dst.height) or 0)
			
			assert(dst_width>0, "Bad value for 'width' of argument #2 to 'draw_frame' (positive number expected)")
			assert(dst_height>0, "Bad value for 'height' of argument #2 to 'draw_frame' (positive number expected)")
			
			dst_surface = sol.surface.create(dst_width, dst_height)
			dst_x = math.floor(tonumber(dst.x) or 0)
			dst_y = math.floor(tonumber(dst.y) or 0)
		end
	end
	
	--// Draw frame on dst_surface
	
	local mid_x,mid_y = src_width-2*border, src_height-2*border --convenience (length/width of src middle segment)
	
	--Tile image segments to draw full-size image on button_surface and button_surface_pushed
	if src_width~=dst_width or src_height~=dst_height then --only tile if source size is different than destination size
		local x,y = border, border --keep track of current position on dst
		while y < dst_height do
			x = border --start new row
			
			--draw middle region across for this row
			while x < dst_width - border and not is_hollow do --don't draw middle region if hollow
				src_surface:draw_region(
					src_x + border,
					src_y + border,
					math.min(mid_x, dst_width - border - x), --last segment may be narrower
					math.min(mid_y, dst_height - border - y), --last row may be shorter
					dst_surface,
					dst_x + x,
					dst_y + y
				)
				x = x + mid_x --move right to the next segment
			end
			
			--draw right edge for this row
			src_surface:draw_region(
				src_x + src_width - border,
				src_y + border,
				border,
				math.min(mid_y, dst_height - border - y), --may be shorter at last row
				dst_surface,
				dst_x + dst_width - border,
				dst_y + y
			)
			
			--draw left edge for this row
			src_surface:draw_region(
				src_x,
				src_y + border,
				border,
				math.min(mid_y, dst_height - border - y), --may be shorter at last row
				dst_surface,
				dst_x,
				dst_y + y
			)
		
			y = y + mid_y --move down to next row
		end
	
		--draw top and bottom edge across
		x = border --restart row
		while x < dst_width - border do
			--draw top edge
			src_surface:draw_region(
				src_x + border,
				src_y,
				math.min(mid_x, dst_width - border - x), --last segment may be narrower
				border,
				dst_surface,
				dst_x + x,
				dst_y
			)
			--draw bottom edge
			src_surface:draw_region(
				src_x + border,
				src_y + src_height - border,
				math.min(mid_x, dst_width - border - x), --last segment may be narrower
				border,
				dst_surface,
				dst_x + x,
				dst_y + dst_height - border
			)
		
			x = x + mid_x
		end
	
		--// draw four corners
		
		--Upper-left corner
		src_surface:draw_region(src_x, src_y, border, border, dst_surface, dst_x, dst_y)
		--Upper-right corner
		src_surface:draw_region(
			src_x + src_width - border,
			src_y,
			border,
			border,
			dst_surface,
			dst_x + dst_width - border,
			dst_y
		)
		--Lower-left corner
		src_surface:draw_region(
			src_x,
			src_y + src_height - border,
			border,
			border,
			dst_surface,
			dst_x,
			dst_y + dst_height - border
		)
		--Lower-right corner
		src_surface:draw_region(
			src_x + src_width - border,
			src_y + src_height - border,
			border,
			border,
			dst_surface,
			dst_width - border,
			dst_height - border
		)
	else src_surface:draw_region(src_x, src_y, src_width, src_height, dst_surface, dst_x, dst_y) end --not tiled
	
	return dst_surface
end

local saved_images = {}
local saved_surfaces = {}

--// Generates an image resized and drawn to a surface of specified dimensions.
--// If previously generated a surface with same dimensions and source image then
--// reuses it instead of redrawing a new one.
	--arg1 properties (table): has the following keys:
		--path (string): Name of the source image file to load
		--border (number, default 0): distance from edges of drawable region denoting the non-repeating section of the source image
		--src_x (number):
		--src_y (number):
		--src_width
		--src_height
		--width (number): width of destination region to draw
		--height (number): height of destination region to draw
		--is_hollow (boolean, default false): if true then middle part of frame not drawn, only edges and corners
	--ret1 (sol.surface): surface with resized source image drawn on it
--NOTE: Do not draw on the returned surface or clear it because it may be used in multiple places
--Use draw_frame() if you need multiple copies of the same pre-drawn surface
--TODO add support for language-specific sprites from language directory
function ui_draw.load_frame(properties)
	if type(properties)=="string" then properties = {path = properties} end
	assert(type(properties)=="table", "Bad argument #1 to 'load_frame' (string or table expected, got "..type(properties)..")")
	
	local file_path = properties.path
	local border = math.floor(tonumber(properties.border) or 0)
	local src_x = tonumber(properties.src_x)
	local src_y = tonumber(properties.src_y)
	
	
	local dst_width = tonumber(properties.width)
	local dst_height = tonumber(properties.height)
	local is_hollow = not not properties.is_hollow
	
	assert(type(file_path)=="string", "Bad argument #1 to 'load_frame' (string expected, got "..type(file_path)..")")
	assert(border>=0, "Bad argument #2 to 'load_frame' (non-negative number expected)")
	
	--get source surface
	local src_surface
	if saved_images[file_path] then
		src_surface = saved_images[file_path]
	else
		src_surface = sol.surface.create(file_path)
		assert(src_surface, "Invalid file path specified for argument #1 to 'load_frame'")
		
		saved_images[file_path] = src_surface
	end
	
	--TODO optimize to return src_surface if width/height not specified
	
	local w,h = src_surface:get_size()
	local src_width = tonumber(properties.src_width) or w
	local src_height = tonumber(properties.src_height) or h
	dst_width = math.floor(dst_width or src_width)
	dst_height = math.floor(dst_height or src_height)
	local src_coordinates = (src_x or 0).."x"..(src_y or 0).."x"..(src_width or 0).."x"..(src_height or 0)
	local size = dst_width.."x"..dst_height
	
	local frame --surface to return
	saved_surfaces[file_path] = saved_surfaces[file_path] or {}
	saved_surfaces[file_path][src_coordinates] = saved_surfaces[file_path][src_coordinates] or {}
	if saved_surfaces[file_path][src_coordinates][size] then
		frame = saved_surfaces[file_path][src_coordinates][size]
	else --generate new surface
		frame = ui_draw.draw_frame(
			{
				surface = src_surface,
				border = border,
				x = src_x,
				y = src_y,
				width = src_width,
				height = src_height,
			},
			{
				width = dst_width,
				height = dst_height,
			},
			is_hollow
		)
		
		saved_surfaces[file_path][src_coordinates][size] = frame --save reference to new surface
	end
	
	return frame
end

return ui_draw


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
