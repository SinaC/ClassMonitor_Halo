local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI

if UI.MyClass ~= "PRIEST" then return end -- Only for druid

local ClassMonitor_ConfigUI = ClassMonitor_ConfigUI
local rc = LibStub("LibRangeCheck-2.0")

-- rc.RegisterCallback(frame, rc.CHECKERS_CHANGED, function() 
	-- -- NOP
-- end)

-- TODO: only if Halo talent learned

local pluginName = "HALO"
local haloPlugin = ClassMonitor:NewPlugin(pluginName)

-- Return value or default is value is nil
local function DefaultBoolean(value, default)
	if value == nil then
		return default
	else
		return value
	end
end

-- Plugin overwritten methods
function haloPlugin:Initialize()
	-- default settings
	self.settings.rangetext = DefaultBoolean(self.settings.rangetext, true)
	self.settings.unit = self.settings.unit or "target"
	self.settings.checkraid = false -- TODO: activate   DefaultBoolean(self.settings.checkraid, true)
	self.settings.colors = self.settings.colors or {
		[1] = {1, 0, 0, 1}, -- Far
		[2] = {0, 1, 0, 1}, -- Near
		[3] = {1, 1, 1, 1}, -- Cursor
	}
	self.settings.displaycursor = DefaultBoolean(self.settings.displaycursor, false)
	self.settings.gradient = DefaultBoolean(self.settings.gradient, true)
	self.settings.cursorsize = self.settings.cursorsize or 4
	--
	self.UnitRangesCache = {}
	--
	self:UpdateGraphics()
end

function haloPlugin:Enable()
	--
	if self.settings.unit == "target" then self:RegisterEvent("PLAYER_TARGET_CHANGED", haloPlugin.UpdateCacheKey) end
	if self.settings.unit == "focus" then self:RegisterEvent("PLAYER_FOCUS_CHANGED", haloPlugin.UpdateCacheKey) end
	if self.settings.checkraid == true then self:RegisterEvent("GROUP_ROSTER_UPDATE", haloPlugin.UpdateCacheKey) end
	--
	self:RegisterUpdate(haloPlugin.UpdateRanges)
	--
	self.bar:Show()
end

function haloPlugin:Disable()
	--
	self:UnregisterAllEvents()
	--
	self:UnregisterUpdate()
	--
	self.bar:Hide()
end

function haloPlugin:SettingsModified()
	--
	self.UnitRangesCache = {} -- empty cache
	--
	self:Disable()
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		--self.forceRefresh = true
		self:UpdateCacheKey() -- update cache
	end
end

