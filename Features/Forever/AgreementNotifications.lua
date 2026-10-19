local _, AF = ...

-- Reuse the Retail toast template with Forever profession textures and richer terms.
-- Agreement transport and notifications remain independent of crafting orders.
local WIDTH, HEIGHT, SPACING = 400, 108, 8
local FADE_IN, HOLD, FADE_OUT = .18, 4.4, .7
local function now() return GetTime and GetTime() or 0 end
local function restricted(self)
    return (InCombatLockdown and InCombatLockdown())
        or (IsInInstance and IsInInstance())
        or (self.IsProtectedActionRestricted and self:IsProtectedActionRestricted())
        or (self.IsAddonCommsUnavailable and self:IsAddonCommsUnavailable())
end
local function state(self)
    if not self.agreementNotifications then
        self.agreementNotifications={pending={},active={},free={},seen={}}
    end
    return self.agreementNotifications
end
local function position(self)
    local offset=170
    for _,frame in ipairs(state(self).active) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP",UIParent,"TOP",0,-offset)
        offset=offset+frame:GetHeight()+SPACING
    end
end
function AF:ReleaseAgreementNotification(frame)
    local notifications=state(self)
    for i,active in ipairs(notifications.active) do
        if active==frame then table.remove(notifications.active,i) break end
    end
    frame:Hide()
    frame:SetScript("OnUpdate",nil)
    frame.notificationSoundPlayed=nil
    frame.recordID=nil frame.itemLink=nil frame.requestedItemID=nil frame.elapsed=0 frame.paused=false
    frame.messageText=nil frame.Message:SetText("") frame.Message:Hide() frame:SetHeight(HEIGHT)
    frame:SetAlpha(1)
    table.insert(notifications.free,frame)
    position(self)
