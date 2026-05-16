local _, AF = ...

local function SetEditBoxText(box, text)
	box.artisanFinderSettingText = true
	box:SetText(text or "")
	box:SetCursorPosition(0)
	box.artisanFinderSettingText = false
end

local function AddGoldIcon(parent, anchor)
	local icon = parent:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
	icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
	return icon
end

local function WatchEditBox(box, callback)
	box:SetScript("OnTextChanged", function(self)
		if not self.artisanFinderSettingText then
			callback()
		end
	end)
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
	noteBox:SetWidth(noteWidth)
	saveButton:ClearAllPoints()
	saveButton:SetPoint("LEFT", noteBox, "RIGHT", 8, 0)
	container:SetWidth(fittedWidth)
end

local function AddInfoButton(parent, tooltipTitle, tooltipText)
	local button = CreateFrame("Button", nil, parent, "UIPanelInfoButton")
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

function AF:GetCraftingSchematicForm()
	if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then
		return nil
	end
	return ProfessionsFrame.CraftingPage.SchematicForm
end

function AF:IsLinkedProfessionOpen()
	if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillLinked then
		local ok, linked = pcall(C_TradeSkillUI.IsTradeSkillLinked)
		return ok and linked == true
	end
	if IsTradeSkillLinked then
		local ok, linked = pcall(IsTradeSkillLinked)
		return ok and linked == true
	end
	return false
end

function AF:GetCurrentCraftingRecipeContext()
	local form = self:GetCraftingSchematicForm()
	if not form or not form.GetRecipeInfo then
		return nil
	end

	local recipeInfo = form:GetRecipeInfo()
	if not recipeInfo or not recipeInfo.recipeID then
		return nil
	end

	local recipeID = recipeInfo.recipeID
	local itemID
	local outputs = self:GetRecipeOutputItemIDs(recipeID)
	for outputItemID in pairs(outputs) do
		if not itemID or tonumber(outputItemID) < tonumber(itemID) then
			itemID = outputItemID
		end
	end

	local professionInfo
	if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if ok then
			professionInfo = info
		end
	end

	local fallbackProfession = self:GetCurrentProfessionInfo()
	local professionID = professionInfo and (professionInfo.profession or professionInfo.professionID or professionInfo.skillLineID)
	professionID = professionID or (fallbackProfession and fallbackProfession.id)

	return itemID and {
		itemID = itemID,
		itemName = self:GetDisplayItemName(itemID, recipeInfo.name),
		recipeID = recipeID,
		recipeName = recipeInfo.name,
		learned = recipeInfo.learned ~= false,
		professionID = professionID,
		professionName = (professionInfo and professionInfo.professionName) or (fallbackProfession and fallbackProfession.name),
	} or nil
end

