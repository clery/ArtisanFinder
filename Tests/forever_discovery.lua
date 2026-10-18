local function load(path, AF) assert(loadfile(path))("ArtisanFinder", AF) end
local now, pending, clients = 1000, {}, {}
strsplit=function(separator,text)
    local parts={}
    for part in (text..separator):gmatch("(.-)"..separator) do parts[#parts+1]=part end
    return unpack(parts)
end
C_Timer={After=function(_,fn) pending[#pending+1]=fn end,
    NewTicker=function(_,fn) return {tick=fn,Cancel=function() end} end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function(self,key,fn) self[key]=fn end} end
C_ChatInfo={RegisterAddonMessagePrefix=function() end}
IsInGuild=function() return false end
local function flush()
    local work=pending pending={}
    for _,fn in ipairs(work) do fn() end
end
local function new(name,available)
    local AF={}
    load("Flavors/Forever.lua",AF) load("Core/Bootstrap.lua",AF)
    load("Features/Social/Comms.lua",AF)
    load("Features/Forever/GuildDirectory.lua",AF) load("Features/Forever/DiscoverySources.lua",AF) load("Features/Forever/Directory.lua",AF)
    load("Features/Forever/Discovery.lua",AF)
    AF.GetProfessionPriceEntry=function(_,profile,id) return profile.professionPrices and profile.professionPrices[tostring(id)] end
    AF.GetRememberedProfessionLink=function(self,who,id) return self.links and self.links[who..id] end
    AF.RememberProfessionLink=function(self,who,id,link) self.links=self.links or {} self.links[who..id]=link end
    load("Utils/Formatting.lua",AF)
    AF.GetTradeAdvertisementProfessionCandidates=function(_,link) return link:find(":333|h",1,true) and {[333]=true} or {} end
    AF.playerName=name
    AF.db={artisanProfile={professions={["333"]={id=333},["165"]={id=165}}},foreverDiscoveries={}}
    AF.NormalizeName=function(_,value) return value end
    AF.GetPlayerFullName=function() return name end
    AF.Now=function() return now end
    AF.IsAvailable=function(self) return self.available end AF.available=available
    AF.IsProfessionAdvertised=function(_,_,id) return id==333 end
    AF.GetSupportedProfessionID=function(_,id) id=tonumber(id) if id==333 or id==165 then return id end end
    AF.IsSecretValue=function() return false end
    AF.IsProtectedActionRestricted=function() return false end
    AF.IsAddonCommsUnavailable=function() return false end
    AF.GetDiscoveryChannelID=function() return 7 end
    AF.QueueDiscoveryChannelJoin=function() end
    AF.DebugLog=function() end AF.IsDevTrafficLogsEnabled=function() return false end
    AF.RefreshCustomerResults=function(self) self.refreshed=true end
    AF.RefreshForeverNameplates=function(self) self.nameplatesRefreshed=true end
    AF.SendPayloadParts=function(self,parts,channel,target)
        self.sends=(self.sends or 0)+1
        for other,peer in pairs(clients) do
            if other~=name and (channel~="WHISPER" or other==target) then
                peer:OnAddonMessage(self.PREFIX,table.concat(parts,"|"),channel,name)
            end
        end
        return true
    end
    AF.ForEachArtisanProfile=function() end
    AF.CustomerEntryMatchesFilter=function() return true end
    AF.IsFavoriteArtisan=function() return false end
    clients[name]=AF
    return AF
end
local crafter=new("Crafter Surname",true)
crafter.db.artisanProfile.professions["333"].professionLink="|cffffd000|Htrade:Player-1:7413:333|h[Enchanting]|h|r"
crafter.db.artisanProfile.professionPrices={["333"]={priceCopper=12500,commissionSpecified=true,note="Bring materials | tips welcome"}}
crafter.db.artisanProfile.professions["333"].skillLevel=225
crafter.db.artisanProfile.professions["333"].maxSkillLevel=300
local browser=new("Browser Surname",false)
browser:InitializeComms() flush() flush()
local presence=browser.db.foreverDiscoveries["Crafter Surname"]
assert(presence.skills[333].level==225 and presence.skills[333].maximum==300,"native presence exchanges profession levels")
assert(presence.commissions[333].note=="Bring materials | tips welcome","default notes survive wire encoding")
assert(presence.commissions[333].priceCopper==12500,"default commissions are announced with professions")
assert(presence and presence.professions[333] and not presence.professions[165],"joining browser discovers existing advertising crafter without item queries")
assert(browser.refreshed and browser.nameplatesRefreshed)
assert(browser:GetRememberedProfessionLink("Crafter Surname",333)==crafter.db.artisanProfile.professions["333"].professionLink,"discovery shares openable profession links")
local rows=browser:GetDirectoryEntries("")
assert(#rows==1 and rows[1].professionID==333 and rows[1].name=="Crafter Surname")
assert(browser:GetForeverNameplateObservation("Crafter Surname").source=="ADDON")
browser.db.linkedInnDiscoveries={["Crafter Surname"]={updatedAt=now+1,expiresAt=now+600,professions={[165]={}}}}
local observation=browser:GetForeverNameplateObservation("Crafter Surname")
assert(observation.source=="ADDON" and observation.professions[333] and not observation.professions[165],
    "native advertisement wins over newer Linked Inn observation without mixing professions")
local nativeExpiry=presence.expiresAt
presence.expiresAt=now
observation=browser:GetForeverNameplateObservation("Crafter Surname")
assert(observation.source=="LINKEDINN" and observation.professions[165] and not observation.professions[333],
    "expired native advertisement falls back to valid Linked Inn observation")
presence.expiresAt=nativeExpiry
local sent=crafter.sends
crafter:OnAddonMessage(crafter.PREFIX,"FQ|FF1","CHANNEL","Browser Surname") flush()
assert(crafter.sends==sent,"requests throttled per peer")
now=now+120
crafter:RefreshForeverDiscovery() flush()
assert(browser.db.foreverDiscoveries["Crafter Surname"].expiresAt==now+360,"heartbeat refreshes expiry")
crafter.available=false crafter:RefreshForeverDiscovery(true)
assert(not browser.db.foreverDiscoveries["Crafter Surname"],"availability off withdraws presence")
assert(browser:GetForeverNameplateObservation("Crafter Surname").source=="LINKEDINN",
    "native withdrawal removes native presence while retaining independent Linked Inn observation")
browser.db.linkedInnDiscoveries=nil
assert(not browser:GetForeverNameplateObservation("Crafter Surname"),"native withdrawal cannot leave an advertising icon without another source")
crafter.available=true crafter:RefreshForeverDiscovery(true)
now=now+361
assert(not browser:GetForeverNameplateObservation("Crafter Surname"),"expired presence cannot leave overhead icon")
assert(#browser:GetDirectoryEntries("")==1,"expired presence retained as discovery history")
browser:OnAddonMessage(browser.PREFIX,"FA|FF1|999999","CHANNEL","Malformed Sender")
assert(not browser.db.foreverDiscoveries["Malformed Sender"])
browser:OnAddonMessage("ARTFIND1","FA|FF1|333","CHANNEL","Retail Sender")
assert(not browser.db.foreverDiscoveries["Retail Sender"],"Retail traffic remains isolated")
print("PASS automatic Forever discovery handshake, heartbeat, directory/nameplates, withdrawal, throttling and expiry")

local before=crafter.sends
crafter.IsAddonCommsUnavailable=function() return true end
crafter:RefreshForeverDiscovery(true)
assert(crafter.sends==before,"restricted communication never sends discovery packets")

-- Notes are chunked independently so a long default note cannot suppress discovery.
crafter.IsProtectedActionRestricted=function() return false end
crafter.IsAddonCommsUnavailable=function() return false end
crafter.available=true
local longNote=string.rep("Craft | ",32)
crafter.db.artisanProfile.professionPrices["333"]={note=longNote}
crafter:SendForeverPresence("WHISPER","Browser Surname")
local fresh=browser.db.foreverDiscoveries["Crafter Surname"]
assert(fresh and fresh.commissions[333].note==longNote,"long notes assemble without losing pipes or blocking presence")
assert(fresh.commissions[333].priceCopper==nil,"note-only profession does not invent a commission")

IsInGuild=function() return true end
Enum={ClubMemberPresence={Offline=3,Online=1}}
C_Club={GetGuildClubId=function() return 42 end,GetClubMembers=function() return {1,2,3} end,
    GetMemberInfo=function(_,id)
        if id==1 then return {name="Guild Firstname Surname",profession1ID=333,profession2ID=165,presence=1} end
        if id==2 then return {name="Offline Guildmate",profession1ID=333,presence=3} end
        return {name="Unknown Profession",profession1ID=99999}
    end}
local guildRows=browser:GetForeverDirectoryRows("",nil,"GUILD")
assert(#guildRows==2 and guildRows[1].source=="GUILD","guild professions appear with their own filter/source, unsupported professions excluded")
local member=guildRows[1]
assert(member.name=="Guild Firstname Surname" and member.professions[333] and member.professions[165],"guild discovery preserves full names and combines both professions")
assert(member.entry.guildDiscovery and not member.entry.addonPresence and not member.entry.priceCopper,"guild discovery does not invent availability or prices")
assert(not browser:GetForeverNameplateObservation("Guild Firstname Surname"),"guild profession data alone does not imply active advertising")
GetNumGuildTradeSkill=function() return 2 end
GetGuildTradeSkillInfo=function(index)
    if index==1 then return 333,false,nil,"Enchanting" end
    return nil,nil,nil,nil,nil,nil,nil,"Guild Firstname Surname",nil,nil,true
end
assert(#browser:GetForeverGuildDirectoryEntries()==3,"legacy and club profession data deduplicate")
local observed=browser:GetForeverGuildDirectoryEntries()[1].updatedAt
assert(observed==now,"online guild member is observed now")
local function guildEntry(name)
    for _,entry in ipairs(browser:GetForeverGuildDirectoryEntries()) do if entry.name==name then return entry end end
end
assert(guildEntry("Offline Guildmate").updatedAt==0,"never-seen offline member has no observation timestamp")
local oldMemberInfo=C_Club.GetMemberInfo
C_Club.GetMemberInfo=function(club,id)
    local member=oldMemberInfo(club,id)
    if id==1 then member.presence=3 end
    return member
end
GetNumGuildTradeSkill=function() return 0 end
now=now+60
assert(guildEntry("Guild Firstname Surname").updatedAt==observed,"offline member retains last online observation")
now=now+60
assert(guildEntry("Guild Firstname Surname").updatedAt==observed,"offline roster refresh cannot advance observation")
C_Club.GetMemberInfo=oldMemberInfo
now=now+60
assert(guildEntry("Guild Firstname Surname").updatedAt==now,"returning online advances observation")
browser.foreverGuildDirectoryCache=nil
C_Club.GetClubMembers=function() return {1,2,3,4} end
C_Club.GetMemberInfo=function(club,id)
    if id==4 then return {name=browser.playerName,profession1ID=333,presence=1} end
    return oldMemberInfo(club,id)
end
GetNumGuildTradeSkill=function() return 2 end
GetGuildTradeSkillInfo=function(index)
    if index==1 then return 333,false,nil,"Enchanting" end
    return nil,nil,nil,nil,nil,nil,nil,browser.playerName,nil,nil,true
end
for _,entry in ipairs(browser:GetForeverGuildDirectoryEntries()) do
    assert(entry.name~=browser.playerName,"current character must not be listed as a guild discovery through club or legacy APIs")
end
IsInGuild=function() return false end
assert(#browser:GetForeverGuildDirectoryEntries()==0,"leaving guild removes roster discoveries immediately")
local refreshed=false
browser.QueueGuildRosterCacheRefresh=function(_,request) assert(request==false) refreshed=true end
browser.foreverGuildDiscoveryFrame.OnEvent(nil,"CLUB_MEMBER_UPDATED")
assert(refreshed,"guild roster changes refresh discovery")
print("PASS guild roster profession discovery, full names, sources, deduplication, guild leave and updates")
