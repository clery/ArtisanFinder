local _, AF = ...

local PREP_HEIGHT = 78
local INLINE_SLOT_SIZE = 39
local INLINE_SLOT_SPACING = 3
local PICKER_SLOT_SIZE = 37
local PICKER_SLOT_SPACING = 3
local PICKER_PADDING = 3
local PICKER_STRIDE = 6

local function Wipe(tbl)
	if table.wipe then
		table.wipe(tbl)
	else
		for key in pairs(tbl) do
			tbl[key] = nil
		end
	end
end

local function MatchesItem(reagent, itemID)
	itemID = tonumber(itemID)
	return reagent and itemID and tonumber(reagent.itemID) == itemID
end

local function SlotContainsItem(slot, itemID)
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		if MatchesItem(reagent, itemID) then
			return true
		end
	end
	return false
end

local function GetQuantityRequired(slot, reagent)
	if slot and slot.GetQuantityRequired then
		local ok, quantity = pcall(slot.GetQuantityRequired, slot, reagent)
		if ok and tonumber(quantity) then
			return tonumber(quantity)
		end
	end
	for _, variableQuantity in ipairs(slot and slot.variableQuantities or {}) do
		if MatchesItem(variableQuantity.reagent, reagent and reagent.itemID) then
			return tonumber(variableQuantity.quantity) or tonumber(slot.quantityRequired) or 1
		end
	end
	return tonumber(slot and slot.quantityRequired) or tonumber(reagent and reagent.quantity) or 1
end

local function GetReagentQualityInfo(itemID)
	if not itemID then
		return nil
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
	if ok and type(qualityInfo) == "table" then
		return qualityInfo
	end
	return nil
end

local function GetReagentDisplayName(candidate)
	if not candidate or not candidate.itemID then
		return AF:Text("UNKNOWN")
	end
	local itemName, itemLink = C_Item.GetItemInfo(candidate.itemID)
	if itemLink and itemLink ~= "" then
		return itemLink
	end
	return itemName or AF:Text("ITEM_FALLBACK") .. " " .. tostring(candidate.itemID)
end

