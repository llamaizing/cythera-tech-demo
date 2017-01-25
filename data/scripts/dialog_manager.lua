--[[ dialog_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script manages all types of dialog boxes and decides which one to launch whenever
	game:start_dialog() is called. game:start_dialog() has a second parameter to determine
	which type of dialog box to use. It can be a string, or it can be a table with the key
	dlg_type, a string identifying the dialog type. When the dialog type is not specified,
	then the conversation dialog type is used by default.
	
	The following string values for the dialog type are possible:
	 * conversation: An interactive dialog in which the player interacts with NPCs
	 * sleep: A dialog that allows the player to select how many hours to advance the time
	 * question: A dialog asking a question with up to 3 options for the player to select
]]

local dlg_manager = {}

local active_dialog --string for the type of dialog currently displayed (nil if none)
local queue_list = {}

function dlg_manager:initialize(game)
	local dialogs = {
		conversation = require"scripts/menus/dialogs/conversation_dialog":initialize(game),
		sleep = require"scripts/menus/dialogs/sleep_dialog":initialize(game),
		question = require"scripts/menus/dialogs/question_dialog":initialize(game),
		--slider --TODO
		--keyboard --TODO
	}
	
	--------------------
	-- Game Functions --
	--------------------
	
	--// Called by engine when dialog starts
		--arg1 dialog (table): entry from dialogs.dat to display
		--arg2 info (string or table array of strings): strings to substitute for $v values
	function game:on_dialog_started(dialog, info)
		dialog.dlg_type = dialog.dlg_type or "conversation" --use conversation dialog by default
		
		local dlg_box = dialogs[dialog.dlg_type]
		assert(dlg_box, "Invalid dlg_type specified for dialog id: "..dialog.id)
		dlg_box:start_dialog(dialog, info)
		active_dialog = dialog.dlg_type
	end
	
	function game:on_dialog_finished(dialog)
		if dialogs[active_dialog].close then dialogs[active_dialog]:close() end
		active_dialog = nil
		
		if #queue_list>0 then table.remove(queue_list)() end
	end
	
	--//
		--arg1 func (function): function to be called after current dialog is closed
	function game:queue_dialog(func)
		if type(func)=="function" then table.insert(queue_list, func) end
	end
	
	function game:get_dialog_box(dlg_type)
		return dialogs[dlg_type]
	end
	
	function game:get_active_dialog_type()
		return active_dialog
	end
end

setmetatable(dlg_manager, {__call = dlg_manager.initialize}) --convenience

return dlg_manager


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
