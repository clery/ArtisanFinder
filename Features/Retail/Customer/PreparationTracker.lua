local _, AF = ...

local function ReagentMatches(left, right)
	if not left or not right then
		return false
	end
	return (left.itemID and left.itemID ~= 0 and tonumber(left.itemID) == tonumber(right.itemID or right.id))
		or (left.currencyID and left.currencyID ~= 0 and tonumber(left.currencyID) == tonumber(right.currencyID))
end

local function FindMatchingSlotReagent(slot, reagent)
	for _, slotReagent in ipairs(slot and slot.reagents or {}) do
		if ReagentMatches(slotReagent, reagent) then
			return slotReagent
		end
	end
	return nil
end

local function GetQuantityRequired(slot, reagent)
	if slot and slot.GetQuantityRequired then
		local ok, quantity = pcall(slot.GetQuantityRequired, slot, reagent)
		if ok and tonumber(quantity) then
			return tonumber(quantity)
		end
	end
	for _, variableQuantity in ipairs(slot and slot.variableQuantities or {}) do
		if ReagentMatches(variableQuantity.reagent, reagent) then
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
	if ok and qualityInfo then
		return tonumber(qualityInfo.quality)
	end
	return nil
end

local function GetSlotText(slot, fallback)
	local slotInfo = slot and slot.slotInfo
	local slotText = slotInfo and slotInfo.slotText
	if slotText and slotText ~= "" then
		return slotText
	end
	return fallback
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

local function IsBasicOrRequiredSlot(slot)
	if not slot or slot.hiddenInCraftingForm or type(slot.reagents) ~= "table" or #slot.reagents == 0 then
		return false
	end
	if slot.required == true then
		return true
	end
	return Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic
end

local function IsOptionalSlot(slot)
	if not slot or slot.required or slot.hiddenInCraftingForm or type(slot.reagents) ~= "table" or #slot.reagents == 0 then
		return false
	end
	if Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Finishing then
		return false
	end
	local isModified = not Enum
		or not Enum.TradeskillSlotDataType
		or slot.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
	local isOptionalType = not Enum
		or not Enum.CraftingReagentType
		or slot.reagentType == Enum.CraftingReagentType.Modifying
		or slot.reagentType == rawget(Enum.CraftingReagentType, "Optional")
	return isModified and isOptionalType
end

local function PickFallbackReagent(slot)
	local selected
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		if not selected then
			selected = reagent
		else
			local selectedQuality = GetReagentQualityInfo(selected.itemID) or 0
			local reagentQuality = GetReagentQualityInfo(reagent.itemID) or 0
			if reagentQuality > selectedQuality then
				selected = reagent
			end
		end
	end
	return selected
end

local function NormalizeReagent(entry, options)
	options = options or {}
	if type(entry) ~= "table" then
		return nil
	end

	local itemID = tonumber(entry.itemID or entry.id)
	local currencyID = tonumber(entry.currencyID)
	if not itemID and not currencyID then
		return nil
	end

	local quality = tonumber(entry.quality)
	if itemID and not quality then
		quality = GetReagentQualityInfo(itemID)
	end

	return {
		kind = currencyID and "currency" or "item",
		itemID = itemID,
		currencyID = currencyID,
		quantity = tonumber(options.quantity) or tonumber(entry.quantity) or 1,
		quality = quality,
		dataSlotIndex = tonumber(entry.dataSlotIndex) or tonumber(options.dataSlotIndex),
		slotIndex = tonumber(entry.slotIndex) or tonumber(options.slotIndex),
		slotKey = entry.slotKey or options.slotKey,
		slotText = entry.slotText or options.slotText,
		optional = options.optional == true or entry.optional == true,
		source = options.source or entry.source,
	}
end

local function ReagentKey(reagent)
	if not reagent then
		return nil
	end
	return table.concat({
		reagent.kind == "currency" and "c" or "i",
		tostring(reagent.currencyID or reagent.itemID or 0),
		tostring(reagent.dataSlotIndex or 0),
		tostring(reagent.optional == true),
	}, ":")
end

local function AddOrMergeReagent(reagents, seen, reagent)
	local key = ReagentKey(reagent)
	if not key then
		return
	end
	local existing = seen[key]
	if existing then
		existing.quantity = math.max(tonumber(existing.quantity) or 1, tonumber(reagent.quantity) or 1)
		existing.quality = existing.quality or reagent.quality
		existing.slotText = existing.slotText or reagent.slotText
		return
	end
	seen[key] = reagent
	table.insert(reagents, reagent)
end

