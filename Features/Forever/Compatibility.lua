local _, AF = ...
-- Independent discovery readers for CraftBoard v1 and Release Gaming protocol 1.
-- Only profession/recipe data is consumed; order-board traffic is ignored.
local networks={CBRD={source="CRAFTBOARD",channel="CraftBoardF",addon="CraftBoard"},
    ReleaseGaming={source="RELEASEGAMING",channel="RGamingAddonChan",addon="ReleaseGaming"}}
local function integer(value,max)
    return type(value)=="number" and value>0 and value%1==0 and value<=max and value or nil
end
local function libraries() return LibStub("LibSerialize",true),LibStub("LibDeflate",true) end
local function validName(value)
    return type(value)=="string" and #value>0 and #value<=96 and not value:find("[%c|]")
end

function AF:SendCompatibilityDiscovery(prefix,kind,body,distribution,target)
    local network=networks[prefix]
    if not network or self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return false end
    -- Co-installed addons own their version and outgoing discovery identity.
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(network.addon) then return false end
    local serialize,deflate=libraries()
    if not serialize or not deflate then return false end
    local data=deflate:CompressDeflate(serialize:Serialize(body))
    local message
    if prefix=="CBRD" then message=kind..deflate:EncodeForWoWAddonChannel(data)
    else message=deflate:EncodeForWoWAddonChannel(string.char(1,kind)..data) end
    if #message>250 then return false end
    if distribution=="CHANNEL" then
        local id=GetChannelName(network.channel)
        if not id or id==0 then return false end
        target=tostring(id)
    end
    if message:byte(1)<=9 then message=string.char(4)..message end
    ChatThrottleLib:SendAddonMessage("BULK",prefix,message,distribution,target,"ArtisanFinderCompatibility")
    return true
end

