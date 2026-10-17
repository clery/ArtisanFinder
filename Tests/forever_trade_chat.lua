local function load(path, AF) assert(loadfile(path))("ArtisanFinder", AF) end
C_Spell={GetSpellName=function(id) if id==7411 then return "Enchanting" end end}
GetLocale=function() return "enUS" end
local AF={db={artisanProfile={items={}}, tradeLeadCache={}},playerName="Local Crafter"}
load("Flavors/Forever.lua",AF)
load("Core/Bootstrap.lua",AF)
load("Core/Util.lua",AF)
load("Core/Data.lua",AF)
load("Features/Social/TradeChat.lua",AF)
load("Features/Forever/TradeChat.lua",AF)
load("Features/Forever/GuildDirectory.lua",AF) load("Features/Forever/DiscoverySources.lua",AF) load("Features/Forever/Directory.lua",AF)
AF.IsProtectedActionRestricted=function() return false end
AF.IsInUnavailableActivity=function() return false end
AF.IsSecretValue=function() return false end
AF.IsDevTrafficLogsEnabled=function() return false end
AF.DebugLog=function() end
AF.NormalizeName=function(_,name) return name end
AF.Now=function() return 1000 end
AF.RefreshCustomerResults=function(self) self.refreshed=(self.refreshed or 0)+1 end
AF.ForEachArtisanProfile=function() end
AF.CustomerEntryMatchesFilter=function() return true end
AF.IsFavoriteArtisan=function() return false end
AF.Text=function(_,key) return key end
AF:InitializeTradeChat()
local function advertise(name,spell,profession,label)
    local link="|cffffd000|Htrade:Player-4618-00164129:"..spell..":"..profession.."|h["..label.."]|h|r"
    AF:OnTradeChatMessage("LFW "..link,name,nil,"2. Trade - City",nil,nil,nil,nil,"Trade")
