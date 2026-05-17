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

local function CreateCleanupOptions()
	local options = {}
	for _, option in ipairs(CLEANUP_OPTIONS) do
		table.insert(options, {
			controlType = Settings.ControlType.Radio,
			label = AF:Text(option.labelKey),
			text = AF:Text(option.labelKey),
			value = option.days,
		})
	end
	return options
end

local function CreateTradeLeadOptions()
	local options = {}
	for _, option in ipairs(TRADE_LEAD_OPTIONS) do
		table.insert(options, {
			controlType = Settings.ControlType.Radio,
			label = AF:Text(option.labelKey),
			text = AF:Text(option.labelKey),
			value = option.minutes,
		})
	end
	return options
end

local function CreateCountOptions(optionTable)
	local options = {}
	for _, option in ipairs(optionTable) do
		table.insert(options, {
			controlType = Settings.ControlType.Radio,
			label = AF:Text(option.labelKey),
			text = AF:Text(option.labelKey),
			value = option.count,
		})
	end
	return options
end

function AF:InitializeOptions()
	if self.optionsInitialized then
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
	Settings.CreateDropdown(category, cleanupFrequency, CreateCleanupOptions, self:Text("OPTIONS_CLEANUP_FREQUENCY_DESC"))

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
		return CreateCountOptions(OFFLINE_FALLBACK_RESULT_OPTIONS)
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
		return CreateCountOptions(OFFLINE_FALLBACK_MAX_OPTIONS)
	end, self:Text("OPTIONS_OFFLINE_FALLBACK_MAX_DESC"))

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
	Settings.CreateDropdown(category, tradeLeadLifetime, CreateTradeLeadOptions, self:Text("OPTIONS_TRADE_LEADS_LIFETIME_DESC"))

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

	Settings.RegisterAddOnCategory(category)
end

function AF:RefreshOptionsPanel()
end
