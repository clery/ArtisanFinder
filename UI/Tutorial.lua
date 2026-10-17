local _, AF = ...

local TUTORIAL_SYSTEM = "ArtisanFinderTutorial"
local HELP_BUTTON_SCALE = 0.55
local HELP_PLATE_BUTTON_SIZE = 28
local HELP_PLATE_TILE_BUTTON_SIZE = 46
local HELP_PLATE_HIGHLIGHT_PADDING = 7

local function EnsureHelpPlate()
	if not C_AddOns or not C_AddOns.LoadAddOn then
		return HelpPlate ~= nil
	end
	local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_HelpPlate")
	return ok == true and HelpPlate ~= nil
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
    AF.discoveryTutorialShowing = nil
    if AF.RefreshTutorialButtons then AF:RefreshTutorialButtons() end
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
					HelpPlateTooltip.artisanFinderOwner = self
				end
			end)
			button:SetScript("OnLeave", function(self)
				if tile.Box and tile.Box.BG then
					tile.Box.BG:Show()
				end
				if HelpPlateTooltip and HelpPlateTooltip.artisanFinderOwner == self then
					HelpPlateTooltip.artisanFinderOwner = nil
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
	if HelpPlateTooltip then
		HelpPlateTooltip.artisanFinderOwner = nil
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
			button:SetScript("OnEnter", function(widget)
				if HelpPlateButtonMixin and HelpPlateButtonMixin.OnEnter then
					HelpPlateButtonMixin.OnEnter(widget)
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
        local tooltipText=AF.GetTutorialHelpButtonText and AF:GetTutorialHelpButtonText(self)
            or AF:Text("TUTORIAL_HELP_BUTTON_TOOLTIP")
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











function AF:SetupCrafterTutorialButton(defaults)
	if defaults.tutorialButton then
		return
	end
	local button = CreateTutorialButton(defaults, "TOPRIGHT", defaults, "TOPRIGHT", -34, 16)
    if self.ConfigureTutorialButton then self:ConfigureTutorialButton(button,defaults,"crafter") end
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
	local frame = self.crafterFrame
	local parent = UIParent
	if not defaults or not parent then
		return nil
	end
	local info = {
		FramePos = { x = 0, y = 0 },
		FrameSize = { width = parent:GetWidth() or 700, height = parent:GetHeight() or 568 },
	}
	local leftX = select(1, GetFrameRectRelativeTo(defaults.defaultsHeader, parent)) or 0
	leftX = math.max(0, leftX - HELP_PLATE_HIGHLIGHT_PADDING)
	if self.AddCrafterPreviewTutorialTile then self:AddCrafterPreviewTutorialTile(info, parent, frame) end
	AddHelpPlateTile(info, parent, self:Text("TUTORIAL_CRAFTER_DEFAULTS"), { leftX = leftX }, defaults.defaultsHeader, defaults.priceField, defaults.noteField, defaults.save)
	if frame and frame:IsShown() then
		AddHelpPlateTile(info, parent, self:Text("ITEM_SPECIFIC_TOOLTIP"), { leftX = leftX }, frame.header, frame.priceField, frame.noteField, frame.save)
	end
	AddHelpPlateTile(info, parent, self:Text("TUTORIAL_CRAFTER_SCAN"), { leftX = leftX }, defaults.scanHeader, defaults.forceRescanButton)
	AddHelpPlateTile(info, parent, self:Text("TUTORIAL_CRAFTER_ADVERTISE"), { leftX = leftX }, defaults.advertisingHeader, defaults.advertiseCheck, defaults.advertiseCheck.Text)
	return #info > 0 and info or nil
end










-- Shared geometry and help-plate mechanics; client tutorials own their flows.
AF.TutorialHelpers = {
	AddFrameHideCleanup = AddFrameHideCleanup,
	AddHelpPlateTile = AddHelpPlateTile,
	CreateTutorialButton = CreateTutorialButton,
	EnsureHelpPlate = EnsureHelpPlate,
	GetFrameRectRelativeTo = GetFrameRectRelativeTo,
	HELP_PLATE_HIGHLIGHT_PADDING = HELP_PLATE_HIGHLIGHT_PADDING,
	IsActiveHelpPlateShowing = IsActiveHelpPlateShowing,
	MakeHelpPlateClickThrough = MakeHelpPlateClickThrough,
	StopActiveTutorial = StopActiveTutorial,
	TUTORIAL_SYSTEM = TUTORIAL_SYSTEM,
	WatchHelpPlateClosed = WatchHelpPlateClosed,
}
