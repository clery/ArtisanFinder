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
local SHOP_ROW_PREVIEW_WIDTH = 154
local SHOP_ROW_PREVIEW_HEIGHT = 72
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

local function IsShopSaveDirty(defaults)
	if not defaults
		or not defaults.shopName
		or not defaults.shopRowColorButton
		or not defaults.shopIconColorButton
		or not defaults.shopEmblemStyle
		or not defaults.shopRowTextureStyle
	then
		return false
	end
	if defaults.artisanFinderLoadedShopName == nil then
		return defaults.artisanFinderShopDirty == true
	end
	return (defaults.shopName:GetText() or "") ~= defaults.artisanFinderLoadedShopName
		or (defaults.shopRowColorButton.artisanFinderColorHex or "") ~= defaults.artisanFinderLoadedShopRowColor
		or (defaults.shopIconColorButton.artisanFinderColorHex or "") ~= defaults.artisanFinderLoadedShopIconColor
		or (defaults.shopEmblemStyle:GetText() or "") ~= defaults.artisanFinderLoadedShopEmblemStyle
		or (defaults.shopRowTextureStyle:GetText() or "") ~= defaults.artisanFinderLoadedShopRowTextureStyle
end

local function SetShopError(defaults, message)
	if defaults and defaults.shopErrorText then
		defaults.shopErrorText:SetText(message or "")
		defaults.shopErrorText:SetShown(message ~= nil and message ~= "")
	end
end

local function HasShopError(defaults)
	return defaults and defaults.shopErrorText and defaults.shopErrorText:IsShown()
end

local function GetHexFromRGBA(r, g, b, a)
	return string.format(
		"%02x%02x%02x%02x",
		math.max(0, math.min(255, math.floor((tonumber(r) or 0) * 255 + 0.5))),
		math.max(0, math.min(255, math.floor((tonumber(g) or 0) * 255 + 0.5))),
		math.max(0, math.min(255, math.floor((tonumber(b) or 0) * 255 + 0.5))),
		math.max(0, math.min(255, math.floor((tonumber(a) or 1) * 255 + 0.5)))
	)
end

local function SetShopColorButtonHex(button, hex, fallback)
	if not button then
		return
	end
	hex = AF:NormalizeShopColor(hex, fallback)
	button.artisanFinderColorHex = hex
	local r, g, b, a = AF:GetShopColorRGBA(hex, fallback)
	if button.Swatch and r then
		button.Swatch:SetVertexColor(r, g, b, a or 1)
	end
end

local function OpenShopColorPicker(button, fallback, onChanged)
	if not button or not ColorPickerFrame then
		return
	end
	local r, g, b, a = AF:GetShopColorRGBA(button.artisanFinderColorHex, fallback)
	local apply = function(red, green, blue, alpha)
		SetShopColorButtonHex(button, GetHexFromRGBA(red, green, blue, alpha), fallback)
		if onChanged then
			onChanged()
		end
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r or 1,
		g = g or 1,
		b = b or 1,
		opacity = a or 1,
		hasOpacity = true,
		swatch = button,
		swatchFunc = function()
			local red, green, blue = ColorPickerFrame:GetColorRGB()
			apply(red, green, blue, ColorPickerFrame:GetColorAlpha())
		end,
		opacityFunc = function()
			local red, green, blue = ColorPickerFrame:GetColorRGB()
			apply(red, green, blue, ColorPickerFrame:GetColorAlpha())
		end,
		cancelFunc = function()
			apply(ColorPickerFrame:GetPreviousValues())
		end,
	})
end

local function CreatePlainBorder(parent, thickness, r, g, b, alpha)
	local border = CreateFrame("Frame", nil, parent)
	border:EnableMouse(false)
	border.Top = border:CreateTexture(nil, "OVERLAY")
	border.Top:SetTexture("Interface\\Buttons\\WHITE8x8")
	border.Top:SetPoint("TOPLEFT")
	border.Top:SetPoint("TOPRIGHT")
	border.Top:SetHeight(thickness or 1)
	border.Bottom = border:CreateTexture(nil, "OVERLAY")
	border.Bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
	border.Bottom:SetPoint("BOTTOMLEFT")
	border.Bottom:SetPoint("BOTTOMRIGHT")
	border.Bottom:SetHeight(thickness or 1)
	border.Left = border:CreateTexture(nil, "OVERLAY")
	border.Left:SetTexture("Interface\\Buttons\\WHITE8x8")
	border.Left:SetPoint("TOPLEFT")
	border.Left:SetPoint("BOTTOMLEFT")
	border.Left:SetWidth(thickness or 1)
	border.Right = border:CreateTexture(nil, "OVERLAY")
	border.Right:SetTexture("Interface\\Buttons\\WHITE8x8")
	border.Right:SetPoint("TOPRIGHT")
	border.Right:SetPoint("BOTTOMRIGHT")
	border.Right:SetWidth(thickness or 1)
	border.SetBorderColor = function(self, red, green, blue, opacity)
		for _, line in ipairs({ self.Top, self.Bottom, self.Left, self.Right }) do
			line:SetVertexColor(red or 1, green or 1, blue or 1, opacity or 1)
		end
	end
	border:SetBorderColor(r or 0.58, g or 0.47, b or 0.24, alpha or 0.9)
	return border
