local _, AF = ...
local INTERVAL, LIFETIME = 120, 360

function AF:SendForeverPresence(chatType, target)
    local ids = {}
    local name = self:NormalizeName(self.playerName or self:GetPlayerFullName())
    if self:IsAvailable() then
        for key, profession in pairs(self.db.artisanProfile.professions or {}) do
            local id = self:GetSupportedProfessionID(key, profession)
            if id and self:IsProfessionAdvertised(name, id) then ids[#ids+1] = id end
        end
    end
    table.sort(ids)
    local parts={"FA", self.PROTOCOL_VERSION, table.concat(ids, ",")}
    if self.MarkAgreementSupport then parts[#parts+1]="c:agreements" parts[#parts+1]="1" end
    if self.GetCompletedAgreementCounts then
        parts[#parts+1]="a:completed" parts[#parts+1]=tostring(self:GetCompletedAgreementCounts())
    end
    local notes={}
    for _,id in ipairs(ids) do
        local profession=self.db.artisanProfile.professions[tostring(id)] or self.db.artisanProfile.professions[id]
        local link=profession and profession.professionLink or self:GetRememberedProfessionLink(name,id)
        if type(link)=="string" and link:find("|Htrade:",1,true) then
            parts[#parts+1]=tostring(id)
            parts[#parts+1]=self:EncodeField(link,2048)
        end
        local level=profession and tonumber(profession.skillLevel)
        local maximum=profession and tonumber(profession.maxSkillLevel)
        if level and level>0 and level<=10000 and level%1==0 then
            parts[#parts+1]="s:"..id
            parts[#parts+1]=tostring(level)..":"..tostring(maximum and maximum>=level and maximum<=10000 and maximum%1==0 and maximum or 0)
        end
        local commission=self:GetProfessionPriceEntry(self.db.artisanProfile,id)
        local price,free=self:GetEntryCommission(commission)
        local note=self:GetEntryNote(commission)
        if note and note~="" then
            notes[id]=self:EncodeField(note,self.MAX_NOTE_BYTES)
        end
        if price~=nil then
            parts[#parts+1]="p:"..id
            parts[#parts+1]=(free and "free:" or "paid:")..tostring(price)
        end
    end
    local sent=self:SendPayloadParts(parts, chatType, target, "BULK", "ForeverPresence")
    -- Keep long notes from making the essential presence packet unsendable.
    if sent then
        for id,note in pairs(notes) do
            local count=math.ceil(#note/120)
            for index=1,count do
                self:SendPayloadParts({"FN",self.PROTOCOL_VERSION,tostring(id),tostring(index),tostring(count),note:sub((index-1)*120+1,index*120)},chatType,target,"BULK","ForeverPresence")
            end
        end
    end
    return sent
end

function AF:RefreshForeverDiscovery(force)
    if self.RefreshLinkedInnDiscovery then self:RefreshLinkedInnDiscovery(force) end
    if self.RefreshCompatibilityDiscovery then self:RefreshCompatibilityDiscovery(force) end
    if not self.db or self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return end
    local now = self:Now()
    local channel = self:GetDiscoveryChannelID()
    if not force and now - (self.foreverPresenceAt or -INTERVAL) < INTERVAL then return end
    local sent = false
    if channel and channel ~= 0 then
        sent = self:SendForeverPresence("CHANNEL", tostring(channel)) or sent
        if not self.foreverDiscoveryRequested then
            self.foreverDiscoveryRequested = self:SendPayloadParts({"FQ", self.PROTOCOL_VERSION}, "CHANNEL", tostring(channel), "BULK", "ForeverDiscovery") == true
        end
    end
    if IsInGuild and IsInGuild() then
        sent = self:SendForeverPresence("GUILD") or sent
        if not self.foreverGuildDiscoveryRequested then
            self.foreverGuildDiscoveryRequested = self:SendPayloadParts({"FQ", self.PROTOCOL_VERSION}, "GUILD", nil, "BULK", "ForeverDiscoveryGuild") == true
        end
    end
    if sent then self.foreverPresenceAt = now end
    self:DebugLog("discovery", "announce sent="..tostring(sent).." channel="..tostring(channel))
end

function AF:HandleFlavorAddonMessage(kind, parts, sender, channel)
    if kind ~= "FA" and kind ~= "FQ" and kind ~= "FN" then return false end
    if not sender or channel ~= "CHANNEL" and channel ~= "GUILD" and channel ~= "WHISPER" then return true end
    if kind=="FN" then
        local presence=self.db.foreverDiscoveries and self.db.foreverDiscoveries[sender]
        local id,index,count=tonumber(parts[3]),tonumber(parts[4]),tonumber(parts[5])
        local chunk=parts[6]
        if not id or not presence or not presence.professions or not presence.professions[id] or not index or not count or index%1~=0 or count%1~=0 or count<1 or count>26 or index<1 or index>count or type(chunk)~="string" or #chunk>120 then return true end
        presence.noteChunks=presence.noteChunks or {}
        local buffer=presence.noteChunks[id]
        if not buffer or buffer.count~=count then buffer={count=count,parts={}} presence.noteChunks[id]=buffer end
        buffer.parts[index]=chunk
        for part=1,count do if not buffer.parts[part] then return true end end
        local note=self:DecodeField(table.concat(buffer.parts))
        presence.noteChunks[id]=nil
        if #note<=self.MAX_NOTE_BYTES then
            presence.commissions=presence.commissions or {}
            presence.commissions[id]=presence.commissions[id] or {}
            presence.commissions[id].note=note
        end
        return true
    end
    if kind == "FQ" then
        -- Requests only belong on shared discovery transports; never recurse.
        if channel == "WHISPER" then return true end
        local now = self:Now()
        self.foreverDiscoveryReplies = self.foreverDiscoveryReplies or {}
        for name, stamp in pairs(self.foreverDiscoveryReplies) do
            if now-stamp >= INTERVAL then self.foreverDiscoveryReplies[name] = nil end
        end
        local last = self.foreverDiscoveryReplies[sender]
        if last and now-last < 60 then return true end
        self.foreverDiscoveryReplies[sender] = now
        C_Timer.After(math.random()*3, function()
            if not AF:IsProtectedActionRestricted() and not AF:IsAddonCommsUnavailable() then
                AF:SendForeverPresence("WHISPER", sender)
            end
        end)
        return true
    end
    if type(parts[3]) ~= "string" or #parts[3] > 128 then return true end
    local professions = {}
    for token in parts[3]:gmatch("[^,]+") do
        local id = token:match("^%d+$") and self:GetSupportedProfessionID(tonumber(token))
        if not id then return true end
        professions[id] = true
    end
    local commissions,skills={},{}
    local completedAgreements
    for index=4,math.min(#parts,64),2 do
        if parts[index]=="c:agreements" and parts[index+1]=="1" and self.MarkAgreementSupport then self:MarkAgreementSupport(sender) end
        if parts[index]=="a:completed" and type(parts[index+1])=="string" and parts[index+1]:match("^%d+$") then
            local count=tonumber(parts[index+1])
            if count and count<=2147483647 then completedAgreements=count end
        end
        local skillID=type(parts[index])=="string" and tonumber(parts[index]:match("^s:(%d+)$"))
        if skillID and professions[skillID] and type(parts[index+1])=="string" then
            local level,maximum=parts[index+1]:match("^(%d+):(%d+)$")
            level,maximum=tonumber(level),tonumber(maximum)
            if level and level>0 and level<=10000 and maximum<=10000 and (maximum==0 or maximum>=level) then
                skills[skillID]={level=level,maximum=maximum>0 and maximum or nil}
            end
        end
        local priceID=type(parts[index])=="string" and tonumber(parts[index]:match("^p:(%d+)$"))
        if priceID and professions[priceID] and type(parts[index+1])=="string" then
            local state,copper=parts[index+1]:match("^(%a+):(%d+)$")
            copper=tonumber(copper)
            if copper and copper<=self.MAX_COMMISSION_COPPER and (state=="free" and copper==0 or state=="paid" and copper>0) then
                commissions[priceID]=commissions[priceID] or {}
                commissions[priceID].priceCopper=copper
                commissions[priceID].freeCommission=state=="free"
                commissions[priceID].commissionSpecified=true
            end
        end
        local noteID=type(parts[index])=="string" and tonumber(parts[index]:match("^n:(%d+)$"))
        if noteID and professions[noteID] and type(parts[index+1])=="string" then
            local note=self:DecodeField(parts[index+1])
            if #note<=self.MAX_NOTE_BYTES then commissions[noteID]=commissions[noteID] or {} commissions[noteID].note=note end
        end
        local id=tonumber(parts[index])
        if id and professions[id] and type(parts[index+1])=="string" then
            local link=self:DecodeField(parts[index+1])
            if #link<=2048 and link:find("|Htrade:",1,true) and self:GetTradeAdvertisementProfessionCandidates(link)[id] then
                self:RememberProfessionLink(sender,id,link)
            end
        end
    end
    self.db.foreverDiscoveries = self.db.foreverDiscoveries or {}
    self.db.foreverDiscoveries[sender] = next(professions) and {
        name=sender, professions=professions, commissions=commissions, skills=skills, completedAgreements=completedAgreements, updatedAt=self:Now(), expiresAt=self:Now()+LIFETIME,
    } or nil
    self:DebugLog("discovery", "presence sender="..sender.." professions="..parts[3])
    if self.RefreshCustomerResults then self:RequestCustomerResultsRefresh() end
    if self.RefreshForeverNameplates then self:RefreshForeverNameplates() end
    return true
end

function AF:InitializeFlavorDiscovery()
    if self.InitializeAgreements then self:InitializeAgreements() end
    if GetChannelName and LeaveChannelByName and GetChannelName("ArtisanFinderForever")~=0 then
        LeaveChannelByName("ArtisanFinderForever")
    end
    self.db.foreverDiscoveries = self.db.foreverDiscoveries or {}
    for name, entry in pairs(self.db.foreverDiscoveries) do
        if type(entry) ~= "table" or self:Now()-(tonumber(entry.updatedAt) or 0) > self.CACHE_MAX_AGE then
            self.db.foreverDiscoveries[name] = nil
        end
    end
    if not self.foreverGuildDiscoveryFrame then
        local frame=CreateFrame("Frame")
        self.foreverGuildDiscoveryFrame=frame
        for _,event in ipairs({"PLAYER_GUILD_UPDATE","CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED","CLUB_MEMBER_UPDATED","CLUB_MEMBERS_UPDATED"}) do
            frame:RegisterEvent(event)
        end
        frame:SetScript("OnEvent",function(_,event,unitOrClub)
            if event=="PLAYER_GUILD_UPDATE" then
                if unitOrClub and unitOrClub~="player" then return end
                AF.foreverGuildDiscoveryRequested=nil
                AF:RefreshForeverDiscovery(true)
            elseif unitOrClub and C_Club and C_Club.GetGuildClubId and unitOrClub~=C_Club.GetGuildClubId() then
                return
            end
            AF:QueueGuildRosterCacheRefresh(false)
        end)
    end
    C_Timer.After(10, function() AF:RefreshForeverDiscovery() end)
    if self.foreverDiscoveryTicker then self.foreverDiscoveryTicker:Cancel() end
    self.foreverDiscoveryTicker = C_Timer.NewTicker(30, function() AF:RefreshForeverDiscovery() end)
    if self.InitializeLinkedInnDiscovery then self:InitializeLinkedInnDiscovery() end
    if self.InitializeCompatibilityDiscovery then self:InitializeCompatibilityDiscovery() end
end

if hooksecurefunc then
    for _, method in ipairs({"SetAvailabilityMode", "SetProfessionAdvertised", "SetProfessionPrice"}) do
        hooksecurefunc(AF, method, function() AF:RefreshForeverDiscovery(true) end)
    end
end
