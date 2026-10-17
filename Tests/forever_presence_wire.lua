-- Real serialization/compression round trip, including binary pipe bytes.
strmatch=string.match
for _,path in ipairs({"Libs/LibStub/LibStub.lua","Libs/LibSerialize/LibSerialize.lua","Libs/LibDeflate/LibDeflate.lua"}) do dofile(path) end
strsplit=function(separator,text)
    local out={} for value in (text..separator):gmatch("(.-)"..separator) do out[#out+1]=value end
    return unpack(out)
end
local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Utils/Formatting.lua")
load("Features/Social/Comms.lua") load("Features/Forever/Discovery.lua") load("Features/Forever/Pricing.lua")
AF.db={artisanProfile={professions={}}}
AF.playerName="Local Crafter"
AF.NormalizeName=function(_,name) return name end
AF.GetPlayerFullName=function() return AF.playerName end
AF.IsSecretValue=function() return false end
AF.Now=function() return 1000 end
AF.DebugLog=function() end AF.IsDevTrafficLogsEnabled=function() return false end
AF.GetSupportedProfessionID=function(_,id) id=tonumber(id) if id==129 or id==165 or id==185 then return id end end
AF.GetTradeAdvertisementProfessionCandidates=function(_,link)
    local id=tonumber(link:match(":(%d+)|h")) return id and {[id]=true} or {}
end
AF.RememberProfessionLink=function() end
AF.RefreshCustomerResults=function() end AF.RefreshForeverNameplates=function() end
AF.GetProfessionPriceEntry=function() end
local parts={"FA","FF1","129,165,185"}
for _,id in ipairs({129,165,185}) do
    parts[#parts+1]=tostring(id)
    parts[#parts+1]="{p}cffffd000{p}Htrade:Player-4618-"..string.format("%08X",11*9301)..":2108:"..id.."{p}h[Profession]{p}h{p}r"
    parts[#parts+1]="p:"..id parts[#parts+1]="paid:"..11*101
end
local wire
AF.SendAddon=function(_,payload) wire=payload return true end
assert(AF:SendPayloadParts(parts,"CHANNEL","7"))
assert(wire:sub(1,2)=="Z|" and #wire<=255)
local _,pipes=wire:gsub("|","")
assert(pipes>2,"fixture exercises a binary delimiter inside the compressed body")
AF:OnAddonMessage(AF.PREFIX,wire,"CHANNEL","Remote Crafter")
local presence=AF.db.foreverDiscoveries and AF.db.foreverDiscoveries["Remote Crafter"]
assert(presence and presence.commissions[165].priceCopper==1111,"actual compressed wire retains announced default commission")
assert(AF:GetForeverEntryCommission({name="Remote Crafter",professionID=165})==1111,"received default reaches directory pricing")
AF:OnAddonMessage(AF.PREFIX,"FA|FF1|165|p:165|free:0","CHANNEL","Remote Crafter")
local price,free=AF:GetForeverEntryCommission({name="Remote Crafter",professionID=165})
assert(price==0 and free,"plain packets and explicit any-commission remain compatible")
print("PASS actual compressed presence with binary delimiters retains default commissions and directory prices")
