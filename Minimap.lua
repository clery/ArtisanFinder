local _, AF = ...

local ICON = 7548932 -- inv-12-profession-blacksmithing-repairhammer-purple
local ICON_COORDS = { 0, 1, 0, 1 }
local OUTDATED_BADGE_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local function GetOutdatedBadgeMarkup(size)
	size = tonumber(size) or 14
	return "|T" .. OUTDATED_BADGE_TEXTURE .. ":" .. size .. ":" .. size .. ":0:0|t"
end

local function HasOutdatedProfessionRows(rows)
	for _, row in ipairs(rows or {}) do
		if row.outdated then
			return true
		end
	end
	return false
end

local function GetMinimapButton()
	return _G.LibDBIcon10_ArtisanFinder
end

local OpenOptionsPanel
local HideMinimapTooltip

local function HandleMinimapClick(owner, button)
	if AF.CloseMinimapTutorial then
		AF:CloseMinimapTutorial(true)
	end
	if button == "RightButton" and IsShiftKeyDown() then
		AF:ClearOrderNotifications()
	elseif IsShiftKeyDown() then
		AF:SetMinimapHidden(true)
	elseif button == "LeftButton" and IsAltKeyDown() then
		AF:ShowMinimapAdvertisingMenu(owner or GetMinimapButton())
	elseif button == "LeftButton" then
		AF:ToggleAvailable()
	elseif button == "MiddleButton" then
		AF:ToggleAutoAvailability()
	elseif button == "RightButton" then
		OpenOptionsPanel()
	end
	AF:RefreshOpenMinimapTooltip()
end

OpenOptionsPanel = function()
	if AF.InitializeOptions then
		AF:InitializeOptions()
	end
	if Settings and Settings.OpenToCategory and AF.optionsCategory and AF.optionsCategory.GetID then
		Settings.OpenToCategory(AF.optionsCategory:GetID())
	end
end

HideMinimapTooltip = function()
	AF.minimapTooltipShown = false
	if _G.LibDBIconTooltip then
		_G.LibDBIconTooltip:Hide()
	end
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function IsAdvertisingRowSelected(row)
	return AF:IsProfessionAdvertised(row.characterName, row.professionID)
end

local function SetAdvertisingRowSelected(row)
	AF:SetProfessionAdvertised(row.characterName, row.professionID, not AF:IsProfessionAdvertised(row.characterName, row.professionID))
end

function AF:ShowMinimapAdvertisingMenu(owner)
	local rows = self:GetAdvertisingProfessionRows()
	if not MenuUtil or #rows == 0 then
		OpenOptionsPanel()
		return
	end

	MenuUtil.CreateContextMenu(owner or GetMinimapButton(), function(_, rootDescription)
		rootDescription:SetTag("ARTISANFINDER_MINIMAP_ADVERTISING")
		rootDescription:CreateTitle(AF:Text("MINIMAP_ADVERTISING_MENU_TITLE"))
		local currentCharacter
		local currentSubmenu
		for _, row in ipairs(rows) do
			if row.characterName ~= currentCharacter then
				currentCharacter = row.characterName
				currentSubmenu = rootDescription:CreateButton(AF:GetDisplayPlayerName(currentCharacter))
			end
			local icon = AF:GetProfessionIconMarkup(row.professionID, row, 14) or ""
			local label = row.professionName or AF:GetProfessionName(row.professionID)
			if icon ~= "" then
				label = icon .. " " .. label
			end
			currentSubmenu:CreateCheckbox(label, IsAdvertisingRowSelected, SetAdvertisingRowSelected, row)
		end
	end)
end