local function FindRecommendedForSlot(recommendations, slot)
	local dataSlotIndex = tonumber(slot and slot.dataSlotIndex)
	local slotIndex = tonumber(slot and slot.slotIndex)
	for _, reagent in ipairs(recommendations or {}) do
		local slotReagent = FindMatchingSlotReagent(slot, reagent)
		if slotReagent then
			local reagentDataSlotIndex = tonumber(reagent.dataSlotIndex)
			local reagentSlotIndex = tonumber(reagent.slotIndex)
			local dataSlotMatches = not dataSlotIndex or not reagentDataSlotIndex or dataSlotIndex == reagentDataSlotIndex
			local slotMatches = not slotIndex or not reagentSlotIndex or slotIndex == reagentSlotIndex
			if dataSlotMatches and slotMatches then
				return reagent, slotReagent
			end
		end
	end
	return nil
end

local function BuildRequiredRecommendations(entry, optionalReagents)
	local recommendations = entry and AF:IsCurrentScanModelEntry(entry) and entry.bestReagents or {}
	if type(optionalReagents) ~= "table" or #optionalReagents == 0 or not AF.BuildReagentSuggestion then
		return recommendations
	end
	if AF.HasAdvancedReagentFacts then
		AF:HasAdvancedReagentFacts(entry)
	end
	if not AF:IsCurrentScanModelEntry(entry) then
		return recommendations
	end
	local suggestion = AF:BuildReagentSuggestion(entry, { optionalReagents = optionalReagents })
	if suggestion and not suggestion.rescanNeeded and type(suggestion.reagents) == "table" and #suggestion.reagents > 0 then
		return suggestion.reagents
	end
	return recommendations
end

local function BuildRequiredReagents(entry, mode, optionalReagents)
	local reagents = {}
	local seen = {}
	local schematic = GetRecipeSchematic(entry and entry.recipeID)
	local recommendations = BuildRequiredRecommendations(entry, mode == "optional" and optionalReagents or nil)

	if schematic then
		for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
			if IsBasicOrRequiredSlot(slot) and not IsOptionalSlot(slot) then
				local recommended, recommendedSlotReagent = FindRecommendedForSlot(recommendations, slot)
				local reagent = recommended and NormalizeReagent(recommended, {
					dataSlotIndex = slot.dataSlotIndex,
					slotIndex = slot.slotIndex,
					slotText = GetSlotText(slot),
					source = "recommendation",
					quantity = GetQuantityRequired(slot, recommendedSlotReagent),
				})
				if not reagent then
					local fallback = PickFallbackReagent(slot)
					reagent = NormalizeReagent(fallback, {
						dataSlotIndex = slot.dataSlotIndex,
						slotIndex = slot.slotIndex,
						slotText = GetSlotText(slot),
						source = "schematic",
						quantity = fallback and GetQuantityRequired(slot, fallback),
					})
				end
				AddOrMergeReagent(reagents, seen, reagent)
			end
		end
	end

	if #reagents == 0 then
		for _, reagent in ipairs(recommendations or {}) do
			AddOrMergeReagent(reagents, seen, NormalizeReagent(reagent, { source = "recommendation" }))
		end
	end

	return reagents
end

local function BuildPreparedCraftKey(entry, mode)
	local target = AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target)) or "?"
	return table.concat({
		tostring(entry and entry.recipeID or 0),
		tostring(entry and entry.itemID or 0),
		target,
		mode or "standard",
	}, ":")
end

function AF:CreatePreparedCraftEntry(entry, mode, optionalReagents)
	if not entry or not entry.recipeID then
		return nil
	end

	local prepared = {
		key = BuildPreparedCraftKey(entry, mode),
		mode = mode or "standard",
		recipeID = tonumber(entry.recipeID),
		itemID = tonumber(entry.itemID),
		itemName = self.currentCustomerItemName or self:GetDisplayItemName(entry.itemID),
		professionID = tonumber(entry.professionID) or tonumber(self.currentCustomerProfessionID) or 0,
		target = self:NormalizeName(entry.orderTarget or entry.name or entry.target) or entry.name,
		createdAt = self:Now(),
		reagents = {},
	}

	local seen = {}
	if mode == "advanced" then
		for _, reagent in ipairs(optionalReagents or {}) do
			AddOrMergeReagent(prepared.reagents, seen, NormalizeReagent(reagent, {
				optional = reagent.optional == true,
				source = "advanced",
			}))
		end
	else
		for _, reagent in ipairs(BuildRequiredReagents(entry, mode, optionalReagents)) do
			AddOrMergeReagent(prepared.reagents, seen, reagent)
		end
		for _, reagent in ipairs(optionalReagents or {}) do
			AddOrMergeReagent(prepared.reagents, seen, NormalizeReagent(reagent, {
				optional = true,
				source = "optional",
			}))
		end
	end

	table.sort(prepared.reagents, function(left, right)
		if left.optional ~= right.optional then
			return left.optional ~= true
		end
		return tostring(left.slotText or "") < tostring(right.slotText or "")
	end)

	return prepared
