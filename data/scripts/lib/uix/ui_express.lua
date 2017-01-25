--[[ ui_express.lua
	version 1.0
	1/24/2017
	GNU General Public License Version 3
	author: Llamazing
	
	   __   __   __   __  _____   _____________  _______
	  / /  / /  /  | /  |/  /  | /__   /_  _/  |/ / ___/
	 / /__/ /__/ & |/ , ,  / & | ,:',:'_/ // /|  / /, /
	/____/____/_/|_/_/|/|_/_/|_|_____/____/_/ |_/____/
	
	This script manages multiple user interface controls, automatically loading all of the
	scripts needed for the various controls, providing a common interface.
]]

local uix = {}

local PATH = "scripts/lib/uix/controls/" --directory with scripts for each control

local controls = { --control name matches script name
	"button",
	"draw_view",
	"frame",
	"image_view",
	"multiline",
	"text_prompt",
	"text_label",
	"journal_viewer",
	"log_viewer",
	"slider",
	
	--compound controls
	"scrollbar",
	"incrementer",
}
for i,v in ipairs(controls) do controls[v] = i end --add lookup

--for convenience can create control from style name --TODO add more control styles
--uix.button{height=16,width=128,type="textbutton"} is equivalent to uix.textbutton{height=16,width=128}
local control_styles = {
	button = {
		"textbutton",
		"logbutton",
		"togglebutton",
		"radiobutton",
	},
	frame = {
		"dialogframe",
		"textframe",
		"mapframe",
	},
}

--// Function to create new instance of any control; embed within all instances
local function create_control(control, properties)
	assert(type(control)=="string", "Bad argument #1 to 'uix' (string expected, got "..type(control)..")")
	assert(controls[control], "Bad argument #1 to 'uix' (not a valid control name)")
	
	return uix[control](properties)
end

--// load control scripts
for _,control in ipairs(controls) do
	local script = require(PATH..control) or {}
	script.uix = create_control
	uix[control] = function(properties)
		return script.create and script.create(properties)
	end
end

--// create methods for control styles
for control,styles in pairs(control_styles) do
	for _,control_style in ipairs(styles) do
		uix[control_style] = function(properties)
			properties = properties or {}
			properties.type = control_style
			
			return uix[control].create(properties)
		end
	end
end

return uix


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
