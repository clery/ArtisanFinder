local _, AF = ...

local TUTORIAL_SYSTEM = "ArtisanFinderTutorial"
local HELP_BUTTON_SCALE = 0.55
local HELP_PLATE_BUTTON_SIZE = 28
local HELP_PLATE_TILE_BUTTON_SIZE = 46
local HELP_PLATE_HIGHLIGHT_PADDING = 7

local function EnsureHelpPlate()
	C_AddOns.LoadAddOn("Blizzard_HelpPlate")
	return true
end

local function StopActiveTutorial()
	if HelpTip and HelpTip.HideAllSystem then
		HelpTip:HideAllSystem(TUTORIAL_SYSTEM)
	end
	if AF.CloseMinimapTutorial then
		AF:CloseMinimapTutorial(false)
	end
	if HelpPlate and HelpPlate.Hide and AF.activeTutorialHelpPlateInfo then
		HelpPlate.Hide(false)
	end
	if HelpPlateTooltip then
		HelpPlateTooltip:Hide()
	end
	if AF.RestoreHelpPlateTiles then
		AF:RestoreHelpPlateTiles()
	end
	AF.activeTutorialHelpPlateInfo = nil
	AF.activeTutorialKind = nil
	AF.activeTutorialWatchToken = (AF.activeTutorialWatchToken or 0) + 1
	AF.crafterTutorialShowing = nil
end

local function IsActiveHelpPlateShowing(kind)
	return AF.activeTutorialKind == kind
		and AF.activeTutorialHelpPlateInfo
		and HelpPlate
		and HelpPlate.IsShowingHelpInfo
		and HelpPlate.IsShowingHelpInfo(AF.activeTutorialHelpPlateInfo)
end

local function GetFrameRectRelativeTo(frame, parent)
	if not frame or not parent or not frame.GetLeft or not parent.GetLeft then
		return nil
	end
	local left, top = frame:GetLeft(), frame:GetTop()
	local parentLeft, parentTop = parent:GetLeft(), parent:GetTop()
	if not left or not top or not parentLeft or not parentTop then
		return nil
	end
	local frameScale = frame:GetEffectiveScale() or 1
	local parentScale = parent:GetEffectiveScale() or 1
	if parentScale == 0 then
		return nil
	end
	return ((left * frameScale) - (parentLeft * parentScale)) / parentScale,
		((top * frameScale) - (parentTop * parentScale)) / parentScale,
		(frame:GetWidth() or 1) * frameScale / parentScale,
		(frame:GetHeight() or 1) * frameScale / parentScale
end

local function Clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function GetUnionRectRelativeTo(parent, ...)
	local minX, maxX, minY, maxY
	for i = 1, select("#", ...) do
		local frame = select(i, ...)
		local x, y, width, height = GetFrameRectRelativeTo(frame, parent)
		if x and y and width and height then
			minX = minX and math.min(minX, x) or x
			maxX = maxX and math.max(maxX, x + width) or x + width
			minY = minY and math.min(minY, y - height) or y - height
			maxY = maxY and math.max(maxY, y) or y
		end
	end
	if not minX then
		return nil
	end
	local parentWidth = parent:GetWidth() or 1
	local parentHeight = parent:GetHeight() or 1
	minX = math.max(0, minX - HELP_PLATE_HIGHLIGHT_PADDING)
	maxX = math.min(parentWidth, maxX + HELP_PLATE_HIGHLIGHT_PADDING)
	maxY = math.min(0, maxY + HELP_PLATE_HIGHLIGHT_PADDING)
	minY = math.max(-parentHeight, minY - HELP_PLATE_HIGHLIGHT_PADDING)
	return minX, maxY, maxX - minX, maxY - minY
end

local function AddHelpPlateTile(info, parent, text, options, ...)
	if type(options) ~= "table" then
		options = {}
	end
	local x, y, width, height = GetUnionRectRelativeTo(parent, ...)
	if not x then
		return
	end
	if options.leftX then
		local right = x + width
		x = math.max(0, options.leftX)
		width = math.max(1, right - x)
	end
	local parentHeight = parent:GetHeight() or 1
	local minY = -math.max(8, parentHeight - HELP_PLATE_TILE_BUTTON_SIZE - 8)
	local maxY = -8
	local buttonX = x - HELP_PLATE_BUTTON_SIZE - 6
	local buttonY = Clamp(y - ((height - HELP_PLATE_TILE_BUTTON_SIZE) / 2), minY, maxY)

	table.insert(info, {
		ButtonPos = { x = buttonX, y = buttonY },
		HighLightBox = { x = x, y = y, width = width, height = height },
		ToolTipDir = "LEFT",
		ToolTipText = text,
	})
