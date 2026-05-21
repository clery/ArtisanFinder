local _, AF = ...

local function NormalizeCommand(message)
	message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
	local command, rest = message:match("^(%S+)%s*(.-)$")
	return command or "", rest or ""
end

local function ClearCustomerQueryState(AF)
	AF.pendingReagentDetails = nil
	AF.currentCustomerItemID = nil
	AF.currentCustomerItemName = nil
	AF.currentCustomerProfessionID = nil
	AF.currentCustomerRecipeID = nil
	AF.currentCustomerQueryToken = nil
	AF.currentCustomerQueryItemID = nil
	AF.currentCustomerQueryProfessionID = nil
	AF.lastQueryItemID = nil
	AF.lastQueryProfessionID = nil
	AF.lastQueryAt = nil
end

function AF:RefreshMainUI(statusText)
	self:RefreshCustomerResults(statusText)
	self:RefreshCrafterUI()
	self:RefreshMinimap()
	self:RefreshOptionsPanel()
end

function AF:SetDebugSelfResults(enabled)
	self.db.debugSelfResults = enabled == true
	if not self.db.debugSelfResults then
		if self.ClearAllDebugSelfResults then
			self:ClearAllDebugSelfResults()
		end
		self:ClearDebugTradeLeads()
	end
	self:Print(self:Text("DEBUG_SELF_CHANGED", self.db.debugSelfResults and self:Text("ENABLED") or self:Text("DISABLED")))
	self:RefreshCustomerQuery(true)
end

function AF:SetShowUncertifiedPeople(enabled)
	self.db.showUncertifiedPeople = enabled == true
	self:Print(self:Text("SHOW_UNCERTIFIED_CHANGED", self.db.showUncertifiedPeople and self:Text("ENABLED") or self:Text("DISABLED")))
	self:RefreshCustomerResults()
end

function AF:PrintSlashHelp()
	self:Print(self:Text("SCAN_HELP_FORCE"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_ON"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_OFF"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_TOGGLE"))
	self:Print(self:Text("AUTO_AVAILABILITY_HELP_STATE"))
	self:Print(self:Text("SHOW_UNCERTIFIED_HELP_ON"))
	self:Print(self:Text("SHOW_UNCERTIFIED_HELP_OFF"))
	self:Print(self:Text("SHOW_UNCERTIFIED_HELP_TOGGLE"))
	self:Print(self:Text("SHOW_UNCERTIFIED_HELP_STATE"))
	if self.db and self.db.debugSelfResults then
		self:Print(self:Text("LOCALE_HELP"))
	end
	self:Print(self:Text("TUTORIAL_HELP_RESET"))
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
	self:Print(self:Text("CLEAR_HELP_GUILD"))
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
	self:RefreshCustomerLocale()
	self:RefreshCrafterLocale()
	if self.RefreshTutorialLocale then
		self:RefreshTutorialLocale()
	end
	self:RefreshMainUI()
end

function AF:SetLocaleOverride(locale)
	locale = self:NormalizeLocale(locale)
	if locale == "" or locale == "reset" or locale == "default" then
		self.localeOverride = nil
		self:Print(self:Text("LOCALE_RESET", self:GetCurrentTextLocale()))
		self:RefreshLocalizedUI()
		return
	end
	if not self.Locales[locale] then
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
	ClearCustomerQueryState(self)
	self:EnsureDB()
	self:SelectActiveArtisanProfile(self.playerName or self:GetPlayerFullName())
	self.tradeLeads = self.db.tradeLeads
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_DONE"))
end

function AF:ResetCustomerQueryState(statusText)
	ClearCustomerQueryState(self)
	self:RefreshCustomerResults(statusText or self:Text("SELECT_ORDER_ITEM"))
end

function AF:RefreshAfterClear(statusText)
	self:RefreshMainUI(statusText or self:Text("SELECT_ORDER_ITEM"))
end

function AF:ClearOptionsData()
	self.db.defaultSort = "best"
	self.db.cacheCleanupDays = 7
	self.db.autoAvailability = false
	self.db.fastScan = false
	self.db.tradeLeadMinutes = 15
	self.db.offlineFallbackResults = 10
	self.db.offlineFallbackMax = 20
	self.db.showUncertifiedPeople = true
	self.db.minimap = { angle = 225, hide = false }
	self.db.debugSelfResults = false
	self.db.advertising = {}
	self.db.advertisingKnown = {}
	self:ClearDebugTradeLeads()
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
	ClearCustomerQueryState(self)
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_ARTISANS_DONE"))
end

function AF:ClearFavoriteArtisans()
	self.db.favoriteArtisans = {}
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_ARTISANS_FAVORITE_DONE"))
end

function AF:ClearGuildCaches()
	if self.ClearGuildMemberData then
		self:ClearGuildMemberData(false)
	end
	self:Print(self:Text("CLEAR_GUILD_DONE"))
end

function AF:HandleSlash(message)
	local command, rest = NormalizeCommand(message)
	if command == "scan" then
		self:StartOrResumeCurrentProfessionScan(true, false)
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
	elseif command == "uncertified" then
		if rest == "on" then
			self:SetShowUncertifiedPeople(true)
		elseif rest == "off" then
			self:SetShowUncertifiedPeople(false)
		elseif rest == "toggle" then
			self:SetShowUncertifiedPeople(not self.db.showUncertifiedPeople)
		elseif rest == "" then
			self:Print(self:Text("SHOW_UNCERTIFIED_STATE", self.db.showUncertifiedPeople and self:Text("ENABLED") or self:Text("DISABLED")))
		else
			self:Print(self:Text("SHOW_UNCERTIFIED_UNKNOWN", rest))
			self:PrintSlashHelp()
		end
	elseif command == "locale" then
		if self.db and self.db.debugSelfResults then
			self:SetLocaleOverride(rest)
		else
			self:PrintSlashHelp()
		end
	elseif command == "tutorial" then
		if rest == "reset" then
			self:ResetTutorial()
		else
			self:Print(self:Text("TUTORIAL_HELP_RESET"))
		end
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
		elseif rest == "guild" then
			self:ClearGuildCaches()
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
