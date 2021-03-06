local _, ns = ...
local M, R, U, I = unpack(ns)
local MISC = M:RegisterModule("Misc")

local _G = getfenv(0)
local tonumber = tonumber
local InCombatLockdown, IsModifiedClick, IsAltKeyDown = InCombatLockdown, IsModifiedClick, IsAltKeyDown
local GetNumAuctionItems, GetAuctionItemInfo = GetNumAuctionItems, GetAuctionItemInfo
local FauxScrollFrame_GetOffset, SetMoneyFrameColor = FauxScrollFrame_GetOffset, SetMoneyFrameColor
local GetItemInfo = GetItemInfo
local BuyMerchantItem = BuyMerchantItem
local GetMerchantItemLink = GetMerchantItemLink
local GetMerchantItemMaxStack = GetMerchantItemMaxStack
local GetItemQualityColor = GetItemQualityColor
local GetTime, GetCVarBool, SetCVar = GetTime, GetCVarBool, SetCVar
local GetNumLootItems, LootSlot = GetNumLootItems, LootSlot
local GetInstanceInfo = GetInstanceInfo
local IsGuildMember, BNGetGameAccountInfoByGUID, C_FriendList_IsFriend = IsGuildMember, BNGetGameAccountInfoByGUID, C_FriendList.IsFriend

--[[
	Miscellaneous 各种有用没用的小玩意儿
]]
local MISC_LIST = {}

function MISC:RegisterMisc(name, func)
	if not MISC_LIST[name] then
		MISC_LIST[name] = func
	end
end

function MISC:OnLogin()
	for name, func in next, MISC_LIST do
		if name and type(func) == "function" then
			func()
		end
	end

	-- Init
	self:UIWidgetFrameMover()
	self:MoveDurabilityFrame()
	self:MoveTicketStatusFrame()
	self:UpdateFasterLoot()
	self:UpdateErrorBlocker()
	self:TradeTargetInfo()
	self:MenuButton_Add()
	self:AutoDismount()
	self:BidPriceHighlight()
	self:BlockStrangerInvite()
	self:xMerchant()
	self:SorasThreat()

	-- Max camera distancee
	if tonumber(GetCVar("cameraDistanceMaxZoomFactor")) <= 2.6 then
		SetCVar("cameraDistanceMaxZoomFactor", 2.6)
	end

	-- Auto chatBubbles
	if MaoRUIDB["AutoBubbles"] then
		local function updateBubble()
			local name, instType = GetInstanceInfo()
			if name and instType == "raid" then
				SetCVar("chatBubbles", 1)
			else
				SetCVar("chatBubbles", 0)
			end
		end
		M:RegisterEvent("PLAYER_ENTERING_WORLD", updateBubble)
	end

	-- Readycheck sound on master channel
	M:RegisterEvent("READY_CHECK", function()
		PlaySound(SOUNDKIT.READY_CHECK, "master")
	end)

	-- Instant delete
	hooksecurefunc(StaticPopupDialogs["DELETE_GOOD_ITEM"], "OnShow", function(self)
		if MaoRUIPerDB["Misc"]["InstantDelete"] then
			self.editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
		end
	end)

	-- Fix blizz error
	MAIN_MENU_MICRO_ALERT_PRIORITY = MAIN_MENU_MICRO_ALERT_PRIORITY or {}

	-- Fix blizz bug in addon list
	local _AddonTooltip_Update = AddonTooltip_Update
	function AddonTooltip_Update(owner)
		if not owner then return end
		if owner:GetID() < 1 then return end
		_AddonTooltip_Update(owner)
	end
end

-- Reanchor Vehicle
function MISC:VehicleSeatMover()
	local frame = CreateFrame("Frame", "NDuiVehicleSeatMover", UIParent)
	frame:SetSize(125, 125)
	M.Mover(frame, U["VehicleSeat"], "VehicleSeat", {"BOTTOMRIGHT", UIParent, -285, 21})

	hooksecurefunc(VehicleSeatIndicator, "SetPoint", function(self, _, parent)
		if parent == "MinimapCluster" or parent == MinimapCluster then
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", frame)
		end
	end)
end