end

local function GetMatchingHelpPlateTileInfo(info, tile)
	local button = tile and tile.Button
	if not button then
		return nil
	end
	local _, relativeTo, _, x, y = button:GetPoint(1)
	if relativeTo ~= HelpPlateCanvas then
		return nil
	end
	for _, tileInfo in ipairs(info or {}) do
		local buttonPos = tileInfo.ButtonPos
		if buttonPos and math.abs((x or 0) - (buttonPos.x or 0)) < 0.5 and math.abs((y or 0) - (buttonPos.y or 0)) < 0.5 then
			return tileInfo
		end
	end
	return nil
end

local function MakeHelpPlateClickThrough(info)
	if not HelpPlateCanvas or not HelpPlateCanvas.GetChildren then
		return
	end
	HelpPlateCanvas:EnableMouse(false)
	for i = 1, select("#", HelpPlateCanvas:GetChildren()) do
		local tile = select(i, HelpPlateCanvas:GetChildren())
		if tile and tile.EnableMouse then
			tile:EnableMouse(false)
		end
		if tile and tile.Box and tile.Box.EnableMouse then
			tile.Box:EnableMouse(false)
		end
		local button = tile and tile.Button
		local tileInfo = GetMatchingHelpPlateTileInfo(info, tile)
		if button and tileInfo then
			button:EnableMouse(true)
			button:SetScript("OnEnter", function(self)
				if HelpPlateButtonMixin and HelpPlateButtonMixin.OnEnter then
					HelpPlateButtonMixin.OnEnter(self)
				end
				if tile.Box and tile.Box.BG then
					tile.Box.BG:Hide()
				end
				if HelpPlateTooltip and HelpPlateTooltip.Init then
					HelpPlateTooltip:Init(self, tileInfo.ToolTipText, tileInfo.ToolTipDir or "RIGHT")
				end
			end)
			button:SetScript("OnLeave", function()
				if tile.Box and tile.Box.BG then
					tile.Box.BG:Show()
				end
				if HelpPlateTooltip then
					HelpPlateTooltip:Hide()
				end
			end)
		end
	end
end

function AF:RestoreHelpPlateTiles()
	if not HelpPlateCanvas or not HelpPlateCanvas.GetChildren then
		return
	end
	HelpPlateCanvas:EnableMouse(true)
	for i = 1, select("#", HelpPlateCanvas:GetChildren()) do
		local tile = select(i, HelpPlateCanvas:GetChildren())
		if tile and tile.EnableMouse then
			tile:EnableMouse(true)
		end
		if tile and tile.Box and tile.Box.EnableMouse then
			tile.Box:EnableMouse(true)
		end
		local button = tile and tile.Button
		if button then
			button:SetScript("OnEnter", function(self)
				if HelpPlateButtonMixin and HelpPlateButtonMixin.OnEnter then
					HelpPlateButtonMixin.OnEnter(self)
				end
			end)
			button:SetScript("OnLeave", nil)
		end
		if tile and tile.Box and tile.Box.BG then
			tile.Box.BG:Show()
		end
	end
end

local function AddFrameHideCleanup(frame, callback)
	if not frame or frame.artisanFinderTutorialHideHooked then
		return
	end
	frame.artisanFinderTutorialHideHooked = true
	frame:HookScript("OnHide", callback)
end

local function WatchHelpPlateClosed(info, onClosed)
	AF.activeTutorialWatchToken = (AF.activeTutorialWatchToken or 0) + 1
	local token = AF.activeTutorialWatchToken
	local function poll()
		if AF.activeTutorialWatchToken ~= token then
			return
		end
		if HelpPlate and HelpPlate.IsShowingHelpInfo and HelpPlate.IsShowingHelpInfo(info) then
			C_Timer.After(0.25, poll)
			return
		end
		if AF.activeTutorialHelpPlateInfo == info then
			AF.activeTutorialHelpPlateInfo = nil
		end
		if AF.RestoreHelpPlateTiles then
			AF:RestoreHelpPlateTiles()
		end
		if onClosed then
			onClosed()
		end
	end
	C_Timer.After(0.25, poll)
end

local function CreateTutorialButton(parent, point, relativeTo, relativePoint, x, y)
	EnsureHelpPlate()
	local button = CreateFrame("Button", nil, parent, "MainHelpPlateButton")
	button:SetScale(HELP_BUTTON_SCALE)
	button:SetHitRectInsets(0, 0, 0, 0)
	button:SetFrameStrata(parent:GetFrameStrata())
	button:SetFrameLevel((parent:GetFrameLevel() or 0) + 500)
	button:SetToplevel(true)
	button:SetScript("OnEnter", function(self)
		local tooltipText = AF:Text("TUTORIAL_HELP_BUTTON_TOOLTIP")
		self.mainHelpPlateButtonTooltipText = tooltipText
		self.tooltipText = tooltipText
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltipText, 1, 0.82, 0)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
	return button
