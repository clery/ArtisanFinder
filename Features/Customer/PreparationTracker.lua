local _, AF = ...

local TRACKER_MAX_REAGENTS = 12
local TRACKER_MODULE_ORDER = 8.5

local PreparationObjectiveTrackerMixin = {}
local auctionatorLoadAttempted = false

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
		or slot.reagentType == Enum.CraftingReagentType.Optional
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

local function GetOwnedCount(reagent)
	if not reagent then
		return 0
	end
	if reagent.currencyID then
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
		return tonumber(currencyInfo and currencyInfo.quantity) or 0
	end
	if reagent.itemID and ProfessionsUtil and ProfessionsUtil.GetReagentQuantityInPossession then
		local ok, count = pcall(ProfessionsUtil.GetReagentQuantityInPossession, { itemID = reagent.itemID }, false)
		if ok and tonumber(count) then
			return tonumber(count)
		end
	end
	if reagent.itemID and C_Item and C_Item.GetItemCount then
		local ok, count = pcall(C_Item.GetItemCount, reagent.itemID, true, false, true)
		if ok and tonumber(count) then
			return tonumber(count)
		end
	end
	return 0
end

local function GetReagentName(reagent)
	if not reagent then
		return AF:Text("UNKNOWN")
	end
	if reagent.currencyID then
		local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
		return currencyInfo and currencyInfo.name or AF:Text("UNKNOWN")
	end
	if reagent.itemID then
		return C_Item.GetItemInfo(reagent.itemID) or AF:Text("ITEM_FALLBACK") .. " " .. tostring(reagent.itemID)
	end
	return AF:Text("UNKNOWN")
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

function AF:AddPreparedCraftToTracker(entry, mode, optionalReagents)
	local prepared = self:CreatePreparedCraftEntry(entry, mode, optionalReagents)
	if not prepared then
		return nil
	end
	self.db = self.db or self:EnsureDB()
	self.db.preparedCrafts = self.db.preparedCrafts or {}

	local replaced = false
	for index, existing in ipairs(self.db.preparedCrafts) do
		if existing.key == prepared.key then
			self.db.preparedCrafts[index] = prepared
			replaced = true
			break
		end
	end
	if not replaced then
		table.insert(self.db.preparedCrafts, 1, prepared)
	end

	self:RefreshPreparationTracker()
	self:Print(self:Text("PREP_TRACKER_ADDED", prepared.itemName or prepared.recipeID))
	return prepared
end

function AF:RemovePreparedCraft(key)
	if not self.db or not self.db.preparedCrafts then
		return
	end
	local fallbackIndex = tonumber(key)
	for index = #self.db.preparedCrafts, 1, -1 do
		local entry = self.db.preparedCrafts[index]
		if entry.key == key or (entry.key and key and tostring(entry.key) == tostring(key)) or (not entry.key and fallbackIndex == index) then
			table.remove(self.db.preparedCrafts, index)
			break
		end
	end
	self:RefreshPreparationTracker()
end

local function GetPreparationEntries()
	local entries = AF.db and AF.db.preparedCrafts
	return type(entries) == "table" and entries or {}
end

local function GetPreparationCount()
	return #GetPreparationEntries()
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

local function FindPreparedCraftEntry(block)
	if not block then
		return nil
	end
	if block.artisanFinderPreparedCraftEntry then
		return block.artisanFinderPreparedCraftEntry
	end

	local key = block.id
	if not key then
		return nil
	end

	local entries = GetPreparationEntries()
	for _, entry in ipairs(entries) do
		if entry and entry.key and tostring(entry.key) == tostring(key) then
			return entry
		end
	end

	local index = tonumber(key)
	if index and entries[index] then
		return entries[index]
	end

	local recipeID = tonumber(tostring(key):match("^(%-?%d+)"))
	if recipeID then
		return { key = key, recipeID = math.abs(recipeID) }
	end
	return nil
end

