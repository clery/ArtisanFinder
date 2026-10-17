local _, AF = ...

local CLEANUP_OPTIONS = {
	{ days = 0, labelKey = "OPTIONS_CLEANUP_DISABLED" },
	{ days = 1, labelKey = "OPTIONS_CLEANUP_1_DAY" },
	{ days = 7, labelKey = "OPTIONS_CLEANUP_7_DAYS" },
	{ days = 14, labelKey = "OPTIONS_CLEANUP_14_DAYS" },
	{ days = 30, labelKey = "OPTIONS_CLEANUP_30_DAYS" },
}

local TRADE_LEAD_OPTIONS = {
	{ minutes = 5, labelKey = "OPTIONS_TRADE_LEADS_5_MINUTES" },
	{ minutes = 10, labelKey = "OPTIONS_TRADE_LEADS_10_MINUTES" },
	{ minutes = 15, labelKey = "OPTIONS_TRADE_LEADS_15_MINUTES" },
	{ minutes = 30, labelKey = "OPTIONS_TRADE_LEADS_30_MINUTES" },
	{ minutes = 60, labelKey = "OPTIONS_TRADE_LEADS_60_MINUTES" },
}

local OFFLINE_FALLBACK_RESULT_OPTIONS = {
	{ count = 0, labelKey = "OPTIONS_OFFLINE_FALLBACK_DISABLED" },
	{ count = 5, labelKey = "OPTIONS_OFFLINE_FALLBACK_5" },
	{ count = 10, labelKey = "OPTIONS_OFFLINE_FALLBACK_10" },
	{ count = 15, labelKey = "OPTIONS_OFFLINE_FALLBACK_15" },
	{ count = 20, labelKey = "OPTIONS_OFFLINE_FALLBACK_20" },
	{ count = 25, labelKey = "OPTIONS_OFFLINE_FALLBACK_25" },
	{ count = 30, labelKey = "OPTIONS_OFFLINE_FALLBACK_30" },
}

local OFFLINE_FALLBACK_MAX_OPTIONS = {
	{ count = 10, labelKey = "OPTIONS_OFFLINE_FALLBACK_10" },
	{ count = 20, labelKey = "OPTIONS_OFFLINE_FALLBACK_20" },
	{ count = 30, labelKey = "OPTIONS_OFFLINE_FALLBACK_30" },
	{ count = 40, labelKey = "OPTIONS_OFFLINE_FALLBACK_40" },
	{ count = 50, labelKey = "OPTIONS_OFFLINE_FALLBACK_50" },
}

local CRAFTER_PANEL_DEFAULT_STATE_OPTIONS = {
	{ key = "maximized", labelKey = "OPTIONS_PROFESSION_PANEL_DEFAULT_MAXIMIZED" },
	{ key = "minimized", labelKey = "OPTIONS_PROFESSION_PANEL_DEFAULT_MINIMIZED" },
}

local AUTO_AVAILABILITY_ACTIVITY_OPTIONS = {
	{ key = "party", labelKey = "OPTIONS_AUTO_DISABLE_PARTY", descKey = "OPTIONS_AUTO_DISABLE_PARTY_DESC" },
	{ key = "raid", labelKey = "OPTIONS_AUTO_DISABLE_RAID", descKey = "OPTIONS_AUTO_DISABLE_RAID_DESC" },
	{ key = "pvp", labelKey = "OPTIONS_AUTO_DISABLE_PVP", descKey = "OPTIONS_AUTO_DISABLE_PVP_DESC" },
	{ key = "arena", labelKey = "OPTIONS_AUTO_DISABLE_ARENA", descKey = "OPTIONS_AUTO_DISABLE_ARENA_DESC" },
	{ key = "delve", labelKey = "OPTIONS_AUTO_DISABLE_DELVE", descKey = "OPTIONS_AUTO_DISABLE_DELVE_DESC" },
}

local function CreateSortOptions()
	local options = {}
	for _, option in ipairs(AF:GetCustomerSortOptions()) do
		table.insert(options, {
			controlType = Settings.ControlType.Radio,
			label = option.text,
			text = option.text,
			value = option.key,
		})
	end
	return options
end

local function CreateRadioOptions(optionTable, valueKey)
	local options = {}
	for _, option in ipairs(optionTable) do
		local text = AF:Text(option.labelKey)
		table.insert(options, {
			controlType = Settings.ControlType.Radio,
			label = text,
			text = text,
			value = option[valueKey],
		})
	end
	return options
end

