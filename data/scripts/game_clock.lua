--[[ game_clock.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script keeps track of the in-game time, which can be accessed through game.clock.
	Time is advanced by a timer that is tied to the current map. If no map is loaded or if
	the map is suspended, then the time does not advance. Whenever changing maps, the time
	remaining on the timer is saved by this script, and when the next map is loaded, a new
	timer is started from that time.
	
	Loading this script automatically assigns the functions to stop and restart the timers
	to the sol.map metatable (on_started() and on_finished(), registered as multi-events).
	
	At the start of every in-game minute, a check is done with the event manager to see if
	there are any events to begin (e.g. to move NPCs around or darken the map at night).
	
	The game.clock:set_time(time) function can be used to skip ahead in time but not to go
	backwards in time. It will trigger a fade in/fade out animation, after which, the hero
	will still be at the same location on the same map, and the positions of all NPCs will
	have been updated in accordance with the current time.
	
	Note that while times are stored internally where 0=6AM and 23=5AM, the hour is always
	interpreted as 0=12AM and 23=11PM whenever it is used as a function argument or return
	value. The day gets incremented at 6AM.
	
	When loading a saved game, the time resumes from the exact time of the last save. NPCs
	will also be moved around in accordance with the current map and time.
]]

local game_clock = {}
local current_game --update game reference each time new game started

