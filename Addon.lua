--[[--------------------------------------------------------------------
	PhanxFlightTimer
	Simple flight timer bar.
	Copyright (c) 2013-2014 Phanx <addons@phanx.net>. All rights reserved.
	See the accompanying LICENSE file for more information.
	http://www.wowinterface.com/downloads/info22654-PhanxTooltip.html
	http://wow.curseforge.com/addons/phanxtooltip/
	http://www.curse.com/addons/wow/phanxtooltip
----------------------------------------------------------------------]]

local TEXTURE = "Interface\\AddOns\\PhanxMedia\\statusbar\\Qlight"

PhanxFlightData = {}

local _, defaults = ...
local data, startPoint, startTime, endPoint, currentPoint
local guildPerk, inWorld, timeOutOfWorld, tookPort

local L = {
	EstimatedTime = "Estimated time:",
	FlyingFrom = "Flying from:",
	FlyingTo = "Flying to:",
	TimeMinSec = gsub(MINUTE_ONELETTER_ABBR, "%s", "") .. " " .. gsub(SECOND_ONELETTER_ABBR, "%s", ""),
	TimeSec = gsub(SECOND_ONELETTER_ABBR, "%s", ""),
}
if GetLocale() == "deDE" then
	L.EstimatedTime = "Geschätzte Flugzeit:"
	L.FlyingFrom = "Fliegt von:"
	L.FlyingTo = "Fliegt nach:"
elseif strmatch(GetLocale(), "^es") then
	L.EstimatedTime = "Tiempo estimado:"
	L.FlyingFrom = "Volando de:"
	L.FlyingTo = "Volando a:"
end

local Addon = CreateFrame("Frame", "PhanxFlightTimer", UIParent, "MirrorTimerTemplate")
Addon.bg, Addon.text, Addon.border = Addon:GetRegions()
Addon.bar = Addon:GetChildren()

Addon.title = Addon:CreateFontString("$parentTitle", "OVERLAY", "GameFontHighlight")
Addon.title:SetPoint("BOTTOM", Addon, "TOP", 0, 2)

Addon:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 2, -2)
	GameTooltip:SetText("PhanxFlightTimer")
	GameTooltip:AddDoubleLine(L.FlyingFrom, startPoint, 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(L.FlyingTo, endPoint, 1, 0.82, 0, 1, 1, 1)
	local t = data[startPoint] and data[startPoint][endPoint] or defaults[startPoint] and defaults[startPoint][endPoint]
	if t then
		if t > 60 then
			GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeMinSec, t/60, mod(t,60)), 1, 0.82, 0, 1, 1, 1)
		else
			GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeSec, t), 1, 0.82, 0, 1, 1, 1)
		end
	end
	GameTooltip:Show()
end)

Addon:SetScript("OnLeave", GameTooltip_Hide)

Addon:UnregisterAllEvents()
Addon:RegisterEvent("PLAYER_LOGIN")
Addon:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, ...)
end)

function Addon:PLAYER_LOGIN()
	local faction = UnitFactionGroup("player")
	if not faction or faction == "" then
		-- Pandaren
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self.PLAYER_LEVEL_UP = self.PLAYER_LOGIN
		return
	end

	self:UnregisterEvent("PLAYER_LEVEL_UP")
	self:UnregisterEvent("PLAYER_LOGIN")

	PhanxFlightData[faction] = PhanxFlightData[faction] or {}
	data = PhanxFlightData[faction]

	PhanxFlightDefaultData = defaults
	defaults = defaults[faction]
	if not defaults then
		print(format("|cffff4444[PhanxFlightTimer]|r ERROR: Bad faction name %q", faction))
	end

	self:SetPoint("TOP", 0, -168)
	if PhanxBorder then
		self.bar:ClearAllPoints()
		self.bar:SetAllPoints(self)
		self.bar:SetStatusBarTexture(TEXTURE)

		self.bg:ClearAllPoints()
		self.bg:SetAllPoints(self)
		self.bg:SetTexture(TEXTURE)
		self.bg:SetVertexColor(0.2, 0.2, 0.2, 1)

		self.text:ClearAllPoints()
		self.text:SetPoint("CENTER", self.bar)

		self.title:SetPoint("BOTTOM", self.bar, "TOP", 0, -2)

		self.border:Hide()

		PhanxBorder.AddBorder(self.bar)
	end

	self:RegisterEvent("PLAYER_CONTROL_LOST")
	self:RegisterEvent("PLAYER_CONTROL_GAINED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
end

TaxiFrame:HookScript("OnShow", function(self)
	for i = 1, NumTaxiNodes() do
		if TaxiNodeGetType(i) == "CURRENT" then
			currentPoint = strmatch(TaxiNodeName(i), "[^,]+")
			break
		end
	end
end)

hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
	local i = button:GetID()
	if TaxiNodeGetType(i) == "REACHABLE" then
		local name = strmatch(TaxiNodeName(i), "[^,]+")
		local t = data[currentPoint] and data[currentPoint][name] or defaults[currentPoint] and defaults[currentPoint][name]
		if t then
			if IsInGuild() and GetGuildLevel() >= 21 then
				t = floor(t / 1.25 + 0.5)
			end
			if t > 60 then
				GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeMinSec, t/60, mod(t,60)), 1, 0.82, 0, 1, 1, 1)
			else
				GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeSec, t), 1, 0.82, 0, 1, 1, 1)
			end
		else
			GameTooltip:AddDoubleLine(L.EstimatedTime, UNKNOWN, 1, 0.82, 0, 0.1, 0.1, 1)
		end
		GameTooltip:Show()
	end