end

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
			AF.db.tutorial.introSeen = true
			AF.introTutorialHelpTipText = nil
			C_Timer.After(0.2, function()
				AF:MaybeShowMinimapTutorial()
			end)
		end,
	}
	self.introTutorialHelpTipText = info.text
	HelpTip:Show(UIParent, info, ProfessionMicroButton)
end

function AF:CloseIntroTutorial()
	if not self.introTutorialHelpTipText then
		return
	end
	if HelpTip and HelpTip.Hide then
		HelpTip:Hide(UIParent, self.introTutorialHelpTipText)
	end
	self.db.tutorial.introSeen = true
	self.introTutorialHelpTipText = nil
end

function AF:IsIntroTutorialActive()
	return self.introTutorialHelpTipText ~= nil
end

function AF:GetMinimapTutorialButton()
	if not self.minimapIcon or not self.minimapIcon.GetMinimapButton then
		return nil
	end
	return self.minimapIcon:GetMinimapButton("ArtisanFinder")
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

function AF:SetupCrafterTutorialButton(defaults)
	if defaults.tutorialButton then
		return
	end
	local button = CreateTutorialButton(defaults, "TOPRIGHT", defaults, "TOPRIGHT", -34, 16)
	button:SetScript("OnClick", function()
		AF:ShowCrafterTutorial(false)
	end)
	defaults.tutorialButton = button
	self.crafterTutorialButton = button
	AddFrameHideCleanup(defaults, function()
		if IsActiveHelpPlateShowing("crafter") then
			StopActiveTutorial()
			AF.db.tutorial.crafterSeen = true
		end
	end)
end

function AF:BuildCrafterHelpPlateInfo()
	local defaults = self.crafterDefaultsFrame
	if not defaults then
		return nil
	end
	local info = {
		FramePos = { x = 0, y = 0 },
		FrameSize = { width = defaults:GetWidth() or 356, height = defaults:GetHeight() or 276 },
	}
	local leftX = select(1, GetFrameRectRelativeTo(defaults.defaultsHeader, defaults)) or 0
	leftX = math.max(0, leftX - HELP_PLATE_HIGHLIGHT_PADDING)
	AddHelpPlateTile(info, defaults, self:Text("TUTORIAL_CRAFTER_DEFAULTS"), { leftX = leftX }, defaults.defaultsHeader, defaults.priceField, defaults.noteField, defaults.save)
	AddHelpPlateTile(info, defaults, self:Text("TUTORIAL_CRAFTER_SCAN"), { leftX = leftX }, defaults.scanHeader, defaults.fastScanButton, defaults.forceRescanButton)
	AddHelpPlateTile(info, defaults, self:Text("TUTORIAL_CRAFTER_ADVERTISE"), { leftX = leftX }, defaults.advertisingHeader, defaults.advertiseCheck, defaults.advertiseCheck.Text)
	return #info > 0 and info or nil
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
	HelpPlate.Show(info, self.crafterDefaultsFrame, self.crafterTutorialButton)
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
	local baseQuality = self:Text("BASE_QUALITY", self:GetQualityIconMarkup(3, nil, 16) or "Q3")
	local bestQuality = self:Text("RECOMMENDED_REAGENTS_QUALITY", self:GetQualityIconMarkup(4, nil, 16) or "Q4")
	local concentrationQuality = self:Text("CONCENTRATION_QUALITY", self:GetQualityIconMarkup(5, nil, 16) or "Q5")
	return {
		tutorialFake = true,
		name = self:Text("TUTORIAL_FAKE_ARTISAN_NAME"),
		target = "ArtisanFinderTutorial",
		orderTarget = "ArtisanFinderTutorial",
		professionID = self.currentCustomerProfessionID or 164,
		professionName = self.currentCustomerProfessionID and self:GetProfessionName(self.currentCustomerProfessionID) or self:Text("PROFESSION_FALLBACK", "Tutorial"),
		note = self:Text("TUTORIAL_FAKE_ARTISAN_NOTE"),
		capabilityText = table.concat({ baseQuality, bestQuality, concentrationQuality }, " - "),
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
	AddHelpPlateTile(info, frame, self:Text("TUTORIAL_CUSTOMER_ROW") .. "\n\n" .. self:Text("TUTORIAL_CUSTOMER_ACTION"), { leftX = leftX }, row.name, row.detail, row.capability, row.whoRefresh, row.action)
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
