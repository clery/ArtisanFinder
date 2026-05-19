local _, AF = ...

local function NormalizeCommand(message)
	message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
	local command, rest = message:match("^(%S+)%s*(.-)$")
	return command or "", rest or ""
end

function AF:SetDebugSelfResults(enabled)
	self.db.debugSelfResults = enabled == true
	if not self.db.debugSelfResults and self.ClearDebugTradeLeads then
		self:ClearDebugTradeLeads()
	end
	self:Print(self:Text("DEBUG_SELF_CHANGED", self.db.debugSelfResults and self:Text("ENABLED") or self:Text("DISABLED")))
	if self.RefreshCustomerQuery then
		self:RefreshCustomerQuery(true)
	end
end

function AF:PrintSlashHelp()
	self:Print(self:Text("SCAN_HELP_FORCE"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_ON"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_OFF"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_TOGGLE"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_STATE"))
	self:Print(self:Text("LOCALE_HELP"))
	self:Print(self:Text("CLEAR_HELP"))
	self:Print(self:Text("DEBUG_HELP_ON"))
	self:Print(self:Text("DEBUG_HELP_OFF"))
	self:Print(self:Text("DEBUG_HELP_TOGGLE"))
	self:Print(self:Text("DEBUG_HELP_STATE"))
end

function AF:PrintClearHelp()
	self:Print(self:Text("CLEAR_HELP_ALL"))
	self:Print(self:Text("CLEAR_HELP_OPTIONS"))
	self:Print(self:Text("CLEAR_HELP_SCANS"))
	self:Print(self:Text("CLEAR_HELP_ARTISANS"))
	self:Print(self:Text("CLEAR_HELP_ARTISANS_FAVORITE"))
end

function AF:GetAvailableLocaleText()
	local locales = {}
	for locale in pairs(self.Locales or {}) do
		table.insert(locales, locale)
	end
	table.sort(locales)
	return table.concat(locales, ", ")
end

function AF:RefreshLocalizedUI()
	if self.RefreshCustomerLocale then
		self:RefreshCustomerLocale()
	end
	if self.RefreshCrafterLocale then
		self:RefreshCrafterLocale()
	end
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:SetLocaleOverride(locale)
	locale = self:NormalizeLocale(locale)
	if locale == "" or locale == "reset" or locale == "default" then
		self.localeOverride = nil
		self:Print(self:Text("LOCALE_RESET", self:GetCurrentTextLocale()))
		self:RefreshLocalizedUI()
		return
	end
	if not self.Locales or not self.Locales[locale] then
		self:Print(self:Text("LOCALE_UNKNOWN", locale, self:GetAvailableLocaleText()))
		return
	end
	self.localeOverride = locale
	self:Print(self:Text("LOCALE_CHANGED", locale))
	self:RefreshLocalizedUI()
end

function AF:ClearAllData()
	local minimap = self.db and self.db.minimap or nil
	ArtisanFinderDB = {
		minimap = minimap,
		debugSelfResults = false,
	}
	self.db = ArtisanFinderDB
	self.activeScan = nil
	self.pendingAutoScanReason = nil
	self.autoScanQueued = false
	self.scanProcessing = false
	self.tradeLeads = {}
	self.pendingReagentDetails = nil
	self.currentCustomerItemID = nil
	self.currentCustomerItemName = nil
	self.currentCustomerProfessionID = nil
	self.currentCustomerRecipeID = nil
	self.currentCustomerQueryToken = nil
	self.currentCustomerQueryItemID = nil
	self.currentCustomerQueryProfessionID = nil
	self.lastQueryItemID = nil
	self.lastQueryProfessionID = nil
	self.lastQueryAt = nil
	self:EnsureDB()
	self:SelectActiveArtisanProfile(self.playerName or self:GetPlayerFullName())
	self.tradeLeads = self.db.tradeLeads
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults(self:Text("SELECT_ORDER_ITEM"))
	end
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
	self:Print(self:Text("CLEAR_DONE"))
end

function AF:ResetCustomerQueryState(statusText)
	self.pendingReagentDetails = nil
	self.currentCustomerItemID = nil
	self.currentCustomerItemName = nil
	self.currentCustomerProfessionID = nil
	self.currentCustomerRecipeID = nil
	self.currentCustomerQueryToken = nil
	self.currentCustomerQueryItemID = nil
	self.currentCustomerQueryProfessionID = nil
	self.lastQueryItemID = nil
	self.lastQueryProfessionID = nil
	self.lastQueryAt = nil
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults(statusText or self:Text("SELECT_ORDER_ITEM"))
	end