local function GetReagentIcon(candidate)
	if candidate and candidate.itemID then
		return C_Item.GetItemIconByID(candidate.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetOwnedCount(candidate)
	if not candidate or not candidate.itemID then
		return 0
	end
	if ProfessionsUtil and ProfessionsUtil.GetReagentQuantityInPossession then
		local ok, count = pcall(ProfessionsUtil.GetReagentQuantityInPossession, { itemID = candidate.itemID }, false)
		if ok and tonumber(count) then
			return tonumber(count)
		end
	end
	if C_Item and C_Item.GetItemCount then
		local ok, count = pcall(C_Item.GetItemCount, candidate.itemID, true, false, true)
		if ok and tonumber(count) then
			return tonumber(count)
		end
	end
	if GetItemCount then
		local ok, count = pcall(GetItemCount, candidate.itemID, true, false, true)
		if ok and tonumber(count) then
			return tonumber(count)
		end
	end
	return 0
end

local function IsModifiedReagentSlot(slot)
	return not Enum
		or not Enum.TradeskillSlotDataType
		or slot.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

local function IsOptionalReagentType(slot)
	if not Enum or not Enum.CraftingReagentType then
		return true
	end
	return slot.reagentType == Enum.CraftingReagentType.Modifying
		or slot.reagentType == Enum.CraftingReagentType.Optional
end

local function IsShoppingOptionalSlot(slot)
	if not slot or slot.required or slot.hiddenInCraftingForm then
		return false
	end
	if type(slot.reagents) ~= "table" or #slot.reagents == 0 then
		return false
	end
	if Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Finishing then
		return false
	end
	return IsModifiedReagentSlot(slot) and IsOptionalReagentType(slot)
end

local function GetSlotText(slot, fallback)
	local slotInfo = slot and slot.slotInfo
	local slotText = slotInfo and slotInfo.slotText
	if slotText and slotText ~= "" then
		return slotText
	end
	return fallback or AF:Text("OPTIONAL_REAGENTS")
end

local function GetSlotKey(slot)
	return tostring(slot and (slot.dataSlotIndex or slot.slotIndex) or "slot")
end

local function GetCandidateKey(candidate)
	if not candidate or not candidate.itemID then
		return nil
	end
	return table.concat({
		tostring(candidate.slotKey or ""),
		tostring(candidate.itemID),
		tostring(candidate.quantity or 1),
	}, ":")
end

local function GetRecipeSchematic(recipeID)
	local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
	local transaction = form and form.transaction
	if transaction and transaction.GetRecipeSchematic and (not transaction.GetRecipeID or tonumber(transaction:GetRecipeID()) == tonumber(recipeID)) then
		local ok, schematic = pcall(transaction.GetRecipeSchematic, transaction)
		if ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" then
			return schematic
		end
	end

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" then
		return schematic
	end
	return nil
end

local function BuildOptionalSlotIndex(recipeID)
	local slots = {}
	local byDataSlotIndex = {}
	local schematic = GetRecipeSchematic(recipeID)
	for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
		if IsShoppingOptionalSlot(slot) then
			slots[#slots + 1] = slot
			local dataSlotIndex = tonumber(slot.dataSlotIndex)
			if dataSlotIndex then
				byDataSlotIndex[dataSlotIndex] = slot
			end
		end
	end
	return slots, byDataSlotIndex
end

local function FindOptionalSlotForEntry(slots, byDataSlotIndex, reagentEntry)
	local itemID = tonumber(reagentEntry and (reagentEntry.itemID or reagentEntry.id))
	if not itemID then
		return nil
	end

	local dataSlotIndex = tonumber(reagentEntry.dataSlotIndex)
	local slot = dataSlotIndex and byDataSlotIndex[dataSlotIndex]
	if slot and SlotContainsItem(slot, itemID) then
		return slot
	end

	local matchedSlot
	for _, candidateSlot in ipairs(slots or {}) do
		if SlotContainsItem(candidateSlot, itemID) then
			if matchedSlot then
				return nil
			end
			matchedSlot = candidateSlot
		end
	end
	return matchedSlot
end

local function BuildCandidate(slot, reagent, suggested)
	local itemID = tonumber(reagent and (reagent.itemID or reagent.id))
	if not itemID or itemID <= 0 then
		return nil
	end
	if not SlotContainsItem(slot, itemID) then
		return nil
	end
	local quality = tonumber(reagent.quality)
	if not quality then
		local qualityInfo = GetReagentQualityInfo(itemID)
		quality = qualityInfo and tonumber(qualityInfo.quality)
	end
	local slotKey = GetSlotKey(slot)
	return {
		itemID = itemID,
		quantity = GetQuantityRequired(slot, reagent),
		quality = quality,
		slotIndex = slot.slotIndex,
		dataSlotIndex = slot.dataSlotIndex,
		slotText = GetSlotText(slot),
		slotKey = slotKey,
		source = suggested and "recommendation" or "schematic",
		suggested = suggested == true,
	}
end

local function CandidateSort(left, right)
	if left.suggested ~= right.suggested then
		return left.suggested == true
	end
	if tostring(left.slotText or "") ~= tostring(right.slotText or "") then
		return tostring(left.slotText or "") < tostring(right.slotText or "")
	end
	if (tonumber(left.quality) or 0) ~= (tonumber(right.quality) or 0) then
		return (tonumber(left.quality) or 0) > (tonumber(right.quality) or 0)
	end
	return (tonumber(left.itemID) or 0) < (tonumber(right.itemID) or 0)
end

local function AddCandidate(candidates, seen, candidate)
	local key = GetCandidateKey(candidate)
	if not key then
		return
	end
	local existing = seen[key]
	if existing then
		existing.suggested = existing.suggested or candidate.suggested
		existing.source = existing.suggested and "recommendation" or existing.source
		return
	end
	candidate.key = key
	seen[key] = candidate
	table.insert(candidates, candidate)
end

local function AddRecommendationCandidates(candidates, seen, entries, slots, byDataSlotIndex)
	for _, entry in ipairs(entries or {}) do
		for _, reagent in ipairs(entry.optionalReagents or {}) do
			local slot = FindOptionalSlotForEntry(slots, byDataSlotIndex, reagent)
			AddCandidate(candidates, seen, BuildCandidate(slot, reagent, true))
		end
		for _, reagent in ipairs(entry.optionalBestReagents or {}) do
			local slot = FindOptionalSlotForEntry(slots, byDataSlotIndex, reagent)
			AddCandidate(candidates, seen, BuildCandidate(slot, reagent, true))
		end
	end
end

local function GetEntryContextKey(entry)
	local target = AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target)) or "?"
	return table.concat({
		target,
		tostring(entry and entry.itemID or AF.currentCustomerItemID or 0),
		tostring(entry and entry.recipeID or AF.currentCustomerRecipeID or 0),
		tostring(entry and entry.professionID or AF.currentCustomerProfessionID or 0),
	}, ":")
