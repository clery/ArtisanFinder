local _, AF = ...
-- Only Forever loads these overrides after the shared crafter interface.

function AF:IsUnlimitedReagentsEnabled() return false end

function AF:RestoreOwnedReagentAllocations() end

function AF:ApplyProfessionReagentMode() end

function AF:SetUnlimitedReagentsEnabled() end

function AF:RefreshUnlimitedReagentsCheck() end

function AF:PositionCrafterUI()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	local form = self:GetCraftingSchematicForm()
	if not frame or not defaults or not form then
		return
	end

	defaults:ClearAllPoints()
	local tabs=ProfessionsFrame.ProfessionsOverviewTab
    local tabWidth=tabs and tabs:GetWidth() or 56
    defaults:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", tabWidth+6, 0)
end

function AF:ConfigureCrafterPanel()
    local collapseButton=self.crafterDefaultsCollapseButton
    collapseButton:SetFrameStrata("HIGH")
    for _,child in ipairs({collapseButton.MaximizeButton,collapseButton.MinimizeButton}) do
        if child then child:SetFrameLevel(collapseButton:GetFrameLevel()+1) end
    end
    self.crafterDefaultsFrame:HookScript("OnHide",function() self:UpdateCrafterRightTabs(false) end)
    self.crafterDefaultsFrame:HookScript("OnShow",function() self:UpdateCrafterRightTabs(not self.crafterDefaultsCollapsed) end)
    self:InstallForeverMoneyInput(self.crafterDefaultsFrame)
    self:InstallForeverMoneyInput(self.crafterFrame)
    self:EnsureForeverDiscoveryTab()
    local panel=self.crafterDefaultsFrame
    if panel and not panel.foreverDiscoveryBackground then
        panel.foreverDiscoveryBackground=true
        -- Keep the atlas coordinates: resetting them samples the whole atlas sheet.
        panel.Bg:SetAtlas("Professions-background-summarylist")
        panel.Bg:SetVertexColor(1,1,1,1)
        panel.Bg:SetAlpha(1)
        panel.Bg:SetHorizTile(false) panel.Bg:SetVertTile(false)
        panel.Bg:ClearAllPoints()
        panel.Bg:SetPoint("TOPLEFT",6,-21)
        panel.Bg:SetPoint("BOTTOMRIGHT",-2,2)
        panel.Bg:SetDrawLayer("BACKGROUND",-6)
        panel.parchment=panel:CreateTexture(nil,"BACKGROUND",nil,-7)
        panel.parchment:SetPoint("TOPLEFT",5,-22)
        panel.parchment:SetPoint("BOTTOMRIGHT",-5,5)
        panel.parchment:SetAtlas("Profession-Background-Template2")
        panel.watermark=panel:CreateTexture(nil,"BACKGROUND",nil,1)
        panel.watermark:SetSize(125,125)
        panel.watermark:SetPoint("BOTTOMRIGHT",panel.Bg,"BOTTOMRIGHT",-24,28)
        panel.watermark:SetTexture("Interface\\AddOns\\"..(self.ADDON_NAME or "ArtisanFinder").."\\Assets\\Icon.png")
        panel.watermark:SetDesaturated(true) panel.watermark:SetAlpha(.035)
    end
end
