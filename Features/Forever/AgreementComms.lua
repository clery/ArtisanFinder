local _,AF=...
local function now(self)return self.Now and self:Now() or time()end
local function encode(value,depth)
    depth=depth or 0
    if depth>5 then error("depth") end
    local kind=type(value)
    if kind=="string" then return "s"..#value..":"..value end
    if kind=="number" then local s=tostring(value) return "n"..#s..":"..s end
    if kind=="boolean" then return value and "t" or "f" end
    if kind~="table" then error("type") end
    local parts={"{"}
    for k,v in pairs(value)do
        if type(k)~="string" then error("key")end
        parts[#parts+1]=encode(k,depth+1) parts[#parts+1]=encode(v,depth+1)
    end
    parts[#parts+1]="}" return table.concat(parts)
end
local function decode(body)
    local pos,nodes=1,0
    local function read(depth)
        nodes=nodes+1 if depth>5 or nodes>512 then error("limit")end
        local tag=body:sub(pos,pos) pos=pos+1
        if tag=="t" then return true elseif tag=="f" then return false end
        if tag=="{" then
            local t={}
            while body:sub(pos,pos)~="}" do
                local k=read(depth+1)
                if type(k)~="string" or t[k]~=nil then error("key")end
                t[k]=read(depth+1)
            end
            pos=pos+1 return t
        end
        if tag~="s" and tag~="n" then error("tag")end
        local finish=body:find(":",pos,true) if not finish or finish-pos>5 then error("length")end
        local raw=body:sub(pos,finish-1) if not raw:match("^%d+$")then error("length")end
        local length=tonumber(raw) if length>4096 or finish+length>#body then error("length")end
        local v=body:sub(finish+1,finish+length) pos=finish+length+1
        if tag=="n"then v=tonumber(v) if not v or v~=v or v==math.huge or v==-math.huge then error("number")end end
        return v
    end
    local result=read(0) if pos~=#body+1 then error("trailing")end return result
end
function AF:MarkAgreementSupport(peer)
    if type(peer)~="string" or #peer>128 then return end
    self.agreementSupport=self.agreementSupport or {}
    local count=0
    for key,stamp in pairs(self.agreementSupport)do if now(self)-stamp>=3600 then self.agreementSupport[key]=nil else count=count+1 end end
    if count>=200 and not self.agreementSupport[peer] then return end
    local wasSupported=self:HasAgreementSupport(peer)
    self.agreementSupport[peer]=now(self)
    if not wasSupported and self.RefreshAgreementUI then self:RefreshAgreementUI()end
end
function AF:HasAgreementSupport(peer)
    local stamp=self.agreementSupport and self.agreementSupport[peer]
    return stamp~=nil and now(self)-stamp<3600
end
function AF:SendAgreementWire(peer,message)
    if type(peer)~="string" or peer=="" or #peer>128 or peer:find("[%c|]")then return false end
    if (self.IsProtectedActionRestricted and self:IsProtectedActionRestricted()) or (self.IsAddonCommsUnavailable and self:IsAddonCommsUnavailable())then return false end
    local ok,body=pcall(encode,message)
    if not ok or #body>4096 then return false end
    body=body:gsub("[%%%z\1-\31\127]",function(c)return string.format("%%%02X",c:byte())end)
    if #body>4096 then return false end
    self.agreementWireSequence=(self.agreementWireSequence or 0)+1
    local id=tostring(self.agreementWireSequence%1000000).."-"..tostring(now(self))
    local count=math.ceil(#body/128)
    for i=1,count do
        if not self:SendPayloadParts({"AG1",id,tostring(i),tostring(count),body:sub((i-1)*128+1,i*128)},"WHISPER",peer,"NORMAL","Agreements:"..peer)then return false end
    end
    return true
end
function AF:ProbeAgreementSupport(peer)
    self.agreementProbes=self.agreementProbes or {}
    local count=0
    for key,stamp in pairs(self.agreementProbes)do if now(self)-stamp>=60 then self.agreementProbes[key]=nil else count=count+1 end end
    if count>=200 and not self.agreementProbes[peer]then return false end
    if now(self)-(self.agreementProbes[peer] or 0)<10 then return false end
    self.agreementProbes[peer]=now(self)
    return self:SendAgreementWire(peer,{kind="probe"})
end
local function integer(n,min,max)return type(n)=="number" and n%1==0 and n>=min and n<=max end
local function sameImmutable(a,b)
    for _,k in ipairs({"id","customer","artisan","craftingCharacter","itemID","recipeID","professionID","quantity","createdAt"})do if a[k]~=b[k]then return false end end
    return true
end
function AF:ReceiveAgreementBody(message,sender)
    if type(message)~="table"then return end
    if type(sender)~="string" or sender=="" or #sender>128 or sender:find("[%c|]")then return end
    if message.kind=="probe"then self:MarkAgreementSupport(sender)self:SendAgreementWire(sender,{kind="support"})return end
    if message.kind=="support"then self:MarkAgreementSupport(sender)return end
    self:TickAgreements()
    local store=self:GetAgreementStore()
    if store.readOnly then return end
    local identity=message.id or (type(message.record)=="table" and message.record.id)
    if identity~=nil and (type(identity)~="string" or #identity>180)then return end
    local r=identity and store.records[identity]
    if message.kind=="stockRequest" then
        if r and (r.status=="Pending" or r.status=="Counteroffered") and r.localRole=="customer" and r.artisan==sender and self.SendAgreementCustomerStock then
            local items
            if message.items~=nil then
                if type(message.items)~="table" then return end
                items={}
                local total=0
                for id,value in pairs(message.items) do
                    total=total+1
                    if total>32 or type(id)~="string" or #id>10 or not id:match("^[1-9]%d*$") or tonumber(id)>2147483647 or value~=true then return end
                    items[id]=true
                end
            end
            self.agreementStockResponses=self.agreementStockResponses or {}
            local stamp=now(self)
            if stamp-(self.agreementStockResponses[r.id] or -math.huge)>=2 then
                self.agreementStockResponses[r.id]=stamp
                self:SendAgreementCustomerStock(r,items)
            end
        end
        return
    end
    if message.kind=="customerStock" then
        if not r or (r.status~="Pending" and r.status~="Counteroffered") or r.localRole~="artisan" or r.customer~=sender or type(message.counts)~="table" then return end
        local counts,total={},0
        for id,count in pairs(message.counts) do
            total=total+1
            if total>32 or type(id)~="string" or not id:match("^[1-9]%d*$") or #id>10 or not integer(count,0,1000000000) then return end
            counts[id]=count
        end
        r.customerStock={customer=sender,counts=counts}
        if self.RefreshAgreementMaterialsUI then self:RefreshAgreementMaterialsUI() end
        return
    end
    if message.kind=="snapshotAck"then
        if r and r.localRole=="artisan" and r.customer==sender and message.revision==r.stateRevision then r.snapshotDelivery=nil r.delivery="delivered" end
        return
    end
    if message.kind=="sync"then
        if r and r.localRole=="artisan" and r.customer==sender then self:SendAgreementWire(sender,{kind="snapshot",record=self:AgreementSnapshot(r),ack=r.lastCommand or 0})
        elseif not r and type(message.id)=="string" and not store.tombstones[message.id] then self:SendAgreementWire(sender,{kind="absent",id=message.id})end
        return
    end
    if message.kind=="absent"then
        if r and r.localRole=="customer" and r.artisan==sender and r.pendingAction and (r.pendingAction.command.action=="submit" or r.pendingAction.command.action=="cancel") then
            r.pendingAction.reconciling=nil self:SendAgreementWire(sender,r.pendingAction.command)
        end return
    end
    if message.kind=="snapshot"then
        local incoming=message.record
        if not r or r.localRole~="customer" or sender~=r.artisan or not self:ValidateAgreementRecord(incoming) or not sameImmutable(r,incoming) or incoming.stateRevision<r.stateRevision or not integer(message.ack,0,1000000)then return end
        if self:AgreementIsTerminal(r.status) and not r.localExpiry and incoming.status~=r.status then return end
        if incoming.proposalRevision<r.proposalRevision then return end
        if incoming.proposalRevision==r.proposalRevision and incoming.commission~=r.commission then return end
        if incoming.proposalRevision>r.proposalRevision and incoming.status~="Counteroffered" and incoming.status~="Accepted" then return end
        if (r.status=="Accepted" or self:AgreementIsTerminal(r.status)) and (incoming.proposalRevision~=r.proposalRevision or incoming.commission~=r.commission) then return end
        if r.status=="Accepted" and (incoming.status=="Pending" or incoming.status=="Counteroffered") then return end
        if (r.completion.customer and not incoming.completion.customer) or (r.completion.artisan and not incoming.completion.artisan) then return end
        -- Accepted material terms cannot change, even in newer completion packets.
        if r.materialSnapshot then
            incoming.materialSnapshot=r.materialSnapshot incoming.materialOutput=r.materialOutput
        end
        if (incoming.status=="Accepted" or self:AgreementIsTerminal(incoming.status)) and not incoming.materialSnapshot and self.FreezeAgreementMaterials then
            self:FreezeAgreementMaterials(incoming,true)
        end
        if incoming.stateRevision>r.stateRevision then
            for k,v in pairs(self:AgreementSnapshot(incoming))do r[k]=v end
            r.commission=incoming.commission r.unread=true r.localExpiry=nil
            if self.RecordCompletedAgreement then self:RecordCompletedAgreement(r) end
            if self.OnAgreementChanged then self:OnAgreementChanged(r,true)end
        end
        if r.pendingAction then
            if message.ack>=r.pendingAction.command.sequence then r.pendingAction=nil r.delivery="delivered"
            elseif r.pendingAction.reconciling then
                local p=r.pendingAction p.reconciling=nil
                -- Never silently apply intent to different terms after reconnect.
                if (p.command.action~="cancel" and p.command.revision~=r.proposalRevision) or self:AgreementIsTerminal(r.status)then r.pendingAction=nil r.delivery="delivered"
                else self:SendAgreementWire(sender,p.command)end
            end
        end
        self:SendAgreementWire(sender,{kind="snapshotAck",id=r.id,revision=r.stateRevision})
        if self.SendAgreementCustomerStock then self:SendAgreementCustomerStock(r) end
        if self.RefreshAgreementUI then self:RefreshAgreementUI()end return
    end
    if message.kind~="command" or not integer(message.sequence,1,1000000) or not integer(message.revision,1,1000000) or type(message.terms)~="table"then return end
    if not r then
        local draft=message.record
        if (message.action~="submit" and message.action~="cancel") or not self:ValidateAgreementRecord(draft) or draft.customer~=sender or draft.artisan~=(self.playerName or self:GetPlayerFullName()) or draft.status~="Pending" or draft.stateRevision~=0 or draft.proposalRevision~=1 or store.tombstones[draft.id] or draft.createdAt<=(tonumber(store.replayFloor) or 0) or store.ignored[sender] or self:AgreementActiveCount("artisan")>=50 or draft.createdAt>now(self)+60 or now(self)-draft.createdAt>172800 then return end
        self.agreementRequestRate=self.agreementRequestRate or {}
        local rates=self.agreementRequestRate
        for key,entry in pairs(rates)do if now(self)-entry.at>=60 then rates[key]=nil end end
        local function limited(key,maximum)
            local rate=rates[key]
            if not rate or now(self)-rate.at>=60 then rate={at=now(self),count=0} rates[key]=rate end
            if rate.count>=maximum then return true end rate.count=rate.count+1 return false
        end
        if limited(sender,3)or limited("*",20)then return end
        r=self:AgreementSnapshot(draft) r.localRole="artisan" r.stateRevision=1 r.lastCommand=message.sequence r.delivery="delivered" r.unread=message.action~="cancel"
        if message.action=="cancel" then r.status="Cancelled" r.updatedAt=now(self) end
        store.records[r.id]=r
        if message.action~="cancel" and self.OnAgreementChanged then self:OnAgreementChanged(r,true)end
    else
        if r.localRole~="artisan" or r.customer~=sender then return end
        if message.sequence>(r.lastCommand or 0)then
            -- Commands are monotonically sequenced; rejected commands are acknowledged too.
            if message.action~="submit"then
                local terms=message.terms
                if terms.commission~=nil and not integer(terms.commission,0,self.MAX_COMMISSION_COPPER or 999999990000)then return end
                if terms.message~=nil and (type(terms.message)~="string" or #terms.message>1024)then return end
                if terms.stock~=nil then
                    if type(terms.stock)~="table" then return end
                    local total=0
                    for id,count in pairs(terms.stock) do
                        total=total+1
                        if total>32 or type(id)~="string" or not id:match("^[1-9]%d*$") or #id>10 or tonumber(id)>2147483647 or not integer(count,0,1000000000) then return end
                    end
                end
                if message.action=="accept" or message.action=="cancel" or message.action=="complete" then self:CommitAgreementAction(r,message.action,terms,message.revision,"customer")end
            end
            r.lastCommand=message.sequence
        end
    end
    self:SendAgreementWire(sender,{kind="snapshot",record=self:AgreementSnapshot(r),ack=r.lastCommand or 0})
    if self.RequestAgreementCustomerStock then self:RequestAgreementCustomerStock(r) end
    if self.RefreshAgreementUI then self:RefreshAgreementUI()end
end
function AF:OnAgreementMessage(payload,channel,sender)
    if type(payload)~="string" or payload:sub(1,4)~="AG1|"then return false end
    if channel~="WHISPER" or type(sender)~="string" or sender=="" or sender:find("[%c|]") or #sender>128 or #payload>255 then return true end
    local id,index,total,chunk=payload:match("^AG1|([%d%-]+)|(%d+)|(%d+)|(.*)$")
    index,total=tonumber(index),tonumber(total)
    if not id or #id>32 or not index or not total or total<1 or total>32 or index<1 or index>total or #chunk>128 then return true end
    local stamp=now(self)
    self.agreementFrames=self.agreementFrames or {} self.agreementFrameRates=self.agreementFrameRates or {}
    local rates=self.agreementFrameRates
    local rateCount=0
    for key,entry in pairs(rates)do if stamp-entry.at>=1 then rates[key]=nil else rateCount=rateCount+1 end end
    if rateCount>=200 and not rates[sender]then return true end
    local rate=rates[sender]
    if not rate or stamp-rate.at>=1 then rate={at=stamp,count=0}rates[sender]=rate end
    rate.count=rate.count+1 if rate.count>96 then return true end
    local global=rates[false]
    if not global or stamp-global.at>=1 then global={at=stamp,count=0}rates[false]=global end
    global.count=global.count+1 if global.count>512 then return true end
    local frames=self.agreementFrames local count,own=0,0
    for key,entry in pairs(frames)do
        if stamp-entry.at>30 then frames[key]=nil else count=count+1 if entry.sender==sender then own=own+1 end end
    end
    local key=sender..":"..id local entry=frames[key]
    if not entry then if own>=2 or count>=16 then return true end entry={sender=sender,at=stamp,total=total,parts={}}frames[key]=entry end
    if entry.total~=total then frames[key]=nil return true end
    if entry.parts[index]and entry.parts[index]~=chunk then frames[key]=nil return true end
    entry.parts[index]=chunk
    for i=1,total do if not entry.parts[i]then return true end end
    frames[key]=nil
    local body=table.concat(entry.parts)
    if #body>4096 then return true end
    body=body:gsub("%%(%x%x)",function(hex)return string.char(tonumber(hex,16))end)
    local ok,message=pcall(decode,body)
    if ok then self:ReceiveAgreementBody(message,sender)end
    return true
end
function AF:MarkAgreementRead(id)
    local r=self:GetAgreement(id)
    if r then r.unread=false end
    if self.RefreshAgreementUnreadIndicator then self:RefreshAgreementUnreadIndicator() end
end
AF.SetAgreementRead=AF.MarkAgreementRead
function AF:UnignoreAgreementPeer(peer)self:GetAgreementStore().ignored[peer]=nil end