-- Reanchor UIWidgetBelowMinimapContainerFrame
function MISC:UIWidgetFrameMover()
	local frame = CreateFrame("Frame", "NDuiUIWidgetMover", UIParent)
	frame:SetSize(210, 60)
	M.Mover(frame, U["UIWidgetFrame"], "UIWidgetFrame", {"TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -43})

	hooksecurefunc(UIWidgetBelowMinimapContainerFrame, "SetPoint", function(self, _, parent)
		if parent == "MinimapCluster" or parent == MinimapCluster then
			self:ClearAllPoints()
			self:SetPoint("TOP", frame)
		end
	end)
end

-- Reanchor DurabilityFrame
function MISC:MoveDurabilityFrame()
	hooksecurefunc(DurabilityFrame, "SetPoint", function(self, _, parent)
		if parent ~= Minimap then
			self:ClearAllPoints()
			self:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -30)
		end
	end)
end

-- Reanchor TicketStatusFrame
function MISC:MoveTicketStatusFrame()
	hooksecurefunc(TicketStatusFrame, "SetPoint", function(self, relF)
		if relF == "TOPRIGHT" then
			self:ClearAllPoints()
			self:SetPoint("TOP", UIParent, "TOP", -400, -20)
		end
	end)
end

-- Faster Looting
local lootDelay = 0
function MISC:DoFasterLoot()
	if GetLootMethod() == "master" then return end

	if GetTime() - lootDelay >= .3 then
		lootDelay = GetTime()
		if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
			for i = GetNumLootItems(), 1, -1 do
				LootSlot(i)
			end
			lootDelay = GetTime()
		end
	end
end

function MISC:UpdateFasterLoot()
	if MaoRUIPerDB["Misc"]["FasterLoot"] then
		M:RegisterEvent("LOOT_READY", MISC.DoFasterLoot)
	else
		M:UnregisterEvent("LOOT_READY", MISC.DoFasterLoot)
	end
end

-- Hide errors in combat
local erList = {
	[ERR_ABILITY_COOLDOWN] = true,
	[ERR_ATTACK_MOUNTED] = true,
	[ERR_OUT_OF_ENERGY] = true,
	[ERR_OUT_OF_FOCUS] = true,
	[ERR_OUT_OF_HEALTH] = true,
	[ERR_OUT_OF_MANA] = true,
	[ERR_OUT_OF_RAGE] = true,
	[ERR_OUT_OF_RANGE] = true,
	[ERR_OUT_OF_RUNES] = true,
	[ERR_OUT_OF_HOLY_POWER] = true,
	[ERR_OUT_OF_RUNIC_POWER] = true,
	[ERR_OUT_OF_SOUL_SHARDS] = true,
	[ERR_OUT_OF_ARCANE_CHARGES] = true,
	[ERR_OUT_OF_COMBO_POINTS] = true,
	[ERR_OUT_OF_CHI] = true,
	[ERR_OUT_OF_POWER_DISPLAY] = true,
	[ERR_SPELL_COOLDOWN] = true,
	[ERR_ITEM_COOLDOWN] = true,
	[SPELL_FAILED_BAD_IMPLICIT_TARGETS] = true,
	[SPELL_FAILED_BAD_TARGETS] = true,
	[SPELL_FAILED_CASTER_AURASTATE] = true,
	[SPELL_FAILED_NO_COMBO_POINTS] = true,
	[SPELL_FAILED_SPELL_IN_PROGRESS] = true,
	[SPELL_FAILED_TARGET_AURASTATE] = true,
	[ERR_NO_ATTACK_TARGET] = true,
}

local isRegistered = true
function MISC:ErrorBlockerOnEvent(_, text)
	if InCombatLockdown() and erList[text] then
		if isRegistered then
			UIErrorsFrame:UnregisterEvent(self)
			isRegistered = false
		end
	else
		if not isRegistered then
			UIErrorsFrame:RegisterEvent(self)
			isRegistered = true
		end
	end
end

function MISC:UpdateErrorBlocker()
	if MaoRUIPerDB["Misc"]["HideErrors"] then
		M:RegisterEvent("UI_ERROR_MESSAGE", MISC.ErrorBlockerOnEvent)
	else
		isRegistered = true
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
		M:UnregisterEvent("UI_ERROR_MESSAGE", MISC.ErrorBlockerOnEvent)
	end
end

-- TradeFrame hook
function MISC:TradeTargetInfo()
	local infoText = M.CreateFS(TradeFrame, 16, "")
	infoText:ClearAllPoints()
	infoText:SetPoint("TOP", TradeFrameRecipientNameText, "BOTTOM", 0, -5)

	local function updateColor()
		local r, g, b = M.UnitColor("NPC")
		TradeFrameRecipientNameText:SetTextColor(r, g, b)

		local guid = UnitGUID("NPC")
		if not guid then return end
		local text = "|cffff0000"..U["Stranger"]
		if BNGetGameAccountInfoByGUID(guid) or C_FriendList_IsFriend(guid) then
			text = "|cffffff00"..FRIEND
		elseif IsGuildMember(guid) then
			text = "|cff00ff00"..GUILD
		end
		infoText:SetText(text)
	end
	hooksecurefunc("TradeFrame_Update", updateColor)
end

-- Show BID and highlight price
function MISC:BidPriceHighlight()
	if IsAddOnLoaded("Auc-Advanced") then return end
	local function setupMisc(event, addon)
		if addon == "Blizzard_AuctionUI" then
			hooksecurefunc("AuctionFrameBrowse_Update", function()
				local numBatchAuctions = GetNumAuctionItems("list")
				local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame)
				local name, buyoutPrice, bidAmount, hasAllInfo
				for i = 1, NUM_BROWSE_TO_DISPLAY do
					local index = offset + i + (NUM_AUCTION_ITEMS_PER_PAGE * AuctionFrameBrowse.page)
					local shouldHide = index > (numBatchAuctions + (NUM_AUCTION_ITEMS_PER_PAGE * AuctionFrameBrowse.page))
					if not shouldHide then
						name, _, count, _, _, _, _, _, _, buyoutPrice, bidAmount, _, _, _, _, _, _, hasAllInfo = GetAuctionItemInfo("list", offset + i)
						if not hasAllInfo then shouldHide = true end
					end
					if not shouldHide then
						local alpha = .5
						local color = "yellow"
						local buttonName = "BrowseButton"..i
						local itemName = _G[buttonName.."Name"]
						local moneyFrame = _G[buttonName.."MoneyFrame"]
						local buyoutMoney = _G[buttonName.."BuyoutFrameMoney"]
						-- AH Gold Icon
						local function formats(value)
							local str = ''
							if value > 9999 then
								str = str .. format('|c00ffd700%d●|r', floor(value / 10000))
							end
							if value > 99 and floor(value/100)%100 ~= 0 then
								str = str .. format('|c00c7c7cf%d●|r', (floor(value / 100) % 100))
							end
							if floor(value)%100 ~= 0 then
								str = str .. format('|c00eda55f%d●|r', (floor(value) % 100))
							end
							return str
						end
						if buyoutPrice >= 1e6 then color = "red" end
							if bidAmount > 0 then
								name = name .. " |cffffff00[￥]|r"
								alpha = 1.0
							end
							if (buyoutPrice > 0) and (count > 1) then
								name = name .. " |cffffff00["..formats(floor(buyoutPrice / count)).."|cffffff00]|r"
							end
							itemName:SetText(name)
							moneyFrame:SetAlpha(alpha)
							SetMoneyFrameColor(buyoutMoney:GetName(), color)
					end
				end
			end)
			M:UnregisterEvent(event, setupMisc)
		end
	end
	M:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- ALT+RightClick to buy a stack
