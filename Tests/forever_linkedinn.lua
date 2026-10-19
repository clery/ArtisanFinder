local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
strsplit=function(separator,text)
    local out={} for value in (text..separator):gmatch("(.-)"..separator) do out[#out+1]=value end
    return unpack(out)
end
local now,sent,channel=1000,{},0
local pending={}
C_Timer={After=function(_,fn) pending[#pending+1]=fn end}
GetChannelName=function() return channel end
JoinChannelByName=function(name) assert(name=="LinkedInnSync") channel=4 end
UnitClass=function() return "Mage","MAGE" end
IsInGuild=function() return false end
ChatThrottleLib={SendAddonMessage=function(_,priority,prefix,message,transport,target)
    assert(#message<=250) sent[#sent+1]={prefix=prefix,text=message,channel=transport,target=target}
end}
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Utils/Formatting.lua")
load("Features/Social/Comms.lua") load("Features/Forever/GuildDirectory.lua") load("Features/Forever/DiscoverySources.lua") load("Features/Forever/Directory.lua")
load("Features/Forever/LinkedInn.lua")
AF.db={artisanProfile={professions={
    ["333"]={recipes={["1000"]=true,["1005"]=true},skillLevel=100,maxSkillLevel=150,
        professionLink="|Htrade:Player-1:7413:333|h[Enchanting]|h"},
    ["165"]={recipes={["2000"]=true}},
}},linkedInnDiscoveries={}}
AF.playerName="Local Crafter"
AF.Now=function() return now end
AF.NormalizeName=function(_,name) return name end
AF.IsAvailable=function() return true end
AF.IsProfessionAdvertised=function(_,_,id) return id==333 end
AF.IsProtectedActionRestricted=function() return false end
AF.IsAddonCommsUnavailable=function() return false end
AF.IsSecretValue=function() return false end
AF.GetPlayerFullName=function() return AF.playerName end
AF.GetProfessionName=function(_,id) return id==333 and "Enchanting" or "Leatherworking" end
AF.GetRememberedProfessionLink=function() return nil end
AF.RememberProfessionLink=function(self,name,id,link) self.remembered=link end
AF.GetTradeAdvertisementProfessionCandidates=function(_,link)
    return link:find(":333|h",1,true) and {[333]=true} or {}
end
AF.RefreshCustomerResults=function(self) self.refreshed=true end
AF.RefreshForeverNameplates=function(self) self.iconsRefreshed=true end
AF.DebugLog=function() end
AF.GetRecipeOutputItemIDs=function(_,id) return {[id+10000]=true} end
AF.ForEachArtisanProfile=function() end
AF.CustomerEntryMatchesFilter=function() return true end
AF.IsFavoriteArtisan=function() return false end
AF.HasJoinedTradeChannel=function() return true end
AF.VisibleServerChannelsStable=function() return true end
AF:RefreshLinkedInnDiscovery()
assert(channel==4,"compatibility channel joined automatically")
AF:RefreshLinkedInnDiscovery()
assert(sent[1].prefix=="LinkedInn" and sent[1].text:find("H1|",1,true)==1)
local payload,version=AF:BuildLinkedInnAdvertisement()
assert(payload=="enchanting~2s~46~Player-1:7413:333~rs.5",payload)
assert(not payload:find("leatherworking",1,true),"unadvertised professions never sent")
local function receive(text,name)
    AF:OnAddonMessage("LinkedInn",text,"WHISPER",name or "Remote Crafter")
end
receive("H1|abc|MAGE|enchanting~2s~46~2||||J")
assert(sent[#sent].text=="Q1|abc" and sent[#sent].target=="Remote Crafter")
local incoming="enchanting~2s~46~Player-22:7413:333~rs.5"
-- Out-of-order chunks and duplicates assemble atomically.
receive("D1|abc|2|2|"..incoming:sub(21))
assert(not AF.db.linkedInnDiscoveries["Remote Crafter"])
receive("D1|abc|2|2|"..incoming:sub(21))
receive("D1|abc|1|2|"..incoming:sub(1,20))
local remote=AF.db.linkedInnDiscoveries["Remote Crafter"]
assert(remote and remote.professions[333].recipes[2]==1005 and AF.remembered)
assert(AF.refreshed and AF.iconsRefreshed)
AF.GetDisplayItemName=function(_,id) return "Known item "..id end
local matches=AF:FindForeverItems("11005")
assert(#matches==1 and matches[1].itemID==11005,"name search includes Linked Inn recipe outputs")
local rows=AF:GetLinkedInnDirectoryEntries(11005)
assert(#rows==1 and rows[1].recipeID==1005 and rows[1].linkedInn)
local groups=AF:GetForeverDirectoryRows("",nil,"LINKEDINN")
assert(#groups==1 and groups[1].source=="LINKEDINN")
assert(AF:GetForeverNameplateObservation("Remote Crafter").source=="LINKEDINN")
receive("Q1|"..version)
local work=pending pending={} for _,fn in ipairs(work) do fn() end
assert(sent[#sent].text:find("D1|"..version.."|1|1|",1,true)==1,"Linked Inn requests receive scanned recipe data")
local before=#sent receive("Q1|"..version)
assert(#pending==0 and #sent==before,"list replies throttled")
assert(not AF:DecodeLinkedInnProfessions("enchanting~2s~46~~0"))
assert(not AF:DecodeLinkedInnProfessions("enchanting~2s~46~Player-1:2108:165~rs"))
receive("D1|abc|1|zz|bad","Malformed Sender")
assert(not AF.db.linkedInnDiscoveries["Malformed Sender"])
now=now+1201
assert(not AF:GetForeverNameplateObservation("Remote Crafter"),"old shared lists do not imply current advertising")
assert(#AF:GetLinkedInnDirectoryEntries()==1,"history retained after live expiry")
local old=#sent
C_AddOns={IsAddOnLoaded=function() return true end}
assert(not AF:SendLinkedInn("H1|abc","WHISPER","Remote Crafter") and #sent==old,"coinstalled Linked Inn owns its wire identity")
C_AddOns=nil
AF.IsAvailable=function() return false end
assert(AF:BuildLinkedInnAdvertisement()=="","availability off suppresses profession sharing")
if arg and arg[1] then
    -- Optional source-reference interoperability check; not required by CI and
    -- no third-party implementation is copied into this repository.
    local LI={GATHERING={},On=function() end,Listen=function() end,RETAIL=false,
        RecipeList=function(prof) return prof.ids or {} end}
    assert(loadfile(arg[1].."/Sync.lua"))("LinkedInn",LI)
    local decoded=LI.Sync.Decode(payload)
    assert(decoded and decoded[1].ids[2]==1005,"upstream decoder accepts ArtisanFinder packet")
    local encoded=LI.Sync.Encode({enchanting={rank=100,max=150,link="trade:Player-22:7413:333",recipes=true,ids={1000,1005}}})
    assert(AF:DecodeLinkedInnProfessions(encoded)[333].recipes[2]==1005,"ArtisanFinder accepts upstream encoder packet")
end
print("PASS Linked Inn protocol interoperability, chunking, source filters, recipes, links, expiry, throttling and coexistence")

AF.IsAvailable=function() return true end
AF.GetProfessionName=function() return "Enchantement" end
local translatedPayload=AF:BuildLinkedInnAdvertisement()
assert(translatedPayload==payload,"Linked Inn requires fixed English profession tokens regardless of client locale")
local translated=assert(AF:DecodeLinkedInnProfessions(incoming))
assert(translated[333].link:find("[Enchantement]",1,true) and translated[333].recipes[2]==1005,"Linked Inn tokens become numeric profession IDs and local link labels")
print("PASS Linked Inn fixed protocol tokens remain locale independent")
