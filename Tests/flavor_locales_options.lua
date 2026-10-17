local function load(path, AF) assert(loadfile(path))("ArtisanFinder", AF) end
GetLocale = function() return "frFR" end
local locales = {"enUS", "frFR", "deDE", "esES", "esMX", "ptPT", "ptBR", "ruRU", "zhCN", "zhTW"}
for _, flavor in ipairs({"Retail", "Forever"}) do
    local AF = {db = {}}
    load("Flavors/" .. flavor .. ".lua", AF)
    load("Core/Bootstrap.lua", AF)
    for _, locale in ipairs(locales) do load("Locales/" .. locale .. ".lua", AF) end
    assert(not AF.Locales.enUS.CUSTOMER_SIDE_PREVIEW)
    assert(not AF.Locales.enUS.FOREVER_INDICATORS and not AF.Locales.enUS.CHANGELOG_ENTRY_2_1_4,
        "shared locale must not own client messages")
    for _, locale in ipairs(locales) do load("Locales/" .. flavor .. "/" .. locale .. ".lua", AF) end
    if flavor == "Retail" then
        assert(AF.Locales.enUS.CHANGELOG_ENTRY_2_1_4)
        assert(AF.Locales.enUS.CUSTOMER_SIDE_PREVIEW)
        assert(not AF.Locales.enUS.FOREVER_INDICATORS)
    else
        assert(AF.Locales.enUS.FOREVER_INDICATORS)
        assert(not AF.Locales.enUS.CUSTOMER_SIDE_PREVIEW and not AF.Locales.enUS.TUTORIAL_CRAFTER_PREVIEW)
        assert(not AF.Locales.enUS.CHANGELOG_ENTRY_2_1_4)
        assert(AF.Locales.frFR.CLEAR_HELP_SCANS:find("Prénom Nom", 1, true))
        load("Changelogs/Forever.lua", AF)
        local key = AF.CHANGELOG_RECENT_ENTRIES[1].key
        assert(AF:Text(key):find("Modifié", 1, true))
        AF.localeOverride = "enUS"
        assert(AF:Text(key):find("Changed", 1, true), "release notes respect locale override")
    end
    load("UI/Tutorial.lua", AF)
    load("Features/" .. flavor .. "/Tutorial.lua", AF)
    assert(AF.SetupCrafterTutorialButton and AF.BuildCrafterHelpPlateInfo)
    assert(AF.InitializeTutorial and AF.ResetTutorial)
    if flavor == "Forever" then
        AF:InitializeTutorial()
        assert(AF.db.tutorial and not AF.StartCustomerTutorial)
        assert(not AF:IsIntroTutorialActive() and not AF:IsMinimapTutorialActive())
    else
        assert(AF.StartCustomerTutorial and AF.MaybeShowIntroTutorial)
    end
    local sections, settings = {}, {}
    Settings = {
        VarType = {Boolean="boolean", Number="number", String="string"},
        CreateCheckbox = function() end, CreateDropdown = function() end,
        RegisterInitializer = function() end,
        CreateSliderOptions = function(min, max) return {SetLabelFormatter=function() end} end,
        CreateSlider = function() end,
    }
    MinimalSliderWithSteppersMixin = {Label={Right=function() end}}
    CreateSettingsButtonInitializer = function() return {} end
    load("Features/" .. flavor .. "/Options.lua", AF)
    AF:RegisterFlavorOptions({}, function(key) sections[key]=true end,
        function(id, kind, key, default, getter, setter)
            settings[id] = {getter=getter, setter=setter}
            return settings[id]
        end, function() return {} end)
    local allSettings,allSections={},{}
    Settings.RegisterVerticalLayoutCategory=function() return {} end
    Settings.RegisterProxySetting=function(_,id,kind,label,default,getter,setter)
        allSettings[id]={getter=getter,setter=setter}
        return allSettings[id]
    end
    Settings.RegisterAddOnCategory=function() end
    CreateSettingsListSectionHeaderInitializer=function(label)
        allSections[label]=true
        return {}
    end
    AF.GetAdvertisingProfessionRows=function() return {} end
    load("UI/Options.lua",AF)
    AF:InitializeOptions()
    assert(allSettings.ArtisanFinder_ShowOwnCharacterRows,"working own-character preference remains accessible")
    assert(allSettings.ArtisanFinder_OfflineFallbackResults and allSettings.ArtisanFinder_CacheCleanupDays,
        "working item-search fallback and cleanup preferences remain available")
    if flavor=="Forever" then
        assert(not allSections[AF:Text("OPTIONS_SECTION_CUSTOMER")],"Forever has no customer-results section")
        assert(allSections[AF:Text("FOREVER_DISCOVERY_OPTIONS")],"Forever owns its discovery section")
        assert(not allSettings.ArtisanFinder_DefaultSort and not allSettings.ArtisanFinder_FreezeTradeLeadRows
            and not allSettings.ArtisanFinder_AutoDisable_delve,"Forever omits unused controls")
    else
        assert(allSections[AF:Text("OPTIONS_SECTION_CUSTOMER")],"Retail customer settings remain available")
        assert(allSettings.ArtisanFinder_DefaultSort and allSettings.ArtisanFinder_FreezeTradeLeadRows
            and allSettings.ArtisanFinder_AutoDisable_delve,"Retail settings are preserved")
    end
    if flavor == "Forever" then
        assert(sections.FOREVER_INDICATORS and not sections.OPTIONS_SECTION_NOTIFICATIONS)
        assert(settings.ArtisanFinder_Indicator_showFriendlyNames,"explicit friendly-name setting is exposed")
        AF.SetForeverFriendlyNames=function(self,value) self.db.foreverIndicators.showFriendlyNames=value end
        settings.ArtisanFinder_Indicator_showFriendlyNames.setter(false)
        assert(settings.ArtisanFinder_Indicator_showFriendlyNames.getter()==false,"name checkbox saves an explicit no")
        settings.ArtisanFinder_Indicator_showFriendlyNames.setter(true)
        assert(settings.ArtisanFinder_Indicator_showFriendlyNames.getter()==true,"name checkbox saves an explicit yes")
        local offset = settings.ArtisanFinder_Indicator_offset
        offset.setter(-200); assert(offset.getter()==-100)
        offset.setter(100); assert(offset.getter()==30)
        assert(not settings.ArtisanFinder_OrderNotificationSoundEnabled)
    else
        assert(sections.OPTIONS_SECTION_NOTIFICATIONS and not sections.FOREVER_INDICATORS)
        local sound = settings.ArtisanFinder_OrderNotificationSoundEnabled
        sound.setter(false); assert(sound.getter()==false)
        assert(not settings.ArtisanFinder_Indicator_offset)
    end
end
print("PASS isolated locales, translated release notes with live locale override, and client settings")