local function RegisterAdvertisingOptions(self, category)
	local advertisingRows = self:GetAdvertisingProfessionRows()
	if #advertisingRows == 0 then
		return
	end
	self.advertisingOptionRegistered = self.advertisingOptionRegistered or {}
	if not self.advertisingOptionsSectionRegistered then
		local initializer = CreateSettingsListSectionHeaderInitializer(self:Text("OPTIONS_SECTION_ADVERTISING"), self:Text("OPTIONS_SECTION_ADVERTISING_DESC"))
		if initializer.AddShownPredicate then
			initializer:AddShownPredicate(function()
				return #AF:GetAdvertisingProfessionRows() > 0
			end)
		end
		Settings.RegisterInitializer(category, initializer)
		self.advertisingOptionsSectionRegistered = true
	end
	for _, row in ipairs(advertisingRows) do
		local characterName = row.characterName
		local professionID = row.professionID
		local key = tostring(characterName) .. ":" .. tostring(professionID)
		if not self.advertisingOptionRegistered[key] then
			local label = self:GetDisplayPlayerName(characterName) .. " - " .. tostring(row.professionName)
			local variable = "ArtisanFinder_Advertise_" .. key:gsub("[^%w_]", "_")
			local defaultAdvertised = self:IsProfessionAdvertisedByDefault(self:GetProfessionDefaultAdvertisingID(professionID, row))
			local advertiseProfession = Settings.RegisterProxySetting(
				category,
				variable,
				Settings.VarType.Boolean,
				label,
				defaultAdvertised,
				function()
					return AF:IsProfessionAdvertised(characterName, professionID)
				end,
				function(value)
					AF:SetProfessionAdvertised(characterName, professionID, value == true)
				end
			)
			local initializer = Settings.CreateCheckbox(category, advertiseProfession, self:Text("OPTIONS_ADVERTISE_PROFESSION_DESC"))
			if initializer and initializer.AddShownPredicate then
				initializer:AddShownPredicate(function()
					return AF:HasScannedProfession(characterName, professionID) or AF:HasAdvertisingProfessionSetting(characterName, professionID)
				end)
			end
			self.advertisingOptionRegistered[key] = true
		end
	end
end

