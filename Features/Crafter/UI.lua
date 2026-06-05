local _, AF = ...

local DEFAULT_COMMISSION_PANEL_WIDTH = 392
local CRAFTER_COLLAPSE_BUTTON_LEVEL_OFFSET = 1000
local COMMISSION_PRICE_FIELD_WIDTH = 150
local COMMISSION_FIELD_HEIGHT = 36
local COMMISSION_PRICE_MAX_LETTERS = 9
local COMMISSION_FIELD_LEFT = 92
local COMMISSION_FIELD_RIGHT_MARGIN = 42
local CRAFTER_REOPEN_ICON = 7548932 -- inv-12-profession-blacksmithing-repairhammer-purple
local CUSTOMER_PREVIEW_TEXTURE = 4675733
local CopyTable = AF.CopyTable
local SECTION_GAP = 28
local SECTION_BOTTOM_GAP = 6
local COLLAPSED_SECTION_HEIGHT = 30
local COLLAPSED_TITLE_OFFSET = 4

local function UpdatePlaceholder(box)
	box.Placeholder:SetShown((box:GetText() or "") == "")
end

local function SetEditBoxText(box, text, updateLastSettingText)
	text = tostring(text or "")
	box.artisanFinderSettingText = true
	box:SetText(text)
	box:SetCursorPosition(0)
	box.artisanFinderSettingText = false
	if updateLastSettingText ~= false then
		box.artisanFinderLastSettingText = text
		box.artisanFinderDirty = false
	end
	UpdatePlaceholder(box)
end

local function SetEditBoxTextIfUnedited(box, text)
	text = tostring(text or "")
	local currentText = box:GetText() or ""
	if currentText == text then
		box.artisanFinderLastSettingText = text
		UpdatePlaceholder(box)
		return
	end
	if box:HasFocus() or (box.artisanFinderLastSettingText ~= nil and currentText ~= box.artisanFinderLastSettingText) then
		UpdatePlaceholder(box)
		return
	end
	SetEditBoxText(box, text)
end

local function SetEditBoxTextForSource(box, text, sourceKey)
	sourceKey = tostring(sourceKey or "")
	if box.artisanFinderSettingSource ~= sourceKey then
		box.artisanFinderSettingSource = sourceKey
		SetEditBoxText(box, text)
		return
	end
	SetEditBoxTextIfUnedited(box, text)
end

local function WatchEditBox(box, callback)
	box:SetScript("OnTextChanged", function(self)
		UpdatePlaceholder(self)
		if not self.artisanFinderSettingText then
			local lastText = self.artisanFinderLastSettingText
			self.artisanFinderDirty = lastText == nil or (self:GetText() or "") ~= lastText
			callback()
		end
	end)
end

local function SaveOnEnter(box, saveButton)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if saveButton and saveButton:IsEnabled() then
			saveButton:Click()
		end
	end)
end

local function IsEditBoxDirty(box)
	return box and box.artisanFinderDirty == true
end

local function SetPanelInputSource(panel, sourceKey)
	sourceKey = tostring(sourceKey or "")
	if panel.artisanFinderInputSource ~= sourceKey then
		panel.artisanFinderInputSource = sourceKey
		if not IsEditBoxDirty(panel.price) and not IsEditBoxDirty(panel.note) then
			panel.artisanFinderDirty = false
		end
	end
end

local function ClampCommissionEditBox(box)
	local value = tonumber(box:GetText())
	if not value or value <= (AF.MAX_COMMISSION_GOLD or 99999999) then
		return
	end
	SetEditBoxText(box, tostring(AF.MAX_COMMISSION_GOLD or 99999999), false)
end

local function PrepareInsetEditBox(field, width, placeholderKey, hasGoldIcon)
	field:SetSize(width, COMMISSION_FIELD_HEIGHT)
	field.NineSlice:SetAllPoints()
	field.NineSlice.layoutType = "InsetFrameTemplate"
	if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
		NineSliceUtil.ApplyLayoutByName(field.NineSlice, field.NineSlice.layoutType)
	end

	local box = field.Box
	box.Field = field
	box:ClearAllPoints()
	box:SetPoint("LEFT", 8, 0)
	box:SetPoint("RIGHT", hasGoldIcon and -25 or -8, 0)
	box:SetHeight(20)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetJustifyH("LEFT")

	box.Placeholder = field.Placeholder
	box.Placeholder:ClearAllPoints()
	box.Placeholder:SetPoint("TOPLEFT", field, "TOPLEFT", 8, -4)
	box.Placeholder:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", hasGoldIcon and -25 or -8, 4)
	box.Placeholder:SetJustifyH("LEFT")
	box.Placeholder:SetJustifyV("MIDDLE")
	box.Placeholder:SetWordWrap(true)
	box.Placeholder:SetText(AF:Text(placeholderKey))

	box.GoldIcon = field.GoldIcon
	box.GoldIcon:SetShown(hasGoldIcon == true)

	box:SetScript("OnEditFocusGained", function(self)
		UpdatePlaceholder(self)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		UpdatePlaceholder(self)
	end)
	UpdatePlaceholder(box)

	return box
end

local function SetFieldPoint(box, ...)
	box.Field:ClearAllPoints()
	box.Field:SetPoint(...)
end

local function SetFieldWidth(box, width)
	box.Field:SetWidth(width)
end

local function MatchFieldWidth(box, sourceBox)
	if box and sourceBox and sourceBox.Field then
		SetFieldWidth(box, sourceBox.Field:GetWidth())
	end
end

local function SizeButtonForText(button, text, minWidth, maxWidth)
	button:SetText(text)
	local fontString = button:GetFontString()
	local textWidth = fontString and fontString:GetStringWidth() or 0
	local width = math.ceil(textWidth + 26)
	width = math.max(minWidth or 54, width)
	if maxWidth then
		width = math.min(maxWidth, width)
	end
	button:SetWidth(width)
	return width
end

local function FitNoteAndSave(container, noteLabel, noteBox, saveButton, totalWidth, minNoteWidth)
	local saveWidth = SizeButtonForText(saveButton, AF:Text("SAVE"), 54)
	local noteWidth = math.max(minNoteWidth or 80, totalWidth - noteLabel:GetWidth() - 4 - 8 - saveWidth)
	local fittedWidth = math.max(totalWidth, noteLabel:GetWidth() + 4 + noteWidth + 8 + saveWidth)
	SetFieldWidth(noteBox, noteWidth)
	saveButton:ClearAllPoints()
	saveButton:SetPoint("LEFT", noteBox.Field, "RIGHT", 8, 0)
	container:SetWidth(fittedWidth)
end

