local _, AF = ...

local function NormalizeCommand(message)
	message = tostring(message or ""):match("^%s*(.-)%s*$")
	local command, rest = message:match("^(%S+)%s*(.-)$")
	return command and command:lower() or "", rest or ""
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
	if self.RefreshCrafterUIScanSafe then
		self:RefreshCrafterUIScanSafe()
	else
		self:RefreshCrafterUI()
	end
	self:RefreshMinimap()
	self:RefreshOptionsPanel()
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
	self:Print(self:Text("DEBUG_HELP"))
	self:Print(self:Text("TUTORIAL_HELP_RESET"))
	self:Print(self:Text("CLEAR_HELP"))
end

function AF:PrintDebugHelp()
	self:Print(self:Text("DEBUG_HELP_ON"))
	self:Print(self:Text("DEBUG_HELP_OFF"))
	self:Print(self:Text("DEBUG_HELP_TOGGLE"))
	self:Print(self:Text("DEBUG_HELP_STATE"))
	self:Print(self:Text("DEBUG_HELP_LOGS"))
	self:Print(self:Text("DEBUG_HELP_CLEAR"))
	self:Print(self:Text("DEBUG_HELP_LOCALE"))
	self:Print(self:Text("DEBUG_HELP_ORDERS"))
end

function AF:PrintDevHelp()
	self:Print(self:Text("DEV_HELP_ON"))
	self:Print(self:Text("DEV_HELP_OFF"))
	self:Print(self:Text("DEV_HELP_TOGGLE"))
	self:Print(self:Text("DEV_HELP_STATE"))
	self:Print(self:Text("DEV_HELP_FAKE"))
	self:Print(self:Text("DEV_HELP_TRAFFIC"))
	self:Print(self:Text("DEV_HELP_NOTIFY"))
	self:Print(self:Text("DEV_HELP_ORDERS"))
	self:Print(self:Text("DEV_HELP_SOUND"))
	self:Print("/af dev orderdump: dump orderable recipe data for maintainer updates.")
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
		debugEnabled = false,
		devEnabled = false,
		devFakeRows = false,
		devTrafficLogs = false,
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
	self.db.disableAutomaticScans = false
	self.db.autoAvailability = false
	self.db.autoAvailabilityDisable = { party = true, raid = true, pvp = true, arena = true, delve = true }
	self.db.tradeLeadMinutes = 15
	self.db.freezeTradeLeadRows = false
	self.db.orderNotificationSound = "CATALOG_SHOP_OPEN_LOADING_SCREEN"
	self.db.orderNotificationChannel = "default"
	self.db.offlineFallbackResults = 10
	self.db.offlineFallbackMax = 20
	self.db.showUncertifiedPeople = true
	self.db.minimap = { angle = 225, hide = false, standalone = false, standaloneX = -180, standaloneY = -120 }
	self.db.debugEnabled = false
	self.db.devEnabled = false
	self.db.devFakeRows = false
	self.db.devTrafficLogs = false
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
	self:ClearCharacterScans(characterName)
end

function AF:ClearCharacterScans(characterName)
	if not characterName then
		return
	end
	characterName = self:NormalizeName(characterName)
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
	
	for key in pairs(self.db.professionLinks or {}) do
		local keyCharacter = tostring(key):match("^(.-):([^:]+)$")
		if keyCharacter == characterName then
			self.db.professionLinks[key] = nil
		end
	end
	
	self.activeScan = nil
	self.pendingAutoScanReason = nil
	self.autoScanQueued = false
	self.scanProcessing = false
	self:RefreshAfterClear()
	self:Print(self:Text("CLEAR_SCANS_DONE", characterName))
end

function AF:ClearExternalArtisans()
	self.db.customerCache = {}
	self.db.tradeLeads = {}
	self.db.tradeLeadCache = {}
	self.responseThrottle = {}
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

