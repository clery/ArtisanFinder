local _, AF = ...
local AddFrameHideCleanup = AF.TutorialHelpers.AddFrameHideCleanup
local AddHelpPlateTile = AF.TutorialHelpers.AddHelpPlateTile
local CreateTutorialButton = AF.TutorialHelpers.CreateTutorialButton
local EnsureHelpPlate = AF.TutorialHelpers.EnsureHelpPlate
local GetFrameRectRelativeTo = AF.TutorialHelpers.GetFrameRectRelativeTo
local HELP_PLATE_HIGHLIGHT_PADDING = AF.TutorialHelpers.HELP_PLATE_HIGHLIGHT_PADDING
local IsActiveHelpPlateShowing = AF.TutorialHelpers.IsActiveHelpPlateShowing
local MakeHelpPlateClickThrough = AF.TutorialHelpers.MakeHelpPlateClickThrough
local StopActiveTutorial = AF.TutorialHelpers.StopActiveTutorial
local TUTORIAL_SYSTEM = AF.TutorialHelpers.TUTORIAL_SYSTEM
local WatchHelpPlateClosed = AF.TutorialHelpers.WatchHelpPlateClosed

function AF:RefreshTutorialLocale()
	local tooltipText = self:Text("TUTORIAL_HELP_BUTTON_TOOLTIP")
	if self.crafterTutorialButton then
		self.crafterTutorialButton.mainHelpPlateButtonTooltipText = tooltipText
		self.crafterTutorialButton.tooltipText = tooltipText
	end
	if self.customerTutorialButton then
		self.customerTutorialButton.mainHelpPlateButtonTooltipText = tooltipText
		self.customerTutorialButton.tooltipText = tooltipText
	end
end

function AF:InitializeTutorial()
	EnsureHelpPlate()
	self.db.tutorial = self.db.tutorial or {}
	C_Timer.After(1, function()
		AF:MaybeShowIntroTutorial()
		AF:MaybeShowMinimapTutorial()
	end)
end

function AF:CloseIntroTutorial()
	if not self.introTutorialHelpTipText then
		return
	end
	if HelpTip and HelpTip.Hide then
		HelpTip:Hide(UIParent, self.introTutorialHelpTipText)
	end
	self:FinishIntroTutorial()
end

function AF:IsIntroTutorialActive()
	return self.introTutorialHelpTipText ~= nil
end

function AF:IsMinimapTutorialActive()
	return self.minimapTutorialHelpTipText ~= nil
end

function AF:CloseMinimapTutorial(markSeen)
	if self.minimapTutorialHelpTipText and HelpTip and HelpTip.Hide then
		HelpTip:Hide(UIParent, self.minimapTutorialHelpTipText)
	end
	if markSeen and self.db and self.db.tutorial then
		self.db.tutorial.minimapSeen = true
	end
	self.minimapTutorialHelpTipText = nil
end

function AF:MaybeShowMinimapTutorial()
	if not self.db or not self.db.tutorial or self.db.tutorial.minimapSeen or not self.db.tutorial.introSeen or not HelpTip then
		return
	end
	if self.minimapTutorialHelpTipText or self.minimapTutorialQueued or self.customerTutorialActive or self.activeTutorialKind or self.db.minimap.hide then
		return
	end
	local button = self:GetMinimapTutorialButton()
	if not button or not button:IsShown() then
		return
	end
	self.minimapTutorialQueued = true
	C_Timer.After(0.1, function()
		AF.minimapTutorialQueued = nil
		if not AF.db or not AF.db.tutorial or AF.db.tutorial.minimapSeen or not AF.db.tutorial.introSeen or AF.db.minimap.hide then
			return
		end
		local minimapButton = AF:GetMinimapTutorialButton()
		if not minimapButton or not minimapButton:IsShown() or AF.customerTutorialActive or AF.activeTutorialKind then
			return
		end
		local info = {
			text = AF:Text("TUTORIAL_MINIMAP_BUTTON"),
			buttonStyle = HelpTip.ButtonStyle.GotIt,
			targetPoint = HelpTip.Point.LeftEdgeCenter,
			alignment = HelpTip.Alignment.Center,
			system = TUTORIAL_SYSTEM,
			autoHorizontalSlide = true,
			onAcknowledgeCallback = function()
				AF.db.tutorial.minimapSeen = true
				AF.minimapTutorialHelpTipText = nil
			end,
		}
		AF.minimapTutorialHelpTipText = info.text
		HelpTip:Show(UIParent, info, minimapButton)
	end)
end