local function FitActionButtons(noteBox, saveButton, discardButton)
	local availableWidth = noteBox.Field:GetWidth()
	local gap = 6
	local saveWidth = SizeButtonForText(saveButton, AF:Text("SAVE"), 72, math.floor((availableWidth - gap) / 2))
	local discardWidth = SizeButtonForText(discardButton, AF:Text("DISCARD"), 72, math.floor((availableWidth - gap) / 2))
	local totalWidth = saveWidth + gap + discardWidth
	if totalWidth > availableWidth then
		local buttonWidth = math.floor((availableWidth - gap) / 2)
		saveButton:SetWidth(buttonWidth)
		discardButton:SetWidth(buttonWidth)
	end
	saveButton:ClearAllPoints()
	saveButton:SetPoint("TOPLEFT", noteBox.Field, "BOTTOMLEFT", 0, -6)
	discardButton:ClearAllPoints()
	discardButton:SetPoint("LEFT", saveButton, "RIGHT", gap, 0)
end

local function FitStackedDefaultNoteAndSave(container, noteLabel, noteBox, saveButton, discardButton)
	SetFieldWidth(noteBox, DEFAULT_COMMISSION_PANEL_WIDTH - COMMISSION_FIELD_LEFT - COMMISSION_FIELD_RIGHT_MARGIN)
	FitActionButtons(noteBox, saveButton, discardButton)
	container:SetWidth(DEFAULT_COMMISSION_PANEL_WIDTH)
end

local function FitCrafterCommissionFields(defaults, frame)
	local panelWidth = defaults:GetWidth()
	if not panelWidth or panelWidth <= 28 then
		panelWidth = DEFAULT_COMMISSION_PANEL_WIDTH
	end
	local fieldWidth = math.max(COMMISSION_PRICE_FIELD_WIDTH, panelWidth - COMMISSION_FIELD_LEFT - COMMISSION_FIELD_RIGHT_MARGIN)
	for _, box in ipairs({ defaults.price, defaults.note, frame.price, frame.note }) do
		SetFieldWidth(box, fieldWidth)
	end
	FitActionButtons(defaults.note, defaults.save, defaults.discard)
	FitActionButtons(frame.note, frame.save, frame.discard)
end