-- Plugin own methods
function haloPlugin:UpdateGraphics()
	--
	local width = self:GetWidth()
	local height = self:GetHeight()
	local colorFarR, colorFarG, colorFarB = unpack(self.settings.colors[1])
	local colorNearR, colorNearG, colorNearB = unpack(self.settings.colors[2])
	local colorCursor = self.settings.colors[3]
	--
	local bar = self.bar
	if not bar then
		bar = CreateFrame("Frame", self.name, UI.PetBattleHider)
		bar:SetTemplate()
		bar:SetFrameStrata("BACKGROUND")
		bar:Hide()
		self.bar = bar
	end
	bar:ClearAllPoints()
	bar:Point(unpack(self:GetAnchor()))
	bar:Size(width, height)
	--
	if not bar.leftStatus then
		bar.leftStatus = CreateFrame("StatusBar", nil, bar)
		bar.leftStatus:SetStatusBarTexture(UI.NormTex)
	end
	bar.leftStatus:ClearAllPoints()
	bar.leftStatus:Point("TOPLEFT", bar, "TOPLEFT", UI.Border, -UI.Border)
	if self.settings.displaycursor == true then
		bar.leftStatus:Size(width-UI.Border*2-self.settings.cursorsize, height-UI.Border*2)
	else
		bar.leftStatus:Size(width-UI.Border*2, height-UI.Border*2)
	end
	--bar.leftStatus:SetStatusBarColor(1, 1, 0, 1)
	if self.settings.gradient then
		bar.leftStatus:GetStatusBarTexture():SetGradient("HORIZONTAL", colorFarR, colorFarG, colorFarB, colorNearR, colorNearG, colorNearB)
	end
	bar.leftStatus:SetMinMaxValues(0, 45)
	bar.leftStatus:SetValue(0)
	--
	if self.settings.displaycursor == true then
		if not bar.middleStatus then
			bar.middleStatus = CreateFrame("StatusBar", nil, bar)
			bar.middleStatus:SetStatusBarTexture(UI.NormTex)
		end
		bar.middleStatus:ClearAllPoints()
		bar.middleStatus:Point("LEFT", bar.leftStatus:GetStatusBarTexture(), "RIGHT", 0, 0) -- middle will move when left moves
		bar.middleStatus:Size(self.settings.cursorsize, bar.leftStatus:GetHeight())
		bar.middleStatus:SetStatusBarColor(unpack(colorCursor))
		bar.middleStatus:SetMinMaxValues(0, 1)
		bar.middleStatus:SetValue(0)
	end
	--
	if not bar.rightStatus then
		bar.rightStatus = CreateFrame("StatusBar", nil, bar)
		bar.rightStatus:SetStatusBarTexture(UI.NormTex)
	end
	bar.rightStatus:ClearAllPoints()
	if self.settings.displaycursor == true then
		bar.rightStatus:Point("LEFT", bar.middleStatus:GetStatusBarTexture(), "RIGHT", 0, 0) -- right will move when middle moves
		bar.rightStatus:Size(width-UI.Border*2-self.settings.cursorsize, height-UI.Border*2)
	else
		bar.rightStatus:Point("LEFT", bar.leftStatus:GetStatusBarTexture(), "RIGHT", 0, 0) -- right will move when middle moves
		bar.rightStatus:Size(width-UI.Border*2, height-UI.Border*2)
	end
	--bar.rightStatus:SetStatusBarColor(1, 0, 1, 1)
	if self.settings.gradient then
		bar.rightStatus:GetStatusBarTexture():SetGradient("HORIZONTAL", colorNearR, colorNearG, colorNearB, colorFarR, colorFarG, colorFarB)
	end
	bar.rightStatus:SetMinMaxValues(0, 45)
	bar.rightStatus:SetValue(0)
	--
	if self.settings.rangetext == true then
		if not bar.rangeText then
			bar.rangeText = UI.SetFontString(bar.leftStatus, 12)
			bar.rangeText:Point("CENTER", bar.leftStatus)
		end
		bar.rangeText:SetText("")
	end
end

function haloPlugin:UpdateCacheKey(event)
	if self.settings.unit == "target" and (not event or event == "PLAYER_TARGET_CHANGED") then
--print("UpdateCacheKey:TARGET:"..tostring(event))
		self.UnitRangesCache["target"] = self.UnitRangesCache["target"] or {} -- force cache refresh
	elseif self.settings.unit == "focus" and (not event or event == "PLAYER_FOCUS_CHANGED") then
--print("UpdateCacheKey:FOCUS:"..tostring(event))
		self.UnitRangesCache["focus"] = self.UnitRangesCache["focus"] or {} -- force cache refresh
	elseif self.settings.checkraid == true and (not event or event == "GROUP_ROSTER_UPDATE") then
		for i = 1, 40, 1 do
			-- TODO: party ?
			local unit = "raid"..tostring(i)
			if UnitInRaid(unit) then
				self.UnitRangesCache[unit] = self.UnitRangesCache[unit] or {} -- force cache refresh
			else
				self.UnitRangesCache[unit] = nil -- remove from cache
			end
		end
	end
end

function haloPlugin:UpdateRanges(elapsed)
	for unit, ranges in pairs(self.UnitRangesCache) do
		local minRange, maxRange = rc:GetRange(unit)
		if self.forceRefresh == true or minRange ~= ranges.minRange or maxRange ~= ranges.maxRange then
			-- update ranges
			ranges.minRange = minRange
			ranges.maxRange = maxRange
