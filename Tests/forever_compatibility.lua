strmatch=string.match
local AF={db={},playerName="Buyer Surname",CACHE_MAX_AGE=1209600}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
assert(loadfile("Libs/LibStub/LibStub.lua"))()
assert(loadfile("Libs/LibSerialize/LibSerialize.lua"))()
assert(loadfile("Libs/LibDeflate/LibDeflate.lua"))()
local serializer,deflate=LibStub("LibSerialize"),LibStub("LibDeflate")
load("Flavors/Forever.lua")
load("Core/Bootstrap.lua")
load("Features/Social/Comms.lua")
AF.InitializeComms=function() end AF.RefreshForeverDiscovery=function() end
AF.HandleCompatibilityAddonMessage=function(_,prefix) return prefix=="LinkedInn" end
local now,sent,joined=1000,{},{}
AF.Now=function() return now end AF.NormalizeName=function(_,name) return name end
AF.GetPlayerFullName=function() return AF.playerName end
AF.GetSupportedProfessionID=function(_,id) return (id==164 or id==333 or id==165) and id or nil end
AF.GetProfessionName=function(_,id) return "Profession "..id end
AF.GetDisplayItemName=function(_,id) return "Item "..id end
AF.IsProtectedActionRestricted=function() return false end AF.IsAddonCommsUnavailable=function() return false end
AF.DebugLog=function() end AF.RefreshCustomerResults=function(self) self.refreshed=true end
AF.RefreshForeverNameplates=function() end AF.IsFavoriteArtisan=function() return false end
AF.ForEachArtisanProfile=function() end AF.CustomerEntryMatchesFilter=function() return false end
AF.GetRememberedProfessionLink=function() end AF.GetCachedArtisans=function() return {} end
AF.RememberArtisanContact=function(self,name,target) self.contact={name,target} end
AF.Text=function(_,key) return key end
GetChannelName=function(channel) return channel=="CraftBoardF" and 7 or 8 end
JoinChannelByName=function(channel) joined[channel]=true end
IsInGuild=function() return true end
C_Timer={After=function(_,callback) callback() end}
C_ChatInfo={RegisterAddonMessagePrefix=function() end}
ChatThrottleLib={SendAddonMessage=function(_,_,prefix,message,channel,target)
    sent[#sent+1]={prefix=prefix,message=message,channel=channel,target=target}
end}
load("Features/Forever/Compatibility.lua") load("Features/Forever/GuildDirectory.lua") load("Features/Forever/DiscoverySources.lua") load("Features/Forever/Directory.lua") load("Features/Forever/Hierarchy.lua")
local function wire(prefix,kind,body)
    local compressed=deflate:CompressDeflate(serializer:Serialize(body))
    if prefix=="CBRD" then return kind..deflate:EncodeForWoWAddonChannel(compressed) end
    local message=deflate:EncodeForWoWAddonChannel(string.char(1,kind)..compressed)
    return message:byte(1)<=9 and string.char(4)..message or message
end
local function receive(prefix,kind,body,channel,sender)
    AF:HandleCompatibilityAddonMessage(prefix,wire(prefix,kind,body),channel or "WHISPER",sender or "Remote Crafter")
end
receive("CBRD","H",{v=1,h="book1",n=2,profs={[164]={r=300}}},"GUILD")
assert(#sent==1 and sent[1].prefix=="CBRD" and sent[1].target=="Remote Crafter","CraftBoard hello triggers targeted recipe request")
receive("CBRD","R",{v=1,h="book1",profs={[164]={r=300}},list={{101,"Sword",201,164}},pg=1,pgs=2})
assert(#AF.db.compatibilityDiscoveries.CRAFTBOARD["Remote Crafter"].crafts==0,"partial lists are not committed")
local second=wire("CBRD","R",{v=1,h="book1",list={{102,"Shield",202,164}},pg=2,pgs=2})
AF:HandleCompatibilityAddonMessage("CBRD",string.char(1)..second:sub(1,20),"WHISPER","Remote Crafter")
AF:HandleCompatibilityAddonMessage("CBRD",string.char(2)..second:sub(21,40),"WHISPER","Remote Crafter")
AF:HandleCompatibilityAddonMessage("CBRD",string.char(3)..second:sub(41),"WHISPER","Remote Crafter")
local cb=AF.db.compatibilityDiscoveries.CRAFTBOARD["Remote Crafter"]
assert(#cb.crafts==2 and cb.crafts[2].itemID==202,"AceComm chunks and paged CraftBoard lists assemble")
local rows=AF:GetForeverDirectoryRows("sword",nil,"CRAFTBOARD")
assert(#rows==1 and rows[1].source=="CRAFTBOARD","item-name search and source filter include CraftBoard")
assert(#AF:GetForeverKnownCrafts("Remote Crafter",164)==2,"CraftBoard recipes expand in hierarchy")
AF.currentCustomerItemID=201
assert(#AF:GetForeverDirectoryRows("",nil,"CRAFTBOARD")==1,"selected-item searches include CraftBoard")
AF.currentCustomerItemID=nil
receive("ReleaseGaming",2,{name="RG Crafter",version=9},"WHISPER","RG Crafter")
assert(sent[#sent].prefix=="ReleaseGaming" and sent[#sent].target=="RG Crafter","RG HEAD triggers GET")
local record={version=9,professions={[333]={rank=300,items={301,302},spells={401}}},main="RG Main"}
receive("ReleaseGaming",4,{name="RG Crafter",version=9,record=record},"WHISPER","RG Crafter")
local rg=AF.db.compatibilityDiscoveries.RELEASEGAMING["RG Crafter"]
assert(#rg.crafts==3 and rg.crafts[3].recipeID==401 and AF.contact[2]=="RG Main","RG item crafts, enchants and alt hints import")
assert(#AF:GetCompatibilityDirectoryEntries(301)==1 and #AF:GetForeverKnownCrafts("RG Crafter",333)==3)
local before=#sent
receive("CBRD","Q",{v=1},"WHISPER","Querying Crafter")
assert(#sent==before+1,"discovery identity answers explicit recipe requests with an empty book")
local snapshot=rg
receive("ReleaseGaming",4,{name="Forged Name",version=9,record=record},"WHISPER","RG Crafter")
assert(AF.db.compatibilityDiscoveries.RELEASEGAMING["RG Crafter"]==snapshot,"sender cannot publish another character")
receive("ReleaseGaming",4,{name="Unsolicited",version=9,record=record},"WHISPER","Unsolicited")
assert(not AF.db.compatibilityDiscoveries.RELEASEGAMING.Unsolicited,"unsolicited record is ignored")
receive("CBRD","P",{v=1,id="order",item=201},"GUILD")
AF:HandleCompatibilityAddonMessage("CBRD","broken", "GUILD","Bad Sender")
assert(not AF.db.compatibilityDiscoveries.CRAFTBOARD["Bad Sender"],"malformed/order packets do not import crafters")
assert(AF:HandleCompatibilityAddonMessage("LinkedInn","", "GUILD","Someone"),"Linked Inn handler remains chained")
AF:RefreshCompatibilityDiscovery(true)
assert(sent[#sent].prefix=="ReleaseGaming" or sent[#sent].prefix=="CBRD")
C_AddOns={IsAddOnLoaded=function() return true end}
local count=#sent
AF:RefreshCompatibilityDiscovery(true)
assert(#sent==count,"co-installed addons own outgoing discovery messages")
now=now+1209601
assert(#AF:GetCompatibilityDirectoryEntries()==0,"stale third-party discoveries expire")
print("PASS CraftBoard/Release Gaming actual compressed wire, fragmentation, paging, source/item searches, crafts, validation, expiry and coexistence")
