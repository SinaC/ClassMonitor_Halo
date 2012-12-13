local ADDON_NAME, Engine = ...

local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI

if Tukui then
	local _, C = unpack(Tukui)
	Engine.BlankTex = C["media"].blank
elseif ElvUI then
	local E = unpack(ElvUI)
	Engine.BlankTex = E["media"].blankTex
else
	Engine.BlankTex = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\blank]]
end