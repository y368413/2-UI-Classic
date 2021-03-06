﻿local _, ns = ...
local M, R, U, I = unpack(ns)

hooksecurefunc("TextStatusBar_UpdateTextString", function(bar)   ----	  血量百分比数字 
	local value = bar:GetValue()
	local _, max = bar:GetMinMaxValues()
	if bar.pctText then
		bar.pctText:SetText(value==0 and "" or tostring(math.ceil((value / max) * 100)))  --(value==0 and "" or tostring(math.ceil((value / max) * 100)) .. "%")
		if not MaoRUIPerDB["UFs"]["UFPctText"] or value == max then bar.pctText:Hide()
		elseif GetCVarBool("statusTextPercentage") and ( bar.unit == PlayerFrame.unit or bar.unit == "target" or bar.unit == "focus" ) then bar.pctText:Hide()
		else bar.pctText:Show()
		end
	end
end)

function CreateBarPctText(frame, ap, rp, x, y, font, fontsize)
	local bar = frame.healthbar 
	if bar then
		if bar.pctText then
			bar.pctText:ClearAllPoints()
			bar.pctText:SetPoint(ap, bar, rp, x, y)
		else
			bar.pctText = frame:CreateFontString(nil, "OVERLAY", font)
			bar.pctText:SetPoint(ap, bar, rp, x, y)
			bar.pctText:SetFont("Interface\\addons\\_ShiGuang\\Media\\Fonts\\Pixel.TTF", fontsize, "OUTLINE")
			bar.pctText:SetShadowColor(0, 0, 0)
		end
	end
end
CreateBarPctText(PlayerFrame, "RIGHT", "LEFT", -80, -8, "NumberFontNormalLarge", 36)
CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 80, -8, "NumberFontNormalLarge", 36)
--CreateBarPctText(TargetFrameToT, "BOTTOMLEFT", "TOPRIGHT", 0, 5)
for i = 1, 4 do CreateBarPctText(_G["PartyMemberFrame"..i], "LEFT", "RIGHT", 6, 0, "NumberFontNormal", 16) end
--for i = 1, MAX_BOSS_FRAMES do CreateBarPctText(_G["Boss"..i.."TargetFrame"], "LEFT", "RIGHT", 8, 30, "NumberFontNormal", 36) end	

--	Player class colors HP.
function unitClassColors(healthbar, unit)
	if healthbar and not healthbar.lockValues and unit == healthbar.unit then
		local min, max = healthbar:GetMinMaxValues()
		local value = healthbar:GetValue()
		if max > min then value = (value - min) / (max - min) else value = 0 end
		if value > 0.5 then r, g, b = 2*(1-value), 1, 0 else r, g, b = 1, 2*value, 0 end
			--if UnitIsPlayer(unit) and UnitClass(unit) then  --按职业着色
				--local color = RAID_CLASS_COLORS[select(2, UnitClass(unit))]
				--healthbar:SetStatusBarColor(color.r, color.g, color.b)
			--else
				--healthbar:SetStatusBarColor(r, g, b)
			--end
		if healthbar.pctText then	healthbar.pctText:SetTextColor(r, g, b) end
	end
	if UnitIsPlayer(unit) and UnitClass(unit) then
		_, class = UnitClass(unit);
		local class = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class];
		healthbar:SetStatusBarColor(class.r, class.g, class.b);
		if not UnitIsConnected(unit) then
			healthbar:SetStatusBarColor(0.6,0.6,0.6,0.5);
		end
	end
	-- PlayerFrameHealthBar:SetStatusBarColor(0,0.9,0);