local function ConfigureInfoButton(button, tooltipTitle, tooltipText)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text(tooltipTitle), 1, 0.82, 0)
		GameTooltip:AddLine(AF:Text(tooltipText), 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(AF:Text("COMMISSION_HELP_0"), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(AF:Text("COMMISSION_HELP_FREE"), 0.8, 0.8, 0.8, true)
		GameTooltip:AddLine(AF:Text("COMMISSION_HELP_POSITIVE"), 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function CreateCustomerPreviewButton(parent)
	local button = CreateFrame("Button", nil, parent, "ArtisanFinderCustomerPreviewButtonTemplate")
	button:SetNormalTexture(CUSTOMER_PREVIEW_TEXTURE)
	button:SetPushedTexture(CUSTOMER_PREVIEW_TEXTURE)
	return button
end

local function ConfigureCustomerPreviewButton(button, getEntry)
	button:SetScript("OnEnter", function(self)
		local entry, defaultEntry, disabledText = getEntry()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("CUSTOMER_SIDE_PREVIEW"), 1, 0.82, 0)
		if disabledText then
			GameTooltip:AddLine(disabledText, 0.75, 0.75, 0.75, true)
		elseif entry or defaultEntry then
			local previewEntry = CopyTable(defaultEntry)
			for key, value in pairs(entry or {}) do
				previewEntry[key] = value
			end
			AF:AddCustomerEntryTooltipLines(GameTooltip, previewEntry, { title = false, source = false, pricing = true })
		else
			GameTooltip:AddLine(AF:Text("CUSTOMER_SIDE_PREVIEW_EMPTY"), 0.65, 0.65, 0.65, true)
		end
		AF:StyleCustomerTooltip(GameTooltip)
		AF:FitTooltipWidthToContent(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function ConfigureSectionToggle(button, sectionKey, labelKey)
	button:SetSize(24, 20)
	button.sectionKey = sectionKey
	button.labelKey = labelKey
	button:SetScript("OnClick", function()
		AF.db.crafterSections[sectionKey] = not AF.db.crafterSections[sectionKey]
		AF:RefreshCrafterUI()
	end)
	button:SetScript("OnEnter", function(self)
		self.arrow:SetAlpha(1)
		self.arrow:SetVertexColor(1, 1, 1)
		local collapsed = AF.db.crafterSections[self.sectionKey] == true
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text(collapsed and "EXPAND_SECTION" or "COLLAPSE_SECTION", AF:Text(self.labelKey)), 1, 0.82, 0)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		button.arrow:SetAlpha(1)
		button.arrow:SetVertexColor(0.72, 0.72, 0.72)
		GameTooltip:Hide()
	end)
end

local function SetPanelError(panel, message)
	if panel and panel.errorText then
		message = tostring(message or "")
		local wasVisible = panel.errorText:IsShown() and (panel.errorText:GetText() or "") ~= ""
		panel.errorText:SetText(message)
		panel.errorText:SetShown(message ~= "")
		local isVisible = panel.errorText:IsShown() and (panel.errorText:GetText() or "") ~= ""
		if wasVisible ~= isVisible and AF.LayoutCrafterSections then
			AF:LayoutCrafterSections()
		end
	end
end

local function ClearPanelError(panel)
	SetPanelError(panel, nil)
end

local function HasPanelError(panel)
	return panel
		and panel.errorText
		and panel.errorText:IsShown()
		and (panel.errorText:GetText() or "") ~= ""
		or false
end

local function IsDefaultsSaveDirty(defaults)
	if not defaults or not defaults.price or not defaults.note then
		return false
	end
	if defaults.artisanFinderLoadedPriceText == nil or defaults.artisanFinderLoadedNoteText == nil then
		return defaults.artisanFinderDirty == true or IsEditBoxDirty(defaults.price) or IsEditBoxDirty(defaults.note)
	end
	return (defaults.price:GetText() or "") ~= defaults.artisanFinderLoadedPriceText
		or (defaults.note:GetText() or "") ~= defaults.artisanFinderLoadedNoteText
end

local function ShouldEnableDefaultsSave(AF, defaults)
	return IsDefaultsSaveDirty(defaults)
		and (defaults.artisanFinderLoadedProfessionID or AF:GetCurrentSupportedProfessionID()) ~= nil
		and not HasPanelError(defaults)
end

local function GetDefaultsRefreshProfessionID(AF, defaults, currentProfessionID)
	if currentProfessionID then
		return currentProfessionID
	end
	local loadedProfessionID = defaults and defaults.artisanFinderLoadedProfessionID
	if loadedProfessionID and (IsDefaultsSaveDirty(defaults) or (AF.activeScan and tonumber(AF.activeScan.professionID) == tonumber(loadedProfessionID))) then
		return loadedProfessionID
	end
	return nil
end

local function SetDefaultsLoadedState(AF, defaults, professionID, default)
	local priceText = default and AF:FormatCommissionInput(default) or ""
	local noteText = default and default.note or ""
	defaults.artisanFinderLoadedProfessionID = professionID
	defaults.artisanFinderLoadedPriceText = priceText
	defaults.artisanFinderLoadedNoteText = noteText
	defaults.artisanFinderDirty = false
	SetEditBoxText(defaults.price, priceText)
	SetEditBoxText(defaults.note, noteText)
	defaults.price.artisanFinderDirty = false
	defaults.note.artisanFinderDirty = false
end

local function RefreshDefaultsTextForProfession(AF, defaults, professionID)
	local sourceKey = "profession:" .. tostring(professionID or "")
	local default = professionID and AF:GetProfessionPriceEntry(AF.db.artisanProfile, professionID)
	if defaults.artisanFinderInputSource ~= sourceKey then
		if IsDefaultsSaveDirty(defaults) then
			return defaults.artisanFinderInputSource or sourceKey
		end
		SetPanelInputSource(defaults, sourceKey)
		SetDefaultsLoadedState(AF, defaults, professionID, default)
		return sourceKey
	end
	if not IsDefaultsSaveDirty(defaults) then
		SetDefaultsLoadedState(AF, defaults, professionID, default)
	end
	return sourceKey
end

local function ValidateCommissionInput(box, panel)
	if AF:NormalizeCommissionInput(box:GetText()) then
		ClearPanelError(panel)
		return true
	end
	SetPanelError(panel, AF:Text("COMMISSION_INVALID"))
	return false
end

local function ParseCommissionOrWarn(box, panel)
	if not ValidateCommissionInput(box, panel) then
		return nil
	end
	local copper, free, state = AF:NormalizeCommissionInput(box:GetText())
	return copper, free, state
end

function AF:InitializeCrafterUI()
	self:AttachCrafterUI()
end

function AF:RefreshCrafterLocale()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	if frame then
		frame.discard:SetText(self:Text("DISCARD"))
		frame.priceLabel:SetText(self:Text("COMMISSION"))
		frame.noteLabel:SetText(self:Text("NOTE"))
		frame.price.Placeholder:SetText(self:Text("COMMISSION_PLACEHOLDER"))
		frame.note.Placeholder:SetText(self:Text("NOTE_PLACEHOLDER"))
		UpdatePlaceholder(frame.price)
		UpdatePlaceholder(frame.note)
		MatchFieldWidth(frame.price, frame.note)
		if frame.errorText and frame.errorText:IsShown() then
			frame.errorText:SetText(self:Text("COMMISSION_INVALID"))
		end
	end
	if defaults then
		defaults.title:SetText("ArtisanFinder")
		defaults.defaultsHeader:SetText(self:Text("DEFAULT_COMMISSION"))
		defaults.itemSectionHeader:SetText(self:Text("CRAFTER_PANEL_ITEM_SECTION"))
		defaults.scanHeader:SetText(self:Text("CRAFTER_PANEL_SCAN_SECTION"))
		defaults.advertisingHeader:SetText(self:Text("CRAFTER_PANEL_ADVERTISING_SECTION"))
		defaults.priceLabel:SetText(self:Text("COMMISSION"))
		defaults.noteLabel:SetText(self:Text("NOTE"))
		defaults.price.Placeholder:SetText(self:Text("COMMISSION_PLACEHOLDER"))
		defaults.note.Placeholder:SetText(self:Text("NOTE_PLACEHOLDER"))
		defaults.advertiseCheck.Text:SetText(self:Text("CRAFTER_PANEL_ADVERTISE_PROFESSION"))
		UpdatePlaceholder(defaults.price)
		UpdatePlaceholder(defaults.note)
		FitStackedDefaultNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save, defaults.discard)
		FitCrafterCommissionFields(defaults, frame)
		if defaults.errorText and defaults.errorText:IsShown() then
			defaults.errorText:SetText(self:Text("COMMISSION_INVALID"))
		end
		self:UpdateScanControls()
	end
end

function AF:LayoutCrafterSections()
	local defaults = self.crafterDefaultsFrame
	local frame = self.crafterFrame
	if not defaults or not frame or self.crafterDefaultsCollapsed then
		return
	end
	local states = self.db.crafterSections
	local y = 33
	local function boundaryAfter(region, fallback)
		local panelTop = defaults:GetTop()
		local regionBottom = region and region:IsShown() and region:GetBottom()
		if panelTop and regionBottom then
			return math.ceil(panelTop - regionBottom + SECTION_BOTTOM_GAP)
		end
		return fallback
	end
	local function placeDividerAfterActionRow(divider, actionPanel, fallback)
		local boundary = HasPanelError(actionPanel) and actionPanel.errorText or actionPanel.save
		divider:ClearAllPoints()
		divider:SetPoint("TOPLEFT", boundary, "BOTTOMLEFT", actionPanel == defaults and -80 or -78, -SECTION_BOTTOM_GAP)
		divider:SetPoint("RIGHT", defaults, "RIGHT", -12, 0)
		return fallback
	end
	local function placeToggle(button, collapsed, belowSeparator)
		button:ClearAllPoints()
		button:SetPoint("TOP", defaults, "TOP", 0, belowSeparator and -(y + 2) or -(y - 8))
		button:SetShown(true)
		if collapsed then
			button.arrow:SetAtlas("minimal-scrollbar-arrow-bottom", true)
		else
			button.arrow:SetAtlas("minimal-scrollbar-arrow-top", true)
		end
		button.arrow:SetAlpha(1)
		button.arrow:SetVertexColor(0.72, 0.72, 0.72)
	end

	local defaultCollapsed = states.defaults == true
	placeToggle(defaults.defaultSectionToggle, defaultCollapsed)
	defaults.defaultsHeader:ClearAllPoints()
	defaults.defaultsHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -y)
	defaults.defaultsHeader:Show()
	for _, region in ipairs({ defaults.priceLabel, defaults.noteLabel, defaults.info, defaults.priceField, defaults.noteField, defaults.save, defaults.discard }) do
		region:SetShown(not defaultCollapsed)
	end
	defaults.errorText:SetShown(not defaultCollapsed and defaults.errorText:GetText() ~= "")
	if not defaultCollapsed then
		defaults.priceLabel:ClearAllPoints()
		defaults.noteLabel:ClearAllPoints()
		defaults.priceLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + 28))
		defaults.noteLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + 69))
		defaults.price.Field:ClearAllPoints()
		defaults.note.Field:ClearAllPoints()
		defaults.price.Field:SetPoint("TOPLEFT", defaults, "TOPLEFT", COMMISSION_FIELD_LEFT, -(y + 20))
		defaults.note.Field:SetPoint("TOPLEFT", defaults, "TOPLEFT", COMMISSION_FIELD_LEFT, -(y + 61))
		y = y + (HasPanelError(defaults) and 162 or 131)
	else
		y = y + COLLAPSED_SECTION_HEIGHT
	end

	local itemDirty = frame.artisanFinderDirty == true or IsEditBoxDirty(frame.price) or IsEditBoxDirty(frame.note)
	local itemCollapsed = states.item == true and not itemDirty
	defaults.itemDivider:ClearAllPoints()
	if not defaultCollapsed then
		y = placeDividerAfterActionRow(defaults.itemDivider, defaults, y)
	else
		defaults.itemDivider:SetPoint("TOPLEFT", defaults, "TOPLEFT", 12, -y)
		defaults.itemDivider:SetPoint("TOPRIGHT", defaults, "TOPRIGHT", -12, -y)
	end
	placeToggle(defaults.itemSectionToggle, itemCollapsed, true)
	defaults.itemSectionHeader:ClearAllPoints()
	defaults.itemSectionHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + COLLAPSED_TITLE_OFFSET))
	defaults.itemSectionHeader:SetShown(itemCollapsed or frame.artisanFinderHasContext ~= true)
	frame:SetShown(frame.artisanFinderHasContext == true and not itemCollapsed)
	frame.errorText:SetShown(frame:IsShown() and (frame.errorText:GetText() or "") ~= "")
	if frame.artisanFinderHasContext and not itemCollapsed then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + SECTION_GAP))
		frame:SetHeight(HasPanelError(frame) and 161 or 130)
		y = y + SECTION_GAP + (HasPanelError(frame) and 161 or 130)
	else
		y = y + COLLAPSED_SECTION_HEIGHT
	end

	local scanCollapsed = states.scan == true
	if frame.artisanFinderHasContext and not itemCollapsed then
		y = placeDividerAfterActionRow(defaults.scanDivider, frame, y)
	else
		defaults.scanDivider:ClearAllPoints()
		defaults.scanDivider:SetPoint("TOPLEFT", defaults, "TOPLEFT", 12, -y)
		defaults.scanDivider:SetPoint("TOPRIGHT", defaults, "TOPRIGHT", -12, -y)
	end
	placeToggle(defaults.scanSectionToggle, scanCollapsed, true)
	defaults.scanHeader:ClearAllPoints()
	defaults.scanHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + (scanCollapsed and COLLAPSED_TITLE_OFFSET or SECTION_GAP)))
	defaults.scanHeader:Show()
	defaults.forceRescanButton:SetShown(not scanCollapsed)
	defaults.scanProgressText:SetShown(not scanCollapsed and defaults.scanProgressText:GetText() ~= "")
	if not scanCollapsed then
		defaults.forceRescanButton:ClearAllPoints()
		defaults.forceRescanButton:SetPoint("TOPLEFT", defaults, "TOPLEFT", 92, -(y + 23))
		y = boundaryAfter(defaults.forceRescanButton, y + 51)
	else
		y = y + COLLAPSED_SECTION_HEIGHT
	end

	local advertisingCollapsed = states.advertising == true
	defaults.advertisingDivider:ClearAllPoints()
	defaults.advertisingDivider:SetPoint("TOPLEFT", defaults, "TOPLEFT", 12, -y)
	defaults.advertisingDivider:SetPoint("TOPRIGHT", defaults, "TOPRIGHT", -12, -y)
	placeToggle(defaults.advertisingSectionToggle, advertisingCollapsed, true)
	defaults.advertisingHeader:Show()
	defaults.advertiseCheck:SetShown(not advertisingCollapsed)
	if not advertisingCollapsed then
		defaults.advertisingHeader:ClearAllPoints()
		defaults.advertiseCheck:ClearAllPoints()
		defaults.advertisingHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + SECTION_GAP))
		defaults.advertiseCheck:SetPoint("TOPLEFT", defaults, "TOPLEFT", 10, -(y + 45))
		y = boundaryAfter(defaults.advertiseCheck, y + 75)
	else
		defaults.advertisingHeader:ClearAllPoints()
		defaults.advertisingHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + COLLAPSED_TITLE_OFFSET))
		y = y + COLLAPSED_SECTION_HEIGHT
	end
	defaults:SetHeight(math.max(120, y))