function AF:EnsureCurrentRecipeEntry(context)
	if not context or not context.itemID then
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

	local frame = CreateFrame("Frame", "ArtisanFinderCrafterFrame", form)
	frame:SetSize(326, 58)
	frame.info = AddInfoButton(frame, "ITEM_SPECIFIC_COMMISSION", "ITEM_SPECIFIC_TOOLTIP")
	frame.info:SetPoint("TOPRIGHT", -2, -2)

	frame.priceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.priceLabel:SetSize(74, 20)
	frame.priceLabel:SetPoint("TOPLEFT", 0, -2)
	frame.priceLabel:SetJustifyH("LEFT")
	frame.priceLabel:SetText(self:Text("COMMISSION"))

	frame.price = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.price:SetSize(58, 22)
	frame.price:SetPoint("LEFT", frame.priceLabel, "RIGHT", 4, 0)
	frame.price:SetAutoFocus(false)
	frame.priceGold = AddGoldIcon(frame, frame.price)

	frame.noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.noteLabel:SetSize(74, 20)
	frame.noteLabel:SetPoint("TOPLEFT", frame.priceLabel, "BOTTOMLEFT", 0, -9)
	frame.noteLabel:SetJustifyH("LEFT")
	frame.noteLabel:SetText(self:Text("NOTE"))

	frame.note = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.note:SetSize(170, 22)
	frame.note:SetPoint("LEFT", frame.noteLabel, "RIGHT", 4, 0)
	frame.note:SetAutoFocus(false)
	frame.note:SetMaxLetters(AF.MAX_NOTE_BYTES)

	frame.save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.save:SetSize(54, 22)
	frame.save:SetPoint("LEFT", frame.note, "RIGHT", 8, 0)
	FitNoteAndSave(frame, frame.noteLabel, frame.note, frame.save, 326, 120)
	frame.save:Hide()
	frame.save:SetScript("OnClick", function()
		local context = AF:GetCurrentCraftingRecipeContext()
		local item = AF:EnsureCurrentRecipeEntry(context)
		if not item or context.learned == false then
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

	local defaults = CreateFrame("Frame", "ArtisanFinderProfessionDefaultsFrame", ProfessionsFrame, "BackdropTemplate")
	defaults:SetSize(286, 108)
	self:ApplyProfessionPanel(defaults)
	defaults.title = defaults:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	defaults.title:SetPoint("TOPLEFT", 12, -10)
	defaults.title:SetText(self:Text("DEFAULT_COMMISSION"))
	defaults.info = AddInfoButton(defaults, "DEFAULT_COMMISSION", "DEFAULT_COMMISSION_TOOLTIP")
	defaults.info:SetPoint("TOPRIGHT", -10, -8)
	defaults.divider = self:AddDivider(defaults, defaults.title, -7)

	defaults.priceLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	defaults.priceLabel:SetSize(74, 20)
	defaults.priceLabel:SetPoint("TOPLEFT", defaults.divider, "BOTTOMLEFT", 0, -8)
	defaults.priceLabel:SetJustifyH("LEFT")
	defaults.priceLabel:SetText(self:Text("COMMISSION"))

	defaults.price = CreateFrame("EditBox", nil, defaults, "InputBoxTemplate")
	defaults.price:SetSize(58, 22)
	defaults.price:SetPoint("LEFT", defaults.priceLabel, "RIGHT", 4, 0)
	defaults.price:SetAutoFocus(false)
	defaults.priceGold = AddGoldIcon(defaults, defaults.price)

	defaults.noteLabel = defaults:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	defaults.noteLabel:SetSize(74, 20)
	defaults.noteLabel:SetPoint("TOPLEFT", defaults.priceLabel, "BOTTOMLEFT", 0, -9)
	defaults.noteLabel:SetJustifyH("LEFT")
	defaults.noteLabel:SetText(self:Text("NOTE"))

	defaults.note = CreateFrame("EditBox", nil, defaults, "InputBoxTemplate")
	defaults.note:SetSize(128, 22)
	defaults.note:SetPoint("LEFT", defaults.noteLabel, "RIGHT", 4, 0)
	defaults.note:SetAutoFocus(false)
	defaults.note:SetMaxLetters(AF.MAX_NOTE_BYTES)

	defaults.save = CreateFrame("Button", nil, defaults, "UIPanelButtonTemplate")
	defaults.save:SetSize(54, 22)
	defaults.save:SetPoint("LEFT", defaults.note, "RIGHT", 8, 0)
	FitNoteAndSave(defaults, defaults.noteLabel, defaults.note, defaults.save, 286, 88)
	defaults.save:Hide()
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

	local markItemDirty = function()
		AF:UpdateCrafterDirtyState()
	end
	local markDefaultDirty = function()
		AF:UpdateCrafterDirtyState()
	end
	WatchEditBox(frame.price, markItemDirty)
	WatchEditBox(frame.note, markItemDirty)
	WatchEditBox(defaults.price, markDefaultDirty)
	WatchEditBox(defaults.note, markDefaultDirty)

	self.crafterFrame = frame
	self.crafterDefaultsFrame = defaults

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
	local auctionatorFrame = _G.AuctionatorCraftingInfoProfessionsFrame
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
	defaults:SetPoint("BOTTOMLEFT", ProfessionsFrame, "BOTTOMRIGHT", 8, 24)
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
		frame.save:Show()
	else
		frame.save:Hide()
	end

	local professionID = context and context.professionID
	if not professionID then
		local profession = self:GetCurrentProfessionInfo()
		professionID = profession and profession.id
	end
	local default = professionID and self.db.artisanProfile.professionPrices[tostring(professionID)]
	local defaultNote = default and default.note or ""
	local defaultDirty = self:IsCommissionInputDirty(defaults.price:GetText(), default)
		or (defaults.note:GetText() or "") ~= defaultNote
	if defaultDirty then
		defaults.save:Show()
	else
		defaults.save:Hide()
	end
end

function AF:RefreshCrafterUI()
	self:AttachCrafterUI()
	local frame = self.crafterFrame
	local defaults = self.crafterDefaultsFrame
	if not frame or not defaults then
		return
	end

	local form = self:GetCraftingSchematicForm()
	if not ProfessionsFrame:IsShown() or not form or not form:IsVisible() or self:IsLinkedProfessionOpen() then
		frame:Hide()
		defaults:Hide()
		return
	end

	self:PositionCrafterUI()

	local context = self:GetCurrentCraftingRecipeContext()
	local profession = self:GetCurrentProfessionInfo()
	local professionID = context and context.professionID or (profession and profession.id)
	if not context or context.learned == false then
		frame:Hide()
	else
		local item = self:EnsureCurrentRecipeEntry(context)
		frame:Show()
		SetEditBoxText(frame.price, self:FormatCommissionInput(item))
		SetEditBoxText(frame.note, item.note or "")
	end

	if professionID then
		defaults:Show()
		local default = self.db.artisanProfile.professionPrices[tostring(professionID)]
		if default then
			SetEditBoxText(defaults.price, self:FormatCommissionInput(default))
			SetEditBoxText(defaults.note, default.note or "")
		else
			SetEditBoxText(defaults.price, "0")
			SetEditBoxText(defaults.note, "")
		end
	else
		defaults:Hide()
	end

	self:UpdateCrafterDirtyState()
end

function AF:FocusCrafterUI()
	self:AttachCrafterUI()
	if self.crafterFrame then
		self.crafterFrame:Show()
		self:RefreshCrafterUI()
	end
end