end

function AF:GetCustomerShoppingContext()
	return self.customerShoppingContext
end

function AF:SetCustomerShoppingContext(entry, mode)
	local itemID = tonumber(entry and entry.itemID) or tonumber(self.currentCustomerItemID)
	local recipeID = tonumber(entry and entry.recipeID) or tonumber(self.currentCustomerRecipeID)
	if not itemID or not recipeID then
		self.customerShoppingContext = nil
		return nil
	end

	local context = {
		itemID = itemID,
		itemName = self.currentCustomerItemName or self:GetDisplayItemName(itemID),
		professionID = tonumber(entry and entry.professionID) or tonumber(self.currentCustomerProfessionID) or 0,
		recipeID = recipeID,
		entry = entry,
		mode = mode or "optional",
		entryKey = GetEntryContextKey(entry),
	}
	context.key = table.concat({ context.itemID, context.professionID, context.recipeID, context.entryKey, context.mode }, ":")
	self.customerShoppingContext = context
	return context
end

function AF:GetCustomerShoppingState(context)
	context = context or self:GetCustomerShoppingContext()
	if not context then
		return nil
	end
	self.customerShoppingState = self.customerShoppingState or {}
	local state = self.customerShoppingState[context.key]
	if not state then
		state = {
			selections = {},
		}
		self.customerShoppingState[context.key] = state
	end
	return state
end

function AF:BuildCustomerShoppingCandidates(context, entries)
	context = context or self:GetCustomerShoppingContext()
	if not context then
		return {}
	end

	local slots, byDataSlotIndex = BuildOptionalSlotIndex(context.recipeID)
	local candidates = {}
	local seen = {}
	AddRecommendationCandidates(candidates, seen, entries, slots, byDataSlotIndex)

	for _, slot in ipairs(slots) do
		for _, reagent in ipairs(slot.reagents or {}) do
			AddCandidate(candidates, seen, BuildCandidate(slot, reagent, false))
		end
	end

	table.sort(candidates, CandidateSort)
	return candidates
end

function AF:BuildCustomerShoppingSlots(context, entries)
	local candidates = self:BuildCustomerShoppingCandidates(context, entries)
	local slots = {}
	local bySlot = {}
	for _, candidate in ipairs(candidates) do
		local slotKey = candidate.slotKey or "slot"
		local slot = bySlot[slotKey]
		if not slot then
			slot = {
				key = slotKey,
				slotText = candidate.slotText or self:Text("OPTIONAL_REAGENTS"),
				candidates = {},
			}
			bySlot[slotKey] = slot
			table.insert(slots, slot)
		end
		table.insert(slot.candidates, candidate)
	end
	table.sort(slots, function(left, right)
		return tostring(left.slotText or "") < tostring(right.slotText or "")
	end)
	self.customerShoppingCandidates = candidates
	self.customerShoppingSlots = slots
	return slots
end

function AF:GetCustomerShoppingSelectedCandidates()
	local context = self:GetCustomerShoppingContext()
	local state = self:GetCustomerShoppingState(context)
	local candidates = self.customerShoppingCandidates or {}
	local selected = {}
	if not state then
		return selected
	end
	for _, candidate in ipairs(candidates) do
		if state.selections[candidate.slotKey] == candidate.key then
			table.insert(selected, candidate)
		end
	end
	return selected
end

function AF:GetCustomerShoppingMissingTotals(selected)
	local missingTotal = 0
	local selectedCount = 0
	for _, candidate in ipairs(selected or {}) do
		selectedCount = selectedCount + 1
		local owned = GetOwnedCount(candidate)
		local needed = tonumber(candidate.quantity) or 1
		missingTotal = missingTotal + math.max(0, needed - owned)
	end
	return selectedCount, missingTotal
end

function AF:ToggleCustomerShoppingCandidate(candidate)
	local context = self:GetCustomerShoppingContext()
	local state = self:GetCustomerShoppingState(context)
	if not state or not candidate then
		return
	end
	if state.selections[candidate.slotKey] == candidate.key then
		state.selections[candidate.slotKey] = nil
	else
		state.selections[candidate.slotKey] = candidate.key
	end
	self:RefreshCustomerShoppingList()
end

function AF:SelectCustomerShoppingCandidate(candidate)
	local context = self:GetCustomerShoppingContext()
	local state = self:GetCustomerShoppingState(context)
	if not state or not candidate then
		return
	end
	state.selections[candidate.slotKey] = candidate.key
	self:HideCustomerShoppingPicker()
	self:RefreshCustomerShoppingList()