end

function AF:ApplyCrafterDefaultsCollapsed(collapsed)
	local defaults = self.crafterDefaultsFrame
	if not defaults then
		return
	end

	self.crafterDefaultsCollapsed = collapsed and true or false
	defaults:SetWidth(self.crafterDefaultsCollapsed and 28 or DEFAULT_COMMISSION_PANEL_WIDTH)
	defaults:SetShown(not self.crafterDefaultsCollapsed)
	for _, region in ipairs(defaults.collapsibleRegions or {}) do
		region:SetShown(not self.crafterDefaultsCollapsed)
	end
	defaults.title:SetShown(not self.crafterDefaultsCollapsed)
	defaults.TitleContainer:SetShown(not self.crafterDefaultsCollapsed)
	defaults.NineSlice:SetShown(not self.crafterDefaultsCollapsed)
	defaults.Bg:SetShown(not self.crafterDefaultsCollapsed)
	defaults.TopTileStreaks:SetShown(not self.crafterDefaultsCollapsed)
	defaults.collapsedRail:SetShown(false)
	defaults.collapsedRail:ClearAllPoints()
	defaults.collapsedRail:SetPoint("TOPLEFT", defaults, "TOPLEFT", 0, 0)
	defaults.collapsedRail:SetPoint("BOTTOMRIGHT", defaults, "BOTTOMRIGHT", 0, 0)
	if defaults.collapseButton then
		defaults.collapseButton:Hide()
	end

	local collapseButton = self.crafterDefaultsCollapseButton
	if collapseButton then
		collapseButton:ClearAllPoints()
		if self.crafterDefaultsCollapsed then
			local form = self:GetCraftingSchematicForm()
			local anchor = form and form.Details or form or ProfessionsFrame
			collapseButton:SetPoint("LEFT", anchor, "RIGHT", -1, 0)
			collapseButton:SetMaximizedLook()
		else
			collapseButton:SetPoint("TOPRIGHT", defaults, "TOPRIGHT", 1, 0)
			collapseButton:SetMinimizedLook()
		end
		self:RaiseButtonAboveAnchor(collapseButton, ProfessionsFrame, CRAFTER_COLLAPSE_BUTTON_LEVEL_OFFSET)
		collapseButton:Show()
	end
end

function AF:SetCrafterDefaultsCollapsed(collapsed)
	self:ApplyCrafterDefaultsCollapsed(collapsed)
	self:RefreshCrafterUI()
end

function AF:GetCraftingSchematicForm()
	if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then
		return nil
	end
	return ProfessionsFrame.CraftingPage.SchematicForm
end

function AF:IsLinkedProfessionOpen()
	return C_TradeSkillUI.IsTradeSkillLinked() == true
		or C_TradeSkillUI.IsTradeSkillGuild() == true
		or C_TradeSkillUI.IsTradeSkillGuildMember() == true
end

function AF:IsOwnProfessionWindowOpen()
	local form = self:GetCraftingSchematicForm()
	return ProfessionsFrame
		and ProfessionsFrame:IsShown()
		and form
		and form:IsVisible()
		and not self:IsLinkedProfessionOpen()
		or false
end

function AF:IsProfessionPanelMinimized()
	return ProfessionsUtil and ProfessionsUtil.IsCraftingMinimized and ProfessionsUtil.IsCraftingMinimized() == true
end