end

local function GetPreparationEntries()
	local entries = AF.db and AF.db.preparedCrafts
	return type(entries) == "table" and entries or {}
end

local function ToSafeNumber(value)
	if AF.IsSecretValue and AF:IsSecretValue(value) then
		return nil
	end
	return tonumber(value)
end

local function GetPreparedCraftEntryTarget(entry)
	return AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target)) or entry and entry.target
end

local function GetPreparedCraftRecipeID(entry)
	local recipeID = ToSafeNumber(entry and (entry.recipeID or entry.spellID))
	if recipeID and recipeID > 0 then
		return recipeID
	end
	return nil
end

local function PreparedCraftMatchesCustomerEntry(prepared, entry)
	if not prepared or not entry then
		return false
	end
	local target = GetPreparedCraftEntryTarget(entry)
	local preparedTarget = GetPreparedCraftEntryTarget(prepared)
	if target and preparedTarget and target ~= preparedTarget then
		return false
	end

	local recipeID = ToSafeNumber(entry.recipeID) or ToSafeNumber(AF.currentCustomerRecipeID)
	local preparedRecipeID = GetPreparedCraftRecipeID(prepared)
	if recipeID and preparedRecipeID and recipeID ~= preparedRecipeID then
		return false
	end

	local itemID = ToSafeNumber(entry.itemID) or ToSafeNumber(AF.currentCustomerItemID)
	local preparedItemID = ToSafeNumber(prepared.itemID)
	if itemID and preparedItemID and itemID ~= preparedItemID then
		return false
	end

	return recipeID ~= nil or itemID ~= nil
end

function AF:FindPreparedCraftForCustomerEntry(entry)
	local best
	for _, prepared in ipairs(GetPreparationEntries()) do
		if PreparedCraftMatchesCustomerEntry(prepared, entry) then
			if not best or (tonumber(prepared.createdAt) or 0) > (tonumber(best.createdAt) or 0) then
				best = prepared
			end
		end
	end
	return best
end

local function GetCustomerOrderFormRecipeID(form)
	local transaction = form and form.transaction
	local recipeID
	if transaction and transaction.GetRecipeID then
		local ok, value = pcall(transaction.GetRecipeID, transaction)
		if ok then
			recipeID = value
		end
	end
	recipeID = recipeID or transaction and transaction.recipeID
	if not recipeID and transaction and transaction.GetRecipeSchematic then
		local ok, schematic = pcall(transaction.GetRecipeSchematic, transaction)
		if ok and type(schematic) == "table" then
			recipeID = schematic.recipeID
		end
	end
	if not recipeID and form and form.order then
		recipeID = form.order.spellID
	end
	if not recipeID and form and form.GetRecipeInfo then
		local ok, recipeInfo = pcall(form.GetRecipeInfo, form)
		if ok and type(recipeInfo) == "table" then
			recipeID = recipeInfo.recipeID
		end
	end
	return ToSafeNumber(recipeID)
end

local function GetCustomerOrderFormSchematic(form, recipeID)
	local transaction = form and form.transaction
	if transaction and transaction.GetRecipeSchematic then
		local ok, schematic = pcall(transaction.GetRecipeSchematic, transaction)
		if ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" then
			return schematic
		end
	end
	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and recipeID then
		local recipeInfo
		if C_TradeSkillUI.GetRecipeInfo then
			local ok, value = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
			if ok then
				recipeInfo = value
			end
		end
		local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
		local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
		if ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table" then
			return schematic
		end
	end
	return nil
end

local function FindPreparedReagentSlot(schematic, preparedReagent)
	local preparedSlotIndex = ToSafeNumber(preparedReagent and preparedReagent.slotIndex)
	local preparedDataSlotIndex = ToSafeNumber(preparedReagent and preparedReagent.dataSlotIndex)
	if preparedSlotIndex or preparedDataSlotIndex then
		for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
			local slotMatches = not preparedSlotIndex or ToSafeNumber(slot.slotIndex) == preparedSlotIndex
			local dataSlotMatches = not preparedDataSlotIndex or ToSafeNumber(slot.dataSlotIndex) == preparedDataSlotIndex
			if slotMatches and dataSlotMatches then
				local slotReagent = FindMatchingSlotReagent(slot, preparedReagent)
				if slotReagent then
					return slot, slotReagent
				end
			end
		end
	end

	local matchedSlot
	local matchedReagent
	for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
		local slotReagent = FindMatchingSlotReagent(slot, preparedReagent)
		if slotReagent then
			if matchedSlot then
				return nil
			end
			matchedSlot = slot
			matchedReagent = slotReagent
		end
	end
	return matchedSlot, matchedReagent
