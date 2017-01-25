--[[ util.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script preforms a number of low-level, utilitarian tasks, such as creating a seed
	value for generating random numbers and parsing strings of utf-8 multibyte characters.
]]

local util = {}

local is_seed = false

--// Generates seed value for random number generation
function util.seed()
	local game_time = sol.main.get_elapsed_time()
	local seed = (os.time() * game_time) % 2^53-1
	
	math.randomseed(seed)
	math.random(); math.random(); math.random()
	
	--re-seed in 30 to 40 seconds if elapsed time is less than 30 seconds
	if game_time < 30000 then
		sol.timer.start(sol.main, 30000+math.random(10000), function() is_seed=false end)
	else util.random = math.random end --stop doing seed check
	
	is_seed = true
end


--// Same as math.random but generates seed first time used
function util.random(...)
	if not is_seed then util.seed() end
	return math.random(...)
end


--// Finds number of characters (can be multibyte) in text (string) if arg max omitted (return #1)
--// Alternately finds number of bytes for the first up to max (number) of characters in text (return #2)
	--arg1 text (string): text to use
	--arg2 max (number, optional): stops counting once this number of multibyte characters found
	--ret1 (number): number of characters (each multibyte counted as one) found
	--ret2 (number): length in bytes of all found characters (equals text:len() if max omitted or fewer than max chars found)
function util.char_count(text, max)
	assert(type(text)=="string", "Bad argument #1 to 'char_count' (string expected, got "..type(text)..")")
	max = tonumber(max)
	
	local char_count = 0
	local char
	local byte
	
	local i = 1
	local text_len = text:len()
	while i<=text_len and (not max or char_count<max) do
		char = text:sub(i,i)
		byte = char:byte()
		
		if byte <= 127 then --1 byte character
			i = i + 1
		elseif byte >= 192 and byte < 224 then --2 byte character
			i = i + 2
		elseif byte <= 224 and byte < 240 then --3 byte character
			i = i + 3
		elseif byte <= 240 and byte < 248 then --4 byte character
			i = i + 4
		else i = i + 1 end --not defined
		
		char_count = char_count + 1
	end
	
	return char_count, i-1
end


--// Returns table containing text split into substrings of each multibyte character
	--arg1 text (string): text to split into multibyte characters
	--arg2 max (number, optional): if specified, only get the first n multibyte characters
	--ret1 (table): array of each multibyte character
