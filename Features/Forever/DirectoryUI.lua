local _, AF = ...
local PAGE=12
local HEADER=82
local ROW_FONT_SIZE=14
local ROW_PROFESSION_ICON_SIZE=22
local ENABLE_DISCOVERY_REFRESH=false
local GOLD={1,.82,.35}
local MUTED={.68,.65,.57}
local function label(parent,value,x,y,width,style,color)
    local text=parent:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT",x,y) text:SetWidth(width) text:SetJustifyH("LEFT")
    text:SetWordWrap(false) text:SetMaxLines(1) text:SetText(value or "")
    if color then text:SetTextColor(unpack(color)) end
    return text
end
local function tip(button,title,help)
    button:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT") GameTooltip:SetText(title,1,.82,.35)
        if help then GameTooltip:AddLine(help,1,1,1,true) end GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function icon(parent,texture,title,action,help)
    local button=CreateFrame("Button",nil,parent) button:SetSize(22,22)
    local art=button:CreateTexture(nil,"ARTWORK") art:SetAllPoints()
    if texture:sub(1,6)=="atlas:" then art:SetAtlas(texture:sub(7)) else art:SetTexture(texture) end
    button.art=art
    art:SetVertexColor(.88,.88,.88)
    button:SetScript("OnClick",action) tip(button,title,help)
    button:HookScript("OnEnter",function() art:SetVertexColor(1,1,1) end)
    button:HookScript("OnLeave",function() art:SetVertexColor(.88,.88,.88) end)
    return button
end
local function sortedIDs(values)
    local ids={} for id in pairs(values or {}) do ids[#ids+1]=id end table.sort(ids) return ids
end
local function sourceText(source) return AF:GetForeverDiscoverySourceLabel(source) end
local function columns(width)
    local profession=width*.285
    local professionWidth=6*ROW_PROFESSION_ICON_SIZE+5*4+12
    local source=profession+professionWidth
    return profession,source,source+150,source+250
end
local function showItemMatches(owner,matches)
    if #matches==0 or not MenuUtil then
        AF:SetCustomerStatusText(AF:Text("FOREVER_ITEM_NOT_FOUND")) return
    end
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(AF:Text("FOREVER_CHOOSE_ITEM"))
        for _,match in ipairs(matches) do
            local item=match
            local link,_,payload=AF:GetForeverCraftPresentation({itemID=item.itemID,itemName=item.name})
            local button=root:CreateButton(link,function()
                AF.customerFrame.item:SetText(item.name) AF:SelectCustomerItem(item.itemID)
            end)
            button:SetTooltip(function(tooltip) tooltip:SetHyperlink(payload) end)
        end
    end)
end
local function searchItem()
    local frame=AF.customerFrame local query=frame.item:GetText()
    local item,matches=AF:SelectCustomerItem(query)
    if not item and matches and #matches>1 then showItemMatches(frame.item,matches) end
end
function AF:GetCustomerSortOptions() return {{key="best",labelKey="SORT_RECOMMENDED"}} end
function AF:SetDefaultSort() self:RefreshCustomerResults() end
function AF:SetCustomerStatusText(value) if self.customerFrame then self.customerFrame.notice:SetText(value or "") end end
function AF:SetCustomerStatusItem(itemID,itemName) self:SetCustomerStatusText(itemName or self:GetDisplayItemName(itemID)) end
function AF:OpenForeverProfessionFilter(owner)
    if not MenuUtil then return end
    local function choose(id) AF.directoryProfession=id AF.directoryPage=1 AF:RefreshCustomerResults() end
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(AF:Text("FOREVER_PROFESSION"))
        root:CreateRadio(AF:Text("FOREVER_ALL"),function() return AF.directoryProfession==nil end,function() choose(nil) end)
        local professions={[164]=true,[165]=true,[171]=true,[197]=true,[202]=true,[333]=true,[185]=true,[129]=true}
        for _,row in ipairs(AF:GetDirectoryEntries("")) do if row.professionID then professions[row.professionID]=true end end
        for _,id in ipairs(sortedIDs(professions)) do
            local profession=id
            root:CreateRadio(AF:GetProfessionIconMarkup(profession,nil,16).." "..AF:GetProfessionName(profession),
                function() return AF.directoryProfession==profession end,function() choose(profession) end)
        end
    end)
end
function AF:OpenForeverSourceFilter(owner)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(owner,function(_,root)
        root:CreateTitle(AF:Text("FOREVER_DISCOVERED_BY"))
        for _,source in ipairs({"ALL","ADDON","LINKEDINN","CRAFTBOARD","RELEASEGAMING","GUILD","TRADE"}) do
            local value=source
            root:CreateRadio(value=="ALL" and AF:Text("FOREVER_ALL") or sourceText(value),
                function() return (AF.directorySource or "ALL")==value end,function()
                    AF.directorySource=value~="ALL" and value or nil AF.directoryPage=1 AF:RefreshCustomerResults()
                end)
        end
    end)
end
local function rowIsHovered(row)
    if row:IsMouseOver() then return true end
    for _,button in ipairs({row.action,row.star,row.link,row.whoRefresh,row.itemLink,row.track,row.request,row.completedTip}) do
        if button and button:IsShown() and button:IsMouseOver() then return true end
    end
    for _,button in ipairs(row.professionButtons or {}) do
        if button:IsShown() and button:IsMouseOver() then return true end
    end
    return false
end
local function updateRowActions(row, hovered)
    hovered=hovered and (not row.view or row.view.kind~="empty")
    row.hovered=hovered==true
    row.actions:SetShown(row.hovered)
    row.updatedAt:SetShown(not row.view or row.view.kind=="artisan")
end
local function deferRowLeave(row)
    -- Parent OnLeave can run before the child's OnEnter during a mouse move.
    local view=row.view
    C_Timer.After(0,function()
        if row.view==view then updateRowActions(row,row:IsShown() and rowIsHovered(row)) end
    end)
end
local function sortableHeader(frame,heading,key)
    local button=CreateFrame("Button",nil,frame.header)
    button:SetPoint("TOPLEFT",heading,"TOPLEFT",-2,4) button:SetHeight(22)
    button:SetScript("OnClick",function() AF:SetForeverDirectorySort(key) end)
    tip(button,AF:Text("FOREVER_SORT"),AF:Text("FOREVER_SORT_HINT"))
    button.arrow=button:CreateTexture(nil,"ARTWORK") button.arrow:SetSize(8,12)
    button.arrow:SetAtlas("common-icon-forwardarrow") button.arrow:SetPoint("LEFT",heading,"RIGHT",4,0)
    button.heading,button.sortKey=heading,key
    return button
