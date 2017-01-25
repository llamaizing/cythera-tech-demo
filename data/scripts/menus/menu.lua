--[[ conversation_dialog.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script processes menu keyboard/mouse events, passing them on to its subcomponents
	that define an event with the same name. It also handles the drawing of the menu along
	with its visible subcomponents.
	
	Every menu must include self.menu_surface (sol.surface), the surface on which the menu
	is drawn. self.get_position() should return the x and y coordinates for the upper-left
	corner of the menu. Any controls used by the menu needing to process mouse or keyboard
	events should be linked to the menu by using self:add_control(), where the coordinates
	for the position of the control are specified relative to the upper-left corner of the
	menu.
]]

local menu_manager = {}

function menu_manager:create(menu)
	local menu = menu or {}
	
	menu.controls = {}
	menu.active_control = nil --index --TODO better name
	
	
	----------------------
	-- EVENT PROCESSING --
	----------------------
	
	--send mouse/keyboard events to all controls assigned to menu
	local mouse_events = {
		on_mouse_pressed = true,
		on_mouse_released = true,
	}
	for event,_ in pairs(mouse_events) do
		menu[event] = function(self, button, x, y, ...)
			local ret = false --value to return
			
			local box_x,box_y,box_width,box_height = 0, 0, sol.video.get_quest_size() --assume fills entire window
			if self.get_bounding_box then box_x,box_y,box_width,box_height = self:get_bounding_box() end
			
			if x>=box_x and x<=box_x + box_width and y>=box_y and y<=box_y + box_height then --clicked inside menu
				--redefine mouse coordinates relative to menu upper-left corner
				local x = x - box_x
				local y = y - box_y
		
				for i,control_info in ipairs(self.controls or {}) do
					local control, ctrl_x, ctrl_y = unpack(control_info)
					local ctrl_width, ctrl_height
				
					if control.get_size then
						ctrl_width, ctrl_height = control:get_size()
				
						if control[event] then
							if x>=ctrl_x and x<=ctrl_x + ctrl_width and y>=ctrl_y and y<=ctrl_y + ctrl_height then
								if control[event](control, button, x-ctrl_x, y-ctrl_y, ...) then
									if event=="on_mouse_pressed" then return true end
									ret = true --event=="on_mouse_released", want to return true at very end
								end
							elseif event=="on_mouse_released" then --send on_mouse_released to all controls even if outside bounds
								control[event](control, button, nil, nil, ...) --x & y are nil because outside control bounds
							end
						end
					end
				end
			elseif event=="on_mouse_released" then --send on_mouse_released to all controls even if outside bounds
				for i,control_info in ipairs(self.controls or {}) do
					local control = unpack(control_info)
				
					if control[event] then
						control[event](control, button, nil, nil, ...) --x & y are nil because outside control bounds
					end
				end
			end
			
			return ret
		end
	end
	
	--TODO send only to active control?
	local keyboard_events = {
		on_character_pressed = true,
		on_key_pressed = true,
	}
	for event,_ in pairs(keyboard_events) do
		menu[event] = function(self, ...)
			for i,control_info in ipairs(self.controls or {}) do
				local control = control_info[1]
				if control[event] and control[event](control, ...) then break end
			end
		end
	end
	
	
	--------------------
	-- IMPLEMENTATION --
	--------------------
	
	--// Adds control to this menu's list of controls. Controls are drawn in the order in
	--// which they get added to this list. Menu Mouse/keyboard events are automatically
	--// sent to the controls in this list as appropriate.
		--arg1 control (table): control to add
		--arg2 x (number, default 0): X coordinate of where to draw the control in the menu
		--arg3 x (number, default 0): Y coordinate of where to draw the control in the menu
	function menu:add_control(control, x, y)
		if not self.controls[control] then --prevent adding same control more than once
			x = math.floor(tonumber(x) or 0)
			y = math.floor(tonumber(y) or 0)
			
			--add control to list of controls
			table.insert(self.controls, {control, x, y})
			self.controls[control] = #self.controls
			
			if control.set_origin then control:set_origin(x,y) end --preserve origin coordinates
			if control.set_menu then control:set_menu(self) end --link menu to control
			
			--make new control the active control if its the first one added
			if not self.active_control then self.active_control = #self.controls end
		
			return true
		end
	
		return false
	end
	
	
	--// Sets the active control to the next one in the list
	function menu:next_control()
		if not self.active_control then return false end
	
		self.active_control = self.active_control + 1
		if not self.controls[self.active_control] then
			self.active_control = 1
		end
	
		return self.controls[self.active_control] and self.controls[self.active_control][1]
	end
	
	
	--// Returns the active control for this menu
	function menu:get_active_control()
		return self.controls[self.active_control] and self.controls[self.active_control][1]
	end
	
	
	--// Draws this menu's controls on menu_surface
	function menu:on_draw(dst_surface)
		if not self.menu_surface then return end
		self.menu_surface:clear()
	
		local offset_x,offset_y = 0, 0
		if self.get_position then offset_x,offset_y = self:get_position() end
	
		for _,control_info in ipairs(self.controls or {}) do
			local control, x, y = unpack(control_info)
		
			local is_visible = true --default true if omitted
			if control.is_visible then --function is defined
				is_visible = control.is_visible()
			end
		
			if is_visible and control.draw then
				control:draw(self.menu_surface, offset_x+x, offset_y+y)
			end
		end
	
		self.menu_surface:draw(dst_surface)
	end

	return menu
end

setmetatable(menu_manager, {__call = menu_manager.create}) --convenience

return menu_manager


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