local function OpenPreparedCraftRecipe(entry)
	local recipeID = GetPreparedCraftRecipeID(entry)
	if not recipeID or not C_TradeSkillUI then
		return false
	end
	if issecretvalue and issecretvalue(recipeID) then
		return false
	end
	if not ProfessionsFrame and ProfessionsFrame_LoadUI then
		pcall(ProfessionsFrame_LoadUI)
	end

	if C_TradeSkillUI.IsRecipeProfessionLearned then
		local ok, learned = pcall(C_TradeSkillUI.IsRecipeProfessionLearned, recipeID)
		if ok and learned and C_TradeSkillUI.OpenRecipe then
			return pcall(C_TradeSkillUI.OpenRecipe, recipeID)
		elseif ok and not learned and Professions and Professions.InspectRecipe then
			return pcall(Professions.InspectRecipe, recipeID)
		end
	end

	if C_TradeSkillUI.OpenRecipe then
		return pcall(C_TradeSkillUI.OpenRecipe, recipeID)
	end
	if ProfessionsUtil and ProfessionsUtil.OpenProfessionFrameToRecipe then
		return pcall(ProfessionsUtil.OpenProfessionFrameToRecipe, recipeID)
	end
	return false
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

local function GetUntrackText()
	return OBJECTIVES_TRACKER_UNTRACK or UNTRACK or PROFESSIONS_UNTRACK_RECIPE or OBJECTIVES_STOP_TRACKING or "Untrack"
end

local function IsAuctionHouseShown()
	return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
end

local function TryLoadAuctionator()
	if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.LoadAddOn then
		return
	end
	if C_AddOns.IsAddOnLoaded("Auctionator") then
		return
	end
	if auctionatorLoadAttempted then
		return
	end
	auctionatorLoadAttempted = true
	pcall(C_AddOns.LoadAddOn, "Auctionator")
end

local function GetAuctionatorMultiSearchAPI()
	TryLoadAuctionator()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if type(api) == "table"
		and type(api.MultiSearchAdvanced) == "function" then
		return api
	end
	return nil
end

local function IsAuctionatorMultiSearchAvailable()
	return GetAuctionatorMultiSearchAPI() ~= nil
end

local function GetItemName(itemID)
	if not itemID then
		return nil
	end
	local itemName = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)
	if itemName and itemName ~= "" then
		return itemName
	end
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, itemID)
		if ok and name and name ~= "" then
			return name
		end
	end
	return nil
end

local function IsSecret(value)
	return AF.IsSecretValue and AF:IsSecretValue(value)
end

local function GetBindOnPickupItemBind()
	return Enum and Enum.ItemBind and Enum.ItemBind.OnAcquire or 1
end

local function IsBindOnPickupBindType(bindType)
	if bindType == nil or IsSecret(bindType) then
		return false
	end
	return tonumber(bindType) == tonumber(GetBindOnPickupItemBind())
end

local function IsBindOnPickupFromItemInfo(itemID)
	if not C_Item or not C_Item.GetItemInfo then
		return nil
	end
	local result = { pcall(C_Item.GetItemInfo, itemID) }
	if not result[1] then
		return nil
	end
	local bindType = result[15]
	if bindType == nil then
		return nil
	end
	return IsBindOnPickupBindType(bindType)
end

local function IsTooltipBindOnPickupArg(arg, bindOnPickup)
	if type(arg) ~= "table" then
		return false
	end
	local intVal = arg.intVal
	if intVal ~= nil and not IsSecret(intVal) and tonumber(intVal) == tonumber(bindOnPickup) then
		return true
	end
	return false
end

local function IsTooltipBindOnPickupLine(line)
	if type(line) ~= "table" or not Enum or not Enum.TooltipDataLineType then
		return false
	end
	local lineType = line.type
	if lineType == nil or IsSecret(lineType) or tonumber(lineType) ~= tonumber(Enum.TooltipDataLineType.ItemBinding) then
		return false
	end

	local bindOnPickup = Enum.TooltipDataItemBinding and Enum.TooltipDataItemBinding.BindOnPickup
	for _, arg in ipairs(type(line.args) == "table" and line.args or {}) do
		if bindOnPickup ~= nil and IsTooltipBindOnPickupArg(arg, bindOnPickup) then
			return true
		end
	end

	local leftText = line.leftText
	return ITEM_BIND_ON_PICKUP and leftText ~= nil and not IsSecret(leftText) and leftText == ITEM_BIND_ON_PICKUP
end

local function IsBindOnPickupFromTooltip(itemID)
	if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then
		return false
	end
	local ok, tooltipData = pcall(C_TooltipInfo.GetItemByID, itemID)
	if not ok or type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" then
		return false
	end
	for _, line in ipairs(tooltipData.lines) do
		if IsTooltipBindOnPickupLine(line) then
			return true
		end
	end
	return false
end

