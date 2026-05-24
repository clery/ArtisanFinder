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
		self.optionsSectionInitializers = self.optionsSectionInitializers or {}
		table.insert(self.optionsSectionInitializers, {
			initializer = initializer,
			labelKey = "OPTIONS_SECTION_ADVERTISING",
			descriptionKey = "OPTIONS_SECTION_ADVERTISING_DESC",
		})
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
		local preservedSetting = row.preservedSetting == true
		local key = tostring(characterName) .. ":" .. tostring(professionID)
		if not self.advertisingOptionRegistered[key] then
			local function GetLabel()
				return self:GetDisplayPlayerName(characterName) .. " - " .. tostring(self:GetProfessionName(professionID, row))
			end
			local variable = "ArtisanFinder_Advertise_" .. key:gsub("[^%w_]", "_")
			local defaultAdvertised = self:IsProfessionAdvertisedByDefault(self:GetProfessionDefaultAdvertisingID(professionID, row))
			local advertiseProfession = Settings.RegisterProxySetting(
				category,
				variable,
				Settings.VarType.Boolean,
				GetLabel,
				defaultAdvertised,
				function()
					return AF:IsProfessionAdvertised(characterName, professionID)
				end,
				function(value)
					AF:SetProfessionAdvertised(characterName, professionID, value == true)
				end
			)
			local initializer = Settings.CreateCheckbox(category, advertiseProfession, function()
				return AF:Text("OPTIONS_ADVERTISE_PROFESSION_DESC")
			end)
			if initializer and initializer.AddShownPredicate then
				initializer:AddShownPredicate(function()
					return AF:HasScannedProfession(characterName, professionID) or preservedSetting
				end)
			end
			self.advertisingOptionRegistered[key] = true
		end
	end
end

function AF:InitializeOptions()
	if self.optionsInitialized then
		return
	end
	self.optionsInitialized = true

	local category = Settings.RegisterVerticalLayoutCategory("ArtisanFinder")
	self.optionsCategory = category
	self.optionsSectionInitializers = {}

	local function AddSection(labelKey, descriptionKey)
		local initializer = CreateSettingsListSectionHeaderInitializer(self:Text(labelKey), descriptionKey and self:Text(descriptionKey) or nil)
		table.insert(self.optionsSectionInitializers, {
			initializer = initializer,
			labelKey = labelKey,
			descriptionKey = descriptionKey,
		})
		Settings.RegisterInitializer(category, initializer)
	end

	local function RegisterProxySetting(variable, varType, labelKey, defaultValue, getter, setter)
		return Settings.RegisterProxySetting(
			category,
			variable,
			varType,
			function()
				return AF:Text(labelKey)
			end,
			defaultValue,
			getter,
			setter
		)
	end

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
	Settings.CreateDropdown(category, defaultSort, CreateSortOptions, function()
		return AF:Text("OPTIONS_DEFAULT_SORT_DESC")
	end)

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
	end, function()
		return AF:Text("OPTIONS_CLEANUP_FREQUENCY_DESC")
	end)

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
	end, function()
		return AF:Text("OPTIONS_OFFLINE_FALLBACK_RESULTS_DESC")
	end)

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
	end, function()
		return AF:Text("OPTIONS_OFFLINE_FALLBACK_MAX_DESC")
	end)

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
	end, function()
		return AF:Text("OPTIONS_TRADE_LEADS_LIFETIME_DESC")
	end)

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
	Settings.CreateCheckbox(category, freezeTradeLeadRows, function()
		return AF:Text("OPTIONS_FREEZE_TRADE_LEAD_ROWS_DESC")
	end)

	AddSection("OPTIONS_SECTION_SCANNING")
	local fastScan = RegisterProxySetting(
		"ArtisanFinder_FastScan",
		Settings.VarType.Boolean,
		"OPTIONS_FAST_SCAN",
		false,
		function()
			return AF.db.fastScan == true
		end,
		function(value)
			AF:SetFastScan(value == true)
		end
	)
	Settings.CreateCheckbox(category, fastScan, function()
		return AF:Text("OPTIONS_FAST_SCAN_DESC")
	end)

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
	Settings.CreateCheckbox(category, autoAvailability, function()
		return AF:Text("OPTIONS_AUTO_AVAILABILITY_DESC")
	end)

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
	Settings.CreateCheckbox(category, hideMinimap, function()
		return AF:Text("OPTIONS_HIDE_MINIMAP_DESC")
	end)

	RegisterAdvertisingOptions(self, category)

	Settings.RegisterAddOnCategory(category)
end

function AF:RefreshOptionsPanel()
	if self.optionsCategory then
		for _, section in ipairs(self.optionsSectionInitializers or {}) do
			local data = section.initializer and section.initializer.GetData and section.initializer:GetData()
			if data then
				data.name = self:Text(section.labelKey)
				data.tooltip = section.descriptionKey and self:Text(section.descriptionKey) or nil
			end
		end
		RegisterAdvertisingOptions(self, self.optionsCategory)
		if SettingsPanel and SettingsPanel:IsShown() and SettingsPanel.GetCurrentCategory and SettingsPanel:GetCurrentCategory() == self.optionsCategory then
			SettingsPanel:DisplayCategory(self.optionsCategory)
		elseif SettingsPanel and SettingsPanel:IsShown() and SettingsPanel.RepairDisplay then
			SettingsPanel:RepairDisplay()
		end
	end
end
