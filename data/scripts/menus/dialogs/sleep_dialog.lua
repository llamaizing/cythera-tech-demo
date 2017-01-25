--[[ sleep_dialog.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a dialog menu allowing the player to choose how long to sleep when
	interacting with a bed.
]]

local sleep_dialog = {}

local ui_draw = require"scripts/lib/uix/ui_draw" --TODO why is this here?
local uix = require"scripts/lib/uix/ui_express"

function sleep_dialog:initialize(game)
	local dialog_box = require"scripts/menus/menu"{
		--settings
		dialog = nil,
		info = nil,
		
		--drawables
		menu_surface = nil,
		box_frame = nil,
		box_tint = nil,
		title = nil,
		buttons = {},
	}
	
	--private variables
	local pos_x,pos_y = 0,0
	
	--constants
	local BUTTON_HEIGHT = 32
	local BOX_SIZE = {x=272, y=352}
	
	--specifications for each button in menu
	local buttons = {
		{
			label = "menu.sleep.dawn_button",
			width = 256,
			set_time = 6, --6AM
		},
		{
			label = "menu.sleep.morning_button",
			width = 256,
			set_time = 8, --8AM
		},
		{
			label = "menu.sleep.noon_button",
			width = 256,
			set_time = 12, --12PM
		},
		{
			label = "menu.sleep.sunset_button",
			width = 256,
			set_time = 18 --6PM
		},
		{
			label = "menu.sleep.midnight_button",
			width = 256,
			set_time = 0, --12AM
		},
		{
			label = "menu.sleep.hours_button",
			width = 128,
			on_clicked = function() game:stop_dialog(-1*dialog_box.hours_increment:get_value()) end,
		},
		{
			label = "menu.cancel_button",
			width = 128,
			on_clicked = function() game:stop_dialog() end,
		},
		gap = 8,
	}
	
	local dialog_bg_fill = {0, 0, 191, 127} --50% blue fill
	
	
	--// creates a button using info from buttons table
	local function create_button(button_info)
		local label = sol.language.get_string(button_info.label) or "???"
		local button = uix.button{
			style = "textbutton",
			width = button_info.width,
			height = BUTTON_HEIGHT,
			text_key = button_info.label
		}
		
		--assign button action
		if type(button_info.on_clicked)=="function" then
			button.on_clicked = button_info.on_clicked
		elseif button_info.set_time then
			button.on_clicked = function()
				game:stop_dialog(button_info.set_time)
			end
		end
		
		return button
	end
	
	--initialize dialog box
	dialog_box.menu_surface = sol.surface.create(sol.video.get_quest_size()) --full quest screen
	
	dialog_box.box_frame = ui_draw.load_frame{
		path = "menus/dialog_frame.png",
		width = BOX_SIZE.x,
		height = BOX_SIZE.y,
		border = 8,
		is_hollow = true,
	}
	
	dialog_box.box_tint = sol.surface.create(BOX_SIZE.x, BOX_SIZE.y)
	dialog_box.box_tint:fill_color(dialog_bg_fill)
	
	dialog_box.title = uix.text_label{
		width = 256,
		height = 40,
		horizontal_alignment = "center",
		font = "librefranklin-bold",
		font_size = 16,
		rendering_mode = "antialiasing",
		font_color = {255, 255, 0}, --yellow
		shadow_color = {0, 0, 0}, --black
	}
	for _,button_info in ipairs(buttons) do
		table.insert(dialog_box.buttons, create_button(button_info))
	end
	
	dialog_box.hours_increment = uix.incrementer{
		style = "textbox",
		width = 128,
		height = BUTTON_HEIGHT,
		value = 1,
		minimum = 1,
		maximum = 24,
	}
	
	
	--// Called when dialog starts
		--arg1 dialog (table): entry from dialogs.dat to display
		--arg2 info (string or table array of strings): strings to substitute for $v values
	function dialog_box:start_dialog(dialog, info)
		dialog_box.dialog = dialog
		dialog_box.info = type(info)=="string" and {info} or info --if info is string then convert to table containing the string
		
		sol.menu.start(game, dialog_box)
	end
	
	
	----------------------
	-- Build Dialog Box --
	----------------------
	
	dialog_box:add_control(dialog_box.box_tint, 0, 0)
	dialog_box:add_control(dialog_box.box_frame, 0, 0)
	dialog_box:add_control(dialog_box.title, 136, 8)
	
	local x_offset = 8
	local y_offset = 32
	
	for _,button in ipairs(dialog_box.buttons) do
		local b_width, b_height = button:get_size()
		dialog_box:add_control(button, x_offset, y_offset)
		y_offset = y_offset + b_height + buttons.gap
	end
	
	dialog_box:add_control(dialog_box.hours_increment, 136,232)
	
	
	-----------------------
	-- Dialog Box Events --
	-----------------------
	
	--// First dialog of a sequence begins
	--// Called by sol.menu.start()
	function dialog_box:on_started()
		self.set_position() --center on screen
		
		local text = self.dialog.text:match"^([^\n]*)" --get first line (ignore rest)
		self.title:set_text(text)
		
		self:show_dialog()
	end
	
	
	--// Dialog box is closed
	function dialog_box:on_finished()
		self.hours_increment:set_value(1)
	end
	
	
	--------------------------
	-- Dialog Box Interface --
	--------------------------
	
	function dialog_box:get_bounding_box()
		local width,height = self.box_frame:get_size()
		
		return pos_x, pos_y, width, height
	end
	
	function dialog_box:get_position() return pos_x, pos_y end
	function dialog_box:set_position(x, y)
		x = tonumber(x)
		x = x and math.floor(x)
		y = tonumber(y)
		y = y and math.floor(y)
		
		if not x or not y then --place at center of screen
			local quest_width, quest_height = sol.video.get_quest_size()
			local box_width,box_height = dialog_box.box_frame:get_size() --TODO use width/height instead
			
			x = (quest_width - box_width)/2
			y = (quest_height - box_height)/2
		end
		
		pos_x,pos_y = x, y
	end
	
	function dialog_box:close()
		if sol.menu.is_started(dialog_box) then
			sol.menu.stop(dialog_box)
		end
		
		self.dialog = nil
		self.info = nil
	end
	
	
	-------------------------------
	-- Dialog Box Implementation --
	-------------------------------
	
	--// Shows new dialog box
	function dialog_box:show_dialog()
		--TODO
	end
	
	return dialog_box
end

setmetatable(sleep_dialog, {__call = sleep_dialog.initialize}) --convenience

return sleep_dialog


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