end
function AF:RefreshForeverSortHeaders()
    local frame=self.customerFrame
    if not frame then return end
    local key,descending=self:GetForeverDirectorySort()
    for _,button in ipairs(frame.sortHeaders) do
        local active=button.sortKey==key
        local width=button.heading:GetStringWidth() or button.heading:GetWidth()
        button.heading:SetWidth(math.min(width,button.heading:GetWidth()))
        button:SetWidth(button.heading:GetWidth()+18)
        button.heading:SetTextColor(unpack(active and {1,.96,.62} or {.69,.58,.37}))
        button.arrow:SetShown(active) button.arrow:SetRotation(descending and -math.pi/2 or math.pi/2)
    end
end
local function showCraftTooltip(row,owner)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    if row.craftPayload then GameTooltip:SetHyperlink(row.craftPayload) else GameTooltip:SetText(row.view.label,1,1,1) end
    GameTooltip:Show()
end
local function createRow(parent)
    local row=CreateFrame("Button",nil,parent)
    row.hovered=false
    row.shade=row:CreateTexture(nil,"BACKGROUND") row.shade:SetAllPoints()
    row.rule=row:CreateTexture(nil,"BORDER") row.rule:SetPoint("BOTTOMLEFT") row.rule:SetPoint("BOTTOMRIGHT")
    row.rule:SetHeight(1) row.rule:SetColorTexture(.52,.36,.14,.18)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
    row.chevron=row:CreateTexture(nil,"ARTWORK")
    row.chevron:SetSize(10,14) row.chevron:SetAtlas("common-icon-forwardarrow")
    row.name=label(row,"",12,0,200)
    row.completed=label(row,"",26,0,200,"GameFontHighlightSmall",MUTED)
    row.completedTip=CreateFrame("Button",nil,row)
    row.completedTip:SetAllPoints(row.completed)
    row.completedTip:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        GameTooltip:SetText(AF:Text("FOREVER_COMPLETED_AGREEMENTS"),1,.82,.35)
        GameTooltip:AddLine(row.completed:GetText(),1,1,1,true)
        GameTooltip:AddLine(AF:Text("FOREVER_COMPLETED_AGREEMENTS_HELP"),1,1,1,true)
        GameTooltip:Show()
    end)
    row.completedTip:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row.completedTip:SetScript("OnClick",function() if row:GetScript("OnClick") then row:GetScript("OnClick")(row) end end)
    row.itemIcon=row:CreateTexture(nil,"ARTWORK") row.itemIcon:SetSize(20,20)
    row.itemIcon:SetPoint("LEFT",row,"LEFT",46,0) row.itemIcon:SetTexCoord(.08,.92,.08,.92)
    row.itemLink=CreateFrame("Button",nil,row) row.itemLink:SetAllPoints(row.name)
    row.itemLink:SetScript("OnEnter",function(owner) showCraftTooltip(row,owner) end)
    row.itemLink:SetScript("OnLeave",function() GameTooltip:Hide() end)
    row.itemLink:SetScript("OnClick",function()
        if row.craftLink and HandleModifiedItemClick and HandleModifiedItemClick(row.craftLink) then return end
        if row.craftPayload and SetItemRef then SetItemRef(row.craftPayload,row.craftLink,"LeftButton",DEFAULT_CHAT_FRAME) end
    end)
    row.professionButtons={}
    row.professions=label(row,"",0,0,120)
    row.source=label(row,"",0,0,170,nil,{.85,.75,.55})
    row.price=label(row,"",0,0,110,nil,{.95,.85,.6})
    row.updatedAt=label(row,"",0,0,150,nil,MUTED)
    row.updatedAt:SetMaxLines(2)
    for _,text in ipairs({row.name,row.professions,row.source,row.price,row.updatedAt}) do
        text:SetFontObject("GameFontHighlight")
        local font,_,flags=text:GetFont()
        if font then text:SetFont(font,ROW_FONT_SIZE,flags) end
    end
    row.actions=CreateFrame("Frame",nil,row) row.actions:EnableMouse(false)
    row.actions:SetFrameLevel((row:GetFrameLevel() or 0)+2)
    row.actions:SetSize(75,26) row.actions:Hide()
    row.action=icon(row.actions,"Interface\\ChatFrame\\UI-ChatIcon-ArmoryChat",AF:Text("WHISPER"),function()
        if row.entry and not row.entry.ownAlt then ChatFrame_SendTell(row.entry.target or row.entry.name) end
    end) row.action:SetPoint("RIGHT",0,0)
    row.star=icon(row,"atlas:PetJournal-FavoritesIcon",AF:Text("FAVORITE"),function()
        AF:ToggleFavoriteArtisan(row.entry) AF.directoryLiveOrder=nil AF:RefreshCustomerResults()
    end) row.star:SetPoint("RIGHT",row,"RIGHT",-5,0)
    -- Fit the native atlas without stretching its artwork or cropping its tips.
    local starInfo=C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("PetJournal-FavoritesIcon")
    local starWidth,starHeight=20,20
    if starInfo and starInfo.width and starInfo.height and starInfo.width>0 and starInfo.height>0 then
        local scale=20/math.max(starInfo.width,starInfo.height)
        starWidth,starHeight=starInfo.width*scale,starInfo.height*scale
    end
    row.star.art:ClearAllPoints() row.star.art:SetPoint("CENTER") row.star.art:SetSize(starWidth,starHeight)
    row.track=icon(row,"Interface\\Buttons\\UI-CheckBox-Check",AF:Text("FOREVER_TRACK_MATERIALS"),function()
        if row.view.kind=="craft" then AF:TrackForeverCraftMaterials(row.entry) end
    end,AF:Text("FOREVER_TRACK_MATERIALS_HELP"))
    row.track:SetPoint("RIGHT",row,"RIGHT",-5,0)
    row.request=icon(row,"Interface\\Cursor\\LootAll",AF:Text("AGREEMENT_REQUEST"),function()
        AF:RequestForeverCraftAgreement(row.view)
    end)
    row.request:SetPoint("RIGHT",row.track,"LEFT",-4,0)
    row.actions:SetPoint("RIGHT",row.star,"LEFT",-3,0)
    row.link=icon(row.actions,"Interface\\Buttons\\UI-GuildButton-PublicNote-Up",AF:Text("PROFESSION_LINK"),function(owner)
        local offers=AF:GetOpenableForeverProfessions(row.group)
        if #offers>1 and MenuUtil then
            MenuUtil.CreateContextMenu(owner,function(_,root)
                for _,entry in ipairs(offers) do
                    root:CreateButton(AF:GetProfessionName(entry.professionID),function() AF:OpenCrafterProfession(entry) end)
                end
            end)
        elseif offers[1] then AF:OpenCrafterProfession(offers[1]) end
    end) row.link:SetPoint("RIGHT",row.action,"LEFT",-3,0)
    row.whoRefresh=icon(row.actions,"Interface\\Buttons\\UI-RefreshButton",AF:Text("WHO_REFRESH_HINT",""),function()
        AF:RefreshCustomerEntryWhoStatus(row.entry)
    end) row.whoRefresh:SetPoint("RIGHT",row.link,"LEFT",-3,0)
    row.whoRefresh:SetEnabled(ENABLE_DISCOVERY_REFRESH)
    row.whoRefresh:SetShown(ENABLE_DISCOVERY_REFRESH)
    row:SetScript("OnClick",function() if row.view then AF:ToggleForeverDirectoryRow(row.view) end end)
    row:SetScript("OnEnter",function(owner)
        updateRowActions(row,true)
        AF:DebugLog("profession-link", "hover name="..tostring(row.group.name).." source="..tostring(row.group.source).." openable="..#AF:GetOpenableForeverProfessions(row.group))
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        if row.view and row.view.kind=="profession" then
            GameTooltip:SetText(AF:GetProfessionName(row.view.professionID),1,.82,.35)
            GameTooltip:AddLine(AF:GetDisplayPlayerName(row.group.name),.7,.7,.7)
            GameTooltip:AddLine(" ")
            local defaults=AF:GetForeverProfessionDefaults(row.group.name,row.view.professionID)
            local note=AF:GetEntryNote(defaults)
            GameTooltip:AddLine(note and note~="" and note or AF:Text("FOREVER_NO_DEFAULT_NOTE"),1,1,1,true)
            GameTooltip:AddLine(" ") GameTooltip:AddLine(AF:Text("FOREVER_PRICE_DEFAULT")..": "..row.priceText,1,.82,.35)
            GameTooltip:Show() return
        elseif row.view and row.view.kind=="craft" then
            showCraftTooltip(row,owner) return
        elseif row.view and row.view.kind=="empty" then GameTooltip:Hide() return end
        GameTooltip:SetText(AF:GetDisplayPlayerName(row.group.name))
        GameTooltip:AddLine(" ")
        for _,id in ipairs(sortedIDs(row.group.professions)) do
            GameTooltip:AddLine(AF:GetProfessionIconMarkup(id,nil,18).." "..AF:GetProfessionName(id),1,.82,.35)
        end
        GameTooltip:AddLine(" ") GameTooltip:AddLine(sourceText(row.group.source),.7,.7,.7)
        if row.entry.note and row.entry.note~="" then GameTooltip:AddLine(row.entry.note,1,1,1,true) end
        if row.entry.directoryItemName then GameTooltip:AddLine(row.entry.directoryItemName,.7,.7,.7,true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(AF:Text("FOREVER_PRICE"),1,.82,.35)
        if row.priceDetails and #row.priceDetails>0 then
            for _,detail in ipairs(row.priceDetails) do GameTooltip:AddLine(detail,1,1,1,true) end
        else GameTooltip:AddLine(AF:Text("FOREVER_PRICE_UNKNOWN"),.68,.65,.57,true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function()
        deferRowLeave(row) GameTooltip:Hide()
    end)
    for _,button in ipairs({row.action,row.star,row.link,row.whoRefresh,row.itemLink,row.track,row.request,row.completedTip}) do
        button:SetFrameLevel(button==row.itemLink and row:GetFrameLevel()+1 or row.actions:GetFrameLevel()+1)
        local enter,leave=button:GetScript("OnEnter"),button:GetScript("OnLeave")
        button:SetScript("OnEnter",function(owner,...)
            updateRowActions(row,true)
            if enter then enter(owner,...) end
        end)
        button:SetScript("OnLeave",function(owner,...)
            if leave then leave(owner,...) end
            deferRowLeave(row)
        end)
    end
    return row
end
function AF:InitializeCustomerUI() self:AttachCustomerUI() end
-- Discovery and agreements share one shell, so navigation never opens overlapping windows.
function AF:SelectForeverDirectoryTab(kind)
    self:AttachCustomerUI()
    local frame=self.customerFrame
    kind=kind=="agreements" and "agreements" or "discovery"
    if kind=="agreements" and not self.agreementsFrame then self:ShowAgreements() return end
    if frame.directoryTab==kind then return end
    if self.activeTutorialKind=="discovery" and self.EndForeverTutorial then self:EndForeverTutorial() end
    frame.directoryTab=kind
    local discovery=kind=="discovery"
    for _,widget in ipairs(frame.discoveryWidgets) do widget:SetShown(discovery) end
    if self.customerTutorialButton then self.customerTutorialButton:SetShown(discovery) end
    if self.agreementsFrame then self.agreementsFrame:SetShown(not discovery) end
    self:PositionForeverDirectoryTabs()
    if discovery then
        self:ResizeForeverDirectoryHost(620)
        self:RefreshCustomerResults()
    else self:RefreshAgreementUI() end
end
function AF:ResizeForeverDirectoryHost(height)
    local frame=self.customerFrame
    if not frame then return end
    -- Match the agreement canvas instead of centering it inside the wider directory.
    local width=frame.directoryTab=="agreements" and self.agreementsFrame and self.agreementsFrame:GetWidth()
        or frame.discoveryWidth or frame:GetWidth()
    frame:SetSize(width,height)
    if self.directoryInProfessions and ProfessionsFrame then
        ProfessionsFrame:SetSize(width,height)
    else
        local rightInset=frame.agreements:GetWidth()+28
        frame:SetScale(math.min(1,(UIParent:GetWidth()-24)/(frame:GetWidth()+rightInset),(UIParent:GetHeight()-24)/height))
    end
end
function AF:PositionForeverDirectoryTabs()
    local frame=self.customerFrame
    if not frame or not frame.directoryTabs then return end
    local embedded=self.directoryInProfessions~=nil
    frame:SetClampRectInsets(0,embedded and 0 or frame.agreements:GetWidth()+28,0,0)
    for index,tab in ipairs(frame.directoryTabs) do
        tab:SetShown(not embedded)
        tab:SetFrameStrata(frame:GetFrameStrata())
        tab:SetFrameLevel(frame:GetFrameLevel()+20)
        tab:SetChecked((index==2)==(frame.directoryTab=="agreements"))
    end
    if self.foreverDiscoveryTab then self.foreverDiscoveryTab:SetChecked(embedded and frame.directoryTab~="agreements") end
    if self.foreverAgreementsTab then self.foreverAgreementsTab:SetChecked(embedded and frame.directoryTab=="agreements") end
end
local function directoryTabs(frame)
    frame.directoryTabs={}
    local textures={"Interface\\AddOns\\"..(AF.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png","Interface\\Icons\\INV_Scroll_03"}
    for index,key in ipairs({"FOREVER_DISCOVERY_OPTIONS","AGREEMENT_TAB"}) do
        local tab=CreateFrame("Frame",nil,frame,"LargeSideTabButtonTemplate")
        tab:EnableMouse(true) tab:SetFillToInterior(true)
        tab.tooltipText="ArtisanFinder - "..AF:Text(key) tab.Icon:SetTexture(textures[index])
        if index==1 then tab:SetPoint("TOPLEFT",frame,"TOPRIGHT",0,-60)
        else tab:SetPoint("TOPLEFT",frame.directoryTabs[index-1],"BOTTOMLEFT",0,-2) end
        tab:SetCustomOnMouseUpHandler(function(_,button,inside)
            if button=="LeftButton" and inside then AF:SelectForeverDirectoryTab(index==1 and "discovery" or "agreements") end
        end)
        frame.directoryTabs[index]=tab
    end
    frame.agreements=frame.directoryTabs[2]
    frame.agreements.notificationBadgeInsideTab=true
    frame.directoryTabs[1]:SetChecked(true) frame.directoryTabs[2]:SetChecked(false)
    frame.directoryTab="discovery"
    frame.discoveryWidgets={frame.inset,frame.scroll,frame.header,frame.footer,frame.previous,frame.next}
end
function AF:AttachCustomerUI()
    if self.customerFrame then return end
    local frame=CreateFrame("Frame","ArtisanFinderDirectory",UIParent,"PortraitFrameTemplate")
    local screenWidth=UIParent:GetWidth()
    local panelWidth=type(screenWidth)=="number" and math.min(920,math.max(840,screenWidth-32)) or 920
    frame.discoveryWidth=panelWidth
    frame:SetSize(panelWidth,620)
    if type(screenWidth)=="number" and screenWidth>0 and screenWidth<panelWidth+24 then
        frame:SetScale((screenWidth-24)/panelWidth)
    end
    frame:SetPoint("CENTER") frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true) frame:SetMovable(true) frame:EnableMouse(true) frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(owner) if owner:IsMovable() then owner:StartMoving() end end)
    frame:SetScript("OnDragStop",function(owner) owner:StopMovingOrSizing() end)
    frame:SetTitle("ArtisanFinder")
    frame:SetPortraitToAsset("Interface\\AddOns\\"..(AF.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png")
    frame.parchment=frame:CreateTexture(nil,"BACKGROUND",nil,-7)
    frame.parchment:SetPoint("TOPLEFT",5,-22) frame.parchment:SetPoint("BOTTOMRIGHT",-5,5)
    frame.parchment:SetAtlas("Profession-Background-Template2")
    frame.inset=CreateFrame("Frame",nil,frame,"InsetFrameTemplate")
    frame.inset:SetPoint("TOPLEFT",7,-35) frame.inset:SetPoint("BOTTOMRIGHT",-7,37)
    frame.inset:EnableMouse(false)
    frame.scroll=CreateFrame("ScrollFrame",nil,frame,"ScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT",12,-40-HEADER) frame.scroll:SetPoint("BOTTOMRIGHT",-34,42)
    frame.scroll.ScrollBar:ClearAllPoints()
    frame.scroll.ScrollBar:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-12,-40-HEADER)
    frame.scroll.ScrollBar:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-12,42)
    frame.scroll.ScrollBar:SetHideIfUnscrollable(true)
    frame.content=CreateFrame("Frame",nil,frame.scroll) frame.content:SetSize(690,540) frame.scroll:SetScrollChild(frame.content)
    frame.background=frame.content:CreateTexture(nil,"BACKGROUND") frame.background:SetAllPoints()
    frame.background:SetAtlas("Professions-background-summarylist")
    frame.watermark=frame.content:CreateTexture(nil,"BACKGROUND",nil,1)
    frame.watermark:SetSize(250,250) frame.watermark:SetPoint("BOTTOMRIGHT",-24,28)
    frame.watermark:SetTexture("Interface\\AddOns\\"..(AF.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png")
    frame.watermark:SetDesaturated(true) frame.watermark:SetAlpha(.035)
    frame.header=CreateFrame("Frame",nil,frame) frame.header:SetPoint("TOPLEFT",12,-40) frame.header:SetSize(690,HEADER)
    frame.header.shade=frame.header:CreateTexture(nil,"BACKGROUND") frame.header.shade:SetAllPoints()
    frame.header.shade:SetColorTexture(.075,.047,.018,.92)
    frame.header.rule=frame.header:CreateTexture(nil,"BORDER")
    frame.header.rule:SetPoint("BOTTOMLEFT") frame.header.rule:SetPoint("BOTTOMRIGHT")
    frame.header.rule:SetHeight(1) frame.header.rule:SetColorTexture(.6,.42,.17,.7)
    frame.artisan=label(frame.header,"",12,-10,200,"GameFontNormal",GOLD)
    frame.profession=label(frame.header,"",0,-10,120,"GameFontNormal",GOLD)
    frame.discovered=label(frame.header,"",0,-10,150,"GameFontNormal",GOLD)
    frame.price=label(frame.header,"",0,-10,100,"GameFontNormal",GOLD)
    frame.observed=label(frame.header,"",0,-10,145,"GameFontNormal",GOLD)
    frame.sortHeaders={sortableHeader(frame,frame.artisan,"name"),sortableHeader(frame,frame.discovered,"source"),
        sortableHeader(frame,frame.price,"price"),sortableHeader(frame,frame.observed,"observed")}
    frame.sourceSort=frame.sortHeaders[2]
    frame.professionFilter=icon(frame.header,"atlas:ui-questtrackerbutton-filter",AF:Text("FOREVER_PROFESSION"),function(owner) AF:OpenForeverProfessionFilter(owner) end)
    frame.sourceFilter=icon(frame.header,"atlas:ui-questtrackerbutton-filter",AF:Text("FOREVER_DISCOVERED_BY"),function(owner) AF:OpenForeverSourceFilter(owner) end)
    frame.professionValue=label(frame.header,"",0,-32,130,nil,MUTED)
    frame.sourceValue=label(frame.header,"",0,-32,150,nil,MUTED)
    frame.count=label(frame.header,"",0,-32,150,nil,MUTED)
    frame.search=CreateFrame("EditBox",nil,frame.header,"SearchBoxTemplate")
    frame.item=frame.search -- One field serves text filtering and exact item queries.
    frame.search:SetPoint("TOPLEFT",12,-51) frame.search:SetSize(620,20) frame.search:SetAutoFocus(false)
    frame.search:HookScript("OnTextChanged",function()
        if not AF.settingTargetedSearch then AF.directoryTargetName=nil end
        AF.directoryPage=1
        if AF.currentCustomerItemID then AF:SelectCustomerItem(nil) else AF:RefreshCustomerResults() end
    end)
    frame.search:SetScript("OnEnterPressed",function(box) box:ClearFocus() searchItem() end)
    frame.search:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    tip(frame.search,AF:Text("FOREVER_SEARCH_ALL"),AF:Text("FOREVER_SEARCH_ALL_HELP"))
    frame.search:SetScript("OnReceiveDrag",function(box)
        local kind,id,link=GetCursorInfo()
        if kind=="item" then ClearCursor() box:SetText(link or tostring(id)) AF:SelectCustomerItem(id) end
    end)
    frame.empty=label(frame.content,"",12,-24,640,nil,MUTED)
    frame.footer=CreateFrame("Frame",nil,frame)
    frame.footer:SetPoint("BOTTOMLEFT",8,7) frame.footer:SetPoint("BOTTOMRIGHT",-8,7) frame.footer:SetHeight(28)
    frame.footer:EnableMouse(false)
    frame.status=label(frame.footer,"",0,0,320,nil,MUTED)
    frame.status:ClearAllPoints() frame.status:SetPoint("CENTER",frame.footer,"CENTER",0,0) frame.status:SetJustifyH("CENTER")
    frame.notice=label(frame.footer,"",0,0,180,nil,MUTED)
    frame.notice:ClearAllPoints() frame.notice:SetPoint("LEFT",frame.footer,"LEFT",6,0)
    local function arrow(delta,texture,key)
        local button=icon(frame,texture,AF:Text(key),function() AF.directoryPage=(AF.directoryPage or 1)+delta AF:RefreshCustomerResults() end)
        button:SetSize(24,24) button:SetPoint("CENTER",frame.footer,"CENTER",delta<0 and -180 or 180,0)
        button.art:ClearAllPoints() button.art:SetSize(12,20) button.art:SetPoint("CENTER")
        return button
    end
    frame.previous=arrow(-1,"atlas:common-icon-backarrow","FOREVER_PREVIOUS")
    frame.next=arrow(1,"atlas:common-icon-forwardarrow","FOREVER_NEXT")
    directoryTabs(frame)
    self.customerFrame,self.customerRows=frame,{}
    self:PositionForeverDirectoryTabs()
    self:ResizeForeverDirectoryHost(620)
    if self.RefreshAgreementUnreadIndicator then self:RefreshAgreementUnreadIndicator() end
    frame:SetScript("OnShow",function() AF.directoryLiveOrder=nil AF:RefreshCustomerResults() end)
    frame:SetScript("OnHide",function() AF.directoryLiveOrder=nil end)
    frame:Hide() if UISpecialFrames then table.insert(UISpecialFrames,"ArtisanFinderDirectory") end
    self:RefreshCustomerLocale()
    if self.SetupCustomerTutorialButton then self:SetupCustomerTutorialButton(frame) end
end
function AF:FocusTargetedForeverArtisan()
    if not UnitIsPlayer or UnitIsPlayer("target")~=true then return false end
    local name=self:NormalizeName(self:GetForeverUnitFullName("target"))
    if not name then return false end
    local known=false
    for _,entry in ipairs(self:GetDirectoryEntries("")) do
        if self:NormalizeName(entry.orderTarget or entry.name or entry.target)==name then known=true break end
    end
    if not known then return false end
    self.directoryTargetName=name
    self.directoryProfession,self.directorySource=nil,nil
    self.directoryExpandedArtisans=self.directoryExpandedArtisans or {}
    self.directoryExpandedArtisans[name]=true
    self.settingTargetedSearch=true
    self.customerFrame.search:SetText(name)
    self.settingTargetedSearch=nil
    self:SelectCustomerItem(nil)
    self.customerFrame.scroll:SetVerticalScroll(0)
    return true
end
function AF:OpenCustomerUI()
    self:AttachCustomerUI()
    self:SelectForeverDirectoryTab("discovery")
    self:FocusTargetedForeverArtisan()
    self.customerFrame:Show() self:RefreshCustomerQuery(false)
end
function AF:ToggleCustomerUI()
    self:AttachCustomerUI()
    if self.customerFrame.directoryTab=="agreements" then
        self:SelectForeverDirectoryTab("discovery") self.customerFrame:Show() return
    end
    if self:FocusTargetedForeverArtisan() then
        self.customerFrame:Show() self:RefreshCustomerResults()
    else self.customerFrame:SetShown(not self.customerFrame:IsShown()) end
end
function AF:RefreshCustomerLocale()
    local frame=self.customerFrame
    if not frame then
        if self.DebugLog then self:DebugLog("trade-directory", "refresh skipped: directory not created") end
        return
    end
    frame.artisan:SetText(self:Text("FOREVER_ARTISAN")) frame.profession:SetText(self:Text("FOREVER_PROFESSION"))
    frame.discovered:SetText(self:Text("FOREVER_DISCOVERED_BY")) frame.observed:SetText(self:Text("FOREVER_LAST_OBSERVED"))
    frame.price:SetText(self:Text("FOREVER_PRICE"))
end
function AF:IsCustomerLiveSearchPending()
    return self.currentCustomerItemID and self.currentCustomerQueryItemID==self.currentCustomerItemID
        and self.lastQueryAt and self:Now()-self.lastQueryAt<self.LIVE_QUERY_TIMEOUT or false
end
function AF:IsCustomerRefreshAvailable()
    return self.currentCustomerItemID~=nil and not self:IsCustomerLiveSearchPending() and self:Now()>=(self.customerRefreshCooldownUntil or 0)
end
function AF:UpdateCustomerRefreshButton()
    -- Live query cooldown remains internal; the manual refresh control is removed.
end
function AF:RefreshCustomerQuery(force)
    if self.currentCustomerItemID and force and self:IsCustomerRefreshAvailable() then
        self.customerRefreshCooldownUntil=self:Now()+5
        self:BroadcastQuery(self.currentCustomerItemID,self.currentCustomerProfessionID or 0)
        if self.InjectDebugSelfResult then self:InjectDebugSelfResult(self.currentCustomerItemID,self.currentCustomerProfessionID or 0) end
    elseif force and self.currentCustomerItemID and C_Timer and C_Timer.After then
        local item,selection=self.currentCustomerItemID,self.foreverItemSelection
        if self.queuedForeverItemSelection~=selection then
            self.queuedForeverItemSelection=selection
            local delay=math.max(.1,(self.customerRefreshCooldownUntil or 0)-self:Now())
            if self:IsCustomerLiveSearchPending() then delay=math.max(delay,self.lastQueryAt+self.LIVE_QUERY_TIMEOUT-self:Now()) end
            C_Timer.After(delay,function()
                if AF.foreverItemSelection==selection and AF.currentCustomerItemID==item then
                    AF.queuedForeverItemSelection=nil AF:RefreshCustomerQuery(true)
                end
            end)
        end
    end
    self:RefreshCustomerResults() self:UpdateCustomerRefreshButton()
end
function AF:RefreshCustomerQueryOnOpen() self:RefreshCustomerQuery(true) end
function AF:GetVisibleCustomerEntries()
    local entries={} for _,row in ipairs(self.customerRows or {}) do if row:IsShown() and row.entry then entries[#entries+1]=row.entry end end
    return entries
end
function AF:FormatForeverObservedAge(timestamp)
    if not tonumber(timestamp) or tonumber(timestamp)<=0 then return "—" end
    local minutes=math.max(0,math.floor((self:Now()-(tonumber(timestamp) or self:Now()))/60))
    if minutes==0 then return self:Text("FOREVER_JUST_NOW") end
    local units={{12*31*24*60,"FOREVER_YEARS_AGO"},{31*24*60,"FOREVER_MONTHS_AGO"},
        {24*60,"FOREVER_DAYS_AGO"},{60,"FOREVER_HOURS_AGO"},{1,"FOREVER_MINUTES_AGO"}}
    for _,unit in ipairs(units) do
        if minutes>=unit[1] then return self:Text(unit[2],math.floor(minutes/unit[1])) end
    end
end

-- Network and guild bursts share one delayed rebuild. Direct user actions stay immediate.
function AF:QueueCustomerResultsRefresh()
    if not self.customerFrame or not self.customerFrame:IsShown() or self.directoryRefreshQueued then return end
    self.directoryRefreshQueued=true
    local delay=math.max(0.2,5-(self:Now()-(self.directoryLastRefreshAt or -5)))
    C_Timer.After(delay,function()
        AF.directoryRefreshQueued=nil
        AF:RefreshCustomerResults()
    end)
end

function AF:RefreshCustomerResults(statusOverride)
    local frame=self.customerFrame if not frame or not frame:IsShown() or frame.directoryTab=="agreements" then return end
    self.directoryLastRefreshAt=self:Now()
    local build={}
    local started=debugprofilestop and debugprofilestop()
    local filter=self.currentCustomerItemID and "" or (frame.search:GetText() or "")
    local rows=self:GetForeverDirectoryRows(filter,self.directoryProfession,self.directorySource,build)
    if frame:IsShown() and self.StabilizeForeverDirectoryRows then
        local sortKey,descending=self:GetForeverDirectorySort()
        local context=table.concat({filter,tostring(self.currentCustomerItemID),tostring(self.directoryProfession),
            tostring(self.directorySource),tostring(self.directoryTargetName),sortKey,tostring(descending)},"\031")
        self:StabilizeForeverDirectoryRows(rows,context)
    end
    if self.DebugLog then self:DebugLog("trade-directory", string.format("refresh rows=%d item=%s profession=%s source=%s search=%s page=%s",
        #rows,tostring(self.currentCustomerItemID),tostring(self.directoryProfession),tostring(self.directorySource),tostring(frame.search:GetText()),tostring(self.directoryPage))) end
    local aggregated=started and debugprofilestop()
    local width,height=frame.scroll:GetWidth(),frame.scroll:GetHeight()
    if type(width)~="number" or width<300 then width=690 end
    if type(height)~="number" or height<200 then height=540 end
    local profession,source,price,observed=columns(width)
    frame.content:SetWidth(width) frame.header:SetWidth(width)
    for _,column in ipairs({{frame.profession,profession},{frame.discovered,source},{frame.price,price},{frame.observed,observed}}) do
        column[1]:ClearAllPoints() column[1]:SetPoint("TOPLEFT",column[2],-10)
    end
    frame.artisan:ClearAllPoints() frame.artisan:SetPoint("TOPLEFT",64,-10) frame.artisan:SetWidth(profession-76) frame.profession:SetWidth(source-profession-30)
    frame.discovered:SetWidth(price-source-48) frame.price:SetWidth(observed-price-12) frame.observed:SetWidth(width-observed-10)
    frame.profession:SetWidth(math.min(frame.profession:GetStringWidth() or (source-profession-30),source-profession-30))
    frame.discovered:SetWidth(math.min(frame.discovered:GetStringWidth() or (price-source-48),price-source-48))
    frame.professionFilter:ClearAllPoints() frame.professionFilter:SetPoint("LEFT",frame.profession,"RIGHT",4,0)
    frame.sourceFilter:ClearAllPoints() frame.sourceFilter:SetPoint("LEFT",frame.sourceSort,"RIGHT",4,0)
    self:RefreshForeverSortHeaders()
    frame.professionValue:ClearAllPoints() frame.professionValue:SetPoint("TOPLEFT",profession,-32)
    frame.sourceValue:ClearAllPoints() frame.sourceValue:SetPoint("TOPLEFT",source,-32)
    frame.count:ClearAllPoints() frame.count:SetPoint("TOPLEFT",observed,-32)
    frame.professionValue:SetText(self.directoryProfession and self:GetProfessionName(self.directoryProfession) or self:Text("FOREVER_ALL"))
    frame.sourceValue:SetText(self.directorySource and sourceText(self.directorySource) or self:Text("FOREVER_ALL"))
    frame.count:SetText(self:Text("FOREVER_ARTISAN_COUNT",#rows))
    for _,control in ipairs({{frame.professionFilter,frame.professionValue,self.directoryProfession},
        {frame.sourceFilter,frame.sourceValue,self.directorySource}}) do
        local active=control[3]~=nil
        control[1].art:SetDesaturated(not active)
        control[1]:SetAlpha(active and 1 or .65)
        control[2]:SetTextColor(unpack(active and GOLD or MUTED))
    end
    frame.search:SetWidth(width-24)
    frame.empty:SetShown(#rows==0) frame.empty:SetText(self:Text("FOREVER_DIRECTORY_EMPTY"))
    local pages=math.max(1,math.ceil(#rows/PAGE))
    self.directoryPage=math.max(1,math.min(pages,self.directoryPage or 1))
    local first=(self.directoryPage-1)*PAGE+1
    local last=math.min(first+PAGE-1,#rows)
    local baseRowHeight=math.max(28,math.floor((height-28)/PAGE))
    local expandedRows=self:BuildForeverExpandedRows(rows,first,last,filter,build)
    local rowOffset=0
    local visible=0
    for index,view in ipairs(expandedRows) do
        visible=visible+1 local group=view.group
        local professionIDs=view.kind=="artisan" and sortedIDs(group.professions) or {}
        local iconLines=math.max(1,math.ceil(#professionIDs/6))
        local rowHeight=baseRowHeight*iconLines
        local row=self.customerRows[visible]
        if not row then row=createRow(frame.content) self.customerRows[visible]=row end
        local keepHover=row.hovered and type(row.view)=="table" and type(row.group)=="table"
            and type(row.entry)=="table" and type(group.entry)=="table"
            and row.view.kind==view.kind and row.group.name==group.name
            and row.view.professionID==view.professionID and row.entry.itemID==group.entry.itemID
        row.group,row.entry,row.view=group,group.entry,view row:ClearAllPoints() row:SetPoint("TOPLEFT",0,-rowOffset)
        rowOffset=rowOffset+rowHeight
        row:SetSize(width,rowHeight)
        if view.kind=="artisan" then
            row.shade:SetColorTexture(.12,.08,.025,index%2==0 and .8 or .58)
            row.rule:SetColorTexture(.52,.36,.14,.3)
        elseif view.kind=="profession" then
            row.shade:SetColorTexture(.31,.21,.065,.36)
            row.rule:SetColorTexture(.52,.36,.14,.2)
        else
            row.shade:SetColorTexture(.08,.06,.025,index%2==0 and .28 or .12)
            row.rule:SetColorTexture(.52,.36,.14,.09)
        end
        local y=-math.floor((rowHeight-ROW_FONT_SIZE)/2)
        for _,cell in ipairs({{row.name,12,profession-24},{row.professions,profession,source-profession-10},{row.source,source,price-source-10},{row.price,price,observed-price-12},{row.updatedAt,observed,math.max(40,width-observed-108)}}) do
            cell[1]:ClearAllPoints() cell[1]:SetPoint("TOPLEFT",cell[2],y) cell[1]:SetWidth(cell[3])
        end
        local depth=view.kind=="artisan" and 0 or (view.kind=="profession" and 1 or 2)
        local expandable=view.kind=="artisan" or view.kind=="profession"
        row.chevron:ClearAllPoints() row.chevron:SetPoint("LEFT",row,"LEFT",10+depth*18,0)
        row.chevron:SetRotation(view.expanded and -math.pi/2 or 0) row.chevron:SetShown(expandable)
        row.name:ClearAllPoints() row.name:SetPoint("TOPLEFT",26+depth*18,y)
        row.name:SetWidth((depth==2 and source or profession)-38-depth*18)
        local title=view.label or (view.kind=="profession" and self:GetForeverProfessionLabel(group,view.professionID) or self:GetDisplayPlayerName(group.name))
        row.itemIcon:SetShown(view.kind=="craft") row.itemLink:SetShown(view.kind=="craft")
        row.track:SetShown(view.kind=="craft")
        row.request:SetShown(view.kind=="craft" and AF.GetAgreementInputFromCraft and AF:GetAgreementInputFromCraft(view.artisanGroup or group,group.entry)~=nil)
        row.actions:ClearAllPoints()
        row.actions:SetPoint("RIGHT",view.kind=="craft" and row.request or row.star,"LEFT",-3,0)
        row.craftLink,row.craftPayload=nil,nil
        if view.kind=="craft" then
            local texture
            row.craftLink,texture,row.craftPayload=self:GetForeverCraftPresentation(row.entry)
            row.itemIcon:SetTexture(texture)
            row.name:ClearAllPoints() row.name:SetPoint("TOPLEFT",72,y) row.name:SetWidth(source-84)
            title=row.craftLink
        end
        local completed,personal
        if view.kind=="artisan" and self.GetForeverGroupAgreementCounts then completed,personal=self:GetForeverGroupAgreementCounts(group) end
        local showCompleted=completed~=nil or (personal or 0)>0
        row.completed:SetShown(showCompleted) row.completedTip:SetShown(showCompleted)
        if showCompleted then
            row.name:ClearAllPoints() row.name:SetPoint("TOPLEFT",26,-math.max(1,math.floor((rowHeight-28)/2)))
            row.completed:ClearAllPoints() row.completed:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-1)
            row.completed:SetWidth(profession-38)
            row.completed:SetText(completed~=nil and self:Text("FOREVER_COMPLETED_COUNTS",completed,personal or 0)
                or self:Text("FOREVER_COMPLETED_PERSONAL",personal))
        end
        row.name:SetText(title)
        row.name:SetTextColor(unpack(view.kind=="profession" and GOLD or (view.kind=="artisan" and {1,.96,.85} or {.86,.83,.75})))
        local priceContext
        if view.kind=="profession" then priceContext=false elseif view.kind=="craft" then priceContext=row.entry.itemID end
        row.priceText,row.priceDetails=self:GetForeverDirectoryPrice(group,priceContext)
        row.price:SetText(row.priceText)
        row.price:SetJustifyH("RIGHT")
        row.price:SetTextColor(unpack(#row.priceDetails>0 and {.95,.85,.6} or MUTED))
        row.professions:ClearAllPoints() row.professions:SetPoint("TOPLEFT",profession,-math.floor((rowHeight-ROW_PROFESSION_ICON_SIZE)/2))
        row.source:SetText(view.kind=="artisan" and sourceText(group.source) or "")
        local crafterName=view.kind=="profession" and self:NormalizeName(group.entry.orderTarget or group.entry.name or group.entry.target)
        local altName=crafterName and crafterName~=self:NormalizeName(group.name) and crafterName
        row.professions:SetText(altName and ("("..self:GetDisplayPlayerName(altName)..")") or "")
        row.professions:ClearAllPoints()
        row.professions:SetPoint("LEFT",row,"LEFT",profession,0)
        row.professions:SetWidth(source-profession-10)
        for professionIndex=1,#professionIDs do
            local button=row.professionButtons[professionIndex]
            if not button then
                button=CreateFrame("Button",nil,row)
                row.professionButtons[professionIndex]=button
                button.art=button:CreateTexture(nil,"ARTWORK")
                button.art:SetAllPoints(button)
                button:SetSize(ROW_PROFESSION_ICON_SIZE,ROW_PROFESSION_ICON_SIZE)
                button:SetFrameLevel(row.actions:GetFrameLevel()+1)
                button:SetScript("OnClick",function(owner)
                    local name=row.group.name
                    AF.directoryExpandedArtisans=AF.directoryExpandedArtisans or {}
                    AF.directoryExpandedProfessions=AF.directoryExpandedProfessions or {}
                    AF.directoryExpandedArtisans[name]=true
                    AF.directoryExpandedProfessions[name..":"..owner.professionID]=true
                    AF:RefreshCustomerResults()
                end)
                button:SetScript("OnEnter",function(owner)
                    updateRowActions(row,true)
                    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
                    GameTooltip:SetText(AF:GetForeverProfessionLabel(row.group,owner.professionID),1,.82,.35)
                    GameTooltip:Show()
                end)
                button:SetScript("OnLeave",function() GameTooltip:Hide() deferRowLeave(row) end)
            end
            button.professionID=professionIDs[professionIndex]
            local markup=AF:GetProfessionIconMarkup(button.professionID,nil,ROW_PROFESSION_ICON_SIZE) or ""
            local texture=markup:match("|T([^:]+)")
            button.art:SetTexture(tonumber(texture) or texture or 134400)
            button:ClearAllPoints()
            button:SetPoint("LEFT",row,"LEFT",profession+((professionIndex-1)%6)*(ROW_PROFESSION_ICON_SIZE+4),(iconLines-1)*baseRowHeight/2-math.floor((professionIndex-1)/6)*baseRowHeight)
            button:Show()
        end
        for professionIndex=#professionIDs+1,#row.professionButtons do row.professionButtons[professionIndex]:Hide() end
        row.source:SetTextColor(unpack(MUTED))
        local observedAge=self:FormatForeverObservedAge(group.updatedAt)
        local lifetime=group.source=="TRADE" and (tonumber(self.db.tradeLeadMinutes) or 15)*60 or 300
        local historical=group.updatedAt>0 and not group.entry.ownAlt and self:Now()-group.updatedAt>lifetime
        row.updatedAt:SetText(view.kind=="artisan" and (observedAge..(historical and ("\n"..self:Text("FOREVER_HISTORICAL")) or "")) or "")
        if view.kind=="empty" then row.price:SetText("") end
        row.updatedAt:ClearAllPoints()
        row.updatedAt:SetPoint("LEFT",row,"LEFT",observed,0)
        row.updatedAt:SetHeight(rowHeight)
        row.updatedAt:SetJustifyV("MIDDLE")
        updateRowActions(row,keepHover or rowIsHovered(row))
        if keepHover then deferRowLeave(row) end
        local hasProfessionLink=#self:GetOpenableForeverProfessions(group)>0
        row.link:SetEnabled(hasProfessionLink) row.link:SetShown(hasProfessionLink)
        row.action:SetEnabled(not group.entry.ownAlt)
        row.star.art:SetDesaturated(not self:IsFavoriteArtisan(group.entry)) row.star:SetShown(view.kind=="artisan") row:Show()
    end
    frame.content:SetSize(width,math.max(height,rowOffset+28))
    for i=visible+1,#self.customerRows do
        local row=self.customerRows[i]
        row.hovered=false row.actions:Hide() row:Hide()
        row.entry=nil row.group=nil row.view=nil
    end
    frame.previous:SetEnabled(self.directoryPage>1) frame.next:SetEnabled(self.directoryPage<pages)
    frame.previous:SetAlpha(self.directoryPage>1 and 1 or .35) frame.next:SetAlpha(self.directoryPage<pages and 1 or .35)
    frame.status:SetWidth(320)
    frame.notice:SetWidth(math.max(100,(width-400)/2))
    frame.status:SetText(self:Text("FOREVER_PAGE",self.directoryPage,pages,#rows))
    if statusOverride then frame.notice:SetText(statusOverride)
    elseif self.currentCustomerItemID then frame.notice:SetText(self:GetDisplayItemName(self.currentCustomerItemID))
    else frame.notice:SetText("") end
    self:UpdateCustomerRefreshButton()
    if started and self.DebugLog then
        local finished=debugprofilestop()
        self:DebugLog("directory-performance",string.format("aggregate=%.2fms render=%.2fms artisans=%d rows=%d",
            aggregated-started,finished-aggregated,#rows,visible))
    end
end
function AF:ShowCustomerMenu(entry) if entry and not entry.ownAlt then ChatFrame_SendTell(entry.target or entry.name) end end
function AF:HideCustomerMenu() end
function AF:QueueCustomerSidePanelLayout() end
function AF:PositionCustomerSidePanels() end
function AF:CanReliablyOpenProfession(entry)
    if not entry or entry.ownAlt then return false end
    local link=entry.professionLink or self:GetRememberedProfessionLink(entry.orderTarget or entry.name,entry.professionID)
    return type(link)=="string" and link~=""
end
function AF:GetOpenableForeverProfessions(group)
    local entries,seen={},{}
    for _,entry in ipairs(group.offers or {group.entry}) do
        if not seen[entry.professionID] and self:CanReliablyOpenProfession(entry) then
            seen[entry.professionID]=true
            entries[#entries+1]=entry
        end
    end
    table.sort(entries,function(a,b) return (tonumber(a.professionID) or 0)<(tonumber(b.professionID) or 0) end)
    return entries
end
function AF:GetProfessionOpenGuildGUID(entry)
	if entry and entry.guildMember and self.GetGuildMemberGUID then return self:GetGuildMemberGUID(entry.name) end
end

