local _, AF = ...

function AF:RegisterFlavorOptions(category, AddSection, RegisterProxySetting, _)
    AddSection("FOREVER_DISCOVERY_OPTIONS")
    local ownRows=RegisterProxySetting("ArtisanFinder_ShowOwnCharacterRows",Settings.VarType.Boolean,
        "OPTIONS_SHOW_OWN_CHARACTER_ROWS",false,
        function() return AF.db.showOwnCharacterRows==true end,
        function(value)
            AF.db.showOwnCharacterRows=value==true
            if AF.RefreshCustomerResults then AF:RefreshCustomerResults() end
        end)
    Settings.CreateCheckbox(category,ownRows,AF:Text("OPTIONS_SHOW_OWN_CHARACTER_ROWS_DESC"))
	AddSection("FOREVER_INDICATORS")
	AF.db.foreverIndicators = AF.db.foreverIndicators or { enabled = true, size = 24, offset = -20, characters = {} }
	for _, option in ipairs({
		{ key = "enabled", label = "FOREVER_INDICATORS_ENABLED", default = true },
        { key = "showFriendlyNames", label = "FOREVER_SHOW_FRIENDLY_NAMES", default = true },
		{ key = "size", label = "FOREVER_INDICATORS_SIZE", default = 24, min = 12, max = 32 },
		{ key = "offset", label = "FOREVER_INDICATORS_OFFSET", default = -20, min = -100, max = 30 },
	}) do
		local key, config = option.key, option
		local setting = RegisterProxySetting("ArtisanFinder_Indicator_" .. key,
			type(config.default) == "boolean" and Settings.VarType.Boolean or Settings.VarType.Number,
			config.label, config.default,
			function()
				local value = AF.db.foreverIndicators[key]
				if value == nil then return config.default end
				return value
			end,
			function(value)
				if type(config.default) ~= "boolean" then
					value = math.max(config.min, math.min(config.max, tonumber(value) or config.default))
				end
                if key=="showFriendlyNames" then AF:SetForeverFriendlyNames(value) return end
				AF.db.foreverIndicators[key] = value
				if AF.RefreshForeverNameplates then AF:RefreshForeverNameplates() end
			end)
		if type(config.default) == "boolean" then
			Settings.CreateCheckbox(category, setting, AF:Text(config.label))
		else
			local options = Settings.CreateSliderOptions(config.min, config.max, 1)
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
			Settings.CreateSlider(category, setting, options, AF:Text(config.label))
		end
	end

end