end

local function CreateShopColorButton(parent, anchor, fallback, onChanged)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(24, 24)
	button:SetPoint(unpack(anchor))
	button.Background = button:CreateTexture(nil, "BACKGROUND")
	button.Background:SetTexture("Interface\\Buttons\\WHITE8x8")
	button.Background:SetAllPoints()
	button.Background:SetVertexColor(0.02, 0.02, 0.02, 1)
	button.Swatch = button:CreateTexture(nil, "ARTWORK")
	button.Swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
	button.Swatch:SetPoint("TOPLEFT", 4, -4)
	button.Swatch:SetPoint("BOTTOMRIGHT", -4, 4)
	button.Border = CreatePlainBorder(button, 1, 0.78, 0.63, 0.28, 0.85)
	button.Border:SetPoint("TOPLEFT", -1, 1)
	button.Border:SetPoint("BOTTOMRIGHT", 1, -1)
	button.SetColorRGB = function(self, r, g, b)
		local _, _, _, a = AF:GetShopColorRGBA(self.artisanFinderColorHex, fallback)
		SetShopColorButtonHex(self, GetHexFromRGBA(r, g, b, a), fallback)
	end
	button:SetScript("OnEnter", function(self)
		if self.Border then
			self.Border:SetBorderColor(1, 0.82, 0, 1)
		end
	end)
	button:SetScript("OnLeave", function(self)
		if self.Border then
			self.Border:SetBorderColor(0.78, 0.63, 0.28, 0.85)
		end
	end)
	button:SetScript("OnClick", function(self)
		OpenShopColorPicker(self, fallback, onChanged or self.artisanFinderOnChanged)
	end)
	SetShopColorButtonHex(button, fallback, fallback)
	return button
end

local function ApplyShopRowTextureVisual(texture, rowTextureStyle, hex, fallback, alpha)
	return AF:ApplyShopRowTextureVisual(texture, rowTextureStyle, hex, fallback, alpha)
end

local function SetShopPreviewTexture(defaults, cosmetics)
	if not defaults or not defaults.shopPreviewBackground then
		return
	end
	local rowTextureStyle = ApplyShopRowTextureVisual(defaults.shopPreviewBackground, cosmetics.rowTextureStyle, cosmetics.rowColor, "24435d", 1)
	if rowTextureStyle then
		defaults.shopPreviewBackground:Show()
		if defaults.shopRowTextureButton then
			ApplyShopRowTextureVisual(defaults.shopRowTextureButton.Sample, cosmetics.rowTextureStyle, cosmetics.rowColor, "24435d", 1)
			defaults.shopRowTextureButton.Sample:Show()
			defaults.shopRowTextureButton.artisanFinderTooltipText = AF:Text(rowTextureStyle.labelKey)
		end
	else
		defaults.shopPreviewBackground:Hide()
		if defaults.shopRowTextureButton then
			defaults.shopRowTextureButton.Sample:Hide()
			defaults.shopRowTextureButton.artisanFinderTooltipText = AF:Text("SHOP_ROW_TEXTURE_DEFAULT")
		end
	end
	local r, g, b, a = AF:GetShopColorRGBA(cosmetics.rowColor, "24435d00")
	defaults.shopPreviewBackground:SetVertexColor(r or 0.14, g or 0.26, b or 0.36, a or 0)
	defaults.shopPreviewEmblem:SetShown(cosmetics.emblemStyle ~= nil)
	r, g, b, a = AF:GetShopColorRGBA(cosmetics.iconColor, "f0c35aff")
	if cosmetics.emblemStyle ~= nil then
		defaults.shopPreviewEmblem:SetTexture("Interface\\GuildFrame\\GuildEmblemsLG_01")
		defaults.shopPreviewEmblem:SetTexCoord(AF:GetShopTabardEmblemTexCoords(cosmetics.emblemStyle))
		defaults.shopPreviewEmblem:SetVertexColor(r or 0.94, g or 0.76, b or 0.35, a or 1)
	end
	if defaults.shopEmblemButton then
		defaults.shopEmblemButton.Icon:SetShown(cosmetics.emblemStyle ~= nil)
		if cosmetics.emblemStyle ~= nil then
			defaults.shopEmblemButton.Icon:SetTexture("Interface\\GuildFrame\\GuildEmblemsLG_01")
			defaults.shopEmblemButton.Icon:SetTexCoord(AF:GetShopTabardEmblemTexCoords(cosmetics.emblemStyle))
			defaults.shopEmblemButton.Icon:SetVertexColor(r or 0.94, g or 0.76, b or 0.35, a or 1)
		end
	end
