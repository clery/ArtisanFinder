local _, AF = ...

local PREP_HEIGHT = 78
local PREP_ADVANCED_HEIGHT = 174
local PREP_ADVANCED_NO_OPTIONAL_HEIGHT = 116
local INLINE_SLOT_SIZE = 39
local INLINE_SLOT_SPACING = 3
local INLINE_ROW_SPACING = 9
local INLINE_ADVANCED_OPTIONAL_OFFSET = 67
local PICKER_SLOT_SIZE = 37
local PICKER_SLOT_SPACING = 3
local PICKER_PADDING = 3
local PICKER_STRIDE = 6
local NORMAL_FONT_COLOR_R = 1
local NORMAL_FONT_COLOR_G = 0.82
local NORMAL_FONT_COLOR_B = 0

local function Wipe(tbl)
	if table.wipe then
		table.wipe(tbl)
	else
		for key in pairs(tbl) do
			tbl[key] = nil
		end
	end
end

local function GetAdvancedPrepHeight(optionalSlotCount)
	return optionalSlotCount and optionalSlotCount > 0 and PREP_ADVANCED_HEIGHT or PREP_ADVANCED_NO_OPTIONAL_HEIGHT
end

local function CountOptionalSlots(slots)
	local count = 0
	for _, slotData in ipairs(slots or {}) do
		if slotData.optional then
			count = count + 1
		end
	end
	return count
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

local function GetQualityTierFromAtlas(atlas)
	return tonumber(tostring(atlas or ""):match("[Tt]ier(%d+)"))
end

local function GetReagentQualityValue(itemID)
	if not itemID then
		return nil
	end
	if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
		local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
		if ok and not AF:IsSecretValue(quality) then
			local numericQuality = tonumber(quality)
			if numericQuality then
				return numericQuality
			end
		end
	end
	local qualityInfo = GetReagentQualityInfo(itemID)
	return qualityInfo
		and (tonumber(qualityInfo.quality)
			or GetQualityTierFromAtlas(qualityInfo.iconInventory)
			or GetQualityTierFromAtlas(qualityInfo.iconSmall)
			or GetQualityTierFromAtlas(qualityInfo.icon)
			or GetQualityTierFromAtlas(qualityInfo.iconChat))
		or nil
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
	if slot and slot.slotText and slot.slotText ~= "" then
		return slot.slotText
	end
	local slotInfo = slot and slot.slotInfo
	local slotText = slotInfo and slotInfo.slotText
	if slotText and slotText ~= "" then
		return slotText
	end
	return fallback or AF:Text("OPTIONAL_REAGENTS")
end

local function GetSlotKey(slot)
	return tostring(slot and (slot.slotKey or slot.dataSlotIndex or slot.slotIndex) or "slot")
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

local AddOptionalEffect