function AF:StoreCompatibilityDiscovery(source,name,professions,crafts,version,busy)
    self.db.compatibilityDiscoveries=self.db.compatibilityDiscoveries or {}
    local records=self.db.compatibilityDiscoveries[source] or {}
    self.db.compatibilityDiscoveries[source]=records
    records[name]={name=name,professions=professions,crafts=crafts,version=version,
        updatedAt=self:Now(),expiresAt=self:Now()+900,busy=busy==true}
    self:DebugLog("compatibility",source.." received "..name.." crafts="..#crafts)
    self:RequestCustomerResultsRefresh() self:RefreshForeverNameplates()
end

local function professions(addon,data)
    if type(data)~="table" then return end
    local ids,count={},0
    for id in pairs(data) do
        count=count+1 if count>24 then return end
        id=addon:GetSupportedProfessionID(tonumber(id))
        if id then ids[id]=true end
    end
    return ids
end

function AF:ReadCraftBoardDiscovery(sender,kind,data,peer,distribution)
    if data.v~=1 then return end
    if kind=="Q" and distribution=="WHISPER" then
        if peer.answered and self:Now()-peer.answered<120 then return end
        peer.answered=self:Now()
        self:SendCompatibilityDiscovery("CBRD","R",{v=1,h="ArtisanFinder-discovery",list={},profs={}},"WHISPER",sender)
        return
    end
    if kind=="H" and distribution~="WHISPER" then
        if type(data.h)~="string" or #data.h>64 or type(data.n)~="number" or not integer(data.n+1,2001) then return end
        local ids=professions(self,data.profs) if not ids then return end
        local records=self.db.compatibilityDiscoveries and self.db.compatibilityDiscoveries.CRAFTBOARD
        local old=records and records[sender]
        local crafts=old and old.crafts or {}
        self:StoreCompatibilityDiscovery("CRAFTBOARD",sender,ids,data.n==0 and {} or crafts,data.h,data.b)
        if data.n>0 and (not old or old.version~=data.h or #crafts==0) and (not peer.asked or self:Now()-peer.asked>=60) then
            peer.asked=self:Now() peer.hash=data.h peer.busy=data.b==true
            self:SendCompatibilityDiscovery("CBRD","Q",{v=1},"WHISPER",sender)
        end
    elseif kind=="R" and peer.asked and self:Now()-peer.asked<=180 then
        if type(data.h)~="string" or data.h~=peer.hash or type(data.list)~="table" or #data.list>2000 then return end
        local page,total=data.pg or 1,data.pgs or 1
        if not integer(page,8) or not integer(total,8) or page>total then return end
        local ids=professions(self,data.profs or {}) if not ids then return end
        local buffer=peer.pages
        if not buffer or buffer.hash~=data.h or buffer.total~=total then
            buffer={hash=data.h,total=total,pages={},ids={}} peer.pages=buffer
        end
        if buffer.pages[page] then return end
        local crafts={}
        for _,row in ipairs(data.list) do
            local recipe=type(row)=="table" and row[1] or row
            if not integer(recipe,100000000) then return end
            local id=type(row)=="table" and self:GetSupportedProfessionID(tonumber(row[4]))
            if not id then local only for key in pairs(ids) do if only then only=nil break end only=key end id=only end
            if id then
                local itemID=type(row)=="table" and integer(row[3],100000000)
                local title=type(row)=="table" and row[2]
                crafts[#crafts+1]={recipeID=recipe,itemID=itemID or -recipe,professionID=id,
                    craftName=type(title)=="string" and #title<=100 and not title:find("[%c|]") and title or nil}
                buffer.ids[id]=true
            end
        end
        for id in pairs(ids) do buffer.ids[id]=true end
        buffer.pages[page]=crafts
        local all={}
        for index=1,total do
            if not buffer.pages[index] then return end
            for _,craft in ipairs(buffer.pages[index]) do all[#all+1]=craft if #all>2000 then peer.pages=nil return end end
        end
        peer.pages=nil peer.asked=nil
        self:StoreCompatibilityDiscovery("CRAFTBOARD",sender,buffer.ids,all,data.h,peer.busy)
    end
end

function AF:ReadReleaseGamingDiscovery(sender,kind,data,peer,distribution)
    if kind==3 and distribution=="WHISPER" and data.name==(self.playerName or self:GetPlayerFullName()) then
        if peer.answered and self:Now()-peer.answered<120 then return end
        peer.answered=self:Now()
        local class=UnitClass and select(2,UnitClass("player"))
        local level=UnitLevel and UnitLevel("player")
        if class and level then
            self:SendCompatibilityDiscovery("ReleaseGaming",4,{name=data.name,version=1,
                record={version=1,class=class,level=level,professions={}}},"WHISPER",sender)
        end
        return
    end
    if not validName(data.name) or self:NormalizeName(data.name)~=sender then return end
    if not integer(data.version,2147483647) then return end
    if kind==1 or kind==2 or kind==5 then
        if kind==2 and distribution~="WHISPER" then return end
        local records=self.db.compatibilityDiscoveries and self.db.compatibilityDiscoveries.RELEASEGAMING
        local old=records and records[sender]
        if old then old.updatedAt=self:Now() old.expiresAt=self:Now()+900 end
        if (not old or old.version~=data.version) and (not peer.asked or self:Now()-peer.asked>=60) then
            peer.asked=self:Now()
            self:SendCompatibilityDiscovery("ReleaseGaming",3,{name=sender},"WHISPER",sender)
        end
    elseif kind==4 and distribution=="WHISPER" and peer.asked and self:Now()-peer.asked<=180 then
        local record=data.record
        if type(record)~="table" or record.version~=data.version then return end
        local ids=professions(self,record.professions) if not ids then return end
        local crafts={}
        for id,profession in pairs(record.professions) do
            id=self:GetSupportedProfessionID(tonumber(id))
            if id then
                if type(profession)~="table" or type(profession.items)~="table" or #profession.items>600
                    or type(profession.spells)~="table" or #profession.spells>300 then return end
                for _,itemID in ipairs(profession.items) do
                    if not integer(itemID,100000000) then return end
                    crafts[#crafts+1]={itemID=itemID,professionID=id}
                end
                for _,recipeID in ipairs(profession.spells) do
                    if not integer(recipeID,100000000) then return end
                    crafts[#crafts+1]={itemID=-recipeID,recipeID=recipeID,professionID=id}
                end
            end
        end
        peer.asked=nil
        self:StoreCompatibilityDiscovery("RELEASEGAMING",sender,ids,crafts,data.version)
        -- A main link is a hint, not permission to publish recipes for someone else.
        if validName(record.main) and self.RememberArtisanContact then self:RememberArtisanContact(sender,record.main) end
    end
end

function AF:ReceiveCompatibilityDiscovery(prefix,message,distribution,sender)
    local network=networks[prefix] if not network then return false end
    if type(message)~="string" or #message>255 or not validName(sender) then return true end
    if distribution~="CHANNEL" and distribution~="GUILD" and distribution~="WHISPER" and distribution~="PARTY" and distribution~="RAID" then return true end
    sender=self:NormalizeName(sender)
    if not sender or sender==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then return true end
    if self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return true end
    local now=self:Now()
    self.compatibilityPeers=self.compatibilityPeers or {}
    for key,value in pairs(self.compatibilityPeers) do if now-value.at>180 then self.compatibilityPeers[key]=nil end end
    local key=prefix..":"..distribution..":"..sender
    local peer=self.compatibilityPeers[key]
    if not peer then
        local count=0 for _ in pairs(self.compatibilityPeers) do count=count+1 end
        if count>=300 then return true end
        peer={at=now,count=0} self.compatibilityPeers[key]=peer
    end
    if now-(peer.rateAt or now)>=60 then peer.count=0 peer.rateAt=now end
    peer.rateAt=peer.rateAt or now peer.count=peer.count+1 peer.at=now
    if peer.count>256 then return true end
    -- AceComm fragmentation: no external addon/library is required to receive it.
    local control=message:byte(1)
    if control==1 then peer.parts={message:sub(2)} peer.bytes=#message-1 return true
    elseif control==2 or control==3 then
        if not peer.parts then return true end
        peer.bytes=peer.bytes+#message-1
        if peer.bytes>12000 or #peer.parts>=60 then peer.parts=nil return true end
        peer.parts[#peer.parts+1]=message:sub(2)
        if control==2 then return true end
        message=table.concat(peer.parts) peer.parts=nil
    elseif control==4 then message=message:sub(2) end
    local serialize,deflate=libraries() if not serialize or not deflate then return true end
    local kind,data
    local ok=pcall(function()
        local compressed
        if prefix=="CBRD" then kind=message:sub(1,1) compressed=deflate:DecodeForWoWAddonChannel(message:sub(2))
        else
            local frame=deflate:DecodeForWoWAddonChannel(message)
            if not frame or frame:byte(1)~=1 then return end
            kind=frame:byte(2) compressed=frame:sub(3)
        end
        if not compressed or #compressed>8192 then return end
        local raw=deflate:DecompressDeflate(compressed)
        if type(raw)~="string" or #raw>(prefix=="CBRD" and 131072 or 65536) then return end
        local valid,value=serialize:Deserialize(raw)
        if valid and type(value)=="table" then data=value end
    end)
    if not ok or not data then return true end
    -- Requests originate after broadcasts; replies may arrive by whisper or broadcast.
    local request=self.compatibilityPeers[prefix..":request:"..sender] or {}
    if prefix=="CBRD" then pcall(self.ReadCraftBoardDiscovery,self,sender,kind,data,request,distribution)
    else pcall(self.ReadReleaseGamingDiscovery,self,sender,kind,data,request,distribution) end
    request.at=now self.compatibilityPeers[prefix..":request:"..sender]=request
    return true
end

function AF:GetCompatibilityDirectoryEntries(itemID)
    local rows={}
    for source,records in pairs(self.db.compatibilityDiscoveries or {}) do
        for name,presence in pairs(records) do
            if self:Now()-(tonumber(presence.updatedAt) or 0)<=(self.CACHE_MAX_AGE or 1209600) then
                if itemID then
                    for _,craft in ipairs(presence.crafts or {}) do
                        if tonumber(craft.itemID)==tonumber(itemID) then
                            local copy={} for key,value in pairs(craft) do copy[key]=value end
                            copy.name=name copy.target=name copy.thirdPartySource=source copy.updatedAt=presence.updatedAt
                            rows[#rows+1]=copy
                        end
                    end
                else
                    for id in pairs(presence.professions or {}) do rows[#rows+1]={name=name,target=name,professionID=id,
                        thirdPartySource=source,updatedAt=presence.updatedAt} end
                end
            end
        end
    end
    return rows
end

function AF:RefreshCompatibilityDiscovery(force)
    if not self.db or self:IsProtectedActionRestricted() or self:IsAddonCommsUnavailable() then return end
    local now=self:Now()
    if not force and now-(self.compatibilityHelloAt or -600)<600 then return end
    self.compatibilityHelloAt=now
    local waiting=false
    for prefix,network in pairs(networks) do
        if self:EnsureDiscoveryNetworkChannel(network.channel)==0 then waiting=true end
        self:HideDiscoveryNetworkChannelFromChat(network.channel)
        -- Discovery-only greetings publish an empty profession book.
        local body=prefix=="CBRD" and {v=1,h="ArtisanFinder-discovery",n=0,profs={},b=true,pg=1}
            or {name=self.playerName or self:GetPlayerFullName(),version=1,bare=true,fetch=1}
        self:SendCompatibilityDiscovery(prefix,prefix=="CBRD" and "H" or 1,body,"CHANNEL")
        if IsInGuild and IsInGuild() then self:SendCompatibilityDiscovery(prefix,prefix=="CBRD" and "H" or 1,body,"GUILD") end
    end
    if waiting and not self.compatibilityJoinRetry then
        self.compatibilityJoinRetry=true
        C_Timer.After(10,function()
            AF:RefreshCompatibilityDiscovery(true)
            AF.compatibilityJoinRetry=nil
        end)
    end
end

local Handle=AF.HandleCompatibilityAddonMessage
function AF:HandleCompatibilityAddonMessage(prefix,...)
    if self:ReceiveCompatibilityDiscovery(prefix,...) then return true end
    return Handle and Handle(self,prefix,... ) or false
end
function AF:InitializeCompatibilityDiscovery()
    for prefix in pairs(networks) do C_ChatInfo.RegisterAddonMessagePrefix(prefix) end
    C_Timer.After(15,function() AF:RefreshCompatibilityDiscovery(true) end)
end
