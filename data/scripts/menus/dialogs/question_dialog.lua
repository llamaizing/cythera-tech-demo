--[[ question_dialog.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a dialog menu that asks the player a question with buttons for the
	player to choose to give a response.
]]

local question_dialog = {}

local uix = require"scripts/lib/uix/ui_express"

function question_dialog:initialize(game)
	local dialog_box = require"scripts/menus/menu"{
		--settings
		dialog = nil,
		info = nil,
		
		--drawables
		menu_surface = nil,
		box_frame = nil,
		--box_tint = nil,
		title = nil,
		buttons = {},
	}
	
	--private variables
	local pos_x,pos_y = 0,0
	
	--constants
	local TEXT_LINE_HEIGHT = 20
	local BUTTON_HEIGHT = 32
	local BOX_SIZE = {x=320, y=128}
	local num_lines = 2
	
	local buttons = {
		{ --button1
			width = 80,
			x_offset = 216,
			on_clicked = function() game:stop_dialog(1) end,
		},
		{ --button2
			width = 80,
			x_offset = 124,
			on_clicked = function() game:stop_dialog(2) end,
		},
		{ --button3
			width = 96,
			x_offset = 20,
			on_clicked = function() game:stop_dialog(3) end,
		},
	}
	
	
	local function create_button(button_info)
		local button = uix.button{
			style = "textbutton",
			width = button_info.width,
			height = BUTTON_HEIGHT,
			text = button_info.label,
			on_clicked = button_info.on_clicked,
		}
		
		return button
	end
	
	--initialize dialog box
	dialog_box.menu_surface = sol.surface.create(sol.video.get_quest_size()) --full quest screen
	
	dialog_box.box_frame = uix.frame{
		style = "questiondialogframe",
		width = BOX_SIZE.x,
		height = BOX_SIZE.y,
	}
	
	for _,button_info in ipairs(buttons) do
		table.insert(dialog_box.buttons, create_button(button_info))
	end
	
	dialog_box.highlight_light = uix.frame{
		style = "highlightframe_light",
		width = buttons[1].width + 10,
		height = BUTTON_HEIGHT + 10,
	}
	dialog_box.highlight_light:set_blend_mode"add"
	
	dialog_box.highlight_corners = uix.frame{
		style = "highlightframe_corners",
		width = buttons[1].width + 10,
		height = BUTTON_HEIGHT + 10,
	}
	
	dialog_box.highlight_dark = uix.frame{
		style = "highlightframe_dark",
		width = buttons[1].width + 10,
		height = BUTTON_HEIGHT + 10,
	}
	dialog_box.highlight_dark:set_blend_mode"multiply"
	
	dialog_box.question_text = uix.multiline{
		style = "blacktext",
		num_lines = num_lines,
		width = 280,
		height = num_lines*TEXT_LINE_HEIGHT,
		text_height = TEXT_LINE_HEIGHT,
		horizontal_alignment = "center",
		is_hyperlinks = false,
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
	
	dialog_box:add_control(dialog_box.box_frame, 0, 0)
	dialog_box:add_control(dialog_box.question_text, 20, 20)
	
	--local x_offset = 20
	local y_offset = 72
	
	for i,button in ipairs(dialog_box.buttons) do
		local b_width, b_height = button:get_size()
		dialog_box:add_control(button, buttons[i].x_offset, y_offset)
		--x_offset = x_offset + b_width + buttons.gap
	end
	
	dialog_box:add_control(dialog_box.highlight_light, 211, 67)
	dialog_box:add_control(dialog_box.highlight_corners, 211, 67)
	dialog_box:add_control(dialog_box.highlight_dark, 211, 67)
	
	
	-----------------------
	-- Dialog Box Events --
	-----------------------
	
	--// First dialog of a sequence begins
	--// Called by sol.menu.start()
	function dialog_box:on_started()
		self.set_position() --center on screen
		
		self.question_text:clear()
		self.question_text:add_line(self.dialog.text)
		
		dialog_box.buttons[1]:set_text(self.dialog.option1)
		dialog_box.buttons[2]:set_text(self.dialog.option2)
		dialog_box.buttons[3]:set_text(self.dialog.option3)
		
		dialog_box.buttons[1]:set_visible(dialog_box.buttons[1]:get_text()~="")
		dialog_box.buttons[2]:set_visible(dialog_box.buttons[2]:get_text()~="")
		dialog_box.buttons[3]:set_visible(dialog_box.buttons[3]:get_text()~="")
		
		dialog_box.default_enter = tonumber(self.dialog.default_enter)
		dialog_box.default_esc = tonumber(self.dialog.default_esc)
		
		self:show_dialog()
	end
	
	
	--// Dialog box is closed
	function dialog_box:on_finished()
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
			y = (quest_height - box_height)/4
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
	
	
	----------------------
	-- Input Processing --
	----------------------
	
	--// Processes key presses
	local menu_on_key_pressed = dialog_box.on_key_pressed --function inherited from menu
	function dialog_box:on_key_pressed(key, modifiers)
		local hotkeys = {
			['escape'] = dialog_box.default_esc,
			['return'] = dialog_box.default_enter,
		}
		
		if hotkeys[key] then
			local button = dialog_box.buttons[ hotkeys[key] ]
			if button and button.on_clicked then button:on_clicked() end
			return true
		end
	
		return menu_on_key_pressed and menu_on_key_pressed(self, key, modifiers)
	end
	
	return dialog_box
end

setmetatable(question_dialog, {__call = question_dialog.initialize}) --convenience

return question_dialog


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
