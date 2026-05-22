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
		return
	end
	self:EnsureDB()
end

function AF:OnPlayerLogin()
	self:EnsureDB()
	self.playerName = self:GetPlayerFullName()
	self:SelectActiveArtisanProfile(self.playerName)
	self.available = false

	self:InitializeComms()
	self:InitializeWhoStatus()
	self:InitializeGuild()
	self:InitializeMinimap()
	self:InitializeCustomerUI()
	self:InitializeCrafterUI()
	self:InitializeSlashCommands()
	self:InitializeTradeChat()
	self:InitializeOptions()
	self:CleanupCustomerCache()
	self:InitializeTutorial()

	self:Print(self:Text("ADDON_LOADED"))
	self:QueueAutoAvailabilityRefresh()
end

function AF:SetAvailable(value, silent)
	local wasAvailable = self.available == true
	self.available = value == true
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if not silent and wasAvailable ~= self.available then
		self:Print(self:Text("AVAILABILITY_CHANGED", self.available and self:Text("ENABLED") or self:Text("DISABLED")))
	end
end

function AF:ToggleAvailable()
	self:SetAvailable(not self.available)
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
	return self:HasTradeChatAccess()
end

function AF:RefreshAutoAvailability(silent)
	if not self.db or not self.db.autoAvailability then
		return
	end
	if self:IsInCombatLocked() then
		self.deferredAutoAvailabilityRefresh = true
		return
	end
	self:SetAvailable(self:ShouldAutoBeAvailable(), silent)
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
	if self.RefreshCrafterUI then
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
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
		if AF:IsInCombatLocked() then
			return
		end
		local closeProfessionBook = event == "TRADE_SKILL_SHOW" and AF.IsIntroTutorialActive and AF:IsIntroTutorialActive()
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
				AF:RefreshCrafterUI()
			end
			local ownProfessionWindowOpen = AF.IsOwnProfessionWindowOpen and AF:IsOwnProfessionWindowOpen()
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
	elseif SCAN_CHANGE_EVENTS[event] then
		if AF:IsInCombatLocked() then
			AF.deferredAutoScanReason = event
			if event == "PROFESSION_EQUIPMENT_CHANGED" then
				AF.deferredProfessionEquipmentSkillLineID = ...
			end
			return
		end
		local ownProfessionWindowOpen = AF.IsOwnProfessionWindowOpen and AF:IsOwnProfessionWindowOpen()
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
