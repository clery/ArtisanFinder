local AF={}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Flavors/Forever.lua") load("Core/Bootstrap.lua") load("Utils/Formatting.lua")
AF.AttachCrafterUI=function() end
AF.RefreshCrafterUI=function(self)
    if self.loadCommission then self.crafterDefaultsFrame.price.text=self.loadCommission end
end
load("Features/Forever/MoneyInputs.lua")
local function object()
    local o={text="",scripts={},hooks={},width=232}
    function o:SetScript(key,fn) self.scripts[key]=fn end
    function o:GetScript(key) return self.scripts[key] end
    function o:HookScript(key,fn) self.hooks[key]=self.hooks[key] or {} table.insert(self.hooks[key],fn) end
    function o:SetText(text,userInput)
        assert(type(text)=="string") self.text=text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,userInput==true) end
        for _,fn in ipairs(self.hooks.OnTextChanged or {}) do fn(self) end
    end
    function o:GetText() return self.text end
    function o:GetWidth() return self.width end
    function o:SetWidth(width) self.width=width end
    function o:CreateTexture() return object() end
    setmetatable(o,{__index=function(_,key) if key=="foreverCoins" then return nil end return function() end end})
    return o
end
CreateFrame=function(_,_,_,template) local box=object() box.template=template return box end
GameFontHighlightSmall={}
local backing=object() backing.Field=object() backing.Field.Background=object() backing.Field.NineSlice=object() backing.Placeholder=object() backing.GoldIcon=object()
local panel={price=backing,note=object()}
local edits=0 backing:SetScript("OnTextChanged",function() edits=edits+1 end)
backing:SetText("1.2345")
AF:InstallForeverMoneyInput(panel)
local coins=backing.foreverCoins
assert(coins[1].template=="LargeInputBoxTemplate" and coins[2]:GetWidth()==58 and coins[3]:GetWidth()==58,"auction house borders and denomination widths")
assert(coins[1]:GetWidth()==104,"gold uses the remaining width with six-pixel gaps")
assert(coins[1]:GetText()=="1" and coins[2]:GetText()=="23" and coins[3]:GetText()=="45","saved copper splits into denominations")
coins[1]:SetText("",true) coins[2]:SetText("",true) coins[3]:SetText("1",true)
assert(AF:NormalizeCommissionInput(backing:GetText())==1,"one copper remains exact")
coins[2]:SetText("12",true) coins[3]:SetText("34",true)
assert(AF:NormalizeCommissionInput(backing:GetText())==1234,"silver/copper input avoids fractional-gold rounding")
local saved={}
backing:SetScript("OnEnterPressed",function(box)
    local copper,free,state=AF:NormalizeCommissionInput(box:GetText())
    AF:SetCommissionFields(saved,copper,free,state)
    box:SetText(AF:FormatCommissionInput(saved))
end)
coins[3].scripts.OnEnterPressed(coins[3])
assert(saved.priceCopper==1234 and saved.commissionSpecified,"existing save flow receives copper")
backing:SetText("0.0002")
assert(coins[1]:GetText()=="0" and coins[2]:GetText()=="0" and coins[3]:GetText()=="2","discard/recipe switch updates visible coin inputs")
backing:SetText("-1")
assert(coins[1]:GetText()=="-1" and coins[2]:GetText()=="" and coins[3]:GetText()=="","any-commission remains supported")
backing:SetText("")
assert(coins[1]:GetText()=="" and coins[2]:GetText()=="" and coins[3]:GetText()=="","unspecified does not become a free quote")
assert(not AF:ParseForeverCoinFields("1.5","0","0"))
assert(not AF:ParseForeverCoinFields("0","100","0"))
assert(not AF:ParseForeverCoinFields("0","0","100"))
assert(not AF:ParseForeverCoinFields("-1","1","0"))
assert(not AF:ParseForeverCoinFields("999999999","0","0"))
local zero,free,state=AF:ParseForeverCoinFields("0","0","0")
assert(zero==0 and free==false and state=="unspecified")
local previous=backing.foreverCoins AF:InstallForeverMoneyInput(panel)
assert(backing.foreverCoins==previous,"reattaching does not duplicate inputs")
assert(edits>0,"visible edits use the existing dirty-state event path")
print("PASS Forever coin inputs: exact copper/silver/gold, save/load/discard, any/unspecified, validation and reuse")

AF.crafterDefaultsFrame=panel
AF.loadCommission="0.1299"
AF:RefreshCrafterUI() AF:SyncCrafterPanelInputs()
assert(coins[1]:GetText()=="0" and coins[2]:GetText()=="12" and coins[3]:GetText()=="99","refresh restores saved commission even without a backing text-change event")
coins[2]:SetText("34",true)
AF.loadCommission=nil
AF:RefreshCrafterUI() AF:SyncCrafterPanelInputs()
assert(coins[2]:GetText()=="34" and coins[3]:GetText()=="99","refresh preserves current unsaved coin edits")
coins[3].text=""
backing.Field.hooks.OnShow[1]()
assert(coins[3]:GetText()=="99","showing a previously hidden panel restores visible denominations")
print("PASS saved commissions restore on panel refresh/show and preserve unsaved edits")

local beforeEdits=edits
local restored=backing:GetText()
backing.foreverSyncCoins()
for _,box in ipairs(coins) do box.scripts.OnTextChanged(box,false) end
assert(edits==beforeEdits and backing:GetText()==restored,"programmatic or delayed coin changes do not mark restored commission dirty")
coins[3]:SetText(coins[3]:GetText(),true)
assert(edits==beforeEdits,"unchanged amount does not emit a dirty-state change")
print("PASS restored prices stay clean; only actual user price changes mark edits")