function AF:EnsureCrafterReopenButton()
	if self.crafterReopenButton then
		return self.crafterReopenButton
	end
	local form = self:GetCraftingSchematicForm()
	if not form then
		return nil
	end

	local button = CreateFrame("Button", "ArtisanFinderCrafterReopenButton", form, "ArtisanFinderCrafterReopenButtonTemplate")
	button:SetFrameLevel((form:GetFrameLevel() or 0) + 20)
	button.icon:SetTexture(CRAFTER_REOPEN_ICON)
	button:SetScript("OnClick", function()
		if ProfessionsFrame and ProfessionsFrame.SetMaximized then
			ProfessionsFrame:SetMaximized()
		elseif ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SetMaximized then
			ProfessionsFrame.CraftingPage:SetMaximized()
		end
		AF:RefreshCrafterUI()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("ArtisanFinder", 1, 0.82, 0)
		GameTooltip:AddLine(AF:Text("CRAFTER_REOPEN_TOOLTIP"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Hide()
	self.crafterReopenButton = button
	return button
end

function AF:RefreshCrafterReopenButton()
	local button = self:EnsureCrafterReopenButton()
	local form = self:GetCraftingSchematicForm()
	if not button or not form then
		return
	end
	button:ClearAllPoints()
	button:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -8, 8)
	button:SetShown(self:IsOwnProfessionWindowOpen() and self:IsProfessionPanelMinimized())
end

function AF:GetCurrentCraftingRecipeContext()
	if not self:IsOwnProfessionWindowOpen() then
		return nil
	end

	local form = self:GetCraftingSchematicForm()
	if not form or not form.GetRecipeInfo then
		return nil
	end

	local recipeInfo = form:GetRecipeInfo()
	if not recipeInfo or not recipeInfo.recipeID then
		return nil
	end

	local recipeID = recipeInfo.recipeID
	local currentProfession = self:GetCurrentProfessionInfo()
	if not currentProfession then
		return nil
	end

	local professionInfo
	local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
	if ok then
		professionInfo = info
	end
	if professionInfo and not self:ProfessionInfoMatchesProfession(currentProfession, professionInfo) then
		return nil
	end
	if not professionInfo and not self:RecipeBelongsToProfession(currentProfession, recipeInfo, self:GetCurrentProfessionCategoryIDs(), recipeID) then
		return nil
	end

	local isRecraft = recipeInfo.isRecraft == true or form.isRecraft == true
	if not isRecraft and form.transaction and form.transaction.IsRecraft then
		isRecraft = form.transaction:IsRecraft() == true
	end

	local itemID
	local outputs = self:GetRecipeOutputItemIDs(recipeID)
	for outputItemID in pairs(outputs) do
		if not itemID or tonumber(outputItemID) < tonumber(itemID) then
			itemID = outputItemID
		end
	end

	local professionID = currentProfession.id
	professionID = self:GetSupportedProfessionID(professionID, currentProfession)
	if not professionID then
		return nil
	end

	return itemID and {
		itemID = itemID,
		recipeID = recipeID,
		learned = recipeInfo.learned ~= false,
		isRecraft = isRecraft,
		professionID = professionID,
		professionIcon = currentProfession.icon,
	} or nil
end

function AF:GetCurrentSupportedProfessionID()
	local profession = self:GetCurrentProfessionInfo()
	return self:GetSupportedProfessionID(profession and profession.id, profession), profession
end

function AF:EnsureCurrentRecipeEntry(context, options)
	if not context or not context.itemID then
		return nil
	end
	if not self:IsOwnProfessionWindowOpen() then
		return nil
	end
	options = options or {}

	local itemKey = tostring(context.itemID)
	local item = self.db.artisanProfile.items[itemKey] or {}
	self.db.artisanProfile.items[itemKey] = item
	item.itemID = context.itemID
	item.recipeID = context.recipeID
	item.professionID = context.professionID or item.professionID
	item.recipeName = nil
	item.itemName = nil
	item.professionName = nil
	item.professionIcon = context.professionIcon or item.professionIcon
	if options.fullCapability then
		self:ApplyRecipeCapability(item, context.recipeID)
	else
		local probe = self:GetRecipeSkillProbe(context.recipeID)
		if probe then
			self:ApplyRecipeSkillProbe(item, context.recipeID, probe)
		end
		item.professionLink = self:CaptureCurrentProfessionLink() or item.professionLink
	end
	item.updatedAt = self:Now()

	if context.professionID then
		local professionKey = tostring(context.professionID)
		local profession = self.db.artisanProfile.professions[professionKey] or {
			id = context.professionID,
			recipes = {},
		}
		self.db.artisanProfile.professions[professionKey] = profession
		profession.name = nil
		profession.icon = context.professionIcon or profession.icon
		profession.updatedAt = self:Now()
		profession.professionLink = item.professionLink or profession.professionLink
		profession.recipes = profession.recipes or {}
		profession.recipes[tostring(context.recipeID)] = true
	end

	return item
end

function AF:IsRecipeEntryScanComplete(context, item)
	if not context or not item then
		return false
	end
	if not item.bestReagents or item.bestReagentPendingNames == true then
		return false
	end
	local active = self.activeScan
	if not active or tonumber(active.professionID) ~= tonumber(context.professionID) then
		return true
	end
	local professionEntry = self.db
		and self.db.artisanProfile
		and self.db.artisanProfile.professions
		and self.db.artisanProfile.professions[tostring(active.professionID)]
	local progress = professionEntry and professionEntry.scanProgress
	if not progress or progress.signature ~= active.signature then
		return true
	end
	local recipeID = tonumber(context.recipeID) or 0
	local itemID = tonumber(context.itemID) or 0
	for index = math.max(1, tonumber(progress.pendingIndex) or 1), #(progress.pending or {}) do
		local job = progress.pending[index]
		if tonumber(job and job.recipeID) == recipeID and tonumber(job and job.itemID) == itemID then
			return false
		end
	end
	return progress.completed and (progress.completed["full:" .. recipeID .. ":" .. itemID] or progress.completed["probe:" .. recipeID .. ":" .. itemID]) == true
end

function AF:AttachCrafterUI()
	local form = self:GetCraftingSchematicForm()
	if self.crafterFrame or not form then
		return
	end

	local defaults = CreateFrame("Frame", "ArtisanFinderProfessionDefaultsFrame", ProfessionsFrame, "ArtisanFinderProfessionDefaultsTemplate")
	self:ApplyCustomerSidePanel(defaults)
	defaults.title = defaults.TitleContainer.TitleText
	defaults.title:SetText("ArtisanFinder")
	defaults.collapseButton:Hide()
	if self.SetupCrafterTutorialButton then
		self:SetupCrafterTutorialButton(defaults)
	end

	local frame = CreateFrame("Frame", "ArtisanFinderCrafterFrame", defaults, "ArtisanFinderCrafterItemTemplate")
	frame:SetPoint("TOPLEFT", defaults.itemSection, "TOPLEFT", 0, 0)
	frame.info = ConfigureInfoButton(frame.info, "ITEM_SPECIFIC_COMMISSION", "ITEM_SPECIFIC_TOOLTIP")
	frame.customerPreview = ConfigureCustomerPreviewButton(CreateCustomerPreviewButton(frame), function()
		local context = frame.artisanFinderLoadedContext
		local item = context and AF.db.artisanProfile.items[tostring(context.itemID or "")]
		local defaultEntry = context and context.professionID and AF:GetProfessionPriceEntry(AF.db.artisanProfile, context.professionID)
		if context and item and not AF:IsRecipeEntryScanComplete(context, item) then
			return item, defaultEntry, AF:Text("CUSTOMER_SIDE_PREVIEW_SCANNING")
		end
		return item, defaultEntry
	end)
	frame.customerPreview:SetPoint("RIGHT", frame.info, "LEFT", -2, 0)
	frame.headerButton:SetScript("OnEnter", function(self)
		local link = frame.artisanFinderItemLink
		if link then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)
	frame.headerButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame.headerButton:SetScript("OnClick", function()
		if frame.artisanFinderItemLink and HandleModifiedItemClick then
			HandleModifiedItemClick(frame.artisanFinderItemLink)
		end
	end)
	frame.priceLabel:SetJustifyH("LEFT")
	frame.priceLabel:SetText(self:Text("COMMISSION"))

	frame.price = PrepareInsetEditBox(frame.priceField, COMMISSION_PRICE_FIELD_WIDTH, "COMMISSION_PLACEHOLDER", true)
	SetFieldPoint(frame.price, "LEFT", frame.priceLabel, "RIGHT", 4, 0)
	frame.price:SetMaxLetters(COMMISSION_PRICE_MAX_LETTERS)

	frame.noteLabel:SetJustifyH("LEFT")
	frame.noteLabel:SetText(self:Text("NOTE"))

	frame.note = PrepareInsetEditBox(frame.noteField, 170, "NOTE_PLACEHOLDER")
	SetFieldPoint(frame.note, "LEFT", frame.noteLabel, "RIGHT", 4, 0)
	frame.note:SetMaxLetters(AF.MAX_NOTE_CHARS or 256)

	frame.errorText:ClearAllPoints()
	frame.errorText:SetPoint("TOPLEFT", frame.save, "BOTTOMLEFT", 0, -3)
	frame.errorText:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
	frame.errorText:SetHeight(28)
	frame.save:Disable()
	frame.save:SetScript("OnClick", function()
		local context = frame.artisanFinderLoadedContext
		local item = AF:EnsureCurrentRecipeEntry(context)
		if not item or not context or context.learned == false then
			AF:Print(AF:Text("SELECT_LEARNED_CRAFT"))
			return
		end

		local copper, free, state = ParseCommissionOrWarn(frame.price, frame)
		if not copper then
			return
		end

		AF:SetItemPrice(item.itemID, copper, free, frame.note:GetText(), state)
		SetEditBoxText(frame.price, AF:FormatCommissionInput(item))
		SetEditBoxText(frame.note, item.note or "")
		frame.price.artisanFinderDirty = false
		frame.note.artisanFinderDirty = false
		frame.artisanFinderDirty = false
		AF:RefreshCrafterUI()
	end)
	frame.discard:SetScript("OnClick", function()
		local context = frame.artisanFinderLoadedContext
		local item = context and AF.db.artisanProfile.items[tostring(context.itemID or "")]
		SetEditBoxText(frame.price, item and AF:FormatCommissionInput(item) or "")
		SetEditBoxText(frame.note, item and item.note or "")
		frame.artisanFinderDirty = false
		frame.price.artisanFinderDirty = false
		frame.note.artisanFinderDirty = false
		frame.artisanFinderInputSource = nil
		frame.artisanFinderLoadedContext = nil
		frame.artisanFinderErrorSource = nil
		ClearPanelError(frame)
		AF:RefreshCrafterUI()
	end)

	local collapseButton = CreateFrame("Frame", "ArtisanFinderCrafterDefaultsCollapseButton", ProfessionsFrame, "MaximizeMinimizeButtonFrameTemplate")
	collapseButton:SetSize(24, 24)
	self:RaiseButtonAboveAnchor(collapseButton, ProfessionsFrame, CRAFTER_COLLAPSE_BUTTON_LEVEL_OFFSET)
	collapseButton:SetOnMinimizedCallback(function()
		AF:SetCrafterDefaultsCollapsed(true)
	end)
	collapseButton:SetOnMaximizedCallback(function()
		AF:SetCrafterDefaultsCollapsed(false)
	end)
	collapseButton:SetMinimizedLook()
	collapseButton:Hide()
	defaults.collapsedRail:SetFrameLevel(defaults:GetFrameLevel() + 5)
	self:ApplyProfessionPanel(defaults.collapsedRail)
	defaults.collapsedRail:Hide()
	defaults.defaultsDivider:Hide()
	defaults.defaultsHeader:SetText(self:Text("DEFAULT_COMMISSION"))
	defaults.itemSectionHeader:SetText(self:Text("CRAFTER_PANEL_ITEM_SECTION"))
	defaults.scanHeader:SetText(self:Text("CRAFTER_PANEL_SCAN_SECTION"))
	defaults.advertisingHeader:SetText(self:Text("CRAFTER_PANEL_ADVERTISING_SECTION"))
	defaults.info = ConfigureInfoButton(defaults.info, "DEFAULT_COMMISSION", "DEFAULT_COMMISSION_TOOLTIP")
	defaults.priceLabel:SetJustifyH("LEFT")
	defaults.priceLabel:SetText(self:Text("COMMISSION"))

	defaults.price = PrepareInsetEditBox(defaults.priceField, COMMISSION_PRICE_FIELD_WIDTH, "COMMISSION_PLACEHOLDER", true)
	SetFieldPoint(defaults.price, "LEFT", defaults.priceLabel, "RIGHT", 4, 0)
	defaults.price:SetMaxLetters(COMMISSION_PRICE_MAX_LETTERS)

	defaults.noteLabel:SetJustifyH("LEFT")
	defaults.noteLabel:SetText(self:Text("NOTE"))

	defaults.note = PrepareInsetEditBox(defaults.noteField, 128, "NOTE_PLACEHOLDER")
	SetFieldPoint(defaults.note, "LEFT", defaults.noteLabel, "RIGHT", 4, 0)
	defaults.note:SetMaxLetters(AF.MAX_NOTE_CHARS or 256)

	FitStackedDefaultNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save, defaults.discard)
	FitCrafterCommissionFields(defaults, frame)
	defaults.errorText:ClearAllPoints()
	defaults.errorText:SetPoint("TOPLEFT", defaults.save, "BOTTOMLEFT", 0, -3)
	defaults.errorText:SetPoint("RIGHT", defaults, "RIGHT", -14, 0)
	defaults.errorText:SetHeight(28)
	defaults.save:Disable()
	defaults.discard:Disable()
	defaults.save:SetScript("OnClick", function()
		local professionID = defaults.artisanFinderLoadedProfessionID or AF:GetCurrentSupportedProfessionID()
		if not professionID then
			AF:Print(AF:Text("OPEN_PROFESSION_DEFAULT"))
			return
		end

		local copper, free, state = ParseCommissionOrWarn(defaults.price, defaults)
		if not copper then
			return
		end

		AF:SetProfessionPrice(professionID, copper, free, defaults.note:GetText(), state)
		local savedDefault = AF:GetProfessionPriceEntry(AF.db.artisanProfile, professionID)
		SetDefaultsLoadedState(AF, defaults, professionID, savedDefault)
		AF:RefreshCrafterUI()
	end)
	defaults.discard:SetScript("OnClick", function()
		local professionID = defaults.artisanFinderLoadedProfessionID or AF:GetCurrentSupportedProfessionID()
		local savedDefault = professionID and AF:GetProfessionPriceEntry(AF.db.artisanProfile, professionID)
		SetPanelInputSource(defaults, "profession:" .. tostring(professionID or ""))
		SetDefaultsLoadedState(AF, defaults, professionID, savedDefault)
		ClearPanelError(defaults)
		AF:RefreshCrafterUI()
	end)

	local forceRescanButton = defaults.forceRescanButton
	forceRescanButton:SetScript("OnClick", function()
		AF:StartOrResumeCurrentProfessionScan(true, false)
		AF:RefreshCrafterUIScanSafe()
	end)
	forceRescanButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("FORCE_RESCAN_BUTTON"), 1, 0.82, 0)
		GameTooltip:AddLine(AF:Text("FORCE_RESCAN_TOOLTIP"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	forceRescanButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	defaults.advertiseCheck.Text:SetText(self:Text("CRAFTER_PANEL_ADVERTISE_PROFESSION"))
	defaults.advertiseCheck.Text:SetPoint("LEFT", defaults.advertiseCheck, "RIGHT", 2, 0)
	defaults.advertiseCheck:SetScript("OnClick", function(self)
		local professionID = AF:GetCurrentSupportedProfessionID()
		if professionID then
			AF:SetProfessionAdvertised(AF.playerName, professionID, self:GetChecked() == true)
		end
	end)
	ConfigureSectionToggle(defaults.defaultSectionToggle, "defaults", "DEFAULT_COMMISSION")
	ConfigureSectionToggle(defaults.itemSectionToggle, "item", "ITEM_SPECIFIC_COMMISSION")
	ConfigureSectionToggle(defaults.scanSectionToggle, "scan", "CRAFTER_PANEL_SCAN_SECTION")
	ConfigureSectionToggle(defaults.advertisingSectionToggle, "advertising", "CRAFTER_PANEL_ADVERTISING_SECTION")

	local markItemDirty = function()
		ClampCommissionEditBox(frame.price)
		ValidateCommissionInput(frame.price, frame)
		frame.artisanFinderDirty = IsEditBoxDirty(frame.price) or IsEditBoxDirty(frame.note)
		AF:UpdateCrafterDirtyState()
	end
	local markDefaultDirty = function()
		ClampCommissionEditBox(defaults.price)
		ValidateCommissionInput(defaults.price, defaults)
		defaults.artisanFinderDirty = IsDefaultsSaveDirty(defaults)
		AF:UpdateCrafterDirtyState()
	end
	WatchEditBox(frame.price, markItemDirty)
	WatchEditBox(frame.note, markItemDirty)
	WatchEditBox(defaults.price, markDefaultDirty)
	WatchEditBox(defaults.note, markDefaultDirty)
	SaveOnEnter(frame.price, frame.save)
	SaveOnEnter(frame.note, frame.save)
	SaveOnEnter(defaults.price, defaults.save)
	SaveOnEnter(defaults.note, defaults.save)

	self.crafterFrame = frame
	self.crafterDefaultsFrame = defaults
	self.crafterDefaultsCollapseButton = collapseButton
	self.crafterForceRescanButton = forceRescanButton
	self.crafterScanProgressText = defaults.scanProgressText
	defaults.collapsibleRegions = {
		defaults.tutorialButton,
		defaults.defaultsHeader,
		defaults.itemSectionHeader,
		defaults.priceLabel,
		defaults.noteLabel,
		defaults.itemDivider,
		defaults.advertisingDivider,
		defaults.defaultSectionToggle,
		defaults.itemSectionToggle,
		defaults.scanSectionToggle,
		defaults.advertisingSectionToggle,
		frame,
		defaults.scanHeader,
		defaults.scanDivider,
		defaults.advertisingHeader,
		defaults.info,
		defaults.priceField,
		defaults.noteField,
		defaults.save,
		defaults.discard,
		defaults.forceRescanButton,
		defaults.scanProgressText,
		defaults.errorText,
		defaults.advertiseCheck,
	}

	if form.RegisterCallback and ProfessionsRecipeSchematicFormMixin then
		local refresh = function()
			AF:RefreshCrafterUI()
		end
		form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, refresh)
		form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified, refresh)
	end

	if form.Init then
		hooksecurefunc(form, "Init", function()
			AF:RefreshCrafterUI()
		end)
	end
	if ProfessionsFrame and not self.crafterProfessionMinimizeHooked then
		self.crafterProfessionMinimizeHooked = true
		hooksecurefunc(ProfessionsFrame, "SetMinimized", function()
			AF:RefreshCrafterUI()
		end)
		hooksecurefunc(ProfessionsFrame, "SetMaximized", function()
			AF:RefreshCrafterUI()
		end)
	end

	self:RefreshCrafterUI()
