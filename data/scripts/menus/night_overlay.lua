--[[ night_overlay.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script draws a shadow overlay on top of the map camera to darken the image and to
	create a night-time effect by overlaying two surfaces (one darkens and the other masks
	out the light sources).
	
	The bottom surface is filled with a color (darkens the screen using the multiply blend
	mode). The top surface contains image masks for any light sources, where a white image
	is used (original map image is unaltered by opaque, pure white pixels) and where fully
	transparent pixels are darkened the most. If non-white colors are used, then the light
	will be tinted by the inverse of that color.
	
	The script also manages playing of different music during the day and at night for the
	active map. The map script must define a map.music table with keys day and night, with
	string values giving the music_id to be used for each. It works best to have the music
	property of the map data file set to "same" for maps using this feature.
]]


local night_overlay = {} --menu that manages night-time overlay

--TODO only update lights when hero changes position or frame timer expires
--only want to register event once; do it when starting new game?
--multi_events:enable(hero)
--hero:register_event("on_position_changed", function(x, y, layer)
	--TODO needs_refresh = true
--end)

local overlays, light_sources = unpack(require"scripts/menus/night_overlay.dat" or {})

local map --linked sol.map
local game --needed to check savegame variables

local frame_timer --250ms timer to advance animation frames
local frame_num --current frame: 1-4

local shadow_surface --multiply layer to darken map at night
local overlay_surface --additive layer to draw light masks where map doesn't get darkened
local light_set --name of light sprites to use at the present time (changes on :update())
local is_lights --(boolean) true if lights are on (draws flame in braziers)
local light_count = 0 --number of active lights that augment ambient light levels


local light_masks = {dim={}, bright={}} --dim mask during twilight has smaller radius; bright mask is brighter with larger radius
for i=1,3 do --use repeating sequence 1,2,3,2...
	table.insert(light_masks.dim, sol.surface.create("masks/lamp_96."..i..".png"))
	table.insert(light_masks.bright, sol.surface.create("masks/lamp_176."..i..".png"))
end
--repeat number 2 for 4th index
table.insert(light_masks.dim, sol.surface.create("masks/lamp_96.2.png"))
table.insert(light_masks.bright, sol.surface.create("masks/lamp_176.2.png"))


--// Called every 250ms by frame_timer; advances frame
local function frame_adv()
	frame_num = frame_num + 1
	if frame_num > 4 then frame_num = 1 end
	
	return true --repeat timer
end


function night_overlay:on_started()
end


--// Called whenever a map loads; saves a reference to the current map and starts a timer
--// to animate the light source sprites
	--arg1 new_map (sol.map): the new map that is now active
	--arg2 time_str (string): current time, formatted as "hh:mm"
function night_overlay:initialize(new_map, time_str)
	map = new_map --update to current map
	game = map:get_game() --update to current game
	frame_num = 1 --restart at 1
	
	--stop and restart frame_timer
	if frame_timer then frame_timer:stop() end
	frame_timer = sol.timer.start(map, 250, frame_adv)
	frame_timer:set_suspended_with_map(false) --don't stop timer when paused
	
	shadow_surface = sol.surface.create(map:get_size()) --TODO only create once and match camera size (only drawing lights visible on-screen on top)
	shadow_surface:set_blend_mode"none"
	
	overlay_surface = sol.surface.create(map:get_size())
	overlay_surface:set_blend_mode"multiply"
	
	--TODO create mask around edge of map (if applicable) to block light
	
	map:set_lights_enabled(is_lights)
	self:update(time_str)
end


--// Given two colors returns an intermediate color between the two
	--arg1 & arg2 (table): arrays of 3 or 4 RGBA values 0-255
	--arg3 (number, default 0): percent completion (0 to 1) in transition from first color to second
	--arg4 (string, default "none"): type of transition to use
		--valid values are "smooth" or "none"
local function calc_color(color_prev, color_next, percent, transition)
	percent = tonumber(percent) or 0 --force to valid value
	
	--for certain conditions may not need to use overlay (return false)
	if not color_prev then
		if not transition or transition=="none" or percent==0 then return false end --don't use overlay
	elseif not color_next and percent==1 then return false end --shouldn't be possible
	
	color_prev = color_prev or {}
	color_next = color_next or {}
	local default_color = {255, 255, 255, 255} --same as no overlay
	
	--force color1 and color2 to be valid values
	local color1 = {}
	local color2 = {}
	for i=1,4 do
		table.insert(color1, math.min(math.max(math.floor(tonumber(color_prev[i]) or default_color[i]), 0), 255))
		table.insert(color2, math.min(math.max(math.floor(tonumber(color_next[i]) or default_color[i]), 0), 255))
	end
	
	--calculate new color between color1 and color2 (algorithm depends on value of transition)
	--the color to use is stored in color1
	if transition=="smooth" then --gradual and uniform transition from first to second
		local p2 = math.min(math.max(tonumber(percent) or 0, 0), 1)
		local p1 = 1 - p2
		
		for i=1,4 do
			color1[i] = math.min(math.floor(p1*color1[i] + p2*color2[i]), 255)
		end
	else color1 = percent==1 and color2 or color1 end --no transition (=="none")
	
	return color1
