--[[ conversation_manager.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script takes text input from the player (in their native language) converts it to
	a topic_id (non-localized) using strings.dat, and then it finds the dialog that should
	be displayed depending on the NPC the player is interacting with, the current map, and
	the current state of the game (such as save game values).
	
	It also manages the actions that are performed after viewing a dialog (such as setting
	save game values and determining the follow-up dialog to be displayed after that). See
	topic_rules.dat for more info.
]]

local conversation_manager = {}

local util = require"scripts/util"

local MIN_WORD_LENGTH = 2 --TODO let these be defined by translation
local MAX_WORD_LENGTH = 5

function conversation_manager:initialize(game)
	local game_type = sol.main.get_type(game)
	assert(game_type=="game", "Bad argument #1 to 'initialize' (sol.game expected, got "..game_type..")")
	
	local conv = {}
	topic_rules = require"scripts/topic_rules":initialize(game)
	local dlg_box = game:get_dialog_box"conversation"
	
	
	--// Returns topic_id that matches input text (native language) entered by player
	--// The topic_id returned corresponds to an entry in the topic_rules table for the NPC
		--arg1 input (string): Text entered by player in native language
		--ret1 (string): Returns the topic_id with key that best matches the input text from player
			--return of "GREETING" is used if no input specified (initial interaction)
			--return of "UNKNOWN" is used if no matching topic found
		--ret2 (string): Substring of player input text that matches topic (player can enter more characters than necessary, which get ignored)
	local function get_topic(input)
		if not input then return "GREETING" end --default if topic not specified (initial interaction)
		input = input:match"^%s*(%S*)%s*":lower() --strip out leading and trailing whitespace and convert to lower case
		
		local npc_name = conv.npc and conv.npc:get_name()
		if not npc_name then return "UNKNOWN" end
		
		local input_char_count = util.char_count(input)
		if input_char_count<MIN_WORD_LENGTH then return "UNKNOWN" end --invalid topic, use unknown response
		
		local dlg_state, dlg_state_val = dlg_box:get_state()
		
		--determine which rules table to use for this npc
		local npc_rules = topic_rules[npc_name] or {}
		if type(npc_rules.RULES_SELECT)=="function" then --check if alternate topic table should be used
			local key = npc_rules.RULES_SELECT(dlg_state, dlg_state_val) or npc_name --alternate key for topic_rules table
			npc_rules = topic_rules[key] or npc_rules --if key invalid then use original table
		end
		
		--if extra list is specified as a string, convert it to an array with one entry
		local extra_list = npc_rules.EXTRA or {}
		if type(extra_list)=="string" then
			extra_list = {extra_list}
		end
		
		--create array of all available rules lists
		local rules_list = {}
		for _,key in ipairs(extra_list) do
			if topic_rules[key] then table.insert(rules_list, topic_rules[key]) end
		end
		table.insert(rules_list, npc_rules) --add primary rules last so they override any duplicates from extra rules (processed in order)
		
		--create list of all possible topics this npc knows about
		local valid_topic_ids = {}
		local topic_input --string (native language) that the beginning of text input from player must match for a given topic
		for _,rules in ipairs(rules_list) do
			for topic_id,rule in pairs(rules) do
				topic_input = sol.language.get_string("topic."..npc_name.."."..topic_id) --lookup topic substring from primary rules			
			
				if not topic_input then topic_input = sol.language.get_string("topic.COMMON."..topic_id) end --lookup from common rules
			
				if not topic_input then --lookup from extra rules
					for _,key in ipairs(extra_list) do
						topic_input = sol.language.get_string("topic."..key.."."..topic_id)
						if topic_input then break end
					end
				end
			
				if topic_input then valid_topic_ids[topic_input] = topic_id end --save topic_id if rule found
			end
		end

		--determine which of the valid topic_ids best matches the text entered by player
		local topic_id --rules table key to select dialog from (return #1)
		local input_sub --substring of player input text (return #2)
		local n_bytes --number of bytes in substring
		for n_chars = math.min(input_char_count,MAX_WORD_LENGTH), MIN_WORD_LENGTH, -1 do --check first 5 chars, then first 4, etc.
			_,n_bytes = util.char_count(input, n_chars) --count number of bytes in first n chars (multibyte)
			input_sub = input:sub(1, n_bytes) --substring of player input text containing first n chars (multibyte)
			
			--get topic id from input substring
			topic_id = valid_topic_ids[input_sub]
			if topic_id then return topic_id, input_sub end
		end
		
		--use max length for input_sub
		_,n_bytes = util.char_count(input, MAX_WORD_LENGTH) 
		input_sub = input:sub(1, n_bytes)
		
		return "UNKNOWN", input_sub --no matching topic found; NPC will give UNKNOWN response
	end
	
	
	--// Returns true if all conditions are met for this dialog to be shown
	local function validate_dialog(properties)
		assert(type(properties)=="table", "Bad argument #1 to 'validate_dialog' (table expected)")
		
		local dlg_item = properties.dlg_item
		if not type(dlg_item)=="table" then return false end

		--check if specified current map conditions met
		if dlg_item.map_id and dlg_item.map_id ~= properties.map_id then
			return false
		end

		--check if specified save game value condition is met
		if not game.expression_check(dlg_item.save_val, "save_val") then return false end
		
		--check if specified state conditions for this dialog met
		--TODO use generic expression function; add support for & and | expressions
		local state_expr = dlg_item.state
		if type(state_expr)=="string" then
			local is_not, state_str = state_expr:match"^(!?)(.+)" --! at front indicates not that state
			is_not = is_not=="!"
	
			if (properties.state==state_str and is_not) or not (properties.state==state_str or is_not) then --XOR
				return false
			end
		elseif type(state_expr)=="function" then
			if not state_expr(properties.state) then return false end
		end --otherwise invalid state expression: ignore (i.e. condition met)

		--check if specified state value conditions for this dialog met
		--TODO use generic expression function
		local state_val_expr = dlg_item.state_val
		if type(state_val_expr)=="string" then
			local compare, state_val = state_val_expr:match"^([!<>=]*)(%d+)$" --! at front indicates not that state
			
			state_val = tonumber(state_val)
	
			if state_val then --if not a valid number then ignore (i.e. condition valid)
				local dlg_val = tonumber(properties.state_val)
				
				if not dlg_val then
					if compare~="!" then return false end
				else
					--possible values for compare; all other comparator strings ignored (i.e. condition met)
					local not_equal = compare=="!" or compare=="<" or compare==">" --fail if compare is one of these and state values are equal
					local not_less = compare=="" or compare==">" or compare==">=" --fail if compare is one of these and state value is less
					local not_more = compare=="" or compare=="<" or compare=="<=" --fail if compare is one of these and state value is greater
					
					if not_equal and dlg_val==state_val then
						return false
					elseif not_less and dlg_val<state_val then
						return false
					elseif not_more and dlg_val>state_val then
						return false
					end
				end
			end
		elseif type(state_val_expr)=="function" then
			if not state_val_expr(properties.state_val) then return false end
		end --otherwise invalid state val expression: ignore (i.e. condition met)

		--check if specified conditions for this NPC met
		--TODO use generic expression function; add support for & and | expressions
		local npc_expr = dlg_item.npc_val
		if type(npc_expr)=="string" then
			local is_not, npc_val_str = npc_expr:match"^(!?)(.+)" --! at front indicates not that state
			is_not = is_not=="!"
	
			local npc_val = conv.npc and conv.npc[npc_val_str]
	
			if (npc_val==npc_val_str and is_not) or not (npc_val==npc_val_str or is_not) then --XOR
				return false
			end
		elseif type(npc_expr)=="function" then
			if not npc_expr(conv.npc) then return false end
		end --otherwise invalid expression: ignore (i.e. condition met)
		
		return true
	end
	
	
	--// given valid topic_id (string, non-localized), determines and returns the dialog rules table to be displayed
	--// use conv:get_topic_response() if you need to get the next dialog from the localized player input text
	local function get_dialog_from_topic(topic_id)
		if not topic_id or topic_id=="" then topic_id = "GREETING" end
		
		local npc_name = conv.npc and conv.npc:get_name()
		if not npc_name then return false end
		
		local npc_rules = topic_rules[npc_name] or {}
		
		--locals needed to determine if dialog conditions met
		local map_id = game:is_started() and game:get_map():get_id()
		local dlg_state, dlg_state_val = dlg_box:get_state()

		--check if alternate topic table should be used
		if type(npc_rules.RULES_SELECT)=="function" then
			local key = npc_rules.RULES_SELECT(dlg_state, dlg_state_val) or npc_name --alternate key for topic_rules table
			npc_rules = topic_rules[key] or npc_rules --if key invalid then use original table
		end
		
		--if extra list is specified as a string, convert it to an array with one entry
		local extra_list = npc_rules.EXTRA or {}
		if type(extra_list)=="string" then
			extra_list = {extra_list}
		end
		
		--create array of all available rules lists
		local rules_list = {npc_rules} --search primary rules first
		for _,key in ipairs(extra_list) do
			if topic_rules[key] then table.insert(rules_list, topic_rules[key]) end
		end
		
		--Check each rules list in order for dialog with valid conditions
		for i,rules in ipairs(rules_list) do
			--check rules to see if any meet all conditions
			local primary_dialogs = rules[topic_id]
			

			--reformat all available dialogs (may or may not be eligible) into single array list
			local available_dialogs = {}
			if type(primary_dialogs)=="string" then primary_dialogs = {dlg=primary_dialogs} end
			if type(primary_dialogs)=="table" then --may be single dialog with conditions or multiple dialogs
				if #primary_dialogs>0 then --primary_dialogs is an array
					--if there's a select() function, use it to determine which dialog to display
					local index
					if type(primary_dialogs.select)=="function" then
						index = tonumber(primary_dialogs.select(dlg_state, dlg_state_val))
					end
					
					if index then primary_dialogs = {primary_dialogs[index]} end --reduce to single entry
					
					for _,item in ipairs(primary_dialogs) do
						if type(item)=="string" then
							table.insert(available_dialogs, {dlg=item})
						elseif type(item)=="table" then --item is table with conditions for dialog
							table.insert(available_dialogs, item)
						end --otherwise item is not a valid entry: ignore it
					end
				else table.insert(available_dialogs, primary_dialogs) end --primary_dialogs is key/value table with conditions for dialog
			end

			local weights = {} --keep list of specified weights to calculate averate
			local needs_weight = {} --list of dialogs without weight specified

			--make list of dialogs with conditions that are met
			local eligible_dialogs = {}
			for _,dlg_item in ipairs(available_dialogs) do
				local conditions_met = validate_dialog{
					dlg_item = dlg_item,
					map_id = map_id,
					state = dlg_state,
					state_val = dlg_state_val,
				}
	
				if conditions_met then --dialog is eligible
					table.insert(eligible_dialogs, dlg_item)
					
					local weight = tonumber(dlg_item.weight)
					if weight then
						weight = math.abs(weight) --don't allow negative weight values
						dlg_item.weight = weight --force to be valid format
						table.insert(weights, weight)
					else table.insert(needs_weight, dlg_item) end --set to avg weight later once calculated
				end
			end

			--calculate average weight
			local avg_weight = 0
			local total_weight
			if #weights>0 then
				total_weight = 0
				
				--calculate avg weight
				for _,weight in ipairs(weights) do
					avg_weight = avg_weight + weight
				end
				avg_weight = avg_weight / #weights
	
				--assign average weight to dialog items that don't specify a weight
				for _,dlg_item in ipairs(needs_weight) do
					dlg_item.weight = avg_weight
				end
	
				weights = {} --clear table; now fill it with cumulative sums
				for i,dlg_item in ipairs(eligible_dialogs) do
					total_weight = total_weight + dlg_item.weight
					table.insert(weights, total_weight)
				end
			end

			--randomly select dialog to use from eligible dialogs
			if #eligible_dialogs>0 then
				if #eligible_dialogs==1 then --only one choice; return it
					return eligible_dialogs[1]
				elseif total_weight then --use weighted random selection
					local val = total_weight * util.random()
					for i,weight in ipairs(weights) do
						if val<weight then return eligible_dialogs[i] end
					end
		
					return eligible_dialogs[#eligible_dialogs] --shouldn't ever happen?
				else --use equally distributed random selection
					local index = math.floor(#eligible_dialogs * util.random())
					return eligible_dialogs[index]
				end
			end
		end
		
		return false
	end

	
	--// Returns a function to perform all actions actions required once the end of the current dialog is reached.
	--// Function to be called after dialog completion.
		--arg1 dlg_rules (table): list of parameters for the current dialog
		--ret1 (function): Function to call at end current dialog.
	local function get_dialog_actions(dlg_rules)
		if not dlg_rules then return false end --no actions to perform
		assert(type(dlg_rules)=="table", "Bad argument #1 to 'get_dialog_actions' (table or nil expected, got "..type(dlg_rules)..")")
		
		local set_save_val = dlg_rules.set_save_val
		assert(not set_save_val or type(set_save_val)=="string", "Bad argument #1 to 'get_dialog_actions' (table entry for 'set_save_val' must be a string or nil)")
		
		--[[
		if set_save_val then
			--parse expression for set_save_val
			local is_not,id,equals,val = set_save_val:match"^(!?)(.-)(=?)(.*)$"
			is_not = is_not=="!"
			equals = equals=="="
			if not val or val=="" then val = nil end
			if not id or id=="" then
				if not equals then
					id = val
				else id = nil end
			end
			local num
			if equals then num = tonumber(val) end
			
			--convert set_save_val to table containing savegame_variable and value for game:set_value() or nil if unused
			if id then
				if is_not and not equals then --set to false
					set_save_val = {id,false}
				elseif not is_not and equals and val then
					set_save_val = {id, num or val}
				elseif not is_not and not equals then
					set_save_val = {id, true}
				end
			else set_save_val = nil end
		end]]
		
		local set_state = dlg_rules.set_state
		assert(not set_state or type(set_state)=="string", "Bad argument #1 to 'get_dialog_actions' (table entry for 'set_state' must be a string or false or nil)")
		
		local set_state_val = dlg_rules.set_state_val
		set_state_val = tonumber(set_state_val) or set_state_val --can be number, false or nil
		
		local play_sound = dlg_rules.play_sound
		assert(not play_sound or type(play_sound)=="string", "Bad argument #1 to 'get_dialog_actions' (table entry for 'play_sound' must be a string or false or nil)")
		
		local remove_money = dlg_rules.remove_money
		if remove_money then
			local num = tonumber(remove_money)
			
			if not num then
				if type(remove_money)=="string" then
					local index = tonumber(remove_money:match"^$v(%d+)")
					num = tonumber((dlg_box.values or {})[index])
				elseif type(remove_money)=="function" then
					num = tonumber(remove_money())
				end
			end
			
			remove_money = num
		end
		
		local add_money = dlg_rules.add_money
		if dlg_rules.add_money then
			local num = tonumber(add_money)
			
			if not num then
				if type(add_money)=="string" then
					local index = tonumber(add_money:match"^$v(%d+)")
					num = tonumber((dlg_box.values or {})[index])
				elseif type(add_money)=="function" then
					num = tonumber(add_money())
				end
			end
			
			add_money = num
		end
		
		local give_item = dlg_rules.give_item
		if type(give_item)=="string" then
			give_item = {give_item}
		elseif type(give_item)=="table" then
			give_item[2] = tonumber(give_item[2])
			if type(give_item[1])~="string" then give_item = nil end
		else give_item = nil end --ignore invalid value
		
		local dlg_mode = dlg_rules.dlg_mode
		assert(not dlg_mode or type(dlg_mode)=="string", "Bad argument #1 to 'get_dialog_actions' (string or nil expected, got "..type(dlg_mode)..")")
		
		local on_done = dlg_rules.on_done
		assert(
			not on_done or type(on_done)=="table" or type(on_done)=="function",
			"Bad argument #1 to 'get_dialog_actions' (table entry 'on_done' must be a string, table, function or nil)"
		)
		
		--arguments to pass to on_done function
		local args = {
			dialog_id = dlg_rules.dlg,
			npc = game.conv.npc,
			map = game:get_map(),
		}
		args.dlg_state, args.dlg_val = dlg_box:get_state()
		
		--function to return performs post-dialog actions
		local func_cb = function()
			if set_save_val then game.set_expression(set_save_val, "save_val") end
			if set_state~=nil then dlg_box:set_state(set_state) end
			if set_state_val~=nil then dlg_box:set_state_val(set_state_val) end
			if play_sound then sol.audio.play_sound(play_sound) end
			if remove_money then game:remove_money(remove_money) end
			if add_money then game:add_money(add_money) end
			
			if give_item then
				local hero = game:get_hero()
				if hero then hero:start_treasure(give_item[1], give_item[2]) end
			end
			
			if dlg_mode then dlg_box:set_mode(dlg_mode) end
			
			local ret
			if type(on_done)=="table" then
				ret = on_done
			elseif type(on_done)=="function" then ret = on_done(args) end
			ret = ret or {}
			
			if ret.dlg then dlg_box.next_dlg = ret end
			
			set_state = ret.set_state
			if set_state==false or type(set_state)=="string" then dlg_box:set_state(set_state) end
			
			set_state_val = ret.set_state_val
			set_state_val = tonumber(set_state_val) or set_state_val --can be number, false or nil
			if set_state_val==false or set_state_val then dlg_box:set_state_val(set_state_val) end
			
			if ret.end_dlg then dlg_box:set_mode"end_dlg" end
		end
		
		return func_cb
	end
	
	
	--// Attaches various parameters for the current dialog to dlg_box
	local condition_list = {
		['hero.gender'] = function() return game:get_gender() end, --TODO add default if not defined
		--TODO add more possible conditions
	}
	local function set_dialog_settings(dlg)
		--reformat substitution values
		local vals_formatted = {}
		local values = dlg.values
		if type(values)=="string" or type(values)=="number" or type(values)=="function" then
			values = {values}
		end
		if type(values)=="table" then
			local new_value
			for _,vals in ipairs(values) do
				if type(vals)=="number" then
					new_value = vals
				elseif type(vals)=="string" then
					new_value = tonumber(vals)
				elseif type(vals)=="function" then
					new_value = vals()
				end
				
				table.insert(vals_formatted, new_value)
			end
		else vals_formatted = dlg_box.values end --if not defined then keep previous
		
		--reformat substitution strings
		local subs_formatted = {}
		local substitutions = dlg.substitutions
		if type(substitutions)=="string" or type(substitutions)=="function" then
			substitutions = {substitutions}
		end
		if type(substitutions)=="table" then
			if substitutions.key or substitutions.values then substitutions = {substitutions} end
			
			local new_text
			for _,subs in ipairs(substitutions) do
				if type(subs)=="string" then --string used as strings.dat key
					new_text = sol.language.get_string(subs) or subs
				elseif type(subs)=="function" then --function returns string to use
					new_text = subs()
				elseif type(subs)=="table" then
					if subs.key then
						local key = condition_list[subs.key] and condition_list[subs.key]()
						new_text = sol.language.get_string(subs[key]) or subs[key]
					elseif subs.values then
						local key = game.expression_check(subs.values, "value", vals_formatted)
						new_text = sol.language.get_string(subs[key]) or subs[key]
					elseif #subs>=1 then --choose entry at random
						new_text = subs[util.random(#subs)]
					else new_text = "???" end --unable to find text to use
				end
				
				table.insert(subs_formatted, new_text)
			end
		else subs_formatted = dlg_box.substitutions end --if not defined then keep previous
		
		dlg_box.substitutions = subs_formatted
		dlg_box.values = vals_formatted
		
		dlg_box.actions = type(dlg.actions)=="table" and dlg.actions or {}
		dlg_box.list = dlg.list
		dlg_box.func_cb = get_dialog_actions(dlg)
	end

	--// Checks if input from player is a valid topic for the given npc then returns the next dialog to display
		--arg2 input (string): Text entered by player in their native language
		--return1 (string): 
	function conv:get_topic_response(npc, input)
		assert(not input or type(input)=="string", "Bad argument #2 to get_topic_response (string or nil expected, got "..type(input)..")")
		--TODO assert for npc
		
		--get topic rules for this npc
		conv.npc = npc --keep reference to the npc the player is talking to --TODO better implementation to keep track of all npcs in conversation
		local topic_id, input_sub = get_topic(input) --find topic_id matching player's input text
		
		local dlg = get_dialog_from_topic(topic_id)
		if not dlg then dlg = get_dialog_from_topic"UNKNOWN" end
		
		set_dialog_settings(dlg)
		
		return dlg and dlg.dlg, input_sub --return topic_sub to remove topic beginning with topic_sub from topic list
	end
	
	
	--// Performs action when player clicks a list item in the conversation dialog
	function conv:list_select(list, index)
		assert(type(list)=="table", "Bad argument #1 to 'list_select' (table expected, got "..type(list)..")")
		
		index = math.floor(tonumber(index) or 0)
		assert(index>0, "Bad argument #2 to 'list_select' (positive number expected)")
		
		local values = dlg_box.values
		if type(values)~="table" then values = {values} end
		
		local dlg_rules = list[index] or {}
		if dlg_rules.select then dlg_rules = dlg_rules[dlg_rules.select(values)] end
		if type(dlg_rules.values)~="table" then dlg_rules.values = {dlg_rules.values} end
		local dlg = dlg_rules
		
		if list.on_select then dlg = list.on_select(index, dlg_rules) end
		if dlg==true then dlg = dlg_rules end
		if not dlg then dlg = get_dialog_from_topic"UNKNOWN" end
		
		if type(dlg)=="string" then dlg = {dlg=dlg} end
		
		set_dialog_settings(dlg)
		
		return dlg and dlg.dlg
	end
	
	
	--// Prepares for viewing the next dialog specified
	function conv:resume_dlg(dlg)
		if type(dlg)=="string" then
			dlg = {dlg=dlg}
		end
		if not dlg then dlg = get_dialog_from_topic"UNKNOWN" end
		
		assert(type(dlg)=="table", "Bad argument #1 to 'resume_dlg' (table expected, got "..type(dlg)..")")
		
		set_dialog_settings(dlg)
		
		return dlg and dlg.dlg
	end
	
	return conv
end

setmetatable(conversation_manager, {__call = conversation_manager.initialize}) --convenience

return conversation_manager


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