end

function AF:PositionCrafterUI()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	local form = self:GetCraftingSchematicForm()
	if not frame or not defaults or not form then
		return
	end

	defaults:ClearAllPoints()
	defaults:SetPoint("BOTTOMLEFT", ProfessionsFrame, "BOTTOMRIGHT", -5, 24)
end

function AF:UpdateCrafterScanProgressText()
	local scanProgressText = self.crafterScanProgressText
	local defaults = self.crafterDefaultsFrame
	if not scanProgressText or not defaults then
		return
	end

	local active = self.activeScan
	local professionEntry = active
		and self.db
		and self.db.artisanProfile
		and self.db.artisanProfile.professions
		and self.db.artisanProfile.professions[tostring(active.professionID)]
	local progress = professionEntry and professionEntry.scanProgress
	if active and progress and progress.signature == active.signature then
		local total = tonumber(progress.total) or 0
		local completed = tonumber(progress.completedCount) or self:TableCount(progress.completed)
		local percent = total > 0 and math.floor((completed / total) * 100) or 0
		percent = math.max(0, math.min(100, percent))
		scanProgressText:SetText(string.format("%d%%", percent))
		scanProgressText:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed)
	else
		scanProgressText:SetText("")
		scanProgressText:Hide()
	end
end

function AF:IsActiveScanForCurrentProfession()
	local active = self.activeScan
	if not active or not active.professionID then
		return false
	end
	local currentProfessionID = self:GetCurrentSupportedProfessionID()
	return currentProfessionID and tonumber(active.professionID) == tonumber(currentProfessionID) or false