end


--// Given two colors returns an intermediate color between the two
	--arg1 (number, default 0): percent completion (0 to 1) in transition from first light to second
	--arg2 (string, default "none"): type of transition to use
		--valid values are "fade" or "none"
local function calc_lights(percent, transition)
	percent = tonumber(percent) or 0 --force to valid value
	
	local opacity1,opacity2
	
	if transition=="fade" then --gradual decrease in opacity of sprite
		opacity2 = math.min(math.max(tonumber(percent)*255 or 0, 0), 255)
		opacity1 = 255 - opacity2
	else
		opacity1 = percent<1 and 255 or 0
		opacity2 = 255 - opacity1
	end
	
	return {opacity1, opacity2}
end


--// Called every in-game minute to set the overlay hue and update light sources
	--arg1 time_str (string): current time, formatted as "hh:mm"
function night_overlay:update(time_str)
	assert(type(time_str)=="string", "Bad argument #1 to 'update' (string expected, got "..type(time_str)..")")
	assert(shadow_surface, "Need to call 'initiailize' before calling 'update'")
	
	--convert time as string to numeric value
	local hr,min = time_str:match"^(%d+):(%d+)"
	local current_minutes = 60*tonumber(hr or 0) + tonumber(min or 0) --time expressed only in minutes for comparing purposes
	
	--// Calculate color and lights for overlay
	
	local color
	local music
	local light_info = {night={}, always={}} --determines which set of sprites to use for light sources
	local prev_is_lights = is_lights --value of what is_lights started at
	
	local map_overlays = overlays[map.lighting] or {} --set of overlays to use for this map
	local start_time, start_time_min
	if #map_overlays >= 1 then
		--iterate thru overlays to find which two surround current time
		local prev_entry,prev_time
		local next_entry,next_time
		for _,entry in ipairs(map_overlays) do
			--convert start time string to number (hours with decimal)
			start_time = entry.start_time
			hr,min = start_time:match"^(%d+):(%d+)"
			start_time_min = 60*tonumber(hr or 0) + tonumber(min or 0)
			
			--determine whether the current entry is before/including or after now
			if current_minutes >= start_time_min then
				prev_entry = entry
				prev_time = start_time_min
			else
				next_entry = entry
				next_time = start_time_min
				break --stop checking; went past current time
			end
		end
		
		--if only one adjacent entry found, use it; otherwise calc transition between the two
		if prev_entry then
			if next_entry then --calculate transition between prev and next entry
				local delta_min = next_time - prev_time
				local percent = (current_minutes - prev_time)/delta_min --percent complete in transition from prev to next
				
				color = calc_color(prev_entry.color, next_entry.color, percent, prev_entry.transition)
				
				music = prev_entry.music
				
				local opacity = calc_lights(percent, prev_entry.lights_transition)
				light_info.night = {
					{set=prev_entry.lights, opacity=opacity[1] or 255},
					{set=next_entry.lights, opacity=opacity[2] or 255},
				}
				light_info.always = { --these lights are always on
					{set=prev_entry.lights or "dim", opacity=255},
					{set=next_entry.lights or "dim", opacity=255},
				}
				if light_info.always[1].set~=light_info.always[2].set then
					light_info.always[1].opacity = opacity[1] or 255
					light_info.always[2].opacity = opacity[2] or 255
				end
				
				if percent<1 then
					is_lights = prev_entry.lights
				else is_lights = next_entry.lights end
			else --if no next entry then use prev_entry as the entry
				color = prev_entry.color
				music = prev_entry.music
				light_info.always = {{set=prev_entry.lights or "dim", opacity=255}} --these lights are always on
				light_info.night = {{set=prev_entry.lights, opacity=255}}
				is_lights = prev_entry.lights
			end
		elseif next_entry then --if no previous entry then use next_entry as the entry
			color = next_entry.color
			music = next_entry.music
			light_info.always = {{set=next_entry.lights or "dim", opacity=255}} --these lights are always on
			light_info.night = {{set=next_entry.lights, opacity=255}}
			is_lights = next_entry.lights
		else return end --could not find any overlays in table
	else --only one overlays entry
		color = map_overlays.color
		music = map_overlays.music
		light_info.always = {{set=map_overlays.lights or "dim", opacity=255}} --these lights are always on
		light_info.night = {{set=map_overlays.lights, opacity=255}}
		is_lights = map_overlays.lights
	end
	
	--// count light sources and increase ambient lighting proportionally
	
	--toggle dynamic tiles if lights need to be turned on/off
	if map and not is_lights ~= not prev_is_lights then --lights turned on or off
		map:set_lights_enabled(is_lights)
	end
	
	light_count = 0
	for prefix,info in pairs(light_sources) do
		if info.is_ambient then --light source increases ambient levels
			--count number of light sources of this type present in map
			for entity in map:get_entities(prefix) do
				if entity:is_enabled() then
					light_count = light_count + 1
				end
			end
		end
	end
	
	--increase ambient levels proportionally to number of active lights
	local color_new = {} --color table modified with increased ambient levels
	if color then --skip if color set to false (defaults to 255, 255, 255)
		for i=1,4 do
			if color[i] then
				table.insert(color_new, math.min(color[i] + light_count*40, 255))
			else break end --don't do anything if empty table (or stop if alpha value not given)
		end
		
		if color_new[1]==255 and color_new[2]==255 and color_new[3]==255 or not color[1] then
			color = false
		else color = color_new end
	end
	
	--// redraw surfaces
	
	shadow_surface:fill_color(color or {255, 255, 255})
	light_set = light_info --update with light info corresponding to current time
	
	--// update music
	
	if music and map.music then
		if type(map.music)=="string" then
			sol.audio.play_music(map.music)
		elseif type(map.music)=="table" and map.music[music] then
			sol.audio.play_music(map.music[music])
		end
	end
