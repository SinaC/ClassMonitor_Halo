--[[

if true then return end

local rc = LibStub("LibRangeCheck-2.0")
local DBM = DBM

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

local DataByUnitCache = {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function (self, event)
	for i = 1, 40, 1 do
		-- TODO: party ?
		local unit = "raid"..tostring(i)
		if UnitInRaid(unit) then
			DataByUnitCache[unit] = {} -- force cache refresh
		else
			DataByUnitCache[unit] = nil -- remove from cache
		end
	end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
	local needUpdate = false
	for unit, dataByUnit in pairs(DataByUnitCache) do
		local minRange, maxRange = rc:GetRange(unit)
		if minRange ~= dataByUnit.minRange or maxRange ~= dataByUnit.maxRange then
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
			needUpdate = true
		end
	end
	if needUpdate then
		local count = 0
		local value = 0
		for unit, dataByUnit in pairs(DataByUnitCache) do
			if dataByUnit.coefficient then
				-- TODO: Perform some black magic with heal/healmax, coefficient and average heal ( + critical score??? )
				--local health = UnitHealth(unit)
				--local maxHealth = UnitHealthMax(unit)
				--local avgHaloHeal = GetAverageHeal(SP)
				value = value + dataByUnit.coefficient / maxHealCoefficient
				count = count + 1
			end
		end
		local efficiency = count > 0 and (value * 100 / count) or 0
print("COEFFICIENT:"..tostring(count).."  "..tostring(value).."  "..tostring(efficiency))
	end
end)
--]]