end

function AF:RefreshCrafterUIScanSafe()
	if self:IsActiveScanForCurrentProfession() then
		self:UpdateCrafterScanProgressText()
	else
		self:RefreshCrafterUI()
	end
end

function AF:UpdateScanControls()
	local forceRescanButton = self.crafterForceRescanButton
	local scanProgressText = self.crafterScanProgressText
	local defaults = self.crafterDefaultsFrame
	if not defaults then
		return
	end
	local active = self.activeScan
	local currentProfessionID = self:GetCurrentSupportedProfessionID()
	if forceRescanButton then
		SizeButtonForText(forceRescanButton, self:Text("FORCE_RESCAN_BUTTON"), 76, 120)
		if currentProfessionID and not active then
			forceRescanButton:Enable()
		else
			forceRescanButton:Disable()
		end
		forceRescanButton:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed and self.db.crafterSections.scan ~= true)
	end
	if scanProgressText then
		if forceRescanButton then
			scanProgressText:ClearAllPoints()
			scanProgressText:SetPoint("LEFT", forceRescanButton, "RIGHT", 8, 0)
		end
		self:UpdateCrafterScanProgressText()
	end
end

function AF:UpdateCrafterDirtyState()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	if not frame or not defaults then
		return
	end

	local context = self:GetCurrentCraftingRecipeContext()
	local item = context and self.db.artisanProfile.items[tostring(context.itemID or "")]
	local itemDirty = frame.artisanFinderDirty == true or IsEditBoxDirty(frame.price) or IsEditBoxDirty(frame.note)
	if not itemDirty and item then
		itemDirty = self:IsCommissionInputDirty(frame.price:GetText(), item)
			or (frame.note:GetText() or "") ~= (item.note or "")
	end
	if itemDirty and not HasPanelError(frame) then
		frame.save:Enable()
	else
		frame.save:Disable()
	end
	if itemDirty then
		frame.discard:Enable()
	else
		frame.discard:Disable()
	end

	if ShouldEnableDefaultsSave(self, defaults) then
		defaults.save:Enable()
		defaults.discard:Enable()
	else
		defaults.save:Disable()
		defaults.discard:Disable()
	end
