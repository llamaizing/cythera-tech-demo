--[[ topic_rules.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script determines which conversation dialog to use when the player interacts with
	an NPC. The dialog chosen depends on a multitude of factors, such as the time, current
	map, or savegame values. The actions that are performed after a dialog is finished are
	also defined by these topic rules.
	
	topic_rules is a table with an entry for each NPC in the game that uses an interactive
	dialog, where the table key is the name of the NPC. Each NPC has a list of topics that
	the player can ask about. Topic names are given by a non-localized topic_id which gets
	converted to the player's native language by looking up the corresponding entry in the
	strings.dat file. The contents of this file do not need to change for a translation of
	the quest to another language.
	
	Each topic entry then contains a list of properties defining which dialog_id to use in
	response to the topic, what conditions must be present in order for the response to be
	available, and the actions to perform after the dialog is displayed. It's possible for
	multiple dialogs to be associated with a given topic, in which case one of the dialogs
	will be randomly selected from among those having conditions which are met. The weight
	property is used to increase the probability for a dialog being selected over another.
	
	For convenience, topics with only one dialog that has no conditions or actions can use
	just a string to specify the dialog_id. This would be equivalent to using a table with
	only a key for "dlg", which gives the dialog_id. Similarly, an array of strings can be
	used to specify multiple dialog_ids where none have any conditions or actions with one
	to be selected randomly. Dialog entries that require multiple conditions or properties
	should substitute the dialog_id string with a table containing the properties needed.
	
	The topic_rules table can also have entries listing topics that are common to multiple
	NPCs. Having the dialogs defined in one central location helps to make the translation
	easier by reducing duplicated text and ensures consistent translation. In order for an
	NPC to use one of the common topic entries, the topics entry for that NPC must contain
	the property key "EXTRA" with a string value naming the common topic entry to be used.
	An array of strings can be used if multiple common topic entries are desired. When the
	dialog to use for a given topic is being selected, the NPC will always choose an entry
	from its own rules table (if it exists) over an entry from a shared rules table.
	
	Keys for a rules table entry should be lower-case and correspond to a strings.dat key,
	omitting ("topic."..npc_name..".") from the beginning of the key. There are also a few
	special topic keys that are upper-case to distinguish them from the topic_id keys. The
	special keys are as follows:
		EXTRA - (table) list of additional generic topics to have this npc respond to
		GREETING - one of these responses are chosen when dialog is initiated with the NPC
		UNKNOWN - uses this "I don't know" response for topics not in NPC's list of topics
		RULES_SELECT - a function that returns an alternate topic table for the NPC to use
			* This allows for using a different list of topics under certain conditions
			* Returning false uses standard topics list (like if RULES_SELECT not defined)
			* generic responses are still appended to the list unless explicitly disabled
			-- arg1 (string or nil): current dialog state
			-- arg2 (number or nil): current dialog state value

	The properties that can be included with a rules table entry (including the conditions
	for which the dialog is available and actions to perform after viewing the dialog) are
	as follows:
	
	*** properties ***
	dlg --dialogs.dat id to use for the dialog --TODO verify that dlg can be nil
	weight - affects probability of this dialog being chosen when multiple are available
		* probability = this_wieght / sum_of_weights_of_all_eligible_dialogs
		* if no dialogs define a weight then the probability is equal
		* if some dialogs have a weight, then the ones without will use the average weight
	
	*** requirements ***
	map_id --The current map must be this map id string for this dialog to be available
	save_val --value from game:get_value() must be set for this dialog to be available
		* preface with "!" for value must not be set, require multiple values with "&"
	state --a string expression or function to determine if this dialog is available
		* (string) indicates required state string for this dialog to be available
			--preface with "!" to indicate must not be in the specified state
		* (function) should return true if the dialog is eligible, else return false
			--arg1 (string): The current dialog state string (nil if none)
	state_val --a string expression or function to determine if this dialog is available
		* (string) indicates required state value for this dialog to be available
			--value is convertible to number, can preface with "<", "<=", ">", ">=", "!"
		* (function) should return true if the dialog is eligible, else return false
			--arg1 (number): The current dialog state value (nil if none)
	npc_val --a string expression or function to determine if this dialog is available
		* (string) value associated with NPC entity must be set for this dialog to be available
			--preface with "!" for value must not be set, require multiple values with "&"
			--these values are typically custom properties that must be set by other scripts
		* (function) should return true if the dialog is eligible, else return false
			--arg1 (sol.npc): The npc entity that the player is interacting with
	
	*** configuration ***
	substitutions -- replaces instances of $s with a strings.dat entry
		* (string) specified the strings.dat key to use for the substituted text
		* (function) returns the string to use for the substituted text
			--Note: substitutes exact text returned; function must retrieve strings.dat content if needed
		* (table) a table can be used to make substitutions dynamically depending on game conditions
			--The table should contain exactly one of the following keys:
				> "values": chooses the substitution string based on a $v value used in the dialog.
					
					e.g. {values="$v2=10", [true]="string.id.1", [false]="string.id.2"}
					--This example uses the strings.dat entry "string.id.1" if the value substituted
					for the second instance of $v is equal to 10, otherwise uses "string.id.2"
				> "key": 
					(list of possible strings to use as substitution table strings):
					"hero.gender" --returns "male" or "female" depending on the hero's gender
				> if none of the keys above are used, then one numeric entry from the table
				will be chosen at random to be used as the strings.dat key
	
	*** actions ***
	set_save_val --after viewing this dialog, set this value to true with game:set_value()
		--preface with "!" to set value to nil
	set_state --string to set the dialog state to for keeping track of dialog progress
		--set to false in order to clear state; value cleared when dialog done
	set_state_val --number associated with state for keeping track of dialog progress
		--set to false in order to clear state value, value cleared when dialog done
	give_item --item string to add to the player's inventory after viewing this dialog
	remove_money (number or string): amount of money to remove from player
		--string value "$v1" removes money equal to value[1], etc.
	play_sound --(string) name of sound to play
	on_done (function): function to call once last paragraph of current dialog is displayed
		--args.dialog_id (string): dialog id of the dialog that was just displayed
		--args.dlg_state (string or nil): current dialog state (after set_state has been applied)
		--args.dlg_val (number or nil): current value associated with dialog state (after set_state_val has been applied)
		--args.npc (map.entity): NPC that the player is interacting with
		--args.map_id (sol.map): The currently active map
		--return.next_dlg (string): dialog id of dialog to immediately begin displaying (if nil then waits for player input)
		--return.set_state (string, false or nil): string to use for new dialog state
			--if false then state becomes nil; if nil then does nothing
		--return.set_state_val (number, false or nil): number to use for new dialog state value
			--if false then state value becomes nil; if nil then does nothing
		--return.end_dlg (boolean): if true then closes the dialog
	on_done (string): if a string instead of a function then is used to specify the next dialog to show
		--on_done="dlg.id" is equivalent to on_done=function() return {next_dlg="dlg.id"} end
	on_done (table): can also be a table with the same keys as the one returned by the function 
	
	*** interaction ***
	dlg_mode --(string) defines how to handle keyboard/mouse events once dialog is over
		--"await_next": (internal use only) player has to press any key to advance to next paragraph of current dialog
		--"await_prompt": (default) The player will have to enter text to advance to the next dialog
		--"prompt_only": Like await_prompt except does not show topic list (to have the player respond directly to a question)
		--"await_list": Player has to choose an option from a list in order to advance to next dialog
		--"end_dlg": the dialog will close after this dialog is finished being displayed
]]

