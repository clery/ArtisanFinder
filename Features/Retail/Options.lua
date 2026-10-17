local _, AF = ...

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

function AF:RegisterFlavorOptions(category, AddSection, RegisterProxySetting, CreateRadioOptions)
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

end