end

local function UpdateShopPreview(defaults)
	if not defaults or not defaults.shopPreviewBackground then
		return
	end
	local cosmetics = AF:NormalizeShopCosmetics({
		rowColor = defaults.shopRowColorButton and defaults.shopRowColorButton.artisanFinderColorHex or "24435d",
		iconColor = defaults.shopIconColorButton and defaults.shopIconColorButton.artisanFinderColorHex or "f0c35a",
		emblemStyle = AF:NormalizeShopTabardEmblemStyle(defaults.shopEmblemStyle and defaults.shopEmblemStyle:GetText(), nil),
		rowTextureStyle = AF:NormalizeShopRowTextureStyle(defaults.shopRowTextureStyle and defaults.shopRowTextureStyle:GetText(), nil),
	}) or AF:GetDefaultShopCosmetics()
	SetShopPreviewTexture(defaults, cosmetics)
end

local function SetShopSelectionText(box, value)
	SetEditBoxText(box, tostring(value or ""), false)
	box.artisanFinderDirty = true
end

local function CreateShopSelectButton(parent, anchor, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 42, 28)
	button:SetPoint(unpack(anchor))
	button.Background = button:CreateTexture(nil, "BACKGROUND")
	button.Background:SetTexture("Interface\\Buttons\\WHITE8x8")
	button.Background:SetAllPoints()
	button.Background:SetVertexColor(0.025, 0.022, 0.018, 0.92)
	button.Border = CreatePlainBorder(button, 1, 0.58, 0.47, 0.24, 0.9)
	button.Border:SetPoint("TOPLEFT", -1, 1)
	button.Border:SetPoint("BOTTOMRIGHT", 1, -1)
	button:SetScript("OnEnter", function(self)
		self.Border:SetBorderColor(1, 0.82, 0, 1)
	end)
	button:SetScript("OnLeave", function(self)
		self.Border:SetBorderColor(0.58, 0.47, 0.24, 0.9)
	end)
	return button
end

local function CreateShopEmblemButton(parent, anchor)
	local button = CreateShopSelectButton(parent, anchor, 38)
	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetPoint("CENTER")
	button.Icon:SetSize(25, 25)
	return button
end

local function CreateShopRowTextureButton(parent, anchor)
	local button = CreateShopSelectButton(parent, anchor, 84)
	button.Sample = button:CreateTexture(nil, "ARTWORK")
	button.Sample:SetPoint("TOPLEFT", 4, -4)
	button.Sample:SetPoint("BOTTOMRIGHT", -4, 4)
	button:SetScript("OnEnter", function(self)
		self.Border:SetBorderColor(1, 0.82, 0, 1)
		if self.artisanFinderTooltipText then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.artisanFinderTooltipText, 1, 0.82, 0)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self.Border:SetBorderColor(0.58, 0.47, 0.24, 0.9)
		GameTooltip:Hide()
	end)
	return button
end