local function GetOperationTotalSkill(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	local totalSkill = (tonumber(operationInfo.baseSkill) or 0) + (tonumber(operationInfo.bonusSkill) or 0)
	return totalSkill > 0 and totalSkill or nil
end

local function GetOperationDifficulty(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	local difficulty = (tonumber(operationInfo.baseDifficulty) or 0) + (tonumber(operationInfo.bonusDifficulty) or 0)
	return difficulty > 0 and difficulty or nil
end

local function IsBaselineRequiredSlot(slot)
	local isBasic = Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic
	return slot and not slot.hiddenInCraftingForm and (slot.required == true or isBasic)
end

local function IsLowerQualityReagent(left, right)
	if not right then
		return true
	end
	if not left then
		return false
	end
	local leftQuality = GetReagentQualityValue(left.itemID) or 0
	local rightQuality = GetReagentQualityValue(right.itemID) or 0
	if leftQuality ~= rightQuality then
		return leftQuality < rightQuality
	end
	return (tonumber(left.itemID) or 0) < (tonumber(right.itemID) or 0)
end

local function SelectBaselineReagent(slot)
	local selected
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		if IsLowerQualityReagent(reagent, selected) then
			selected = reagent
		end
	end
	return selected
end

local function AddCraftingReagentInfo(reagentInfo, slot, reagent)
	if not slot or not reagent then
		return
	end
	reagentInfo[#reagentInfo + 1] = {
		reagent = reagent,
		dataSlotIndex = slot.dataSlotIndex,
		quantity = GetQuantityRequired(slot, reagent),
	}
end

local function CopyCraftingReagentInfo(reagentInfo)
	local copy = {}
	for index, info in ipairs(reagentInfo or {}) do
		copy[index] = {
			reagent = info.reagent,
			dataSlotIndex = info.dataSlotIndex,
			quantity = info.quantity,
		}
	end
	return copy
end

local function BuildBaselineCraftingReagentInfo(schematic)
	local reagentInfo = {}
	for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
		if IsBaselineRequiredSlot(slot) then
			AddCraftingReagentInfo(reagentInfo, slot, SelectBaselineReagent(slot))
		end
	end
	return reagentInfo
end

local function GetCraftingOperationInfo(recipeID, reagentInfo)
	if not C_TradeSkillUI or not C_TradeSkillUI.GetCraftingOperationInfo then
		return nil
	end
	local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, reagentInfo or {}, nil, false)
	return ok and type(operationInfo) == "table" and operationInfo or nil
end

local function ProbeOptionalEffectMap(entry)
	local recipeID = tonumber(entry and entry.recipeID)
	if not recipeID or not C_TradeSkillUI or not C_TradeSkillUI.GetCraftingOperationInfo then
		return nil
	end
	local schematic = GetRecipeSchematic(recipeID)
	if not schematic then
		return nil
	end
	local baselineReagentInfo = BuildBaselineCraftingReagentInfo(schematic)
	local baselineOperationInfo = GetCraftingOperationInfo(recipeID, baselineReagentInfo)
		or GetCraftingOperationInfo(recipeID, {})
	local facts = entry and entry.reagentSkillFacts
	local baselineDifficulty = GetOperationDifficulty(baselineOperationInfo)
		or tonumber(entry and entry.recipeDifficulty)
		or tonumber(facts and facts.baseRecipeDifficulty)
	local baselineSkill = GetOperationTotalSkill(baselineOperationInfo)
	if not baselineDifficulty and not baselineSkill then
		return nil
	end

	local effects
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		if IsShoppingOptionalSlot(slot) then
			for _, reagent in ipairs(slot.reagents or {}) do
				local itemID = tonumber(reagent and reagent.itemID)
				if itemID then
					local probeReagentInfo = CopyCraftingReagentInfo(baselineReagentInfo)
					AddCraftingReagentInfo(probeReagentInfo, slot, reagent)
					local operationInfo = GetCraftingOperationInfo(recipeID, probeReagentInfo)
					local difficulty = GetOperationDifficulty(operationInfo)
					local skill = GetOperationTotalSkill(operationInfo)
					local difficultyDelta = difficulty and baselineDifficulty and (difficulty - baselineDifficulty) or nil
					local skillDelta = skill and baselineSkill and (skill - baselineSkill) or nil
					effects = AddOptionalEffect(effects, itemID, difficultyDelta, skillDelta)
				end
			end
		end
	end
	return effects
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

local function BuildAdvancedSlotsFromFacts(facts)
	local slots = {}
	for _, slot in ipairs(facts and facts.requiredSlots or {}) do
		slots[#slots + 1] = {
			slotKey = slot.slotKey or tostring(slot.dataSlotIndex or slot.slotIndex or #slots + 1),
			slotText = slot.slotText,
			required = true,
			reagents = slot.reagents or {},
		}
	end
	for _, slot in ipairs(facts and facts.optionalSlots or {}) do
		slots[#slots + 1] = {
			slotKey = slot.slotKey or tostring(slot.dataSlotIndex or slot.slotIndex or #slots + 1),
			slotText = slot.slotText,
			optional = true,
			reagents = slot.reagents or {},
		}
	end
	return slots
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
	if not quality or quality <= 0 then
		quality = GetReagentQualityValue(itemID)
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
		optional = slot and (slot.optional == true or IsShoppingOptionalSlot(slot)) or reagent.optional == true,
		required = slot and slot.required == true or reagent.required == true,
		difficultyAdjustment = reagent.difficultyAdjustment,
		difficultyDelta = reagent.difficultyDelta,
		skillDelta = reagent.skillDelta,
		source = suggested and "recommendation" or "schematic",
		suggested = suggested == true,
	}
end

function AddOptionalEffect(effects, itemID, difficultyDelta, skillDelta)
	itemID = tonumber(itemID)
	difficultyDelta = tonumber(difficultyDelta)
	skillDelta = tonumber(skillDelta)
	if not itemID or ((not difficultyDelta or difficultyDelta == 0) and (not skillDelta or skillDelta == 0)) then
		return effects
	end
	effects = effects or {}
	effects[itemID] = {
		difficultyDelta = difficultyDelta and difficultyDelta ~= 0 and difficultyDelta or nil,
		skillDelta = skillDelta and skillDelta ~= 0 and skillDelta or nil,
	}
	return effects
end

local function BuildEntryOptionalEffectMap(entry)
	local effects
	for itemID, effect in pairs(type(entry and entry.compactOptionalReagentDeltas) == "table" and entry.compactOptionalReagentDeltas or {}) do
		effects = AddOptionalEffect(effects, itemID, effect.difficultyDelta, effect.skillDelta)
	end
	local facts = entry and entry.reagentSkillFacts
	for _, slot in ipairs(type(facts) == "table" and facts.optionalSlots or {}) do
		for _, reagent in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
			effects = AddOptionalEffect(effects, reagent.itemID, reagent.difficultyDelta, reagent.skillDelta)
		end
	end
	if not effects then
		for itemID, effect in pairs(ProbeOptionalEffectMap(entry) or {}) do
			effects = AddOptionalEffect(effects, itemID, effect.difficultyDelta, effect.skillDelta)
		end
		if effects and type(entry) == "table" then
			entry.compactOptionalReagentDeltas = effects
		end
	end
	return effects
end

local function ApplyOptionalEffect(candidate, effects)
	if not candidate or candidate.optional ~= true or not effects then
		return candidate
	end
	local effect = effects[tonumber(candidate.itemID)] or effects[tostring(candidate.itemID or "")]
	if not effect then
		return candidate
	end
	if effect.difficultyDelta ~= nil then
		candidate.difficultyDelta = effect.difficultyDelta
	end
	if effect.skillDelta ~= nil then
		candidate.skillDelta = effect.skillDelta
	end
	return candidate
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
		if candidate.difficultyDelta ~= nil then
			existing.difficultyDelta = candidate.difficultyDelta
		end
		if candidate.difficultyAdjustment ~= nil then
			existing.difficultyAdjustment = candidate.difficultyAdjustment
		end
		if candidate.skillDelta ~= nil then
			existing.skillDelta = candidate.skillDelta
		end
		return
	end
	candidate.key = key
	seen[key] = candidate
	table.insert(candidates, candidate)
end

local function AddRecommendationCandidates(candidates, seen, entries, slots, byDataSlotIndex, optionalEffects)
	for _, entry in ipairs(entries or {}) do
		if AF:IsCurrentScanModelEntry(entry) then
			for _, reagent in ipairs(entry.optionalReagents or {}) do
				local slot = FindOptionalSlotForEntry(slots, byDataSlotIndex, reagent)
				AddCandidate(candidates, seen, ApplyOptionalEffect(BuildCandidate(slot, reagent, true), optionalEffects))
			end
			for _, reagent in ipairs(entry.optionalBestReagents or {}) do
				local slot = FindOptionalSlotForEntry(slots, byDataSlotIndex, reagent)
				AddCandidate(candidates, seen, ApplyOptionalEffect(BuildCandidate(slot, reagent, true), optionalEffects))
			end
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
		self.customerShoppingSlotsContextKey = nil
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

	local candidates = {}
	local seen = {}
	local optionalEffects = BuildEntryOptionalEffectMap(context.entry)
	if context.mode == "advanced" then
		if not self:IsCurrentScanModelEntry(context.entry) then
			return candidates
		end
		local suggestedSignature = self:GetReagentDisplaySignature(context.entry and context.entry.bestReagents)
		for _, slot in ipairs(BuildAdvancedSlotsFromFacts(context.entry and context.entry.reagentSkillFacts)) do
			for _, reagent in ipairs(slot.reagents or {}) do
				local candidate = ApplyOptionalEffect(BuildCandidate(slot, reagent, false), optionalEffects)
				if candidate then
					local candidateSignature = self:GetReagentDisplaySignature({ candidate })
					candidate.suggested = suggestedSignature ~= "" and suggestedSignature:find(candidateSignature, 1, true) ~= nil
					candidate.source = candidate.suggested and "recommendation" or candidate.source
					AddCandidate(candidates, seen, candidate)
				end
			end
		end
	else
		local slots, byDataSlotIndex = BuildOptionalSlotIndex(context.recipeID)
		AddRecommendationCandidates(candidates, seen, entries, slots, byDataSlotIndex, optionalEffects)

		for _, slot in ipairs(slots) do
			for _, reagent in ipairs(slot.reagents or {}) do
				AddCandidate(candidates, seen, ApplyOptionalEffect(BuildCandidate(slot, reagent, false), optionalEffects))
			end
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
				required = candidate.required == true,
				optional = candidate.optional == true,
				candidates = {},
			}
			bySlot[slotKey] = slot
			table.insert(slots, slot)
		end
		table.insert(slot.candidates, candidate)
	end
	table.sort(slots, function(left, right)
		if left.required ~= right.required then
			return left.required == true
		end
		if left.optional ~= right.optional then
			return left.optional ~= true
		end
		return tostring(left.slotText or "") < tostring(right.slotText or "")
	end)
	self.customerShoppingCandidates = candidates
	self.customerShoppingSlots = slots
	self.customerShoppingSlotsContextKey = context and context.key or nil
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

function AF:PrimeAdvancedShoppingSelections(context)
	if not context or context.mode ~= "advanced" then
		return
	end
	local state = self:GetCustomerShoppingState(context)
	if not state or state.primed then
		return
	end
	for _, slotData in ipairs(self.customerShoppingSlots or {}) do
		local selected
		for _, candidate in ipairs(slotData.candidates or {}) do
			if candidate.suggested then
				selected = candidate
				break
			end
			if slotData.required and (not selected or (tonumber(candidate.quality) or 0) < (tonumber(selected.quality) or 0)) then
				selected = candidate
			end
		end
		if selected and selected.slotKey then
			if selected.suggested or slotData.required then
				state.selections[selected.slotKey] = selected.key
			end
		end
	end
	state.primed = true
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
	if button.quantity then
		button.quantity:Hide()
	end
	button:ClearAllPoints()
	button:Hide()
end

local function SetReagentQuantityText(text, candidate)
	if not text then
		return
	end
	local quantity = tonumber(candidate and candidate.quantity) or 1
	if quantity > 1 then
		text:SetText(quantity)
		text:Show()
	else
		text:SetText("")
		text:Hide()
	end
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
	if button.quantity then
		button.quantity:Hide()
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
	SetReagentQuantityText(button.quantity, candidate)
end

local function EnsurePrepText(prep, key, fontObject)
	if prep[key] then
		return prep[key]
	end
	local text = prep:CreateFontString(nil, "OVERLAY", fontObject or "GameFontDisableSmall")
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	prep[key] = text
	return text
end

local function EnsureAdvancedPrepRegions(prep)
	EnsurePrepText(prep, "expectedQuality", "GameFontNormal")
	EnsurePrepText(prep, "concentrationQuality", "GameFontNormal")
	EnsurePrepText(prep, "requiredLabel", "GameFontNormalSmall")
	EnsurePrepText(prep, "optionalLabel", "GameFontNormalSmall")
end

local function HideAdvancedPrepRegions(prep)
	for _, key in ipairs({ "expectedQuality", "concentrationQuality", "requiredLabel", "optionalLabel" }) do
		if prep[key] then
			prep[key]:Hide()
		end
	end
end

local function BuildAdvancedOutcomeSelections(candidates, selectedBySlot)
	local selections = {
		requiredQualities = {},
		optionalReagents = {},
	}
	for _, candidate in ipairs(candidates or {}) do
		if selectedBySlot and selectedBySlot[candidate.slotKey] == candidate.key then
			if candidate.required then
				selections.requiredQualities[candidate.slotKey] = {
					itemID = tonumber(candidate.itemID),
					quality = tonumber(candidate.quality),
				}
			elseif candidate.optional then
				table.insert(selections.optionalReagents, candidate)
			end
		end
	end
	return selections
end

local function GetOptionalAdjustments(optionalReagents)
	local difficultyDelta = 0
	local skillDelta = 0
	for _, reagent in ipairs(optionalReagents or {}) do
		local reagentDifficulty = tonumber(reagent.difficultyDelta)
		if reagentDifficulty == nil then
			reagentDifficulty = tonumber(reagent.difficultyAdjustment or reagent.bonusDifficulty)
		end
		difficultyDelta = difficultyDelta + (reagentDifficulty or 0)
		skillDelta = skillDelta + (tonumber(reagent.skillDelta or reagent.bonusSkill) or 0)
	end
	return difficultyDelta, skillDelta
end

local function ComputeOptionalShoppingOutcome(AF, entry, selections)
	local optionalReagents = selections and selections.optionalReagents or nil
	local difficultyDelta, skillDelta = GetOptionalAdjustments(optionalReagents)
	if difficultyDelta == 0 and skillDelta == 0 then
		return nil
	end
	local facts = entry and entry.reagentSkillFacts
	local totalSkill = tonumber(entry and entry.bestTotalSkill)
		or tonumber(entry and entry.totalSkill)
		or tonumber(facts and facts.baseSkill)
		or 0
	local totalDifficulty = tonumber(entry and entry.recipeDifficulty)
		or tonumber(facts and facts.baseRecipeDifficulty)
		or 0
	local maxQuality = tonumber(entry and entry.maxOutputQuality)
		or tonumber(facts and facts.maxOutputQuality)
		or tonumber(entry and entry.bestQuality)
		or 1
	if totalSkill <= 0 or totalDifficulty <= 0 or maxQuality <= 0 or not AF.GetCraftQualityForSkill then
		return nil
	end
	totalSkill = totalSkill + skillDelta
	totalDifficulty = totalDifficulty + difficultyDelta
	local quality = AF:GetCraftQualityForSkill(totalSkill, totalDifficulty, maxQuality)
	return {
		totalSkill = totalSkill,
		totalDifficulty = totalDifficulty,
		quality = quality,
		concentrationQuality = math.min(quality + 1, maxQuality),
		maxQuality = maxQuality,
		optionalDifficultyDelta = difficultyDelta,
		optionalSkillDelta = skillDelta,
	}
end

function AF:GetCustomerShoppingOutcome(entry, context)
	context = context or self:GetCustomerShoppingContext()
	if not context or (context.mode ~= "optional" and context.mode ~= "advanced") or not entry then
		return nil
	end
	if context.entryKey ~= GetEntryContextKey(entry) then
		return nil
	end
	context.entry = entry
	local state = self:GetCustomerShoppingState(context)
	if not state then
		return nil
	end
	if self.customerShoppingSlotsContextKey ~= context.key then
		self:BuildCustomerShoppingSlots(context, { entry })
		self:PrimeAdvancedShoppingSelections(context)
	end
	local selections = BuildAdvancedOutcomeSelections(self.customerShoppingCandidates or {}, state.selections or {})
	if context.mode == "optional" then
		return ComputeOptionalShoppingOutcome(self, entry, selections)
	end
	return self.ComputeCraftOutcome and self:ComputeCraftOutcome(entry, selections) or nil
end

local function FormatAdvancedExpectedQuality(AF, entry, candidates, selectedBySlot)
	if not AF.ComputeCraftOutcome then
		return nil
	end
	local outcome = AF:ComputeCraftOutcome(entry, BuildAdvancedOutcomeSelections(candidates, selectedBySlot))
	if not outcome or outcome.rescanNeeded then
		if outcome and outcome.missingData and not outcome.missingData.reagentSkillFacts then
			return AF:Text("ADVANCED_EXPECTED_SELECT_REQUIRED"), nil
		end
		return AF:Text("ADVANCED_EXPECTED_RESCAN"), nil
	end
	local qualityText = AF:GetRecipeQualityIconMarkup(entry.recipeID, outcome.quality, 16) or ("Q" .. tostring(outcome.quality or 0))
	local concentrationText = AF:GetRecipeQualityIconMarkup(entry.recipeID, outcome.concentrationQuality, 16) or ("Q" .. tostring(outcome.concentrationQuality or 0))
	local expectedLine = AF:Text("ADVANCED_EXPECTED_QUALITY", qualityText)
	local concentrationLine
	if tonumber(outcome.concentrationQuality) and tonumber(outcome.concentrationQuality) > tonumber(outcome.quality or 0) then
		concentrationLine = AF:Text("CONCENTRATION_QUALITY", concentrationText)
	end
	return expectedLine, concentrationLine
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
			AF:AddPreparedCraftToTracker(context.entry, context.mode or "optional", AF:GetCustomerShoppingSelectedCandidates())
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
	self.customerShoppingSlotsContextKey = nil
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
		SetReagentQuantityText(button.quantity, candidate)
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

function AF:ShowCustomerShoppingListForEntry(entry, mode)
	if mode == "advanced" and self.HasAdvancedReagentFacts then
		-- Retries wire-facts rehydration in place when the entry only has
		-- synthetic compact facts but the wire payload is still cached.
		self:HasAdvancedReagentFacts(entry)
	end
	local context = self:SetCustomerShoppingContext(entry, mode or "optional")
	if not context then
		return
	end
	self:BuildCustomerShoppingSlots(context, { entry })
	self:PrimeAdvancedShoppingSelections(context)
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:RefreshCustomerShoppingList(entries)
	local context = self:GetCustomerShoppingContext()
	if not context or (context.mode ~= "optional" and context.mode ~= "advanced") then
		self.customerShoppingCandidates = nil
		self.customerShoppingSlots = nil
		self.customerShoppingSlotsContextKey = nil
		return 0
	end

	if entries then
		self:BuildCustomerShoppingSlots(context, context.entry and { context.entry } or entries)
		self:PrimeAdvancedShoppingSelections(context)
	elseif not self.customerShoppingSlots then
		self:BuildCustomerShoppingSlots(context, context.entry and { context.entry } or {})
		self:PrimeAdvancedShoppingSelections(context)
	end

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
	return context.mode == "advanced" and GetAdvancedPrepHeight(CountOptionalSlots(self.customerShoppingSlots)) or PREP_HEIGHT
end

function AF:RefreshCustomerOptionalPrepRow(row, entry)
	if not row or not row.optionalPrep then
		return 0
	end
	self:ConfigureCustomerOptionalPrepRow(row)

	local context = self:GetCustomerShoppingContext()
	if not context or (context.mode ~= "optional" and context.mode ~= "advanced") or context.entryKey ~= GetEntryContextKey(entry) then
		row.optionalPrep:Hide()
		if row.optionalPrep.slotPool then
			row.optionalPrep.slotPool:ReleaseAll()
		end
		return 0
	end

	context.entry = entry
	self:BuildCustomerShoppingSlots(context, { entry })
	self:PrimeAdvancedShoppingSelections(context)
	local slots = self.customerShoppingSlots or {}
	local candidates = self.customerShoppingCandidates or {}
	local state = self:GetCustomerShoppingState(context)
	local selectedBySlot = state and state.selections or {}
	local selectedCount = 0
	local requiredSlotCount = 0
	local optionalSlotCount = 0
	local selectedRequiredCount = 0
	for _, slotData in ipairs(slots) do
		if slotData.required then
			requiredSlotCount = requiredSlotCount + 1
			if GetSelectedCandidateForSlot(slotData, selectedBySlot) then
				selectedRequiredCount = selectedRequiredCount + 1
			end
		elseif slotData.optional then
			optionalSlotCount = optionalSlotCount + 1
		end
	end
	for _, candidate in ipairs(candidates) do
		if selectedBySlot[candidate.slotKey] == candidate.key then
			selectedCount = selectedCount + 1
		end
	end

	local prep = row.optionalPrep
	local advanced = context.mode == "advanced"
	local advancedHeight = GetAdvancedPrepHeight(optionalSlotCount)
	prep:SetWidth(math.max(280, row:GetWidth() or 280))
	prep:SetHeight(advanced and advancedHeight or PREP_HEIGHT)
	prep.label:SetText(advanced and self:Text("ADVANCED_REAGENTS") or self:Text("OPTIONAL_REAGENTS"))
	local factsPending = advanced and entry and type(entry.reagentSkillFacts) == "table" and entry.reagentSkillFacts.compact == true
	prep.empty:SetText(advanced and self:Text(factsPending and "ADVANCED_REAGENTS_PENDING" or "ADVANCED_REAGENTS_EMPTY") or self:Text("CUSTOMER_SHOPPING_EMPTY"))
	prep.label:ClearAllPoints()
	prep.label:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -10)
	prep.label:SetShown(not advanced)
	prep.empty:ClearAllPoints()
	if advanced then
		prep.empty:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -8)
	else
		prep.empty:SetPoint("TOPLEFT", prep.label, "BOTTOMLEFT", 0, -7)
	end
	prep.empty:SetPoint("RIGHT", prep, "RIGHT", -128, 0)
	prep.slots:ClearAllPoints()
	prep.track:ClearAllPoints()
	HideAdvancedPrepRegions(prep)
	if advanced then
		EnsureAdvancedPrepRegions(prep)
		local expectedLine, concentrationLine = FormatAdvancedExpectedQuality(self, entry, candidates, selectedBySlot)
		local qualityTopOffset = optionalSlotCount > 0 and -136 or -72
		prep.expectedQuality:ClearAllPoints()
		prep.expectedQuality:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, qualityTopOffset)
		prep.expectedQuality:SetPoint("RIGHT", prep, "RIGHT", -65, 0)
		prep.expectedQuality:SetTextColor(NORMAL_FONT_COLOR_R, NORMAL_FONT_COLOR_G, NORMAL_FONT_COLOR_B)
		prep.expectedQuality:SetText(expectedLine or "")
		prep.expectedQuality:Show()
		prep.concentrationQuality:ClearAllPoints()
		prep.concentrationQuality:SetPoint("TOPLEFT", prep.expectedQuality, "BOTTOMLEFT", 0, -2)
		prep.concentrationQuality:SetPoint("RIGHT", prep, "RIGHT", -65, 0)
		prep.concentrationQuality:SetTextColor(NORMAL_FONT_COLOR_R, NORMAL_FONT_COLOR_G, NORMAL_FONT_COLOR_B)
		prep.concentrationQuality:SetText(concentrationLine or "")
		prep.concentrationQuality:SetShown(concentrationLine ~= nil and concentrationLine ~= "")
		prep.requiredLabel:ClearAllPoints()
		prep.requiredLabel:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -8)
		prep.requiredLabel:SetTextColor(NORMAL_FONT_COLOR_R, NORMAL_FONT_COLOR_G, NORMAL_FONT_COLOR_B)
		prep.requiredLabel:SetText(self:Text("REQUIRED_REAGENTS"))
		prep.requiredLabel:SetShown(requiredSlotCount > 0)
		prep.optionalLabel:ClearAllPoints()
		prep.optionalLabel:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -75)
		prep.optionalLabel:SetTextColor(NORMAL_FONT_COLOR_R, NORMAL_FONT_COLOR_G, NORMAL_FONT_COLOR_B)
		prep.optionalLabel:SetText(self:Text("OPTIONAL_REAGENTS"))
		prep.optionalLabel:SetShown(optionalSlotCount > 0)
		prep.slots:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -23)
		prep.track:SetPoint("TOPRIGHT", prep, "TOPRIGHT", -65, optionalSlotCount > 0 and -139 or -76)
	else
		prep.slots:SetPoint("TOPLEFT", prep, "TOPLEFT", 27, -28)
		prep.track:SetPoint("TOPRIGHT", prep, "TOPRIGHT", -65, -31)
	end
	prep.empty:SetShown(#slots == 0)
	prep.slots:SetShown(#slots > 0)
	prep.track:SetEnabled(advanced and (requiredSlotCount > 0 and selectedRequiredCount >= requiredSlotCount) or (not advanced and selectedCount > 0))
	prep.slotPool:ReleaseAll()
	local requiredIndex = 0
	local optionalIndex = 0
	local singleIndex = 0
	for _, slotData in ipairs(slots) do
		local button = prep.slotPool:Acquire()
		button:SetParent(prep.slots)
		SetSlotButtonDisplay(button, slotData, GetSelectedCandidateForSlot(slotData, selectedBySlot))
		if advanced and slotData.optional then
			button:SetPoint("TOPLEFT", optionalIndex * (INLINE_SLOT_SIZE + INLINE_SLOT_SPACING), -INLINE_ADVANCED_OPTIONAL_OFFSET)
			optionalIndex = optionalIndex + 1
		elseif advanced then
			button:SetPoint("TOPLEFT", requiredIndex * (INLINE_SLOT_SIZE + INLINE_SLOT_SPACING), 0)
			requiredIndex = requiredIndex + 1
		else
			button:SetPoint("TOPLEFT", singleIndex * (INLINE_SLOT_SIZE + INLINE_SLOT_SPACING), 0)
			singleIndex = singleIndex + 1
		end
		button:Show()
	end
	local maxRowCount = advanced and math.max(requiredIndex, optionalIndex) or singleIndex
	local slotRows = advanced and ((optionalIndex > 0 and 2 or 1)) or 1
	prep.slots:SetWidth(math.max(1, (maxRowCount * INLINE_SLOT_SIZE) + (math.max(0, maxRowCount - 1) * INLINE_SLOT_SPACING)))
	prep.slots:SetHeight(advanced and (INLINE_ADVANCED_OPTIONAL_OFFSET + INLINE_SLOT_SIZE) or ((slotRows * INLINE_SLOT_SIZE) + (math.max(0, slotRows - 1) * INLINE_ROW_SPACING)))
	prep:Show()
	return advanced and advancedHeight or PREP_HEIGHT
end