end
advertise("Test Cook",2550,185,"Cooking")
advertise("Test Healer",3274,129,"First Aid")
advertise("Test Leatherworker",2108,165,"Leatherworking")
local rows=AF:GetDirectoryEntries("")
assert(#rows==3,"every observed profession reaches the unfiltered directory")
local seen={}
for _,row in ipairs(rows) do seen[row.name]=row.professionID end
assert(seen["Test Cook"]==185 and seen["Test Healer"]==129 and seen["Test Leatherworker"]==165)
assert(AF.refreshed==3,"visible directory refreshes on incoming advertisements")
local key,lead=next(AF.db.tradeLeadCache)
lead.professionCandidates={}
AF:InitializeTradeChat()
assert(next(lead.professionCandidates),"previously missed professions repaired on reload")
local candidates=AF:GetTradeAdvertisementProfessionCandidates("|Htrade:Player-164-129:2108:165|h[Leatherworking]|h")
assert(candidates[165] and not candidates[164] and not candidates[129],"GUID digits cannot invent professions")
assert(not next(AF:GetTradeAdvertisementProfessionCandidates("|Htrade:invalid|h[Unknown]|h")))
assert(AF:GetTradeAdvertisementProfessionCandidates("|Htrade:7411:300:300:guid:recipes|h[Enchanting]|h")[333])
assert(AF:GetTradeAdvertisementProfessionCandidates("|Htrade:Player-1:7411:333:extra|h[Enchanting]|h")[333])
assert(AF:GetTradeAdvertisementProfessionCandidates("|Htrade:unknown-format|h[Enchanting]|h")[333])
AF:OnTradeChatMessage("|cffffd000|Htrade:unknown-format|h[Enchanting]|h|r LFW", "Chonky Obama",nil,"2. Trade - English",nil,nil,nil,nil,"Trade - English")
local screenshotFound=false
for _,row in ipairs(AF:GetDirectoryEntries("")) do
    if row.name=="Chonky Obama" then assert(row.professionID==333);screenshotFound=true end
end
assert(screenshotFound,"screenshot advertisement appears under its full player name")
C_TradeSkillUI={GetProfessionInfoByRecipeID=function(id)
    if id==20010 then return {parentProfessionID=333} end
    if id==19690 then return {parentProfessionID=164} end
end}
AF:OnTradeChatMessage("LFW |cffffd000|Henchant:20010|h[Enchant Bracer]|h|r", "Test Enchanter",nil,"2. Trade",nil,nil,nil,nil,"Trade")
AF:OnTradeChatMessage("LFW |Henchant:19690|h[Crafted armor]|h", "Test Smith",nil,"2. Trade",nil,nil,nil,nil,"Trade")
seen={}
for _,row in ipairs(AF:GetDirectoryEntries("")) do seen[row.name]=row.professionID end
assert(seen["Test Enchanter"]==333 and seen["Test Smith"]==164,"recipe advertisements resolve actual profession")
for _,lead in pairs(AF.tradeLeads) do
    if lead.name=="Test Enchanter" then assert(not lead.professionLink and lead.recipeID==20010) end
end
assert(#AF:GetAdditionalTradeAdvertisements("|Henchant:99999|h[Unknown]|h")==0,"unknown recipe does not guess Enchanting")
print("PASS Forever Trade Chat ingestion through discovery, secondary professions, cached repair and GUID-safe parsing")

local logs={}
AF.DebugLog=function(_,category,message) logs[#logs+1]="["..category.."] "..message end
AF.db.debugEnabled=true
AF:OnTradeChatMessage("LFW |Htrade:Player-1:7411:333|h[Enchanting]|h", "Trace Enchanter",nil,"2. Trade - English",nil,nil,nil,nil,"Trade - English")
local trace=table.concat(logs,"\n")
assert(trace:find("payload=LFW |Htrade:",1,true),"raw hyperlink is available without copying it from chat")
assert(trace:find("parsed advertisements=1",1,true) and trace:find("profession=333",1,true))
AF:PrintTradeChatDiagnostics()
trace=table.concat(logs,"\n")
assert(trace:find("STATUS registered=",1,true) and trace:find("CACHE active=",1,true) and trace:find("DIRECTORY rows=",1,true))
AF:OnTradeChatMessage("plain text", "Test Player",nil,"2. Trade",nil,nil,nil,nil,"Trade")
assert(AF.tradeChatDiagnostics.stage=="no recognized links")
local before=#logs
AF.IsSecretValue=function() return true end
AF:OnTradeChatMessage("SECRET-CONTENT", "Secret Sender",nil,"2. Trade",nil,nil,nil,nil,"Trade")
assert(AF.tradeChatDiagnostics.stage=="secret payload")
for i=before+1,#logs do assert(not logs[i]:find("SECRET-CONTENT",1,true)) end
print("PASS Trade Chat diagnostics: raw links, parser stages, event/cache/filter snapshot and secret guard")

-- Reproduce the live log: native Enchanting link, Trade - English, automatic
-- availability marked unavailable. Passive discovery must still store it.
AF.IsSecretValue=function() return false end
AF.IsInUnavailableActivity=function() return true end
local message="|cffffd000|Htrade:Player-4618-006E4378:7413:333|h[Enchanting]|h|r LFW"
AF:OnTradeChatMessage(message,"Chonky Obama",nil,"2. Trade - English",nil,nil,nil,nil,"Trade - English")
assert(AF.tradeChatDiagnostics.stage=="stored","Forever discovery ignores automatic availability state")
local found=false
for _,row in ipairs(AF:GetDirectoryEntries("")) do
    if row.name=="Chonky Obama" and row.professionID==333 then found=true end
end
assert(found,"exact live advertisement reaches the table despite unavailable activity")
AF.capabilities.passiveTradeDiscovery=false
local count=AF.tradeChatDiagnostics.stored
AF:OnTradeChatMessage(message,"Retail Control",nil,"2. Trade - English",nil,nil,nil,nil,"Trade - English")
assert(AF.tradeChatDiagnostics.stage=="unavailable activity" and AF.tradeChatDiagnostics.stored==count,
    "Retail activity gating remains unchanged")
AF.capabilities.passiveTradeDiscovery=true
AF.IsProtectedActionRestricted=function() return true end
AF:OnTradeChatMessage(message,"Restricted Control",nil,"2. Trade - English",nil,nil,nil,nil,"Trade - English")
assert(AF.tradeChatDiagnostics.stage=="protected activity restriction","actual API restrictions still enforced")
print("PASS exact live Enchanting advertisement with unavailable activity; Retail policy and protected restrictions preserved")