end
hooksecurefunc("UnitFrameHealthBar_Update", unitClassColors)
hooksecurefunc("HealthBar_OnValueChanged", function(self) unitClassColors(self, self.unit) end)

  
--	Whoa′s customs target unit reactions HP colors.
local function npcReactionColors(healthbar, unit)
		if UnitExists(unit) and (not UnitIsPlayer(unit)) then
			local reaction = FACTION_BAR_COLORS[UnitReaction(unit,"player")];
			if reaction then
				healthbar:SetStatusBarColor(reaction.r, reaction.g, reaction.b);
			else
				healthbar:SetStatusBarColor(0,0.6,0.1)
			end
			if (UnitIsTapDenied(unit)) then
				healthbar:SetStatusBarColor(0.5, 0.5, 0.5)
			elseif UnitIsCivilian(unit) then
				healthbar:SetStatusBarColor(1.0, 1.0, 1.0)
			end
		end
		--if UnitExists(unit) and (not UnitIsPlayer(unit)) then
			--healthbar:SetStatusBarColor(0,0.9,0)
		--end
end
hooksecurefunc("UnitFrameHealthBar_Update", npcReactionColors)
hooksecurefunc("HealthBar_OnValueChanged", function(self) npcReactionColors(self, self.unit) end)

---------------------------------------------------------------------------------	Aura positioning constants.
local LARGE_AURA_SIZE, SMALL_AURA_SIZE, AURA_OFFSET_Y, AURA_ROW_WIDTH, NUM_TOT_AURA_ROWS = 21, 16, 1, 128, 2   -- Set aura size.
hooksecurefunc("TargetFrame_UpdateAuraPositions", function(self, auraName, numAuras, numOppositeAuras, largeAuraList, updateFunc, maxRowWidth, offsetX, mirrorAurasVertically)
		local size;
		local offsetY = AURA_OFFSET_Y;
		local rowWidth = 0;
		local firstBuffOnRow = 1;
		for i=1, numAuras do
			if ( largeAuraList[i] ) then
				size = LARGE_AURA_SIZE; --(cfg.largeAuraSize)
				offsetY = AURA_OFFSET_Y + AURA_OFFSET_Y;
			else
				size = SMALL_AURA_SIZE;	--(cfg.smallAuraSize) --
			end
			if ( i == 1 ) then
				rowWidth = size;
				self.auraRows = self.auraRows + 1;
			else
				rowWidth = rowWidth + size + offsetX;
			end
			if ( rowWidth > maxRowWidth ) then
				updateFunc(self, auraName, i, numOppositeAuras, firstBuffOnRow, size, offsetX, offsetY, mirrorAurasVertically);
				rowWidth = size;
				self.auraRows = self.auraRows + 1;
				firstBuffOnRow = i;
				offsetY = AURA_OFFSET_Y;
				if ( self.auraRows > NUM_TOT_AURA_ROWS ) then
					maxRowWidth = AURA_ROW_WIDTH;
				end
			else
				updateFunc(self, auraName, i, numOppositeAuras, i - 1, size, offsetX, offsetY, mirrorAurasVertically);
			end
		end
end)

local function CreateStatusBarText(name, parentName, parent, point, x, y)
	local fontString = parent:CreateFontString(parentName..name, nil, "TextStatusBarText")
	fontString:SetPoint(point, parent, point, x, y)
	return fontString
end
local function CreateDeadText(name, parentName, parent, point, x, y)
	local fontString = parent:CreateFontString(parentName..name, nil, "GameFontNormalSmall")
	fontString:SetPoint(point, parent, point, x, y)
	return fontString