function AF:ShowCrafterTutorial(initial)
	if not EnsureHelpPlate() or not self.crafterDefaultsFrame or not self.crafterTutorialButton then
		return
	end
	if self.customerTutorialActive then
		self:EndCustomerTutorial()
	end
	if IsActiveHelpPlateShowing("crafter") then
		StopActiveTutorial()
		self.db.tutorial.crafterSeen = true
		return
	end
	StopActiveTutorial()
	self:ApplyCrafterDefaultsCollapsed(false)
	self:PositionCrafterUI()
	local info = self:BuildCrafterHelpPlateInfo()
	if not info then
		return
	end
	if initial and HelpPlate.ShowTutorialTooltip then
		HelpPlate.ShowTutorialTooltip(info, self.crafterTutorialButton)
	end
	self.crafterTutorialShowing = true
	self.activeTutorialHelpPlateInfo = info
	self.activeTutorialKind = "crafter"
	HelpPlate.Show(info, UIParent, self.crafterTutorialButton)
	MakeHelpPlateClickThrough(info)
	WatchHelpPlateClosed(info, function()
		AF.crafterTutorialShowing = nil
		AF.activeTutorialKind = nil
		AF.db.tutorial.crafterSeen = true
	end)
end

function AF:MaybeShowCrafterTutorial()
	if self.db and self.db.tutorial and not self.db.tutorial.crafterSeen and not self.crafterTutorialInitialQueued and not self.crafterTutorialShowing then
		self.crafterTutorialInitialQueued = true
		C_Timer.After(0.2, function()
			if AF.crafterDefaultsFrame and AF.crafterDefaultsFrame:IsShown() and not AF.crafterTutorialShowing then
				AF:ShowCrafterTutorial(true)
			end
			AF.crafterTutorialInitialQueued = nil
		end)
	end
end

function AF:ResetTutorial()
	StopActiveTutorial()
	if self.customerTutorialActive then
		self.customerTutorialActive = nil
		self.customerTutorialFavorite = nil
		self:HideCustomerMenu()
		self:RefreshCustomerResults()
	end
	self.db.tutorial = {}
	self.introTutorialHelpTipText = nil
	self.minimapTutorialHelpTipText = nil
	self.minimapTutorialQueued = nil
	self.crafterTutorialInitialQueued = nil
	self.customerTutorialInitialQueued = nil
	self.crafterTutorialShowing = nil
	self:Print(self:Text("TUTORIAL_RESET_DONE"))
	C_Timer.After(0.2, function()
		AF:MaybeShowIntroTutorial()
	end)
end

function AF:FinishIntroTutorial()
	if not self.db or not self.db.tutorial then
		return
	end
	if self.db.tutorial.introSeen and not self.introTutorialHelpTipText then
		return
	end
	self.db.tutorial.introSeen = true
	self.introTutorialHelpTipText = nil
	C_Timer.After(0.2, function()
		AF:MaybeShowMinimapTutorial()
	end)
end

function AF:MaybeShowIntroTutorial()
	if not self.db or not self.db.tutorial or self.db.tutorial.introSeen or not HelpTip or not ProfessionMicroButton then
		return
	end
	local info = {
		text = self:Text("TUTORIAL_INTRO"),
		buttonStyle = HelpTip.ButtonStyle.GotIt,
		targetPoint = HelpTip.Point.TopEdgeCenter,
		alignment = HelpTip.Alignment.Center,
		system = TUTORIAL_SYSTEM,
		autoHorizontalSlide = true,
		onAcknowledgeCallback = function()
			AF:FinishIntroTutorial()
		end,
		onHideCallback = function()
			AF:FinishIntroTutorial()
		end,
	}
	if HelpTip:Show(UIParent, info, ProfessionMicroButton) then
		self.introTutorialHelpTipText = info.text
	end
end

function AF:GetMinimapTutorialButton()
	if not self.minimapIcon or not self.minimapIcon.GetMinimapButton then
		return nil
	end
	return self.minimapIcon:GetMinimapButton("ArtisanFinder")
end

function AF:SetupCustomerTutorialButton(frame)
	if frame.tutorialButton then
		return
	end
	local button = CreateTutorialButton(frame, "TOPRIGHT", frame, "TOPRIGHT", -34, 16)
	button:SetScript("OnClick", function()
		AF:StartCustomerTutorial(false)
	end)
	frame.tutorialButton = button
	self.customerTutorialButton = button
	AddFrameHideCleanup(frame, function()
		if AF.customerTutorialActive then
			AF:EndCustomerTutorial()
		elseif IsActiveHelpPlateShowing("customer") then
			StopActiveTutorial()
			AF.db.tutorial.customerSeen = true
		end
	end)
end