end

local function GetPreparedAllocationQuantity(slot, slotReagent, preparedReagent)
	local quantity = ToSafeNumber(preparedReagent and preparedReagent.quantity)
	if not quantity or quantity <= 0 then
		quantity = GetQuantityRequired(slot, slotReagent)
	end
	return ToSafeNumber(quantity) or 1
end

local function OverwriteTransactionAllocation(transaction, slotIndex, reagent, quantity)
	if not transaction or not slotIndex or not reagent then
		return false
	end
	if transaction.OverwriteAllocation then
		local ok = pcall(transaction.OverwriteAllocation, transaction, slotIndex, reagent, quantity)
		return ok
	end
	if transaction.GetAllocations then
		local ok, allocations = pcall(transaction.GetAllocations, transaction, slotIndex)
		if ok and allocations and allocations.Clear and allocations.Allocate then
			allocations:Clear()
			allocations:Allocate(reagent, quantity)
			return true
		end
	end
	return false
end

local function ClearTransactionAllocation(transaction, slotIndex)
	if not transaction or not slotIndex then
		return false
	end
	if transaction.ClearAllocations then
		local ok = pcall(transaction.ClearAllocations, transaction, slotIndex)
		return ok
	end
	if transaction.GetAllocations then
		local ok, allocations = pcall(transaction.GetAllocations, transaction, slotIndex)
		if ok and allocations and allocations.Clear then
			allocations:Clear()
			return true
		end
	end
	return false
end

local function ApplyPreparedCraftActiveSlotChange(slot, change)
	if not slot or not change then
		return
	end
	if change.reagent then
		if slot.SetReagent then
			pcall(slot.SetReagent, slot, change.reagent)
		end
		if slot.SetHighlightShown then
			pcall(slot.SetHighlightShown, slot, true)
		end
	else
		if slot.ClearReagent then
			pcall(slot.ClearReagent, slot)
		end
		if slot.SetHighlightShown then
			pcall(slot.SetHighlightShown, slot, false)
		end
	end
end

local function RefreshPreparedCraftOrderSlots(form, changedSlots)
	local pool = form and form.reagentSlotPool
	if not pool or not pool.EnumerateActive then
		return
	end
	for slot in pool:EnumerateActive() do
		local schematic
		if slot.GetReagentSlotSchematic then
			local ok, value = pcall(slot.GetReagentSlotSchematic, slot)
			if ok then
				schematic = value
			end
		end
		local slotIndex = ToSafeNumber(schematic and schematic.slotIndex)
		ApplyPreparedCraftActiveSlotChange(slot, slotIndex and changedSlots[slotIndex])
	end
end

function AF:ApplyTrackedCraftToCustomerOrder(entry)
	if InCombatLockdown and InCombatLockdown() then
		return false
	end

	local prepared = self:FindPreparedCraftForCustomerEntry(entry)
	if not prepared or type(prepared.reagents) ~= "table" or #prepared.reagents == 0 then
		return false
	end

	local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
	local transaction = form and form.transaction
	if not transaction then
		return false
	end

	local formRecipeID = GetCustomerOrderFormRecipeID(form)
	if not formRecipeID or formRecipeID ~= GetPreparedCraftRecipeID(prepared) then
		return false
	end

	local schematic = GetCustomerOrderFormSchematic(form, formRecipeID)
	if not schematic then
		return false
	end

	if form.UpdateReagentSlots then
		pcall(form.UpdateReagentSlots, form)
	end

	local changedSlots = {}
	local appliedCount = 0
	for _, preparedReagent in ipairs(prepared.reagents or {}) do
		local slot, slotReagent = FindPreparedReagentSlot(schematic, preparedReagent)
		local slotIndex = ToSafeNumber(slot and slot.slotIndex)
		if slotIndex and slotReagent then
			local quantity = GetPreparedAllocationQuantity(slot, slotReagent, preparedReagent)
			if OverwriteTransactionAllocation(transaction, slotIndex, slotReagent, quantity) then
				changedSlots[slotIndex] = { reagent = slotReagent }
				appliedCount = appliedCount + 1
			end
		end
	end

	if appliedCount == 0 then
		return false
	end

	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		local slotIndex = ToSafeNumber(slot.slotIndex)
		if slotIndex and IsOptionalSlot(slot) and not changedSlots[slotIndex] then
			if ClearTransactionAllocation(transaction, slotIndex) then
				changedSlots[slotIndex] = { cleared = true }
			end
		end
	end

	RefreshPreparedCraftOrderSlots(form, changedSlots)
	if form.UpdateListOrderButton then
		pcall(form.UpdateListOrderButton, form)
	end
	return true, prepared, appliedCount
end

