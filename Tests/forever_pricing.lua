local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
GetLocale=function() return "enUS" end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
load("Utils/Formatting.lua") load("Features/Forever/Pricing.lua")
AF.playerName="Local Crafter"
AF.NormalizeName=function(_,name) return name end
AF.GetPlayerFullName=function() return AF.playerName end
AF.GetProfessionName=function(_,id) return tostring(id) end
AF.GetProfessionPriceEntry=function(_,profile,id) return profile.professionPrices and profile.professionPrices[tostring(id)] end
local function paid(value) return {priceCopper=value,commissionSpecified=true} end
local profile={items={["100"]=paid(20000)},professionPrices={["333"]=paid(10000)}}
AF.db={artisanProfile=profile,artisanCharacters={},foreverDiscoveries={
    ["Remote Crafter"]={commissions={[333]=paid(30000)}}}}
local own={name="Local Crafter",professionID=333,itemID=100}
assert(AF:GetForeverEntryCommission(own,100)==20000,"item override takes precedence")
assert(AF:GetForeverEntryCommission(own)==10000,"browsing uses profession default rather than arbitrary item rate")
profile.items["100"]={commissionSpecified=false}
assert(AF:GetForeverEntryCommission(own,100)==10000,"unspecified item uses default")
profile.items["100"]={priceCopper=0,freeCommission=true,commissionSpecified=true}
local price,free=AF:GetForeverEntryCommission(own,100)
assert(price==0 and free,"explicit any commission overrides paid default")
local remote={name="Remote Crafter",professionID=333,itemID=100,priceCopper=50000,commissionSpecified=true}
assert(AF:GetForeverEntryCommission(remote,100)==50000,"live item response overrides announced default")
assert(AF:GetForeverEntryCommission(remote)==30000,"browsing remote profession uses announced default")
remote.commissionSpecified=false remote.priceCopper=nil
assert(AF:GetForeverEntryCommission(remote,100)==30000,"missing item quote falls back to announced rate")
assert(AF:GetForeverEntryCommission({name="Unknown Crafter",professionID=333,tradeLead=true})==nil,"trade links do not invent a price")
local text,details=AF:GetForeverDirectoryPrice({offers={own,remote}})
assert(text==AF:FormatMoney(10000) and #details==2,"multiple profession rates show the minimum without a prefix and retain details")
assert(AF:GetForeverDirectoryPrice({offers={{name="Unknown Crafter",professionID=333,linkedInn=true}}})=="—")
AF.currentCustomerItemID=100
text=AF:GetForeverDirectoryPrice({offers={own}})
assert(text==AF:Text("FREE_COMMISSION"),"free item commission remains visible")
print("PASS Forever directory pricing: item/default precedence, explicit free, remote quotes, missing data and grouped rates")
