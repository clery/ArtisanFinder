local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Core/Data.lua")
UnitName=function() return "Fess","Oakenshield" end
load("Features/Forever/Names.lua") load("Features/Social/Comms.lua")
AF.Now=function() return 1000 end
AF.IsSecretValue=function() return false end
AF.IsAddonCommsUnavailable=function() return false end
AF.GetDiscoveryChannelID=function() return 7 end
AF.EncodeField=function(_,value) return tostring(value or "") end
AF.DecodeField=function(_,value) return value end
AF.EncodeNote=function(_,value) return value or "" end
AF.DebugLog=function() end AF.IsDevTrafficLogsEnabled=function() return false end
IsInGuild=function() return false end
local sent={}
AF.SendAddon=function(_,payload,channel,target) sent[#sent+1]={payload=payload,channel=channel,target=target} return true end
AF.playerName="Buyer Smith"
assert(AF:BroadcastQuery(100,0),"standalone item queries do not need a known profession")
assert(sent[1].payload=="Q|FF1|100|0|1000|Buyer Smith","full name and wildcard sent intact")
AF.IsForever=false
assert(not AF:BroadcastQuery(100,0),"Retail still requires a profession from its order form")
AF.IsForever=true
AF.playerName="Fess Oakenshield"
AF.IsAvailable=function() return true end
AF.IsCurrentCharacterOnlyAvailable=function() return true end
AF.IsProfessionAdvertised=function() return true end
local profile={professions={},items={["100"]={itemID=100,recipeID=200,professionID=164,foreverRecipe=true}}}
AF.ForEachArtisanProfile=function(_,callback) callback("Fess Oakenshield",profile) end
AF.GetItemPriceForProfile=function() return 500,false,"Bring materials" end
AF.GetRememberedProfessionLink=function() return nil end
AF.SendPayloadParts=function(_,parts,channel,target)
 sent[#sent+1]={parts=parts,channel=channel,target=target} return true
end
AF:HandleQuery({"Q","FF1",100,0,1000,"Buyer Smith"},"Buyer Smith","CHANNEL")
local reply=sent[#sent]
assert(reply.parts and reply.parts[1]=="R" and reply.parts[12]=="Fess Oakenshield","any-profession lookup returns the actual full crafter name")
assert(reply.target=="Buyer Smith" and reply.parts[4]==164,"reply whispers full requester name and actual profession")
print("PASS live Forever item query/reply across unknown professions with full unique names; Retail behavior isolated")
