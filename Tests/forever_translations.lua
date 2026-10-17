local AF={Locales={}}
GetLocale=function() return "enUS" end
local locales={"enUS","frFR","deDE","esES","esMX","ptBR","ptPT","ruRU","zhCN","zhTW"}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
-- Only keys explicitly owned by the Forever overlay are part of this contract.
local overlay={}
local target={Locales={enUS=overlay}}
assert(loadfile("Locales/Forever/enUS.lua"))("ArtisanFinder",target)
local function placeholders(value)
    local found={}
    for token in value:gmatch("%%[sdif]") do found[#found+1]=token end
    return table.concat(found,",")
end
local count=0
for _,locale in ipairs(locales) do
    if locale~="enUS" then load("Locales/"..locale..".lua") load("Locales/Forever/"..locale..".lua") end
    local values=AF.Locales[locale]
    for key,value in pairs(overlay) do
        if not key:find("^CHANGELOG_") then
            assert(type(values[key])=="string" and values[key]~="",locale.." missing Forever translation "..key)
            assert(placeholders(values[key])==placeholders(value),locale.." mismatched format arguments for "..key)
            count=count+1
        end
    end
end
print("PASS "..count.." Forever UI translations across ten locales, including format-placeholder parity")
