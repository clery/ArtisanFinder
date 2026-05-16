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
RegisterEvent(AF.frame, "CHAT_MSG_ADDON")
RegisterEvent(AF.frame, "CHAT_MSG_CHANNEL")
RegisterEvent(AF.frame, "CRAFTINGORDERS_SHOW_CUSTOMER")
RegisterEvent(AF.frame, "TRADE_SKILL_SHOW")
RegisterEvent(AF.frame, "TRADE_SKILL_CLOSE")
RegisterEvent(AF.frame, "TRADE_SKILL_LIST_UPDATE")
RegisterEvent(AF.frame, "TRADE_SKILL_DATA_SOURCE_CHANGED")
RegisterEvent(AF.frame, "SKILL_LINES_CHANGED")
RegisterEvent(AF.frame, "SPELLS_CHANGED")
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
	self.available = false

	if self.InitializeComms then
		self:InitializeComms()
	end
	if self.InitializeMinimap then
		self:InitializeMinimap()
	end
	if self.InitializeCustomerUI then
		self:InitializeCustomerUI()
	end
	if self.InitializeCrafterUI then
		self:InitializeCrafterUI()
	end
	if self.InitializeSlashCommands then
		self:InitializeSlashCommands()
	end
	if self.InitializeTradeChat then
		self:InitializeTradeChat()
	end

	self:Print(self:Text("ADDON_LOADED"))
end

function AF:SetAvailable(value)
	self.available = value == true
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	self:Print(self:Text("AVAILABILITY_CHANGED", self.available and self:Text("ENABLED") or self:Text("DISABLED")))
end

function AF:ToggleAvailable()
	self:SetAvailable(not self.available)
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
	elseif event == "CHAT_MSG_ADDON" then
		if AF.OnAddonMessage then
			AF:OnAddonMessage(...)
		end
	elseif event == "CHAT_MSG_CHANNEL" then
		if AF.OnTradeChatMessage then
			AF:OnTradeChatMessage(...)
		end
	elseif event == "CRAFTINGORDERS_SHOW_CUSTOMER" then
		C_Timer.After(0, function()
			AF:TryAttachProfessionUIs()
			if AF.RefreshCustomerQuery then
				AF:RefreshCustomerQuery()
			end
		end)
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
		C_Timer.After(0, function()
			AF:TryAttachProfessionUIs()
			if event == "TRADE_SKILL_SHOW" and AF.ResumeCurrentProfessionScanIfNeeded then
				AF:ResumeCurrentProfessionScanIfNeeded()
			end
			if AF.RefreshCrafterUI then
				AF:RefreshCrafterUI()
			end
			if AF.TrySelectPendingProfessionRecipe then
				AF:TrySelectPendingProfessionRecipe()
			end
		end)
	elseif event == "TRADE_SKILL_CLOSE" then
		if AF.PauseActiveProfessionScan then
			AF:PauseActiveProfessionScan()
		else
			AF.activeScan = nil
		end
	elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_NODE_CHANGED" then
		if AF.QueueAutoScanForChange then
			AF:QueueAutoScanForChange(event)
		end
		if AF.TrySelectPendingProfessionRecipe then
			AF:TrySelectPendingProfessionRecipe()
		end
	end
end)