end
local function targetFrameStatusText()
	TargetFrameHealthBar.TextString = CreateStatusBarText("Text", "TargetFrameHealthBar", TargetFrameTextureFrame, "CENTER", 0, 0);
	TargetFrameHealthBar.LeftText = CreateStatusBarText("TextLeft", "TargetFrameHealthBar", TargetFrameTextureFrame, "LEFT", 5, 0);
	TargetFrameHealthBar.RightText = CreateStatusBarText("TextRight", "TargetFrameHealthBar", TargetFrameTextureFrame, "RIGHT", -3, 0);
	TargetFrameManaBar.TextString = CreateStatusBarText("Text", "TargetFrameManaBar", TargetFrameTextureFrame, "CENTER", 0, 0);
	TargetFrameManaBar.LeftText = CreateStatusBarText("TextLeft", "TargetFrameManaBar", TargetFrameTextureFrame, "LEFT", 5, 0);
	TargetFrameManaBar.RightText = CreateStatusBarText("TextRight", "TargetFrameManaBar", TargetFrameTextureFrame, "RIGHT", -3, 0);
	TargetFrameTextureFrameGhostText = CreateDeadText("GhostText", "TargetFrameHealthBar", TargetFrameHealthBar, "CENTER", 0, 0);
	TargetFrameTextureFrameOfflineText = CreateDeadText("OfflineText", "TargetFrameHealthBar", TargetFrameHealthBar, "CENTER", 0, 0);
	PlayerFrameDeadText = CreateDeadText("DeadText", "PlayerFrame", PlayerFrameHealthBar, "CENTER", 0, 0);
	PlayerFrameGhostText = CreateDeadText("GhostText", "PlayerFrame", PlayerFrameHealthBar, "CENTER", 0, 0);

	PlayerFrameDeadText:SetText(DEAD);
	PlayerFrameGhostText:SetText("Ghost");
	TargetFrameTextureFrameGhostText:SetText("Ghost");
	TargetFrameTextureFrameOfflineText:SetText("Offline");
end
targetFrameStatusText()

--[[hooksecurefunc("PlayerFrame_ToPlayerArt", function(self)
		self.healthbar.LeftText:SetFontObject(SystemFont_Outline_Small);
		self.healthbar.RightText:SetFontObject(SystemFont_Outline_Small);
		self.manabar.LeftText:SetFontObject(SystemFont_Outline_Small);
		self.manabar.RightText:SetFontObject(SystemFont_Outline_Small);
		self.healthbar.TextString:SetFontObject(SystemFont_Outline_Small);
		self.manabar.TextString:SetFontObject(SystemFont_Outline_Small);
end)]]

--[[hooksecurefunc("TargetFrame_CheckClassification", function(self)
		self.healthbar.LeftText:SetFontObject(SystemFont_Outline_Small);
		self.healthbar.RightText:SetFontObject(SystemFont_Outline_Small);
		self.manabar.LeftText:SetFontObject(SystemFont_Outline_Small);
		self.manabar.RightText:SetFontObject(SystemFont_Outline_Small);
		self.healthbar.TextString:SetFontObject(SystemFont_Outline_Small);
		self.manabar.TextString:SetFontObject(SystemFont_Outline_Small);
end)]]

--[[hooksecurefunc("TextStatusBar_UpdateTextStringWithValues", function(self)
		MainMenuBarExpText:SetFontObject(SystemFont_Outline_Small);
end)]]