end

function AF:RefreshAfterClear(statusText)
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults(statusText or self:Text("SELECT_ORDER_ITEM"))
	end
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:ClearOptionsData()
	self.db.defaultSort = "best"
	self.db.cacheCleanupDays = 7
	self.db.autoAvailability = false
	self.db.fastScan = false
	self.db.tradeLeadMinutes = 15
	self.db.offlineFallbackResults = 10
	self.db.offlineFallbackMax = 20
	self.db.minimap = { angle = 225, hide = false }
	self.db.debugSelfResults = false
	self.db.advertising = {}
	if self.ClearDebugTradeLeads then
		self:ClearDebugTradeLeads()
	end
	if self.customerSortIndex then
		self.customerSortIndex = nil
	end
	self:RefreshLocalizedUI()
	self:Print(self:Text("CLEAR_OPTIONS_DONE"))
end

function AF:ClearCurrentCharacterScans()
	local characterName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if not characterName then
		return
	end
	local profile = self.db.artisanCharacters and self.db.artisanCharacters[characterName] or self.db.artisanProfile
	profile = self:NormalizeArtisanProfile(profile, characterName)
	profile.professions = {}
	profile.items = {}
	self.db.artisanCharacters[characterName] = profile
	if self.activeArtisanCharacter == characterName then
		self.db.artisanProfile = profile
	end
	self.activeScan = nil
	self.pendingAutoScanReason = nil
	self.autoScanQueued = false
	self.scanProcessing = false
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_SCANS_DONE"))
end

function AF:ClearExternalArtisans()
	self.db.customerCache = {}
	self.db.tradeLeads = {}
	self.db.tradeLeadCache = {}
	self.db.responseThrottle = {}
	self.tradeLeads = self.db.tradeLeads
	self:ResetCustomerQueryState()
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_ARTISANS_DONE"))
end

function AF:ClearFavoriteArtisans()
	self.db.favoriteArtisans = {}
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_ARTISANS_FAVORITE_DONE"))
end

function AF:HandleSlash(message)
	local command, rest = NormalizeCommand(message)
	if command == "scan" then
		if self.StartOrResumeCurrentProfessionScan then
			self:StartOrResumeCurrentProfessionScan(true, false)
		end
	elseif command == "auto" then
		if rest == "on" then
			self:SetAutoAvailability(true)
		elseif rest == "off" then
			self:SetAutoAvailability(false)
		elseif rest == "toggle" then
			self:ToggleAutoAvailability()
		elseif rest == "" then
			self:Print(self:Text("AUTO_AVAILABILITY_STATE", self.db.autoAvailability and self:Text("ENABLED") or self:Text("DISABLED")))
		else
			self:Print(self:Text("AUTO_AVAILABILITY_UNKNOWN", rest))
			self:PrintSlashHelp()
		end
	elseif command == "locale" then
		self:SetLocaleOverride(rest)
	elseif command == "clear" then
		if rest == "all" then
			self:ClearAllData()
		elseif rest == "options" then
			self:ClearOptionsData()
		elseif rest == "scans" then
			self:ClearCurrentCharacterScans()
		elseif rest == "artisans" then
			self:ClearExternalArtisans()
		elseif rest == "artisans favorite" then
			self:ClearFavoriteArtisans()
		else
			self:PrintClearHelp()
		end
	elseif command == "debug" then
		if rest == "on" then
			self:SetDebugSelfResults(true)
		elseif rest == "off" then
			self:SetDebugSelfResults(false)
		elseif rest == "toggle" then
			self:SetDebugSelfResults(not self.db.debugSelfResults)
		elseif rest == "" then
			self:Print(self:Text("DEBUG_SELF_STATE", self.db.debugSelfResults and self:Text("ENABLED") or self:Text("DISABLED")))
		else
			self:Print(self:Text("DEBUG_UNKNOWN", rest))
			self:PrintSlashHelp()
		end
	else
		self:PrintSlashHelp()
	end
end

function AF:InitializeSlashCommands()
	SLASH_ARTISANFINDER1 = "/af"
	SLASH_ARTISANFINDER2 = "/artisanfinder"
	SlashCmdList.ARTISANFINDER = function(message)
		AF:HandleSlash(message)
	end
end