local function GetShopPickerPopup()
	if ArtisanFinderShopPickerPopup then
		return ArtisanFinderShopPickerPopup
	end
	local popup = CreateFrame("Frame", "ArtisanFinderShopPickerPopup", UIParent, "BackdropTemplate")
	popup:SetFrameStrata("DIALOG")
	popup:SetClampedToScreen(true)
	popup:EnableMouse(true)
	popup:SetMovable(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	popup:Hide()
	popup.Title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	popup.Title:SetPoint("TOP", 0, -16)
	popup.Close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	popup.Close:SetPoint("TOPRIGHT", -4, -4)
	popup.ScrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
	popup.ScrollFrame:SetPoint("TOPLEFT", 24, -42)
	popup.ScrollFrame:SetPoint("BOTTOMRIGHT", -34, 44)
	popup.ScrollChild = CreateFrame("Frame", nil, popup.ScrollFrame)
	popup.ScrollFrame:SetScrollChild(popup.ScrollChild)
	popup.Cancel = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.Cancel:SetSize(76, 22)
	popup.Cancel:SetPoint("BOTTOMRIGHT", -16, 14)
	popup.Cancel:SetText(AF:Text("CANCEL"))
	popup.Cancel:SetScript("OnClick", function(self)
		self:GetParent():Hide()
	end)
	popup.Buttons = {}
	tinsert(UISpecialFrames, "ArtisanFinderShopPickerPopup")
	return popup
end

local function ResetShopPickerPopup(popup, title, width, height, scrollWidth, scrollHeight, childHeight)
	popup:SetSize(width, height)
	popup:ClearAllPoints()
	popup:SetPoint("CENTER")
	popup.Title:SetText(title)
	popup.Cancel:SetText(AF:Text("CANCEL"))
	popup.ScrollFrame:ClearAllPoints()
	popup.ScrollFrame:SetPoint("TOPLEFT", 24, -42)
	popup.ScrollFrame:SetPoint("BOTTOMRIGHT", -34, 44)
	popup.ScrollChild:SetSize(scrollWidth or math.max(1, width - 58), childHeight or scrollHeight or math.max(1, height - 86))
	popup.ScrollFrame:SetVerticalScroll(0)
	for _, button in ipairs(popup.Buttons) do
		button:Hide()
	end
end

local function GetShopPickerButton(popup, index, width, height)
	local button = popup.Buttons[index]
	if not button then
		button = CreateFrame("Button", nil, popup.ScrollChild)
		button.Background = button:CreateTexture(nil, "BACKGROUND")
		button.Background:SetTexture("Interface\\Buttons\\WHITE8x8")
		button.Background:SetAllPoints()
		button.Background:SetVertexColor(0.02, 0.018, 0.014, 0.82)
		button.Icon = button:CreateTexture(nil, "ARTWORK")
		button.Icon:SetPoint("CENTER")
		button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
		button.Highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		button.Highlight:SetBlendMode("ADD")
		button.Highlight:SetAllPoints()
		button.Selected = CreatePlainBorder(button, 2, 1, 0.82, 0, 1)
		button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		button.Label:SetPoint("CENTER")
		button.Label:SetJustifyH("CENTER")
		popup.Buttons[index] = button
	end
	button:SetParent(popup.ScrollChild)
	button:SetSize(width, height)
	button.Icon:SetSize(width - 10, height - 10)
	button.Selected:ClearAllPoints()
	button.Selected:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -3, 3)
	button.Selected:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 3, -3)
	button.Label:Hide()
	button.artisanFinderTooltipText = nil
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)
	button:Show()
	return button
end