-- NOTE: Blizzards API will return targets current and max healh as a percentage instead of exact value (ex. 100/100).
hooksecurefunc("TextStatusBar_UpdateTextStringWithValues",function(statusFrame, textString, value, valueMin, valueMax)
	local xpValue = UnitXP("player");
	local xpMaxValue = UnitXPMax("player");
	
	if( statusFrame.LeftText and statusFrame.RightText ) then
		statusFrame.LeftText:SetText("");
		statusFrame.RightText:SetText("");
		statusFrame.LeftText:Hide();
		statusFrame.RightText:Hide();
	end
	
	if ( ( tonumber(valueMax) ~= valueMax or valueMax > 0 ) and not ( statusFrame.pauseUpdates ) ) then
		statusFrame:Show();
		
		if ( (statusFrame.cvar and GetCVar(statusFrame.cvar) == "1" and statusFrame.textLockable) or statusFrame.forceShow ) then
			textString:Show();
		elseif ( statusFrame.lockShow > 0 and (not statusFrame.forceHideText) ) then
			textString:Show();
		else
			textString:SetText("");
			textString:Hide();
			return;
		end
		
	valueDisplay	=	M.Numb(value)
	valueMaxDisplay	=	M.Numb(valueMax)	
	xpValueDisplay	=	M.Numb(xpValue)
	xpMaxValueDisplay	=	M.Numb(xpMaxValue)							
		
		local textDisplay = GetCVar("statusTextDisplay");
		if ( value and valueMax > 0 and ( (textDisplay ~= "NUMERIC" and textDisplay ~= "NONE") or statusFrame.showPercentage ) and not statusFrame.showNumeric) then
			if ( value == 0 and statusFrame.zeroText ) then
				textString:SetText(statusFrame.zeroText);
				statusFrame.isZero = 1;
				textString:Show();
			elseif ( textDisplay == "BOTH" and not statusFrame.showPercentage) then
				if( statusFrame.LeftText and statusFrame.RightText ) then
					if(not statusFrame.powerToken or statusFrame.powerToken == "MANA") then
						statusFrame.LeftText:SetText(math.ceil((value / valueMax) * 100) .. "%");	-- % both.
						if value == 0 then statusFrame.LeftText:SetText(""); end
						statusFrame.LeftText:Show();
					end
					statusFrame.RightText:SetText(valueDisplay);	-- both rtext.
					if value == 0 then statusFrame.RightText:SetText(""); end
					statusFrame.RightText:Show();
					textString:Hide();
				else
					valueDisplay = "(" .. math.ceil((value / valueMax) * 100) .. "%) " .. xpValueDisplay .. " / " .. xpMaxValueDisplay;	-- xp both.
					if value == 0 then textString:SetText(""); end	
				end
				textString:SetText(valueDisplay);
			else
				valueDisplay = math.ceil((value / valueMax) * 100) .. "%";
				if ( statusFrame.prefix and (statusFrame.alwaysPrefix or not (statusFrame.cvar and GetCVar(statusFrame.cvar) == "1" and statusFrame.textLockable) ) ) then
					textString:SetText(statusFrame.prefix .. " " .. valueDisplay);	--	xp %.
				else
					textString:SetText(valueDisplay);	-- %.
				end
				if value == 0 then textString:SetText(""); end
			end
		elseif ( value == 0 and statusFrame.zeroText ) then
			textString:SetText(statusFrame.zeroText);
			statusFrame.isZero = 1;
			textString:Show();
			return;
		else
			statusFrame.isZero = nil;
			if ( statusFrame.prefix and (statusFrame.alwaysPrefix or not (statusFrame.cvar and GetCVar(statusFrame.cvar) == "1" and statusFrame.textLockable) ) ) then
				textString:SetText(statusFrame.prefix.." "..valueDisplay.." / "..valueMaxDisplay);		--	xp # / none, + none.
				MainMenuBarExpText:SetText(statusFrame.prefix.." "..xpValueDisplay .. "  / " .. xpMaxValueDisplay);		-- xp override.
			elseif valueMax == value then
			  textString:SetText(valueMaxDisplay)
			else
				textString:SetText(valueDisplay.." / "..valueMaxDisplay);		-- #.
			end
			if value == 0 then textString:SetText("") end
		end
	else
		textString:Hide();
		textString:SetText("");
		if ( not statusFrame.alwaysShow ) then
			statusFrame:Hide();
		else
			statusFrame:SetValue(0);
		end
	end
end)