--print("UNIT:"..tostring(unit).."  RANGE:"..tostring(ranges.minRange).."=>"..tostring(ranges.maxRange))
			local direction = ""
			if not minRange then direction = ""
			elseif maxRange and maxRange <= 15 then direction = ">>>"
			elseif maxRange and minRange >= 15 and maxRange <= 20 then direction = ">"
			elseif maxRange and minRange >= 20 and maxRange <= 25 then direction = "***"
			elseif maxRange and minRange >= 25 and maxRange <= 30 then direction = "<"
			elseif minRange >= 30 then direction = "<<<"
			end
			local midValue = maxRange and ((minRange + maxRange)/2) or minRange
			-- update text
			if self.settings.rangetext == true and unit == self.settings.unit and direction ~= "***" then
				if minRange then
					--local text = maxRange and string.format("%d - %d %s", minRange, maxRange, direction) or string.format("%d+ %s", minRange, direction)
					--self.bar.rangeText:SetText(text)
					--local text = maxRange and string.format("%d %s", midValue, direction) or string.format("%d+ %s", midValue, direction)
					local text = direction
					self.bar.rangeText:SetText(text)
				else
					self.bar.rangeText:SetText("")
				end
			else
				self.bar.rangeText:SetText("")
			end
			-- update value
			if unit == self.settings.unit then
				if minRange then
					--self.bar.status:SetValue(value)
					self.bar.leftStatus:SetValue(midValue)
					if self.settings.displaycursor == true then
						self.bar.middleStatus:SetValue(1)
					end
					self.bar.rightStatus:SetValue(45-midValue)
					if self.settings.gradient ~= true then
						local colorFarR, colorFarG, colorFarB = unpack(self.settings.colors[1])
						local colorNearR, colorNearG, colorNearB = unpack(self.settings.colors[2])
						local colorCursor = self.settings.colors[3]
						if direction == ">>>" then
							self.bar.leftStatus:SetStatusBarColor(colorFarR, colorFarG, colorFarB, 1)
							self.bar.rightStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
						elseif direction == ">" then
							self.bar.leftStatus:SetStatusBarColor(colorFarR, colorFarG, colorFarB, 1)
							self.bar.rightStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
						elseif direction == "***" then
							self.bar.leftStatus:SetStatusBarColor(unpack(colorCursor))
							self.bar.rightStatus:SetStatusBarColor(unpack(colorCursor))
						elseif direction == "<" then
							self.bar.leftStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
							self.bar.rightStatus:SetStatusBarColor(colorFarR, colorFarG, colorFarB, 1)
						elseif direction == "<<<" then
							self.bar.leftStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
							self.bar.rightStatus:SetStatusBarColor(colorFarR, colorFarG, colorFarB, 1)
						end
					end
				else
					self.bar.leftStatus:SetValue(0)
					if self.settings.displaycursor == true then
						self.bar.middleStatus:SetValue(0)
					end
					self.bar.rightStatus:SetValue(0)
				end
			end
			self.forceRefresh = false
		end
	end
end

-- UI
if ClassMonitor_ConfigUI then
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
			key = "rangetext",
			name = "Range text",
			desc = "Display direction text",
			type = "toggle",
			get = Helpers.GetValue,
			set = Helpers.SetValue,
			disabled = Helpers.IsPluginDisabled
		},
		[10] = {
			key = "displaycursor",
			name = "Cursor",
			desc = "Display cursor",
			type = "toggle",
			get = Helpers.GetValue,
			set = Helpers.SetValue,
			disabled = Helpers.IsPluginDisabled
		},
		[11] = {
			key = "gradient",
			name = "Gradient",
			desc = "Display gradient instead of plain color",
			type = "toggle",
			get = Helpers.GetValue,
			set = Helpers.SetValue,
			disabled = Helpers.IsPluginDisabled
		},
		[12] = {
			key = "cursorsize",
			name = "Cursor width",
			desc = "Change cursor width",
			type = "range",
			min = 1, max = 10, step = 1,
			get = Helpers.GetValue,
			set = Helpers.SetValue,
			disabled = Helpers.IsPluginDisabled
		},
		[13] = colors,
		[14] = Helpers.Anchor,
		[15] = Helpers.AutoGridAnchor,
	}

	local short = "Halo"
	local long = "Get best performance of priest Halo talent aka HaloReallyPro"
	ClassMonitor_ConfigUI:NewPluginDefinition(pluginName, options, short, long) -- add plugin definition in ClassMonitor_ConfigUI
end

--[[
----------------------------------------
-- TEST CODE
----------------------------------------
local checkTarget = true
local checkFocus = true
local checkRaid = true

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event)
	if checkTarget == true and event == "PLAYER_TARGET_CHANGED" then
		UnitRangesCache["target"] = UnitRangesCache["target"] or {} -- force cache refresh
	elseif checkFocus == true and event == "PLAYER_FOCUS_CHANGED" then
		UnitRangesCache["focus"] = UnitRangesCache["focus"] or {} -- force cache refresh
	elseif checkRaid == true and event == "GROUP_ROSTER_UPDATE" then
		for i = 1, 40, 1 do
			-- TODO: party ?
			local unit = "raid"..tostring(i)
			if UnitInRaid(unit) then
				UnitRangesCache[unit] = UnitRangesCache["unit"] or {} -- force cache refresh
			else
				UnitRangesCache[unit] = nil -- remove from cache
			end
		end
	end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
	
end)
--]]