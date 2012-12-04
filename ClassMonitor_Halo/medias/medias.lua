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

Engine.Left = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\left]]
Engine.MidLeft = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\mid_left]]
Engine.Center = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\center]]
Engine.MidRight = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\mid_right]]
Engine.Right = [[Interface\AddOns\]]..ADDON_NAME..[[\medias\right]]