-- Dead, Ghost and Offline text.
hooksecurefunc("TextStatusBar_UpdateTextStringWithValues",function(self)
	local textDisplay = GetCVar("statusTextDisplay");
	
	if UnitIsDeadOrGhost("player") then
		if textDisplay == "BOTH" then
			PlayerFrameHealthBarTextLeft:Hide();
			PlayerFrameHealthBarTextRight:Hide();
			PlayerFrameManaBarTextLeft:Hide();
			PlayerFrameManaBarTextRight:Hide();
		else
			PlayerFrameHealthBarText:Hide();
			PlayerFrameManaBarText:Hide();
		end
	else
	end
	if UnitIsDead("player") then
		PlayerFrameDeadText:Show();
		PlayerFrameGhostText:Hide();
	elseif UnitIsGhost("player") then
		PlayerFrameDeadText:Hide();
		PlayerFrameGhostText:Show();
	else
		PlayerFrameDeadText:Hide();
		PlayerFrameGhostText:Hide();
	end
	
	if UnitIsDeadOrGhost("target") or not UnitIsConnected("target") then
		if textDisplay == "BOTH" then
			TargetFrameHealthBarTextLeft:Hide();
			TargetFrameHealthBarTextRight:Hide();
			TargetFrameManaBarTextLeft:Hide();
			TargetFrameManaBarTextRight:Hide();
		else
			TargetFrameHealthBarText:Hide();
			TargetFrameManaBarText:Hide();
		end
	else
	end
	if UnitIsDead("target") then
		TargetFrameTextureFrameDeadText:Show();
		TargetFrameTextureFrameGhostText:Hide();
	elseif UnitIsGhost("target") then
		TargetFrameTextureFrameDeadText:Hide();
		TargetFrameTextureFrameGhostText:Show();
	else
		TargetFrameTextureFrameDeadText:Hide();
		TargetFrameTextureFrameGhostText:Hide();
	end
	if not UnitIsConnected("target") then
		TargetFrameTextureFrameOfflineText:Show();
		TargetFrameManaBar:Hide();
		
	else
		TargetFrameTextureFrameOfflineText:Hide();
	end
	
end)

--	Player frame.
hooksecurefunc("PlayerFrame_ToPlayerArt", function(self)
	self.healthbar:SetStatusBarTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-StatusBar");
	PlayerStatusTexture:SetTexture("Interface\\AddOns\\_ShiGuang\\Media\\Modules\\UFs\\UI-Player-Status");
	PlayerStatusTexture:ClearAllPoints();
	PlayerStatusTexture:SetPoint("CENTER", PlayerFrame, "CENTER",16, 8);
	PlayerFrameBackground:SetWidth(120);
	self.name:Hide();
	--self.name:SetPoint("CENTER", PlayerFrame, "CENTER",50.5, 36);
	self.healthbar:SetPoint("TOPLEFT",108,-24);
	self.healthbar:SetHeight(28);
	self.healthbar.LeftText:SetPoint("LEFT",self.healthbar,"LEFT",5,0);	
	self.healthbar.RightText:SetPoint("RIGHT",self.healthbar,"RIGHT",-5,0);
	self.healthbar.TextString:SetPoint("CENTER", self.healthbar, "CENTER", 0, 0);
	self.manabar:SetPoint("TOPLEFT",108,-51);
	self.manabar.LeftText:SetPoint("LEFT",self.manabar,"LEFT",5,-1)		;
	self.manabar.RightText:SetPoint("RIGHT",self.manabar,"RIGHT",-4,-1);
	self.manabar.TextString:SetPoint("CENTER",self.manabar,"CENTER",0,-1);
	--PlayerFrameGroupIndicatorText:SetPoint("BOTTOMLEFT", PlayerFrame,"TOP",0,-20);
	PlayerFrameGroupIndicatorLeft:Hide();
	PlayerFrameGroupIndicatorMiddle:Hide();
	PlayerFrameGroupIndicatorRight:Hide();
	PlayerFrameTexture:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-TargetingFrame");
	PlayerPVPIcon:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-PVP-FFA");
	--PlayerPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA");
end)

hooksecurefunc("PlayerFrame_UpdatePvPStatus", function()
	local factionGroup, factionName = UnitFactionGroup("player");
	if ( factionGroup and factionGroup ~= "Neutral" and UnitIsPVP("player") ) then
			PlayerPVPIcon:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-PVP-"..factionGroup);
			--PlayerPVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup);
	end