end)

hooksecurefunc("TakeTaxiNode", function(node)
	--print("TakeTaxiNode", node)
	startPoint, startTime, endTime = nil, nil, nil
	inWorld, timeOutOfWorld, tookPort = true, 0, nil
	for i = 1, NumTaxiNodes() do
		if i == node then
			startTime = GetTime()
			startPoint = currentPoint
			endPoint = strmatch(TaxiNodeName(i), "[^,]+")
			break
		end
	end
	--print("    Flying from", startPoint, "to", endPoint, "[^,]+"))
end)

function Addon:PLAYER_CONTROL_LOST()
	--print("PLAYER_CONTROL_LOST")
	if startPoint then
		local now = GetTime()
		if now - startTime < 1 then
			--print("    Flight started")
			startTime = now
			guildPerk = IsInGuild() and GetGuildLevel() >= 21
			local t = data[startPoint] and data[startPoint][endPoint] or defaults[startPoint] and defaults[startPoint][endPoint]
			if t then
				if guildPerk then
					t = floor(t / 1.25 + 0.5)
				end
				--print("    Expected time", floor(t/60), "m", mod(t,60), "s")
				endTime = startTime + t
				self.bar:SetMinMaxValues(startTime, endTime)
				self.title:SetText(endPoint)
				self:Show()
			else
				endTime = 1
				self.bar:SetMinMaxValues(0, endTime)
				self.title:SetText(endPoint)
				self:Show()
			end
		else
			startPoint = nil
			startTime = nil
		end
	end
end

function Addon:PLAYER_CONTROL_GAINED()
	--print("PLAYER_CONTROL_GAINED")
	if startTime and inWorld and not tookPort then
		local stillHasPerk = IsInGuild() and GetGuildLevel() >= 21
		if guildPerk == stillHasPerk then
			-- Only save if the player's guild status didn't change during the flight.
			local t = GetTime() - startTime
			if guildPerk then
				t = floor(t * 1.25 + 0.5)
			else
				t = floor(t + 0.5)
			end
			if not defaults[startPoint] or t ~= defaults[startPoint][endPoint] then
				--print("   Flight ended")
				--print("   Elapsed time", floor(t/60), "min", floor(mod(t,60)), "sec")
				data[startPoint] = data[startPoint] or {}
				data[startPoint][endPoint] = t
			end
			if not defaults[endPoint] and (not data[endPoint] or not data[endPoint][startPoint]) then
				-- Reverse path probably has the same time, use it if there's nothing else
				data[endPoint] = data[endPoint] or {}
				data[endPoint][startPoint] = t
			end
		end
	end
	self:Hide()
	startPoint, startTime, endTime = nil, nil, nil
end

function Addon:PLAYER_LEAVING_WORLD()
	inWorld = nil
end

function Addon:PLAYER_ENTERING_WORLD()
	inWorld = true
end

hooksecurefunc("AcceptBattlefieldPort", function(index, accept) tookPort = accept and true end)
hooksecurefunc("ConfirmSummon", function() tookPort = true end)
hooksecurefunc("CompleteLFGRoleCheck", function(bool) tookPort = bool end)

Addon:Hide()
Addon:SetScript("OnUpdate", function(self, elapsed)
	local now = GetTime()
	if now <= endTime then
		self.bar:SetValue(now)
		self.bar:SetStatusBarColor(0, 0.5, 0.5)

		local t = endTime - now
		if t > 60 then
			self.text:SetFormattedText(L.TimeMinSec, t/60, mod(t,60))
		else
			self.text:SetFormattedText(L.TimeSec, t)
		end
	else
		self.bar:SetValue(endTime)
		self.bar:SetStatusBarColor(0.5, 0, 0.5)
		self.text:SetText(nil)
	end
end)