local function IsItemBindOnPickup(itemID)
	local itemInfoResult = IsBindOnPickupFromItemInfo(itemID)
	if itemInfoResult ~= nil then
		return itemInfoResult
	end
	return IsBindOnPickupFromTooltip(itemID)
end

local function AddItemContinuable(container, itemID)
	if not container or not itemID or not Item or not Item.CreateFromItemID then
		return
	end
	container:AddContinuable(Item:CreateFromItemID(itemID))
end

local function GetAuctionatorTemporarySearchName()
	if type(AUCTIONATOR_L_REAGENT_SEARCH) == "string" and AUCTIONATOR_L_REAGENT_SEARCH ~= "" then
		return AUCTIONATOR_L_REAGENT_SEARCH
	end
	return AF:Text("PREP_TRACKER_AUCTIONATOR_SEARCH_NAME")
end

local function GetAuctionatorSearchKey(itemID, quality)
	return tostring(itemID or 0) .. ":" .. tostring(quality or 0)
end

local function BuildAuctionatorSearchEntries()
	local totals = {}
	local orderedTotals = {}
	local searchEntries = {}

	for _, entry in ipairs(GetPreparationEntries()) do
		for _, reagent in ipairs(entry and entry.reagents or {}) do
			local itemID = tonumber(reagent.itemID)
			if itemID and itemID > 0 and not IsItemBindOnPickup(itemID) then
				local needed = tonumber(reagent.quantity) or 1
				if needed > 0 then
					local quality = tonumber(reagent.quality) or 0
					local key = GetAuctionatorSearchKey(itemID, quality)
					local existing = totals[key]
					if existing then
						existing.quantity = existing.quantity + needed
					else
						existing = {
							itemID = itemID,
							quality = quality > 0 and quality or nil,
							quantity = needed,
							reagent = reagent,
						}
						totals[key] = existing
						table.insert(orderedTotals, existing)
					end
				end
			end
		end
	end

	for _, entry in ipairs(orderedTotals) do
		local missing = math.max(0, (tonumber(entry.quantity) or 1) - GetOwnedCount(entry.reagent))
		if missing > 0 then
			table.insert(searchEntries, {
				itemID = entry.itemID,
				quality = entry.quality,
				quantity = missing,
			})
		end
	end

	table.sort(searchEntries, function(left, right)
		if left.itemID ~= right.itemID then
			return left.itemID < right.itemID
		end
		return (left.quality or 0) < (right.quality or 0)
	end)

	return searchEntries
end

local function BuildAuctionatorSearchTerm(searchEntry)
	local itemName = GetItemName(searchEntry and searchEntry.itemID)
	if not itemName then
		return nil
	end

	local term = {
		searchString = itemName,
		isExact = true,
		quantity = tonumber(searchEntry.quantity) or 1,
	}
	if searchEntry.quality then
		term.tier = searchEntry.quality
	end

	return term
end

local function SearchAuctionatorMissingReagents()
	local api = GetAuctionatorMultiSearchAPI()
	if not api then
		return 0, 0, false
	end

	local searchTerms = {}
	local skipped = 0
	for _, searchEntry in ipairs(BuildAuctionatorSearchEntries()) do
		local searchTerm = BuildAuctionatorSearchTerm(searchEntry)
		if searchTerm then
			table.insert(searchTerms, searchTerm)
		else
			skipped = skipped + 1
		end
	end

	if #searchTerms == 0 then
		return 0, skipped, true
	end

	local ok, errorMessage = pcall(api.MultiSearchAdvanced, GetAuctionatorTemporarySearchName(), searchTerms)
	if not ok then
		if AF.DebugLog then
			AF:DebugLog("auctionator", "MultiSearchAdvanced failed: " .. tostring(errorMessage))
		end
		return 0, skipped, false
	end

	return #searchTerms, skipped, true
end

local function ContinueWhenPreparationItemsLoad(callback)
	if not callback then
		return
	end

	local continuableContainer = ContinuableContainer and ContinuableContainer.Create and ContinuableContainer:Create()
	if continuableContainer then
		local seen = {}
		for _, searchEntry in ipairs(BuildAuctionatorSearchEntries()) do
			if searchEntry.itemID and not seen[searchEntry.itemID] then
				seen[searchEntry.itemID] = true
				AddItemContinuable(continuableContainer, searchEntry.itemID)
			end
		end
		continuableContainer:ContinueOnLoad(callback)
		return
	end

	for _, searchEntry in ipairs(BuildAuctionatorSearchEntries()) do
		if C_Item and C_Item.RequestLoadItemDataByID and searchEntry.itemID then
			pcall(C_Item.RequestLoadItemDataByID, searchEntry.itemID)
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0.5, callback)
	else
		callback()
	end