end)

--	Player vehicle frame.
hooksecurefunc("PlayerFrame_ToVehicleArt", function(self, vehicleType)
		if ( vehicleType == "Natural" ) then
		PlayerFrameVehicleTexture:SetTexture("Interface\\Vehicles\\UI-Vehicle-Frame-Organic");
		PlayerFrameFlash:SetTexture("Interface\\Vehicles\\UI-Vehicle-Frame-Organic-Flash");
		PlayerFrameFlash:SetTexCoord(-0.02, 1, 0.07, 0.86);
		self.healthbar:SetSize(103,12);
		self.healthbar:SetPoint("TOPLEFT",116,-41);
		self.manabar:SetSize(103,12);
		self.manabar:SetPoint("TOPLEFT",116,-52);
	else
		PlayerFrameVehicleTexture:SetTexture("Interface\\Vehicles\\UI-Vehicle-Frame");
		PlayerFrameFlash:SetTexture("Interface\\Vehicles\\UI-Vehicle-Frame-Flash");
		PlayerFrameFlash:SetTexCoord(-0.02, 1, 0.07, 0.86);
		self.healthbar:SetSize(100,12);
		self.healthbar:SetPoint("TOPLEFT",119,-41);
		self.manabar:SetSize(100,12);
		self.manabar:SetPoint("TOPLEFT",119,-52);
	end
	PlayerName:SetPoint("CENTER",50,23);
	PlayerFrameBackground:SetWidth(114);
end)

hooksecurefunc("PlayerFrame_ToPlayerArt", function()
	PetFrameHealthBarTextRight:SetPoint("RIGHT",PetFrameHealthBar,"RIGHT",2,0);
	PetFrameManaBarTextRight:SetPoint("RIGHT",PetFrameManaBar,"RIGHT",2,-5);
		PetFrameHealthBarTextLeft:SetPoint("LEFT",PetFrameHealthBar,"LEFT",0,0);
		PetFrameHealthBarTextRight:SetPoint("RIGHT",PetFrameHealthBar,"RIGHT",2,0);
		PetFrameManaBarText:SetPoint("CENTER",PetFrameManaBar,"CENTER",0,-3);
		PetFrameManaBarTextLeft:SetPoint("LEFT",PetFrameManaBar,"LEFT",0,-3);
		PetFrameManaBarTextRight:SetPoint("RIGHT",PetFrameManaBar,"RIGHT",2,-3);
		PetFrameHealthBarText:SetFontObject(SystemFont_Outline_Small);
		PetFrameHealthBarTextLeft:SetFontObject(SystemFont_Outline_Small);
		PetFrameHealthBarTextRight:SetFontObject(SystemFont_Outline_Small);
		PetFrameManaBarText:SetFontObject(SystemFont_Outline_Small);
		PetFrameManaBarTextLeft:SetFontObject(SystemFont_Outline_Small);
		PetFrameManaBarTextRight:SetFontObject(SystemFont_Outline_Small);
end)

hooksecurefunc("PetFrame_Update", function(self, override)
	if ( (not PlayerFrame.animating) or (override) ) then
		if ( UnitIsVisible(self.unit) and PetUsesPetFrame() and not PlayerFrame.vehicleHidesPet ) then
			if ( UnitPowerMax(self.unit) == 0 ) then
					PetFrameTexture:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-SmallTargetingFrame-NoMana");
					--PetFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-SmallTargetingFrame-NoMana");
				PetFrameManaBarText:Hide();
			else
					PetFrameTexture:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-SmallTargetingFrame");
					--PetFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-SmallTargetingFrame");
			end
		end
	end
end)

