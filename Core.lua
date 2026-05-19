local addonName, AF = ...

AF.frame = CreateFrame("Frame")

local function RegisterEvent(frame, event)
	local ok = pcall(frame.RegisterEvent, frame, event)
	if not ok then
		AF:Print(AF:Text("EVENT_UNAVAILABLE", event))
	end
end

RegisterEvent(AF.frame, "ADDON_LOADED")
RegisterEvent(AF.frame, "PLAYER_LOGIN")
RegisterEvent(AF.frame, "PLAYER_REGEN_ENABLED")
RegisterEvent(AF.frame, "PLAYER_REGEN_DISABLED")
RegisterEvent(AF.frame, "PLAYER_ENTERING_WORLD")
RegisterEvent(AF.frame, "ZONE_CHANGED")
RegisterEvent(AF.frame, "ZONE_CHANGED_INDOORS")
RegisterEvent(AF.frame, "ZONE_CHANGED_NEW_AREA")
RegisterEvent(AF.frame, "CHANNEL_UI_UPDATE")
RegisterEvent(AF.frame, "CHAT_MSG_CHANNEL_NOTICE")
RegisterEvent(AF.frame, "CHAT_MSG_ADDON")
RegisterEvent(AF.frame, "CHAT_MSG_CHANNEL")
RegisterEvent(AF.frame, "GUILD_ROSTER_UPDATE")
RegisterEvent(AF.frame, "GUILD_TRADESKILL_UPDATE")
RegisterEvent(AF.frame, "GUILD_RECIPE_KNOWN_BY_MEMBERS")
RegisterEvent(AF.frame, "CRAFTINGORDERS_SHOW_CUSTOMER")
RegisterEvent(AF.frame, "TRADE_SKILL_SHOW")
RegisterEvent(AF.frame, "TRADE_SKILL_CLOSE")
RegisterEvent(AF.frame, "TRADE_SKILL_LIST_UPDATE")
RegisterEvent(AF.frame, "TRADE_SKILL_DATA_SOURCE_CHANGED")
RegisterEvent(AF.frame, "SKILL_LINES_CHANGED")
RegisterEvent(AF.frame, "SPELLS_CHANGED")
RegisterEvent(AF.frame, "PLAYER_EQUIPMENT_CHANGED")
RegisterEvent(AF.frame, "PROFESSION_EQUIPMENT_CHANGED")
RegisterEvent(AF.frame, "TRAIT_CONFIG_UPDATED")
RegisterEvent(AF.frame, "TRAIT_NODE_CHANGED")

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

function AF:HasTradeChatAccess()
	if GetChannelList then
		local channels = { GetChannelList() }
		for _, value in ipairs(channels) do
			if type(value) == "string" and self:IsTradeChannelName(value) then
				return true
			end
		end
	end
	if EnumerateServerChannels then
		local channels = { EnumerateServerChannels() }
		for _, channelName in ipairs(channels) do
			if self:IsTradeChannelName(channelName) then
				return true
			end
		end
	end
	return false
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
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" or event == "CHANNEL_UI_UPDATE" or event == "CHAT_MSG_CHANNEL_NOTICE" then
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
	elseif event == "GUILD_ROSTER_UPDATE" then
		if AF.RefreshGuildRosterCache then
			AF:RefreshGuildRosterCache(false)
		end
		if AF.RefreshCustomerResults then
			AF:RefreshCustomerResults()
		end
	elseif event == "GUILD_TRADESKILL_UPDATE" then
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
	elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PROFESSION_EQUIPMENT_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_NODE_CHANGED" then
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
