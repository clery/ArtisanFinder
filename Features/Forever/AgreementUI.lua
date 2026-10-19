local _, AF = ...
-- Reserve the largest action footer from the start, including room for the stamp.
-- Agreement state changes must not resize the paper or rescale its host window.
local PAGE_HEIGHT=756
local INK={.14,.10,.06}
local MUTED_INK={.25,.18,.11}
local INPUT_INK={.94,.88,.76}
local STAMP_INK={.48,.12,.075,.95}
local function ink(line,muted)
    line:SetTextColor(unpack(muted and MUTED_INK or INK))
    line:SetShadowColor(0,0,0,0)
end
local function paperColumn(parent,x,width,parchment)
    -- Keep surfaces on the window's background layer, below its footer labels.
    local column=parent:CreateTexture(nil,"BACKGROUND",nil,2)
    column:SetPoint("TOPLEFT",x,-78)
    column:SetPoint("BOTTOMLEFT",x,14)
    column:SetWidth(width)
    local shadow=parent:CreateTexture(nil,"BACKGROUND",nil,1)
    shadow:SetPoint("TOPLEFT",column,"TOPLEFT",3,-4) shadow:SetPoint("BOTTOMRIGHT",column,"BOTTOMRIGHT",4,-4)
    shadow:SetColorTexture(0,0,0,.65)
    column:SetColorTexture(.28,.18,.08)
    local backing=parent:CreateTexture(nil,"BACKGROUND",nil,3)
    backing:SetPoint("TOPLEFT",column,"TOPLEFT",1,-1) backing:SetPoint("BOTTOMRIGHT",column,"BOTTOMRIGHT",-1,1)
    if parchment then backing:SetColorTexture(.84,.73,.5)
    else backing:SetColorTexture(.84,.73,.5) end
    local paper=parent:CreateTexture(nil,"BACKGROUND",nil,4)
    paper:SetPoint("TOPLEFT",column,"TOPLEFT",1,-1) paper:SetPoint("BOTTOMRIGHT",column,"BOTTOMRIGHT",-1,1)
    if parchment and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestBG-Parchment") then
        paper:SetAtlas("QuestBG-Parchment")
    else paper:SetTexture("Interface\\QuestFrame\\QuestBG") end
    -- Native quest parchment stays untinted; reward cards provide item contrast.
    paper.backing=backing
    return paper
end
local function text(key,...) return AF:Text("AGREEMENT_"..key,...) end
local function status(record) return tostring(record.status or ""):upper() end
local terminal={COMPLETED=true,DECLINED=true,CANCELLED=true,EXPIRED=true}
local function font(widget,size)
    local path,_,flags=widget:GetFont()
    widget:SetFont(path,size,flags)
end
local function buttonFont(button) font(button:GetFontString(),14) end
local function label(parent,value,x,y,width)
    local line=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font(line,14)
    line:SetPoint("TOPLEFT",x,y) line:SetWidth(width) line:SetJustifyH("LEFT")
    line:SetText(value or "") return line
end
-- QuestInfo's quest-log rewards inherit SmallItemButtonTemplate. Reuse its
-- QuestItemBorder atlas, 30px icon and two-line name instead of stretching the
-- legacy 128x64 texture used by the larger quest turn-in reward buttons.
local function rewardCard(button)
    button.icon=button.Icon
    button.nameFrame=button.NameFrame
    button.label=button.Name
    button.label:SetTextColor(1,1,1)
    button.border=button:CreateTexture(nil,"OVERLAY",nil,1)
    button.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    button.border:SetAllPoints(button.icon)
end
local function updateMaterialScroll(scroll)
    local height=scroll:GetScrollChild():GetHeight()
    ScrollFrame_OnScrollRangeChanged(scroll,0,math.max(0,height-scroll:GetHeight()))
