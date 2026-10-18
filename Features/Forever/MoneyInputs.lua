local _, AF = ...

function AF:ParseForeverCoinFields(gold,silver,copper)
    gold,silver,copper=tostring(gold or ""),tostring(silver or ""),tostring(copper or "")
    if gold=="-1" and (silver=="" or silver=="0") and (copper=="" or copper=="0") then return 0,true,"free" end
    for _,text in ipairs({gold,silver,copper}) do if text~="" and not text:match("^%d+$") then return nil end end
    local g,s,c=tonumber(gold) or 0,tonumber(silver) or 0,tonumber(copper) or 0
    if s>99 or c>99 then return nil end
    local amount=g*10000+s*100+c
    if amount>self.MAX_COMMISSION_COPPER then return nil end
    return amount,false,amount>0 and "paid" or "unspecified"
end

function AF:InstallForeverMoneyInput(panel)
    local backing=panel and panel.price
    if not backing or backing.foreverCoins then return end
    local field=backing.Field
    field.Background:Hide()
    field.NineSlice:Hide()
    local coins={}
    backing.foreverCoins=coins
    backing:SetAlpha(0) backing:EnableMouse(false) backing:SetMaxLetters(32)
    backing.Placeholder:SetAlpha(0) backing.GoldIcon:SetAlpha(0)
    local updating=false
    local function sync()
        if updating then return end
        local amount,free,state=AF:NormalizeCommissionInput(backing:GetText())
        if amount==nil then return end
        updating=true
        local g=math.floor(amount/10000)
        local s=math.floor(amount/100)%100
        local c=amount%100
        coins[1]:SetText(free and "-1" or (state=="unspecified" and "" or tostring(g)))
        coins[2]:SetText((state=="unspecified" or free) and "" or tostring(s))
        coins[3]:SetText((state=="unspecified" or free) and "" or tostring(c))
        updating=false
    end
    local function changed(_,userInput)
        if updating or not userInput then return end
        local amount,free=AF:ParseForeverCoinFields(coins[1]:GetText(),coins[2]:GetText(),coins[3]:GetText())
        local text=amount and (free and "-1" or (amount==0 and "" or AF:GetCommissionInputText(amount,false))) or "invalid"
        if backing:GetText()==text then return end
        updating=true backing:SetText(text) updating=false
    end
    local names={"GOLD","SILVER","COPPER"}
    local textures={"coin-gold","coin-silver","coin-copper"}
    for index=1,3 do
        local box=CreateFrame("EditBox",nil,field,"LargeInputBoxTemplate")
        coins[index]=box
        box:SetAutoFocus(false) box:SetFontObject("PriceFont") box:SetJustifyH("RIGHT")
        box:SetTextInsets(8,24,0,0)
        box:SetHeight(33) box:SetMaxLetters(index==1 and 8 or 2)
        if index~=1 then box:SetNumeric(true) end
        box:SetScript("OnTextChanged",changed)
        box:SetScript("OnEnterPressed",function(owner)
            owner:ClearFocus()
            local handler=backing:GetScript("OnEnterPressed")
            if handler then handler(backing) end
        end)
        box:SetScript("OnEscapePressed",function(owner) owner:ClearFocus() end)
        box:SetScript("OnTabPressed",function(owner)
            owner:ClearFocus()
            local target=index+(IsShiftKeyDown() and -1 or 1)
            if coins[target] then coins[target]:SetFocus() coins[target]:HighlightText() else panel.note:SetFocus() end
        end)
        box:SetScript("OnEnter",function(owner)
            GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
            GameTooltip:SetText(AF:Text("FOREVER_COIN_"..names[index]),1,.82,.35)
            GameTooltip:AddLine(AF:Text("FOREVER_COIN_HELP"),1,1,1,true) GameTooltip:Show()
        end)
        box:SetScript("OnLeave",function() GameTooltip:Hide() end)
        box.coin=box:CreateTexture(nil,"ARTWORK")
        box.coin:SetSize(14,16) box.coin:SetAtlas(textures[index])
    end
    local function layout()
        local width=math.max(184,field:GetWidth())
        local goldWidth=width-128
        for index,box in ipairs(coins) do
            box:ClearAllPoints()
            if index==1 then box:SetPoint("LEFT",field,"LEFT",0,0)
            else box:SetPoint("LEFT",coins[index-1],"RIGHT",6,0) end
            box:SetWidth(index==1 and goldWidth or 58)
            box.coin:ClearAllPoints() box.coin:SetPoint("RIGHT",box,"RIGHT",-8,0)
        end
    end
    field:HookScript("OnSizeChanged",layout)
    backing.foreverSyncCoins=sync
    backing:HookScript("OnTextChanged",sync)
    field:HookScript("OnShow",sync)
    layout() sync()
end

-- A panel refresh can load saved values before the visible coin fields exist,
-- or reuse an unchanged backing value without firing OnTextChanged.
function AF:SyncCrafterPanelInputs()
    for _,panel in ipairs({self.crafterDefaultsFrame,self.crafterFrame}) do
        if panel.price and panel.price.foreverSyncCoins then panel.price.foreverSyncCoins() end
    end
end
