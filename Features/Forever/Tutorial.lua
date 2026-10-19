local _, AF = ...
local H=AF.TutorialHelpers

function AF:GetTutorialHelpButtonText(button)
    return self:Text(self.activeTutorialKind==button.tutorialKind and "FOREVER_TUTORIAL_END_HINT" or "TUTORIAL_HELP_BUTTON_TOOLTIP")
end
function AF:ConfigureTutorialButton(button,parent,kind)
    button.tutorialKind=kind
    -- Camelot's MainHelpPlateButton template hides itself in OnShow.
    -- These addon-owned buttons must remain available to reopen/end help.
    button:SetScript("OnShow",nil)
    button:Show()
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-60,12)
    button:SetScale(.55)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(parent:GetFrameLevel()+600)
end
function AF:RefreshTutorialButtons()
    for _,button in pairs({self.crafterTutorialButton,self.customerTutorialButton}) do
        local text=self:GetTutorialHelpButtonText(button)
        button.mainHelpPlateButtonTooltipText=text
        button.tooltipText=text
        button:SetFrameStrata(self.activeTutorialKind==button.tutorialKind and "FULLSCREEN_DIALOG" or "DIALOG")
    end
end
function AF:EndForeverTutorial()
    local kind=self.activeTutorialKind
    self.db.tutorial=self.db.tutorial or {}
    if kind=="crafter" then self.db.tutorial.crafterSeen=true end
    if kind=="discovery" then self.db.tutorial.discoverySeen=true end
    H.StopActiveTutorial()
end
function AF:RefreshTutorialLocale() self:RefreshTutorialButtons() end
function AF:InitializeTutorial() self.db.tutorial=self.db.tutorial or {} end
function AF:CloseIntroTutorial() end
function AF:IsIntroTutorialActive() return false end
function AF:IsMinimapTutorialActive() return false end
function AF:CloseMinimapTutorial() end
function AF:MaybeShowMinimapTutorial() end

function AF:BeginForeverTutorial(kind,info,button,_)
    if not info then return end
    self:EndForeverTutorial()
    self.activeTutorialKind=kind
    self.activeTutorialHelpPlateInfo=info
    self.crafterTutorialShowing=kind=="crafter" or nil
    self.discoveryTutorialShowing=kind=="discovery" or nil
    self:RefreshTutorialButtons()
    if HelpPlate.ShowTutorialTooltip then HelpPlate.ShowTutorialTooltip(info,button) end
    HelpPlate.Show(info,UIParent,button)
    H.MakeHelpPlateClickThrough(info)
    H.WatchHelpPlateClosed(info,function()
        if AF.activeTutorialKind==kind then AF:EndForeverTutorial() end
    end)
end
function AF:ShowCrafterTutorial(initial)
    if not H.EnsureHelpPlate() or not self.crafterDefaultsFrame or not self.crafterTutorialButton then return end
    if H.IsActiveHelpPlateShowing("crafter") then self:EndForeverTutorial() return end
    self:ApplyCrafterDefaultsCollapsed(false)
    self:PositionCrafterUI()
    self:BeginForeverTutorial("crafter",self:BuildCrafterHelpPlateInfo(),self.crafterTutorialButton,initial)
end
function AF:BuildDiscoveryHelpPlateInfo()
    local frame=self.customerFrame
    if not frame or not frame:IsShown() then return end
    local info={FramePos={x=0,y=0},FrameSize={width=UIParent:GetWidth(),height=UIParent:GetHeight()}}
    H.AddHelpPlateTile(info,UIParent,self:Text("FOREVER_TUTORIAL_SEARCH"),nil,frame.search)
    H.AddHelpPlateTile(info,UIParent,self:Text("FOREVER_TUTORIAL_HEADERS"),nil,
        frame.artisan,frame.profession,frame.discovered,frame.price,frame.observed,frame.professionFilter,frame.sourceFilter)
    H.AddHelpPlateTile(info,UIParent,self:Text("FOREVER_TUTORIAL_ROWS"),nil,frame.scroll)
    H.AddHelpPlateTile(info,UIParent,self:Text("FOREVER_TUTORIAL_PAGES"),nil,frame.previous,frame.status,frame.next)
    return #info>0 and info or nil
end
function AF:ShowDiscoveryTutorial(initial)
    if self.customerFrame and self.customerFrame.directoryTab=="agreements" then return end
    if not H.EnsureHelpPlate() or not self.customerFrame or not self.customerTutorialButton then return end
    if H.IsActiveHelpPlateShowing("discovery") then self:EndForeverTutorial() return end
    self:BeginForeverTutorial("discovery",self:BuildDiscoveryHelpPlateInfo(),self.customerTutorialButton,initial)
end
local function queueInitial(kind,parent,seenKey,queueKey)
    local tutorial=AF.db and AF.db.tutorial
    if not tutorial or tutorial[seenKey] or AF[queueKey] or AF.activeTutorialKind then return end
    AF[queueKey]=true
    C_Timer.After(.2,function()
        AF[queueKey]=nil
        if not AF.db.tutorial[seenKey] and not AF.activeTutorialKind and parent and parent:IsShown() then
            if kind=="crafter" then AF:ShowCrafterTutorial(true) else AF:ShowDiscoveryTutorial(true) end
        end
    end)
end
function AF:MaybeShowCrafterTutorial()
    queueInitial("crafter",self.crafterDefaultsFrame,"crafterSeen","crafterTutorialInitialQueued")
end
function AF:MaybeShowDiscoveryTutorial()
    queueInitial("discovery",self.customerFrame,"discoverySeen","discoveryTutorialInitialQueued")
end
function AF:SetupCustomerTutorialButton(frame)
    if frame.tutorialButton then return end
    local button=H.CreateTutorialButton(frame,"TOPRIGHT",frame,"TOPRIGHT",-30,0)
    self:ConfigureTutorialButton(button,frame,"discovery")
    button:SetScript("OnClick",function() AF:ShowDiscoveryTutorial(false) end)
    frame.tutorialButton=button
    self.customerTutorialButton=button
    H.AddFrameHideCleanup(frame,function()
        if AF.activeTutorialKind=="discovery" then AF:EndForeverTutorial() end
    end)
    frame:HookScript("OnShow",function() AF:MaybeShowDiscoveryTutorial() end)
end
function AF:ResetTutorial()
    self:EndForeverTutorial()
    self.db.tutorial={}
    self:Print(self:Text("FOREVER_TUTORIAL_RESET"))
    if self.customerFrame and self.customerFrame:IsShown() then self:MaybeShowDiscoveryTutorial()
    else self:MaybeShowCrafterTutorial() end
end
