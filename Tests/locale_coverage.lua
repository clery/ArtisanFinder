-- Every shipped language must provide every shared and client-owned string.
local locales = {"enUS", "frFR", "deDE", "esES", "esMX", "ptPT", "ptBR", "ruRU", "zhCN", "zhTW"}
local function load(path, AF)
    assert(loadfile(path))("ArtisanFinder", AF)
end
local function formats(value)
    local result = {}
    -- Literal percentages consume no argument. Preserve argument order and types.
    value = value:gsub("%%%%", "")
    for token in value:gmatch("%%[-+ #0]*%d*%.?%d*[cdeEfgGiouXxqs]") do
        result[#result + 1] = token:sub(-1)
    end
    return table.concat(result, ",")
end
local function owned(layer, locale)
    local values = {}
    local AF = {Locales = {[locale] = values}}
    load("Locales/" .. layer .. locale .. ".lua", AF)
    return AF.Locales[locale]
end
local checked = 0
for _, layer in ipairs({"", "Retail/", "Forever/"}) do
    local english = owned(layer, "enUS")
    for _, locale in ipairs(locales) do
        GetLocale = function() return locale end
        local values = owned(layer, locale)
        for key, value in pairs(english) do
            assert(type(values[key]) == "string" and values[key]:match("%S"),
                layer .. locale .. " missing translation: " .. key)
            assert(formats(values[key]) == formats(value),
                layer .. locale .. " mismatched format arguments: " .. key)
            checked = checked + 1
        end
    end
end
for _, flavor in ipairs({"Retail", "Forever"}) do
    for _, locale in ipairs(locales) do
        GetLocale = function() return locale end
        local AF = {Locales = {}}
        for _, code in ipairs(locales) do load("Locales/" .. code .. ".lua", AF) end
        for _, code in ipairs(locales) do load("Locales/" .. flavor .. "/" .. code .. ".lua", AF) end
        load("Changelogs/" .. flavor .. ".lua", AF)
        assert(AF.L == AF.Locales[locale], flavor .. " selected wrong runtime language: " .. locale)
        local key = AF.CHANGELOG_RECENT_ENTRIES[1].key
        assert(AF:Text(key) == AF.Locales[locale][key], flavor .. " release notes fell back: " .. locale)
        AF.localeOverride = "frFR"
        assert(AF:Text(key) == AF.Locales.frFR[key], "release-note language override ignored")
    end
end
print("PASS " .. checked .. " shared/client locale entries, format arguments, runtime language selection and release notes")