local function petFrameBg()
	local f = CreateFrame("Frame",nil,PetFrame)
	f:SetFrameStrata("BACKGROUND")
	f:SetSize(70,18);
	local t = f:CreateTexture(nil,"BACKGROUND")
	t:SetColorTexture(0, 0, 0, 0.5)
	t:SetAllPoints(f)
	f.texture = t
	f:SetPoint("CENTER",16,-5);
	f:Show()
end
petFrameBg();

--	Target frame
hooksecurefunc("TargetFrame_CheckClassification", function(self, forceNormalTexture)
	local classification = UnitClassification(self.unit);
	self.highLevelTexture:ClearAllPoints();
	self.highLevelTexture:SetPoint("CENTER", self.levelText, "CENTER", 1,0);
	self.deadText:SetPoint("CENTER", self.healthbar, "CENTER",0,0);
	self.unconsciousText:SetPoint("CENTER", self.manabar, "CENTER",0,0);
	self.nameBackground:Hide();
	if UnitIsCivilian(self.unit) then
		self.name:SetTextColor(1.0,0,0);
	else
		self.name:SetTextColor(1.0,0.82,0,1);
	end
	-- self.threatIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash");
	self.name:SetPoint("LEFT", self, 15, 36);
	self.healthbar:SetSize(119, 28);
	self.healthbar:SetPoint("TOPLEFT", 5, -24);
	self.healthbar.LeftText:SetPoint("LEFT", self.healthbar, "LEFT", 5, 0);
	self.healthbar.RightText:SetPoint("RIGHT", self.healthbar, "RIGHT", -3, 0);
	self.healthbar.TextString:SetPoint("CENTER", self.healthbar, "CENTER", 0, 0);
	self.manabar.LeftText:SetPoint("LEFT", self.manabar, "LEFT", 2, -1);	
	self.manabar.RightText:ClearAllPoints();
	self.manabar.RightText:SetPoint("RIGHT", self.manabar, "RIGHT", -2, -1);
	self.manabar.TextString:SetPoint("CENTER", self.manabar, "CENTER", 0, -1);
	-- TargetFrame.threatNumericIndicator:SetPoint("BOTTOM", PlayerFrame, "TOP", 72, -21);
	-- FocusFrame.threatNumericIndicator:SetAlpha(0);
	local path = "Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\";
	if ( forceNormalTexture ) then
		self.borderTexture:SetTexture(path.."UI-TargetingFrame");
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 88, -8, "NumberFontNormalLarge", 36)
	elseif ( classification == "minus" ) then
		self.borderTexture:SetTexture(path.."UI-TargetingFrame-Minus");
		forceNormalTexture = true;
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 66, 0, "NumberFontNormalLarge", 36)
	elseif ( classification == "worldboss" or classification == "elite" ) then
		self.borderTexture:SetTexture(path.."UI-TargetingFrame-Elite");
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 102, -8, "NumberFontNormalLarge", 36)
	elseif ( classification == "rareelite" ) then
		self.borderTexture:SetTexture(path.."UI-TargetingFrame-Rare-Elite");
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 102, -8, "NumberFontNormalLarge", 36)
	elseif ( classification == "rare" ) then
		self.borderTexture:SetTexture(path.."UI-TargetingFrame-Rare");
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 102, -8, "NumberFontNormalLarge", 36)
	else
		self.borderTexture:SetTexture(path.."UI-TargetingFrame");
		forceNormalTexture = true;
		CreateBarPctText(TargetFrame, "LEFT", "RIGHT", 88, -8, "NumberFontNormalLarge", 36)
	end
	if ( forceNormalTexture ) then
		self.haveElite = nil;
		if ( classification == "minus" ) then
			self.Background:SetSize(119,12);
			self.Background:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 7, 47);
			self.name:SetPoint("LEFT", self, 16, 19);
			self.healthbar:ClearAllPoints();
			self.healthbar:SetPoint("LEFT", 5, 3);
			self.healthbar:SetHeight(12);
			self.healthbar.LeftText:SetPoint("LEFT", self.healthbar, "LEFT", 3, 0);
			self.healthbar.RightText:SetPoint("RIGHT", self.healthbar, "RIGHT", -2, 0);
		else
			self.Background:SetSize(119,42);
			self.Background:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 7, 35);
		end
		if ( self.threatIndicator ) then
			if ( classification == "minus" ) then
				self.threatIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Minus-Flash");
				self.threatIndicator:SetTexCoord(0, 1, 0, 1);
				self.threatIndicator:SetWidth(256);
				self.threatIndicator:SetHeight(128);
				self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -24, 0);
			else
				self.threatIndicator:SetTexCoord(0, 0.9453125, 0, 0.181640625);
				self.threatIndicator:SetWidth(242);
				self.threatIndicator:SetHeight(93);
				self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -24, 0);
			end
		end	
	else
		self.haveElite = true;
		self.Background:SetSize(119,42);
		if ( self.threatIndicator ) then
			self.threatIndicator:SetTexCoord(0, 0.9453125, 0.181640625, 0.400390625);
			self.threatIndicator:SetWidth(242);
			self.threatIndicator:SetHeight(112);
		end		
	end
	self.healthbar.lockColor = true;
	self.healthbar:SetStatusBarTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-StatusBar");
	
	if ( self.showPVP ) then
		local factionGroup = UnitFactionGroup(self.unit);
		if ( UnitIsPVPFreeForAll(self.unit) ) then
				self.pvpIcon:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-PVP-FFA");
				--self.pvpIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA");
		elseif ( factionGroup and factionGroup ~= "Neutral" and UnitIsPVP(self.unit) ) then
				self.pvpIcon:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-PVP-"..factionGroup);
				--self.pvpIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup);
		end
		if (UnitIsCivilian(self.unit)) then
				self.questIcon:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\PortraitWarningBadge");
			self.questIcon:Show();
		else
			self.questIcon:Hide();
		end
	end
