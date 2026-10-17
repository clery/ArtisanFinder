local AF={db={}}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
GetLocale=function() return "enUS" end
load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
AF.Text=function(_,key) return AF.Locales.enUS[key] or key end
local pending={}
C_Timer={After=function(delay,callback) pending[#pending+1]={delay=delay,callback=callback} end}
local function flush()
    local work=pending pending={}
    for _,entry in ipairs(work) do entry.callback() end
end
local function frame(left,top,width,height)
    local f={shown=true,scripts={},hooks={},left=left or 400,top=top or 700,width=width or 80,height=height or 24}
    function f:ClearAllPoints() self.point=nil end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return 1 end
    function f:GetFrameLevel() return 1 end
    function f:GetFrameStrata() return "MEDIUM" end
    function f:IsShown() return self.shown end
    function f:SetScale(value) self.scale=value end
    function f:SetSize(w,h) self.width=w self.height=h end
    function f:SetPoint(...) self.point={...} end
    function f:SetText(text) self.text=text end
    function f:SetFrameStrata(value) self.strata=value end
    function f:SetScript(event,callback) self.scripts[event]=callback end
    function f:HookScript(event,callback) self.hooks[event]=callback end
    function f:Show()
        local changed=not self.shown self.shown=true
        if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
        if changed and self.hooks.OnShow then self.hooks.OnShow(self) end
    end
    function f:Hide()
        local changed=self.shown self.shown=false
        if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
        if changed and self.hooks.OnHide then self.hooks.OnHide(self) end
    end
    function f:Click() self.scripts.OnClick(self) end
    for _,method in ipairs({"SetHitRectInsets","SetFrameLevel","SetToplevel","EnableMouse"}) do f[method]=function() end end
    return f
end
UIParent=frame(0,900,1400,900)
CreateFrame=function(_,_,parent,template)
    local button=frame()
    if template=="MainHelpPlateButton" then
        button:SetScript("OnShow",function(self) self:Hide() end)
        button:Hide() -- The actual Camelot template self-hides on creation/show.
    end
    return button
end
HelpPlateCanvas=frame()
HelpPlateCanvas.GetChildren=function() end
local current
HelpPlate={Show=function(info) current=info end,Hide=function() current=nil end,
    IsShowingHelpInfo=function(info) return info==current end}
load("UI/Tutorial.lua") load("Features/Forever/Tutorial.lua")
AF:InitializeTutorial()
AF.Print=function() end
AF.ApplyCrafterDefaultsCollapsed=function() end AF.PositionCrafterUI=function() end
local crafter=frame(700,800,392,500)
for _,name in ipairs({"defaultsHeader","priceField","noteField","save","scanHeader","forceRescanButton","advertisingHeader","advertiseCheck"}) do crafter[name]=frame() end
crafter.advertiseCheck.Text=frame()
AF.crafterDefaultsFrame=crafter AF:SetupCrafterTutorialButton(crafter)
assert(AF.crafterTutorialButton:IsShown() and not AF.crafterTutorialButton.scripts.OnShow,
    "crafter information icon overrides Camelot template self-hiding")
AF:ShowCrafterTutorial(false)
assert(current and AF.activeTutorialKind=="crafter" and AF.crafterTutorialButton.tooltipText==AF:Text("FOREVER_TUTORIAL_END_HINT"))
AF.crafterTutorialButton:Click()
assert(not current and not AF.tutorialEndButton and AF.db.tutorial.crafterSeen,
    "end button closes crafter help and marks it seen")
assert(crafter:IsShown(),"ending the tutorial never closes the crafting sidebar")
flush()
assert(not current,"stale help-plate watchers cannot reopen a finished guide")

local directory=frame(150,800,840,620)
for _,name in ipairs({"search","artisan","profession","discovered","price","observed","professionFilter","sourceFilter","scroll","previous","status","next"}) do directory[name]=frame() end
AF.customerFrame=directory AF.customerRows={}
directory:Hide()
AF:SetupCustomerTutorialButton(directory)
assert(AF.customerTutorialButton:IsShown() and not AF.customerTutorialButton.scripts.OnShow,
    "discovery information icon overrides Camelot template self-hiding")
AF.customerTutorialButton:Hide() AF.customerTutorialButton:Show()
assert(AF.customerTutorialButton:IsShown(),"reopening a panel cannot hide its information icon")
directory:Show() flush()
assert(current and #current==4 and AF.activeTutorialKind=="discovery",
    "first opening shows search, header, table and pagination help even with an empty directory")
assert(AF.customerTutorialButton.tooltipText==AF:Text("FOREVER_TUTORIAL_END_HINT"),
    "discovery provides both an information icon and an end button")
AF.customerTutorialButton:Click()
assert(directory:IsShown() and AF.db.tutorial.discoverySeen and not current,
    "ending discovery help keeps the panel open and remembers completion")
directory:Hide() directory:Show() flush()
assert(not current,"completed guide does not reopen automatically")
AF.customerTutorialButton:Click()
assert(current and AF.activeTutorialKind=="discovery","information icon reopens completed guide")
AF.customerTutorialButton:Click()
assert(not current and not AF.tutorialEndButton,"information icon also ends the guide")
AF.customerTutorialButton:Click()
AF:ShowCrafterTutorial(false)
assert(current and AF.activeTutorialKind=="crafter","tutorial ownership switches cleanly between panels")
crafter:Hide()
assert(not current and not AF.tutorialEndButton,"closing the owner removes its help and end button")
AF.customerTutorialButton:Click()
directory:Hide()
assert(not current and not AF.tutorialEndButton,"closing discovery cleans up its tutorial")
directory:Show() AF.customerTutorialButton:Click()
HelpPlate.Hide() flush()
assert(not AF.activeTutorialKind and not AF.tutorialEndButton,"external help-plate dismissal cleans up end controls")
AF:ResetTutorial() flush()
assert(current and AF.activeTutorialKind=="discovery","reset replays the guide for an open panel")
AF:EndForeverTutorial()
AF.db.tutorial.discoverySeen=nil AF:MaybeShowDiscoveryTutorial() directory:Hide() flush()
assert(not current,"queued first-use help cannot open after its panel closes")
AF.crafterTutorialButton=nil
AF.customerTutorialButton.tooltipText="old"
AF:RefreshTutorialLocale()
assert(AF.customerTutorialButton.tooltipText==AF:Text("TUTORIAL_HELP_BUTTON_TOOLTIP"),
    "locale refresh supports discovery without a crafting panel")
assert(not AF.tutorialEndButton,"standalone end button is removed")
assert(AF.customerTutorialButton.scale==.55 and crafter.tutorialButton.scale==.55,"both information buttons use a readable size")
assert(AF.customerTutorialButton.point[4]==-60 and AF.customerTutorialButton.point[5]==12,"information icon leaves clearance from the close button")
AF.db.tutorial.discoverySeen=true directory:Show()
AF.customerTutorialButton:Click()
assert(AF.customerTutorialButton.strata=="FULLSCREEN_DIALOG","active information icon stays above the help overlay")
GameTooltip={SetOwner=function() end,SetText=function(_,text) AF.tooltip=text end,Show=function() end}
AF.customerTutorialButton.scripts.OnEnter(AF.customerTutorialButton)
assert(AF.tooltip==AF:Text("FOREVER_TUTORIAL_END_HINT"),"hover explains how to end the active tutorial")
AF.customerTutorialButton:Click()
assert(AF.customerTutorialButton.strata=="DIALOG" and AF.customerTutorialButton.tooltipText==AF:Text("TUTORIAL_HELP_BUTTON_TOOLTIP"),"ending help restores the normal icon state")
print("PASS information-icon placement, layering, end hints, guide toggles, replay and cleanup")