--// Call once at the creation of a new game
function game_clock:initialize(game)
	require"scripts/game_events":initialize(game)
	
	--constants
	local TICKS = 500 --in ms; length of 1 in-game minute
	--TODO allow speed-up/slow-down of time
	
	local game_day
	local game_hour
	local game_minute
	local game_ticks
	
	local clock_timer --counts amount of time until next in-game minute interval
	
	game.clock = {}
	current_game = game
	
	
	--// initialize time
	do
		local initial_time = game.starting_time or {} --convenience
		
		local hour = math.min(math.max(math.floor(tonumber(initial_time.hour) or 0), 0), 23) --format 0=12AM
		local full_minute = tonumber(initial_time.minute) or 0 --includes ticks as decimal value
		
		game_day = math.max(math.floor(tonumber(initial_time.day) or 1), 0)
		game_hour =  (hour - 6) % 24
		game_minute = math.min(math.max(math.floor(full_minute), 0), 59)
		game_ticks = math.min(math.max(math.floor((full_minute - game_minute)*TICKS), 0), TICKS)
		
		game.starting_time = nil --no longer needed
	end
	
	
	--// Returns the current time
		--ret1 (number): The current day (starting from day 1)
		--ret2 (number): The current hour, 0-23 where 0=12AM and 23=11PM
		--ret3 (number): The current minute, 0-23. Includes decimal value.
	function game.clock:get_time()
		local day = game_day
		local hr = game_hour
		local min = game_minute
		local ticks = clock_timer and TICKS - clock_timer:get_remaining_time() or game_ticks
	
		--account for overflow
		if ticks >= TICKS then
			ticks = ticks - TICKS
			min = min + 1
		
			if min >= 60 then
				min = min - 60
				hr = hr + 1
			
				if hr >=24 then
					hr = hr - 24
					day = day + 1
				end
			end
		end
	
		hr = (hr + 6) % 24
	
		return day, hr, min + ticks/TICKS
	end
	
	
	--// Returns the current time
		--ret1 (string): "HH:MM" where HH is the hour 0-23 and MM is the minute 0-59
	function game.clock:get_time_str()
		local _,hr,min = self:get_time()
		min = math.floor(min)
	
		return string.format("%02d:%02d", hr, min)
	end
	
	
	--// Converts the specified time to number as total number of ticks
	--// Allows comparing two times as numbers to see which is earlier
		--arg1 time (table or nil): time to convert to number; has keys of day, hour, minute and ticks
			--uses current time if not specified
		--ret1 (number): will be a positive integer
	function game.clock:get_time_val(time)
		assert(not time or type(time)=="table", "Bad argument #1 to 'get_time_val' (nil or table expected, got "..type(time)..")")
		
		--use current time by default
		if not time then
			time = {
				day = game_day,
				hour = game_hour,
				minute = game_minute,
				ticks = game_ticks,
			}
		end
		
		local day = math.floor(math.max(tonumber(time.day) or 0, 0))
		local hour = math.floor(math.max(tonumber(time.hour) or 0, 0))
		local minute = math.floor(math.max(tonumber(time.minute) or 0, 0))
		local ticks = math.floor(math.max(tonumber(time.ticks) or 0, 0))
		
		return ((day*24 + hour)*60 + minute)*TICKS + ticks
	end
	
	--// Returns just the current hour (0-23 where 0=12AM and 23=11PM)
		--arg1 is_decimal (boolean, default false): if true then returns the decimal part of the hour, false returns an integer
		--ret1 (number): The current hour
	function game.clock:get_hour(is_decimal)
		local _,hr,min = self:get_time()
		
		if is_decimal then
			return hr + math.min(min/60,1)
		else return hr end
	end
	
	
	--// Returns the next time matching the given time criteria; cannot go backward to an earlier time
	--// Does not actually advance the clock time; do that by passing the returned time to game.clock:set_time()
		--arg1 time (number, string or table):
			--(number, positive): the hour (0-24) to advance the time to if positive; non-integer decimal values ignored
				--e.g. current_time=={day=1, hour=5} and time==6 returns {day=1, hour=6}
				--e.g. current_time=={day=1, hour=7} and time==6 returns {day=2, hour=6}
			--(number, negative): returns time equal to abs(time) hours later, to nearest hour and zero minutes; decimal part of non-integer values ignored
				--e.g. current time is 8:58 and time == -1 then returns 9:00; time == -2 returns 10:00; time == -48 returns time 2 days later
			--(string): hour and minute in the form HH:MM where HH is 0-24 and MM is 0-60; non-integer values allowed for MM
			--(table): table with any combination of keys for day (positive integer), hour (0-24), minute (0-60) and ticks (0-500)
				--if all keys present then returned time is identical (unless time is in past, in which case specified day is ignored)
		--ret1 (table): next matching time as table where keys are day, hour (0-23), minute (0-59) and ticks (0-499)
	function game.clock:next_time(time)
		local num = tonumber(time)
		local time_type = type(time)
	
		--Convert value specified for time to table form
		local new_time --table format
		if num then
			local hour = math.floor(num) --negative numbers get rounded to greater magnitude
			if hour==24 then hour = 0 end
		
			if hour>=0 then --set to specified hour
				assert(hour<24, "Bad argument #1 to 'set_time' (number must be less than 24)")
				hour = (hour - 6) % 24 --convert to internal hour format where 0 = 6AM
			
				new_time = {
					hour = hour,
					minute = 0,
					ticks = 0,
				}
			else --advance by number of hours
				hour = math.floor(game_hour - hour) --subtract negative number, so really adding
			
				local num_days = math.floor(hour/24)
				hour = hour % 24
			
				new_time = {
					day = game_day + num_days,
					hour = hour,
					minute = 0,
					ticks = 0,
				}
			end
		elseif time_type=="string" then
			local hour,min = time:match"^(%d+):(.+)"
			hour = tonumber(hour)
			min = tonumber(min)
			assert(hour and min, "Bad argument #1 to 'set_time' (string must be of format 'HH:MM')")
		
			if hour==24 then hour = 0 end
			if min==60 then min = 0 end
			assert(hour>=0, hour<24, "Bad argument #1 to 'set_time' (string must be of format 'HH:MM' where HH (hour) is 0-23")
			assert(min>=0 and min<60, "Bad argument #1 to 'set_time' (string must be of format 'HH:MM' where MM (minute) is 0-60")
		
			hour = (hour - 6) % 24 --convert to internal hour format where 0 = 6AM
			local minute = math.floor(min)
			local ticks = math.floor((min-minute)*TICKS)
		
			new_time = {
				hour = hour,
				minute = minute,
				ticks = ticks,
			}
		elseif time_type=="table" then --validate table entries only
			local day = tonumber(time.day)
			local hour = tonumber(time.hour)
			local min = tonumber(time.minute)
			local ticks = tonumber(time.ticks)
			assert(day or hour or minute or ticks, "Bad argument #1 to 'set_time' (table must contain value for keys 'day', 'hour' or 'minute')")
		
			if day then
				day = math.floor(day)
				assert(day>=1, "Bad argument #1 to 'set_time' (table value for key 'day' must be positive)")
				if day <= game_day then day = nil end --ignore day if not a future day
			end
		
			if hour then
				hour = math.floor(hour)
				if hour==24 then hour = 0 end
				assert(hour>=0 and hour<24, "Bad argument #1 to 'set_time' (table value for key 'hour' must be 0-23")
				hour = (hour - 6) % 24 --convert to internal hour format where 0 = 6AM
			end
		
			if ticks then
				ticks = math.floor(ticks)
				if ticks<0 or ticks>=TICKS then ticks = 0 end --force ticks to valid value (no error msg)
			end
		
			if min then
				if min==60 then min = 0 end
				assert(min>=0 and min<60, "Bad argument #1 to 'set_time' (table value for key 'minute' must be 0-60")
				local minute = math.floor(min)
				if not ticks then --use decimal part of minute for ticks
					ticks = math.floor((min-minute)*TICKS)
				end --otherwise decimal part ignored if ticks specified
			end
		
			new_time = {
				day = day,
				hour = hour,
				minute = min,
				ticks = ticks,
			}
		else error("Bad argument #1 to 'set_time' (number or string or table expected, got "..time_type..")", 0) end
	
		--if day not specified then use today (tentatively)
		if not new_time.day then --NOTE: if day is specified then it is at least tomorrow
			new_time.day = game_day
		end
	
		--Determine if need to advance to next day
		if new_time.day == game_day then
			--NOTE: new_time.ticks guaranteed to be less than TICKS
			--NOTE: new_time.minute guaranteed to be less than 60
			--NOTE: new_time.hour guaranteed to be less than 24
		
			if new_time.hour < game_hour then
				new_time.day = new_time.day+1
			elseif new_time.hour == game_hour then
				if new_time.minute < game_minute then
					new_time.day = new_time.day+1
				elseif new_time.minute == game_minute then
					if new_time.ticks < game_ticks then
						new_time.day = new_time.day+1
					elseif new_time.ticks == game_ticks then
						return false --set time is current time; do not change time
					end
				end
			end
		end
		
		return new_time
	end
	
	--// Sets game time to specified value (moves time forward only) and includes fade in/out
		--arg1	(pos number):	Advances to that hour (0-23); day increments as necessary
		--		(neg number):	Advances forward the specified number of hours (on the hour)
		--						if current time is 9:38, then time==-1 advances to 10:00, time==-2 to 11:00, etc
		--		(string):		Advances forward to the specified time (HH:MM), where HH is 0-23 and MM is 0-60
		--		(table):		Advances forward to specified time: {day=num1, hour=num2, minute=num3}
		--						where day is positive integer >= current day, hour=0-23, minute=0-59 (decimal values allowed)
		--ret1	(number):		Returns the new hour or false if time did not change
	function game.clock:set_time(time)
		local new_time = self:next_time(time)
		
		--Abort existing clock timer if running
		if clock_timer then
			clock_timer:stop()
			clock_timer = nil
		end
	
		--set new time
		game_day = new_time.day
		game_hour = new_time.hour
		game_minute = new_time.minute
		game_ticks = new_time.ticks

		--restart map (fade in/out)
		local map = game:get_map()
		if map then
			local map_id = map:get_id()
			local hero = game:get_hero()
			if hero then hero:teleport(map_id, "_same", "fade") end
			
			--reinitialize map in middle of fade out transition while screen is dark
			sol.timer.start(game, 600, function()
				--reinitialize map
				game.events:load_map_events()
				game.clock:run(game:get_map())
			end)
			
			--NOTE: clock timer will restart at map:on_started()
		end
	end
	
	
	--// Advances to next in-game minute
		--arg1 is_new_timer (boolean, default true): if non-false then restart timer until next minute
		--ret1 (boolean): returns true if new timer started
	function game.clock:increment()
		--advance time to next minute
		game_ticks = 0
		game_minute = game_minute + 1
	
		--account for overflow
		if game_minute >= 60 then
			game_minute = 0
			game_hour = game_hour + 1
		
			if game_hour >=24 then
				game_hour = 0
				game_day = game_day + 1
			end
		end
	
		--check if event triggered
		local time_str = string.format("%02d:%02d", (game_hour + 6) % 24, game_minute) --NOTE: don't use self:get_time_str() because want to ignore time left on clock_timer
		game.events:new_time(time_str)
		
		return true --repeat timer until map closed (or don't repeat timer if is_new_timer is false)
	end
	
	
	--// Called automatically during map:on_started() to resume timer
	function game.clock:run(map)
		--stop timer if exists
		if clock_timer then
			clock_timer:stop()
			clock_timer = nil
		end
		
		local delay = TICKS - game_ticks --delay for timer until next in-game minute
		
		if delay <= 0 then --past due for advancing to next in-game minute
			delay = TICKS --use full in-game minute for new timer
			self:increment() --advance to next in-game minute without starting timer
		end
	
		clock_timer = sol.timer.start(map, delay, function()
			self:increment() --increment without starting new timer
			clock_timer = sol.timer.start(map, TICKS, self.increment) --start repeating timer with full delay
		end)
	end
	

	--// Called automatically during map:on_finished() to suspend timer
	function game.clock:suspend()
		local ticks_remaining --remaining time on currently active timer
		if clock_timer then
			--preserve remaining time on timer then abort it
			ticks_remaining = clock_timer:get_remaining_time()
			clock_timer:stop()
			clock_timer = nil
			
			if ticks_remaining <= 0 then --past due for advancing to next minute
				self:increment() --advance to next minute without starting timer
				ticks_remaining = nil --don't need to preserve remaining time from previous timer
			end
		end
	
		game_ticks = ticks_remaining and math.min(TICKS - ticks_remaining, TICKS) or 0
	end

	--// Returns true if clock_timer is running; else returns false
	function game.clock:is_running()
		return not not clock_timer
	end
end


--// Register events to map metatable to automatically start and stop timer on loading
	
local map_meta = sol.main.get_metatable"map"
map_meta:register_event("on_started", function(self, ...)
	if current_game then
		current_game.events:load_map_events()
		current_game.clock:run(self)
	end
end)

map_meta:register_event("on_finished", function(self, ...)
	if current_game then current_game.clock:suspend() end
end)


setmetatable(game_clock, {__call = game_clock.initialize}) --convenience

return game_clock


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