end)


-- Mana texture
hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
	local powerType, powerToken, altR, altG, altB = UnitPowerType(manaBar.unit);
	local info = PowerBarColor[powerToken];
	if ( info ) then
		if ( not manaBar.lockColor ) then
			if not ( info.atlas ) then
				manaBar:SetStatusBarTexture("Interface\\Addons\\_ShiGuang\\Media\\Skullflower3");
			end
		end
	end
end)

--	ToT
local function totFrame()
	TargetFrameToTTextureFrameDeadText:ClearAllPoints();
	TargetFrameToTTextureFrameDeadText:SetPoint("CENTER", "TargetFrameToTHealthBar","CENTER",1, 0);
	TargetFrameToTTextureFrameUnconsciousText:ClearAllPoints();
	TargetFrameToTTextureFrameUnconsciousText:SetPoint("CENTER", "TargetFrameToTHealthBar","CENTER",1, 0);
	TargetFrameToTTextureFrameName:SetSize(65,10);
	TargetFrameToTHealthBar:ClearAllPoints();
	TargetFrameToTHealthBar:SetPoint("TOPLEFT", 45, -15);
    TargetFrameToTHealthBar:SetHeight(10);
    TargetFrameToTManaBar:ClearAllPoints();
    TargetFrameToTManaBar:SetPoint("TOPLEFT", 45, -25);
    TargetFrameToTManaBar:SetHeight(5);
	TargetFrameToTBackground:SetSize(50,14);
	TargetFrameToTBackground:ClearAllPoints();
	TargetFrameToTBackground:SetPoint("CENTER", "TargetFrameToT","CENTER",20, 0);
	TargetFrameToTTextureFrameTexture:SetTexture("Interface\\Addons\\_ShiGuang\\Media\\Modules\\UFs\\UI-TargetofTargetFrame");

end
hooksecurefunc("TargetofTarget_Update", totFrame)
hooksecurefunc("TargetFrame_CheckClassification", totFrame)
--------------------------------------------------------------------------------------whoa end