function AF:PopulateMinimapTooltip(tooltip)
	if not tooltip or not tooltip.AddLine then
		return
	end
	tooltip:AddLine("ArtisanFinder", 1, 0.82, 0)
	local mode = AF:GetAvailabilityMode()
	if mode == AF.AVAILABILITY_ACCOUNT then
		tooltip:AddLine(AF:Text("MINIMAP_AVAILABLE_ACCOUNT"), 0.1, 1, 0.1)
	elseif mode == AF.AVAILABILITY_CURRENT then
		tooltip:AddLine(AF:Text("MINIMAP_AVAILABLE_CURRENT"), 1, 0.82, 0.1)
	else
		tooltip:AddLine(AF:Text("MINIMAP_UNAVAILABLE"), 1, 0.25, 0.1)
	end
	tooltip:AddLine(AF:Text("MINIMAP_AUTO_AVAILABILITY", AF.db.autoAvailability and AF:Text("ENABLED") or AF:Text("DISABLED")), 1, 1, 1)
	if AF.db.autoAvailability then
		tooltip:AddLine(AF:Text("MINIMAP_AUTO_HINT"), 0.65, 0.65, 0.65, true)
	end
	local professionRows = AF:GetAdvertisingProfessionRows()
	if HasOutdatedProfessionRows(professionRows) then
		tooltip:AddLine(GetOutdatedBadgeMarkup(14) .. " " .. AF:Text("MINIMAP_OUTDATED_SCANS"), 1, 0.82, 0.1, true)
	end
	if #professionRows > 0 then
		local currentCharacter
		for _, row in ipairs(professionRows) do
			if row.characterName ~= currentCharacter then
				currentCharacter = row.characterName
				tooltip:AddLine(AF:GetDisplayPlayerName(currentCharacter), 1, 0.82, 0)
			end
			local icon = AF:GetProfessionIconMarkup(row.professionID, row, 14) or ""
			local text = AF:Text("MINIMAP_PROFESSION_SCANNED", row.professionName, row.count)
			if row.outdated then
				text = text .. " |cff888888(" .. AF:Text("OUTDATED") .. ")|r"
			end
			if icon ~= "" then
				text = icon .. " " .. text
			end
			if row.advertised then
				tooltip:AddLine("  " .. text, 1, 1, 1)
			else
				tooltip:AddLine("  " .. text .. " |cff888888(" .. AF:Text("MINIMAP_NOT_ADVERTISED") .. ")|r", 0.65, 0.65, 0.65)
			end
		end
	else
		tooltip:AddLine(AF:Text("MINIMAP_SCANNED", 0), 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(AF:Text("MINIMAP_LEFT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_ALT_LEFT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_MIDDLE_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_RIGHT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_SHIFT_RIGHT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_SHIFT_CLICK"), 0.65, 0.65, 0.65)
end

function AF:RefreshOpenMinimapTooltip()
	local tooltip = _G.LibDBIconTooltip
	if not self.minimapTooltipShown then
		return
	end
	local function refreshTooltip(openTooltip)
		if not openTooltip or not openTooltip:IsShown() or not openTooltip.ClearLines then
			return false
		end
		local owner = openTooltip.GetOwner and openTooltip:GetOwner()
		local ownerName = owner and owner.GetName and owner:GetName()
		if ownerName
			and ownerName ~= "LibDBIcon10_ArtisanFinder"
			and ownerName ~= "ArtisanFinderStandaloneButton"
		then
			return false
		end
		openTooltip:ClearLines()
		self:PopulateMinimapTooltip(openTooltip)
		openTooltip:Show()
		return true
	end
	if refreshTooltip(tooltip) then
		return
	end
	refreshTooltip(GameTooltip)
end

function AF:InitializeMinimap()
	if self.minimapInitialized then
		return
	end
	self.minimapInitialized = true

	if self.db.minimap.angle and self.db.minimap.minimapPos == nil then
		self.db.minimap.minimapPos = self.db.minimap.angle
	end
	if self.db.minimap.minimapPos == nil then
		self.db.minimap.minimapPos = 225
	end

	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not ldb or not icon then
		self:Print(self:Text("MINIMAP_LIBS_MISSING"))
		return
	end

	self.minimapBroker = ldb:NewDataObject("ArtisanFinder", {
		type = "data source",
		text = "ArtisanFinder",
		icon = ICON,
		iconCoords = ICON_COORDS,
		OnClick = function(owner, button)
			HandleMinimapClick(owner, button)
		end,
		OnTooltipShow = function(tooltip)
			AF.minimapTooltipShown = true
			AF:PopulateMinimapTooltip(tooltip)
		end,
		OnLeave = function()
			AF.minimapTooltipShown = false
		end,
	})

	icon:Register("ArtisanFinder", self.minimapBroker, self.db.minimap)
	self.minimapIcon = icon
	self:InitializeStandaloneMinimapButton()
	self:HookMinimapButtonDrag()
	self:StyleMinimapButton()
	self:RefreshMinimap()
	C_Timer.After(0.1, function()
		AF:MaybeShowMinimapTutorial()
	end)
end

function AF:InitializeStandaloneMinimapButton()
	if self.standaloneMinimapButton then
		return
	end
	local button = CreateFrame("Button", "ArtisanFinderStandaloneButton", UIParent, "BackdropTemplate")
	button:SetSize(42, 42)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	button:SetClampedToScreen(true)
	self:ApplyProfessionPanel(button)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(ICON)
	button.icon:SetSize(28, 28)
	button.icon:SetPoint("CENTER")
	button:SetScript("OnClick", function(self, clickButton)
		HandleMinimapClick(self, clickButton)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		AF.minimapTooltipShown = true
		AF:PopulateMinimapTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		AF.minimapTooltipShown = false
		GameTooltip:Hide()
	end)
	button:Hide()
	self.standaloneMinimapButton = button
end

function AF:GetStandaloneMinimapButton()
	return self.standaloneMinimapButton
end

function AF:HookMinimapButtonDrag()
	local button = GetMinimapButton()
	if not button or button.artisanFinderDragHooked then
		return
	end
	button.artisanFinderDragHooked = true
	button:HookScript("OnDragStart", HideMinimapTooltip)
end

function AF:PositionStandaloneMinimapButton()
	local button = self.standaloneMinimapButton
	if not button then
		return
	end
	button:ClearAllPoints()
	local point = self.db.minimap.standalonePoint or "CENTER"
	button:SetPoint(point, UIParent, point, self.db.minimap.standaloneX or -180, self.db.minimap.standaloneY or -120)
end

function AF:ResetMinimapButtonPosition()
	self.db.minimap = self.db.minimap or {}
	if self.db.minimap.standalone then
		self.db.minimap.standalonePoint = "CENTER"
		self.db.minimap.standaloneX = 0
		self.db.minimap.standaloneY = 0
	else
		self.db.minimap.angle = 225
		self.db.minimap.minimapPos = 225
	end
	self:RefreshMinimap()
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:SetMinimapStandalone(enabled)
	self.db.minimap.standalone = enabled == true
	self:RefreshMinimap()
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:StyleMinimapButton()
	if not self.minimapIcon then
		return
	end
	self.minimapIcon:ResetButtonBorder("ArtisanFinder")
	self.minimapIcon:ResetButtonBackground("ArtisanFinder")
	self.minimapIcon:ResetButtonHighlightTexture("ArtisanFinder")
	self.minimapIcon:SetButtonIcon("ArtisanFinder", ICON, 18, "CENTER", 0, 0)
	self:RefreshMinimapBadge()
end

function AF:HasOutdatedScannedRows()
	return HasOutdatedProfessionRows(self:GetAdvertisingProfessionRows())
end

function AF:RefreshMinimapBadge()
	local button = GetMinimapButton()
	if not button then
		return
	end
	if not button.artisanFinderOutdatedBadge then
		local badge = button:CreateTexture(nil, "OVERLAY", nil, 7)
		badge:SetTexture(OUTDATED_BADGE_TEXTURE)
		badge:SetSize(19, 19)
		badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 8, 7)
		button.artisanFinderOutdatedBadge = badge
	end
	button.artisanFinderOutdatedBadge:SetShown(self:HasOutdatedScannedRows())
