local _, AF = ...

local DEFAULT_COMMISSION_PANEL_WIDTH = 392
local DEFAULT_COMMISSION_PANEL_HEIGHT = 316
local CRAFTER_COLLAPSE_BUTTON_LEVEL_OFFSET = 1000
local COMMISSION_PRICE_FIELD_WIDTH = 150
local COMMISSION_FIELD_HEIGHT = 36
local COMMISSION_PRICE_MAX_LETTERS = 9
local CRAFTER_REOPEN_ICON = 7548932 -- inv-12-profession-blacksmithing-repairhammer-purple
local CUSTOMER_PREVIEW_ATLAS = "UI-HUD-Minimap-CraftingOrder-Up"

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

local function FitStackedDefaultNoteAndSave(container, noteLabel, noteBox, saveButton)
	local noteWidth = DEFAULT_COMMISSION_PANEL_WIDTH - 14 - noteLabel:GetWidth() - 4 - 14
	SetFieldWidth(noteBox, noteWidth)
	SizeButtonForText(saveButton, AF:Text("SAVE"), 54, noteWidth)
	saveButton:ClearAllPoints()
	saveButton:SetPoint("TOPLEFT", noteBox.Field, "BOTTOMLEFT", 0, -8)
	container:SetSize(DEFAULT_COMMISSION_PANEL_WIDTH, DEFAULT_COMMISSION_PANEL_HEIGHT)
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
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(18, 18)
	button:SetNormalAtlas(CUSTOMER_PREVIEW_ATLAS)
	button:SetPushedAtlas(CUSTOMER_PREVIEW_ATLAS)
	return button
end

local function ConfigureCustomerPreviewButton(button, getEntry)
	button:SetScript("OnEnter", function(self)
		local entry, defaultEntry = getEntry()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("CUSTOMER_SIDE_PREVIEW"), 1, 0.82, 0)
		if entry or defaultEntry then
			local priceCopper, freeCommission = AF:GetEntryCommission(entry)
			if not priceCopper then
				priceCopper, freeCommission = AF:GetEntryCommission(defaultEntry)
			end
			GameTooltip:AddLine(AF:FormatMoney(priceCopper or 0, freeCommission), 1, 1, 1, true)
			local note = AF:GetEntryNote(entry)
			if not note then
				note = AF:GetEntryNote(defaultEntry)
			end
			if note and note ~= "" then
				GameTooltip:AddLine(note, 0.85, 0.85, 0.85, true)
			end
			local capability = AF:FormatCapability(entry)
			if capability and capability ~= "" then
				GameTooltip:AddLine(capability, 0.65, 0.65, 0.65, true)
			end
			if entry then
				AF:AddCapabilityTooltipLines(GameTooltip, entry)
			end
		else
			GameTooltip:AddLine(AF:Text("CUSTOMER_SIDE_PREVIEW_EMPTY"), 0.65, 0.65, 0.65, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function SetPanelError(panel, message)
	if panel and panel.errorText then
		panel.errorText:SetText(message or "")
		panel.errorText:SetShown(message ~= nil and message ~= "")
	end
end

local function ClearPanelError(panel)
	SetPanelError(panel, nil)
end

local function HasPanelError(panel)
	return panel and panel.errorText and panel.errorText:IsShown()
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
		frame.priceLabel:SetText(self:Text("COMMISSION"))
		frame.noteLabel:SetText(self:Text("NOTE"))
		frame.price.Placeholder:SetText(self:Text("COMMISSION_PLACEHOLDER"))
		frame.note.Placeholder:SetText(self:Text("NOTE_PLACEHOLDER"))
		UpdatePlaceholder(frame.price)
		UpdatePlaceholder(frame.note)
		FitNoteAndSave(frame, frame.noteLabel, frame.note, frame.save, 326, 120)
		MatchFieldWidth(frame.price, frame.note)
		if frame.errorText and frame.errorText:IsShown() then
			frame.errorText:SetText(self:Text("COMMISSION_INVALID"))
		end
	end
	if defaults then
		defaults.title:SetText("ArtisanFinder")
		defaults.defaultsHeader:SetText(self:Text("DEFAULT_COMMISSION"))
		defaults.scanHeader:SetText(self:Text("CRAFTER_PANEL_SCAN_SECTION"))
		defaults.advertisingHeader:SetText(self:Text("CRAFTER_PANEL_ADVERTISING_SECTION"))
		defaults.priceLabel:SetText(self:Text("COMMISSION"))
		defaults.noteLabel:SetText(self:Text("NOTE"))
		defaults.price.Placeholder:SetText(self:Text("COMMISSION_PLACEHOLDER"))
		defaults.note.Placeholder:SetText(self:Text("NOTE_PLACEHOLDER"))
		defaults.advertiseCheck.Text:SetText(self:Text("CRAFTER_PANEL_ADVERTISE_PROFESSION"))
		UpdatePlaceholder(defaults.price)
		UpdatePlaceholder(defaults.note)
		FitStackedDefaultNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save)
		if frame then
			MatchFieldWidth(defaults.note, frame.note)
		end
		MatchFieldWidth(defaults.price, defaults.note)
		if defaults.errorText and defaults.errorText:IsShown() then
			defaults.errorText:SetText(self:Text("COMMISSION_INVALID"))
		end
		self:UpdateFastScanButton()
	end
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
			collapseButton:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
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
		or (C_TradeSkillUI.IsTradeSkillGuildMember and C_TradeSkillUI.IsTradeSkillGuildMember() == true)
		or (C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() == true)
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

	local button = CreateFrame("Button", "ArtisanFinderCrafterReopenButton", form, "UIPanelButtonTemplate")
	button:SetSize(32, 32)
	button:SetFrameLevel((form:GetFrameLevel() or 0) + 20)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(CRAFTER_REOPEN_ICON)
	button.icon:SetSize(20, 20)
	button.icon:SetPoint("CENTER")
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
	if self.IsOwnProfessionWindowOpen and not self:IsOwnProfessionWindowOpen() then
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
	if not professionInfo and self.RecipeBelongsToProfession and not self:RecipeBelongsToProfession(currentProfession, recipeInfo, self:GetCurrentProfessionCategoryIDs(), recipeID) then
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

