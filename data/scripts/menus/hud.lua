--[[ hud.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This scrips draws the interface elements that are outside of the map window. The items
	included are a frame image around the map area with a title at the top, a console that
	displays messages related to the player's actions, a list of objectives for the player
	to complete, and a journal displaying text saved from conversations with NPCs.
	
	It also handles mouse and keyboard events for interacting with the interface elements.
]]

local hud_view = {}

local uix = require"scripts/lib/uix/ui_express"
local ui_draw = require"scripts/lib/uix/ui_draw"
local objectives = require"scripts/objectives_manager"


function hud_view:initialize(game)
	local hud = require"scripts/menus/menu"{
		menu_surface = sol.surface.create(sol.video.get_quest_size()),
	}
	
	local map_frame = ui_draw.load_frame{
		path = "menus/map_frame.png",
		width = 352,
		height = 272,
		border = 16,
		is_hollow = true,
	}
	
	local objectives_title_bar = uix.frame{
		style = "titlebarframe",
		width = 288,
		height = 16,
	}
	
	local journal_title_bar = uix.frame{
		style = "titlebarframe",
		width = 288,
		height = 16,
	}
	
	local console_title_bar = uix.frame{
		style = "labelframe",
		width = 352,
		height = 16,
	}
	
	local console_log = uix.log_viewer{
		num_lines = 6,
		max_lines = 24, --6*64/16
		line_width = 336,
		line_height = 16,
		horz_margin = 4,
		font = "minecraftia",
		font_size = 7,
		bg_color = {255, 255, 255},
		prompt = "> ",
	}
	
	local console_scrollbar = uix.scrollbar{
		style = "vertical",
		width = 16,
		height = 96,
		on_clicked1 = function() console_log:scroll_line(1) end,
		on_clicked2 = function() console_log:scroll_line(-1) end,
	}
	console_log:link_slider(console_scrollbar)
	console_scrollbar:link_view(console_log)
	
	local journal_log = uix.journal_viewer{
		num_lines = 26,
		line_width = 272,
		line_height = 12,
		horz_margin = 4,
		font = "minecraftia",
		font_size = 7,
		bg_color = {255, 255, 255},
	}
	
	local journal_scrollbar = uix.scrollbar{
		style = "vertical",
		width = 16,
		height = 320,
		on_clicked1 = function() journal_log:scroll_line(1) end,
		on_clicked2 = function() journal_log:scroll_line(-1) end,
	}
	journal_log:link_slider(journal_scrollbar)
	journal_scrollbar:link_view(journal_log)
	
	local objectives_log = uix.draw_view{
		num_lines = 2,
		line_width = 272,
		line_height = 16,
		horz_margin = 4,
	}
	
	--Obj = objectives_log --DEBUG
	
	--create text labels
	local objectives_label = uix.text_label{
		style = "title",
		text_key = "hud.label.objectives",
		horizontal_alignment = "center",
		vertical_alignment = "middle",
		max_width = 128,
		height = 16,
	}
	local journal_label = uix.text_label{
		style = "title",
		text_key = "hud.label.journal",
		horizontal_alignment = "center",
		vertical_alignment = "middle",
		max_width = 128,
		height = 16,
	}
	local map_name_label = uix.text_label{
		style = "title",
		text_key = "map.city.cademia", --TODO use map world name instead of hard coded
		horizontal_alignment = "center",
		vertical_alignment = "middle",
		max_width = 160,
		height = 16,
	}
	
	--assign globals
	console = console_log
	game.journal = journal_log
	game.objectives = objectives.create(game, objectives_log)
	
	
	----------------
	-- Build Menu --
	----------------
	
	hud:add_control(map_frame, 288, 0)
	hud:add_control(objectives_title_bar, 0, 0)
	hud:add_control(journal_title_bar, 0, 48)
	hud:add_control(console_title_bar, 288, 272)
	
	hud:add_control(console_log, 288, 288)
	hud:add_control(journal_log, 0, 64)
	hud:add_control(objectives_log, 0, 16)
	
	hud:add_control(objectives_label, 144, 8)
	hud:add_control(journal_label, 144, 56)
	hud:add_control(map_name_label, 464, 8)
	
	hud:add_control(console_scrollbar, 624, 288)
	hud:add_control(journal_scrollbar, 272, 64)
	
	
	-----------------
	-- Menu Events --
	-----------------
	
	function hud:on_started()
		console:print(sol.language.get_string"console.initial") --console greeting message
	end
	
	function hud:on_finished()
	end
	
	
	--------------------
	-- Menu Interface --
	--------------------
	
	function hud:get_bounding_box()
		local width,height = self.menu_surface:get_size()
		
		return 0, 0, width, height
	end
	
	sol.menu.start(game, hud, false)
end

setmetatable(hud_view, {__call = hud_view.initialize}) --convenience

return hud_view


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
