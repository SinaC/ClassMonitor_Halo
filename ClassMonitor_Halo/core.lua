local ADDON_NAME, Engine = ...

local class = select(2, UnitClass("player"))
if class ~= "PRIEST" then return end -- Only for priests

local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI

local rc = LibStub("LibRangeCheck-2.0")
local DBM = DBM

-- rc.RegisterCallback(frame, rc.CHECKERS_CHANGED, function() 
	-- -- NOP
-- end)

local pluginName = "HALO"
local haloPlugin = ClassMonitor:NewPlugin(pluginName)

-- Halo datas
local haloSpellID = 120517 -- there is 3 different spellID's  (120517, 120692 and 120696)
local minDamage = 15163
local maxDamage = 25270
local SPDamage = 195
local minHeal = 25271
local maxHeal = 42117
local SPHeal = 325

local healCoefficients = {
	{ minRange = 0, maxRange = 5, value = 0.275747203 },
	{ minRange = 5, maxRange = 8, value = 0.485580837 },
	{ minRange = 8, maxRange = 10, value = 0.575568022 },
	{ minRange = 10, maxRange = 15, value = 0.786628563 },
	{ minRange = 15, maxRange = 20, value = 1.696996699 },
	{ minRange = 20, maxRange = 25, value = 2.489160379 },
	{ minRange = 25, maxRange = 30, value = 2.660550872 },
	{ minRange = 30, maxRange = 35, value = 0.910363971 },
	{ minRange = 35, maxRange = 40, value = 0.5 }, --2.548339578}, -- invalid data
	{ minRange = 40, maxRange = 45, value = 0.25 }, --1.444601947}, -- invalid data
	{ minRange = 45, maxRange = 100, value = 0},
}

local maxHealCoefficient = 0
for _, healCoefficient in pairs(healCoefficients) do
	if healCoefficient.value > maxHealCoefficient then
		maxHealCoefficient = healCoefficient.value
	end
end

local damageCoefficients = {
	{ minRange = 0, maxRange = 5, value = 1.284179898 },
	{ minRange = 5, maxRange = 8, value = 1.651862459 },
	{ minRange = 8, maxRange = 10, value = 1.874270192 },
	{ minRange = 10, maxRange = 15, value = 2.399364388 },
	{ minRange = 15, maxRange = 20, value = 2.99459488 },
	{ minRange = 20, maxRange = 25, value = 3.509965761 },
	{ minRange = 25, maxRange = 30, value = 2.988709629 },
	{ minRange = 30, maxRange = 35, value = 2.471406291 },
	{ minRange = 35, maxRange = 40, value = 0 }, -- no data
	{ minRange = 40, maxRange = 45, value = 0 }, -- no data
	{ minRange = 45, maxRange = 100, value = 0}, -- no data
}

local maxDamageCoefficient = 0
for _, damageCoefficient in pairs(damageCoefficients) do
	if damageCoefficient.value > maxDamageCoefficient then
		maxDamageCoefficient = damageCoefficient.value
	end
end

local function GetAverageDamage(SP)
	return (minDamage + maxDamage) * SP * SPDamage / 2*100
end

local function GetAverageHeal(SP)
	return (minHeal + maxHeal) * SP * SPHeal / 2*100
end

-- Return value or default is value is nil
local function DefaultBoolean(value, default)
	if value == nil then
		return default
	else
		return value
	end
end

-- Return DBM distance if available, use LibRangeCheck otherwise
local function GetRange(unit)
	local minRange, maxRange
	if DBM and UnitCanAssist("player", unit) then
		local x, y = GetPlayerMapPosition("player")
		if x == 0 and y == 0 then
			SetMapToCurrentZone()
			x, y = GetPlayerMapPosition("player")
		end
		local distance = DBM.RangeCheck:GetDistance(unit, x, y)
		minRange = distance
		maxRange = distance
	end
	if not minRange and not maxRange then
		minRange, maxRange = rc:GetRange(unit)
	end
	return minRange, maxRange
