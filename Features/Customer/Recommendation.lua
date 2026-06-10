local _, AF = ...

local function GetScanModelVersion()
	return tonumber(AF.SCAN_MODEL_VERSION or 4)
end

local function HasCurrentReagentSkillFacts(facts)
	local scanModelVersion = GetScanModelVersion()
	return type(facts) == "table"
		and tonumber(facts.scanModelVersion) == scanModelVersion
		and tonumber(facts.baseSkill) ~= nil
		and tonumber(facts.baseRecipeDifficulty) ~= nil
		and tonumber(facts.maxOutputQuality) ~= nil
		and type(facts.requiredSlots) == "table"
		and type(facts.optionalSlots) == "table"
end

local function CopyTable(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local function SlotKey(slot, fallback)
	return tostring(slot and (slot.slotKey or slot.dataSlotIndex or slot.slotIndex) or fallback or "")
end

local function GetThresholdQuality(totalSkill, totalDifficulty, maxQuality)
	totalSkill = tonumber(totalSkill) or 0
	totalDifficulty = tonumber(totalDifficulty) or 0
	maxQuality = tonumber(maxQuality) or 1
	if maxQuality <= 1 or totalDifficulty <= 0 then
		return 1
	end
	local percent = (totalSkill / totalDifficulty) * 100
	if maxQuality >= 5 then
		if percent >= 100 then
			return 5
		elseif percent >= 80 then
			return 4
		elseif percent >= 50 then
			return 3
		elseif percent >= 20 then
			return 2
		end
		return 1
	elseif maxQuality == 3 then
		if percent >= 100 then
			return 3
		elseif percent >= 50 then
			return 2
		end
		return 1
	elseif maxQuality == 2 then
		return percent >= 100 and 2 or 1
	end
	return math.min(maxQuality, math.max(1, math.floor((percent / 100) * maxQuality) + 1))
end

local function NormalizeQualityBonusTable(slot)
	local bonuses = slot and slot.qualityBonuses
	if type(bonuses) ~= "table" then
		return nil
	end
	local normalized = {}
	for quality, bonus in pairs(bonuses) do
		local numericQuality = tonumber(quality)
		if numericQuality then
			normalized[numericQuality] = tonumber(bonus) or 0
		end
	end
	return normalized
end

local function GetReagentQualityByItemID(slot, itemID)
	itemID = tonumber(itemID)
	if not itemID then
		return nil
	end
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		if tonumber(reagent.itemID) == itemID then
			local quality = tonumber(reagent.quality)
			if quality and quality > 0 then
				return quality
			end
		end
	end
	return nil
end

local function GetQualityTierFromAtlas(atlas)
	return tonumber(tostring(atlas or ""):match("[Tt]ier(%d+)"))
end

local function GetQualityByItemInfo(itemID)
	if not itemID or not C_TradeSkillUI then
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
	if C_TradeSkillUI.GetItemReagentQualityInfo then
		local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
		if ok and type(qualityInfo) == "table" then
			return tonumber(qualityInfo.quality)
				or GetQualityTierFromAtlas(qualityInfo.iconInventory)
				or GetQualityTierFromAtlas(qualityInfo.iconSmall)
				or GetQualityTierFromAtlas(qualityInfo.icon)
				or GetQualityTierFromAtlas(qualityInfo.iconChat)
		end
	end
	return nil
end

local function GetSelectedRequiredQuality(slot, selections)
	local key = SlotKey(slot)
	local required = selections and selections.requiredQualities
	local selected = required and (required[key] or required[tonumber(slot.slotIndex)] or required[tonumber(slot.dataSlotIndex)])
	if type(selected) == "table" then
		local quality = tonumber(selected.quality)
		if quality and quality > 0 then
			return quality, true
		end
		return GetReagentQualityByItemID(slot, selected.itemID) or GetQualityByItemInfo(selected.itemID), true
	end
	return tonumber(selected), selected ~= nil
end

local function GetLowestRequiredQuality(slot)
	local lowest
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		local quality = tonumber(reagent.quality) or 0
		if quality > 0 and (not lowest or quality < lowest) then
			lowest = quality
		end
	end
	local bonuses = NormalizeQualityBonusTable(slot)
	for quality in pairs(bonuses or {}) do
		if quality > 0 and (not lowest or quality < lowest) then
			lowest = quality
		end
	end
	return lowest or 0
end

local function HasQualityChoices(slot)
	local seen = {}
	local count = 0
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		local quality = tonumber(reagent.quality) or 0
		if quality > 0 and not seen[quality] then
			seen[quality] = true
			count = count + 1
		end
	end
	for quality in pairs(NormalizeQualityBonusTable(slot) or {}) do
		if quality > 0 and not seen[quality] then
			seen[quality] = true
			count = count + 1
		end
	end
	return count > 1
end

local function HasNonZeroQualityBonus(slot)
	for _, bonus in pairs(NormalizeQualityBonusTable(slot) or {}) do
		if (tonumber(bonus) or 0) > 0 then
			return true
		end
	end
	return false
end

local function GetHighestRequiredQuality(slot)
	local highest = 0
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		highest = math.max(highest, tonumber(reagent.quality) or 0)
	end
	local bonuses = NormalizeQualityBonusTable(slot)
	for quality in pairs(bonuses or {}) do
		highest = math.max(highest, tonumber(quality) or 0)
	end
	return highest
end

local function GetRequiredSlotSkill(slot, quality)
	local bonuses = NormalizeQualityBonusTable(slot)
	if not bonuses then
		return 0
	end
	quality = tonumber(quality) or GetLowestRequiredQuality(slot)
	local bestQuality
	for candidateQuality in pairs(bonuses) do
		if candidateQuality <= quality and (not bestQuality or candidateQuality > bestQuality) then
			bestQuality = candidateQuality
		end
	end
	return (tonumber(bonuses[bestQuality or quality]) or 0) * (tonumber(slot.quantity) or 1)
end

local function GetOptionalDifficulty(selections)
	local total = 0
	for _, reagent in ipairs(selections and selections.optionalReagents or {}) do
		total = total + (tonumber(reagent.difficultyDelta or reagent.difficultyAdjustment or reagent.bonusDifficulty) or 0)
	end
	return total
end

local function GetOptionalSkill(selections)
	local total = 0
	for _, reagent in ipairs(selections and selections.optionalReagents or {}) do
		total = total + (tonumber(reagent.skillDelta or reagent.bonusSkill) or 0)
	end
	return total
end

function AF:GetCraftQualityForSkill(totalSkill, totalDifficulty, maxQuality)
	return GetThresholdQuality(totalSkill, totalDifficulty, maxQuality)
end

function AF:ComputeCraftOutcome(entry, selections)
	local facts = entry and (entry.reagentSkillFacts or entry.scanFacts)
	local missingData = {}
	if not HasCurrentReagentSkillFacts(facts) then
		missingData.reagentSkillFacts = true
		return {
			totalSkill = tonumber(entry and entry.totalSkill) or 0,
			totalDifficulty = tonumber(entry and entry.recipeDifficulty) or 0,
			quality = tonumber(entry and entry.quality) or 0,
			concentrationQuality = tonumber(entry and entry.concentrationQuality) or 0,
			missingData = missingData,
			rescanNeeded = true,
		}
	end

	local totalSkill = tonumber(facts.baseSkill) or tonumber(entry and entry.totalSkill) or 0
	local totalDifficulty = tonumber(facts.baseRecipeDifficulty) or tonumber(entry and entry.recipeDifficulty) or 0
	for slotIndex, slot in ipairs(facts.requiredSlots or {}) do
		local selectedQuality, hasSelection = GetSelectedRequiredQuality(slot, selections)
		local quality = selectedQuality or GetLowestRequiredQuality(slot)
		if quality > GetLowestRequiredQuality(slot) and HasQualityChoices(slot) and not HasNonZeroQualityBonus(slot) then
			missingData.reagentSkillFacts = true
		end
		if quality <= 0 then
			if hasSelection then
				quality = 1
			else
				missingData["required:" .. tostring(slotIndex)] = true
			end
		end
		totalSkill = totalSkill + GetRequiredSlotSkill(slot, quality)
	end
	totalDifficulty = totalDifficulty + GetOptionalDifficulty(selections)
	totalSkill = totalSkill + GetOptionalSkill(selections)

	local maxQuality = tonumber(facts.maxOutputQuality) or tonumber(entry and entry.maxOutputQuality) or 1
	local quality = GetThresholdQuality(totalSkill, totalDifficulty, maxQuality)
	return {
		totalSkill = totalSkill,
		totalDifficulty = totalDifficulty,
		quality = quality,
		concentrationQuality = math.min(quality + 1, maxQuality),
		maxQuality = maxQuality,
		missingData = next(missingData) and missingData or nil,
		rescanNeeded = next(missingData) ~= nil,
	}
end

local function BuildRequiredQualitySelection(facts, highest)
	local requiredQualities = {}
	for slotIndex, slot in ipairs(facts.requiredSlots or {}) do
		requiredQualities[SlotKey(slot, slotIndex)] = highest and GetHighestRequiredQuality(slot) or GetLowestRequiredQuality(slot)
	end
	return { requiredQualities = requiredQualities }
end

local function GetSlotImpact(slot)
	return GetRequiredSlotSkill(slot, GetHighestRequiredQuality(slot)) - GetRequiredSlotSkill(slot, GetLowestRequiredQuality(slot))
end

local function GetQualityChoices(slot)
	local choices = {}
	local seen = {}
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		local quality = tonumber(reagent.quality) or 0
		if quality > 0 and not seen[quality] then
			seen[quality] = true
			choices[#choices + 1] = quality
		end
	end
	local bonuses = NormalizeQualityBonusTable(slot)
	for quality in pairs(bonuses or {}) do
		if quality > 0 and not seen[quality] then
			seen[quality] = true
			choices[#choices + 1] = quality
		end
	end
	table.sort(choices)
	if #choices == 0 then
		choices[1] = 0
	end
	return choices
end

local function GetRepresentativeReagent(slot, quality)
	local selected
	for _, reagent in ipairs(slot and slot.reagents or {}) do
		if (tonumber(reagent.quality) or 0) == (tonumber(quality) or 0) then
			if not selected or (tonumber(reagent.itemID) or 0) < (tonumber(selected.itemID) or 0) then
				selected = reagent
			end
		end
	end
	if not selected then
		return nil
	end
	local copy = CopyTable(selected)
	copy.kind = copy.currencyID and "currency" or "item"
	copy.quantity = tonumber(slot.quantity) or tonumber(copy.quantity) or 1
	copy.dataSlotIndex = slot.dataSlotIndex
	copy.slotIndex = slot.slotIndex
	copy.slotKey = SlotKey(slot)
	copy.slotText = slot.slotText
	copy.quality = tonumber(copy.quality) or tonumber(quality)
	return copy
end

local function CompareSuggestion(left, right, impactSlots)
	if not right then
		return true
	end
	if left.qualityCost ~= right.qualityCost then
		return left.qualityCost < right.qualityCost
	end
	if left.maxQuality ~= right.maxQuality then
		return left.maxQuality < right.maxQuality
	end
	for _, slotInfo in ipairs(impactSlots) do
		local leftQuality = tonumber(left.requiredQualities[slotInfo.key]) or 0
		local rightQuality = tonumber(right.requiredQualities[slotInfo.key]) or 0
		if leftQuality ~= rightQuality then
			return leftQuality > rightQuality
		end
	end
	if left.skill ~= right.skill then
		return left.skill < right.skill
	end
	return left.signature < right.signature
end

function AF:BuildReagentSuggestion(entry, selections)
	local facts = entry and (entry.reagentSkillFacts or entry.scanFacts)
	if not HasCurrentReagentSkillFacts(facts) then
		return {
			rescanNeeded = true,
			missingData = { reagentSkillFacts = true },
			reagents = nil,
		}
	end

	local highestSelections = BuildRequiredQualitySelection(facts, true)
	highestSelections.optionalReagents = selections and selections.optionalReagents or nil
	local highestOutcome = self:ComputeCraftOutcome(entry, highestSelections)
	local targetQuality = highestOutcome.quality or 1
	local slots = facts.requiredSlots or {}
	local choicesBySlot = {}
	local impactSlots = {}
	for slotIndex, slot in ipairs(slots) do
		local key = SlotKey(slot, slotIndex)
		choicesBySlot[slotIndex] = GetQualityChoices(slot)
		impactSlots[#impactSlots + 1] = {
			key = key,
			impact = GetSlotImpact(slot),
		}
	end
	table.sort(impactSlots, function(left, right)
		if left.impact ~= right.impact then
			return left.impact > right.impact
		end
		return left.key < right.key
	end)

	local best
	local selectedQualities = {}
	local function Visit(slotIndex)
		if slotIndex > #slots then
			local requiredQualities = {}
			local qualityCost = 0
			local maxSelectedQuality = 0
			local signatureParts = {}
			for index, slot in ipairs(slots) do
				local key = SlotKey(slot, index)
				local quality = tonumber(selectedQualities[index]) or 0
				requiredQualities[key] = quality
				qualityCost = qualityCost + (quality * (tonumber(slot.quantity) or 1))
				maxSelectedQuality = math.max(maxSelectedQuality, quality)
				signatureParts[#signatureParts + 1] = key .. "=" .. tostring(quality)
			end
			table.sort(signatureParts)
			local outcome = AF:ComputeCraftOutcome(entry, {
				requiredQualities = requiredQualities,
				optionalReagents = selections and selections.optionalReagents or nil,
			})
			if outcome.quality >= targetQuality then
				local candidate = {
					requiredQualities = requiredQualities,
					outcome = outcome,
					quality = outcome.quality,
					concentrationQuality = outcome.concentrationQuality,
					skill = outcome.totalSkill,
					qualityCost = qualityCost,
					maxQuality = maxSelectedQuality,
					signature = table.concat(signatureParts, ";"),
				}
				if CompareSuggestion(candidate, best, impactSlots) then
					best = candidate
				end
			end
			return
		end
		for _, quality in ipairs(choicesBySlot[slotIndex] or {}) do
			selectedQualities[slotIndex] = quality
			Visit(slotIndex + 1)
		end
		selectedQualities[slotIndex] = nil
	end
	Visit(1)

	if not best then
		best = {
			requiredQualities = BuildRequiredQualitySelection(facts, true).requiredQualities,
			outcome = highestOutcome,
			quality = highestOutcome.quality,
			concentrationQuality = highestOutcome.concentrationQuality,
			skill = highestOutcome.totalSkill,
			qualityCost = 0,
			maxQuality = 0,
			signature = "highest",
		}
	end

	local reagents = {}
	for slotIndex, slot in ipairs(slots) do
		local reagent = GetRepresentativeReagent(slot, best.requiredQualities[SlotKey(slot, slotIndex)])
		if reagent then
			reagents[#reagents + 1] = reagent
		end
	end
	best.reagents = reagents
	best.targetQuality = targetQuality
	best.rescanNeeded = false
	return best
end
