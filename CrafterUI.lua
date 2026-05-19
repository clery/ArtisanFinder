local _, AF = ...

local DEFAULT_COMMISSION_PANEL_WIDTH = 356
local DEFAULT_COMMISSION_PANEL_HEIGHT = 276
local CRAFTER_COLLAPSE_BUTTON_LEVEL_OFFSET = 1000
local COMMISSION_PRICE_FIELD_WIDTH = 104
local COMMISSION_PRICE_MAX_LETTERS = 9

local function UpdatePlaceholder(box)
	box.Placeholder:SetShown((box:GetText() or "") == "" and not box:HasFocus())
end

local function SetEditBoxText(box, text)
	box.artisanFinderSettingText = true
	box:SetText(text or "")
	box:SetCursorPosition(0)
	box.artisanFinderSettingText = false
	UpdatePlaceholder(box)
end

local function WatchEditBox(box, callback)
	box:SetScript("OnTextChanged", function(self)
		UpdatePlaceholder(self)
		if not self.artisanFinderSettingText then
			callback()
		end
	end)
end

local function ClampCommissionEditBox(box)
	local value = tonumber(box:GetText())
	if not value or value <= (AF.MAX_COMMISSION_GOLD or 99999999) then
		return
	end
	SetEditBoxText(box, tostring(AF.MAX_COMMISSION_GOLD or 99999999))
end

local function PrepareInsetEditBox(field, width, placeholderKey, hasGoldIcon)
	field:SetSize(width, 24)
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
	box.Placeholder:SetPoint("LEFT", box, "LEFT", 0, 0)
	box.Placeholder:SetPoint("RIGHT", box, "RIGHT", 0, 0)
	box.Placeholder:SetJustifyH("LEFT")
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