local rules = {}

local util = require"scripts/util"

function rules:initialize(game)
	local dlg_box = game:get_dialog_box"conversation"
	
	local function where_substitution(sel, dlg_rules)
		local info = sol.language.get_dialog(dlg_rules.dlg)
		local map = game:get_map()
		local map_name = map and map:get_id()
		local substitution = info.default
		
		if info.map and info.map==map_name and info.dest then
			local dest = map:get_entity(info.dest)
			local dest_x,dest_y = dest:get_position()
			
			local hero = map:get_hero()
			local hero_x,hero_y = hero:get_position()
			
			local dx = math.floor((dest_x - hero_x)/16)
			local dy = math.floor((dest_y - hero_y)/16)
			
			local horz = ""
			if dx > 0 then
				horz = dx..sol.language.get_string"directions.east"
			elseif dx < 0 then
				horz = math.abs(dx)..sol.language.get_string"directions.west"
			end
			
			local vert = ""
			if dy > 0 then
				vert = dy..sol.language.get_string"directions.south"
			elseif dy < 0 then
				vert = math.abs(dy)..sol.language.get_string"directions.north"
			end
			
			local and_str = ""
			if string.len(dx)>0 and string.len(dy)>0 then and_str=sol.language.get_string"directions.and" end
			
			substitution = horz..and_str..vert
		end
		
		dlg_rules.substitutions = substitution
		
		return true
	end
	
	-------------------------
	-- Dice Game Functions --
	-------------------------
	
	local DICE_COST = 1 --cost to play dice game
	local dice_game = {}
	
	--// Returns number corresponding to outcome of game and values of dice
		--1000's digit is amount of money player wins (0-5)
		--100's digit is player's die roll (1-6)
		--10's digit is foe's first die roll (1-6)
		--1's digit is foe's second die roll (1-6)
		--special exception: if foe's first roll is equal to player's then just the number 1-6 is returned for the value of the roll
	function dice_game.roll()
		local player_roll = util.random(6)
		local foe_roll1 = util.random(6)
		local foe_roll2 = util.random(6)
		
		if player_roll==foe_roll1 then return player_roll end --rolls equal, player wins 2
		
		--player's die is 'trapped' if between or equal to these values
		local foe_min = math.min(foe_roll1, foe_roll2)
		local foe_max = math.max(foe_roll1, foe_roll2)
		
		local winnings --number of oboloi won by player (0-5)
		if player_roll>=foe_min and player_roll<=foe_max then --trapped, player loses
			winnings = 0
		else winnings = math.max(player_roll - foe_max, foe_min - player_roll) end
		
		return tonumber(table.concat({winnings, player_roll, foe_roll1, foe_roll2}, "")) --convert to 4-digit number
	end
	
	
	--// Returns topics entry for starting new round of dice game depending on whether player is broke
	function dice_game.new_game(args)
		local money = game:get_money() or 0
		if money >= DICE_COST then
			game:remove_money(DICE_COST)
			
			local rules = topic_rules.DICE_GAME.start
			rules.set_state_val = dice_game.roll() --roll dice and save values in dlg state value
			rules.values = dice_game.roll1_values(rules.set_state_val)
			
			return rules
		else return topic_rules.DICE_GAME.broke end
	end
	
	
	--// Returns table with foe's first roll and players roll as numbers.
	--// Used as $v values for dialogs.dat id "Crito.play"
	function dice_game.roll1_values(state_value)
		state_value = state_value or 1
		if state_value<=6 then return {state_value, state_value} end --player and foe rolls are equal
		
		local str = string.format("%04d", state_value) --otherwise state_value is a 4-digit number
		
		local values = {}
		for i=3,2,-1 do table.insert( values, tonumber(str:sub(i,i)) ) end
		
		return values
	end
	
	
	--// Returns table containing foe's second roll as number.
	--// Used as $v values for dialogs.dat id "Crito.play2"
	function dice_game.roll2_values(state_value)
		state_value = state_value or 1
		local str = string.format("%04d", state_value)
		
		return { tonumber(str:sub(4,4)) }
	end
	
	
	--// Returns a number for the amount of oboloi the player won this round (0-5)
	function dice_game.get_winnings(state_value)
		state_value = state_value or 1
		local str = string.format("%04d", state_value)
		
		return tonumber(str:sub(1,1))
	end
	
	
	--// Returns topics entry to determine next branch of dice game after first roll
	function dice_game.get_stage2(args)
		local state_value = args.dlg_val or 1
		
		if state_value <= 6 then --player's roll and foe's first roll equal, player wins
			return topic_rules.DICE_GAME.equal
		else --foe to take second roll
			local rules = topic_rules.DICE_GAME.roll2
			rules.values = dice_game.roll2_values(state_value) --calculate $v values for next dialog
			return rules
		end
	end
	
	
	--// Returns topics entry to determine next branch of dice game after second roll
	function dice_game.get_stage3(args)
		local state_value = args.dlg_val or 1
			
		local winnings = dice_game.get_winnings(state_value)
		if winnings==1 then --player wins back initial bet; play again
			return topic_rules.DICE_GAME.tie
		elseif winnings>0 then --player wins
			local rules = topic_rules.DICE_GAME.win
			rules.values = {winnings, game:get_money() + winnings} --calculate $v values for next dialog
			rules.add_money = winnings --amount of money to credit player after next dialog is shown
			
			return rules
		else --player loses
			local rules = topic_rules.DICE_GAME.lose
			rules.values = {game:get_money()} --calculate $v values for next dialog
			
			return rules
		end
	end
	
	
	----------
	-- Data --
	----------
	
	--TODO move this data to a separate .dat file? (quest-specific)
	
	--lists referenced multiple times in topic_list
	local lists = {
		is_afford_v1 = function(values) --1 if player can afford value #1, else 2
			local money = game:get_money() or 0
			return money>=(values[1] or 0) and 1 or 2
		end,
		is_not_broke = function(values) --2 if player has no money, else 1
			local money = game:get_money() or 0
			return money>0 and 1 or 2
		end,
		play_again = {
			{ --yes
				label = "choice.yes",
				{
					dlg = "Crito.play_again_yes",
					on_done = dice_game.new_game,
				},
				{ dlg = "Crito.dice_broke" },
				select = function(values) --1 if player has money, else 2
					local money = game:get_money() or 0
					return money>=DICE_COST and 1 or 2
				end,
			},
			{ --no
				label = "choice.no",
				dlg = "Crito.play_again_no",
			},
		},
	}
	
	--NPC-specific topic rules
	local topic_rules = {
		Demodocus = {
		--[[
		Save game values:
			* met_demodocus: true as soon as first dialog is complete
			* plague_cured: true after curing plague (not used)
		]]
			GREETING = {
				{	--first time greeting
					dlg = "Demodocus.greeting_initial",
					save_val = "!met_demodocus",
					set_save_val = "met_demodocus",
					substitutions = {key="hero.gender", male="hero_male", female="hero_female"},
				},
				{	--subsequent greetings
					dlg = "Demodocus.greeting",
					save_val = "met_demodocus",
				},
			},
			UNKNOWN = "Demodocus.unknown",
			EXTRA = "CITIZEN",
			name = "Demodocus.name",
			job = "Demodocus.job",
			join = "Demodocus.join",
			train = "Demodocus.train",
			alaric = "Demodocus.alaric",
			demodocus = "Demodocus.demodocus",
			neoptolemus = "Demodocus.neoptolemus",
			haggling = "Demodocus.neoptolemus",
			persuasion ="Demodocus.neoptolemus",
		
			bard = "Demodocus.job",
			strange = "Demodocus.strange",
			plague = {
				{	--response before plague cured
					dlg = "Demodocus.plague_plague",
					save_val = "!plague_cured",
				},
				{	--response after plague cured
					dlg = "Demodocus.plague",
					save_val = "plague_cured",
				},
			},
			rumors = {
				{	--response before plague cured
					dlg = "Demodocus.rumors_plague",
					save_val = "!plague_cured",
				},
				{	--response after plague cured
					dlg = "Demodocus.rumors",
					save_val = "plague_cured",
				},
			},
			song = "Demodocus.song",
			entertain = "Demodocus.entertain",
			land = "Demodocus.land",
			more = "Demodocus.more",
			crime = "Demodocus.crime",
			bandits = "Demodocus.bandits",
			organized = "Demodocus.organized",
			inns = "Demodocus.inns",
			traveling = "Demodocus.traveling",
			bye = {
				dlg = "Demodocus.bye",
				dlg_mode = "end_dlg",
			},
		},
		Neoptolemus = { --responses after learning his name (or while eating)
		--[[
		Dialog States:
			* ask_name: Neoptolemus asks who told you his name with a prompt for the player to enter text
			* story: While Neoptolemus is telling his story
				- state val starts at 0 and increments up to 5 during story to keep track of progress
			* train: Neoptolemus asks what to train in and the player can choose from a list
		Save game values:
			* met_neoptolemus: true after learning his name
			* neoptolemus_story: true after listening to his story
		]]
			RULES_SELECT = function(dlg_state, dlg_state_val)
				local map_id = game:get_map()
				if map_id then map_id = map_id:get_id() end
				 
				if dlg_state=="ask_name" then --use alternate list of responses for player prompt
					return "Neoptolemus_prompt"
				elseif dlg_state=="story" then --use alternate list of responses during story
					return "Neoptolemus_story"
				elseif map_id=="cademia" and not game:get_value"met_neoptolemus" then --use alternate list of responses before learning his name
					return "Neoptolemus_stranger"
				else return false end --use standard responses
			end,
			GREETING = {
				{ --standard greeting
					dlg = "Neoptolemus.greeting",
					map_id = "cademia",
				},
				{ --greeting while eating
					dlg = "Neoptolemus.greeting_eating",
					map_id = "neoptolemus_house",
				},
			},
			UNKNOWN = "Neoptolemus.unknown",
			EXTRA = {"CITIZEN"},
			name = { --only occurs while eating
				dlg = "Neoptolemus.name",
				set_save_val = "met_neoptolemus",
				actions = {refresh_name=true},
			},
			job = "Neoptolemus.job",
			train = { --alias: teach
				{ --Neoptolemus response before listening to story
					dlg = "Neoptolemus.train_before_story",
					save_val = "!neoptolemus_story",
				},
				{ --Neoptolemus response after listening to story (will train)
					dlg = "Neoptolemus.train_after_story",
					save_val = "neoptolemus_story",
					dlg_mode = "await_list",
					list = {
						{ --haggling
							label = "skill.name.haggling",
							dlg = "train.learn",
							substitutions = "skill.name.haggling", --substitute name of skill learned
							set_save_val = "skill_haggling",
							play_sound = "treasure",
						},
						{ --persuasion
							label = "skill.name.persuasion",
							dlg = "train.learn",
							substitutions = "skill.name.persuasion", --substitute name of skill learned
							set_save_val = "skill_persuasion",
							play_sound = "treasure",
						},
						on_select = function(sel, dlg_rules)
							local new_rules = true --use original dialog unless overridden
							if game:get_value(dlg_rules.set_save_val) then --player already learned skill
								new_rules = {
									dlg = "train.already_learned",
									substitutions = dlg_rules.substitutions,
								}
							elseif (game:get_value"skill_points" or 0) < 1 then --player has no xp to spend
								new_rules = "train.no_xp"
							else
								--decrement skill points by 1
								local skill_points = game:get_value"skill_points" or 0
								skill_points = math.max(skill_points - 1, 0)
								game:set_value("skill_points", skill_points)
							end
							
							return new_rules
						end,
					},
				},
			},
			haggling = {
				{ --before listening to story
					dlg = "Neoptolemus.haggling_before_story",
					save_val = "!neoptolemus_story",
				},
				{ --after listening to story
					dlg = "Neoptolemus.haggling_after_story",
					save_val = "neoptolemus_story",
				},
			},
			persuasion = {
				{ --before listening to story
					dlg = "Neoptolemus.persuasion_before_story",
					save_val = "!neoptolemus_story",
				},
				{ --after listening to story
					dlg = "Neoptolemus.persuasion_after_story",
					save_val = "neoptolemus_story",
				},
			},
			respect = {
				{ --only occurs while eating
					dlg = "Neoptolemus.respect_stranger",
					save_val = "!met_neoptolemus",
		
				},
				{
					dlg = "Neoptolemus.respect",
					save_val = "met_neoptolemus",
				},
			},
			days = { --alias: differently
				{ --before listening to story (and must know his name); begin story
					dlg = "Neoptolemus.days_before_story",
					save_val = "!neoptolemus_story&met_neoptolemus",
					set_state = "story",
					set_state_val = 0,
				},
				{ --after listening to story; don't listen to story again (also occurs if don't know his name)
					dlg = "Neoptolemus.days_after_story",
					save_val = "neoptolemus_story|!met_neoptolemus",
				},
			},
			merchant = "Neoptolemus.merchant",
			interested = {
				{ --before listening to story
					dlg = "Neoptolemus.interested_before_story",
					save_val = "!neoptolemus_story",
				},
				{ --after listening to story
					dlg = "Neoptolemus.interested_after_story",
					save_val = "neoptolemus_story",
				},
			},
			grapes = { --after listening to story
					dlg = "Neoptolemus.grapes_after_story",
					save_val = "neoptolemus_story",
			}, --otherwise use UNKNOWN response
			bye = {
				dlg = "Neoptolemus.bye",
				dlg_mode = "end_dlg",
			}, --otherwise use UNKNOWN response
		},
		Neoptolemus_stranger = { --Neoptolemus responses before learning his name, all others give UNKNOWN
			GREETING = "Neoptolemus.greeting_stranger",
			UNKNOWN = "Neoptolemus.go_away",
			EXTRA = nil, --don't respond to generic topics
			born = "Neoptolemus.merchant_stranger",
			elders = "Neoptolemus.elders_stranger",
			job = "Neoptolemus.no_business",
			name = "Neoptolemus.no_business",
			train = "Neoptolemus.train_before_name", --alias: teach
			merchant = "Neoptolemus.merchant_stranger",
			neoptolemus = {
				dlg = "Neoptolemus.neoptolemus",
				dlg_mode = "prompt_only", --player inputs name of person who told his name
				set_state = "ask_name"
			},
			respect = "Neoptolemus.no_respect",
			bye = {
				dlg = "Neoptolemus.bye",
				dlg_mode = "end_dlg",
			},
		},
		Neoptolemus_prompt = { --Neoptolemus responses to prompt asking who told player his name
			UNKNOWN = {
				dlg = "Neoptolemus.neoptolemus_other",
				set_state = false, --remove prompt
			},
			EXTRA = nil, --don't respond to generic topics during prompt
			alaric = {
				dlg = "Neoptolemus.neoptolemus_alaric",
				set_state = false, --remove prompt
			},
			demodocus = {
				dlg = "Neoptolemus.neoptolemus_demodocus",
				set_save_val = "met_neoptolemus",
				set_state = false, --remove prompt
				actions = {refresh_name=true},
			},
		},
		Neoptolemus_story = { --Neoptolemus responses during story
			UNKNOWN = { --interrupted story
				dlg = "Neoptolemus.story_interrupt",
				set_state = false, --end story
				set_state_val = false,
			},
			EXTRA = nil, --don't respond to generic topics during story
			odemia = {
				{ --at correct time in story
					dlg = "Neoptolemus.odemia_story",
					state_val = "0",
					set_state_val = "1", --progress story
				},
				{ --at wrong time during story
					dlg = "Neoptolemus.odemia_interrupt",
					state_val = ">0",
					set_state = false, --end story
					set_state_val = false,
				}
			},
			client = { --wrong choice, story ends
					dlg = "Neoptolemus.client_story",
					state_val = "0",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			cloth = { --wrong choice, story ends
					dlg = "Neoptolemus.cloth_story",
					state_val = "<=1",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			grapes = { --at correct time in story
					dlg = "Neoptolemus.grapes_story",
					state_val = "1",
					set_state_val = "2", --progress story
			}, --otherwise use UNKNOWN response
			fashion = { --wrong choice, story ends
					dlg = "Neoptolemus.fashion_story",
					state_val = "2",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			belt = {
				{ --at correct time in story (first time)
					dlg = "Neoptolemus.belt_story_first",
					state_val = "2",
					set_state_val = "3", --progress story
				},
				{ --conclude story
					dlg = "Neoptolemus.belt_story_second",
					state_val = "5",
					set_save_val = "neoptolemus_story", --listened to story
					set_state = false, --story done
					set_state_val = false,
				},
			}, --otherwise use UNKNOWN response
			cheap = { --wrong choice, story ends
					dlg = "Neoptolemus.cheap_story",
					state_val = "3",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			cape = { --wrong choice, story ends
					dlg = "Neoptolemus.cape_story",
					state_val = "3",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			oboloi = { --at correct time in story
					dlg = "Neoptolemus.oboloi_story",
					state_val = "3",
					set_state_val = "4", --progress story
			}, --otherwise use UNKNOWN response
			fancy = { --wrong choice, story ends
					dlg = "Neoptolemus.fancy_story",
					state_val = "4",
					set_state = false, --end story
					set_state_val = false,
			}, --otherwise use UNKNOWN response
			bees = { --at correct time in story
					dlg = "Neoptolemus.bees_story",
					state_val = "4",
					set_state_val = "5", --progress story
			},
			bye = {
				dlg = "Neoptolemus.bye",
				dlg_mode = "end_dlg",
			},
		},
		Crito = {
		--[[
		Save game values:
			* crito_meal_pending: temporarily flag the player as having paid for a meal until it is redeemed
			* crito_bed_pending: temporarily flag the player as having paid for a bed until it is redeemed
			* skill_persuasion: required for additional dialog
			* possession_bottle_1: true after receiving bottle
		]]
			GREETING = {
				{	--standard greeting; player has not paid for a meal
					dlg = "Crito.greeting",
					save_val = "!crito_meal_pending",
				},
				{	--player has paid for a room but not eaten the meal yet
					dlg = "Crito.greeting_meal",
					save_val = "crito_meal_pending",
					dlg_mode = "await_list", --yes or no
					list = {
						{ --yes
							label = "choice.yes",
							dlg = "Crito.meal_yes",
							set_save_val = "!crito_meal_pending",
							give_item = nil, --TODO give food item to player
						},
						{ --no
							label = "choice.no",
							dlg = "Crito.greeting_meal_no",
						},
					},
				},
			},
			UNKNOWN = "Crito.unknown",
			EXTRA = "CITIZEN",
			name = "Crito.name",
			job = "Crito.job",
			inn = "Crito.inn",
			room = {
				dlg = "Crito.room",
				dlg_mode = "await_list",
				values = 6, --cost to rent room for the night
				list = {
					{ --yes
						label = "choice.yes",
						{
							dlg = "Crito.room_yes",
							set_save_val = "crito_meal_pending&crito_bed_pending",
							remove_money = "$v1",
						},
						{ dlg = "Crito.room_yes_broke" },
						select = lists.is_afford_v1, --1 if player can afford room, else 2
					},
					{ --no
						label = "choice.no",
						dlg = "Crito.room_no",
					},
				},
			},
			food = {
				{
					dlg = "Crito.food",
					dlg_mode = "await_list",
					list = {
						{ --Menu item #1
							label = "food.cheese",
							dlg = "Crito.food_cheese",
							values = 8, --cost
							remove_money = "$v1",
							give_item = nil, --TODO add as inventory item
						},
						{ --Menu item #2
							label = "food.bread",
							dlg = "Crito.food_bread",
							values = 5, --cost
							remove_money = "$v1",
							give_item = nil, --TODO add as inventory item
						},
						{ --Menu item #3
							label = "food.fish",
							dlg = "Crito.food_fish",
							values = 5, --cost
							remove_money = "$v1",
							give_item = nil, --TODO add as inventory item
						},
						{ --Menu item #4
							label = "food.wine",
							{
								dlg = "Crito.food_wine",
								values = 0, --don't make purchase
							},
							{
								dlg = "Crito.food_wine_persuasion",
								values = 10,
								remove_money = "$v1",
								give_item = "bottle_1",
								set_save_val = "possession_bottle_1",
							},
							select = function()
								return game:get_value"skill_persuasion" and 2 or 1
							end,
						},
						on_select = function(sel, dlg_rules)
							local money = game:get_money() or 0
							local values = dlg_rules.values or {}
							if money >= (tonumber(values[1]) or 0) then
								return true 
							else return "Crito.meal_yes_broke" end
						end,
					},
				},
				{ dlg = "Crito.food_broke", },
				select = lists.is_not_broke, --2 if player has no money, else 1
			},
			meal = {
				{ --player hasn't already paid for a meal not yet redeemded
					dlg = "Crito.meal",
					save_val = "!crito_meal_pending",
					dlg_mode = "await_list",
					values = 4, --cost of meal
					list = {
						{ --yes
							label = "choice.yes",
							{
								dlg = "Crito.meal_yes",
								set_save_val = "!crito_meal_pending",
								remove_money = "$v1",
								give_item = nil, --TODO give food item to player
							},
							{ dlg = "Crito.meal_yes_broke" },
							select = lists.is_afford_v1, --1 if player can afford meal, else 2
						},
						{ --no
							label = "choice.no",
							dlg = "Crito.meal_no",
						},
					},
				},
				{ --player has paid for meal in advance
					dlg = "Crito.meal_yes",
					save_val = "crito_meal_pending",
					set_save_val = "!crito_meal_pending",
					give_item = nil, --TODO give food item to player
				},
			},
			drink = {
				dlg = "Crito.drink",
				dlg_mode = "await_list",
				values = 1, --cost of drink
				substitutions = {values="$v1=1", [true]="obol_single", [false]="obol_plural"},
				list = {
					{ --yes
						label = "choice.yes",
						{
							dlg = "Crito.drink_join", --TODO have pool of dialogs to choose from if player drinks
							set_save_val = "!crito_meal_pending",
							remove_money = "$v1",
							give_item = nil --TODO give food item to player
						},
						{ dlg = "Crito.drink_yes_broke" },
						select = lists.is_afford_v1, --1 if player can afford meal, else 2
					},
					{ --no
						label = "choice.no",
						dlg = "Crito.drink_no",
					},
				},
			},
			dice = {
				dlg = "Crito.dice", --do you need instructions?
				dlg_mode = "await_list",
				list = {
					{ --yes
						label = "choice.yes",
						dlg = "Crito.dice_instructions",
						dlg_mode = "await_list",
						list = {
							{ --yes
								label = "choice.yes",
								{
									dlg = "Crito.dice_instructions_yes",
									on_done = dice_game.new_game,
								},
								{ dlg = "Crito.dice_broke" },
								select = function(values) --1 if player has money, else 2
									local money = game:get_money() or 0
									return money>=DICE_COST and 1 or 2
								end,
							},
							{ --no
								label = "choice.no",
								dlg = "Crito.dice_instructions_no",
							},
						},
					},
					{ --no
						label = "choice.no",
						dlg = "Crito.dice_no",
						on_done = dice_game.new_game,
					},
				},
			},
			demodocus = "Crito.demodocus",
			wine = "Crito.wine",
			bye = {
				dlg = "Crito.bye",
				dlg_mode = "end_dlg",
			},
		},
		DICE_GAME = { --dice game
			start = {
				dlg = "Crito.play",
				play_sound = "dice_roll",
				set_state = "dice_game",
				values = nil, --changed dynamically with dice_game.new_game()
				set_state_val = nil, --changed dynamically with dice_game.new_game()
				on_done = dice_game.get_stage2,
			},
			equal = {
				dlg = "Crito.play_equal",
				add_money = 2,
				dlg_mode = "await_list",
				list = lists.play_again,
			},
			roll2 = {
				dlg = "Crito.play2",
				values = nil, --changed dynamically with dice_game.get_stage2()
				on_done = dice_game.get_stage3,
			},
			win = {
				dlg = "Crito.play_win",
				values = nil, --changed dynamically with dice_game.get_stage3()
				add_money = nil, --changed dynamically with dice_game.get_stage3()
				dlg_mode = "await_list",
				list = lists.play_again,
			},
			lose = {
				dlg = "Crito.play_lose",
				values = nil, --changed dynamically with dice_game.get_stage3()
				dlg_mode = "await_list",
				list = lists.play_again,
			},
			tie = {
				dlg = "Crito.play_tie",
				add_money = DICE_COST, --will be subtracted again on new game
				on_done = dice_game.new_game,
			},
			broke = {
				dlg = "Crito.dice_broke",
				set_state = false,
				set_state_val = false,
			},
		},
		CITIZEN = { --generic NPC responses
			music = "COMMON.music",
			odemia = "COMMON.odemia",
			cademia = "COMMON.cademia",
			sitia = "COMMON.sitia",
			catamarca = "COMMON.catamarca",
			oboloi = "COMMON.oboloi",
			alaric = "COMMON.alaric",
			where = {
				dlg = "WHERE_IS.title",
				dlg_mode = "await_list",
				list = {
					{
						label = "map.city.catamarca",
						dlg = "WHERE_IS.from_cademia.catamarca",
					},
					{
						label = "map.city.odemia",
						dlg = "WHERE_IS.from_cademia.odemia",
					},
					{
						label = "map.location.cademia.inn",
						dlg = "WHERE_IS.from_cademia.inn",
					},
					on_select = where_substitution,
				},
			},
		},
	}

	--assign aliases
	topic_rules.Neoptolemus.differently = topic_rules.Neoptolemus.days
	topic_rules.Neoptolemus.teach = topic_rules.Neoptolemus.train
	topic_rules.Neoptolemus_stranger.teach = topic_rules.Neoptolemus_stranger.train
	topic_rules.Crito.crito = topic_rules.Crito.inn
	
	return topic_rules
end

setmetatable(rules, {__call = rules.initialize}) --convenience

return rules


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