do
	local cache = {}
	local itemLink, id

	StaticPopupDialogs["BUY_STACK"] = {
		text = CHARMS_BUY_STACK,
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			if not itemLink then return end
			BuyMerchantItem(id, GetMerchantItemMaxStack(id))
			cache[itemLink] = true
			itemLink = nil
		end,
		hideOnEscape = 1,
		hasItemFrame = 1,
	}

	local _MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
	function MerchantItemButton_OnModifiedClick(self, ...)
		if IsAltKeyDown() then
			id = self:GetID()
			itemLink = GetMerchantItemLink(id)
			if not itemLink then return end
			local name, _, quality, _, _, _, _, maxStack, _, texture = GetItemInfo(itemLink)
			if maxStack and maxStack > 1 then
				if not cache[itemLink] then
					local r, g, b = GetItemQualityColor(quality or 1)
					StaticPopup_Show("BUY_STACK", " ", " ", {["texture"] = texture, ["name"] = name, ["color"] = {r, g, b, 1}, ["link"] = itemLink, ["index"] = id, ["count"] = maxStack})
				else
					BuyMerchantItem(id, GetMerchantItemMaxStack(id))
				end
			end
		end

		_MerchantItemButton_OnModifiedClick(self, ...)
	end
end

-- Temporary taint fix
do
	InterfaceOptionsFrameCancel:SetScript("OnClick", function()
		InterfaceOptionsFrameOkay:Click()
	end)
end

-- Select target when click on raid units
do
	local function fixRaidGroupButton()
		for i = 1, 40 do
			local bu = _G["RaidGroupButton"..i]
			if bu and bu.unit and not bu.clickFixed then
				bu:SetAttribute("type", "target")
				bu:SetAttribute("unit", bu.unit)

				bu.clickFixed = true
			end
		end
	end

	local function setupMisc(event, addon)
		if event == "ADDON_LOADED" and addon == "Blizzard_RaidUI" then
			if not InCombatLockdown() then
				fixRaidGroupButton()
			else
				M:RegisterEvent("PLAYER_REGEN_ENABLED", setupMisc)
			end
			M:UnregisterEvent(event, setupMisc)
		elseif event == "PLAYER_REGEN_ENABLED" then
			if RaidGroupButton1 and RaidGroupButton1:GetAttribute("type") ~= "target" then
				fixRaidGroupButton()
				M:UnregisterEvent(event, setupMisc)
			end
		end
	end

	M:RegisterEvent("ADDON_LOADED", setupMisc)
end

