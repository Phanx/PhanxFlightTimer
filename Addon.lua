--[[--------------------------------------------------------------------
	PhanxFlightTimer
	Simple flight timer bar.
	Copyright (c) 2013-2014 Phanx <addons@phanx.net>. All rights reserved.

	Please DO NOT upload this addon to other websites, or post modified
	versions of it. However, you are welcome to include a copy of it
	WITHOUT CHANGES in compilations posted on Curse and/or WoWInterface.
	You are also welcome to use any/all of its code in your own addon, as
	long as you do not use my name or the name of this addon ANYWHERE in
	your addon, including its name, outside of an optional attribution.
----------------------------------------------------------------------]]

local TEXTURE = "Interface\\AddOns\\PhanxMedia\\statusbar\\HalA"

PhanxFlightTimes = { Alliance = {}, Horde = {} }
PhanxFlightNames = { Alliance = {}, Horde = {} }

local _, defaults = ...
local times, names
local currentName, currentPoint, startName, startPoint, startTime, endName, endPoint
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

	times = PhanxFlightTimes[faction]
	names = PhanxFlightNames[faction]

	defaults = defaults[faction]
	if not defaults then
		print(format("|cffff4444[PhanxFlightTimer]|r ERROR: Bad faction name %q", faction))
	end

	self.bg, self.text, self.border = self:GetRegions()
	self.bar = self:GetChildren()
	self.bar:GetStatusBarTexture():SetDrawLayer("BORDER")

	self.title = self:CreateFontString("$parentTitle", "OVERLAY", "GameFontHighlight")
	self.title:SetPoint("BOTTOM", self, "TOP", 0, 2)

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

local function getTaxiNodeInfo(i)
	local name = strmatch(TaxiNodeName(i), "[^,]+")
	local x, y = TaxiNodePosition(i)
	return name, floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end

TaxiFrame:HookScript("OnShow", function(self)
	local npc = strmatch(UnitGUID("npc"), "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	for i = 1, NumTaxiNodes() do
		local nodeType = TaxiNodeGetType(i)
		if nodeType ~= "NONE" then
			local name, point = getTaxiNodeInfo(i)
			if nodeType == "CURRENT" then
				currentName, currentPoint = name, point
			end
			if npc == 43287 then
				-- Sandy Beach, Vashj'ir @ Swift Seahorse
				name = name .. " (UNDERWATER)"
			elseif npc == 43290 then
				-- Sandy Beach, Vashj'ir @ Francis Greene
				name = name .. " (NORMAL)"
			end
			if names[name] and names[name] ~= point then
				local faction = UnitFactionGroup("player")
				print(format("|cffff4444[PhanxFlightTimer]|r ERROR: %s taxi node position %q changed!", faction, name))
				PhanxFlightNames.ErrorLog = PhanxFlightNames.ErrorLog or {}
				tinsert(PhanxFlightNames.ErrorLog, strjoin(" | ", date("%Y-%m-%d"), faction, name, names[name], point))
			end
			names[name] = point
	--	else
	--		print("TaxiNodeGetType", i, "NONE", TaxiNodeName(i))
	--		INFO: type is "NONE" for paths that use a different system,
	--		eg. Vashj'ir underwater paths when viewed from non-underwater
	--		points; must fly to Sandy Beach and transfer manually.
		end
	end
end)

hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
	local i = button:GetID()
	if TaxiNodeGetType(i) == "REACHABLE" then
		local name, point = getTaxiNodeInfo(i)
		local t = times[currentPoint] and times[currentPoint][point] or defaults[currentPoint] and defaults[currentPoint][point]
		if t then
			if IsInGuild() then
				t = floor(t / 1.25 + 0.5)
			end
			if t > 60 then
				GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeMinSec, t/60, mod(t,60)), 1, 0.82, 0, 1, 1, 1)
			else
				GameTooltip:AddDoubleLine(L.EstimatedTime, format(L.TimeSec, t), 1, 0.82, 0, 1, 1, 1)
			end
		else
			GameTooltip:AddDoubleLine(L.EstimatedTime, UNKNOWN, 1, 0.82, 0, 0.6, 0.6, 0.6)
		end
		GameTooltip:Show()
	end
end)

hooksecurefunc("TakeTaxiNode", function(i)
	print("TakeTaxiNode", i)
	inWorld, timeOutOfWorld, tookPort = true, 0, nil
	startName, startPoint, startTime = currentName, currentPoint, GetTime()
	endName, endPoint = getTaxiNodeInfo(i)
	endTime = nil
	print("    Flying from", startName, "to", endName)
end)

function Addon:PLAYER_CONTROL_LOST()
	print("PLAYER_CONTROL_LOST")
	if startName then
		local now = GetTime()
		if now - startTime < 1 then
			print("    Flight started")
			startTime = now
			guildPerk = IsInGuild()
			local t = times[startPoint] and times[startPoint][endPoint] or defaults[startPoint] and defaults[startPoint][endPoint]
			if t then
				if guildPerk then
					print("    Has guild perk")
					t = floor(t / 1.25 + 0.5)
				end
				print("    Expected time", floor(t/60), "m", mod(t,60), "s")
				endTime = startTime + t
				self.bar:SetMinMaxValues(startTime, endTime)
				self.title:SetText(endName)
				self:Show()
			else
				endTime = 1
				self.bar:SetMinMaxValues(0, endTime)
				self.title:SetText(endName)
				self:Show()
			end
		else
			startName = nil
			startTime = nil
		end
	end
end

function Addon:PLAYER_CONTROL_GAINED()
	print("PLAYER_CONTROL_GAINED")
	if startTime and inWorld and not tookPort then
		local stillHasPerk = IsInGuild()
		if guildPerk == stillHasPerk then
			-- Only save if the player's guild status didn't change during the flight.
			local t = GetTime() - startTime
			if guildPerk then
				t = floor(t * 1.25 + 0.5)
			else
				t = floor(t + 0.5)
			end
			if not defaults[startPoint] or t ~= defaults[startPoint][endPoint] then
				print("   Flight ended")
				print("   Elapsed time", floor(t/60), "min", floor(mod(t,60)), "sec")
				times[startPoint] = times[startPoint] or {}
				times[startPoint][endPoint] = t
			end
			if not defaults[endPoint] and (not times[endPoint] or not times[endPoint][startPoint]) then
				-- Reverse path probably has the same time, use it if there's nothing else
				print("    Reverse was missing")
				times[endPoint] = times[endPoint] or {}
				times[endPoint][startPoint] = t
			end
		end
	end
	self:Hide()
	startName, startTime, endTime = nil, nil, nil
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

Addon:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 2, -2)
	GameTooltip:SetText("PhanxFlightTimer")
	GameTooltip:AddDoubleLine(L.FlyingFrom, startName, 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddDoubleLine(L.FlyingTo, endName, 1, 0.82, 0, 1, 1, 1)
	local t = times[startPoint] and times[startPoint][endPoint] or defaults[startPoint] and defaults[startPoint][endPoint]
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