function AF:GetCustomerTutorialRow()
	local bestQuality = self:Text("RECOMMENDED_REAGENTS_QUALITY", self:GetQualityIconMarkup(4, nil, 16) or "Q4")
	local concentrationQuality = self:Text("CONCENTRATION_QUALITY", self:GetQualityIconMarkup(5, nil, 16) or "Q5")
	return {
		tutorialFake = true,
		name = self:Text("TUTORIAL_FAKE_ARTISAN_NAME"),
		target = "ArtisanFinderTutorial",
		orderTarget = "ArtisanFinderTutorial",
		professionID = self.currentCustomerProfessionID or 164,
		professionName = self.currentCustomerProfessionID and self:GetProfessionName(self.currentCustomerProfessionID) or self:Text("PROFESSION_FALLBACK", self:Text("TUTORIAL_PROFESSION_NAME")),
		note = self:Text("TUTORIAL_FAKE_ARTISAN_NOTE"),
		capabilityText = table.concat({ bestQuality, concentrationQuality }, " - "),
		quality = 3,
		bestQuality = 4,
		bestConcentrationQuality = 5,
		priceCopper = 5000000,
		freeCommission = false,
		commissionSpecified = true,
		tradeLead = false,
		updatedAt = self:Now(),
	}
end

function AF:BuildCustomerHelpPlateInfo()
	local frame = self.customerFrame
	local row = self.customerRows and self.customerRows[1]
	if not frame or not row or not row:IsShown() then
		return nil
	end
	local info = {
		FramePos = { x = 0, y = 0 },
		FrameSize = { width = frame:GetWidth() or 482, height = frame:GetHeight() or 568 },
	}
	local leftX = select(1, GetFrameRectRelativeTo(frame.status, frame)) or 0
	leftX = math.max(0, leftX - HELP_PLATE_HIGHLIGHT_PADDING)
	AddHelpPlateTile(info, frame, self:Text("TUTORIAL_CUSTOMER_STATUS"), { leftX = leftX }, frame.status)
	AddHelpPlateTile(info, frame, self:Text("TUTORIAL_CUSTOMER_SEARCH"), { leftX = leftX }, frame.search, frame.sort, frame.refresh)
	AddHelpPlateTile(info, frame, self:Text("TUTORIAL_CUSTOMER_ROW") .. "\n\n" .. self:Text("TUTORIAL_CUSTOMER_ACTION"), { leftX = leftX }, row.name, row.detail, row.capability, row.whoRefresh, row.prepare, row.action)
	return #info > 0 and info or nil
end

function AF:EndCustomerTutorial()
	local wasActive = self.customerTutorialActive
	local shouldStopHelpPlate = IsActiveHelpPlateShowing("customer")
		or (self.activeTutorialKind == "customer" and self.activeTutorialHelpPlateInfo ~= nil)
	if not wasActive and not shouldStopHelpPlate then
		return
	end
	self.customerTutorialActive = nil
	self.customerTutorialFavorite = nil
	self:HideCustomerMenu()
	self.db.tutorial.customerSeen = true
	if shouldStopHelpPlate then
		StopActiveTutorial()
	end
	self:RefreshCustomerResults()
end

function AF:StartCustomerTutorial(initial)
	if not EnsureHelpPlate() or not self.customerFrame or not self.customerTutorialButton then
		return
	end
	if IsActiveHelpPlateShowing("customer") or self.customerTutorialActive then
		self:EndCustomerTutorial()
		return
	end
	StopActiveTutorial()
	self.customerTutorialActive = true
	self.customerTutorialFavorite = false
	self:SetCustomerPanelCollapsed(false, true)
	self:RefreshCustomerResults()
	C_Timer.After(0.1, function()
		if not AF.customerTutorialActive then
			return
		end
		local info = AF:BuildCustomerHelpPlateInfo()
		if not info then
			AF:EndCustomerTutorial()
			return
		end
		if initial and HelpPlate.ShowTutorialTooltip then
			HelpPlate.ShowTutorialTooltip(info, AF.customerTutorialButton)
		end
		AF.activeTutorialHelpPlateInfo = info
		AF.activeTutorialKind = "customer"
		HelpPlate.Show(info, AF.customerFrame, AF.customerTutorialButton)
		MakeHelpPlateClickThrough(info)
		WatchHelpPlateClosed(info, function()
			AF.activeTutorialKind = nil
			AF:EndCustomerTutorial()
		end)
	end)
end

function AF:MaybeShowCustomerTutorial()
	if self.db and self.db.tutorial and not self.db.tutorial.customerSeen and not self.customerTutorialInitialQueued then
		self.customerTutorialInitialQueued = true
		C_Timer.After(0.2, function()
			if AF.customerFrame and AF.customerFrame:IsShown() then
				AF:StartCustomerTutorial(true)
			end
			AF.customerTutorialInitialQueued = nil
		end)
	end
end