-- Add friend and guild invite on target menu
function MISC:MenuButton_OnClick(info)
	local name, server = UnitName(info.unit)
	if server and server ~= "" then name = name.."-"..server end

	if info.value == "name" then
		if MailFrame:IsShown() then
			MailFrameTab_OnClick(nil, 2)
			SendMailNameEditBox:SetText(name)
			SendMailNameEditBox:HighlightText()
		else
			local editBox = ChatEdit_ChooseBoxForSend()
			local hasText = (editBox:GetText() ~= "")
			ChatEdit_ActivateChat(editBox)
			editBox:Insert(name)
			if not hasText then editBox:HighlightText() end
		end
	elseif info.value == "guild" then
		GuildInvite(name)
	end
end

function MISC:MenuButton_Show(_, unit)
	if UIDROPDOWNMENU_MENU_LEVEL > 1 then return end

	if unit and (unit == "target" or string.find(unit, "party") or string.find(unit, "raid")) then
		local info = UIDropDownMenu_CreateInfo()
		info.text = MISC.MenuButtonList["name"]
		info.arg1 = {value = "name", unit = unit}
		info.func = MISC.MenuButton_OnClick
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)

		if IsInGuild() and UnitIsPlayer(unit) and not UnitCanAttack("player", unit) and not UnitIsUnit("player", unit) then
			info = UIDropDownMenu_CreateInfo()
			info.text = MISC.MenuButtonList["guild"]
			info.arg1 = {value = "guild", unit = unit}
			info.func = MISC.MenuButton_OnClick
			info.notCheckable = true
			UIDropDownMenu_AddButton(info)
		end
	end
end

function MISC:MenuButton_Add()
	if not MaoRUIPerDB["Misc"]["EnhancedMenu"] then return end

	MISC.MenuButtonList = {
		["name"] = COPY_NAME,
		["guild"] = gsub(CHAT_GUILD_INVITE_SEND, HEADER_COLON, ""),
	}
	hooksecurefunc("UnitPopup_ShowMenu", MISC.MenuButton_Show)
end

-- Auto dismount and auto stand
function MISC:AutoDismount()
	if not MaoRUIPerDB["Misc"]["AutoDismount"] then return end

	local standString = {
		[ERR_LOOT_NOTSTANDING] = true,
		[SPELL_FAILED_NOT_STANDING] = true,
	}

	local dismountString = {
		[ERR_ATTACK_MOUNTED] = true,
		[ERR_NOT_WHILE_MOUNTED] = true,
		[ERR_TAXIPLAYERALREADYMOUNTED] = true,
		[SPELL_FAILED_NOT_MOUNTED] = true,
	}

	local function updateEvent(event, ...)
		local _, msg = ...
		if standString[msg] then
			DoEmote("STAND")
		elseif dismountString[msg] then
			Dismount()
		end
	end
	M:RegisterEvent("UI_ERROR_MESSAGE", updateEvent)
end

-- Block invite from strangers
function MISC:BlockStrangerInvite()
	M:RegisterEvent("PARTY_INVITE_REQUEST", function(_, _, _, _, _, _, _, guid)
		if MaoRUIPerDB["Misc"]["BlockInvite"] and not (IsGuildMember(guid) or BNGetGameAccountInfoByGUID(guid) or C_FriendList_IsFriend(guid)) then
			DeclineGroup()
			StaticPopup_Hide("PARTY_INVITE")
		end
	end)
end

--[[hooksecurefunc("TextStatusBar_UpdateTextStringWithValues",function(self,textString,value,_,maxValue)  ---	Custom status text format.
	if self.RightText and value and maxValue>0 and not self.showPercentage and GetCVar("statusTextDisplay")=="BOTH" then
		self.RightText:SetText(M.Numb(value))
		if value == 0 then self.RightText:SetText(" "); end
	end
	if maxValue>0 and GetCVar("statusTextDisplay")=="NUMERIC" then 
     if maxValue == value then textString:SetText(M.Numb(maxValue))
     else textString:SetText(M.Numb(value) .." / "..M.Numb(maxValue))
       --textString:SetText(tostring(math.ceil((value / maxValue) * 100)).."% "..maxValue.." ")
     end 
   end 
   for i = 1, 4 do
		_G["PartyMemberFrame"..i.."HealthBarText"]:SetText(" ");
		_G["PartyMemberFrame"..i.."HealthBarTextLeft"]:SetText(" ");
		_G["PartyMemberFrame"..i.."HealthBarTextRight"]:SetText(" ");
		_G["PartyMemberFrame"..i.."ManaBarText"]:SetText(" ");
		_G["PartyMemberFrame"..i.."ManaBarTextLeft"]:SetText(" ");
		_G["PartyMemberFrame"..i.."ManaBarTextRight"]:SetText(" ");
	end
end)]]