end
-- Measure complete UTF-8 characters so truncation never splits a localized message.
local function preview(frame,message)
    local value=type(message)=="string" and message:gsub("%s+"," "):match("^%s*(.-)%s*$") or ""
    frame.messageText=value~="" and value or nil
    frame:SetHeight(HEIGHT+(frame.messageText and 16 or 0))
    frame.Message:SetText(value)
    if value=="" then frame.Message:Hide() return end
    frame.Message:Show()
    local width=WIDTH-100
    if frame.Message:GetStringWidth()<=width then return end
    local characters={}
    for character in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do characters[#characters+1]=character end
    local low,high=0,#characters
    while low<high do
        local middle=math.ceil((low+high)/2)
        frame.Message:SetText(table.concat(characters,"",1,middle).."…")
        if frame.Message:GetStringWidth()<=width then low=middle else high=middle-1 end
    end
    frame.Message:SetText(table.concat(characters,"",1,low).."…")
end
-- Read rarity from local item metadata, never a sender's localized item label.
local function populate(self,frame,record)
    local name,link=self:GetAgreementCraftPresentation(record)
    frame.itemLink=link
    local icon,quality
    if tonumber(record.itemID) and record.itemID>0 and C_Item then
        if C_Item.GetItemIconByID then icon=C_Item.GetItemIconByID(record.itemID) end
        if C_Item.GetItemInfo then
            local ok,_,_,rarity=pcall(C_Item.GetItemInfo,record.itemID)
            if ok and not (self.IsSecretValue and self:IsSecretValue(rarity)) and type(rarity)=="number" then quality=rarity end
        end
    elseif record.recipeID and C_Spell and C_Spell.GetSpellTexture then
        icon=C_Spell.GetSpellTexture(record.recipeID)
    end
    if quality==nil and tonumber(record.itemID) and record.itemID>0 and C_Item and C_Item.RequestLoadItemDataByID
        and frame.requestedItemID~=record.itemID then
        frame.requestedItemID=record.itemID
        pcall(C_Item.RequestLoadItemDataByID,record.itemID)
    end
    local color=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local red,green,blue=1,1,1
    if color then red,green,blue=color.r,color.g,color.b end
    frame.Icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_Note_01")
    frame.ItemName:SetTextColor(red,green,blue)
    frame.IconBorder:SetVertexColor(red,green,blue)
    frame.IconBorder:Show()
    frame.Title:SetText(self:Text("AGREEMENT_TOAST_TITLE"))
    frame.ItemName:SetText(name)
    frame.Meta:SetText(self:Text("ORDER_NOTIFICATION_META",record.craftingCharacter or record.artisan or "",record.customer or ""))
    local amount=record.commission==nil and "—" or self:FormatMoney(record.commission,record.commission==0)
    frame.Commission:SetText(self:Text("ORDER_NOTIFICATION_COMMISSION",amount))
    frame.Status:SetText(self:GetAgreementDisplayStatus(record))
    local agreementStatus=tostring(record.status or ""):upper()
    if agreementStatus=="CANCELLED" then frame.Status:SetTextColor(1,.2,.2)
    elseif agreementStatus=="ACCEPTED" then frame.Status:SetTextColor(.2,1,.2)
    else frame.Status:SetTextColor(.72,.68,.6) end
    preview(frame,record.message)
    position(self)
end
local function createToast(self)
    local frame=CreateFrame("Button",nil,UIParent,"ArtisanFinderOrderNotificationToastTemplate")
    frame:SetSize(WIDTH,HEIGHT)
    frame:SetFrameStrata("DIALOG") frame:SetFrameLevel(80)
    frame:EnableMouse(true) frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Gold-Border",tile=true,tileSize=32,
        edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    frame:SetBackdropColor(.28,.17,.09,1) frame:SetBackdropBorderColor(1,.88,.6,1)
    frame.Parchment=frame:CreateTexture(nil,"BACKGROUND",nil,1)
    frame.Parchment:SetPoint("TOPLEFT",11,-12) frame.Parchment:SetPoint("BOTTOMRIGHT",-12,11)
    frame.Parchment:SetAtlas("Profession-Background-Template2")
    frame.Parchment:SetVertexColor(.75,.56,.35) frame.Parchment:SetAlpha(.85)
    frame.Watermark=frame:CreateTexture(nil,"BACKGROUND",nil,2)
    frame.Watermark:SetSize(100,100) frame.Watermark:SetPoint("RIGHT",-18,0)
    frame.Watermark:SetTexture("Interface\\AddOns\\"..(self.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png")
    frame.Watermark:SetDesaturated(true) frame.Watermark:SetAlpha(.055)
    frame.Icon:SetSize(52,52) frame.Icon:ClearAllPoints() frame.Icon:SetPoint("LEFT",18,0)
    frame.Title:ClearAllPoints() frame.Title:SetPoint("TOPLEFT",82,-15) frame.Title:SetPoint("RIGHT",-18,0)
    frame.Status=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.Status:SetPoint("TOPLEFT",frame.Commission,"BOTTOMLEFT",0,-2) frame.Status:SetPoint("RIGHT",-18,0)
    frame.Message=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    frame.Message:SetPoint("TOPLEFT",frame.Status,"BOTTOMLEFT",0,-2) frame.Message:SetPoint("RIGHT",-18,0)
    frame.Message:SetTextColor(.88,.8,.64)
    for _,label in ipairs({frame.Title,frame.ItemName,frame.Meta,frame.Commission,frame.Status,frame.Message}) do
        label:SetJustifyH("LEFT") label:SetWordWrap(false)
    end
    frame.Meta:SetTextColor(.86,.8,.68) frame.Commission:SetTextColor(1,.82,0)
    frame.Status:SetTextColor(.72,.68,.6)
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:SetScript("OnEvent",function(toast,_,itemID,success)
        local record=toast.recordID and self:GetAgreement(toast.recordID)
        if success and record and record.itemID==itemID then populate(self,toast,record) end
    end)
    frame:SetScript("OnEnter",function(toast)
        toast.paused=true toast.elapsed=FADE_IN toast:SetAlpha(1)
        if GameTooltip then
            GameTooltip:SetOwner(toast,"ANCHOR_TOP")
            if toast.itemLink then GameTooltip:SetHyperlink(toast.itemLink)
            else GameTooltip:SetText(toast.ItemName:GetText()) end
            for _,label in ipairs({toast.Meta,toast.Commission,toast.Status}) do
                GameTooltip:AddLine(label:GetText(),1,.82,0,true)
            end
            if toast.messageText then GameTooltip:AddLine(toast.messageText,.88,.8,.64,true) end
            local record=self:GetAgreement(toast.recordID)
            if record and record.commission==nil then GameTooltip:AddLine(self:Text("FOREVER_PRICE_UNKNOWN"),.85,.8,.7,true) end
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave",function(toast)
        toast.paused=false if GameTooltip then GameTooltip:Hide() end
    end)
    frame:SetScript("OnClick",function(toast,button)
        local record=self:GetAgreement(toast.recordID)
        if GameTooltip then GameTooltip:Hide() end
        self:ReleaseAgreementNotification(toast)
        if button=="LeftButton" and record and not restricted(self) then
            self:OpenAgreementNotification(record)
        end
    end)
    return frame
end
function AF:QueueAgreementNotification(record)
    local notifications=state(self)
    local revision=tostring(record.stateRevision or 0)..":"..tostring(record.status)..":"
        ..tostring(record.completion and record.completion.customer)..":"..tostring(record.completion and record.completion.artisan)
    if notifications.seen[record.id]==revision then return end
    notifications.seen[record.id]=revision
    -- Coalesce updates received while restricted. Unread state survives queue limits.
    for _,entry in ipairs(notifications.pending) do
        if entry.id==record.id then self:RefreshAgreementNotifications() return end
    end
    if #notifications.pending>=50 then table.remove(notifications.pending,1) end
    table.insert(notifications.pending,{id=record.id,queuedAt=now()})
    self:RefreshAgreementNotifications()
end
function AF:RefreshAgreementNotifications()
    local notifications=self.agreementNotifications
    if not notifications then return end
    if restricted(self) then
        -- Pause visible cards without losing their unread records.
        while #notifications.active>0 do
            local frame=notifications.active[1]
            if #notifications.pending<50 then table.insert(notifications.pending,{id=frame.recordID,queuedAt=now(),soundPlayed=frame.notificationSoundPlayed}) end
            self:ReleaseAgreementNotification(frame)
        end
        return
    end
    while #notifications.active<3 and #notifications.pending>0 do
        local entry=table.remove(notifications.pending,1)
        local record=self:GetAgreement(entry.id)
        if record and record.unread and now()-(entry.queuedAt or 0)<300 then
            local frame=table.remove(notifications.free) or createToast(self)
            frame.recordID=record.id frame.elapsed=0 frame.paused=false
            populate(self,frame,record)
            frame:SetAlpha(0)
            frame:SetScript("OnUpdate",function(toast,elapsed)
                if restricted(self) then self:RefreshAgreementNotifications() return end
                if toast.paused then return end
                toast.elapsed=toast.elapsed+elapsed
                local t=toast.elapsed
                if t<FADE_IN then toast:SetAlpha(t/FADE_IN)
                elseif t<HOLD then toast:SetAlpha(1)
                elseif t<HOLD+FADE_OUT then toast:SetAlpha(1-(t-HOLD)/FADE_OUT)
                else self:ReleaseAgreementNotification(toast) self:RefreshAgreementNotifications() end
            end)
            table.insert(notifications.active,frame) frame:Show()
            frame.notificationSoundPlayed=true
            if not entry.soundPlayed then self:PlayNotificationSound() end
        end
    end
    -- Retain deduplication only for existing records, preventing unbounded history.
    for id in pairs(notifications.seen) do if not self:GetAgreement(id) then notifications.seen[id]=nil end end
    position(self)
end