end

-- Plugin overwritten methods
function haloPlugin:Initialize()
	-- default settings
	self.settings.directiontext = DefaultBoolean(self.settings.directiontext, true)
	self.settings.unit = self.settings.unit or "target"
	self.settings.checkraid = DefaultBoolean(self.settings.checkraid, true)
	self.settings.colors = self.settings.colors or {
		[1] = {0.15, 0.15, 0.15, 1}, -- Far
		[2] = {0.85, 0.74, 0.25, 1}, -- Near
		[3] = {1, 1, 1, 1}, -- Cursor
	}
	self.settings.displaycursor = DefaultBoolean(self.settings.displaycursor, false)
	self.settings.gradient = DefaultBoolean(self.settings.gradient, true)
	self.settings.cursorsize = self.settings.cursorsize or 4
	self.settings.showcdup = DefaultBoolean(self.settings.showcdup, true)
	--
	self.DataByUnitCache = {}
	--
	self:UpdateGraphics()
end

function haloPlugin:Enable()
	--
	if self.settings.unit == "target" then self:RegisterEvent("PLAYER_TARGET_CHANGED", haloPlugin.UpdateCacheKey) end
	if self.settings.unit == "focus" then self:RegisterEvent("PLAYER_FOCUS_CHANGED", haloPlugin.UpdateCacheKey) end
	if self.settings.checkraid == true then self:RegisterEvent("GROUP_ROSTER_UPDATE", haloPlugin.UpdateCacheKey) end
	--
	if self.settings.showcdup == true then
		self:RegisterEvent("SPELL_UPDATE_USABLE", haloPlugin.UpdateVisibility)
	end
	self:RegisterEvent("PLAYER_TALENT_UPDATE", haloPlugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", haloPlugin.UpdateVisibility)
	--
	--self.bar:Show()
end

function haloPlugin:Disable()
	--
	self:UnregisterAllEvents()
	self:UnregisterUpdate()
	--
	self.currentCDState = nil
	--
	self.bar:Hide()
end

function haloPlugin:SettingsModified()
	--
	self.DataByUnitCache = {} -- empty cache
	--
	self:Disable()
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibility()
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
		--bar.leftStatus:SetStatusBarTexture(UI.NormTex)
		bar.leftStatus:SetStatusBarTexture(Engine.BlankTex)
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
	else
		bar.leftStatus:SetStatusBarColor(0, 0, 0, 1)
	end
	bar.leftStatus:SetMinMaxValues(0, 45)
	bar.leftStatus:SetValue(0)
	--
	if self.settings.displaycursor == true then
		if not bar.middleStatus then
			bar.middleStatus = CreateFrame("StatusBar", nil, bar)
			--bar.middleStatus:SetStatusBarTexture(UI.NormTex)
			bar.middleStatus:SetStatusBarTexture(Engine.BlankTex)
		end
		bar.middleStatus:ClearAllPoints()
		bar.middleStatus:Point("LEFT", bar.leftStatus:GetStatusBarTexture(), "RIGHT", 0, 0) -- middle will move when left moves
		bar.middleStatus:Size(self.settings.cursorsize, bar.leftStatus:GetHeight())
		bar.middleStatus:SetStatusBarColor(unpack(colorCursor))
		bar.middleStatus:SetMinMaxValues(0, 1)
	end
	if bar.middleStatus then
		bar.middleStatus:SetValue(0)
	end
	--
	if not bar.rightStatus then
		bar.rightStatus = CreateFrame("StatusBar", nil, bar)
		--bar.rightStatus:SetStatusBarTexture(UI.NormTex)
		bar.rightStatus:SetStatusBarTexture(Engine.BlankTex)
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
	else
		bar.rightStatus:SetStatusBarColor(0, 0, 0, 1)
	end
	bar.rightStatus:SetMinMaxValues(0, 45)
	bar.rightStatus:SetValue(0)
	--
	if self.settings.directiontext == true then
		if not bar.directionText then
			bar.directionText = UI.SetFontString(bar.leftStatus, 12)
			bar.directionText:Point("CENTER", bar.leftStatus)
		end
		bar.directionText:SetText("")
	end
	--
	if self.settings.checkraid == true then
		if not bar.healText then
			bar.healText = UI.SetFontString(bar.leftStatus, 12)
			bar.healText:Point("RIGHT", bar.leftStatus)
		end
		bar.healText:SetText("")
	end
end

function haloPlugin:UpdateCacheKey(event)
	if self.settings.unit == "target" and (not event or event == "PLAYER_TARGET_CHANGED") then
		self.DataByUnitCache["target"] = UnitName("target") and {} or nil-- force cache refresh or clear
	elseif self.settings.unit == "focus" and (not event or event == "PLAYER_FOCUS_CHANGED") then
		self.DataByUnitCache["focus"] = UnitName("focus") and {} or nil-- force cache refresh or clear
	elseif self.settings.checkraid == true and (not event or event == "GROUP_ROSTER_UPDATE") then
		for i = 1, 40, 1 do
			-- TODO: party ?
			local unit = "raid"..tostring(i)
			if UnitInRaid(unit) then
				self.DataByUnitCache[unit] = {} -- force cache refresh
			else
				self.DataByUnitCache[unit] = nil -- remove from cache
			end
		end
	end
end

function haloPlugin:UpdateVisibility(event)
	local spellName = GetSpellInfo(GetSpellInfo(haloSpellID)) -- double check ... Blizzard I hate you
--print("UPDATEVISIBILITY:"..tostring(event).."  "..tostring(spellName))
	if not spellName then
--print("NOT KNOWN")
		self:UnregisterUpdate()
		self.bar:Hide()
		self.currentCDState = nil
	elseif self.settings.showcdup == true then
		local start, duration, enabled = GetSpellCooldown(spellName)
		local newCDState = nil
		if start > 0 and duration > 1.5 then -- not a GCD
			newCDState = "ONCD"
		else
			newCDState = "OFFCD"
		end
		if self.currentCDState ~= newCDState then
			if newCDState == "ONCD" then
--print("->ONCD")
				self:UnregisterUpdate()
				self.bar:Hide()
			else
--print("->OFFCD")
				self:UpdateCacheKey()
				self:RegisterUpdate(haloPlugin.Update)
			end
			self.currentCDState = newCDState
		end
	else
		self:UpdateCacheKey()
		self:RegisterUpdate(haloPlugin.Update)
	end
end

function haloPlugin:Update(elapsed)
	-- Update range and update monitored unit
	for unit, dataByUnit in pairs(self.DataByUnitCache) do
		local minRange, maxRange = GetRange(unit)
		if minRange ~= dataByUnit.minRange or maxRange ~= dataByUnit.maxRange then
			-- update ranges
			dataByUnit.minRange = minRange
			dataByUnit.maxRange = maxRange
			if unit == self.settings.unit then
				dataByUnit.coefficient = nil
				if not UnitCanAttack("player", unit) and not UnitCanAssist("player", unit) then
					self.bar:Hide()
				else
					local direction = ""
					if not minRange then direction = ""
					elseif maxRange and maxRange <= 10 then direction = ">>>"
					elseif maxRange and minRange >= 10 and maxRange <= 15 then direction = ">>"
					elseif maxRange and minRange >= 15 and maxRange <= 20 then direction = ">"
					elseif maxRange and minRange >= 20 and maxRange <= 25 then direction = "***"
					elseif maxRange and minRange >= 25 and maxRange <= 30 then direction = "<"
					elseif maxRange and minRange >= 30 and maxRange <= 40 then direction = "<<"
					elseif minRange >= 40 then direction = "<<<"
					end
					local midValue = maxRange and ((minRange + maxRange)/2) or minRange
					local normalizedValue = 22.5+22.5/(math.pi/2)*math.atan(0.1*(midValue-22.5)) -- too sharp
print("UNIT:"..tostring(unit).."  RANGE:"..tostring(dataByUnit.minRange).."=>"..tostring(dataByUnit.maxRange).."  "..tostring(direction).."  "..tostring(midValue).."  "..tostring(normalizedValue))
					midValue = (direction == ">>>" or direction == "<<<") and midValue or normalizedValue -- normalize central values only to avoid <<, <, ***, >, >> to be almost at the same place on the bar
					-- update text
					if self.settings.directiontext == true and unit == self.settings.unit and direction ~= "***" then
						if minRange then
							--local text = maxRange and string.format("%d - %d %s", minRange, maxRange, direction) or string.format("%d+ %s", minRange, direction)
							--self.bar.directionText:SetText(text)
							--local text = maxRange and string.format("%d %s", midValue, direction) or string.format("%d+ %s", midValue, direction)
							--self.bar.directionText:SetText(text)
							self.bar.directionText:SetText(direction)
						else
							self.bar.directionText:SetText("")
						end
					else
						self.bar.directionText:SetText("")
					end
					-- update value
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
								--self.bar.leftStatus:SetStatusBarColor(unpack(colorCursor))
								--self.bar.rightStatus:SetStatusBarColor(unpack(colorCursor))
								self.bar.leftStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
								self.bar.rightStatus:SetStatusBarColor(colorNearR, colorNearG, colorNearB, 1)
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
					self.bar:Show()
				end
			else
				-- other units
				if UnitCanAssist("player", unit) then
					local midRange = maxRange and ((minRange + maxRange)/2) or minRange
					local coefficient = 0
					for _, v in pairs(healCoefficients) do
						if v.minRange == minRange and v.maxRange == maxRange then
							coefficient = v.value
							break
						end
						if v.minRange <= midRange and v.maxRange >= midRange then
							coefficient = v.value
						end
					end
					dataByUnit.coefficient = coefficient
				else
					dataByUnit.coefficient = nil
				end
			end
		end
	end
	if self.settings.checkraid == true then
		-- Compute heal efficiency
		--local SP = GetSpellBonusHealing()  -- GetSpellBonusDamage(7)  DPS
		local count = 0
		local value = 0
		for unit, dataByUnit in pairs(self.DataByUnitCache) do
			if dataByUnit.coefficient and not UnitIsUnit(unit, "player") then -- if valid coefficient and not the player
				-- TODO: Perform some black magic with heal/healmax, coefficient and average heal ( + critical score??? )
				--local health = UnitHealth(unit)
				--local maxHealth = UnitHealthMax(unit)
				--local avgHaloHeal = GetAverageHeal(SP)
				value = value + dataByUnit.coefficient / maxHealCoefficient
				count = count + 1
			end
		end
		local efficiency = count > 0 and (value * 100 / count) or 0
	--print("COEFFICIENT:"..tostring(count).."  "..tostring(value).."  "..tostring(efficiency))
		self.bar.healText:SetFormattedText("%.2f%%", efficiency)
	end
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
		DataByUnitCache["target"] = DataByUnitCache["target"] or {} -- force cache refresh
	elseif checkFocus == true and event == "PLAYER_FOCUS_CHANGED" then
		DataByUnitCache["focus"] = DataByUnitCache["focus"] or {} -- force cache refresh
	elseif checkRaid == true and event == "GROUP_ROSTER_UPDATE" then
		for i = 1, 40, 1 do
			-- TODO: party ?
			local unit = "raid"..tostring(i)
			if UnitInRaid(unit) then
				DataByUnitCache[unit] = DataByUnitCache["unit"] or {} -- force cache refresh
			else
				DataByUnitCache[unit] = nil -- remove from cache
			end
		end
	end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
	
end)
--]]