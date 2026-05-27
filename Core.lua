local addonName, AF = ...

AF.frame = CreateFrame("Frame")

local EVENTS = {
	"ADDON_LOADED",
	"PLAYER_LOGIN",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"CHANNEL_UI_UPDATE",
	"CHAT_MSG_CHANNEL_NOTICE",
	"CHAT_MSG_ADDON",
	"CHAT_MSG_CHANNEL",
	"GET_ITEM_INFO_RECEIVED",
	"ITEM_DATA_LOAD_RESULT",
	"GUILD_ROSTER_UPDATE",
	"GUILD_TRADESKILL_UPDATE",
	"GUILD_RECIPE_KNOWN_BY_MEMBERS",
	"CRAFTINGORDERS_SHOW_CUSTOMER",
	"CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE",
	"CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS",
	"TRADE_SKILL_SHOW",
	"TRADE_SKILL_CLOSE",
	"TRADE_SKILL_LIST_UPDATE",
	"TRADE_SKILL_DATA_SOURCE_CHANGED",
	"SKILL_LINES_CHANGED",
	"SPELLS_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED",
	"PROFESSION_EQUIPMENT_CHANGED",
	"TRAIT_CONFIG_UPDATED",
	"TRAIT_NODE_CHANGED",
}

for _, event in ipairs(EVENTS) do
	AF.frame:RegisterEvent(event)
end

local AUTO_AVAILABILITY_EVENTS = {
	PLAYER_ENTERING_WORLD = true,
	ZONE_CHANGED = true,
	ZONE_CHANGED_INDOORS = true,
	ZONE_CHANGED_NEW_AREA = true,
	CHANNEL_UI_UPDATE = true,
	CHAT_MSG_CHANNEL_NOTICE = true,
}

local SCAN_CHANGE_EVENTS = {
	TRADE_SKILL_LIST_UPDATE = true,
	SKILL_LINES_CHANGED = true,
	SPELLS_CHANGED = true,
	PLAYER_EQUIPMENT_CHANGED = true,
	PROFESSION_EQUIPMENT_CHANGED = true,
	TRAIT_CONFIG_UPDATED = true,
	TRAIT_NODE_CHANGED = true,
}

function AF:OnAddonLoaded(name)
	if name ~= addonName then
		if name == "Blizzard_ProfessionsCustomerOrders" and self.InitializeCustomerOrderFormHook then
			self:InitializeCustomerOrderFormHook()
		end
		return
	end
	self:EnsureDB()
end

function AF:OnPlayerLogin()
	self:EnsureDB()
	self.playerName = self:GetPlayerFullName()
	self:SelectActiveArtisanProfile(self.playerName)
	self:SetAvailabilityMode(self.AVAILABILITY_UNAVAILABLE, true)

	self:InitializeComms()
	self:InitializeWhoStatus()
	self:InitializeGuild()
	self:InitializeMinimap()
	self:InitializeCustomerUI()
	self:InitializeCrafterUI()
	self:InitializeSlashCommands()
	self:InitializeTradeChat()
	self:InitializeOrderNotifications()
	self:InitializeOptions()
	self:CleanupCustomerCache()
	self:InitializeTutorial()
	self:InitializeEditMode()

	self:Print(self:Text("ADDON_LOADED"))
	C_Timer.After(3, function()
		AF:PrintDeprecatedScanWarning()
	end)
	self:QueueAutoAvailabilityRefresh()
end

function AF:GetAvailabilityMode()
	return self.availabilityMode or self.AVAILABILITY_UNAVAILABLE
end

function AF:IsAvailable()
	return self:GetAvailabilityMode() ~= self.AVAILABILITY_UNAVAILABLE
end

function AF:IsCurrentCharacterOnlyAvailable()
	return self:GetAvailabilityMode() == self.AVAILABILITY_CURRENT
end