end


--// Draws the overlay
function night_overlay:on_draw(dst_surface)
	if map and shadow_surface then
		local camera = map:get_camera()
		local offset_x,offset_y = camera:get_position()
		local lights = {night={}, always={}}
		
		shadow_surface:draw(overlay_surface) --clears old overlay_surface
		
		local info = {} --temporary table used in for loop
		for k,v in pairs(lights) do
			local set = light_set[k]
			if set[1] and set[1].set then
				info = {} --table for light1 values
				info.mask = light_masks[ set[1].set ][frame_num]
				info.opacity = set[1].opacity or 255
				info.width, info.height = info.mask:get_size()
				table.insert(v, info)
			end
			
			if set[2] and set[2].set then
				info = {} --table for light2 values
				info.mask = light_masks[ set[2].set ] --may be nil
				info.mask = info.mask and info.mask[frame_num]
				info.opacity = set[2].opacity or 255
				info.width, info.height = 0,0
				if info.mask then info.width, info.height = info.mask:get_size() end
				table.insert(v, info)
			end
		end
			
		local x,y,w,h --entity position
		for prefix,info in pairs(light_sources) do
			if not info.save_val or (type(info.save_val)=="string" and game:get_value(info.save_val)) then
				local set = lights[info.active or "night"] or {}
				if set[1] and set[1].mask then
					set[1].mask:set_opacity(set[1].opacity)
					if set[2] and set[2].mask and set[2].mask ~= set[1].mask then set[2].mask:set_opacity(set[2].opacity) end
				elseif set[2] and set[2].mask then set[2].mask:set_opacity(set[2].opacity) end
				
				for entity in map:get_entities(prefix) do
					if entity:is_enabled() then
						x,y = entity:get_position()
						
						w,h = entity:get_size()
						if entity:get_type()~="dynamic_tile" then w,h = 0,0 end --use origin if not dynamic tile, otherwise use center
						
						if set[1] and set[1].mask then
							set[1].mask:draw(overlay_surface, x+(w-set[1].width)/2-offset_x, y+(w-set[1].height)/2-offset_y)
						end
						
						if set[2] and set[2].mask then
							set[2].mask:draw(overlay_surface, x+(w-set[2].width)/2-offset_x, y+(w-set[2].height)/2-offset_y)
						end
					end
				end
			end
		end
		
		overlay_surface:draw(dst_surface)
	end
end


--// Swaps out dynamic tiles with prefix "brazier_off" with "brazier_on" when lights toggle
	--arg1 enabled (boolean, default true): true = use lights on sprite(s); false = use lights off sprite(s)
local map_meta = sol.main.get_metatable"map"
function map_meta:set_lights_enabled(enabled)
	enabled = enabled~=false --force to boolean
	
	if self:has_entities"brazier_" then --don't bother if no entries beginning with "brazier_"
		for entity in self:get_entities"brazier_on" do
			entity:set_enabled(enabled)
		end
	
		for entity in self:get_entities"brazier_off" do
			entity:set_enabled(not enabled)
		end
	end
end

return night_overlay


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
