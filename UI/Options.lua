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

local ORDER_SOUND_OPTIONS = {
	{ key = "CATALOG_SHOP_OPEN_LOADING_SCREEN", labelKey = "OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN" },
	{ key = "UI_IG_STORE_PURCHASE_DELIVERED_TOAST_01", labelKey = "OPTIONS_ORDER_SOUND_STORE_DELIVERY" },
	{ key = "UI_IG_STORE_WINDOW_OPEN_BUTTON", labelKey = "OPTIONS_ORDER_SOUND_STORE_OPEN" },
	{ key = "UI_BNET_TOAST", labelKey = "OPTIONS_ORDER_SOUND_BNET_TOAST" },
	{ key = "UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST", labelKey = "OPTIONS_ORDER_SOUND_PROFESSION_TOAST" },
	{ key = "UI_EVENT_SCHEDULER_CHIME", labelKey = "OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME" },
	{ key = "UI_GARRISON_START_WORK_ORDER", labelKey = "OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER" },
	{ key = "IG_BACKPACK_COIN_SELECT", labelKey = "OPTIONS_ORDER_SOUND_BACKPACK_COIN" },
	{ key = "SOULBINDS_ACTIVATE_SOULBIND", labelKey = "OPTIONS_ORDER_SOUND_SOULBIND" },
	{ key = "GM_CHAT_WARNING", labelKey = "OPTIONS_ORDER_SOUND_GM_CHAT_WARNING" },
	{ key = "AUCTION_WINDOW_OPEN", labelKey = "OPTIONS_ORDER_SOUND_AUCTION" },
}

local ORDER_SOUND_CHANNEL_OPTIONS = {
	{ key = "Master", labelKey = "OPTIONS_SOUND_CHANNEL_DEFAULT" },
	{ key = "SFX", labelKey = "OPTIONS_SOUND_CHANNEL_SFX" },
	{ key = "Music", labelKey = "OPTIONS_SOUND_CHANNEL_MUSIC" },
	{ key = "Ambience", labelKey = "OPTIONS_SOUND_CHANNEL_AMBIENCE" },
	{ key = "Dialog", labelKey = "OPTIONS_SOUND_CHANNEL_DIALOG" },
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

	AddSection("OPTIONS_SECTION_NOTIFICATIONS")
	local orderNotificationSoundEnabled = RegisterProxySetting(
		"ArtisanFinder_OrderNotificationSoundEnabled",
		Settings.VarType.Boolean,
		"OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED",
		true,
		function()
			return AF.db.orderNotificationsEnabled ~= false and AF.db.orderNotificationSoundEnabled ~= false
		end,
		function(value)
			AF.db.orderNotificationsEnabled = nil
			AF.db.orderNotificationSoundEnabled = value ~= false
		end
	)
	Settings.CreateCheckbox(category, orderNotificationSoundEnabled, self:Text("OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC"))

	local orderNotificationBannerEnabled = RegisterProxySetting(
		"ArtisanFinder_OrderNotificationBannerEnabled",
		Settings.VarType.Boolean,
		"OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED",
		true,
		function()
			return AF.db.orderNotificationsEnabled ~= false and AF.db.orderNotificationBannerEnabled ~= false
		end,
		function(value)
			AF.db.orderNotificationsEnabled = nil
			AF.db.orderNotificationBannerEnabled = value ~= false
		end
	)
	Settings.CreateCheckbox(category, orderNotificationBannerEnabled, self:Text("OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC"))

	local hideSelfAltOrderNotifications = RegisterProxySetting(
		"ArtisanFinder_HideSelfAltOrderNotifications",
		Settings.VarType.Boolean,
		"OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS",
		false,
		function()
			return AF.db.hideSelfAltOrderNotifications == true
		end,
		function(value)
			AF.db.hideSelfAltOrderNotifications = value == true
		end
	)
	Settings.CreateCheckbox(category, hideSelfAltOrderNotifications, self:Text("OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC"))

	local hideSelfAltFulfilledNotifications = RegisterProxySetting(
		"ArtisanFinder_HideSelfAltFulfilledNotifications",
		Settings.VarType.Boolean,
		"OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS",
		false,
		function()
			return AF.db.hideSelfAltFulfilledNotifications == true
		end,
		function(value)
			AF.db.hideSelfAltFulfilledNotifications = value == true
		end
	)
	Settings.CreateCheckbox(category, hideSelfAltFulfilledNotifications, self:Text("OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC"))

	local orderSound = RegisterProxySetting(
		"ArtisanFinder_OrderNotificationSound",
		Settings.VarType.String,
		"OPTIONS_ORDER_SOUND",
		"CATALOG_SHOP_OPEN_LOADING_SCREEN",
		function()
			return AF.db.orderNotificationSound or "CATALOG_SHOP_OPEN_LOADING_SCREEN"
		end,
		function(value)
			AF.db.orderNotificationSound = value or "CATALOG_SHOP_OPEN_LOADING_SCREEN"
			if AF.PlayOrderNotificationSound then
				AF:PlayOrderNotificationSound(true)
			end
		end
	)
	Settings.CreateDropdown(category, orderSound, function()
		return CreateRadioOptions(ORDER_SOUND_OPTIONS, "key")
	end, self:Text("OPTIONS_ORDER_SOUND_DESC"))

	local orderSoundChannel = RegisterProxySetting(
		"ArtisanFinder_OrderNotificationChannel",
		Settings.VarType.String,
		"OPTIONS_ORDER_SOUND_CHANNEL",
		"default",
		function()
			return AF.db.orderNotificationChannel or "default"
		end,
		function(value)
			AF.db.orderNotificationChannel = value or "default"
		end
	)
	Settings.CreateDropdown(category, orderSoundChannel, function()
		return CreateRadioOptions(ORDER_SOUND_CHANNEL_OPTIONS, "key")
	end, self:Text("OPTIONS_ORDER_SOUND_CHANNEL_DESC"))

	Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
		"",
		self:Text("OPTIONS_PLAY_ORDER_SOUND"),
		function()
			if AF.PlayOrderNotificationSound then
				AF:PlayOrderNotificationSound(true)
			end
		end,
		self:Text("OPTIONS_PLAY_ORDER_SOUND_DESC"),
		true
	))

	Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(
		"",
		self:Text("OPTIONS_CLEAR_ORDER_NOTIFICATIONS"),
		function()
			if AF.ClearOrderNotifications then
				AF:ClearOrderNotifications()
			end
		end,
		self:Text("OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC"),
		true
	))

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