function AF:SetAvailabilityMode(mode, silent)
	if mode ~= self.AVAILABILITY_CURRENT and mode ~= self.AVAILABILITY_ACCOUNT then
		mode = self.AVAILABILITY_UNAVAILABLE
	end
	local oldMode = self:GetAvailabilityMode()
	self.availabilityMode = mode
	self.available = mode ~= self.AVAILABILITY_UNAVAILABLE
	if mode ~= self.AVAILABILITY_UNAVAILABLE and self.db then
		self.db.lastAvailabilityMode = mode
	end
	if self.RefreshCrafterUIScanSafe then
		self:RefreshCrafterUIScanSafe()
	elseif self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
	if oldMode ~= mode then
		self:DebugLog("state", string.format("availabilityMode=%s silent=%s", tostring(mode), tostring(silent == true)))
	end
	if not silent and oldMode ~= mode then
		self:Print(self:Text("AVAILABILITY_CHANGED", self:GetAvailabilityModeText(mode)))
	end
end

function AF:GetAvailabilityModeText(mode)
	mode = mode or self:GetAvailabilityMode()
	if mode == self.AVAILABILITY_ACCOUNT then
		return self:Text("AVAILABILITY_ACCOUNT")
	end
	if mode == self.AVAILABILITY_CURRENT then
		return self:Text("AVAILABILITY_CURRENT")
	end
	return self:Text("UNAVAILABLE")
end

function AF:SetAvailable(value, silent)
	self:SetAvailabilityMode(value and self.AVAILABILITY_ACCOUNT or self.AVAILABILITY_UNAVAILABLE, silent)
end

function AF:ToggleAvailable()
	local mode = self:GetAvailabilityMode()
	if mode == self.AVAILABILITY_UNAVAILABLE then
		self:SetAvailabilityMode(self.AVAILABILITY_CURRENT)
	elseif mode == self.AVAILABILITY_CURRENT then
		self:SetAvailabilityMode(self.AVAILABILITY_ACCOUNT)
	else
		self:SetAvailabilityMode(self.AVAILABILITY_UNAVAILABLE)
	end
end