end

function AF:ClearCustomerShoppingSelections()
	local context = self:GetCustomerShoppingContext()
	local state = self:GetCustomerShoppingState(context)
	if state then
		Wipe(state.selections)
	end
	self:RefreshCustomerShoppingList()
end

local function GetQualityAtlas(candidate)
	local qualityInfo = GetReagentQualityInfo(candidate and candidate.itemID)
	return qualityInfo and qualityInfo.iconInventory
end

local function SetQualityOverlay(texture, candidate)
	if not texture then
		return
	end
	local atlas = GetQualityAtlas(candidate)
	if atlas and C_Texture.GetAtlasInfo(atlas) then
		texture:SetAtlas(atlas, TextureKitConstants and TextureKitConstants.UseAtlasSize)
		texture:Show()
	else
		texture:Hide()
	end
end

local function SetItemQualityBorder(button, candidate)
	if not button or not button.iconBorder then
		return
	end
	if not candidate or not candidate.itemID then
		button.iconBorder:Hide()
		return
	end

	local quality = select(3, C_Item.GetItemInfo(candidate.itemID))
	if quality and ColorManager and ColorManager.GetAtlasDataForProfessionsItemQuality then
		local atlasData = ColorManager.GetAtlasDataForProfessionsItemQuality(quality)
		if atlasData and atlasData.atlas then
			button.iconBorder:SetAtlas(atlasData.atlas, TextureKitConstants and TextureKitConstants.IgnoreAtlasSize)
			local overrideColor = atlasData.overrideColor
			if overrideColor then
				button.iconBorder:SetVertexColor(overrideColor.r, overrideColor.g, overrideColor.b)
			else
				button.iconBorder:SetVertexColor(1, 1, 1)
			end
			button.iconBorder:Show()
			return
		end
	end

	local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color then
		button.iconBorder:SetVertexColor(color.r, color.g, color.b)
	else
		button.iconBorder:SetVertexColor(1, 1, 1)
	end
	button.iconBorder:Show()
end

local function GetSelectedCandidateForSlot(slot, selectedBySlot)
	for _, candidate in ipairs(slot and slot.candidates or {}) do
		if selectedBySlot and selectedBySlot[candidate.slotKey] == candidate.key then
			return candidate
		end
	end
	return nil
end

local function ResetInlineSlot(_, button)
	button.slotData = nil
	button.candidate = nil
	button:ClearAllPoints()
	button:Hide()
end

local function ShowCandidateTooltip(owner, candidate, includeSafeLine)
	if not owner or not candidate then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	AF:HideEmbeddedItemTooltip(GameTooltip)
	GameTooltip:SetHyperlink("item:" .. tostring(candidate.itemID))
	AF:HideEmbeddedItemTooltip(GameTooltip)
	GameTooltip:AddLine(" ")
	local owned = GetOwnedCount(candidate)
	local needed = tonumber(candidate.quantity) or 1
	local missing = math.max(0, needed - owned)
	GameTooltip:AddLine(AF:Text("CUSTOMER_SHOPPING_TOOLTIP_COUNTS", owned, needed, missing), 1, 0.82, 0, true)
	if includeSafeLine then
		GameTooltip:AddLine(AF:Text("CUSTOMER_SHOPPING_TOOLTIP_SAFE"), 0.65, 0.65, 0.65, true)
	end
	GameTooltip:Show()
end

local function ConfigureInlineSlot(button)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(slotButton, mouseButton)
		if mouseButton == "RightButton" and slotButton.candidate then
			local context = AF:GetCustomerShoppingContext()
			local state = AF:GetCustomerShoppingState(context)
			if state and slotButton.candidate.slotKey then
				state.selections[slotButton.candidate.slotKey] = nil
				AF:HideCustomerShoppingPicker()
				AF:RefreshCustomerShoppingList()
			end
		elseif slotButton.slotData then
			AF:OpenCustomerShoppingPicker(slotButton.slotData, slotButton)
		end
	end)
	button:SetScript("OnEnter", function(slotButton)
		if slotButton.addIconHighlight then
			slotButton.addIconHighlight:SetShown(slotButton.candidate == nil)
		end
		if slotButton.candidate then
			ShowCandidateTooltip(slotButton, slotButton.candidate, true)
		else
			GameTooltip:SetOwner(slotButton, "ANCHOR_RIGHT")
			GameTooltip:SetText(slotButton.slotData and slotButton.slotData.slotText or AF:Text("OPTIONAL_REAGENTS"), 1, 0.82, 0, 1, true)
			GameTooltip:AddLine(AF:Text("CUSTOMER_SHOPPING_SELECT_SLOT"), 0.65, 0.65, 0.65, true)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(slotButton)
		if slotButton.addIconHighlight then
			slotButton.addIconHighlight:Hide()
		end
		GameTooltip:Hide()
	end)
	return button
