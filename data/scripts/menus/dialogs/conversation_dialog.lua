--[[ conversation_dialog.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script creates a menu dialog for displaying conversation text with npcs that lets
	the player interact by typing in responses or by clicking on key words to continue the
	conversation.
	
	******** Keeping Track of the Terms *********
	Dialog Box: Menu containing the surfaces used to draw the dialog on screen
	Dialog Rules: Table of all dialog rules for which dialogs to show when under which conditions, for each NPC
	<Dialog Rules Entry>: Need better name!
	Dialog ID: unique identifier in dialogs.dat for the dialog
	Dialog Text: String containing raw text of the full dialog (from dialogs.dat)
	Dialog: dialogs.dat table entry with dialog text and other properties
	
	Topic Input: String of text entered by player (in native language) in dialog box that can be linked to a dialog id in strings.dat
	Topic ID: key from strings.dat associated with this topic. Used to identify keywords that an NPC will talk about
	Topic Name: Topic keyword as appears in dialog text (denoted by preceding with @ character)
]]

local dialog_box_manager = {}

local util = require"scripts/util.lua"
local ui_draw = require"scripts/lib/uix/ui_draw" --TODO why is this here?
local uix = require"scripts/lib/uix/ui_express"


function dialog_box_manager:initialize(game)
	local dialog_box = require"scripts/menus/menu"{
		--settings
		dialog = nil, --dialog being displayed
		info = nil, --parameter passed to start_dialog()
		dlg_state = nil, --string set during conversations to keep track of dialog progression
		dlg_state_val = nil, --number value for state to keep track of dialog progression
		
		--implementation
		text_index = nil, --which text area to use for the current paragraph
		text_index_prev = nil, --keep track of previous text index to revert (after a # comment)
		line_it = nil, --iterator over all lines of text
		next_line = nil, --(string) line of text read from line iterator but not yet processed
		topic_list = {}, --list of topics player has seen
		dlg_mode = nil, --what dialog is currently doing and what input is needed from player
			--possible values: "await_next", "await_prompt", "await_list", "prompt_only"
		func_cb = nil, --(function) executed once all dialogs in a set have been displayed
		
		--drawables
		menu_surface = nil, --intermediate surface to draw the dialog
		box_frame = nil, --image of the dialog box frame
		box_tint = nil, --dialog box semi-transparent fill with additive blend mode
		text_areas = {}, --TODO desc
		text_prompt = nil, --text box for player to enter text (not always visible)
		portraits = {false, false, false}, --array of surfaces to use containing each portrait
		name_surfaces = {false, false, false}, --array of text surfaces with character names
		log_buttons = {}, --TODO desc
	}
	
	local pos_x,pos_y = 0,0
	
	--constants
	local NUM_LINES = {4, 4, 4, 2}
	local MAX_TEXT_WIDTH = {380, 380, 380, 480}
	local TEXT_LINE_HEIGHT = 20
	local HORZ_ALIGNMENT = {"left", "left", "left", "center"}
	local BOX_SIZE = {x=550, y=330}
	local PORTRAIT_SIZE = {x=64, y=64}
	local PORTRAIT_OFFSETS = {{x=34, y=16}, {x=34, y=104}, {x=34, y=192}} --x/y locations to place sprite surfaces
	local TEXT_OFFSETS = {{x=118, y=16}, {x=118, y=104}, {x=118, y=192}, {x=18, y=280}} --x/y locations to place text surfaces
	local NAME_OFFSETS = {{x=66, y=82}, {x=66, y=170}, {x=66, y=258}} --x/y locations to place text surfaces
	local LOG_BUTTON_OFFSETS = {{x=506, y=16}, {x=506, y=192}, {x=506, y=192}, {x=506, y=280}}
	local MAX_NAME_SIZE = 96 --width of surfaces to display character name under portrait
	local dialog_bg_fill = {0, 0, 191, 127} --50% blue fill
	
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
	
	for i,num_lines in ipairs(NUM_LINES) do
		local is_hyperlinks = i~=3
		dialog_box.text_areas[i] = uix.multiline{
			style = "bodytext",
			num_lines = num_lines,
			width = MAX_TEXT_WIDTH[i],
			height = num_lines*TEXT_LINE_HEIGHT,
			text_height = TEXT_LINE_HEIGHT,
			horizontal_alignment = HORZ_ALIGNMENT[i],
			is_hyperlinks = is_hyperlinks,
		}
		
		dialog_box.log_buttons[i] = uix.button{
			style = "logbutton",
			is_visible = false,
			on_clicked = function()
				sol.audio.play_sound"write_log"
				
				local npc = game.conv.npc
				local npc_name = npc and npc:get_display_name() or "???"
				
				local raw_text = dialog_box:get_text(i) or ""
				raw_text = raw_text:gsub("\n", " ") --remove newline characters
				
				game.journal:new_entry(npc_name.." said:\n"..raw_text.."\n")
				
				return true
			end,
		}
		
		if i<#NUM_LINES then --last text area does not have a portrait or name label
			dialog_box.portraits[i] = uix.image_view{
				width = PORTRAIT_SIZE.x,
				height = PORTRAIT_SIZE.y,
			}
			
			dialog_box.name_surfaces[i] = uix.text_label{
				style = "namelabel",
				width = MAX_NAME_SIZE,
				height = TEXT_LINE_HEIGHT+1, --add 1 for shadow
			}
		end
	end
	dialog_box.text_areas[3].on_hyperlink = function(self, topic_name) --clicking a link in text area for player
		if dialog_box.dlg_mode=="await_list" then
			local list = dialog_box.list
			local index = (dialog_box.list_items or {})[topic_name]
			
			dialog_box:clear()
			
			local dialog_id = game.conv:list_select(list, index)
			dialog_box:next_dialog(dialog_id)
		else dialog_box:new_topic(topic_name) end
	end
	dialog_box.text_prompt = uix.text_prompt{
		style = "simpleprompt",
		width = MAX_TEXT_WIDTH[3],
		height = TEXT_LINE_HEIGHT + 4,
	}
	function dialog_box.text_prompt:on_enter(text) dialog_box:new_topic(text) end
	
	dialog_box.portraits[3]:set_surface(ui_draw.load_frame"npc/portraits/player.png") --portrait for player
	
	
	----------------------
	-- Build Dialog Box --
	----------------------
	
	dialog_box:add_control(dialog_box.box_tint, 0, 0)
	dialog_box:add_control(dialog_box.box_frame, 0, 0)
	for i=1,#NUM_LINES-1 do
		dialog_box:add_control(dialog_box.portraits[i], PORTRAIT_OFFSETS[i].x, PORTRAIT_OFFSETS[i].y)
		dialog_box:add_control(dialog_box.name_surfaces[i], NAME_OFFSETS[i].x, NAME_OFFSETS[i].y)
	end
	for i=1,#NUM_LINES do
		dialog_box:add_control(dialog_box.log_buttons[i], LOG_BUTTON_OFFSETS[i].x, LOG_BUTTON_OFFSETS[i].y)
		dialog_box:add_control(dialog_box.text_areas[i], TEXT_OFFSETS[i].x, TEXT_OFFSETS[i].y)
	end
	dialog_box:add_control(dialog_box.text_prompt, TEXT_OFFSETS[3].x, TEXT_OFFSETS[3].y + 2)
	
	
	-----------------------
	-- Dialog Box Events --
	-----------------------
	
	--// First dialog of a sequence begins; called by sol.menu.start()
	function dialog_box:on_started()
		self:set_position() --center on screen
		
		self:show_dialog()
	end
	
	
	--// dialog box is closed; called by sol.main.stop()
	function dialog_box:on_finished()
		self:clear()
		
		sol.audio.play_sound"dialog_close"
		
		--TODO clear sub controls (display blank text rather than clearing surface)
	end
	
	
	--------------------------
	-- Dialog Box Interface --
	--------------------------
	
	--// Called when dialog starts
		--arg1 dialog (table): entry from dialogs.dat to display
		--arg2 info (string or table array of strings): strings to substitute for $v values
	function dialog_box:start_dialog(dialog, info)
		self.dialog = dialog
		self.info = type(info)=="string" and {info} or info --if info is string then convert to table containing the string
		
		local npc = game.conv.npc
		if npc then self.portraits[1]:set_surface(ui_draw.load_frame(npc:get_portrait())) end --load NPC portrait
		
		self:redraw_names()
		
		sol.menu.start(game, self)
	end
	
	
	--// Returns the current state (string) for the dialog box and associated value (number). 
	--// Useful for keeping track of dialog progress or determining which set of dialogs to enable next.
		--ret1 state (string): The current state. Allowable characters are alphanumeric and underscore.
		--ret2 state_val (number): The current state value. Any number or nil if not set.
	function dialog_box:get_state() return self.dlg_state, self.dlg_state_val end
	
	
	--// See 'get_state'; setting the state replaces the old state; set to false/nil for none
		--arg1 state (string): The new state to set; allowable characters are alphanumeric and underscore
	function dialog_box:set_state(state)
		assert(not state or type(state)=="string", "Bad argument #1 to 'set_state' (string or nil expected, got "..type(state)..")")
		self.dlg_state = state or nil --don't set to false
		
		--TODO disallow all characters except non-alphanumeric or underscore
	end
	
	
	--// See 'get_state'; setting the state value replaces the old value
		--arg1 state_val (number): The new state value to set; can be any number or false/nil to clear
	function dialog_box:set_state_val(val)
		local num = tonumber(val)
		assert(not val or num, "Bad argument #1 to 'set_state_val' (number or nil expected, got "..type(val)..")")
		self.dlg_state_val = num or nil --don't set to false
	end
	
	
	--// The mode of the dialog box determines how key presses and mouse actions will be handled
		--ret1 (string): The current mode; possible values are:
			--"await_next"	any key or mouse click advances dialog
			--"await_prompt"	player must enter text or click topic to advance dialog
			--"prompt_only"	same as "await_prompt" except clickable topics are hidden
			--"await_list"	player must select an entry from a list to advance dialog
	function dialog_box:get_mode() return mode end
		--arg1 mode (string): see above for possible values
	function dialog_box:set_mode(mode)
		assert(not mode or type(mode)=="string", "Bad argument #1 to 'set_mode' (string or nil expected, got "..type(mode)..")")
		self.dlg_mode = mode --TODO validate mode
		
		--Enable/Disable flashing prompt cursor depending on new mode
		if mode=="await_prompt" or mode=="prompt_only" then --if prompt is shown then animate cursor
			--TODO set visibility of prompt
		end
	end
	
	
	function dialog_box:get_bounding_box()
		local width,height = self.box_frame:get_size()
		return pos_x, pos_y, width, height
	end
	
	
	function dialog_box:get_position() return pos_x,pos_y end
	function dialog_box:set_position(x, y)
		x = tonumber(x)
		x = x and math.floor(x)
		y = tonumber(y)
		y = y and math.floor(y)
		
		if not x or not y then --place at center of screen if x or y not specified
			local quest_width, quest_height = sol.video.get_quest_size()
			local box_width,box_height = self.box_frame:get_size() --TODO use width/height instead
			
			x = (quest_width - box_width)/2
			y = (quest_height - box_height)/2
		end
		
		pos_x,pos_y = x, y
	end
	
	
	function dialog_box:close()
		if sol.menu.is_started(self) then
			sol.menu.stop(self)
		end
		
		self.dialog = nil
		self.info = nil
		self.dlg_state = nil
		self.dlg_state_val = nil
	end
	
	
	-------------------------------
	-- Dialog Box Implementation --
	-------------------------------
	
	--// Shows new dialog box
	function dialog_box:show_dialog()
		sol.audio.play_sound"dialog_open"
		
		--set-up first time topic list
		self.topic_list = {
			"topic.LIST.bye",
			"topic.LIST.where",
			"topic.LIST.job",
			"topic.LIST.name",
		}
		
		--convert string_ids to strngs.dat string and add lookup entries for each topic
		for i,string_id in ipairs(self.topic_list) do
			local topic_name = sol.language.get_string(string_id)
			self.topic_list[i] = topic_name
			self.topic_list[topic_name] = true --to check if topic is in list
		end
		
		--TODO only show valid topics in list
		
		self:next_dialog()
	end
	
	--// Gets and returns next line of text for dialog; lines containing only whitespace become empty
	function dialog_box:read_line()
		local line = self.line_it() --read next line
		
		if line and line:match"%S+" then --contains at least one non-whitespace character
			return line
		else return line and "" or nil end --line containing only whitespace becomes empty
	end
	
	--// Gets enough text to fill box (stops at empty line) and displays it, clearing existing text in that area only
	--// When end of dialog reached, displays prompt for player to enter text for next dialog
	function dialog_box:next_paragraph()
		--if next dialog previously designated by on_done function then use that instead
		local next_dlg = self.next_dlg
		if next_dlg then
			self:clear()
			
			local dialog_id = game.conv:resume_dlg(next_dlg)
			self:next_dialog(dialog_id)
			
			return
		end
		
		local next_line = self.next_line or self:read_line() --get next line to process
		while next_line=="" do next_line = self:read_line() end --keep getting next until non-empty
		if not next_line then return end --TODO need to set mode?
		
		--// Stuff specific to first line of paragraph
		
		--check for special character indicating which text area to use
		local is_index, text_index
		local is_comment,text = next_line:match"^(#)(.*)" --begins with #
		if is_comment=="#" then
			is_index = true
			self.text_index_prev = text_index or 1 --text index to use for next non-comment
			self.text_index = #NUM_LINES --use last line for comment text
			next_line = text
		else --begins with $1 $2 $3, etc.
			is_index, text_index, next_line = next_line:match"^(%$?)(%d?)(.*)"
			is_index = is_index=="$"
			text_index = tonumber(text_index) --convert from string
			
			if is_index and text_index and text_index>=1 and text_index<=#NUM_LINES then
				self.text_index_prev = nil
			else text_index = self.text_index_prev or 1 end
			
			self.text_index = text_index
		end
		
		text_index = self.text_index --convenience
		local text_area = self.text_areas[text_index] --convenience
		
		--clear text from previous paragraph
		text_area:clear()
		
		--// Stuff common to all lines of paragraph (including first)
		
		--continue getting all lines for this paragraph
		local overflow
		local line_max = NUM_LINES[text_index] --maximum number of lines that can be shown before pause
		while next_line and next_line~="" and not text_area:is_full() do
			overflow = text_area:add_line(next_line)
			self.log_buttons[text_index]:set_visible(true)
			
			if overflow then
				next_line = overflow
				break
			else next_line = self:read_line() end
		end
		
		--// end of paragraph reached (or at maximum number of lines)
		
		--update hyperlinks
		local new_hyperlinks = text_area:get_hyperlinks()
		for _,hyperlink in ipairs(new_hyperlinks) do
			if not self.topic_list[hyperlink] then
				self.topic_list[hyperlink] = true
				table.insert(self.topic_list, hyperlink)
			end
		end
		
		while next_line=="" do next_line = self:read_line() end --keep getting next until non-empty (need to confirm there actually are more non-blank lines ahead)
		
		self.next_line = next_line --save for next pass (if overflow) or reset to nil (if dialog done)
		if next_line then --still more lines to process later
			--now wait for user input to advance to next paragraph
			self:set_mode"await_next"
			self.text_prompt:set_visible(false)
		else --no more lines; show text prompt for player
			self:set_mode"await_prompt" --default mode
			
			if type(self.func_cb)=="function" then self.func_cb() end --may change dialog mode
			
			--if player learned npc's name then draw new name in dialog
			if self.actions.refresh_name then
				self:redraw_names()
			end
			
			
			
			if self.next_dlg then
				self:set_mode"await_next"
				self.text_prompt:set_visible(false)
			elseif self.dlg_mode=="await_prompt" or self.dlg_mode=="prompt_only" then
				text_index = 3 --contents of text area 3 to be replaced with topic list
				self.text_index = text_index
				
				--clear any text from previous paragraphs
				local text_area = self.text_areas[text_index] --convenience
				text_area:clear()
				self.log_buttons[text_index]:set_visible(false)
				
				--add topic list to text area #3
				local is_success
				if self.dlg_mode~="prompt_only" then --topics not shown if mode is prompt_only
					for i=#self.topic_list,1,-1 do --backwards thru list
						is_success = self:add_topic(self.topic_list[i]) --attempt to add topic
				
						if not is_success then break end --stop if topic doesn't fit
					end
				
					if not is_success then text_area:clear_line(NUM_LINES[text_index]) end --remove any topics added to last line
				end
				
				--determine which line to show text prompt and make it visible
				local num_lines_used = text_area:get_line_index()
				local y_offset = self.dlg_mode~="prompt_only" and num_lines_used*TEXT_LINE_HEIGHT or 0
				self.text_prompt:set_xy(0, y_offset)
				self.text_prompt:set_visible(true)
			elseif self.dlg_mode=="await_list" and self.list then --display list for player to choose from
				text_index = 3 --contents of text area 3 to be replaced with list
				self.text_index = text_index
				
				--clear any text from previous paragraphs
				local text_area = self.text_areas[text_index] --convenience
				text_area:clear()
				self.log_buttons[text_index]:set_visible(false)
				
				--add list to text area #3
				self.list_items = {} --topic name as key, list index as value
				for i,item in ipairs(self.list) do
					local item_name = item.label and sol.language.get_string(item.label) or "???"
					self.list_items[item_name] = i
					
					local hotkey = sol.language.get_string(item.label..".hotkey")
					if hotkey and not self.list_items[hotkey] then self.list_items[hotkey] = i end
					
					self:add_topic(item_name, "\n")
					
					line_index = new_index
				end
				
				self.text_prompt:set_visible(false)
			else self.text_prompt:set_visible(false) end
		end
		
		text_area:refresh() --force text area to be redrawn now; won't change again until input from player received
	end
	
	
	--// Appends topic text to current text area in order to create topic list; starts new line if necessary
	function dialog_box:add_topic(topic, suffix)
		assert(type(topic)=="string", "Bad argument #1 to 'add_topic' (string expected, got "..type(topic)..")")
		
		--make first letter upper-case
		local topic_chars = util.get_chars(topic)
		if topic_chars[1] then topic_chars[1] = topic_chars[1]:upper() end
		topic = table.concat(topic_chars, "")
		
		--topic = "- "..topic --this text is a clickable hyperlink
		local trailing_space = suffix or "  " --this text is not a hyperlink
		
		local is_fit = self.text_areas[self.text_index]:add_word(topic, true, "- ")
		local current_line = self.text_areas[self.text_index]:add_word(trailing_space, false)
		
		return is_fit and current_line and current_line < NUM_LINES[self.text_index] --don't want any links on last line
	end
	
	--// Starts new set of dialog based on user input (string, localized)
	function dialog_box:new_topic(input)
		self:clear()
		
		--find id of dialog to show
		local npc = game.conv.npc
		local dialog_id, input_sub = game.conv:get_topic_response(npc, input)
		
		if npc then self.portraits[1]:set_surface(ui_draw.load_frame(npc:get_portrait())) end
		
		--remove topic from list that corresponds to input
		local is_topic_found = false
		local sub_length = input_sub and input_sub:len() or 0
		if sub_length>0 then
			local topic_sub
			for i,topic in ipairs(self.topic_list) do
				topic_sub = topic:sub(1,sub_length):lower()
				if topic_sub==input_sub then
					is_topic_found = true
					self.topic_list[topic]=false
					table.remove(self.topic_list, i) --okay to remove in for loop since only removing one entry then breaking
					break
				end
			end
		end
		
		self:next_dialog(dialog_id)
	end
	
	
	function dialog_box:clear()
		--clear all text areas
		for _,text_area in ipairs(self.text_areas) do
			text_area:clear()
		end
		for _,log_button in ipairs(self.log_buttons) do
			log_button:set_visible(false)
		end
		
		self.actions = {}
		self.func_cb = nil
		self.substitutions = nil
		self.list = nil
		self.list_items = nil
		self.next_dlg = nil
	end
	
	function dialog_box:next_dialog(dialog_id)
		if dialog_id then self.dialog = sol.language.get_dialog(dialog_id) end
		
		local dialog = self.dialog
		local text = dialog.text
		local info = self.info or {}
		
		--make any "$s" substitutions (substitute strings.dat string depending on game conditions)
		local substitutions = self.substitutions
		if type(substitutions)=="table" then		
			for i,new_text in ipairs(substitutions) do
				assert(type(new_text)=="string", "Invalid $s substitution #"..i.." in dialog id: "..tostring(self.dialog))
				text = text:gsub("%$s", new_text, 1) --make substitution number i
			end
		end
		
		--make any "$v" substitutions (values to substitute provided by info table)
		local values = self.values
		if type(values)=="table" then
			for i,new_text in ipairs(values) do
				if new_text then
					text = text:gsub("%$v", new_text, i<#values and 1 or nil) --use last entry in info for all remaining instances of "$v"
				end
			end
		end
		
		--split the text into lines
		text = text:gsub("\r\n", "\n"):gsub("\r", "\n") --convert carriage return character(s) to new line character(s)
		self.line_it = text:gmatch("([^\n]*)\n") --each line including empty ones
		
		self.text_index = 1 --default in case not specified
		
		self:next_paragraph()
	end
	
	
	--------------------
	-- Draw Functions --
	--------------------
	
	--multiply this value by the width of the text field to get horizontal origin for drawing text depending on horz alignment
	local alignment_offsets = {
		left = 0,
		center = 0.5,
		right = 1,
	}
	
	
	--// redraws surface containing names of characters in dialog box
	function dialog_box:redraw_names()
		local text_surface = self.line_text_surface --convenience
		local center_offset
		
		--redraw name of NPC player is interacting with
		local npc = game.conv.npc
		if npc then
			local npc_name = npc:get_display_name()
			self.name_surfaces[1]:set_text(npc_name)
		end
		
		--TODO redraw for area #2 too, if applicable
		
		--redraw player name
		self.name_surfaces[3]:set_text(game:get_value"player_name" or sol.language.get_string"player.default_name")
	end
	
	
	--// Returns a string of the raw text (@ characters for topics included) currently displayed in text area text_index
	--// The returned string can contain up to NUM_LINES[text_index] lines of text
	function dialog_box:get_text(text_index)
		local num = tonumber(text_index)
		assert(num or not text_index, "Bad argument #1 to 'get_text' (Number expected, got "..type(text_index)..")")
		
		text_index = math.floor(num or self.text_index)
		assert(text_index >= 1 and text_index <= #NUM_LINES, "Bad argument #1 to 'text_index' (Number out of range)")
		
		return self.text_areas[text_index]:get_text()
		--[[local text = {}
		
		--duplicate contents of raw_text
		for _,line in ipairs(raw_text or {}) do
			table.insert(text, line)
		end
		
		--remove empty lines at end
		for i=#raw_text,1,-1 do --iterate backwards
			if text[i]:match"^%s*$" then --empty line or only contains space characters
				table.remove(text, i)
			else break end --non-empty string; don't check lines above
		end
		
		return table.concat(text, '\n') --combine lines into single string]] --OBSOLETE
	end
	
	
	----------------------
	-- Input Processing --
	----------------------
	
	local menu_on_character_pressed = dialog_box.on_character_pressed --function inherited from menu
	function dialog_box:on_character_pressed(character)
		if self.dlg_mode=="await_list" then
			local list = self.list
			local index = self.list_items and self.list_items[character]
			
			if list and index then
				self:clear()
			
				local dialog_id = game.conv:list_select(list, index)
				self:next_dialog(dialog_id)
				
				return true
			end
		end
		
		return menu_on_character_pressed and menu_on_character_pressed(self, character)
	end
	
	local menu_on_key_pressed = dialog_box.on_key_pressed --function inherited from menu
	function dialog_box:on_key_pressed(key, modifiers)
		local num = tonumber(key)
		
		if self.dlg_mode=="await_next" then --any key to advance dialog
			sol.timer.start(self, 2, function() self:next_paragraph() end) --breif delay so state doesn't change until after on_character_pressed()
			return true
		elseif self.dlg_mode=="end_dlg" then
			game:stop_dialog()
			return true
		elseif self.dlg_mode=="await_prompt" or self.dlg_mode=="prompt_only" then --player must enter text phrase to advance
			if key=="page up" then
				--TODO forward topic
				return true
			elseif key=="page down" then
				--TODO back topic
				return true
			elseif key=="tab" then
				--TODO autocomplete
				return true
			elseif num then
				if modifiers.control then --save text to log
					if num <= #NUM_LINES then
						if num==0 then num = #NUM_LINES end
					
						--TODO
						return true
					end --else ignore
				elseif modifiers.alt then --populate text for topic n
					if num==0 then num = 10 end
				
					--TODO
					return true
				end
			end
		end
		
		return menu_on_key_pressed and menu_on_key_pressed(self, key, modifiers)
	end
	
	local menu_on_mouse_released = dialog_box.on_mouse_released --function inherited from menu
	function dialog_box:on_mouse_released(button, x, y)
		if menu_on_mouse_released and menu_on_mouse_released(self, button, x, y) then return true end
		
		local box_x, box_y, box_width, box_height = self:get_bounding_box()
		local text_bounds = {{}, {}, {}, {}}
		
		if button=="left" then
			if x>=box_x and x<=box_x + box_width and y>=box_y and y<=box_y + box_height then --clicked inside dialog box
				if self.dlg_mode=="await_next" then --clicking anywhere inside dialog box advances
					self:next_paragraph()
					return true
				elseif self.dlg_mode=="await_list" then
					--TODO
				elseif self.dlg_mode=="end_dlg" then
					game:stop_dialog()
				end
			end
		end
		
		--if menu_on_mouse_released then menu_on_mouse_released(self, button, x, y) end --TODO this line is in error?
	end
	
	return dialog_box
end

return dialog_box_manager


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