end

function AF:RefreshCrafterUI()
	self:AttachCrafterUI()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	if not frame or not defaults then
		return
	end

	if not self:IsOwnProfessionWindowOpen() or self:IsProfessionPanelMinimized() then
		frame:Hide()
		defaults:Hide()
		if self.crafterDefaultsCollapseButton then
			self.crafterDefaultsCollapseButton:Hide()
		end
		self:RefreshCrafterReopenButton()
		return
	end
	self:RefreshCrafterReopenButton()

	self:PositionCrafterUI()

	local context = self:GetCurrentCraftingRecipeContext()
	local currentProfessionID, profession = self:GetCurrentSupportedProfessionID()
	local defaultsProfessionID = GetDefaultsRefreshProfessionID(self, defaults, currentProfessionID)
	if not currentProfessionID and not defaultsProfessionID then
		frame:Hide()
		defaults:Hide()
		if self.crafterDefaultsCollapseButton then
			self.crafterDefaultsCollapseButton:Hide()
		end
		return
	end
	self:UpdateScanControls()

	local itemProfessionID = context and context.professionID or currentProfessionID
	if itemProfessionID then
		self:CaptureCurrentProfessionLink(profession or { id = itemProfessionID }, "crafter-ui-refresh")
	end
	if not context or context.learned == false or context.isRecraft then
		if not (frame.artisanFinderDirty == true or IsEditBoxDirty(frame.price) or IsEditBoxDirty(frame.note)) then
			frame.artisanFinderHasContext = false
			frame:Hide()
		end
	else
		local currentSourceKey = table.concat({ "item", tostring(context.itemID or ""), tostring(context.recipeID or ""), tostring(context.professionID or "") }, ":")
		local dirty = frame.artisanFinderDirty == true or IsEditBoxDirty(frame.price) or IsEditBoxDirty(frame.note)
		local loadedContext = frame.artisanFinderLoadedContext
		if dirty and loadedContext and frame.artisanFinderInputSource ~= currentSourceKey then
			context = loadedContext
		end
		local item = self:EnsureCurrentRecipeEntry(context)
		if item then
			frame.artisanFinderHasContext = true
			frame.artisanFinderLoadedContext = CopyTable(context)
			local itemName, itemLink = C_Item.GetItemInfo(context.itemID)
			frame.artisanFinderItemLink = itemLink
			frame.headerButton:SetEnabled(itemLink ~= nil)
			if itemName and itemLink then
				frame.header:SetText(self:Text("ITEM_CONTEXT_HEADER", itemLink))
			else
				frame.header:SetText(self:Text("ITEM_CONTEXT_LOADING"))
				pcall(C_Item.RequestLoadItemDataByID, context.itemID)
			end
			if frame.customerPreview then
				if self:IsRecipeEntryScanComplete(context, item) then
					frame.customerPreview:Enable()
					frame.customerPreview:SetAlpha(1)
				else
					frame.customerPreview:Disable()
					frame.customerPreview:SetAlpha(0.45)
				end
			end
			local sourceKey = table.concat({ "item", tostring(context.itemID or ""), tostring(context.recipeID or ""), tostring(context.professionID or "") }, ":")
			if frame.artisanFinderErrorSource ~= sourceKey then
				frame.artisanFinderErrorSource = sourceKey
				ClearPanelError(frame)
			end
			SetPanelInputSource(frame, sourceKey)
			SetEditBoxTextForSource(frame.price, self:FormatCommissionInput(item), sourceKey)
			SetEditBoxTextForSource(frame.note, item.note or "", sourceKey)
		else
			ClearPanelError(frame)
			frame.artisanFinderHasContext = false
			frame:Hide()
		end
	end

	if defaultsProfessionID then
		defaults:Show()
		self:ApplyCrafterDefaultsCollapsed(self.crafterDefaultsCollapsed)
		self:LayoutCrafterSections()
		if self.MaybeShowCrafterTutorial then
			self:MaybeShowCrafterTutorial()
		end
		defaults.advertiseCheck:SetChecked(self:IsProfessionAdvertised(self.playerName, defaultsProfessionID))
		local sourceKey = RefreshDefaultsTextForProfession(self, defaults, defaultsProfessionID)
		if defaults.artisanFinderErrorSource ~= sourceKey then
			defaults.artisanFinderErrorSource = sourceKey
			ClearPanelError(defaults)
		end
	else
		ClearPanelError(defaults)
		defaults:Hide()
		if self.crafterDefaultsCollapseButton then
			self.crafterDefaultsCollapseButton:Hide()
		end
	end

	self:UpdateScanControls()
	self:UpdateCrafterDirtyState()
end

function AF:FocusCrafterUI()
	self:AttachCrafterUI()
	if self.crafterFrame then
		self.crafterFrame:Show()
		self:RefreshCrafterUI()
	end
end
