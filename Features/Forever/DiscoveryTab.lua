local _, AF = ...

function AF:PositionForeverDiscoveryTab()
    local tab=self.foreverDiscoveryTab
    if not tab or not ProfessionsFrame then return end
    local last=ProfessionsFrame.ProfessionsOverviewTab
    for _,profession in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
        if profession:IsShown() then last=profession end
    end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-2)
    tab:SetFrameStrata(ProfessionsFrame:GetFrameStrata())
    tab:SetFrameLevel(ProfessionsFrame:GetFrameLevel()+20)
    tab:SetChecked(self.directoryInProfessions~=nil)
    tab:Show()
end

function AF:DetachForeverDiscovery(restorePage)
    local state=self.directoryInProfessions
    if not state then return end
    self.directoryInProfessions=nil
    local frame=self.customerFrame
    frame:Hide() frame:SetParent(state.parent)
    frame:ClearAllPoints() frame:SetSize(state.width,state.height)
    for _,point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
    frame:SetFrameStrata(state.strata)
    ProfessionsFrame:SetSize(state.professionWidth,state.professionHeight)
    self.foreverDiscoveryTab:SetChecked(false)
    if restorePage~=false then
        ProfessionsFrame.BookPage:SetShown(state.bookShown)
        ProfessionsFrame.CraftingPage:SetShown(not state.bookShown)
        if self.RefreshCrafterUI then self:RefreshCrafterUI() end
    end
end

function AF:ShowForeverDiscoveryTab()
    if self.directoryInProfessions then return end
    self:AttachCustomerUI()
    local frame=self.customerFrame
    local points={} for index=1,frame:GetNumPoints() do points[index]={frame:GetPoint(index)} end
    self.directoryInProfessions={parent=frame:GetParent(),points=points,width=frame:GetWidth(),height=frame:GetHeight(),
        strata=frame:GetFrameStrata(),professionWidth=ProfessionsFrame:GetWidth(),professionHeight=ProfessionsFrame:GetHeight(),
        bookShown=ProfessionsFrame.BookPage:IsShown()}
    ProfessionsFrame:RightTabSelected(self.foreverDiscoveryTab)
    self.foreverDiscoveryTab:SetChecked(true)
    ProfessionsFrame.BookPage:Hide() ProfessionsFrame.CraftingPage:Hide()
    if self.crafterDefaultsFrame then self.crafterDefaultsFrame:Hide() end
    if self.crafterDefaultsCollapseButton then self.crafterDefaultsCollapseButton:Hide() end
    self:UpdateCrafterRightTabs(false)
    ProfessionsFrame:SetSize(840,620)
    frame:SetParent(ProfessionsFrame) frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",ProfessionsFrame,"TOPLEFT",0,0)
    frame:SetPoint("BOTTOMRIGHT",ProfessionsFrame,"BOTTOMRIGHT",0,0)
    frame:SetFrameStrata(ProfessionsFrame:GetFrameStrata())
    frame:SetFrameLevel(ProfessionsFrame:GetFrameLevel()+5)
    frame:Show() self:RefreshCustomerResults()
    self:PositionForeverDiscoveryTab()
end

function AF:EnsureForeverDiscoveryTab()
    if self.foreverDiscoveryTab or not ProfessionsFrame or not ProfessionsFrame.rightProfessionTabs or not SidePanelTabButtonMixin then return end
    local tab=CreateFrame("Frame",nil,ProfessionsFrame,"LargeSideTabButtonTemplate")
    self.foreverDiscoveryTab=tab
    tab:EnableMouse(true)
    tab:SetFillToInterior(true)
    tab.tooltipText="ArtisanFinder"
    tab.Icon:SetTexture("Interface\\AddOns\\"..(self.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png")
    tab:SetID(100)
    tab:SetCustomOnMouseUpHandler(function(_,button,upInside)
        if button=="LeftButton" and upInside then AF:ShowForeverDiscoveryTab() end
    end)
    hooksecurefunc(ProfessionsFrame,"RightTabSelected",function(_,selected)
        if selected~=tab then AF:DetachForeverDiscovery(false) tab:SetChecked(false) end
    end)
    hooksecurefunc(ProfessionsFrame,"RefreshRightTabs",function() AF:PositionForeverDiscoveryTab() end)
    ProfessionsFrame:HookScript("OnHide",function() AF:DetachForeverDiscovery() end)
    self:AttachCustomerUI()
    self.customerFrame:HookScript("OnHide",function() AF:DetachForeverDiscovery() end)
    self:PositionForeverDiscoveryTab()
end

function AF:UpdateCrafterRightTabs(_)
    self:PositionForeverDiscoveryTab()
end
local Own=AF.IsOwnProfessionWindowOpen
function AF:IsOwnProfessionWindowOpen()
    return not self.directoryInProfessions and Own(self) or false
end
-- Minimap/slash access keeps the standalone directory behavior.
local Open,Toggle=AF.OpenCustomerUI,AF.ToggleCustomerUI
function AF:OpenCustomerUI()
    self:DetachForeverDiscovery() Open(self)
end
function AF:ToggleCustomerUI()
    self:DetachForeverDiscovery() Toggle(self)
end
