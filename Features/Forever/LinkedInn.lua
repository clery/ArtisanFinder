local _, AF = ...
-- Wire adapter for Linked Inn H1/Q1/Q2/D1 (Sync.lua, v1.5.0).
-- Independent implementation; no Linked Inn code or assets are bundled.
local PREFIX, CHANNEL = "LinkedInn", "LinkedInnSync"
local professions = {alchemy=171,blacksmithing=164,enchanting=333,engineering=202,
    leatherworking=165,tailoring=197,cooking=185,["first aid"]=129,fishing=356}
local function split(text, separator)
    local out = {}
    for part in (text..separator):gmatch("(.-)"..separator:gsub("(%W)","%%%1")) do out[#out+1]=part end
    return out
end
local function b36(number)
    local result=""
    number=math.max(0,math.floor(tonumber(number) or 0))
    repeat
        local digit=number%36
        result=("0123456789abcdefghijklmnopqrstuvwxyz"):sub(digit+1,digit+1)..result
        number=math.floor(number/36)
    until number==0
    return result
end
local function number36(value)
    if type(value)=="string" and #value>0 and #value<=8 and not value:find("[^0-9a-z]") then return tonumber(value,36) end
end

function AF:BuildLinkedInnAdvertisement()
    local sections, summary = {}, {}
    if self:IsAvailable() then
        local name=self.playerName or self:GetPlayerFullName()
        local keys={} for key in pairs(professions) do keys[#keys+1]=key end table.sort(keys)
        for _,key in ipairs(keys) do
            local id=professions[key]
            local profile=self.db.artisanProfile
            local profession=profile.professions[tostring(id)] or profile.professions[id]
            if profession and self:IsProfessionAdvertised(name,id) then
                local ids, seen = {}, {}
                for recipe,known in pairs(profession.recipes or {}) do
                    recipe=tonumber(recipe)
                    if known and recipe and recipe>0 and recipe%1==0 and not seen[recipe] then ids[#ids+1]=recipe seen[recipe]=true end
                end
                table.sort(ids)
                local deltas,last={},0
                for _,recipe in ipairs(ids) do deltas[#deltas+1]=b36(recipe-last) last=recipe end
                local link=profession.professionLink or self:GetRememberedProfessionLink(name,id) or ""
                link=link:match("|Htrade:([^|]+)|h") or link:match("^trade:(.+)$") or ""
                if not link:match("^Player%-[%w%-]+:%d+:%d+$") then link="" end
                local rank,max=b36(profession.skillLevel or profession.rank),b36(profession.maxSkillLevel or profession.max)
                local recipes=#ids>0 and table.concat(deltas,".") or "-"
                sections[#sections+1]=table.concat({key,rank,max,link,recipes},"~")
                summary[#summary+1]=table.concat({key,rank,max,#ids>0 and b36(#ids) or "-"},"~")
                if #sections==8 then break end
            end
        end
    end
    local payload=table.concat(sections,";")
    if payload~=self.linkedInnOwnPayload then
        self.linkedInnOwnPayload=payload
        self.db.linkedInnVersion=math.max(self:Now(),(tonumber(self.db.linkedInnVersion) or 0)+1)
    end
    return payload,b36(self.db.linkedInnVersion or self:Now()),table.concat(summary,";")
end

function AF:SendLinkedInn(message,channel,target)
    -- Let Linked Inn own its identity/version when both addons are loaded.
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LinkedInn") then return false end
    if #message>250 or self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return false end
    if channel=="CHANNEL" then
        local id=GetChannelName(CHANNEL)
        if not id or id==0 then return false end
        target=tostring(id)
    end
    ChatThrottleLib:SendAddonMessage("BULK",PREFIX,message,channel,target,"ArtisanFinderLinkedInn")
    return true
end

function AF:RefreshLinkedInnDiscovery(force)
    if not self.db or self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return end
    local now=self:Now()
    if not force and now-(self.linkedInnHelloAt or -720)<720 then return end
    if self:EnsureDiscoveryNetworkChannel(CHANNEL)==0 then return end
    self:HideDiscoveryNetworkChannelFromChat(CHANNEL)
    local _,version,summary=self:BuildLinkedInnAdvertisement()
    -- Empty summaries greet peers without advertising a profession.
    local class=UnitClass and select(2,UnitClass("player")) or ""
    local hello=table.concat({"H1",version,class or "",summary,"","","","J"},"|")
    local sent=self:SendLinkedInn(hello,"CHANNEL")
    if IsInGuild and IsInGuild() then self:SendLinkedInn(hello,"GUILD") end
    if sent then self.linkedInnHelloAt=now end
end

function AF:DecodeLinkedInnProfessions(payload)
    if type(payload)~="string" or #payload==0 or #payload>8000 then return end
    local out={}
    local sections=split(payload,";")
    if #sections>8 then return end
    for _,section in ipairs(sections) do
        local fields=split(section,"~")
        local id=professions[fields[1]]
        if #fields~=5 or not id or out[id] or not number36(fields[2]) or not number36(fields[3]) then return end
        local profession={rank=number36(fields[2]),max=number36(fields[3]),recipes={}}
        if fields[4]~="" then
            if not fields[4]:match("^Player%-[%w%-]+:%d+:%d+$") then return end
            local link="|Htrade:"..fields[4].."|h["..self:GetProfessionName(id).."]|h"
            if not self:GetTradeAdvertisementProfessionCandidates(link)[id] then return end
            profession.link=link
        end
        if fields[5]~="-" and fields[5]~="" then
            local codes=split(fields[5],".")
            if #codes>1500 then return end
            local recipe=0
            for _,code in ipairs(codes) do
                local delta=number36(code)
                if not delta or delta<=0 or recipe+delta>2147483647 then return end
                recipe=recipe+delta profession.recipes[#profession.recipes+1]=recipe
            end
        end
        out[id]=profession
    end
    return out
end

function AF:ApplyLinkedInnProfessions(sender,version,payload)
    local decoded=self:DecodeLinkedInnProfessions(payload)
    if not decoded then self:DebugLog("linkedinn","rejected invalid profession list from "..sender) return end
    self.db.linkedInnDiscoveries=self.db.linkedInnDiscoveries or {}
    self.db.linkedInnDiscoveries[sender]={name=sender,version=version,professions=decoded,updatedAt=self:Now(),expiresAt=self:Now()+1200}
    for id,profession in pairs(decoded) do
        if profession.link then self:RememberProfessionLink(sender,id,profession.link) end
    end
    self:DebugLog("linkedinn","received profession list from "..sender)
    self:RequestCustomerResultsRefresh() self:RefreshForeverNameplates()
end

function AF:HandleCompatibilityAddonMessage(prefix,message,channel,sender)
    if prefix~=PREFIX then return false end
    if type(message)~="string" or #message>255 or type(sender)~="string" then return true end
    if channel~="CHANNEL" and channel~="GUILD" and channel~="PARTY" and channel~="RAID" and channel~="WHISPER" then return true end
    sender=self:NormalizeName(sender)
    if not sender or sender==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then return true end
    local now=self:Now()
    self.linkedInnPeers=self.linkedInnPeers or {}
    for name,peer in pairs(self.linkedInnPeers) do if now-peer.at>120 then self.linkedInnPeers[name]=nil end end
    local peer=self.linkedInnPeers[sender]
    if not peer then
        local count=0 for _ in pairs(self.linkedInnPeers) do count=count+1 end
        if count>=100 then return true end
        peer={at=now,count=0} self.linkedInnPeers[sender]=peer
    end
    peer.count=peer.count+1 if peer.count>60 then return true end
    local fields=split(message,"|")
    local kind,version=fields[1],fields[2]
    if kind=="H1" and number36(version) and type(fields[4])=="string" then
        local cached=self.db.linkedInnDiscoveries and self.db.linkedInnDiscoveries[sender]
        if cached and cached.version==version then
            cached.updatedAt=now cached.expiresAt=now+1200
        elseif not peer.asked or now-peer.asked>=120 then
            peer.asked=now self:SendLinkedInn("Q1|"..version,"WHISPER",sender)
        end
        self:RefreshLinkedInnDiscovery()
    elseif kind=="D1" and #fields==5 and number36(version) then
        local index,total=number36(fields[3]),number36(fields[4])
        if not index or not total or total<1 or total>40 or index<1 or index>total or #fields[5]>200 then return true end
        if not peer.buffer or peer.buffer.version~=version or peer.buffer.total~=total then
            peer.buffer={version=version,total=total,chunks={},at=now}
        end
        local buffer=peer.buffer
        if now-buffer.at>90 then peer.buffer=nil return true end
        if buffer.chunks[index] and buffer.chunks[index]~=fields[5] then peer.buffer=nil return true end
        buffer.chunks[index]=fields[5]
        for part=1,total do if not buffer.chunks[part] then return true end end
        peer.buffer=nil
        self:ApplyLinkedInnProfessions(sender,version,table.concat(buffer.chunks))
    elseif kind=="Q1" or kind=="Q2" and fields[3]==(self.playerName or self:GetPlayerFullName()) then
        if peer.answered and now-peer.answered<30 then return true end
        local payload,ownVersion=self:BuildLinkedInnAdvertisement()
        local total=math.ceil(#payload/200)
        if total<1 or total>40 then return true end
        peer.answered=now
        for part=1,total do
            local text=table.concat({"D1",ownVersion,b36(part),b36(total),payload:sub((part-1)*200+1,part*200)},"|")
            C_Timer.After((part-1)*1.1,function()
                if AF:IsAvailable() and AF:BuildLinkedInnAdvertisement()==payload then AF:SendLinkedInn(text,"WHISPER",sender) end
            end)
        end
    end
    return true
end

function AF:GetLinkedInnDirectoryEntries(itemID)
    local rows={}
    for name,presence in pairs(self.db.linkedInnDiscoveries or {}) do
        if self:Now()-(tonumber(presence.updatedAt) or 0)<=self.CACHE_MAX_AGE then
            for id,profession in pairs(presence.professions or {}) do
                local recipeID
                if itemID then
                    for _,recipe in ipairs(profession.recipes or {}) do
                        if tonumber(itemID)==-recipe or self:GetRecipeOutputItemIDs(recipe)[tonumber(itemID)] then recipeID=recipe break end
                    end
                end
                if not itemID or recipeID then
                    rows[#rows+1]={name=name,target=name,professionID=id,professionLink=profession.link,
                        itemID=itemID,recipeID=recipeID,professionName=self:GetProfessionName(id),updatedAt=presence.updatedAt,linkedInn=true}
                end
            end
        end
    end
    return rows
end

function AF:ForEachLinkedInnItem(callback)
    local seen={}
    for _,presence in pairs(self.db.linkedInnDiscoveries or {}) do
        if self:Now()-(tonumber(presence.updatedAt) or 0)<=self.CACHE_MAX_AGE then
            for _,profession in pairs(presence.professions or {}) do
                for _,recipe in ipairs(profession.recipes or {}) do
                    if not seen[recipe] then
                        seen[recipe]=true
                        for itemID in pairs(self:GetRecipeOutputItemIDs(recipe)) do
                            if itemID>0 then callback(itemID) end
                        end
                    end
                end
            end
        end
    end
end

function AF:InitializeLinkedInnDiscovery()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    self.db.linkedInnDiscoveries=self.db.linkedInnDiscoveries or {}
    for name,presence in pairs(self.db.linkedInnDiscoveries) do
        if type(presence)~="table" or self:Now()-(tonumber(presence.updatedAt) or 0)>self.CACHE_MAX_AGE then
            self.db.linkedInnDiscoveries[name]=nil
        end
    end
    C_Timer.After(12,function() AF:RefreshLinkedInnDiscovery(true) end)
end