local function ContainsTradeChannelName(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" and AF:IsTradeChannelName(value) then
			return true
		end
	end
	return false
end

function AF:HasTradeChatAccess()
	if GetChannelList and ContainsTradeChannelName(GetChannelList()) then
		return true
	end
	return EnumerateServerChannels and ContainsTradeChannelName(EnumerateServerChannels()) or false
end

function AF:ShouldAutoBeAvailable()
	if self:IsInUnavailableActivity() then
		return false
	end
	if self:HasTradeChatAccess() then
		return true
	end
	return false
end

function AF:RefreshAutoAvailability(silent)
	if not self.db or not self.db.autoAvailability then
		return
	end
	if self:IsInCombatLocked() then
		self.deferredAutoAvailabilityRefresh = true
		return
	end
	local shouldBeAvailable = self:ShouldAutoBeAvailable()
	self:DebugLog("auto", string.format("refresh shouldBeAvailable=%s silent=%s", tostring(shouldBeAvailable), tostring(silent == true)))
	local availableMode = self.db.lastAvailabilityMode
	if availableMode ~= self.AVAILABILITY_CURRENT and availableMode ~= self.AVAILABILITY_ACCOUNT then
		availableMode = self.AVAILABILITY_ACCOUNT
	end
	self:SetAvailabilityMode(shouldBeAvailable and availableMode or self.AVAILABILITY_UNAVAILABLE, silent)
end

function AF:QueueAutoAvailabilityRefresh()
	if not self.db or not self.db.autoAvailability or self.autoAvailabilityQueued then
		return
	end
	if self:IsInCombatLocked() then
		self.deferredAutoAvailabilityRefresh = true
		return
	end
	self.autoAvailabilityQueued = true
	C_Timer.After(0.5, function()
		AF.autoAvailabilityQueued = false
		if AF:IsInCombatLocked() then
			AF.deferredAutoAvailabilityRefresh = true
			return
		end
		AF:RefreshAutoAvailability()
	end)
end

function AF:SetAutoAvailability(enabled)
	self.db.autoAvailability = enabled == true
	self:DebugLog("auto", "mode=" .. tostring(self.db.autoAvailability))
	self:Print(self:Text("AUTO_AVAILABILITY_CHANGED", self.db.autoAvailability and self:Text("ENABLED") or self:Text("DISABLED")))
	if self.db.autoAvailability then
		self:QueueAutoAvailabilityRefresh()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:ToggleAutoAvailability()
	self:SetAutoAvailability(not self.db.autoAvailability)
end

function AF:SetFastScan(enabled)
	self.db.fastScan = enabled == true
	if self.activeScan and self.ProcessScanQueue then
		self.scanProcessing = false
		self.scanQueueToken = (self.scanQueueToken or 0) + 1
		self:ProcessScanQueue()
	end
	if self.RefreshCrafterUIScanSafe then
		self:RefreshCrafterUIScanSafe()
	elseif self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:TryAttachProfessionUIs()
	if self.AttachCustomerUI then
		self:AttachCustomerUI()
	end
	if self.AttachCrafterUI then
		self:AttachCrafterUI()
	end
end

AF.frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		AF:OnAddonLoaded(...)
	elseif event == "PLAYER_LOGIN" then
		AF:OnPlayerLogin()
	elseif event == "PLAYER_REGEN_DISABLED" then
		if AF.activeScan then
			AF.deferredScanResume = true
		end
		if AF.PauseActiveProfessionScan then
			AF:PauseActiveProfessionScan(true)
		else
			AF.activeScan = nil
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if AF.HideDiscoveryChannelFromChat then
			AF:HideDiscoveryChannelFromChat()
		end
		if AF.deferredDiscoveryChannelJoin and AF.QueueDiscoveryChannelJoin then
			AF.deferredDiscoveryChannelJoin = nil
			AF:QueueDiscoveryChannelJoin(1)
		end
		if AF.deferredAutoAvailabilityRefresh then
			AF.deferredAutoAvailabilityRefresh = nil
			AF:QueueAutoAvailabilityRefresh()
		end
		if AF.deferredAutoScanReason and AF.QueueAutoScanForChange then
			local reason = AF.deferredAutoScanReason
			AF.deferredAutoScanReason = nil
			if reason == "PROFESSION_EQUIPMENT_CHANGED" then
				AF.pendingProfessionEquipmentSkillLineID = AF.deferredProfessionEquipmentSkillLineID
				AF.deferredProfessionEquipmentSkillLineID = nil
			end
			AF:QueueAutoScanForChange(reason)
		end
		if AF.deferredScanResume and AF.ResumeCurrentProfessionScanIfNeeded then
			AF.deferredScanResume = nil
			AF:ResumeCurrentProfessionScanIfNeeded()
		end
	elseif AUTO_AVAILABILITY_EVENTS[event] then
		if AF:IsInCombatLocked() then
			AF.deferredAutoAvailabilityRefresh = true
			return
		end
		if event == "PLAYER_ENTERING_WORLD" and AF.QueueDiscoveryChannelJoin then
			AF:QueueDiscoveryChannelJoin(8)
		end
		if (event == "CHANNEL_UI_UPDATE" or event == "CHAT_MSG_CHANNEL_NOTICE") and AF.HideDiscoveryChannelFromChat then
			AF:HideDiscoveryChannelFromChat()
			AF:HideDiscoveryChannelFromChat(0.5)
		end
		AF:QueueAutoAvailabilityRefresh()
	elseif event == "CHAT_MSG_ADDON" then
		if AF:IsInCombatLocked() then
			return
		end
		if AF.OnAddonMessage then
			AF:OnAddonMessage(...)
		end
	elseif event == "CHAT_MSG_CHANNEL" then
		if AF:IsInCombatLocked() then
			return
		end
		if AF.OnTradeChatMessage then
			AF:OnTradeChatMessage(...)
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
		if AF.OnItemDataLoaded then
			AF:OnItemDataLoaded(...)
		end
	elseif event == "GUILD_ROSTER_UPDATE" then
		if AF.QueueGuildRosterCacheRefresh then
			AF:QueueGuildRosterCacheRefresh(false)
		end
	elseif event == "GUILD_TRADESKILL_UPDATE" then
		AF.guildTradeSkillParsedAt = nil
		if AF.RefreshCustomerResults then
			AF:RefreshCustomerResults()
		end
	elseif event == "GUILD_RECIPE_KNOWN_BY_MEMBERS" then
		if AF.HandleGuildRecipeKnownByMembers then
			AF:HandleGuildRecipeKnownByMembers(...)
		end
	elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
		if AF:IsInCombatLocked() then
			return
		end
		C_Timer.After(0, function()
			if AF:IsInCombatLocked() then
				return
			end
			AF:TryAttachProfessionUIs()
			if AF.RefreshCustomerQuery then
				AF:RefreshCustomerQuery()
			end
		end)
	elseif event == "CRAFTINGORDERS_ORDER_PLACEMENT_RESPONSE" then
		if AF.OnOrderPlacementResponse then
			AF:OnOrderPlacementResponse(...)
		end
	elseif event == "CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS" then
		if AF.OnPersonalOrderCountsUpdated then
			AF:OnPersonalOrderCountsUpdated()
		end
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
		if AF:IsInCombatLocked() then
			return
		end
		local closeProfessionBook = event == "TRADE_SKILL_SHOW"
			and (AF:IsIntroTutorialActive() or AF:IsMinimapTutorialActive())
		if event == "TRADE_SKILL_SHOW" and AF.CloseIntroTutorial then
			AF:CloseIntroTutorial()
		end
		if closeProfessionBook and ProfessionsBookFrame and ProfessionsBookFrame:IsShown() then
			if HideUIPanel then
				HideUIPanel(ProfessionsBookFrame)
			else
				ProfessionsBookFrame:Hide()
			end
		end
		C_Timer.After(0, function()
			if AF:IsInCombatLocked() then
				return
			end
			AF:TryAttachProfessionUIs()
			if AF.RefreshCrafterUI then
				if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" and AF.RefreshCrafterUIScanSafe then
					AF:RefreshCrafterUIScanSafe()
				else
					AF:RefreshCrafterUI()
				end
			end
			local ownProfessionWindowOpen = AF:IsOwnProfessionWindowOpen()
			if event == "TRADE_SKILL_DATA_SOURCE_CHANGED" and ownProfessionWindowOpen and AF.QueueProfessionDataSourceProbe then
				AF:QueueProfessionDataSourceProbe()
			end
			if event == "TRADE_SKILL_SHOW" and ownProfessionWindowOpen and AF.StartProfessionEquipmentWatch then
				AF:StartProfessionEquipmentWatch()
			end
			if event == "TRADE_SKILL_SHOW" and ownProfessionWindowOpen and AF.ResumeCurrentProfessionScanIfNeeded then
				AF:ResumeCurrentProfessionScanIfNeeded()
			end
			if ownProfessionWindowOpen and AF.CaptureCurrentProfessionLink then
				AF:CaptureCurrentProfessionLink(nil, event)
			end
			if AF.TrySelectPendingProfessionRecipe then
				AF:TrySelectPendingProfessionRecipe()
			end
		end)
	elseif event == "TRADE_SKILL_CLOSE" then
		if AF.StopProfessionEquipmentWatch then
			AF:StopProfessionEquipmentWatch()
		end
		if AF.PauseActiveProfessionScan then
			AF:PauseActiveProfessionScan()
		else
			AF.activeScan = nil
		end
		if AF.ReleaseScanRuntimeMemory then
			AF:ReleaseScanRuntimeMemory("close")
		end
	elseif SCAN_CHANGE_EVENTS[event] then
		if AF:IsInCombatLocked() then
			AF.deferredAutoScanReason = event
			if event == "PROFESSION_EQUIPMENT_CHANGED" then
				AF.deferredProfessionEquipmentSkillLineID = ...
			end
			return
		end
		local ownProfessionWindowOpen = AF:IsOwnProfessionWindowOpen()
		if event == "PROFESSION_EQUIPMENT_CHANGED" and ownProfessionWindowOpen then
			AF.pendingProfessionEquipmentSkillLineID = ...
			AF.pendingProfessionEquipmentScan = true
		end
		if ownProfessionWindowOpen and AF.QueueAutoScanForChange then
			AF:QueueAutoScanForChange(event == "PLAYER_EQUIPMENT_CHANGED" and "PROFESSION_EQUIPMENT_CHANGED" or event)
		end
		if ownProfessionWindowOpen and AF.CaptureCurrentProfessionLink then
			AF:CaptureCurrentProfessionLink(nil, event)
		end
		if AF.TrySelectPendingProfessionRecipe then
			AF:TrySelectPendingProfessionRecipe()
		end
	end
end)