function AF:HandleDebugSlash(rest)
	local command, commandRest = NormalizeCommand(rest)
	if command == "on" then
		self:SetDebugEnabled(true)
	elseif command == "off" then
		self:SetDebugEnabled(false)
	elseif command == "toggle" then
		self:SetDebugEnabled(not self:IsDebugEnabled())
	elseif command == "state" then
		self:Print(self:Text("DEBUG_STATE", self:IsDebugEnabled() and self:Text("ENABLED") or self:Text("DISABLED")))
	elseif command == "" then
		self:PrintDebugHelp()
	elseif command == "logs" then
		self:OpenDebugLogFrame()
	elseif command == "clear" then
		self:ClearDebugLog()
	elseif command == "locale" then
		if self:IsDebugEnabled() then
			self:SetLocaleOverride(commandRest)
		else
			self:PrintSlashHelp()
		end
	elseif command == "orders" then
		if self:IsDebugEnabled() and self.PrintOrderDebugState then
			self:PrintOrderDebugState()
		else
			self:PrintSlashHelp()
		end
	else
		self:Print(self:Text("DEBUG_UNKNOWN", rest))
		self:PrintDebugHelp()
	end
end

function AF:HandleDevSlash(rest)
	local command, commandRest = NormalizeCommand(rest)
	if command == "on" then
		self:SetDevEnabled(true)
	elseif command == "off" then
		self:SetDevEnabled(false)
	elseif command == "toggle" then
		self:SetDevEnabled(not self:IsDevEnabled())
	elseif command == "state" then
		self:Print(self:Text(
			"DEV_STATE",
			self:IsDevEnabled() and self:Text("ENABLED") or self:Text("DISABLED"),
			self:IsDevFakeRowsEnabled() and self:Text("ENABLED") or self:Text("DISABLED"),
			self:IsDevTrafficLogsEnabled() and self:Text("ENABLED") or self:Text("DISABLED")
		))
	elseif command == "" then
		self:PrintDevHelp()
	elseif command == "fake" then
		local subcommand = NormalizeCommand(commandRest)
		if subcommand == "on" then
			self:SetDevFakeRows(true)
		elseif subcommand == "off" then
			self:SetDevFakeRows(false)
		elseif subcommand == "toggle" then
			self:SetDevFakeRows(not self:IsDevFakeRowsEnabled())
		else
			self:Print(self:Text("DEV_FAKE_STATE", self:IsDevFakeRowsEnabled() and self:Text("ENABLED") or self:Text("DISABLED")))
		end
	elseif command == "traffic" then
		local subcommand = NormalizeCommand(commandRest)
		if subcommand == "on" then
			self:SetDevTrafficLogs(true)
		elseif subcommand == "off" then
			self:SetDevTrafficLogs(false)
		elseif subcommand == "toggle" then
			self:SetDevTrafficLogs(not self:IsDevTrafficLogsEnabled())
		else
			self:Print(self:Text("DEV_TRAFFIC_STATE", self:IsDevTrafficLogsEnabled() and self:Text("ENABLED") or self:Text("DISABLED")))
		end
	elseif command == "notify" then
		local characterName, count = commandRest:match("^(%S+)%s*(%d*)")
		if tonumber(characterName) and (not count or count == "") then
			count = characterName
			characterName = nil
		end
		self:DevNotifyOrder(characterName ~= "" and characterName or self:GetPlayerFullName(), tonumber(count) or 1)
	elseif command == "orders" then
		local subcommand, subRest = NormalizeCommand(commandRest)
		if subcommand == "current" then
			self:DevSetCurrentOrders(tonumber(subRest) or 1)
		elseif subcommand == "alt" then
			local characterName, professionName, count = subRest:match("^(%S+)%s*(.-)%s+(%d+)$")
			if not characterName then
				characterName, professionName = subRest:match("^(%S+)%s*(.*)$")
			end
			self:DevSetAltOrders(characterName or self:GetPlayerFullName(), professionName, tonumber(count) or 1)
		elseif subcommand == "clear" then
			self:DevClearOrders()
		else
			self:Print(self:Text("DEV_HELP_ORDERS"))
		end
	elseif command == "sound" then
		local subcommand = NormalizeCommand(commandRest)
		if subcommand == "order" and self.PlayOrderNotificationSound then
			self:PlayOrderNotificationSound()
		else
			self:Print(self:Text("DEV_HELP_SOUND"))
		end
	elseif command == "orderdump" then
		self:DumpOrderableRecipeData()
	else
		self:Print(self:Text("DEV_UNKNOWN", rest))
		self:PrintDevHelp()
	end
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
		elseif rest:match("^scans") then
			local scansRest = rest:match("^scans%s+(.-)%s*$") or ""
			if scansRest == "" then
				self:ClearCurrentCharacterScans()
			else
				self:ClearCharacterScans(scansRest)
			end
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
		self:HandleDebugSlash(rest)
	elseif command == "dev" then
		self:HandleDevSlash(rest)
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