end

function AF:SetMinimapHidden(hidden)
	self.db.minimap.hide = hidden == true
	if self.minimapIcon then
		if self.db.minimap.hide or self.db.minimap.standalone then
			if self.CloseMinimapTutorial then
				self:CloseMinimapTutorial(false)
			end
			self.minimapIcon:Hide("ArtisanFinder")
		else
			self.minimapIcon:Show("ArtisanFinder")
			C_Timer.After(0.1, function()
				AF:MaybeShowMinimapTutorial()
			end)
		end
	end
	self:RefreshStandaloneMinimapButton()
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:RefreshStandaloneMinimapButton()
	self:InitializeStandaloneMinimapButton()
	local button = self.standaloneMinimapButton
	if not button then
		return
	end
	local show = self.db.minimap.standalone == true and self.db.minimap.hide ~= true
	if show then
		self:PositionStandaloneMinimapButton()
		local mode = self:GetAvailabilityMode()
		if mode == self.AVAILABILITY_ACCOUNT then
			button.icon:SetVertexColor(0.25, 1, 0.25)
		elseif mode == self.AVAILABILITY_CURRENT then
			button.icon:SetVertexColor(1, 0.82, 0.15)
		else
			button.icon:SetVertexColor(1, 1, 1)
		end
		button:Show()
	else
		button:Hide()
	end
	if not button.artisanFinderOutdatedBadge then
		local badge = button:CreateTexture(nil, "OVERLAY", nil, 7)
		badge:SetTexture(OUTDATED_BADGE_TEXTURE)
		badge:SetSize(19, 19)
		badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
		button.artisanFinderOutdatedBadge = badge
	end
	button.artisanFinderOutdatedBadge:SetShown(show and self:HasOutdatedScannedRows())
end

function AF:RefreshMinimap()
	if not self.minimapBroker then
		return
	end

	local mode = self:GetAvailabilityMode()
	if mode == self.AVAILABILITY_ACCOUNT then
		self.minimapBroker.iconR = 0.25
		self.minimapBroker.iconG = 1
		self.minimapBroker.iconB = 0.25
	elseif mode == self.AVAILABILITY_CURRENT then
		self.minimapBroker.iconR = 1
		self.minimapBroker.iconG = 0.82
		self.minimapBroker.iconB = 0.15
	else
		self.minimapBroker.iconR = 1
		self.minimapBroker.iconG = 1
		self.minimapBroker.iconB = 1
	end

	if self.minimapIcon then
		self:HookMinimapButtonDrag()
		self.minimapIcon:Refresh("ArtisanFinder", self.db.minimap)
		if self.db.minimap.hide or self.db.minimap.standalone then
			self.minimapIcon:Hide("ArtisanFinder")
		else
			self.minimapIcon:Show("ArtisanFinder")
			C_Timer.After(0.1, function()
				AF:MaybeShowMinimapTutorial()
			end)
		end
	end
	self:RefreshStandaloneMinimapButton()
	self:RefreshMinimapBadge()
end