local function ParseCommissionOrWarn(box)
	local copper, free, state = AF:NormalizeCommissionInput(box:GetText())
	if not copper then
		AF:Print(AF:Text("COMMISSION_INVALID"))
		return nil
	end
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
	for _, region in ipairs(defaults.collapsibleRegions or {}) do
		region:SetShown(not self.crafterDefaultsCollapsed)
	end
	defaults.title:SetShown(not self.crafterDefaultsCollapsed)
	defaults.TitleContainer:SetShown(not self.crafterDefaultsCollapsed)
	defaults.NineSlice:SetShown(not self.crafterDefaultsCollapsed)
	defaults.Bg:SetShown(not self.crafterDefaultsCollapsed)
	defaults.TopTileStreaks:SetShown(not self.crafterDefaultsCollapsed)
	defaults.collapsedRail:SetShown(self.crafterDefaultsCollapsed)
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
			collapseButton:SetPoint("TOP", defaults.collapsedRail, "TOP", 0, -2)
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

	return itemID and {
		itemID = itemID,
		itemName = self:GetDisplayItemName(itemID, recipeInfo.name),
		recipeID = recipeID,
		recipeName = recipeInfo.name,
		learned = recipeInfo.learned ~= false,
		isRecraft = isRecraft,
		professionID = professionID,
		professionName = currentProfession.name,
		professionIcon = currentProfession.icon,
	} or nil
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
	item.recipeName = context.recipeName or item.recipeName
	item.itemName = context.itemName or item.itemName
	item.professionID = context.professionID or item.professionID
	item.professionName = context.professionName or item.professionName
	item.professionIcon = context.professionIcon or item.professionIcon
	self:ApplyRecipeCapability(item, context.recipeID)
	item.updatedAt = self:Now()

	if context.professionID then
		local professionKey = tostring(context.professionID)
		local profession = self.db.artisanProfile.professions[professionKey] or {
			id = context.professionID,
			name = context.professionName or AF:Text("PROFESSION_FALLBACK", tostring(context.professionID)),
			recipes = {},
		}
		self.db.artisanProfile.professions[professionKey] = profession
		profession.name = context.professionName or profession.name
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
	frame.save:Disable()
	frame.save:SetScript("OnClick", function()
		local context = AF:GetCurrentCraftingRecipeContext()
		local item = AF:EnsureCurrentRecipeEntry(context)
		if not item or not context or context.learned == false then
			AF:Print(AF:Text("SELECT_LEARNED_CRAFT"))
			return
		end

		local copper, free, state = ParseCommissionOrWarn(frame.price)
		if not copper then
			return
		end

		AF:SetItemPrice(item.itemID, copper, free, frame.note:GetText(), state)
		AF:RefreshCrafterUI()
	end)

	local defaults = CreateFrame("Frame", "ArtisanFinderProfessionDefaultsFrame", ProfessionsFrame, "ArtisanFinderProfessionDefaultsTemplate")
	self:ApplyCustomerSidePanel(defaults)
	defaults.title = defaults.TitleContainer.TitleText
	defaults.title:SetText("ArtisanFinder")
	defaults.collapseButton:Hide()

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
	defaults.save:Disable()
	defaults.save:SetScript("OnClick", function()
		local context = AF:GetCurrentCraftingRecipeContext()
		local professionID = context and context.professionID
		if not professionID then
			local profession = AF:GetCurrentProfessionInfo()
			professionID = profession and profession.id
		end
		if not professionID then
			AF:Print(AF:Text("OPEN_PROFESSION_DEFAULT"))
			return
		end

		local copper, free, state = ParseCommissionOrWarn(defaults.price)
		if not copper then
			return
		end

		AF:SetProfessionPrice(professionID, copper, free, defaults.note:GetText(), state)
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
		AF:RefreshCrafterUI()
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
		local profession = AF:GetCurrentProfessionInfo()
		if profession and profession.id then
			AF:SetProfessionAdvertised(AF.playerName, profession.id, self:GetChecked() == true)
		end
	end)

	local markItemDirty = function()
		ClampCommissionEditBox(frame.price)
		AF:UpdateCrafterDirtyState()
	end
	local markDefaultDirty = function()
		ClampCommissionEditBox(defaults.price)
		AF:UpdateCrafterDirtyState()
	end
	WatchEditBox(frame.price, markItemDirty)
	WatchEditBox(frame.note, markItemDirty)
	WatchEditBox(defaults.price, markDefaultDirty)
	WatchEditBox(defaults.note, markDefaultDirty)

	self.crafterFrame = frame
	self.crafterDefaultsFrame = defaults
	self.crafterDefaultsCollapseButton = collapseButton
	self.crafterFastScanButton = fastScanButton
	self.crafterForceRescanButton = forceRescanButton
	defaults.collapsibleRegions = {
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

function AF:UpdateFastScanButton()
	local button = self.crafterFastScanButton
	local forceRescanButton = self.crafterForceRescanButton
	local defaults = self.crafterDefaultsFrame
	if not button or not defaults then
		return
	end
	local active = self.activeScan
	local currentProfession = self:GetCurrentProfessionInfo()
	local fastScanText = self:Text("FAST_SCAN_BUTTON")
	if self.db and self.db.fastScan == true then
		fastScanText = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14:0:0|t " .. fastScanText
	end
	SizeButtonForText(button, fastScanText, 108, 140)
	if currentProfession then
		button:Enable()
	else
		button:Disable()
	end
	button:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed)
	if forceRescanButton then
		SizeButtonForText(forceRescanButton, self:Text("FORCE_RESCAN_BUTTON"), 76, 120)
		forceRescanButton:ClearAllPoints()
		forceRescanButton:SetPoint("LEFT", button, "RIGHT", 6, 0)
		if currentProfession and not active then
			forceRescanButton:Enable()
		else
			forceRescanButton:Disable()
		end
		forceRescanButton:SetShown(defaults:IsShown() and not self.crafterDefaultsCollapsed)
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
	local itemDirty = false
	if item then
		itemDirty = self:IsCommissionInputDirty(frame.price:GetText(), item)
			or (frame.note:GetText() or "") ~= (item.note or "")
	end
	if itemDirty then
		frame.save:Enable()
	else
		frame.save:Disable()
	end

	local professionID = context and context.professionID
	if not professionID then
		local profession = self:GetCurrentProfessionInfo()
		professionID = profession and profession.id
	end
	local default = professionID and self:GetProfessionPriceEntry(self.db.artisanProfile, professionID)
	local defaultNote = default and default.note or ""
	local defaultDirty = self:IsCommissionInputDirty(defaults.price:GetText(), default)
		or (defaults.note:GetText() or "") ~= defaultNote
	if defaultDirty then
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

	if not self:IsOwnProfessionWindowOpen() then
		frame:Hide()
		defaults:Hide()
		if self.crafterDefaultsCollapseButton then
			self.crafterDefaultsCollapseButton:Hide()
		end
		return
	end

	self:PositionCrafterUI()
	self:UpdateFastScanButton()

	local context = self:GetCurrentCraftingRecipeContext()
	local profession = self:GetCurrentProfessionInfo()
	local professionID = context and context.professionID or (profession and profession.id)
	if professionID then
		self:CaptureCurrentProfessionLink(profession or { id = professionID, name = context and context.professionName }, "crafter-ui-refresh")
	end
	if not context or context.learned == false or context.isRecraft then
		frame:Hide()
	else
		local item = self:EnsureCurrentRecipeEntry(context)
		if item then
			frame:Show()
			SetEditBoxText(frame.price, self:FormatCommissionInput(item))
			SetEditBoxText(frame.note, item.note or "")
		else
			frame:Hide()
		end
	end

	if professionID then
		defaults:Show()
		self:ApplyCrafterDefaultsCollapsed(self.crafterDefaultsCollapsed)
		defaults.advertiseCheck:SetChecked(self:IsProfessionAdvertised(self.playerName, professionID))
		local default = self:GetProfessionPriceEntry(self.db.artisanProfile, professionID)
		if default then
			SetEditBoxText(defaults.price, self:FormatCommissionInput(default))
			SetEditBoxText(defaults.note, default.note or "")
		else
			SetEditBoxText(defaults.price, "0")
			SetEditBoxText(defaults.note, "")
		end
	else
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
