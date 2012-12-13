local class = select(2, UnitClass("player"))
if class ~= "PRIEST" then return end -- Only for priests

local ADDON_NAME, Engine = ...
local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI
local ClassMonitor_ConfigUI = ClassMonitor_ConfigUI

if not ClassMonitor_ConfigUI then return end

local pluginName = "HALO"
local Helpers = ClassMonitor_ConfigUI.Helpers

local unitValues = {
	["target"] = "Target",
	["focus"] = "Focus",
}
local function GetUnitValues()
	return unitValues
end

local colors = Helpers.CreateColorsDefinition("colors", 3, {"Far", "Near", "Cursor"})
local options = {
	[1] = Helpers.Description,
	[2] = Helpers.Name,
	[3] = Helpers.DisplayName,
	[4] = Helpers.Kind,
	[5] = Helpers.Enabled,
	[6] = Helpers.WidthAndHeight,
	[7] = {
		key = "unit",
		name = "Unit",
		desc = "Unit to monitor",
		type = "select",
		values = GetUnitValues,
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled
	},
	[8] = {
		key = "checkraid",
		name = "Raid check",
		desc = "Check raid health within halo radius to optimize healing",
		type = "toggle",
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = true,
	},
	[9] = {
		key = "showcdup",
		name = "Only if CD up",
		desc = "Display bar only when CD is up",
		type = "toggle",
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled,
	},
	[10] = {
		key = "directiontext",
		name = "Direction text",
		desc = "Display direction text",
		type = "toggle",
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled,
	},
	[11] = {
		key = "displaycursor",
		name = "Cursor",
		desc = "Display cursor",
		type = "toggle",
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled,
	},
	[12] = {
		key = "gradient",
		name = "Gradient",
		desc = "Display gradient instead of plain color",
		type = "toggle",
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled,
	},
	[13] = {
		key = "cursorsize",
		name = "Cursor width",
		desc = "Change cursor width",
		type = "range",
		min = 1, max = 10, step = 1,
		get = Helpers.GetValue,
		set = Helpers.SetValue,
		disabled = Helpers.IsPluginDisabled,
	},
	[14] = colors,
	[15] = Helpers.Anchor,
	[16] = Helpers.AutoGridAnchor,
}

local short = "Halo"
local long = "Get the best of priest talent Halo aka HaloReallyPro"
ClassMonitor_ConfigUI:NewPluginDefinition(pluginName, options, short, long) -- add plugin definition in ClassMonitor_ConfigUI