end

local function ResetPickerButton(_, button)
	button.candidate = nil
	if button.iconBorder then
		button.iconBorder:Hide()
	end
	button:ClearAllPoints()
	button:Hide()
end

local function ConfigurePickerButton(button)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function(candidateButton)
		if candidateButton.candidate then
			AF:SelectCustomerShoppingCandidate(candidateButton.candidate)
		end
	end)
	button:SetScript("OnEnter", function(candidateButton)
		ShowCandidateTooltip(candidateButton, candidateButton.candidate, false)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function SetSlotButtonDisplay(button, slotData, candidate)
	button.slotData = slotData
	button.candidate = candidate
	button.icon:SetShown(candidate ~= nil)
	button.icon:SetTexture(candidate and GetReagentIcon(candidate) or nil)
	SetItemQualityBorder(button, candidate)
	button.addIcon:SetShown(candidate == nil)
	button.addIconHighlight:Hide()
	SetQualityOverlay(button.qualityOverlay, candidate)
end

local function EnsureOptionalPicker()
	if AF.customerOptionalPicker then
		return AF.customerOptionalPicker
	end

	local picker = CreateFrame("Frame", "ArtisanFinderCustomerOptionalPicker", UIParent, "ArtisanFinderCustomerOptionalPickerTemplate")
	picker:SetFrameStrata("HIGH")
	picker.slotPool = CreateFramePool("Button", picker.slots, "ArtisanFinderCustomerOptionalPickerButtonTemplate", ResetPickerButton, nil, ConfigurePickerButton)
	picker:Hide()
	AF.customerOptionalPicker = picker
	return picker
end

function AF:GetCustomerShoppingEntryKey(entry)
	return GetEntryContextKey(entry)
end

function AF:InitializeCustomerShoppingList(frame)
	if frame then
		EnsureOptionalPicker()
	end
end

function AF:ConfigureCustomerOptionalPrepRow(row)
	if not row or row.optionalPrepConfigured then
		return
	end
	row.optionalPrepConfigured = true
	row.optionalPrep.label:SetText(self:Text("OPTIONAL_REAGENTS"))
	row.optionalPrep.empty:SetText(self:Text("CUSTOMER_SHOPPING_EMPTY"))
	row.optionalPrep.track:SetText(self:Text("CUSTOMER_SHOPPING_TRACK"))
	if row.optionalPrep.topLine then
		row.optionalPrep.topLine:Hide()
	end
	row.optionalPrep.track:SetScript("OnClick", function()
		local context = AF:GetCustomerShoppingContext()
		if context and context.entry then
			AF:AddPreparedCraftToTracker(context.entry, "optional", AF:GetCustomerShoppingSelectedCandidates())
			AF:HideCustomerShoppingList()
		end
	end)
	row.optionalPrep.slotPool = CreateFramePool("Button", row.optionalPrep.slots, "ArtisanFinderCustomerOptionalPrepSlotTemplate", ResetInlineSlot, nil, ConfigureInlineSlot)
end

function AF:HideCustomerShoppingPicker()
	local picker = self.customerOptionalPicker
	if picker then
		picker:Hide()
		if picker.slotPool then
			picker.slotPool:ReleaseAll()
		end
	end
end

function AF:HideCustomerShoppingList()
	self.customerShoppingContext = nil
	self.customerShoppingCandidates = nil
	self.customerShoppingSlots = nil
	self:HideCustomerShoppingPicker()
	for _, row in ipairs(self.customerRows or {}) do
		if row.optionalPrep then
			row.optionalPrep:Hide()
			if row.optionalPrep.slotPool then
				row.optionalPrep.slotPool:ReleaseAll()
			end
		end
	end
	local frame = self.customerFrame
	if frame and frame:IsShown() and self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:OpenCustomerShoppingPicker(slotData, owner)
	local picker = EnsureOptionalPicker()
	if not picker or not slotData then
		return
	end

	picker.slotPool:ReleaseAll()
	picker.slotData = slotData
	picker.ownerButton = owner
	local candidates = slotData.candidates or {}

	local count = #candidates
	for i = 1, count do
		local candidate = candidates[i]
		local button = picker.slotPool:Acquire()
		button:SetParent(picker.slots)
		button.candidate = candidate
		button.icon:SetTexture(GetReagentIcon(candidate))
		SetItemQualityBorder(button, candidate)
		SetQualityOverlay(button.qualityOverlay, candidate)
		local column = (i - 1) % PICKER_STRIDE
		local row = math.floor((i - 1) / PICKER_STRIDE)
		button:SetPoint("TOPLEFT", PICKER_PADDING + (column * (PICKER_SLOT_SIZE + PICKER_SLOT_SPACING)), -(PICKER_PADDING + (row * (PICKER_SLOT_SIZE + PICKER_SLOT_SPACING))))
		button:Show()
	end

	local rows = math.max(1, math.ceil(count / PICKER_STRIDE))
	local columns = math.min(PICKER_STRIDE, math.max(1, count))
	local width = 30 + (columns * PICKER_SLOT_SIZE) + ((columns - 1) * PICKER_SLOT_SPACING) + (PICKER_PADDING * 2)
	local slotsHeight = (rows * PICKER_SLOT_SIZE) + ((rows - 1) * PICKER_SLOT_SPACING) + (PICKER_PADDING * 2)
	local height = 30 + slotsHeight
	picker:SetSize(width, height)
	picker.slots:SetSize(math.max(1, width - 30), math.max(1, slotsHeight))
	picker:ClearAllPoints()
	picker:SetPoint("TOPLEFT", owner or UIParent, "TOPRIGHT", 5, 0)
	picker:Show()
end

function AF:SetCustomerShoppingListShown(shown)
	if not shown then
		self:HideCustomerShoppingList()
	end
end

function AF:ShowCustomerShoppingListForEntry(entry)
	local context = self:SetCustomerShoppingContext(entry, "optional")
	if not context then
		return
	end
	self:BuildCustomerShoppingSlots(context, { entry })
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:RefreshCustomerShoppingList(entries)
	local context = self:GetCustomerShoppingContext()
	if not context or context.mode ~= "optional" then
		self.customerShoppingCandidates = nil
		self.customerShoppingSlots = nil
		return 0
	end

	if entries then
		self:BuildCustomerShoppingSlots(context, context.entry and { context.entry } or entries)
	elseif not self.customerShoppingSlots then
		self:BuildCustomerShoppingSlots(context, context.entry and { context.entry } or {})
	end

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
	return PREP_HEIGHT
end

function AF:RefreshCustomerOptionalPrepRow(row, entry)
	if not row or not row.optionalPrep then
		return 0
	end
	self:ConfigureCustomerOptionalPrepRow(row)

	local context = self:GetCustomerShoppingContext()
	if not context or context.mode ~= "optional" or context.entryKey ~= GetEntryContextKey(entry) then
		row.optionalPrep:Hide()
		if row.optionalPrep.slotPool then
			row.optionalPrep.slotPool:ReleaseAll()
		end
		return 0
	end

	if not self.customerShoppingSlots then
		self:BuildCustomerShoppingSlots(context, { entry })
	end
	local slots = self.customerShoppingSlots or {}
	local candidates = self.customerShoppingCandidates or {}
	local state = self:GetCustomerShoppingState(context)
	local selectedBySlot = state and state.selections or {}
	local selectedCount = 0
	for _, candidate in ipairs(candidates) do
		if selectedBySlot[candidate.slotKey] == candidate.key then
			selectedCount = selectedCount + 1
		end
	end

	local prep = row.optionalPrep
	prep:SetWidth(math.max(280, row:GetWidth() or 280))
	prep.empty:SetShown(#slots == 0)
	prep.slots:SetShown(#slots > 0)
	prep.track:SetEnabled(selectedCount > 0)
	prep.slotPool:ReleaseAll()
	for i, slotData in ipairs(slots) do
		local button = prep.slotPool:Acquire()
		button:SetParent(prep.slots)
		SetSlotButtonDisplay(button, slotData, GetSelectedCandidateForSlot(slotData, selectedBySlot))
		button:SetPoint("TOPLEFT", (i - 1) * (INLINE_SLOT_SIZE + INLINE_SLOT_SPACING), 0)
		button:Show()
	end
	prep.slots:SetWidth(math.max(1, (#slots * INLINE_SLOT_SIZE) + (math.max(0, #slots - 1) * INLINE_SLOT_SPACING)))
	prep:Show()
	return PREP_HEIGHT
end
