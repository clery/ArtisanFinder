local _, AF = ...
local terminal = {Completed=true, Declined=true, Cancelled=true, Expired=true}
local states = {Pending=true, Counteroffered=true, Accepted=true, Completed=true, Declined=true, Cancelled=true, Expired=true}
local function copy(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k,v in pairs(t) do result[k] = copy(v) end
    return result
end
local function integer(n, low, high)
    return type(n)=="number" and n==n and n%1==0 and n>=low and n<=high
end
local function utf8Length(text)
    local index,count=1,0
    while index<=#text do
        local first=text:byte(index)
        local length=first<128 and 1 or (first>=194 and first<=223 and 2) or (first>=224 and first<=239 and 3) or (first>=240 and first<=244 and 4)
        if not length or index+length-1>#text then return nil end
        for offset=1,length-1 do local byte=text:byte(index+offset) if byte<128 or byte>191 then return nil end end
        local second=text:byte(index+1)
        if (first==224 and second<160) or (first==237 and second>=160) or (first==240 and second<144) or (first==244 and second>=144) then return nil end
        index=index+length count=count+1
    end
    return count
end
local function name(n)
    return type(n)=="string" and #n>0 and #n<=128 and not n:find("[%c|]") and utf8Length(n)~=nil
end
local function note(n)
    if type(n)~="string" or #n>1024 or n:find("|",1,true) or n:find("[%z\1-\8\11\12\14-\31]") then return false end
    local count=utf8Length(n)
    return count~=nil and count<=256
end
local function now(self) return self.Now and self:Now() or time() end
local function me(self) return self.playerName or self:GetPlayerFullName() end
local function changed(self,r,event)
    if self.RecordCompletedAgreement then self:RecordCompletedAgreement(r) end
    if self.OnAgreementChanged then self:OnAgreementChanged(r,event) end
    if self.RefreshAgreementUI then self:RefreshAgreementUI() end
end
function AF:GetAgreementStore()
    self.db = self.db or {}
    self.db.foreverAgreements = type(self.db.foreverAgreements)=="table" and self.db.foreverAgreements or {characters={}}
    self.db.foreverAgreements.characters=type(self.db.foreverAgreements.characters)=="table" and self.db.foreverAgreements.characters or {}
    local characters=self.db.foreverAgreements.characters
    local realm=GetRealmName and GetRealmName() or ""
    local key=realm..":"..me(self)
    local character = type(characters[key])=="table" and characters[key] or {}
    characters[key]=character
    local s=character.agreements
    if type(s)=="table" and type(s.version)=="number" and s.version>1 then
        self.readonlyAgreementsStore=self.readonlyAgreementsStore or {version=1,records={},ignored={},tombstones={},sequence=0,readOnly=true}
        return self.readonlyAgreementsStore
    end
    if type(s)~="table" or s.version~=1 then
        s={version=1,records={},ignored={},tombstones={},sequence=0}
        character.agreements=s
    end
    s.records=type(s.records)=="table" and s.records or {}
    s.ignored=type(s.ignored)=="table" and s.ignored or {}
    s.tombstones=type(s.tombstones)=="table" and s.tombstones or {}
    s.sequence=integer(s.sequence,0,1000000000) and s.sequence or 0
    return s
end
local MAX_COMPLETED=2147483647
local function completionStats(store)
    local stats=type(store.completedStats)=="table" and store.completedStats or {}
    store.completedStats=stats
    stats.artisan=integer(stats.artisan,0,MAX_COMPLETED) and stats.artisan or 0
    stats.customers=type(stats.customers)=="table" and stats.customers or {}
    return stats
end
local function countCompletion(self,store,r,owner)
    if r.completionCounted or r.status~="Completed" or not self:ValidateAgreementRecord(r) then return false end
    local stats=completionStats(store)
    if r.localRole=="artisan" and r.artisan==owner then
        stats.artisan=math.min(MAX_COMPLETED,stats.artisan+1)
    elseif r.localRole=="customer" and r.customer==owner then
        local count=stats.customers[r.artisan]
        stats.customers[r.artisan]=math.min(MAX_COMPLETED,(integer(count,0,MAX_COMPLETED) and count or 0)+1)
    else return false end
    r.completionCounted=true
    return true
end
function AF:RecordCompletedAgreement(r)
    local store=self:GetAgreementStore()
    if store.readOnly then return end
    if countCompletion(self,store,r,me(self)) then
        -- Advertise the aggregate on the next regular discovery tick, never request contents.
        if r.localRole=="artisan" then self.foreverPresenceAt=nil end
        if self.RequestCustomerResultsRefresh then self:RequestCustomerResultsRefresh() end
    end
end
function AF:GetCompletedAgreementCounts(contacts)
    self:GetAgreementStore()
    local realm=(GetRealmName and GetRealmName() or "")..":"
    local total,personal=0,0
    for key,character in pairs(self.db.foreverAgreements.characters) do
        local store=type(character)=="table" and character.agreements
        if type(key)=="string" and key:sub(1,#realm)==realm and type(store)=="table" and store.version==1 then
            local owner=key:sub(#realm+1)
            if not store.completedStatsMigrated then
                for _,record in pairs(type(store.records)=="table" and store.records or {}) do
                    if type(record)=="table" then countCompletion(self,store,record,owner) end
                end
                store.completedStatsMigrated=true
            end
            local stats=completionStats(store)
            total=math.min(MAX_COMPLETED,total+stats.artisan)
            for contact in pairs(contacts or {}) do
                local count=stats.customers[contact]
                if integer(count,0,MAX_COMPLETED) then personal=math.min(MAX_COMPLETED,personal+count) end
            end
        end
    end
    return total,personal
end
function AF:ValidateAgreementRecord(r)
    if type(r)~="table" or type(r.id)~="string" or #r.id>180 or #r.id<1 or r.id:find("[%c|]") then return false,"id" end
    if not name(r.customer) or not name(r.artisan) or r.customer==r.artisan or not name(r.craftingCharacter) then return false,"participants" end
    if not integer(r.quantity,1,999) or not integer(r.recipeID,1,2147483647) or not integer(r.professionID,1,2147483647) then return false,"craft" end
    if r.itemID~=nil and not integer(r.itemID,-2147483647,2147483647) then return false,"itemID" end
    if r.commission~=nil and not integer(r.commission,0,self.MAX_COMMISSION_COPPER or 999999990000) then return false,"commission" end
    if not note(r.message or "") or not states[r.status] then return false,"message" end
    if not integer(r.createdAt,1,9999999999) or not integer(r.updatedAt,r.createdAt,9999999999) then return false,"timestamps" end
    if not integer(r.stateRevision,0,1000000) or not integer(r.proposalRevision,1,1000000) then return false,"revisions" end
    if type(r.completion)~="table" or type(r.completion.customer)~="boolean" or type(r.completion.artisan)~="boolean" then return false,"completion" end
    local customerDone,artisanDone=r.completion.customer,r.completion.artisan
    if (r.status=="Pending" or r.status=="Counteroffered" or r.status=="Declined" or r.status=="Expired") and (customerDone or artisanDone) then return false,"completion" end
    if r.status=="Completed" and not (customerDone and artisanDone) then return false,"completion" end
    if r.status=="Accepted" and customerDone and artisanDone then return false,"completion" end
    if r.materialSnapshot~=nil then
        if type(r.materialSnapshot)~="table" or r.status=="Pending" or r.status=="Counteroffered" then return false,"materials" end
        local total=0
        for id,value in pairs(r.materialSnapshot) do
            total=total+1
            if total>32 or type(id)~="string" or not id:match("^[1-9]%d*$") or #id>10 or tonumber(id)>2147483647
                or type(value)~="table" or not integer(value.quantity,1,1000000000)
                or (value.owned~=nil and not integer(value.owned,0,1000000000)) then return false,"materials" end
            for key in pairs(value) do if key~="quantity" and key~="owned" then return false,"materials" end end
        end
    end
    if r.materialOutput~=nil and (type(r.materialOutput)~="table" or not integer(r.materialOutput.minimum,1,1000000000)
        or not integer(r.materialOutput.maximum,r.materialOutput.minimum,1000000000)) then return false,"materials" end
    if r.itemName~=nil and (type(r.itemName)~="string" or #r.itemName>256 or r.itemName:find("[%c|]") or not utf8Length(r.itemName)) then return false,"itemName" end
    if r.itemLink~=nil then
        if type(r.itemLink)~="string" or #r.itemLink>512 or r.itemLink:find("%c") or not utf8Length(r.itemLink) then return false,"itemLink" end
        local link=r.itemLink:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("^|cnIQ%d:", ""):gsub("^|cn[A-Z][A-Z0-9_]*:", ""):gsub("|r$", "")
        local kind,id,suffix,label=link:match("^|H(%a+):(%d+)([^|]*)|h%[([^|]*)%]|h$")
        if not kind or not suffix:match("^[:%d%-]*$") or label=="" then return false,"itemLink" end
        id=tonumber(id)
        if not ((kind=="item" and r.itemID and r.itemID>0 and id==r.itemID) or (kind=="enchant" and id==r.recipeID)) then return false,"itemLink" end
    end
    return true
end
function AF:GetAgreement(id) return self:GetAgreementStore().records[id] end
function AF:GetAgreements(direction)
    local result={}
    for _,r in pairs(self:GetAgreementStore().records) do
        if not direction or (direction=="incoming" and r.localRole=="artisan") or (direction=="outgoing" and r.localRole=="customer") then result[#result+1]=r end
    end
    table.sort(result,function(a,b) if a.updatedAt==b.updatedAt then return a.id<b.id end return a.updatedAt>b.updatedAt end)
    return result
end
function AF:AgreementActiveCount(role)
    local count=0
    for _,r in pairs(self:GetAgreementStore().records) do if r.localRole==role and not terminal[r.status] then count=count+1 end end
    return count
end
function AF:CreateAgreementDraft(input)
    if self:GetAgreementStore().readOnly then return nil,"future-schema" end
    if type(input)~="table" or self:AgreementActiveCount("customer")>=50 then return nil,"capacity" end
    local s=self:GetAgreementStore()
    local stamp=now(self)
    repeat s.sequence=s.sequence+1 until not s.records[me(self)..":"..stamp..":"..s.sequence] and not s.tombstones[me(self)..":"..stamp..":"..s.sequence]
    local r={id=me(self)..":"..stamp..":"..s.sequence,customer=me(self),artisan=input.artisan or input.contact,
        craftingCharacter=input.craftingCharacter or input.artisan or input.contact,itemID=input.itemID,recipeID=tonumber(input.recipeID),
        professionID=tonumber(input.professionID),itemLink=input.itemLink,itemName=input.itemName,quantity=tonumber(input.quantity) or 1,
        commission=input.commission,message=input.message or "",status="Pending",stateRevision=0,proposalRevision=1,
        createdAt=stamp,updatedAt=stamp,delivery="draft",unread=false,localRole="customer",completion={customer=false,artisan=false},commandSequence=0}
    local valid,field=self:ValidateAgreementRecord(r)
    if not valid then
        if self.DebugLog then self:DebugLog("agreements","draft rejected: invalid "..tostring(field).."; recipe="..tostring(r.recipeID).." item="..tostring(r.itemID).." profession="..tostring(r.professionID)) end
        return nil,"invalid"
    end
    s.records[r.id]=r
    changed(self,r,false)
    return r
end
function AF:AgreementSnapshot(r)
    local result={}
    for _,k in ipairs({"id","customer","artisan","craftingCharacter","itemID","recipeID","professionID","itemLink","itemName","quantity","commission","message","status","stateRevision","proposalRevision","createdAt","updatedAt","completion","materialSnapshot","materialOutput"}) do result[k]=copy(r[k]) end
    return result
end
function AF:QueueAgreementCommand(r,action,terms)
    if r.pendingAction and action~="cancel" then return false,"pending" end
    if r.pendingAction and action=="cancel" and r.pendingAction.command.action=="cancel" then return false,"pending" end
    r.commandSequence=(r.commandSequence or 0)+1
    if action=="accept" and self.GetAgreementMaterials then
        terms=copy(terms or {}) terms.stock={}
        for _,material in ipairs(self:GetAgreementMaterials(r) or {}) do
            if material.owned~=nil then terms.stock[tostring(material.itemID)]=material.owned end
        end
        -- Customer may not have the recipe. Reuse the authenticated reagent IDs.
        for id in pairs(r.stockItems or {}) do
            if C_Item and C_Item.GetItemCount then
                local ok,value=pcall(C_Item.GetItemCount,tonumber(id),true,false,true)
                if ok and not (self.IsSecretValue and self:IsSecretValue(value)) and integer(value,0,1000000000) then terms.stock[id]=value end
            end
        end
    end
    local command={kind="command",id=r.id,sequence=r.commandSequence,action=action,revision=r.proposalRevision,terms=copy(terms or {})}
    if action=="submit" or action=="cancel" then command.record=self:AgreementSnapshot(r) end
    r.pendingAction={command=command,startedAt=now(self),attempts=0}
    r.delivery="pending"
    self:TickAgreements()
    changed(self,r,false)
    return true
end
function AF:SendAgreement(id)
    local r=self:GetAgreement(id)
    if not r or r.localRole~="customer" or r.delivery~="draft" then return false,"invalid" end
    if (self.IsProtectedActionRestricted and self:IsProtectedActionRestricted()) or (self.IsAddonCommsUnavailable and self:IsAddonCommsUnavailable()) then return false,"restricted" end
    if not self:HasAgreementSupport(r.artisan) then self:ProbeAgreementSupport(r.artisan) return false,"unsupported" end
    if not self:ValidateAgreementRecord(r) then return false,"invalid" end
    r.createdAt=now(self) r.updatedAt=r.createdAt
    return self:QueueAgreementCommand(r,"submit")
end
function AF:PerformAgreementAction(id,action,terms)
    action=type(action)=="string" and action:lower() or ""
    local r=self:GetAgreement(id)
    self:TickAgreements()
    if not r or terminal[r.status] or r.delivery=="draft" then return false,"invalid" end
    terms=terms or {}
    if terms.message~=nil and not note(terms.message) then return false,"invalid" end
    if terms.commission~=nil and not integer(terms.commission,0,self.MAX_COMMISSION_COPPER or 999999990000) then return false,"invalid" end
    if r.localRole=="artisan" then
        local ok,err=self:CommitAgreementAction(r,action,terms,r.proposalRevision,"artisan")
        if ok then self:QueueAgreementSnapshot(r) end
        return ok,err
    end
    if action~="accept" and action~="cancel" and action~="complete" then return false,"role" end
    return self:QueueAgreementCommand(r,action,terms)
end
function AF:CommitAgreementAction(r,action,terms,revision,role)
    if terminal[r.status] then return false,"terminal" end
    if action=="cancel" then r.status="Cancelled"
    elseif action=="decline" and role=="artisan" and (r.status=="Pending" or r.status=="Counteroffered") then r.status="Declined"
    elseif action=="counter" and role=="artisan" and (r.status=="Pending" or r.status=="Counteroffered") then
        if terms.commission==nil then return false,"invalid" end
        r.commission=terms.commission r.message=terms.message or "" r.status="Counteroffered" r.proposalRevision=r.proposalRevision+1
    elseif action=="accept" and revision==r.proposalRevision and ((role=="artisan" and r.status=="Pending") or (role=="customer" and r.status=="Counteroffered")) then
        if self.FreezeAgreementMaterials then self:FreezeAgreementMaterials(r,false,terms.stock) end
        r.status="Accepted"
    elseif action=="complete" and r.status=="Accepted" then
        r.completion[role]=true
        if r.completion.customer and r.completion.artisan then r.status="Completed" end
    else return false,"state" end
    r.stateRevision=r.stateRevision+1 r.updatedAt=now(self) r.unread=role~=r.localRole
    changed(self,r,role~=r.localRole)
    return true
end
function AF:QueueAgreementSnapshot(r)
    r.delivery="pending"
    r.snapshotDelivery={startedAt=now(self),attempts=0,revision=r.stateRevision}
    self:TickAgreements()
end
function AF:IgnoreAgreementPeer(peer)
    if not name(peer) then return false end
    if self:GetAgreementStore().readOnly then return false end
    local ignored=self:GetAgreementStore().ignored
    local count=0 for _ in pairs(ignored) do count=count+1 end
    if count>=200 and not ignored[peer] then return false end
    ignored[peer]=true return true
end
function AF:DeleteAgreement(id)
    local s=self:GetAgreementStore() local r=s.records[id]
    if not r or (not terminal[r.status] and r.delivery~="draft") then return false end
    s.records[id]=nil s.tombstones[id]=now(self)
    self:TickAgreements() changed(self,r,false) return true
end
function AF:RetryAgreement(id)
    local r=self:GetAgreement(id)
    if r and r.localRole=="artisan" and r.snapshotDelivery and r.snapshotDelivery.failed then
        r.delivery="pending" self:QueueAgreementSnapshot(r) return true
    end
    if not r or not r.pendingAction or r.delivery~="failed" then return false end
    r.pendingAction.reconciling=true r.pendingAction.startedAt=now(self) r.pendingAction.attempts=0 r.delivery="pending"
    self:TickAgreements() return true
end
function AF:TickAgreements(background)
    if self.RefreshAgreementNotifications then self:RefreshAgreementNotifications() end
    local stamp=now(self)
    if background and self.nextAgreementTick and stamp<self.nextAgreementTick then return end
    self.nextAgreementTick=stamp+30
    local s=self:GetAgreementStore()
    local schedule={0,5,20,60,180}
    local history={}
    for id,r in pairs(s.records) do
        if (r.status=="Pending" or r.status=="Counteroffered") and r.delivery~="draft" and stamp>=r.createdAt+172800 then
            r.status="Expired" r.updatedAt=stamp r.pendingAction=nil r.localExpiry=r.localRole=="customer" or nil
            if r.localRole=="artisan"then r.stateRevision=r.stateRevision+1 r.snapshotDelivery={startedAt=stamp,attempts=0,revision=r.stateRevision} end
            changed(self,r,false)
        end
        local p=r.pendingAction
        if p and r.delivery~="failed" then
            self.nextAgreementTick=stamp+1
            if stamp-p.startedAt>=300 then r.delivery="failed" changed(self,r,false)
            elseif p.attempts<5 and stamp-p.startedAt>=schedule[p.attempts+1] then
                p.attempts=p.attempts+1
                self:SendAgreementWire(r.artisan,p.reconciling and {kind="sync",id=id,sequence=p.command.sequence} or p.command)
            end
        end
        local outgoing=r.snapshotDelivery
        if outgoing and not outgoing.failed then
            self.nextAgreementTick=stamp+1
            if stamp-outgoing.startedAt>=300 then outgoing.failed=true r.delivery="failed" changed(self,r,false) end
        end
        if outgoing and not outgoing.failed and outgoing.attempts<5 and stamp-outgoing.startedAt>=schedule[outgoing.attempts+1]then
            outgoing.attempts=outgoing.attempts+1
            self:SendAgreementWire(r.customer,{kind="snapshot",record=self:AgreementSnapshot(r),ack=r.lastCommand or 0})
        end
        if terminal[r.status] then history[#history+1]=r end
    end
    table.sort(history,function(a,b)return a.updatedAt>b.updatedAt end)
    for i,r in ipairs(history) do if i>200 or stamp-r.updatedAt>2592000 then s.records[r.id]=nil s.tombstones[r.id]=stamp end end
    local tombstones={} for id,t in pairs(s.tombstones) do tombstones[#tombstones+1]={id=id,time=t} end
    table.sort(tombstones,function(a,b)return a.time>b.time end)
    for i,t in ipairs(tombstones) do
        if i>1000 or stamp-t.time>2592000 then
            -- Bounded tombstones must not reopen still-valid proposals after eviction.
            if i>1000 then s.replayFloor=math.max(tonumber(s.replayFloor) or 0,t.time) end
            s.tombstones[t.id]=nil
        end
    end
end
function AF:InitializeAgreements()
    self:GetAgreementStore()
    self.agreementSupport={}
    local store=self:GetAgreementStore()
    if not integer(store.replayFloor,0,9999999999) then store.replayFloor=0 end
    for id,stamp in pairs(store.tombstones) do
        if type(id)~="string" or #id>180 or not integer(stamp,1,9999999999) then store.tombstones[id]=nil end
    end
    local ignoredCount=0
    for peer,value in pairs(store.ignored) do
        if not name(peer) or value~=true or ignoredCount>=200 then store.ignored[peer]=nil else ignoredCount=ignoredCount+1 end
    end
    local function quarantineMetadata(id,field,value)
        store.quarantine=type(store.quarantine)=="table" and store.quarantine or {}
        if #store.quarantine<20 then store.quarantine[#store.quarantine+1]={id=id,field=field,value=value} end
    end
    local actions={submit=true,accept=true,cancel=true,complete=true}
    for id,r in pairs(store.records) do
        if not self:ValidateAgreementRecord(r) or (r.localRole~="customer" and r.localRole~="artisan") then
            store.quarantine=type(store.quarantine)=="table" and store.quarantine or {}
            if #store.quarantine<20 then store.quarantine[#store.quarantine+1]={id=id,record=r} end
            store.records[id]=nil
        else
            if (r.status=="Accepted" or terminal[r.status]) and not r.materialSnapshot and self.FreezeAgreementMaterials then
                self:FreezeAgreementMaterials(r,true)
            end
            if not integer(r.commandSequence,0,1000000) then r.commandSequence=0 end
            if not integer(r.lastCommand,0,1000000) then r.lastCommand=0 end
            local pending=r.pendingAction
            if pending then
                local command=type(pending)=="table" and pending.command
                local valid=type(pending)=="table" and integer(pending.startedAt,1,9999999999) and integer(pending.attempts,0,5)
                    and type(command)=="table" and actions[command.action] and command.kind=="command" and command.id==r.id
                    and integer(command.sequence,1,1000000) and integer(command.revision,1,1000000) and type(command.terms)=="table"
                if valid and type(command)=="table" then
                    pending.reconciling=true r.commandSequence=math.max(r.commandSequence,tonumber(command.sequence) or 0)
                else quarantineMetadata(id,"pendingAction",pending) r.pendingAction=nil r.delivery="failed" end
            end
            local outgoing=r.snapshotDelivery
            if outgoing and not (type(outgoing)=="table" and integer(outgoing.startedAt,1,9999999999) and integer(outgoing.attempts,0,5) and integer(outgoing.revision,1,1000000)) then
                quarantineMetadata(id,"snapshotDelivery",outgoing) r.snapshotDelivery=nil r.delivery="failed"
            end
        end
    end
    self:GetCompletedAgreementCounts()
    if C_Timer and C_Timer.NewTicker and not self.agreementTicker then self.agreementTicker=C_Timer.NewTicker(1,function()self:TickAgreements(true)end) end
end
AF.AgreementIsTerminal=function(_,status)return terminal[status]==true end