function AF:InitializeOptions()
	if self.optionsInitialized or not Settings or not Settings.RegisterVerticalLayoutCategory then
		return
	end
	self.optionsInitialized = true

	local category = Settings.RegisterVerticalLayoutCategory("ArtisanFinder")
	self.optionsCategory = category

	local function AddSection(labelKey, descriptionKey)
		Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(self:Text(labelKey), descriptionKey and self:Text(descriptionKey) or nil))
	end

	local function RegisterProxySetting(variable, varType, labelKey, defaultValue, getter, setter)
		return Settings.RegisterProxySetting(
			category,
			variable,
			varType,
			self:Text(labelKey),
			defaultValue,
			getter,
			setter
		)
	end

	AddSection("OPTIONS_SECTION_MINIMAP")
	local hideMinimap = RegisterProxySetting(
		"ArtisanFinder_HideMinimap",
		Settings.VarType.Boolean,
		"OPTIONS_HIDE_MINIMAP",
		false,
		function()
			return AF.db.minimap and AF.db.minimap.hide == true
		end,
		function(value)
			AF:SetMinimapHidden(value == true)
		end
	)
	Settings.CreateCheckbox(category, hideMinimap, self:Text("OPTIONS_HIDE_MINIMAP_DESC"))

	local standaloneMinimap = RegisterProxySetting(
		"ArtisanFinder_StandaloneMinimap",
		Settings.VarType.Boolean,
		"OPTIONS_STANDALONE_MINIMAP",
		false,
		function()
			return AF.db.minimap and AF.db.minimap.standalone == true
		end,
		function(value)
			AF:SetMinimapStandalone(value == true)
		end
	)
	Settings.CreateCheckbox(category, standaloneMinimap, self:Text("OPTIONS_STANDALONE_MINIMAP_DESC"))

	Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
		self:Text("OPTIONS_RESET_MINIMAP_POSITION"),
		self:Text("OPTIONS_RESET_POSITION_BUTTON"),
		function()
			AF:ResetMinimapButtonPosition()
		end,
		self:Text("OPTIONS_RESET_MINIMAP_POSITION_DESC"),
		true
	))

	AddSection("OPTIONS_SECTION_PROFESSION_PANEL")
	local professionPanelDefaultState = RegisterProxySetting(
		"ArtisanFinder_ProfessionPanelDefaultState",
		Settings.VarType.String,
		"OPTIONS_PROFESSION_PANEL_DEFAULT_STATE",
		"maximized",
		function()
			return AF:GetCrafterPanelDefaultState()
		end,
		function(value)
			AF:SetCrafterPanelDefaultState(value)
		end
	)
	Settings.CreateDropdown(category, professionPanelDefaultState, function()
		return CreateRadioOptions(CRAFTER_PANEL_DEFAULT_STATE_OPTIONS, "key")
	end, self:Text("OPTIONS_PROFESSION_PANEL_DEFAULT_STATE_DESC"))

	AddSection("OPTIONS_SECTION_AVAILABILITY")
	local autoAvailability = RegisterProxySetting(
		"ArtisanFinder_AutoAvailability",
		Settings.VarType.Boolean,
		"OPTIONS_AUTO_AVAILABILITY",
		false,
		function()
			return AF.db.autoAvailability == true
		end,
		function(value)
			AF:SetAutoAvailability(value == true)
		end
	)
	Settings.CreateCheckbox(category, autoAvailability, self:Text("OPTIONS_AUTO_AVAILABILITY_DESC"))

	local rememberManualAvailability = RegisterProxySetting(
		"ArtisanFinder_RememberManualAvailability",
		Settings.VarType.Boolean,
		"OPTIONS_REMEMBER_MANUAL_AVAILABILITY",
		false,
		function()
			return AF.db.rememberManualAvailability == true
		end,
		function(value)
			AF.db.rememberManualAvailability = value == true
			if value == true and AF.db.autoAvailability ~= true then
				AF.db.manualAvailabilityMode = AF:GetAvailabilityMode()
			end
		end
	)
	Settings.CreateCheckbox(category, rememberManualAvailability, self:Text("OPTIONS_REMEMBER_MANUAL_AVAILABILITY_DESC"))

	for _, option in ipairs(AUTO_AVAILABILITY_ACTIVITY_OPTIONS) do
		if not self.IsForever or option.key~="delve" then
		local activityKey = option.key
		local labelKey = option.labelKey
		local descKey = option.descKey
		local setting = RegisterProxySetting(
			"ArtisanFinder_AutoDisable_" .. activityKey,
			Settings.VarType.Boolean,
			labelKey,
			true,
			function()
				return AF:IsAutoAvailabilityActivityDisabled(activityKey)
			end,
			function(value)
				AF:SetAutoAvailabilityActivityDisabled(activityKey, value == true)
			end
		)
		Settings.CreateCheckbox(category, setting, self:Text(descKey))
        end
	end

	AddSection("OPTIONS_SECTION_SCANNING")
	Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
		self:Text("OPTIONS_TRANSFER_ARTISANS"),
		self:Text("OPTIONS_TRANSFER_OPEN"),
		function()
			AF:OpenTransferFrame()
		end,
		self:Text("OPTIONS_TRANSFER_ARTISANS_DESC"),
		true
	))

	local disableAutomaticScans = RegisterProxySetting(
		"ArtisanFinder_DisableAutomaticScans",
		Settings.VarType.Boolean,
		"OPTIONS_DISABLE_AUTOMATIC_SCANS",
		false,
		function()
			return AF.db.disableAutomaticScans == true
		end,
		function(value)
			AF.db.disableAutomaticScans = value == true
			if value == true then
				if AF.StopProfessionEquipmentWatch then
					AF:StopProfessionEquipmentWatch()
				end
			elseif AF.IsOwnProfessionWindowOpen and AF:IsOwnProfessionWindowOpen() then
				if AF.StartProfessionEquipmentWatch then
					AF:StartProfessionEquipmentWatch()
				end
				if AF.ResumeCurrentProfessionScanIfNeeded then
					AF:ResumeCurrentProfessionScanIfNeeded()
				end
			end
		end
	)
	Settings.CreateCheckbox(category, disableAutomaticScans, self:Text("OPTIONS_DISABLE_AUTOMATIC_SCANS_DESC"))

	AddSection("OPTIONS_SECTION_TRADE_LEADS")
	local tradeLeadLifetime = RegisterProxySetting(
		"ArtisanFinder_TradeLeadMinutes",
		Settings.VarType.Number,
		"OPTIONS_TRADE_LEADS_LIFETIME",
		15,
		function()
			return tonumber(AF.db.tradeLeadMinutes) or 15
		end,
		function(value)
			AF.db.tradeLeadMinutes = tonumber(value) or 15
			if AF.PruneTradeLeads then
				AF:PruneTradeLeads()
			end
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
		end
	)
	Settings.CreateDropdown(category, tradeLeadLifetime, function()
		return CreateRadioOptions(TRADE_LEAD_OPTIONS, "minutes")
	end, self:Text("OPTIONS_TRADE_LEADS_LIFETIME_DESC"))

	if not self.IsForever then
		local freezeTradeLeadRows = RegisterProxySetting(
			"ArtisanFinder_FreezeTradeLeadRows",
			Settings.VarType.Boolean,
			"OPTIONS_FREEZE_TRADE_LEAD_ROWS",
			false,
			function()
				return AF.db.freezeTradeLeadRows == true
			end,
			function(value)
				AF.db.freezeTradeLeadRows = value == true
				AF.customerTradeLeadSnapshot = nil
				if AF.RefreshCustomerQuery then
					AF:RefreshCustomerQuery(true)
				end
			end
		)
		Settings.CreateCheckbox(category, freezeTradeLeadRows, self:Text("OPTIONS_FREEZE_TRADE_LEAD_ROWS_DESC"))
	end

	self:RegisterFlavorOptions(category, AddSection, RegisterProxySetting, CreateRadioOptions)

	if not self.IsForever then
		AddSection("OPTIONS_SECTION_CUSTOMER")
		local defaultSort = RegisterProxySetting(
			"ArtisanFinder_DefaultSort",
			Settings.VarType.String,
			"OPTIONS_DEFAULT_SORT",
			"best",
			function()
				return AF.db.defaultSort or "best"
			end,
			function(value)
				AF:SetDefaultSort(value)
			end
		)
		Settings.CreateDropdown(category, defaultSort, CreateSortOptions, self:Text("OPTIONS_DEFAULT_SORT_DESC"))

		local showOwnCharacterRows = RegisterProxySetting(
			"ArtisanFinder_ShowOwnCharacterRows",
			Settings.VarType.Boolean,
			"OPTIONS_SHOW_OWN_CHARACTER_ROWS",
			true,
			function()
				return AF.db.showOwnCharacterRows == true
			end,
			function(value)
				AF.db.showOwnCharacterRows = value == true
				if AF.RefreshCustomerResults then
					AF:RefreshCustomerResults()
				end
			end
		)
		Settings.CreateCheckbox(category, showOwnCharacterRows, self:Text("OPTIONS_SHOW_OWN_CHARACTER_ROWS_DESC"))
	end

	AddSection("OPTIONS_SECTION_CACHE")
	local cleanupFrequency = RegisterProxySetting(
		"ArtisanFinder_CacheCleanupDays",
		Settings.VarType.Number,
		"OPTIONS_CLEANUP_FREQUENCY",
		7,
		function()
			return tonumber(AF.db.cacheCleanupDays) or 7
		end,
		function(value)
			AF.db.cacheCleanupDays = tonumber(value) or 7
		end
	)
	Settings.CreateDropdown(category, cleanupFrequency, function()
		return CreateRadioOptions(CLEANUP_OPTIONS, "days")
	end, self:Text("OPTIONS_CLEANUP_FREQUENCY_DESC"))

	local offlineFallbackResults = RegisterProxySetting(
		"ArtisanFinder_OfflineFallbackResults",
		Settings.VarType.Number,
		"OPTIONS_OFFLINE_FALLBACK_RESULTS",
		10,
		function()
			return tonumber(AF.db.offlineFallbackResults) or 10
		end,
		function(value)
			AF.db.offlineFallbackResults = tonumber(value) or 0
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
		end
	)
	Settings.CreateDropdown(category, offlineFallbackResults, function()
		return CreateRadioOptions(OFFLINE_FALLBACK_RESULT_OPTIONS, "count")
	end, self:Text("OPTIONS_OFFLINE_FALLBACK_RESULTS_DESC"))

	local offlineFallbackMax = RegisterProxySetting(
		"ArtisanFinder_OfflineFallbackMax",
		Settings.VarType.Number,
		"OPTIONS_OFFLINE_FALLBACK_MAX",
		20,
		function()
			return tonumber(AF.db.offlineFallbackMax) or 20
		end,
		function(value)
			AF.db.offlineFallbackMax = tonumber(value) or 20
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
		end
	)
	Settings.CreateDropdown(category, offlineFallbackMax, function()
		return CreateRadioOptions(OFFLINE_FALLBACK_MAX_OPTIONS, "count")
	end, self:Text("OPTIONS_OFFLINE_FALLBACK_MAX_DESC"))

	RegisterAdvertisingOptions(self, category)

	Settings.RegisterAddOnCategory(category)
end

function AF:RefreshOptionsPanel()
	if self.optionsCategory then
		RegisterAdvertisingOptions(self, self.optionsCategory)
	end
end