function util.get_chars(text, max)
	assert(type(text)=="string", "Bad argument #1 to 'char_iter' (string expected, got "..type(text)..")")
	max = tonumber(max)
	
	local chars = {} --array of multibyte chars (return #1)
	local chars_lookup = {} --each multibyte char present in text is a key with value true (return #2)
	--Note: don't want to combine chars and chars_lookup into same table because if char is a number it will mess things up
	
	local char
	local byte
	local count --how many bytes the current char uses
	
	local i = 1
	local text_len = text:len()
	while i<=text_len and (not max or #chars<max) do
		char = text:sub(i,i)
		byte = char:byte()
		
		if byte <= 127 then --1 byte character
			count = 1
		elseif byte >= 192 and byte < 224 then --2 byte character
			count = 2
		elseif byte <= 224 and byte < 240 then --3 byte character
			count = 3
		elseif byte <= 240 and byte < 248 then --4 byte character
			count = 4
		else count = 1 end --not defined
		
		char = text:sub(i,i+count-1)
		table.insert(chars, char) --substring of this multibyte char
		chars_lookup[char] = true
		
		i = i + 1 --skip to start of next multibyte char
	end
	
	return chars, chars_lookup
end


--// Gets a string in the current language for string_id using sol.language.get_string(string_id)
--// Then substitutes any instances of $s in that string with entries from the table subs
--// Then replaces instances of "$a" or "$A $A" with "a" or "an" depending on the first letter of the following word.
--// "a" & "an" are customizable in strings.dat, as are which characters are considered vowels.
--// A single "$a" always gets replaced with the article; there must be two of "$A" to replace with the article, otherwise it is omitted.
--// This way you can have one "$A" in the strings.dat string and the second "$A" has to come from the string substituted for "$s",
--// thus allowing you to control whether the article is included by the string that gets substituted
	--ret1 (string): Return is the native-language sting after all substitutions have been made
function util.get_string_article(string_id, subs)
	assert(type(string_id)=="string", "Bad argument #1 to 'get_string_article' (string expected, got "..type(string_id)..")")
	if type(subs)=="string" then subs = {subs} end --if single string entry then put in table
	assert(not subs or type(subs)=="table", "Bad argument #2 to 'get_string_article' (nil or string or table expected)")
	
	--get raw text from strings.dat
	local str = sol.language.get_string(string_id)
	if not str then return end --string_id does not exist in strings.dat
	
	--get articles and vowels from strings.dat
	local article = sol.language.get_string"lang.article" or ""
	local article_vowel = sol.language.get_string"lang.article_vowel" or ""
	local vowels = sol.language.get_string"lang.vowels" or ""
	
	_,vowels = util.get_chars(vowels) --convert string to table
	
	--make all substitutions
	for i,sub in ipairs(subs or {}) do
		str = str:gsub("%$s", sub, 1)
	end
	
	--list of patterns to substitute for article; order matters, replace doubles first
		--[1]: gmatch pattern to extract characters used and analyze
		--[2]: gsub pattern to make substitution
	local patterns = {
		{"%$([Aa])%s?%$([Aa])%s?(%S*)", "%$[Aa]%s?%$[Aa]%s?"},
		{"%$(a)%s?()(%S*)", "%$a%s?"}, --empty parentheses are to ensure correct number of returns
		{"%$(A)%s?()(%S*)", "%$A%s?"},
	}
	
	local iter
	local char --first non-space multibyte character following article
	local a_str --either article or article_vowel
	for i,pattern in ipairs(patterns) do
		--start by extracting pattern to see first character after
		iter = str:gmatch(pattern[1])
		for a1,a2,word in iter do
			--determine whether to use article or article_vowel
			char = util.get_chars(word or "", 1)[1]
			a_str = (vowels[char or ""] and article_vowel or article).." "
			
			--determine wether article should be used or not
			if a1 and a2 and not tonumber(a2) then --always replace pair
				str = str:gsub(pattern[2], a_str, 1)
			elseif a1=="a" then --always replace single $a
				str = str:gsub(pattern[2], a_str, 1)
			else str = str:gsub(pattern[2], "", 1) end --do not replace single $A
		end
	end
	
	return str
end


--// game-specific functions
function util:initialize(game)
	--gets value of id based on context key
	local get_val = {
		save_val = function(id, _) return game and game:get_value(id) end, --get savegame variable
		value = function(id, data)
			assert(type(data)=="table", "Bad argument #3 to 'expression_check' for context 'value' (table expected)")
			
			local index = tonumber(id)
			if not index then
				index = tonumber(id:match"^%$v(.*)")
				return index and data[index] or "???"
			else return data[index] or "???" end
		end,
		--TODO add more context options
	}
	
	--// Checks if a string expression is true or false
		--arg1 expr (string): The expression to check
		--arg2 context (string): what to check the expression against (e.g. keys are save variable names)
			--"save_val": compare to savegame variables
		--ret1 (boolean): True if the expression is met, otherwise false
	--// Expression keys can contain alphanumeric characters and underscore; ! to negate, & for AND, | for OR
	--// AND evaluated before OR, e.g.: "one&two|three&four" is evaluated as (one AND two) OR (three AND four)
	--// For numeric expressions: =, <, >, <=, >=, != can be used followed by a number
	function game.expression_check(expr, context, data)
		if not expr then return true end --no expression specified == pass
		assert(type(expr)=="string", "Bad argument #1 to 'expression_check' (string or nil expected, got "..type(expr)..")")
		
		local func = get_val[context]
		assert(type(func)=="function", "Bad argument #2 to 'expression_check' (not a valid context)")
		
		local is_valid = false --at least one | expression must be valid
		for sub_expr in expr:gmatch"([^|]+)" do --handle multiple expressions separated by |
			local sub_valid = true --all & sub expressions must be true
			for and_expr in sub_expr:gmatch"([^&]+)" do
				local num_id, compare, num = and_expr:match"^(.+)([!<>=]+)(%d+)$" --numeric validation
				local is_not, id = and_expr:match"^(!?)(.+)" --non-numeric validation
		
				is_not = is_not=="!"
				num = tonumber(num)
		
				if not num or not compare then --non-numeric expression
					local is_set = id and func(id, data) --get what value is set to
					if (is_set and is_not) or not (is_set or is_not) then --XOR
						sub_valid = false
						break --don't check rest of & sub expressions
					end
				elseif num and compare~="" and not is_not then --numeric comparison
					local num_val = tonumber(num_id and func(num_id, data))
					if num_val then
						--possible values for compare; all other comparator strings ignored (i.e. condition met)
						local not_equal = compare=="!=" or compare=="<" or compare==">" --fail if compare is one of these and state values are equal
						local not_less = compare=="=" or compare==">" or compare==">=" --fail if compare is one of these and state value is less
						local not_more = compare=="=" or compare=="<" or compare=="<=" --fail if compare is one of these and state value is greater

						if not_equal and num_val==num then
							sub_valid = false; break
						elseif not_less and num_val<num then
							sub_valid = false; break
						elseif not_more and num_val>num then
							sub_valid = false; break
						end
					else sub_valid = false; break end
				end
			end
	
			if sub_valid then is_valid = true; break end
		end

		return is_valid
	end
	
	
	--sets value of id based on context key
	local set_val = {
		save_val = function(id, val) return game and game:set_value(id, val) end, --set savegame variable
		--TODO add more context options
	}
	
	--//Sets the value specified by a string expression
		--arg1 expr (string): The expression to set
		--arg2 context (string): what to set the expression against
	--// Expressions keys can contain alphanumeric characters and underscore; followed by = and the value to set
	--// For multiple expressions, separate with &
		--e.g. game.set_expression("saved_princess&num_rewards=3&!has_door_key", "save_val") is equivalent to
			--game:set_value("saved_princess", true) game:set_value("num_rewards", 3) game:set_value("has_door_key", false)
	function game.set_expression(expr, context)
		assert(type(expr)=="string", "Bad argument #1 to 'set_expression' (string expected, got "..type(expr)..")")
		
		local func = set_val[context]
		assert(type(func)=="function", "Bad argument #2 to 'set_expression' (not a valid context)")
		
		for sub_expr in expr:gmatch"([^&]+)" do --separate expressions by &
			local is_not, id, equals, val = sub_expr:match"^(!?)([^!=]+)(=?)(.*)$"
			
			is_not = is_not=="!"
			equals = equals=="="
			
			local val = tonumber(val) or val
			if not equals then val = not is_not end --use boolean value
			
			func(id, val)
		end
	end
end

setmetatable(util, {__call = util.initialize}) --convenience

return util


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