function AF:EnsureCurrentRecipeEntry(context)
	if not context or not context.itemID then
		return nil
	end
	if self.IsOwnProfessionWindowOpen and not self:IsOwnProfessionWindowOpen() then
		return nil
	end

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
	self:ApplyRecipeCapability(item, context.recipeID)
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

function AF:AttachCrafterUI()
	local form = self:GetCraftingSchematicForm()
	if self.crafterFrame or not form then
		return
	end

	local frame = CreateFrame("Frame", "ArtisanFinderCrafterFrame", form, "ArtisanFinderCrafterItemTemplate")
	frame.info = ConfigureInfoButton(frame.info, "ITEM_SPECIFIC_COMMISSION", "ITEM_SPECIFIC_TOOLTIP")
	frame.customerPreview = ConfigureCustomerPreviewButton(CreateCustomerPreviewButton(frame), function()
		local context = AF:GetCurrentCraftingRecipeContext()
		local item = context and AF.db.artisanProfile.items[tostring(context.itemID or "")]
		local defaultEntry = context and context.professionID and AF:GetProfessionPriceEntry(AF.db.artisanProfile, context.professionID)
		return item, defaultEntry
	end)
	frame.customerPreview:SetPoint("RIGHT", frame.info, "LEFT", -2, 0)
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

	frame.save:SetPoint("LEFT", frame.note, "RIGHT", 8, 0)
	FitNoteAndSave(frame, frame.noteLabel, frame.note, frame.save, 326, 120)
	MatchFieldWidth(frame.price, frame.note)
	frame.errorText:ClearAllPoints()
	frame.errorText:SetPoint("TOPLEFT", frame.note.Field, "BOTTOMLEFT", 0, -3)
	frame.errorText:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
	frame.errorText:SetHeight(28)
	frame.save:Disable()
	frame.save:SetScript("OnClick", function()
		local context = AF:GetCurrentCraftingRecipeContext()
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

	local defaults = CreateFrame("Frame", "ArtisanFinderProfessionDefaultsFrame", ProfessionsFrame, "ArtisanFinderProfessionDefaultsTemplate")
	self:ApplyCustomerSidePanel(defaults)
	defaults.title = defaults.TitleContainer.TitleText
	defaults.title:SetText("ArtisanFinder")
	defaults.collapseButton:Hide()
	if self.SetupCrafterTutorialButton then
		self:SetupCrafterTutorialButton(defaults)
	end

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
	defaults.defaultsHeader:SetText(self:Text("DEFAULT_COMMISSION"))
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

	FitStackedDefaultNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save)
	MatchFieldWidth(defaults.note, frame.note)
	MatchFieldWidth(defaults.price, defaults.note)
	defaults.errorText:ClearAllPoints()
	defaults.errorText:SetPoint("LEFT", defaults.save, "RIGHT", 8, 0)
	defaults.errorText:SetPoint("RIGHT", defaults, "RIGHT", -14, 0)
	defaults.errorText:SetHeight(28)
	defaults.save:Disable()
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

	local fastScanButton = defaults.fastScanButton
	fastScanButton:SetScript("OnClick", function()
		AF:SetFastScan(not (AF.db and AF.db.fastScan == true))
	end)
	fastScanButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("FAST_SCAN_BUTTON"), 1, 0.82, 0)
		GameTooltip:AddLine(AF:Text("FAST_SCAN_STATE", AF.db and AF.db.fastScan and AF:Text("ENABLED") or AF:Text("DISABLED")), 0.85, 0.85, 0.85, true)
		GameTooltip:AddLine(AF:Text("FAST_SCAN_TOOLTIP"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	fastScanButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
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
	self.crafterFastScanButton = fastScanButton
	self.crafterForceRescanButton = forceRescanButton
	self.crafterScanProgressText = defaults.scanProgressText
	defaults.collapsibleRegions = {
		defaults.tutorialButton,
		defaults.defaultsHeader,
		defaults.priceLabel,
		defaults.noteLabel,
		defaults.defaultsDivider,
		defaults.scanHeader,
		defaults.scanDivider,
		defaults.advertisingHeader,
		defaults.info,
		defaults.priceField,
		defaults.noteField,
		defaults.save,
		defaults.fastScanButton,
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

	frame:ClearAllPoints()
	local auctionatorFrame = _G["AuctionatorCraftingInfoProfessionsFrame"]
	if auctionatorFrame and auctionatorFrame:GetParent() == form and auctionatorFrame:IsShown() then
		frame:SetPoint("TOPLEFT", auctionatorFrame, "BOTTOMLEFT", 0, -8)
	else
		local anchor = form.Reagents
		if form.OptionalReagents and form.OptionalReagents:IsShown() then
			anchor = form.OptionalReagents
		end
		if form.extraSlotFrames then
			for _, extraFrame in ipairs(form.extraSlotFrames) do
				if extraFrame:IsShown() and anchor and extraFrame:GetBottom() and anchor:GetBottom() and extraFrame:GetBottom() < anchor:GetBottom() then
					anchor = extraFrame
				end
			end
		end

		if anchor then
			frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
		else
			frame:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 4, 4)
		end
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
		local completed = self:TableCount(progress.completed)
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

function AF:UpdateFastScanButton()
	local button = self.crafterFastScanButton
	local forceRescanButton = self.crafterForceRescanButton
	local scanProgressText = self.crafterScanProgressText
	local defaults = self.crafterDefaultsFrame
	if not button or not defaults then
		return
	end
	local active = self.activeScan
	local currentProfessionID = self:GetCurrentSupportedProfessionID()
	local fastScanText = self:Text("FAST_SCAN_BUTTON")
	if self.db and self.db.fastScan == true then
		fastScanText = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t " .. fastScanText
	end
	SizeButtonForText(button, fastScanText, 108, 140)
	if currentProfessionID then
		button:Enable()
	else
		button:Disable()
	end
	button:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed)
	if forceRescanButton then
		SizeButtonForText(forceRescanButton, self:Text("FORCE_RESCAN_BUTTON"), 76, 120)
		forceRescanButton:ClearAllPoints()
		forceRescanButton:SetPoint("LEFT", button, "RIGHT", 6, 0)
		if currentProfessionID and not active then
			forceRescanButton:Enable()
		else
			forceRescanButton:Disable()
		end
		forceRescanButton:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed)
	end
	if scanProgressText then
		scanProgressText:ClearAllPoints()
		if forceRescanButton then
			scanProgressText:SetPoint("LEFT", forceRescanButton, "RIGHT", 8, 0)
		else
			scanProgressText:SetPoint("LEFT", button, "RIGHT", 8, 0)
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

	if ShouldEnableDefaultsSave(self, defaults) then
		defaults.save:Enable()
	else
		defaults.save:Disable()
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
	self:UpdateFastScanButton()

	local itemProfessionID = context and context.professionID or currentProfessionID
	if itemProfessionID then
		self:CaptureCurrentProfessionLink(profession or { id = itemProfessionID }, "crafter-ui-refresh")
	end
	if not context or context.learned == false or context.isRecraft then
		frame:Hide()
	else
		local item = self:EnsureCurrentRecipeEntry(context)
		if item then
			frame:Show()
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
			frame:Hide()
		end
	end

	if defaultsProfessionID then
		defaults:Show()
		self:ApplyCrafterDefaultsCollapsed(self.crafterDefaultsCollapsed)
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

	self:UpdateFastScanButton()
	self:UpdateCrafterDirtyState()
end

function AF:FocusCrafterUI()
	self:AttachCrafterUI()
	if self.crafterFrame then
		self.crafterFrame:Show()
		self:RefreshCrafterUI()
	end
end