local function OpenShopEmblemPicker(defaults, onChanged)
	local popup = GetShopPickerPopup()
	local cols = 8
	local size = 48
	local gap = 2
	local options = AF:GetShopTabardEmblemOptions()
	local rows = math.ceil(#options / cols)
	local contentWidth = cols * size + (cols - 1) * gap
	local contentHeight = rows * size + (rows - 1) * gap
	ResetShopPickerPopup(popup, AF:Text("SHOP_TABARD_EMBLEM"), 468, 470, contentWidth, 380, contentHeight)
	local selected = AF:NormalizeShopTabardEmblemStyle(defaults.shopEmblemStyle:GetText(), nil) or ""
	for index, value in ipairs(options) do
		local selectedValue = value
		local offset = index - 1
		local button = GetShopPickerButton(popup, index, size, size)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", popup.ScrollChild, "TOPLEFT", (offset % cols) * (size + gap), -math.floor(offset / cols) * (size + gap))
		button.Icon:ClearAllPoints()
		button.Icon:SetPoint("CENTER")
		button.Icon:SetSize(40, 40)
		button.Icon:SetShown(value ~= "")
		if value ~= "" then
			button.Icon:SetTexture("Interface\\GuildFrame\\GuildEmblemsLG_01")
			button.Icon:SetTexCoord(AF:GetShopTabardEmblemTexCoords(value))
		end
		local r, g, b, a = AF:GetShopColorRGBA(defaults.shopIconColorButton and defaults.shopIconColorButton.artisanFinderColorHex, "f0c35aff")
		button.Icon:SetVertexColor(r or 1, g or 0.82, b or 0, a or 1)
		button.Label:SetShown(value == "")
		button.Label:SetText(AF:Text("SHOP_TABARD_EMBLEM_NONE"))
		button.Selected:SetShown(selectedValue == selected)
		button:SetScript("OnClick", function()
			SetShopSelectionText(defaults.shopEmblemStyle, selectedValue)
			popup:Hide()
			if onChanged then
				onChanged()
			end
		end)
	end
	popup:Show()
end

local function OpenShopRowTexturePicker(defaults, onChanged)
	local popup = GetShopPickerPopup()
	local selected = AF:NormalizeShopRowTextureStyle(defaults.shopRowTextureStyle:GetText(), nil) or ""
	local options = AF:GetShopRowTextureOptions()
	local cols = 3
	local width = 88
	local height = 42
	local gap = 10
	local rows = math.max(1, math.ceil(#options / cols))
	local contentHeight = rows * height + (rows - 1) * gap
	ResetShopPickerPopup(popup, AF:Text("SHOP_ROW_TEXTURE"), 334, contentHeight + 86, 286, contentHeight, contentHeight)
	for index, option in ipairs(options) do
		local optionValue = option.value
		local button = GetShopPickerButton(popup, index, width, height)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", popup.ScrollChild, "TOPLEFT", ((index - 1) % cols) * (width + gap), -math.floor((index - 1) / cols) * (height + gap))
		button.Icon:ClearAllPoints()
		button.Icon:SetPoint("TOPLEFT", 5, -5)
		button.Icon:SetPoint("BOTTOMRIGHT", -5, 5)
		local style = ApplyShopRowTextureVisual(button.Icon, optionValue, defaults.shopRowColorButton and defaults.shopRowColorButton.artisanFinderColorHex, "24435d", 1)
		button.Icon:SetShown(style ~= nil)
		button.Label:SetShown(style == nil)
		button.Label:SetText(AF:Text(option.labelKey))
		button.artisanFinderTooltipText = AF:Text(option.labelKey)
		button.Selected:SetShown(optionValue == selected)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.artisanFinderTooltipText or "", 1, 0.82, 0)
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		button:SetScript("OnClick", function()
			SetShopSelectionText(defaults.shopRowTextureStyle, optionValue)
			popup:Hide()
			if onChanged then
				onChanged()
			end
		end)
	end
	popup:Show()
end

local function ValidateShopInputs(defaults)
	local emblemStyle = AF:NormalizeShopTabardEmblemStyle(defaults.shopEmblemStyle and defaults.shopEmblemStyle:GetText(), nil)
	local rowTextureStyle = AF:NormalizeShopRowTextureStyle(defaults.shopRowTextureStyle and defaults.shopRowTextureStyle:GetText(), nil)
	if (emblemStyle ~= nil or defaults.shopEmblemStyle:GetText() == "")
		and (rowTextureStyle ~= nil or defaults.shopRowTextureStyle:GetText() == "") then
		SetShopError(defaults, nil)
		return true
	end
	SetShopError(defaults, AF:Text("SHOP_IDENTITY_INVALID"))
	return false
end

local function SetShopLoadedState(AF, defaults)
	local cosmetics = AF:GetShopCosmetics(AF.db and AF.db.artisanProfile) or AF:GetDefaultShopCosmetics()
	local shopName = cosmetics.shopName or ""
	local rowColor = cosmetics.rowColor or ""
	local iconColor = cosmetics.iconColor or ""
	local emblemStyle = cosmetics.emblemStyle ~= nil and tostring(cosmetics.emblemStyle) or ""
	local rowTextureStyle = cosmetics.rowTextureStyle ~= nil and tostring(cosmetics.rowTextureStyle) or ""
	defaults.artisanFinderLoadedShopName = shopName
	defaults.artisanFinderLoadedShopRowColor = rowColor
	defaults.artisanFinderLoadedShopIconColor = iconColor
	defaults.artisanFinderLoadedShopEmblemStyle = emblemStyle
	defaults.artisanFinderLoadedShopRowTextureStyle = rowTextureStyle
	defaults.artisanFinderShopDirty = false
	SetEditBoxText(defaults.shopName, shopName)
	SetShopColorButtonHex(defaults.shopRowColorButton, rowColor, "24435d")
	SetShopColorButtonHex(defaults.shopIconColorButton, iconColor, "f0c35a")
	SetEditBoxText(defaults.shopEmblemStyle, emblemStyle)
	SetEditBoxText(defaults.shopRowTextureStyle, rowTextureStyle)
	UpdateShopPreview(defaults)
	SetShopError(defaults, nil)
end

local function RefreshShopTextIfClean(AF, defaults)
	if not IsShopSaveDirty(defaults) then
		SetShopLoadedState(AF, defaults)
	end
end

local function ShouldEnableDefaultsSave(AF, defaults)
	return IsDefaultsSaveDirty(defaults)
		and (defaults.artisanFinderLoadedProfessionID or AF:GetCurrentSupportedProfessionID()) ~= nil
		and not HasPanelError(defaults)
end

local function ShouldEnableShopSave(defaults)
	return IsShopSaveDirty(defaults) and not HasShopError(defaults)
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
		defaults.shopHeader:SetText(self:Text("SHOP_COSMETICS"))
		defaults.priceLabel:SetText(self:Text("COMMISSION"))
		defaults.noteLabel:SetText(self:Text("NOTE"))
		defaults.shopNameLabel:SetText(self:Text("SHOP_NAME"))
		defaults.shopRowColorLabel:SetText(self:Text("SHOP_ROW_COLOR"))
		defaults.shopIconColorLabel:SetText(self:Text("SHOP_ICON_COLOR"))
		defaults.shopEmblemStyleLabel:SetText(self:Text("SHOP_TABARD_EMBLEM"))
		defaults.shopRowTextureStyleLabel:SetText(self:Text("SHOP_ROW_TEXTURE"))
		defaults.price.Placeholder:SetText(self:Text("COMMISSION_PLACEHOLDER"))
		defaults.note.Placeholder:SetText(self:Text("NOTE_PLACEHOLDER"))
		defaults.shopName.Placeholder:SetText(self:Text("SHOP_NAME_PLACEHOLDER"))
		defaults.shopEmblemStyle.Placeholder:SetText("0-" .. tostring(self:GetShopTabardEmblemPickerMaxStyle()))
		defaults.shopRowTextureStyle.Placeholder:SetText(self:Text("SHOP_ROW_TEXTURE_PLACEHOLDER"))
		defaults.advertiseCheck.Text:SetText(self:Text("CRAFTER_PANEL_ADVERTISE_PROFESSION"))
		defaults.shopSave:SetText(self:Text("SAVE"))
		defaults.shopReset:SetText(self:Text("SHOP_IDENTITY_RESET"))
		UpdatePlaceholder(defaults.price)
		UpdatePlaceholder(defaults.note)
		FitStackedDefaultNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save, defaults.discard)
		FitCrafterCommissionFields(defaults, frame)
		UpdatePlaceholder(defaults.shopName)
		UpdatePlaceholder(defaults.shopEmblemStyle)
		UpdatePlaceholder(defaults.shopRowTextureStyle)
		UpdateShopPreview(defaults)
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
	local defaultCollapsed = states.defaults == true
	local y = defaultCollapsed and 25 or 33
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

	defaults.defaultsDivider:Hide()
	placeToggle(defaults.defaultSectionToggle, defaultCollapsed, defaultCollapsed)
	defaults.defaultsHeader:ClearAllPoints()
	defaults.defaultsHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + (defaultCollapsed and COLLAPSED_TITLE_OFFSET or 0)))
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

	local shopCollapsed = states.shop ~= false
	defaults.shopDivider:ClearAllPoints()
	defaults.shopDivider:SetPoint("TOPLEFT", defaults, "TOPLEFT", 12, -y)
	defaults.shopDivider:SetPoint("TOPRIGHT", defaults, "TOPRIGHT", -12, -y)
	placeToggle(defaults.shopSectionToggle, shopCollapsed, true)
	defaults.shopHeader:ClearAllPoints()
	defaults.shopHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(y + (shopCollapsed and COLLAPSED_TITLE_OFFSET or SECTION_GAP)))
	defaults.shopHeader:Show()
	for _, region in ipairs({
		defaults.shopNameLabel, defaults.shopNameField, defaults.shopRowColorLabel, defaults.shopRowColorButton,
		defaults.shopIconColorLabel, defaults.shopIconColorButton, defaults.shopEmblemStyleLabel,
		defaults.shopEmblemButton, defaults.shopRowTextureStyleLabel, defaults.shopRowTextureButton,
		defaults.shopPreview, defaults.shopSave, defaults.shopReset,
	}) do
		region:SetShown(not shopCollapsed)
	end
	defaults.shopErrorText:SetShown(not shopCollapsed and (defaults.shopErrorText:GetText() or "") ~= "")
	if not shopCollapsed then
		local contentY = y + SECTION_GAP + 28
		defaults.shopNameLabel:ClearAllPoints()
		defaults.shopRowColorLabel:ClearAllPoints()
		defaults.shopIconColorLabel:ClearAllPoints()
		defaults.shopEmblemStyleLabel:ClearAllPoints()
		defaults.shopRowTextureStyleLabel:ClearAllPoints()
		defaults.shopPreview:ClearAllPoints()
		defaults.shopSave:ClearAllPoints()
		defaults.shopReset:ClearAllPoints()
		defaults.shopNameLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -contentY)
		defaults.shopRowColorLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(contentY + 34))
		defaults.shopIconColorLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(contentY + 68))
		defaults.shopEmblemStyleLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(contentY + 102))
		defaults.shopRowTextureStyleLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -(contentY + 136))
		defaults.shopPreview:SetPoint("TOPLEFT", defaults, "TOPLEFT", 214, -contentY)
		defaults.shopSave:SetPoint("TOPLEFT", defaults, "TOPLEFT", 108, -(contentY + 168))
		defaults.shopReset:SetPoint("LEFT", defaults.shopSave, "RIGHT", 6, 0)
		y = contentY + 198
	else
		y = y + COLLAPSED_SECTION_HEIGHT
	end
	defaults:SetHeight(math.max(120, y))
	self:PositionCrafterUI()
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
	ConfigureSectionToggle(defaults.shopSectionToggle, "shop", "SHOP_COSMETICS")

		defaults.shopHeader = defaults:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		defaults.shopHeader:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -282)
		defaults.shopHeader:SetText(self:Text("SHOP_COSMETICS"))

		defaults.shopNameLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		defaults.shopNameLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -310)
		defaults.shopNameLabel:SetSize(88, 20)
		defaults.shopNameLabel:SetJustifyH("LEFT")
		defaults.shopNameLabel:SetText(self:Text("SHOP_NAME"))

		defaults.shopNameField = CreateFrame("Frame", nil, defaults, "ArtisanFinderInsetEditBoxTemplate")
		defaults.shopName = PrepareInsetEditBox(defaults.shopNameField, 96, "SHOP_NAME_PLACEHOLDER")
		SetFieldPoint(defaults.shopName, "LEFT", defaults.shopNameLabel, "RIGHT", 6, 0)
		defaults.shopName:SetMaxLetters(AF.MAX_SHOP_NAME_CHARS or 32)

		defaults.shopRowColorLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		defaults.shopRowColorLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -344)
		defaults.shopRowColorLabel:SetSize(88, 20)
		defaults.shopRowColorLabel:SetJustifyH("LEFT")
		defaults.shopRowColorLabel:SetText(self:Text("SHOP_ROW_COLOR"))

		defaults.shopRowColorButton = CreateShopColorButton(defaults, { "LEFT", defaults.shopRowColorLabel, "RIGHT", 6, 0 }, "24435d")

		defaults.shopIconColorLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		defaults.shopIconColorLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -378)
		defaults.shopIconColorLabel:SetSize(88, 20)
		defaults.shopIconColorLabel:SetJustifyH("LEFT")
		defaults.shopIconColorLabel:SetText(self:Text("SHOP_ICON_COLOR"))

		defaults.shopIconColorButton = CreateShopColorButton(defaults, { "LEFT", defaults.shopIconColorLabel, "RIGHT", 6, 0 }, "f0c35a")

		defaults.shopEmblemStyleLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		defaults.shopEmblemStyleLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -412)
		defaults.shopEmblemStyleLabel:SetSize(88, 20)
		defaults.shopEmblemStyleLabel:SetJustifyH("LEFT")
		defaults.shopEmblemStyleLabel:SetText(self:Text("SHOP_TABARD_EMBLEM"))

		defaults.shopEmblemStyleField = CreateFrame("Frame", nil, defaults, "ArtisanFinderInsetEditBoxTemplate")
		defaults.shopEmblemStyle = PrepareInsetEditBox(defaults.shopEmblemStyleField, 52, "SHOP_TABARD_EMBLEM_PLACEHOLDER")
		SetFieldPoint(defaults.shopEmblemStyle, "LEFT", defaults.shopEmblemStyleLabel, "RIGHT", 6, 0)
		defaults.shopEmblemStyle:SetMaxLetters(3)
		defaults.shopEmblemStyleField:Hide()

		defaults.shopEmblemButton = CreateShopEmblemButton(defaults, { "LEFT", defaults.shopEmblemStyleLabel, "RIGHT", 6, 0 })

		defaults.shopRowTextureStyleLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		defaults.shopRowTextureStyleLabel:SetPoint("TOPLEFT", defaults, "TOPLEFT", 14, -446)
		defaults.shopRowTextureStyleLabel:SetSize(88, 20)
		defaults.shopRowTextureStyleLabel:SetJustifyH("LEFT")
		defaults.shopRowTextureStyleLabel:SetText(self:Text("SHOP_ROW_TEXTURE"))

		defaults.shopRowTextureStyleField = CreateFrame("Frame", nil, defaults, "ArtisanFinderInsetEditBoxTemplate")
		defaults.shopRowTextureStyle = PrepareInsetEditBox(defaults.shopRowTextureStyleField, 38, "SHOP_ROW_TEXTURE_PLACEHOLDER")
		SetFieldPoint(defaults.shopRowTextureStyle, "LEFT", defaults.shopRowTextureStyleLabel, "RIGHT", 6, 0)
		defaults.shopRowTextureStyle:SetMaxLetters(2)
		defaults.shopRowTextureStyleField:Hide()

		defaults.shopRowTextureButton = CreateShopRowTextureButton(defaults, { "LEFT", defaults.shopRowTextureStyleLabel, "RIGHT", 6, 0 })

		defaults.shopPreview = CreateFrame("Frame", nil, defaults)
		defaults.shopPreview:SetSize(SHOP_ROW_PREVIEW_WIDTH, SHOP_ROW_PREVIEW_HEIGHT)
		defaults.shopPreview:SetPoint("TOPLEFT", defaults, "TOPLEFT", 214, -310)
		defaults.shopPreviewBackground = defaults.shopPreview:CreateTexture(nil, "BACKGROUND")
		defaults.shopPreviewBackground:SetAllPoints()
		defaults.shopPreviewEmblem = defaults.shopPreview:CreateTexture(nil, "ARTWORK")
		defaults.shopPreviewEmblem:SetPoint("RIGHT", defaults.shopPreview, "RIGHT", -10, 0)
		defaults.shopPreviewEmblem:SetSize(52, 58)

		defaults.shopSave = CreateFrame("Button", nil, defaults, "UIPanelButtonTemplate")
		defaults.shopSave:SetSize(54, 22)
		defaults.shopSave:SetPoint("TOPLEFT", defaults, "TOPLEFT", 108, -478)
		defaults.shopSave:SetText(self:Text("SAVE"))
		defaults.shopSave:Disable()
		defaults.shopReset = CreateFrame("Button", nil, defaults, "UIPanelButtonTemplate")
		defaults.shopReset:SetSize(62, 22)
		defaults.shopReset:SetPoint("LEFT", defaults.shopSave, "RIGHT", 6, 0)
		defaults.shopReset:SetText(self:Text("SHOP_IDENTITY_RESET"))
		defaults.shopErrorText = defaults:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
		defaults.shopErrorText:SetPoint("LEFT", defaults.shopReset, "RIGHT", 8, 0)
		defaults.shopErrorText:SetPoint("RIGHT", defaults, "RIGHT", -14, 0)
		defaults.shopErrorText:SetHeight(20)
		defaults.shopErrorText:SetJustifyH("LEFT")
		defaults.shopErrorText:Hide()
		defaults.shopSave:SetScript("OnClick", function()
			if not ValidateShopInputs(defaults) then
				AF:UpdateCrafterDirtyState()
				return
			end
			AF:SetShopCosmetics(AF.db.artisanProfile, {
				shopName = defaults.shopName:GetText(),
				rowColor = defaults.shopRowColorButton.artisanFinderColorHex,
				iconColor = defaults.shopIconColorButton.artisanFinderColorHex,
				emblemStyle = AF:NormalizeShopTabardEmblemStyle(defaults.shopEmblemStyle:GetText(), nil),
				rowTextureStyle = AF:NormalizeShopRowTextureStyle(defaults.shopRowTextureStyle:GetText(), nil),
			})
			SetShopLoadedState(AF, defaults)
			AF:RefreshCrafterUI()
		end)
		defaults.shopReset:SetScript("OnClick", function()
			AF:SetShopCosmetics(AF.db.artisanProfile, nil)
			SetShopLoadedState(AF, defaults)
			AF:RefreshCrafterUI()
		end)

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
		local markShopDirty = function()
			ValidateShopInputs(defaults)
			UpdateShopPreview(defaults)
			defaults.artisanFinderShopDirty = IsShopSaveDirty(defaults)
			AF:UpdateCrafterDirtyState()
		end
		WatchEditBox(frame.price, markItemDirty)
		WatchEditBox(frame.note, markItemDirty)
		WatchEditBox(defaults.price, markDefaultDirty)
		WatchEditBox(defaults.note, markDefaultDirty)
		WatchEditBox(defaults.shopName, markShopDirty)
		WatchEditBox(defaults.shopEmblemStyle, markShopDirty)
		WatchEditBox(defaults.shopRowTextureStyle, markShopDirty)
		defaults.shopRowColorButton.artisanFinderOnChanged = markShopDirty
		defaults.shopIconColorButton.artisanFinderOnChanged = markShopDirty
		defaults.shopEmblemButton:SetScript("OnClick", function()
			OpenShopEmblemPicker(defaults, markShopDirty)
		end)
		defaults.shopRowTextureButton:SetScript("OnClick", function()
			OpenShopRowTexturePicker(defaults, markShopDirty)
		end)
		SaveOnEnter(frame.price, frame.save)
		SaveOnEnter(frame.note, frame.save)
		SaveOnEnter(defaults.price, defaults.save)
		SaveOnEnter(defaults.note, defaults.save)
		SaveOnEnter(defaults.shopName, defaults.shopSave)
		SaveOnEnter(defaults.shopEmblemStyle, defaults.shopSave)
		SaveOnEnter(defaults.shopRowTextureStyle, defaults.shopSave)
		SetShopLoadedState(self, defaults)

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
		defaults.shopDivider,
		defaults.shopSectionToggle,
		defaults.shopHeader,
		defaults.shopNameLabel,
		defaults.shopNameField,
		defaults.shopRowColorLabel,
		defaults.shopRowColorButton,
		defaults.shopIconColorLabel,
		defaults.shopIconColorButton,
		defaults.shopEmblemStyleLabel,
		defaults.shopEmblemButton,
		defaults.shopRowTextureStyleLabel,
		defaults.shopRowTextureButton,
		defaults.shopPreview,
		defaults.shopSave,
		defaults.shopReset,
		defaults.shopErrorText,
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
	defaults:SetPoint("LEFT", ProfessionsFrame, "RIGHT", -5, 0)
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
	if defaults.shopSave then
		if ShouldEnableShopSave(defaults) then
			defaults.shopSave:Enable()
		else
			defaults.shopSave:Disable()
		end
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
		RefreshShopTextIfClean(self, defaults)
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