end

function AF:SearchAuctionatorPreparationReagents()
	if not IsAuctionHouseShown() or not IsAuctionatorMultiSearchAvailable() then
		return false
	end

	ContinueWhenPreparationItemsLoad(function()
		local searched, skipped, success = SearchAuctionatorMissingReagents()
		if success and searched > 0 then
			self:Print(self:Text("PREP_TRACKER_AUCTIONATOR_SEARCHED", searched))
		end
		if skipped > 0 and self.DebugLog then
			self:DebugLog("auctionator", string.format("Skipped %d preparation reagent(s) with unavailable item names.", skipped))
		end
	end)
	return true
end

local function HasObjectiveTrackerRuntime()
	return ObjectiveTrackerFrame
		and ObjectiveTrackerModuleMixin
		and ObjectiveTrackerManager
		and ObjectiveTrackerContainerMixin
end

local function GetObjectiveTrackerColor(style)
	if OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR[style] then
		return OBJECTIVE_TRACKER_COLOR[style]
	end
	if style == "Complete" then
		return { r = 0.6, g = 0.6, b = 0.6 }
	end
	return { r = 0.8, g = 0.8, b = 0.8 }
end

local function GetObjectiveDashStyle(style)
	if style == "hide" then
		return OBJECTIVE_DASH_STYLE_HIDE or 2
	elseif style == "collapse" then
		return OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE or 3
	end
	return OBJECTIVE_DASH_STYLE_SHOW or 1
end

local function FormatTrackerReagentText(countText, reagentName)
	if PROFESSIONS_TRACKER_REAGENT_FORMAT then
		return PROFESSIONS_TRACKER_REAGENT_FORMAT:format(countText, reagentName)
	end
	return tostring(countText) .. " " .. tostring(reagentName)
end

local function FormatTrackerReagentName(reagentName, reagent)
	local quality = tonumber(reagent and reagent.quality)
	if not quality or quality <= 0 then
		return reagentName
	end
	local qualityText = AF.FormatReagentQuality and AF:FormatReagentQuality(quality, 14, { itemID = reagent.itemID, reagent = reagent }) or ("Q" .. quality)
	if not qualityText or qualityText == "" then
		return reagentName
	end
	if qualityText == ("Q" .. quality) then
		qualityText = "(" .. qualityText .. ")"
	end
	return tostring(reagentName) .. " " .. qualityText
end

local function OpenReagentTooltip(owner, reagent)
	if not owner or not reagent then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if reagent.itemID then
		AF:HideEmbeddedItemTooltip(GameTooltip)
		GameTooltip:SetHyperlink("item:" .. tostring(reagent.itemID))
		AF:HideEmbeddedItemTooltip(GameTooltip)
	else
		GameTooltip:SetText(GetReagentName(reagent), 1, 1, 1, 1, true)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(AF:Text("PREP_TRACKER_REAGENT_COUNTS", GetOwnedCount(reagent), tonumber(reagent.quantity) or 1), 1, 0.82, 0, true)
	if reagent.slotText and reagent.slotText ~= "" then
		GameTooltip:AddLine(reagent.slotText, 0.65, 0.65, 0.65, true)
	end
	GameTooltip:Show()
end

local function ReleaseLineButton(_, button)
	button.entryKey = nil
	button.reagent = nil
	button:Hide()
	button:SetParent(nil)
	button:ClearAllPoints()
	button:SetScript("OnClick", nil)
	button:SetScript("OnEnter", nil)
	button:SetScript("OnLeave", nil)
end

local function GetLineButtonPool()
	if not AF.preparationObjectiveTrackerLineButtonPool then
		AF.preparationObjectiveTrackerLineButtonPool = CreateFramePool("Button", nil, nil, ReleaseLineButton)
	end
	return AF.preparationObjectiveTrackerLineButtonPool
end