end
local function showReward(button,value,link,itemID,recipeID)
    -- Native rewards show plain item names; links remain on the tooltip owner.
    local name=(value or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name=name:gsub("|H.-|h(.-)|h", "%1"):gsub("^%[(.*)%]$", "%1")
    button.label:SetText(name)
    local texture
    itemID=tonumber(itemID)
    if itemID and itemID>0 and C_Item and C_Item.GetItemIconByID then texture=C_Item.GetItemIconByID(itemID)
    elseif recipeID and C_Spell and C_Spell.GetSpellTexture then texture=C_Spell.GetSpellTexture(recipeID) end
    button.icon:SetTexture(texture or "Interface\\Icons\\INV_Scroll_03")
    local r,g,b=1,1,1
    if itemID and itemID>0 and C_Item and C_Item.GetItemInfo then
        local _,_,quality=C_Item.GetItemInfo(itemID)
        local color=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then r,g,b=color.r,color.g,color.b
        elseif link then
            local hex=link:match("|c%x%x(%x%x%x%x%x%x)")
            if hex then r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255 end
        end
    end
    button.border:SetVertexColor(r,g,b)
    button.icon:Show() button.nameFrame:Show() button.border:Show()
end
local function tip(owner,title)
    owner:SetScript("OnEnter",function(button)
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT") GameTooltip:SetText(title,1,.82,.35) GameTooltip:Show()
        if button.art then button.art:SetVertexColor(1,1,1) end
    end)
    owner:SetScript("OnLeave",function(button)
        GameTooltip:Hide() if button.art then button.art:SetVertexColor(.82,.82,.82) end
    end)
end
local function actionButton(parent,key,callback,tooltipKey)
    local button=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    button:SetSize(220,30) button:SetText(text("BUTTON_"..key)) buttonFont(button)
    button:SetScript("OnClick",callback) tip(button,text(tooltipKey or key))
    return button
end
local function field(parent,x,y,width,maxLetters)
    local box=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    box:SetPoint("TOPLEFT",x,y) box:SetSize(width,30) box:SetAutoFocus(false) font(box,14)
    box:SetTextColor(unpack(INPUT_INK))
    box:SetMaxLetters(maxLetters or 256)
    box:SetScript("OnEscapePressed",function(owner) owner:ClearFocus() end)
    box:SetScript("OnEnterPressed",function(owner) owner:ClearFocus() end)
    return box
end
local function shownItem(record)
    local name,link=AF:GetAgreementCraftPresentation(record)
    return link or name
end
local function isDraft(record)
    return record.delivery=="draft" or record.delivery=="Draft" or record.status=="Draft" or record.draft==true
end
function AF:GetAgreementDisplayStatus(record)
    if isDraft(record) then return text("DRAFT") end
    if record.delivery=="failed" then return text("DELIVERY_FAILED") end
    if record.pendingAction then
        local command=record.pendingAction.command
        return command and command.action=="cancel" and (text("CANCEL").." · "..text("WAITING_DELIVERY")) or text("WAITING_DELIVERY")
    end
    if status(record)=="ACCEPTED" and record.completion and (record.completion.customer or record.completion.artisan) then
        return text("AWAITING_CONFIRMATION")
    end
    return text(status(record))
end
function AF:GetAgreementEditorTotal(unitCommission,quantity)
    quantity=tonumber(quantity)
    if not quantity or quantity%1~=0 or quantity<1 or quantity>999 then return nil,"QUANTITY_ERROR" end
    if unitCommission==nil then return nil end
    if type(unitCommission)~="number" or unitCommission<0 or unitCommission%1~=0 then return nil,"PRICE_ERROR" end
    if unitCommission>self.MAX_COMMISSION_COPPER/quantity then return nil,"PRICE_ERROR" end
    return unitCommission*quantity
end
local function setMoney(panel,amount)
    panel.syncing=true
    if amount==nil then for _,box in ipairs(panel.money) do box:SetText("") end
    else
        panel.money[1]:SetText(tostring(math.floor(amount/10000)))
        panel.money[2]:SetText(tostring(math.floor(amount/100)%100))
        panel.money[3]:SetText(tostring(amount%100))
    end
    panel.syncing=false
end
local function readMoney(panel)
    local g,s,c=panel.money[1]:GetText(),panel.money[2]:GetText(),panel.money[3]:GetText()
    if g=="" and s=="" and c=="" then return nil end
    for _,v in ipairs({g,s,c}) do if v~="" and not v:match("^%d+$") then return nil,"PRICE_ERROR" end end
    local gold,silver,copper=tonumber(g) or 0,tonumber(s) or 0,tonumber(c) or 0
    local total=gold*10000+silver*100+copper
    if silver>99 or copper>99 or total>AF.MAX_COMMISSION_COPPER then return nil,"PRICE_ERROR" end
    return total
end
local function moneyFields(parent)
    parent.money={}
    for i,atlas in ipairs({"coin-gold","coin-silver","coin-copper"}) do
        local box=CreateFrame("EditBox",nil,parent,"LargeInputBoxTemplate")
        box:SetSize(i==1 and 126 or 72,33) box:SetAutoFocus(false) box:SetFontObject("PriceFont") font(box,16)
        box:SetTextColor(unpack(INPUT_INK))
        box:SetTextInsets(8,24,0,0) box:SetJustifyH("RIGHT") box:SetNumeric(true)
        box:SetMaxLetters(i==1 and 8 or 2)
        if i==1 then box:SetPoint("TOPLEFT",0,-147) else box:SetPoint("LEFT",parent.money[i-1],"RIGHT",6,0) end
        local coin=box:CreateTexture(nil,"ARTWORK") coin:SetSize(14,16) coin:SetAtlas(atlas)
        coin:SetPoint("RIGHT",-8,0)
        tip(box,AF:Text("FOREVER_COIN_"..({"GOLD","SILVER","COPPER"})[i]))
        box:SetScript("OnEscapePressed",function(owner) owner:ClearFocus() end)
        box:SetScript("OnEnterPressed",function(owner) owner:ClearFocus() end)
        box:SetScript("OnTextChanged",function(_,userInput)
            if userInput and not parent.syncing then parent.priceEdited=true end
        end)
        parent.money[i]=box
    end
end
local function showError(frame,key)
    frame.notice:SetText(key and text(key) or "")
end
local function showSendError(frame,reason)
    local keys={unsupported="UNSUPPORTED",restricted="RESTRICTED",capacity="CAPACITY_ERROR",["future-schema"]="SCHEMA_ERROR",invalid="INVALID_ERROR"}
    showError(frame,keys[reason] or "ACTION_ERROR")
end
local function selectedRecord(frame)
    return frame.selectedID and AF:GetAgreement(frame.selectedID)
end
-- Keep edits local to their form; tab changes never submit or persist an agreement.
local function saveForm(frame)
    local panel=frame.detail
    if not panel or not panel.loadedContext then return end
    frame.forms[panel.loadedContext]={quantity=panel.quantity:GetText(),message=panel.message:GetText(),
        money={panel.money[1]:GetText(),panel.money[2]:GetText(),panel.money[3]:GetText()},
        priceEdited=panel.priceEdited,revision=panel.loadedRevision}
end
local function changeDirection(frame,direction)
    saveForm(frame)
    frame.tabs[frame.direction]={selectedID=frame.selectedID,editorInput=frame.editorInput,offset=frame.offset}
    local tab=frame.tabs[direction] or {}
    frame.direction=direction frame.selectedID=tab.selectedID frame.editorInput=tab.editorInput frame.offset=tab.offset or 0
    frame.detail.loadedContext=nil
    showError(frame)
end
local function itemTooltip(button,record)
    button:SetScript("OnEnter",function(owner)
        local _,link=AF:GetAgreementCraftPresentation(record)
        if link then GameTooltip:SetOwner(owner,"ANCHOR_RIGHT") GameTooltip:SetHyperlink(link) GameTooltip:Show() end
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnHide",function(owner) if GameTooltip.IsOwned and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end
local function showIgnored(frame)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(frame,function(_,root)
        root:CreateTitle(text("IGNORED"))
        local store=AF:GetAgreementStore()
        local peers={}
        for peer in pairs(store.ignored or store.ignoredPeers or {}) do peers[#peers+1]=peer end
        table.sort(peers)
        if #peers==0 then root:CreateTitle(text("NO_IGNORED")) end
        for _,peer in ipairs(peers) do
            root:CreateButton(text("UNIGNORE",peer),function()
                AF:UnignoreAgreementPeer(peer) AF:RefreshAgreementUI()
            end)
        end
    end)
end
local function isAgreementVisible(frame)
    return frame and frame:IsShown() and (not frame.directoryHost or frame.directoryHost:IsShown())
end
local function raiseWindow(frame)
    if frame.directoryHost then frame.directoryHost:Raise() return end
    -- Discovery uses HIGH on its own and inherits the professions frame when embedded.
    -- Keep the editor and all its inherited child controls above either source window.
    local sourceLevel=0
    for _,source in pairs({AF.customerFrame,ProfessionsFrame}) do
        if source:IsShown() then sourceLevel=math.max(sourceLevel,source:GetFrameLevel()) end
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(math.max(frame:GetFrameLevel(),sourceLevel+10))
    frame:Raise()
end
local function layoutActions(frame,count)
    local extra=math.max(0,math.ceil(count/2)-1)*36
    frame.notice:ClearAllPoints() frame.notice:SetPoint("TOPLEFT",350,-600-extra)
    if frame.directoryHost then
        AF:ResizeForeverDirectoryHost(PAGE_HEIGHT)
        frame:SetScale(1)
        return
    end
    local widthLimit=(UIParent:GetWidth()-24)/840
    local heightLimit=(UIParent:GetHeight()-24)/PAGE_HEIGHT
    frame:SetScale(math.min(1,widthLimit,heightLimit))
end
local function makeWindow()
    if AF.AttachCustomerUI then AF:AttachCustomerUI() end
    local host=AF.customerFrame and AF.customerFrame.directoryTabs and AF.customerFrame
    local template
    if not host then template="PortraitFrameTemplate" end
    local frame=CreateFrame("Frame","ArtisanFinderAgreements",host or UIParent,template)
    frame.directoryHost=host
    AF.agreementsFrame=frame frame:SetSize(840,PAGE_HEIGHT) frame:SetPoint("CENTER")
    if host then
        frame:ClearAllPoints() frame:SetPoint("TOP",host,"TOP",0,0)
        frame:SetFrameLevel(host:GetFrameLevel()+2)
    else
    frame:SetFrameStrata("DIALOG") frame:SetToplevel(true) frame:SetClampedToScreen(true) frame:SetMovable(true) frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton") frame:SetScript("OnDragStart",frame.StartMoving)
    frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    frame.TitleContainer.TitleText:SetText(text("TITLE"))
    if frame.SetPortraitToAsset then frame:SetPortraitToAsset("Interface\\Icons\\INV_Scroll_03") end
    local bg=frame:CreateTexture(nil,"BACKGROUND",nil,1) bg:SetPoint("TOPLEFT",7,-27) bg:SetPoint("BOTTOMRIGHT",-7,7)
    bg:SetColorTexture(.055,.04,.025,.97)
    if UISpecialFrames then table.insert(UISpecialFrames,"ArtisanFinderAgreements") end
    end
    frame.direction="incoming" frame.offset=0 frame.tabs={} frame.forms={}
    frame.incoming=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    frame.incoming:SetSize(145,30) buttonFont(frame.incoming) frame.incoming:SetPoint("TOPLEFT",24,-40) frame.incoming:SetText(text("INCOMING"))
    frame.outgoing=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    frame.outgoing:SetSize(145,30) buttonFont(frame.outgoing) frame.outgoing:SetPoint("LEFT",frame.incoming,"RIGHT",6,0) frame.outgoing:SetText(text("OUTGOING"))
    for _,direction in ipairs({"incoming","outgoing"}) do
        frame[direction]:SetScript("OnClick",function()
            changeDirection(frame,direction) AF:RefreshAgreementUI()
        end)
    end
    frame.ignored=actionButton(frame,"IGNORED",function() showIgnored(frame) end)
    frame.ignored:SetSize(210,30) frame.ignored:SetPoint("TOPRIGHT",-32,-40)
    -- Independent surfaces leave a visible gutter between the file stack and document.
    frame.folders=paperColumn(frame,18,314)
    frame.folders:SetColorTexture(.12,.085,.045)
    frame.paper=paperColumn(frame,340,478,true)
    local stamp=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    frame.stamp=stamp stamp:SetSize(186,52) stamp:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-30,26)
    stamp:EnableMouse(false)
    stamp:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
    stamp:SetBackdropBorderColor(unpack(STAMP_INK))
    local brand=label(stamp,"ArtisanFinder",0,-7,186) brand:SetJustifyH("CENTER") font(brand,18)
    local completed=label(stamp,text("COMPLETED"),0,-30,186) completed:SetJustifyH("CENTER") font(completed,12)
    brand:SetTextColor(unpack(STAMP_INK)) completed:SetTextColor(unpack(STAMP_INK))
    stamp.animation=stamp:CreateAnimationGroup()
    local scale=stamp.animation:CreateAnimation("Scale")
    scale:SetScaleFrom(1.8,1.8) scale:SetScaleTo(1,1) scale:SetDuration(.22) scale:SetSmoothing("OUT")
    local fade=stamp.animation:CreateAnimation("Alpha")
    fade:SetFromAlpha(0) fade:SetToAlpha(1) fade:SetDuration(.22)
    stamp:Hide()
    frame.list=CreateFrame("Frame",nil,frame) frame.list:SetPoint("TOPLEFT",22,-78) frame.list:SetSize(306,480)
    frame.list:EnableMouseWheel(true) frame.list:SetScript("OnMouseWheel",function(_,delta)
        local count=#AF:GetAgreements(frame.direction)
        frame.offset=math.max(0,math.min(math.max(0,count-7),frame.offset-delta)) AF:RefreshAgreementUI()
    end)
    frame.rows={}
    for i=1,7 do
        local row=CreateFrame("Button",nil,frame.list) row:SetSize(306,66) row:SetPoint("TOPLEFT",0,-(i-1)*68)
        row.bg=row:CreateTexture(nil,"BACKGROUND") row.bg:SetAllPoints()
        row.selected=row:CreateTexture(nil,"ARTWORK") row.selected:SetPoint("TOPLEFT",0,0) row.selected:SetPoint("BOTTOMLEFT",0,0)
        row.selected:SetWidth(3) row.selected:SetColorTexture(.9,.7,.3)
        row.icon=row:CreateTexture(nil,"ARTWORK") row.icon:SetSize(26,26) row.icon:SetPoint("TOPLEFT",8,-8)
        row.item=label(row,"",40,-7,160) row.peer=label(row,"",40,-26,258) row.status=label(row,"",8,-46,190)
        row.price=label(row,"",204,-7,94) row.price:SetJustifyH("RIGHT")
        row.time=label(row,"",204,-46,94) row.time:SetJustifyH("RIGHT")
        for _,line in ipairs({row.item,row.peer,row.status,row.price,row.time}) do line:SetTextColor(.92,.84,.66) end
        for _,line in ipairs({row.item,row.peer,row.status,row.price,row.time}) do line:SetWordWrap(false) end
        row:SetScript("OnClick",function()
            saveForm(frame)
            frame.selectedID=row.id frame.editorInput=nil frame.detail.loadedContext=nil showError(frame)
            if AF.MarkAgreementRead then AF:MarkAgreementRead(row.id)
            else local record=AF:GetAgreement(row.id) if record then record.unread=false end end
            AF:RefreshAgreementUI()
        end)
        frame.rows[i]=row
    end
    frame.listInfo=label(frame,"",24,-568,302)
    frame.listInfo:SetJustifyH("CENTER")
    local function arrow(atlas,key,x,callback)
        local button=CreateFrame("Button",nil,frame)
        button:SetSize(24,24) button:SetPoint("TOPLEFT",x,-593)
        button.art=button:CreateTexture(nil,"ARTWORK")
        button.art:SetAtlas(atlas) button.art:SetSize(12,20) button.art:SetPoint("CENTER")
        button.art:SetVertexColor(.88,.88,.88)
        button:SetScript("OnClick",callback) tip(button,AF:Text(key))
        button:HookScript("OnLeave",function() button.art:SetVertexColor(.88,.88,.88) end)
        return button
    end
    frame.previous=arrow("common-icon-backarrow","FOREVER_PREVIOUS",24,function()
        frame.offset=math.max(0,frame.offset-7) AF:RefreshAgreementUI()
    end)
    frame.next=arrow("common-icon-forwardarrow","FOREVER_NEXT",302,function()
        frame.offset=math.min(math.max(0,#AF:GetAgreements(frame.direction)-7),frame.offset+7) AF:RefreshAgreementUI()
    end)
    frame.detail=CreateFrame("Frame",nil,frame) frame.detail:SetPoint("TOPLEFT",350,-88) frame.detail:SetSize(458,502)
    local panel=frame.detail
    panel.contact=label(panel,"",0,0,450) panel.crafter=label(panel,"",0,-22,450)
    panel.item=CreateFrame("Button",nil,panel,"SmallItemButtonTemplate") panel.item:SetPoint("TOPLEFT",0,-47) panel.item:SetSize(446,32)
    rewardCard(panel.item) panel.itemText=panel.item.label
    panel.quantityLabel=label(panel,text("QUANTITY"),0,-88,120)
    panel.quantity=field(panel,132,-80,65,3) panel.quantity:SetNumeric(true)
    panel.quantity:SetScript("OnTextChanged",function(_,userInput)
        if not userInput or not frame.editorInput then return end
        if not panel.priceEdited then
            local total,err=AF:GetAgreementEditorTotal(frame.editorInput.unitCommission,panel.quantity:GetText())
            setMoney(panel,total) showError(frame,err)
        end
        AF:RefreshAgreementMaterialsUI()
    end)
    panel.priceLabel=label(panel,text("TOTAL_COMMISSION"),0,-126,446) moneyFields(panel)
    panel.messageLabel=label(panel,text("MESSAGE"),0,-193,446)
    panel.message=field(panel,5,-211,437,256)
    panel.info=label(panel,"",0,-253,446) panel.info:SetHeight(52)
    panel.materialsLabel=label(panel,text("MATERIALS"),0,-311,446)
    panel.materials=label(panel,"",0,-333,446) panel.materials:SetHeight(130)
    panel.materials:SetWordWrap(true) panel.materials:SetJustifyV("TOP")
    for _,line in ipairs({panel.contact,panel.crafter,panel.quantityLabel,panel.priceLabel,
        panel.messageLabel,panel.info,panel.materialsLabel,panel.materials}) do ink(line) end
    ink(panel.crafter,true) ink(panel.info,true)
    panel.materialScroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    panel.materialScroll:SetPoint("TOPLEFT",0,-333) panel.materialScroll:SetSize(420,130)
    panel.materialContent=CreateFrame("Frame",nil,panel.materialScroll) panel.materialContent:SetSize(420,130)
    panel.materialScroll:SetScrollChild(panel.materialContent)
    panel.materialScroll.scrollBarHideable=true
    panel.materialScroll:HookScript("OnSizeChanged",updateMaterialScroll)
    updateMaterialScroll(panel.materialScroll)
    panel.materialRows={}
    frame.actions={}
    for _,action in ipairs({"SEND","ACCEPT","DECLINE","COUNTER","CANCEL","COMPLETE","TRACK","RETRY","WHISPER","IGNORE","DELETE"}) do
        frame.actions[action]=actionButton(frame,action,function() AF:AgreementUIAction(action) end)
    end
    frame.notice=label(frame,"",350,-694,446) frame.notice:SetHeight(30) frame.notice:SetJustifyV("TOP")
    ink(frame.notice) frame.notice:SetTextColor(.50,.09,.04)
    frame:RegisterEvent("BAG_UPDATE_DELAYED") frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    frame:SetScript("OnEvent",function(_,event)
        if event=="BAG_UPDATE_DELAYED" and AF.SendAgreementCustomerStock then
            for _,agreement in ipairs(AF:GetAgreements("outgoing")) do
                if not AF:AgreementIsTerminal(agreement.status) then AF:SendAgreementCustomerStock(agreement) end
            end
        end
        if isAgreementVisible(frame) then
            if event=="ITEM_DATA_LOAD_RESULT" then AF:RefreshAgreementUI() else AF:RefreshAgreementMaterialsUI() end
        end
    end)
    frame:SetScript("OnHide",function() saveForm(frame) frame.stamp.animation:Stop() end)
    frame:SetScript("OnShow",function() raiseWindow(frame) AF:RefreshAgreementUI() end)
    frame:Hide() return frame
end
function AF:RefreshAgreementMaterialsUI()
    local frame=self.agreementsFrame if not frame then return end
    local record=selectedRecord(frame) or frame.editorInput
    local panel=frame.detail
    for _,row in ipairs(panel.materialRows) do
        if GameTooltip.IsOwned and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row:Hide()
    end
    panel.materials:SetText("")
    if not record then return end
    local copy={} for key,value in pairs(record) do copy[key]=value end
    if frame.editorInput then copy.quantity=tonumber(panel.quantity:GetText()) or 1 end
    if self.RequestAgreementCustomerStock then self:RequestAgreementCustomerStock(copy) end
    local materials,output=self:GetAgreementMaterials(copy)
    if not materials then panel.materials:SetText(self:Text("FOREVER_MATERIALS_UNAVAILABLE")) panel.materialScroll:Hide() return end
    panel.materialScroll:Show()
    local index=0
    local function addLine(value,link,itemID,counts,missing)
        index=index+1
        local row=panel.materialRows[index]
        if not row then
            row=CreateFrame("Button",nil,panel.materialContent,"SmallItemButtonTemplate") row:SetSize(420,34)
            rewardCard(row)
            row.counts=label(row,"",0,0,268) font(row.counts,12)
            row.counts:ClearAllPoints() row.counts:SetPoint("LEFT",row.nameFrame,"RIGHT",6,0)
            row.counts:SetHeight(26) row.counts:SetJustifyH("LEFT") row.counts:SetJustifyV("MIDDLE")
            ink(row.counts)
            row:SetPoint("TOPLEFT",0,-(index-1)*34) panel.materialRows[index]=row
            row:SetScript("OnEnter",function(owner)
                if owner.link then GameTooltip:SetOwner(owner,"ANCHOR_RIGHT") GameTooltip:SetHyperlink(owner.link) GameTooltip:Show() end
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row:SetScript("OnHide",function(owner) if GameTooltip.IsOwned and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
        end
        row.link=link row.counts:SetText(counts or "")
        if type(missing)=="number" then
            if missing>0 then row.counts:SetTextColor(.65,.08,.025)
            else row.counts:SetTextColor(.10,.35,.10) end
        else ink(row.counts,true) end
        if itemID then showReward(row,value,link,itemID)
        else
            row.icon:Hide() row.nameFrame:Hide() row.border:Hide()
            row.label:ClearAllPoints() row.label:SetPoint("TOPLEFT",0,-2) row.label:SetWidth(420) ink(row.label)
            row.label:SetText(value)
        end
        if itemID then
            row.label:ClearAllPoints() row.label:SetPoint("LEFT",row.nameFrame,"LEFT",4,0) row.label:SetSize(92,36)
            row.label:SetTextColor(1,1,1) row.label:SetShadowColor(0,0,0,1)
        end
        row:Show()
    end
    if output then addLine(text("OUTPUT",output.minimum,output.maximum)) end
    for _,material in ipairs(materials) do
        local _,link=self:GetAgreementMaterialPresentation(material)
        local counts
        if material.owned==nil then counts=text("MATERIAL_UNKNOWN",material.quantity)
        else counts=text("MATERIAL_LINE","",material.owned,material.quantity,material.missing):gsub("^%s*·%s*","") end
        addLine(link or self:Text("AGREEMENT_UNKNOWN_CRAFT"),link,material.itemID,counts,material.missing)
    end
    panel.materialContent:SetHeight(index*34)
    updateMaterialScroll(panel.materialScroll)
end
function AF:RefreshAgreementUnreadIndicator()
    if self.RefreshNotificationCountBadges then self:RefreshNotificationCountBadges() end
end
function AF:RefreshAgreementUI()
    self:RefreshAgreementUnreadIndicator()
    local frame=self.agreementsFrame if not isAgreementVisible(frame) then return end
    saveForm(frame)
    local records=self:GetAgreements(frame.direction)
    frame.offset=math.max(0,math.min(frame.offset,math.max(0,#records-7)))
    frame.previous:SetEnabled(frame.offset>0) frame.next:SetEnabled(frame.offset+7<#records)
    frame.previous:SetAlpha(frame.offset>0 and 1 or .35) frame.next:SetAlpha(frame.offset+7<#records and 1 or .35)
    frame.incoming:SetEnabled(frame.direction~="incoming") frame.outgoing:SetEnabled(frame.direction~="outgoing")
    for i,row in ipairs(frame.rows) do
        local record=records[i+frame.offset] row.id=record and record.id
        if record then
            local peer=frame.direction=="incoming" and record.customer or record.artisan
            row.item:SetText((record.unread and "|cffffd100• |r" or "")..shownItem(record))
            row.peer:SetText(peer or "")
            local itemID=tonumber(record.itemID)
            local texture
            if itemID and itemID>0 and C_Item and C_Item.GetItemIconByID then texture=C_Item.GetItemIconByID(itemID)
            elseif record.recipeID and C_Spell and C_Spell.GetSpellTexture then texture=C_Spell.GetSpellTexture(record.recipeID) end
            row.icon:SetTexture(texture or "Interface\\Icons\\INV_Scroll_03") itemTooltip(row,record)
            local dateText=date and date("%d/%m %H:%M",record.updatedAt or record.createdAt) or ""
            local commission=record.commission==nil and "—" or self:FormatMoney(record.commission,record.commission==0)
            row.status:SetText(self:GetAgreementDisplayStatus(record)) row.price:SetText(commission) row.time:SetText(dateText)
            local selected=frame.selectedID==record.id
            row.bg:SetColorTexture(selected and .28 or .16,selected and .22 or .12,selected and .13 or .075)
            row.selected:SetShown(selected) row:Show()
        else row:Hide() end
    end
    frame.listInfo:SetText(#records==0 and text("EMPTY") or text("LIST_COUNT",#records))
    local record=selectedRecord(frame) or frame.editorInput local panel=frame.detail
    for _,button in pairs(frame.actions) do button:Hide() end
    local completed=record and not frame.editorInput and status(record)=="COMPLETED"
    if frame.stamp.recordID~=(record and record.id) or not completed then frame.stamp.animation:Stop() end
    frame.stamp.recordID=record and record.id
    frame.stamp:SetShown(completed or false)
    if not record then panel.loadedContext=nil panel:Hide() layoutActions(frame,0) return end panel:Show()
    local editing=frame.editorInput~=nil
    panel.contact:SetText(text("CONTACT",not editing and record.localRole=="artisan" and record.customer or record.artisan or record.contact or ""))
    panel.crafter:SetText(text("CRAFTING_CHARACTER",record.craftingCharacter or record.artisan or ""))
    local _,craftLink=self:GetAgreementCraftPresentation(record)
    showReward(panel.item,shownItem(record),craftLink,record.itemID,record.recipeID) itemTooltip(panel.item,record)
    panel.quantity:SetEnabled(editing)
    local context=editing and record or record.id
    if panel.loadedContext~=context or panel.loadedRevision~=record.stateRevision then
        local form=frame.forms[context]
        if form and form.revision~=record.stateRevision then form=nil frame.forms[context]=nil end
        panel.loadedContext=context panel.loadedID=record.id panel.loadedRevision=record.stateRevision
        panel.quantity:SetText(form and form.quantity or tostring(record.quantity or 1))
        if form then
            panel.syncing=true
            for i,box in ipairs(panel.money) do box:SetText(form.money[i]) end
            panel.syncing=false
        else setMoney(panel,record.commission) end
        panel.message:SetText(form and form.message or record.message or "")
        panel.priceEdited=form and form.priceEdited or false
    end
    local s=status(record)
    local role=record.localRole or (record.customer==self.playerName and "customer" or "artisan")
    local canCounter=not editing and role=="artisan" and (s=="PENDING" or s=="COUNTEROFFERED")
    for _,box in ipairs(panel.money) do box:SetEnabled(editing or canCounter) end
    panel.message:SetEnabled(editing or canCounter)
    local info=editing and text("DRAFT_HELP") or self:GetAgreementDisplayStatus(record)
    if not editing and record.snapshotDelivery and not record.snapshotDelivery.failed then info=info.." · "..text("WAITING_DELIVERY") end
    panel.info:SetText(info)
    if (editing or isDraft(record)) and record.artisan and not self:HasAgreementSupport(record.artisan) then panel.info:SetText(text("UNSUPPORTED")) end
    self:RefreshAgreementMaterialsUI()
    local visible={}
    local function add(action) visible[#visible+1]=action end
    if editing then add("SEND") add("WHISPER")
    else
        if isDraft(record) then add("SEND") add("WHISPER") add("DELETE")
        elseif not terminal[s] then
            if s=="PENDING" and role=="artisan" then add("ACCEPT") add("DECLINE") add("COUNTER") end
            if s=="COUNTEROFFERED" then
                if role=="customer" then add("ACCEPT") else add("DECLINE") add("COUNTER") end
            end
            if s=="ACCEPTED" then
                if not record.completion or not record.completion[role] then add("COMPLETE") end
                add("TRACK")
            end
            add("CANCEL")
            if (record.delivery=="failed" and record.pendingAction) or (record.snapshotDelivery and record.snapshotDelivery.failed) then add("RETRY") end
            add("WHISPER")
        else add("DELETE") add("WHISPER") end
        if record.snapshotDelivery and record.snapshotDelivery.failed and terminal[s] then add("RETRY") end
        add("IGNORE")
        if record.pendingAction then
            visible={}
            if role=="customer" and not terminal[s] and record.pendingAction.command
                and record.pendingAction.command.action~="cancel" then add("CANCEL") end
            if record.delivery=="failed" then add("RETRY") end
            add("WHISPER") add("IGNORE")
        end
    end
    layoutActions(frame,#visible)
    for index,action in ipairs(visible) do
        local button=frame.actions[action]
        if action=="COMPLETE" then
            local otherRole=role=="artisan" and "customer" or "artisan"
            button:SetText(text(record.completion and record.completion[otherRole] and "BUTTON_CONFIRM" or "BUTTON_COMPLETE"))
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",350+((index-1)%2)*228,-558-math.floor((index-1)/2)*36)
        button:Show()
    end
    if completed and not record.completionStampSeen then
        -- Local SavedVariables flag, deliberately excluded from AgreementSnapshot's wire fields.
        -- Set only after displaying the completed page, including a historical agreement's first open.
        record.completionStampSeen=true
        frame.stamp.animation:Play()
    end
end
function AF:OpenAgreementEditor(input)
    if type(input)~="table" or not (input.artisan or input.contact) or not input.recipeID then return nil end
    local frame=self.agreementsFrame or makeWindow()
    local copy={} for key,value in pairs(input) do copy[key]=value end
    copy.artisan=copy.artisan or copy.contact copy.quantity=copy.quantity or 1
    copy.unitCommission=copy.unitCommission==nil and copy.commission or copy.unitCommission
    changeDirection(frame,"outgoing")
    if frame.editorInput then frame.forms[frame.editorInput]=nil end
    frame.editorInput=copy frame.selectedID=nil
    frame.detail.loadedContext=nil
    local total,err=self:GetAgreementEditorTotal(copy.unitCommission,copy.quantity)
    copy.commission=total
    showError(frame,err) self:ProbeAgreementSupport(copy.artisan)
    if frame.directoryHost then self:SelectForeverDirectoryTab("agreements") frame.directoryHost:Show() end
    frame:Show() raiseWindow(frame) self:RefreshAgreementUI() return frame
end
function AF:ShowAgreements(direction)
    local frame=self.agreementsFrame or makeWindow()
    changeDirection(frame,(direction=="incoming" or direction=="outgoing") and direction or frame.direction)
    if frame.directoryHost then self:SelectForeverDirectoryTab("agreements") frame.directoryHost:Show() end
    frame:Show() raiseWindow(frame) self:RefreshAgreementUI() return frame
end
function AF:OpenAgreementNotification(record)
    local frame=self.agreementsFrame or makeWindow()
    saveForm(frame)
    changeDirection(frame,record.localRole=="artisan" and "incoming" or "outgoing")
    frame.selectedID=record.id frame.editorInput=nil frame.detail.loadedContext=nil
    showError(frame)
    if self.MarkAgreementRead then self:MarkAgreementRead(record.id) else record.unread=false end
    if frame.directoryHost then self:SelectForeverDirectoryTab("agreements") frame.directoryHost:Show() end
    frame:Show() raiseWindow(frame) self:RefreshAgreementUI()
end
function AF:AgreementUIAction(action)
    local frame=self.agreementsFrame if not frame then return end
    local record=selectedRecord(frame) local input=frame.editorInput
    showError(frame)
    if action=="WHISPER" then
        local peer=input and input.artisan or record and (record.localRole=="artisan" and record.customer or record.artisan)
        if peer and ChatFrame_SendTell then ChatFrame_SendTell(peer) end return
    end
    if action=="SEND" then
        if input then
            local quantity=tonumber(frame.detail.quantity:GetText())
            if not quantity or quantity%1~=0 or quantity<1 or quantity>999 then showError(frame,"QUANTITY_ERROR") return end
            local commission,err=readMoney(frame.detail) if err then showError(frame,err) return end
            local draft={} for key,value in pairs(input) do draft[key]=value end
            draft.quantity=quantity draft.commission=commission draft.message=frame.detail.message:GetText()
            local draftError
            record,draftError=self:CreateAgreementDraft(draft)
            if not record then showSendError(frame,draftError) return end
            frame.forms[input]=nil frame.detail.loadedContext=nil
            frame.selectedID=record.id frame.editorInput=nil
        end
        if record then
            local ok,err=self:SendAgreement(record.id)
            if not ok then showSendError(frame,err) end
        end
    elseif record then
        if action=="TRACK" then
            if not self:TrackAgreementMaterials(record) then showError(frame,"MATERIALS_ERROR") end
        elseif action=="RETRY" then self:RetryAgreement(record.id)
        elseif action=="IGNORE" then
            local peer=record.localRole=="artisan" and record.customer or record.artisan self:IgnoreAgreementPeer(peer)
        elseif action=="DELETE" then self:DeleteAgreement(record.id) frame.forms[record.id]=nil frame.selectedID=nil
        else
            local terms
            if action=="COUNTER" then
                local commission,err=readMoney(frame.detail) if err or commission==nil then showError(frame,err or "PRICE_ERROR") return end
                terms={commission=commission,message=frame.detail.message:GetText()}
            end
            local ok=self:PerformAgreementAction(record.id,action,terms)
            if not ok then showError(frame,"ACTION_ERROR") end
        end
    end
    self:RefreshAgreementUI()
end
function AF:GetAgreementUnreadCount()
    local count=0
    for _,direction in ipairs({"incoming","outgoing"}) do
        for _,record in ipairs(self:GetAgreements(direction)) do if record.unread then count=count+1 end end
    end
    return count
end
function AF:OnAgreementChanged(record,isIncomingEvent)
    local frame=self.agreementsFrame
    if isAgreementVisible(frame) and frame.selectedID==record.id then
        if self.MarkAgreementRead then self:MarkAgreementRead(record.id) else record.unread=false end
    end
    self:RefreshAgreementUI()
    if self.RefreshAgreementUnreadIndicator then self:RefreshAgreementUnreadIndicator() end
    if isIncomingEvent and record.unread and self.QueueAgreementNotification then
        self:QueueAgreementNotification(record)
    end
end