local function AttachLineButton(module, line, entryKey, reagent)
	if not line then
		return
	end

	line.entryKey = entryKey
	line.reagent = reagent
	if line.Button then
		line.Button.entryKey = entryKey
		line.Button.reagent = reagent
		line.Button:Show()
		return
	end

	local pool = GetLineButtonPool()
	local button = pool:Acquire()
	button.entryKey = entryKey
	button.reagent = reagent
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetParent(line)
	button:SetAllPoints(line)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" and self.entryKey then
			AF:RemovePreparedCraft(self.entryKey)
		end
	end)
	button:SetScript("OnEnter", function(self)
		OpenReagentTooltip(self, self.reagent)
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:Show()
	line.Button = button

	local originalOnFree = line.OnFree
	line.OnFree = function(self, ...)
		if self.Button then
			pool:Release(self.Button)
		end
		self.Button = nil
		self.entryKey = nil
		self.reagent = nil
		self.OnFree = originalOnFree
		if self.OnFree then
			return self:OnFree(...)
		end
	end
end

function PreparationObjectiveTrackerMixin:CanUpdate()
	return true
end

function PreparationObjectiveTrackerMixin:InitModule()
	self:RegisterEvent("BAG_UPDATE_DELAYED")
	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
	self:RegisterEvent("ADDON_LOADED")
	self:UpdateSearchButton()
end

function PreparationObjectiveTrackerMixin:OnEvent(eventName, eventData)
	if eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or eventName == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
		if not Enum or not Enum.PlayerInteractionType or eventData == Enum.PlayerInteractionType.Auctioneer then
			self:UpdateSearchButton()
		end
		return
	end
	if eventName == "ADDON_LOADED" then
		if eventData == "Auctionator" then
			self:UpdateSearchButton()
		end
		return
	end
	-- Bag/item/currency events fire constantly; they only matter while
	-- prepared crafts are displayed.
	if GetPreparationCount() == 0 then
		return
	end
	self:MarkDirty()
end

function PreparationObjectiveTrackerMixin:UpdateSearchButton()
	local button = self.SearchButton
	if not button then
		return
	end

	local shouldShow = GetPreparationCount() > 0 and IsAuctionHouseShown()
	button:SetShown(shouldShow)
	if not shouldShow then
		return
	end
	if IsAuctionatorMultiSearchAvailable() then
		button:Enable()
	else
		button:Disable()
	end
end

function PreparationObjectiveTrackerMixin:LayoutContents()
	local entries = GetPreparationEntries()
	if #entries == 0 then
		self:UpdateSearchButton()
		return
	end

	for index, entry in ipairs(entries) do
		if not self:AddPreparedCraftBlock(entry, index) then
			return
		end
	end
	self:UpdateSearchButton()
end

function PreparationObjectiveTrackerMixin:AddPreparedCraftBlock(entry, index)
	local entryKey = entry.key or index
	local block = self:GetBlock(entryKey)
	block.artisanFinderPreparedCraftEntry = entry
	block.artisanFinderPreparedCraftKey = entryKey
	block.artisanFinderPreparedCraftRecipeID = GetPreparedCraftRecipeID(entry)
	local title = entry.itemName or entry.recipeID or ""
	block:SetHeader(title)

	local missingTotal = 0
	local shownReagents = 0
	for _, reagent in ipairs(entry.reagents or {}) do
		local owned = GetOwnedCount(reagent)
		local needed = tonumber(reagent.quantity) or 1
		local missing = math.max(0, needed - owned)
		missingTotal = missingTotal + missing
	end

	local modeKey = entry.mode == "advanced" and "PREP_TRACKER_MODE_ADVANCED" or entry.mode == "optional" and "PREP_TRACKER_MODE_OPTIONAL" or "PREP_TRACKER_MODE_STANDARD"
	local summaryText = missingTotal > 0 and AF:Text("PREP_TRACKER_MISSING", missingTotal) or AF:Text("PREP_TRACKER_READY")
	local modeText = AF:Text(modeKey, entry.target or "")
	local summaryColor = GetObjectiveTrackerColor(missingTotal > 0 and "Normal" or "Complete")
	local summaryLine = block:AddObjective("summary", modeText .. " - " .. summaryText, nil, nil, GetObjectiveDashStyle("collapse"), summaryColor)
	if summaryLine.Icon then
		summaryLine.Icon:SetShown(missingTotal == 0)
		if missingTotal == 0 then
			summaryLine.Icon:SetAtlas("ui-questtracker-tracker-check", false)
		end
	end

	for reagentIndex, reagent in ipairs(entry.reagents or {}) do
		if shownReagents >= TRACKER_MAX_REAGENTS then
			break
		end
		shownReagents = shownReagents + 1
		local owned = GetOwnedCount(reagent)
		local needed = tonumber(reagent.quantity) or 1
		local complete = owned >= needed
		local countText = AF:Text("PREP_TRACKER_COUNT", owned, needed)
		local name = FormatTrackerReagentName(GetReagentName(reagent), reagent)
		local lineText = FormatTrackerReagentText(countText, name)

		local dashStyle = GetObjectiveDashStyle(complete and "hide" or "show")
		local colorStyle = GetObjectiveTrackerColor(complete and "Complete" or "Normal")
		local line = block:AddObjective(reagentIndex, lineText, nil, nil, dashStyle, colorStyle)
		if line.Icon then
			line.Icon:SetShown(complete)
			if complete then
				line.Icon:SetAtlas("ui-questtracker-tracker-check", false)
			end
		end
		AttachLineButton(self, line, entryKey, reagent)
	end

	if #(entry.reagents or {}) > TRACKER_MAX_REAGENTS then
		local more = #(entry.reagents or {}) - TRACKER_MAX_REAGENTS
		block:AddObjective("more", AF:Text("PREP_TRACKER_MORE", more), nil, nil, GetObjectiveDashStyle("collapse"), GetObjectiveTrackerColor("Normal"))
	end

	return self:LayoutBlock(block)
end

function PreparationObjectiveTrackerMixin:OnBlockHeaderClick(block, mouseButton)
	if not block then
		return
	end
	local key = block.id
	local activeChatWindow = ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow()
	if not activeChatWindow and ChatEdit_GetActiveWindow then
		activeChatWindow = ChatEdit_GetActiveWindow()
	end
	if IsModifiedClick and IsModifiedClick("CHATLINK") and activeChatWindow then
		local entry = FindPreparedCraftEntry(block)
		local recipeID = GetPreparedCraftRecipeID(entry)
		local link = recipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(recipeID)
		if link then
			if ChatFrameUtil and ChatFrameUtil.InsertLink then
				ChatFrameUtil.InsertLink(link)
			elseif ChatEdit_InsertLink then
				ChatEdit_InsertLink(link)
			end
		end
		return
	end

	if mouseButton == "RightButton" or (IsModifiedClick and IsModifiedClick("RECIPEWATCHTOGGLE")) then
		if MenuUtil and MenuUtil.CreateContextMenu and mouseButton == "RightButton" then
			MenuUtil.CreateContextMenu(self:GetContextMenuParent(), function(_, rootDescription)
				rootDescription:SetTag("MENU_ARTISANFINDER_PREPARATION_TRACKER")
				rootDescription:CreateButton(GetUntrackText(), function()
					AF:RemovePreparedCraft(key)
				end)
			end)
		else
			AF:RemovePreparedCraft(key)
		end
	else
		OpenPreparedCraftRecipe(FindPreparedCraftEntry(block))
	end
end

local function CreatePreparationObjectiveTrackerModule()
	if not HasObjectiveTrackerRuntime() then
		return nil
	end

	local settings = {
		headerText = AF:Text("PREP_TRACKER_HEADER"),
		blockTemplate = "ObjectiveTrackerAnimBlockTemplate",
		lineTemplate = "ObjectiveTrackerAnimLineTemplate",
		uiOrder = TRACKER_MODULE_ORDER,
	}

	local module = Mixin(CreateFrame("Frame", "ArtisanFinderPreparationObjectiveTracker", nil, "ObjectiveTrackerModuleTemplate"), ObjectiveTrackerModuleMixin, PreparationObjectiveTrackerMixin, settings)
	module:SetScript("OnLoad", module.OnLoad)
	module:SetScript("OnEvent", module.OnEvent)
	module:SetScript("OnHide", module.OnHide)
	module:OnLoad()
	if module.Header then
		local ok, button = pcall(CreateFrame, "Button", nil, module.Header, "UIPanelDynamicResizeButtonTemplate")
		if not ok or not button then
			button = CreateFrame("Button", nil, module.Header, "UIPanelButtonTemplate")
		end
		button:SetText(AF:Text("PREP_TRACKER_SEARCH"))
		button:SetSize(75, 22)
		button:SetPoint("TOPRIGHT", module.Header.MinimizeButton or module.Header, "TOPLEFT", -30, 5)
		button:RegisterForClicks("LeftButtonUp")
		button:SetScript("OnClick", function()
			AF:SearchAuctionatorPreparationReagents()
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if IsAuctionatorMultiSearchAvailable() then
				GameTooltip:SetText(AF:Text("PREP_TRACKER_SEARCH"), 1, 1, 1, 1, true)
				GameTooltip:AddLine(AF:Text("PREP_TRACKER_AUCTIONATOR_TOOLTIP"), 0.65, 0.65, 0.65, true)
			else
				GameTooltip:SetText(AF:Text("PREP_TRACKER_AUCTIONATOR_UNAVAILABLE"), 1, 0.82, 0, 1, true)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		button:Hide()
		module.SearchButton = button

		if module.Header.Text then
			module.Header.Text:ClearAllPoints()
			module.Header.Text:SetPoint("LEFT", module.Header, "LEFT", 7, 0)
			module.Header.Text:SetPoint("RIGHT", button, "LEFT", -6, 0)
		end
	end
	return module
end

function AF:IsPreparationObjectiveTrackerInstalled()
	local module = self.preparationObjectiveTracker
	local frame = ObjectiveTrackerFrame
	return module and frame and frame.HasModule and frame:HasModule(module)
end

function AF:InstallPreparationObjectiveTracker()
	if not HasObjectiveTrackerRuntime() then
		return false
	end

	local module = self.preparationObjectiveTracker
	if not module then
		module = CreatePreparationObjectiveTrackerModule()
		self.preparationObjectiveTracker = module
	end
	if not module then
		return false
	end

	module.uiOrder = TRACKER_MODULE_ORDER
	if ProfessionsRecipeTracker and ProfessionsRecipeTracker.uiOrder then
		module.uiOrder = ProfessionsRecipeTracker.uiOrder - 0.1
	end

	local isInstalled = ObjectiveTrackerFrame.HasModule and ObjectiveTrackerFrame:HasModule(module)
	local addedModule = false
	if not isInstalled then
		if ObjectiveTrackerManager and ObjectiveTrackerManager.SetModuleContainer then
			ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
		elseif ObjectiveTrackerFrame.AddModule then
			ObjectiveTrackerFrame:AddModule(module)
		else
			module:SetContainer(ObjectiveTrackerFrame)
		end
		addedModule = true
	end

	if addedModule and ObjectiveTrackerFrame.MarkDirty then
		ObjectiveTrackerFrame:MarkDirty()
	elseif addedModule and ObjectiveTrackerFrame.Update then
		ObjectiveTrackerFrame:Update()
	end

	return true
end

function AF:EnsurePreparationObjectiveTrackerHook()
	if self.preparationObjectiveTrackerHooked or not ObjectiveTrackerContainerMixin or not hooksecurefunc then
		return
	end
	hooksecurefunc(ObjectiveTrackerContainerMixin, "Update", function(container)
		if container == ObjectiveTrackerFrame and GetPreparationCount() > 0 and AF.InstallPreparationObjectiveTracker then
			AF:InstallPreparationObjectiveTracker()
		end
	end)
	self.preparationObjectiveTrackerHooked = true
end

function AF:EnsurePreparationTracker()
	if self:InstallPreparationObjectiveTracker() then
		self:EnsurePreparationObjectiveTrackerHook()
		return self.preparationObjectiveTracker
	end
	return nil
end

function AF:RefreshPreparationTracker()
	local module = self:EnsurePreparationTracker()
	if module and module.MarkDirty then
		module:MarkDirty()
	elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.MarkDirty then
		ObjectiveTrackerFrame:MarkDirty()
	end
end

function AF:InitializePreparationTracker()
	if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker") then
		if C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_ObjectiveTracker")
		end
		if not self.preparationObjectiveTrackerLoader then
			local loader = CreateFrame("Frame")
			loader:RegisterEvent("ADDON_LOADED")
			loader:SetScript("OnEvent", function(frame, _, addonName)
				if addonName == "Blizzard_ObjectiveTracker" then
					frame:UnregisterEvent("ADDON_LOADED")
					AF:EnsurePreparationTracker()
					AF:RefreshPreparationTracker()
				end
			end)
			self.preparationObjectiveTrackerLoader = loader
		end
	end

	self:EnsurePreparationTracker()
	self:RefreshPreparationTracker()
end
