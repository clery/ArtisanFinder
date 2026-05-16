local _, AF = ...

local MAX_REAGENT_COMBINATIONS = 72
local MAX_REAGENT_SUMMARY_BYTES = 900
local MAX_OPTIONAL_REAGENTS_PER_SLOT = 8
local SCAN_SIGNATURE_VERSION = 22
local GetOperationQuality
local GetRecipeDisplayQuality
local GetRecipeDisplayQualityInfo

local function SortNumbers(left, right)
	return tonumber(left) < tonumber(right)
end

local function AddOutput(outputs, itemID)
	itemID = tonumber(itemID)
	if itemID then
		outputs[itemID] = true
	end
end

local function ReagentMatches(left, right)
	if not left or not right then
		return false
	end
	return (left.itemID and left.itemID ~= 0 and left.itemID == right.itemID)
		or (left.currencyID and left.currencyID ~= 0 and left.currencyID == right.currencyID)
end

local function GetQuantityRequired(reagentSlotSchematic, reagent)
	for _, variableQuantity in ipairs(reagentSlotSchematic.variableQuantities or {}) do
		if ReagentMatches(reagent, variableQuantity.reagent) then
			return tonumber(variableQuantity.quantity) or reagentSlotSchematic.quantityRequired or 1
		end
	end
	return tonumber(reagentSlotSchematic.quantityRequired) or 1
end

local function GetReagentQuality(reagent)
	if not reagent or not reagent.itemID or not C_TradeSkillUI or not C_TradeSkillUI.GetItemReagentQualityInfo then
		return 0
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, reagent.itemID)
	if ok and qualityInfo then
		return tonumber(qualityInfo.quality) or 0
	end
	return 0
end

local function GetReagentQualityMarkup(reagent)
	if not reagent or not reagent.itemID or not C_TradeSkillUI or not C_TradeSkillUI.GetItemReagentQualityInfo then
		return nil
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, reagent.itemID)
	if ok and qualityInfo then
		local atlas = qualityInfo.iconSmall or qualityInfo.icon
		if atlas and CreateAtlasMarkup then
			local okMarkup, markup = pcall(CreateAtlasMarkup, atlas, 16, 16)
			if okMarkup and markup and markup ~= "" then
				return markup
			end
		end
		return AF:GetQualityIconMarkup(qualityInfo.quality)
	end
	return nil
end

local function GetQualityTierFromAtlas(atlas)
	return tonumber(tostring(atlas or ""):match("[Tt]ier(%d+)"))
end

local function GetReagentQualityInfoFromItemID(itemID)
	if not itemID or not C_TradeSkillUI or not C_TradeSkillUI.GetItemReagentQualityInfo then
		return nil, nil
	end
	local ok, reagentQualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
	if ok and reagentQualityInfo then
		return tonumber(reagentQualityInfo.quality), reagentQualityInfo.iconSmall or reagentQualityInfo.icon
	end
	return nil, nil
end

local function GetReagentQualityFromItemID(itemID)
	local quality = GetReagentQualityInfoFromItemID(itemID)
	return quality
end

local function IsLowerQualityReagent(left, right)
	if not right then
		return true
	end
	if not left then
		return false
	end
	local leftQuality = GetReagentQuality(left) or 0
	local rightQuality = GetReagentQuality(right) or 0
	if leftQuality ~= rightQuality then
		return leftQuality < rightQuality
	end
	return (tonumber(left.itemID) or tonumber(left.currencyID) or 0) < (tonumber(right.itemID) or tonumber(right.currencyID) or 0)
end

local function IsHigherQualityReagent(left, right)
	if not right then
		return true
	end
	if not left then
		return false
	end
	local leftQuality = GetReagentQuality(left) or 0
	local rightQuality = GetReagentQuality(right) or 0
	if leftQuality ~= rightQuality then
		return leftQuality > rightQuality
	end
	return (tonumber(left.itemID) or tonumber(left.currencyID) or 0) > (tonumber(right.itemID) or tonumber(right.currencyID) or 0)
end

local function GetReagentName(reagent)
	if not reagent then
		return nil
	end
	if reagent.itemID then
		local itemName
		if C_Item and C_Item.GetItemInfo then
			itemName = C_Item.GetItemInfo(reagent.itemID)
		elseif GetItemInfo then
			itemName = GetItemInfo(reagent.itemID)
		end
		if not itemName and C_Item and C_Item.RequestLoadItemDataByID then
			pcall(C_Item.RequestLoadItemDataByID, reagent.itemID)
			if C_Timer and not AF.reagentNameRetryQueued then
				AF.reagentNameRetryQueued = true
				C_Timer.After(2, function()
					AF.reagentNameRetryQueued = false
					if AF.QueueAutoScanForChange then
						AF:QueueAutoScanForChange("ITEM_DATA_LOADED")
					end
				end)
			end
		end
		return itemName
	end
	if reagent.currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local info = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
		return info and info.name or nil
	end
	return nil
end

local function GetOperationTotalSkill(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	local totalSkill = (tonumber(operationInfo.baseSkill) or 0) + (tonumber(operationInfo.bonusSkill) or 0)
	return totalSkill > 0 and totalSkill or nil
end

local function FormatOperationDebug(operationInfo)
	if type(operationInfo) ~= "table" then
		return "-"
	end
	return table.concat({
		"craftingQuality=" .. tostring(operationInfo.craftingQuality or "-"),
		"quality=" .. tostring(operationInfo.quality or "-"),
		"guaranteed=" .. tostring(operationInfo.guaranteedCraftingQualityID or "-"),
		"skill=" .. tostring(GetOperationTotalSkill(operationInfo) or "-"),
		"baseSkill=" .. tostring(operationInfo.baseSkill or "-"),
		"bonusSkill=" .. tostring(operationInfo.bonusSkill or "-"),
		"difficulty=" .. tostring(operationInfo.baseDifficulty or "-"),
		"bonusDifficulty=" .. tostring(operationInfo.bonusDifficulty or "-"),
		"lower=" .. tostring(operationInfo.lowerSkillThreshold or "-"),
		"upper=" .. tostring(operationInfo.upperSkillTreshold or operationInfo.upperSkillThreshold or "-"),
	}, ", ")
end

local function ScoreOperationPair(normalInfo, concentrationInfo)
	local normalQuality = GetOperationQuality(normalInfo) or 0
	local concentrationQuality = GetOperationQuality(concentrationInfo) or 0
	local totalSkill = GetOperationTotalSkill(normalInfo) or GetOperationTotalSkill(concentrationInfo) or 0
	local concentrationCost = tonumber(concentrationInfo and concentrationInfo.concentrationCost) or 999999
	return normalQuality, concentrationQuality, totalSkill, -concentrationCost
end

local function IsBetterOperation(normalInfo, concentrationInfo, reagentQualityScore, best)
	local quality, concentrationQuality, totalSkill, inverseCost = ScoreOperationPair(normalInfo, concentrationInfo)
	if not best then
		return true
	end
	local bestQuality, bestConcentrationQuality, bestSkill, bestInverseCost = ScoreOperationPair(best.normalInfo, best.concentrationInfo)
	if quality ~= bestQuality then
		return quality > bestQuality
	end
	if concentrationQuality ~= bestConcentrationQuality then
		return concentrationQuality > bestConcentrationQuality
	end
	if reagentQualityScore ~= (best.reagentQualityScore or 0) then
		return reagentQualityScore < (best.reagentQualityScore or 0)
	end
	if inverseCost ~= bestInverseCost then
		return inverseCost > bestInverseCost
	end
	return totalSkill > bestSkill
end

local function AddReagentInfo(tbl, reagentSlotSchematic, reagent)
	local quantity = GetQuantityRequired(reagentSlotSchematic, reagent)
	table.insert(tbl, {
		reagent = reagent,
		dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
		quantity = quantity,
	})
end

local function IsModifiedReagentSlot(reagentSlotSchematic)
	return not Enum
		or not Enum.TradeskillSlotDataType
		or reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

local function TryCraftingOperationInfo(recipeID, reagentVariants, applyConcentration)
	local debugParts = {}
	for _, variant in ipairs(reagentVariants) do
		local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, variant.reagents, nil, applyConcentration)
		if ok and type(operationInfo) == "table" then
			return operationInfo, variant.name, table.concat(debugParts, "; ")
		end
		table.insert(debugParts, variant.name .. "=" .. (ok and "nil" or "error"))
	end
	return nil, nil, table.concat(debugParts, "; ")
end

local function BuildSummaryEntry(reagentSlotSchematic, reagent)
	local quantity = GetQuantityRequired(reagentSlotSchematic, reagent)
	local reagentName = GetReagentName(reagent)
	if not reagentName then
		return nil
	end
	local itemIcon = reagent.itemID and (AF:GetItemIconMarkup(reagent.itemID, 16) or "") or ""
	local qualityText = GetReagentQuality(reagent) > 0 and (" " .. (GetReagentQualityMarkup(reagent) or "")) or ""
	return string.format("%s%s x%d%s", itemIcon ~= "" and (itemIcon .. " ") or "", reagentName, quantity, qualityText)
end

local function TrimSummaryByLine(summary, maxBytes)
	if not maxBytes or #summary <= maxBytes then
		return summary, false
	end

	local lines = {}
	local length = 0
	for reagentText in tostring(summary or ""):gmatch("[^;\n]+") do
		reagentText = reagentText:match("^%s*(.-)%s*$")
		if reagentText ~= "" then
			local separatorLength = #lines > 0 and 2 or 0
			if length + separatorLength + #reagentText > maxBytes then
				return table.concat(lines, "; "), true
			end
			table.insert(lines, reagentText)
			length = length + separatorLength + #reagentText
		end
	end

	return table.concat(lines, "; "), true
end

function AF:GetCurrentProfessionInfo()
	if not C_TradeSkillUI or not C_TradeSkillUI.GetChildProfessionInfo then
		return nil
	end
	local info = C_TradeSkillUI.GetChildProfessionInfo()
	if not info then
		return nil
	end
	local professionID = info.profession or info.professionID or info.skillLineID
	if not professionID and C_TradeSkillUI.GetProfessionChildSkillLineID then
		professionID = C_TradeSkillUI.GetProfessionChildSkillLineID()
	end
	if not professionID then
		return nil
	end
	return {
		id = professionID,
		name = info.professionName or info.parentProfessionName or self:Text("PROFESSION_FALLBACK", tostring(professionID)),
	}
end

function AF:GetRecipeOutputItemIDs(recipeID)
	local outputs = {}

	if C_TradeSkillUI.GetRecipeQualityItemIDs then
		local ok, qualityItemIDs = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
		if ok and type(qualityItemIDs) == "table" then
			for _, itemID in pairs(qualityItemIDs) do
				AddOutput(outputs, itemID)
			end
		end
	end

	if C_TradeSkillUI.GetRecipeItemLink then
		local ok, link = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
		if ok then
			AddOutput(outputs, self:GetItemIDFromLink(link))
		end
	end

	if C_TradeSkillUI.GetRecipeOutputItemData then
		for quality = 1, 5 do
			local ok, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, {}, nil, quality)
			if ok and type(outputInfo) == "table" then
				AddOutput(outputs, outputInfo.itemID)
				AddOutput(outputs, self:GetItemIDFromLink(outputInfo.hyperlink))
			end
		end
	end

	return outputs
end

GetOperationQuality = function(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	return operationInfo.craftingQuality or operationInfo.quality or operationInfo.guaranteedCraftingQualityID
end

GetRecipeDisplayQualityInfo = function(recipeID, operationInfo, reagentInfo)
	local quality = tonumber(GetOperationQuality(operationInfo))
	if not quality then
		return nil, nil
	end

	local recipeInfo = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
	local qualityItemID = recipeInfo and recipeInfo.qualityItemIDs and recipeInfo.qualityItemIDs[quality]
	local reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(qualityItemID)
	if reagentQuality then
		return reagentQuality, reagentQualityAtlas
	end

	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeQualityItemIDs then
		local okQualityItems, qualityItemIDs = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
		qualityItemID = okQualityItems and type(qualityItemIDs) == "table" and qualityItemIDs[quality] or nil
		reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(qualityItemID)
		if reagentQuality then
			return reagentQuality, reagentQualityAtlas
		end
	end

	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData and C_TradeSkillUI.GetItemReagentQualityInfo then
		local overrideQualityID = recipeInfo and recipeInfo.qualityIDs and recipeInfo.qualityIDs[quality] or quality
		local okOutput, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, reagentInfo or {}, nil, overrideQualityID)
		if okOutput and type(outputInfo) == "table" and outputInfo.itemID then
			reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(outputInfo.itemID)
			if reagentQuality then
				return reagentQuality, reagentQualityAtlas
			end
		end
	end

	local maxQuality = tonumber(recipeInfo and recipeInfo.maxQuality)
	local qualityCount = recipeInfo and recipeInfo.qualityIDs and #recipeInfo.qualityIDs or nil
	if maxQuality and qualityCount and qualityCount > 0 and qualityCount < maxQuality and quality <= qualityCount then
		return quality + (maxQuality - qualityCount), nil
	end

	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemQualityInfo then
		local ok, qualityInfo = pcall(C_TradeSkillUI.GetRecipeItemQualityInfo, recipeID, quality)
		if ok and qualityInfo then
			return GetQualityTierFromAtlas(qualityInfo.iconSmall)
				or GetQualityTierFromAtlas(qualityInfo.icon)
				or tonumber(qualityInfo.quality)
				or quality,
				qualityInfo.iconSmall or qualityInfo.icon
		end
	end
	return quality, nil
end

GetRecipeDisplayQuality = function(recipeID, operationInfo, reagentInfo)
	local quality = GetRecipeDisplayQualityInfo(recipeID, operationInfo, reagentInfo)
	return quality
end

function AF:GetProfessionLink()
	if not C_TradeSkillUI or not C_TradeSkillUI.GetTradeSkillListLink then
		return nil
	end
	local ok, link = pcall(C_TradeSkillUI.GetTradeSkillListLink)
	if ok and type(link) == "string" and link ~= "" then
		return link
	end
	return nil
end

function AF:GetRecipeCapability(recipeID)
	if not C_TradeSkillUI or not C_TradeSkillUI.GetCraftingOperationInfo then
		return {}
	end

	local capability = {}
	local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
	if ok and type(operationInfo) == "table" then
		capability.recipeDifficulty = operationInfo.baseDifficulty
		local totalSkill = (tonumber(operationInfo.baseSkill) or 0) + (tonumber(operationInfo.bonusSkill) or 0)
		if totalSkill > 0 then
			capability.totalSkill = totalSkill
		end
		capability.debugBaseOperation = FormatOperationDebug(operationInfo)
		capability.rawQuality = GetOperationQuality(operationInfo)
		capability.quality, capability.qualityAtlas = GetRecipeDisplayQualityInfo(recipeID, operationInfo, {})
	end

	local okConcentration, concentrationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, true)
	if okConcentration and type(concentrationInfo) == "table" then
		capability.rawConcentrationQuality = GetOperationQuality(concentrationInfo)
		capability.concentrationQuality, capability.concentrationQualityAtlas = GetRecipeDisplayQualityInfo(recipeID, concentrationInfo, {})
		capability.concentrationCost = concentrationInfo.concentrationCost
		capability.recipeDifficulty = capability.recipeDifficulty or concentrationInfo.baseDifficulty
		if not capability.totalSkill then
			capability.totalSkill = GetOperationTotalSkill(concentrationInfo)
		end
	end

	local best = self:GetBestReagentCapability(recipeID)
	local baselineQuality = tonumber(capability.quality) or 0
	local bestQuality = tonumber(best and best.bestQuality) or 0
	local baselineRawQuality = tonumber(capability.rawQuality) or 0
	local bestRawQuality = tonumber(best and best.rawBestQuality) or 0
	local baselineAtlas = tostring(capability.qualityAtlas or "")
	local bestAtlas = tostring(best and best.bestQualityAtlas or "")
	local hasAtlasUpgrade = baselineAtlas ~= "" and bestAtlas ~= "" and bestAtlas ~= baselineAtlas
	local hasQualityUpgrade = bestQuality > baselineQuality or bestRawQuality > baselineRawQuality or hasAtlasUpgrade
	if best then
		capability.debugBestCandidateQuality = best.bestQuality
		capability.debugBestCandidateAtlas = best.bestQualityAtlas
		capability.debugBestCandidateRawQuality = best.rawBestQuality
		capability.debugBestCandidateSummary = best.bestReagentSummary
		capability.debugBestCandidateAccepted = hasQualityUpgrade == true
		capability.debugBestCandidateOperation = best.debugOperation
		capability.debugBestCandidateReason = table.concat({
			tostring(best.debugReason or "ok"),
			"display " .. tostring(baselineQuality) .. "->" .. tostring(bestQuality),
			"raw " .. tostring(baselineRawQuality) .. "->" .. tostring(bestRawQuality),
			"atlas " .. tostring(hasAtlasUpgrade),
			"score " .. tostring(best.reagentQualityScore or "-"),
		}, "; ")
	else
		capability.debugBestCandidateReason = "no best candidate"
	end
	if best then
		capability.bestQuality = best.bestQuality
		capability.bestQualityAtlas = best.bestQualityAtlas
		capability.rawBestQuality = best.rawBestQuality
		capability.bestConcentrationQuality = best.bestConcentrationQuality
		capability.bestTotalSkill = best.bestTotalSkill
		capability.bestConcentrationCost = best.bestConcentrationCost
		capability.bestReagentSummary = best.bestReagentSummary
		capability.bestReagentTruncated = best.bestReagentTruncated
		capability.bestReagentPendingNames = best.debugReason == "waiting for reagent item names"
	end

	capability.professionLink = self:GetProfessionLink()
	return capability
end

function AF:GetProfessionRecipeSignature()
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
	if type(recipeIDs) ~= "table" then
		return nil
	end

	local learnedRecipeIDs = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
		if not recipeInfo or recipeInfo.learned ~= false then
			table.insert(learnedRecipeIDs, tonumber(recipeID) or 0)
		end
	end
	table.sort(learnedRecipeIDs, SortNumbers)
	return table.concat(learnedRecipeIDs, ",")
end

function AF:GetProfessionSpecSignature(professionID)
	if not professionID or not C_ProfSpecs or not C_Traits then
		return "nospec"
	end
	if C_ProfSpecs.SkillLineHasSpecialization and not C_ProfSpecs.SkillLineHasSpecialization(professionID) then
		return "nospec"
	end
	if not C_ProfSpecs.GetConfigIDForSkillLine or not C_ProfSpecs.GetSpecTabIDsForSkillLine or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then
		return "unknown"
	end

	local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionID)
	if not configID or configID == 0 then
		return "nospec"
	end

	local tabTreeIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(professionID)
	if type(tabTreeIDs) ~= "table" or #tabTreeIDs == 0 then
		return "nospec"
	end

	local parts = {}
	for _, treeID in ipairs(tabTreeIDs) do
		local nodeIDs = C_Traits.GetTreeNodes(treeID)
		if type(nodeIDs) == "table" then
			table.sort(nodeIDs, SortNumbers)
			for _, nodeID in ipairs(nodeIDs) do
				local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
				if nodeInfo then
					local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or 0
					table.insert(parts, table.concat({
						nodeID,
						tonumber(nodeInfo.currentRank) or 0,
						tonumber(nodeInfo.ranksPurchased) or 0,
						entryID,
					}, ":"))
				end
			end
		end
	end
	return #parts > 0 and table.concat(parts, ",") or "nospec"
end

function AF:GetCurrentProfessionScanSignature(profession)
	if not profession then
		return nil
	end

	local recipeSignature = self:GetProfessionRecipeSignature()
	if not recipeSignature then
		return nil
	end

	local specSignature = self:GetProfessionSpecSignature(profession.id)
	return table.concat({ SCAN_SIGNATURE_VERSION, recipeSignature, specSignature }, "|")
end

function AF:GetBestReagentCapability(recipeID)
	if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeSchematic or not C_TradeSkillUI.GetCraftingOperationInfo then
		return { debugReason = "missing profession simulation APIs" }
	end

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local okSchematic, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if not okSchematic or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return { debugReason = "recipe schematic unavailable" }
	end

	local candidateSlots = {}
	local fixedReagents = {}
	local skippedOptional = false
	local ignoredOptional = 0
	local visibleSlots = 0
	for _, reagentSlotSchematic in ipairs(schematic.reagentSlotSchematics) do
		if not reagentSlotSchematic.hiddenInCraftingForm and type(reagentSlotSchematic.reagents) == "table" and #reagentSlotSchematic.reagents > 0 then
			visibleSlots = visibleSlots + 1
			local reagentType = reagentSlotSchematic.reagentType
			local isBasic = Enum and Enum.CraftingReagentType and reagentType == Enum.CraftingReagentType.Basic
			local isRequired = reagentSlotSchematic.required == true
			if (isBasic or isRequired) and #reagentSlotSchematic.reagents > 1 then
				table.insert(candidateSlots, { slot = reagentSlotSchematic, optional = false })
			elseif isRequired then
				local bestReagent
				for _, reagent in ipairs(reagentSlotSchematic.reagents) do
					if IsLowerQualityReagent(reagent, bestReagent) then
						bestReagent = reagent
					end
				end
				if bestReagent then
					table.insert(fixedReagents, { slot = reagentSlotSchematic, reagent = bestReagent })
				end
			else
				ignoredOptional = ignoredOptional + 1
			end
		end
	end

	if #candidateSlots == 0 and #fixedReagents == 0 then
		return { debugReason = visibleSlots == 0 and "no visible reagent slots" or "no required or finite reagent candidates" }
	end

	local combinations = 1
	for _, candidate in ipairs(candidateSlots) do
		local optionCount = math.max(1, #candidate.slot.reagents)
		if candidate.optional then
			optionCount = optionCount + 1
		end
		combinations = combinations * optionCount
	end

	local useGreedy = combinations > MAX_REAGENT_COMBINATIONS
	local best
	local function Evaluate(selectedReagents, truncated)
		local allReagentInfo = {}
		local modifiedReagentInfo = {}
		local summary = {}
		local reagentQualityScore = 0
		local missingSummaryName = false
		for _, fixed in ipairs(fixedReagents) do
			AddReagentInfo(allReagentInfo, fixed.slot, fixed.reagent)
			if IsModifiedReagentSlot(fixed.slot) then
				AddReagentInfo(modifiedReagentInfo, fixed.slot, fixed.reagent)
			end
			local summaryEntry = BuildSummaryEntry(fixed.slot, fixed.reagent)
			if summaryEntry then
				table.insert(summary, summaryEntry)
			else
				missingSummaryName = true
			end
			reagentQualityScore = reagentQualityScore + ((GetReagentQuality(fixed.reagent) or 0) * (GetQuantityRequired(fixed.slot, fixed.reagent) or 1))
		end
		for slotIndex, candidate in ipairs(candidateSlots) do
			local slot = candidate.slot
			local reagent = selectedReagents[slotIndex]
			if reagent then
				AddReagentInfo(allReagentInfo, slot, reagent)
				if IsModifiedReagentSlot(slot) then
					AddReagentInfo(modifiedReagentInfo, slot, reagent)
				end
				local summaryEntry = BuildSummaryEntry(slot, reagent)
				if summaryEntry then
					table.insert(summary, summaryEntry)
				else
					missingSummaryName = true
				end
				reagentQualityScore = reagentQualityScore + ((GetReagentQuality(reagent) or 0) * (GetQuantityRequired(slot, reagent) or 1))
			end
		end

		local reagentVariants = {
			{ name = "modified", reagents = modifiedReagentInfo },
			{ name = "all", reagents = allReagentInfo },
			{ name = "empty", reagents = {} },
		}
		local normalInfo, normalVariant, normalDebug = TryCraftingOperationInfo(recipeID, reagentVariants, false)
		local concentrationInfo = nil
		if normalInfo then
			concentrationInfo = TryCraftingOperationInfo(recipeID, reagentVariants, true)
		end
		if type(normalInfo) == "table" and IsBetterOperation(normalInfo, concentrationInfo, reagentQualityScore, best) then
			best = {
				normalInfo = normalInfo,
				concentrationInfo = type(concentrationInfo) == "table" and concentrationInfo or nil,
				reagentInfo = normalVariant == "all" and allReagentInfo or modifiedReagentInfo,
				reagentQualityScore = reagentQualityScore,
				debugOperation = FormatOperationDebug(normalInfo) .. ", variant=" .. tostring(normalVariant) .. ", attempts=" .. tostring(normalDebug),
				summary = table.concat(summary, "; "),
				truncated = truncated or missingSummaryName,
				missingSummaryName = missingSummaryName,
			}
		end
	end

	if useGreedy then
		local selected = {}
		for slotIndex, candidate in ipairs(candidateSlots) do
			local slot = candidate.slot
			local bestReagent = candidate.optional and nil or slot.reagents[1]
			for _, reagent in ipairs(slot.reagents) do
				if IsLowerQualityReagent(reagent, bestReagent) then
					bestReagent = reagent
				end
			end
			selected[slotIndex] = bestReagent
		end
		Evaluate(selected, true)

		selected = {}
		for slotIndex, candidate in ipairs(candidateSlots) do
			local slot = candidate.slot
			local bestReagent = candidate.optional and nil or slot.reagents[1]
			for _, reagent in ipairs(slot.reagents) do
				if IsHigherQualityReagent(reagent, bestReagent) then
					bestReagent = reagent
				end
			end
			selected[slotIndex] = bestReagent
		end
		Evaluate(selected, true)
	else
		local selected = {}
		local function Visit(slotIndex)
			if slotIndex > #candidateSlots then
				Evaluate(selected, false)
				return
			end
			local candidate = candidateSlots[slotIndex]
			if candidate.optional then
				selected[slotIndex] = nil
				Visit(slotIndex + 1)
			end
			for _, reagent in ipairs(candidate.slot.reagents) do
				selected[slotIndex] = reagent
				Visit(slotIndex + 1)
			end
			selected[slotIndex] = nil
		end
		Visit(1)
	end

	if not best then
		return { debugReason = "all reagent simulations failed" }
	end

	local summary = best.summary or ""
	local summaryTruncated = best.truncated == true
	local trimmedSummary, lineTruncated = TrimSummaryByLine(summary, MAX_REAGENT_SUMMARY_BYTES)
	summary = trimmedSummary
	summaryTruncated = summaryTruncated or lineTruncated

	return {
		rawBestQuality = GetOperationQuality(best.normalInfo),
		bestQuality = GetRecipeDisplayQuality(recipeID, best.normalInfo, best.reagentInfo),
		bestQualityAtlas = select(2, GetRecipeDisplayQualityInfo(recipeID, best.normalInfo, best.reagentInfo)),
		bestConcentrationQuality = GetRecipeDisplayQuality(recipeID, best.concentrationInfo, best.reagentInfo),
		bestTotalSkill = GetOperationTotalSkill(best.normalInfo) or GetOperationTotalSkill(best.concentrationInfo),
		bestConcentrationCost = best.concentrationInfo and best.concentrationInfo.concentrationCost or nil,
		bestReagentSummary = summary,
		bestReagentTruncated = summaryTruncated,
		debugOperation = best.debugOperation,
		debugReason = table.concat({
			best.missingSummaryName and "waiting for reagent item names" or "ok",
			"ignored optional " .. tostring(ignoredOptional),
		}, "; "),
	}
end

function AF:ApplyRecipeCapability(item, recipeID)
	if not item or not recipeID then
		return
	end
	local capability = self:GetRecipeCapability(recipeID)
	item.recipeDifficulty = capability.recipeDifficulty
	item.totalSkill = capability.totalSkill
	item.quality = capability.quality
	item.qualityAtlas = capability.qualityAtlas
	item.rawQuality = capability.rawQuality
	item.concentrationQuality = capability.concentrationQuality
	item.concentrationQualityAtlas = capability.concentrationQualityAtlas
	item.rawConcentrationQuality = capability.rawConcentrationQuality
	item.concentrationCost = capability.concentrationCost
	item.bestQuality = capability.bestQuality
	item.bestQualityAtlas = capability.bestQualityAtlas
	item.rawBestQuality = capability.rawBestQuality
	item.bestConcentrationQuality = capability.bestConcentrationQuality
	item.bestTotalSkill = capability.bestTotalSkill
	item.bestConcentrationCost = capability.bestConcentrationCost
	item.bestReagentSummary = capability.bestReagentSummary
	item.bestReagentTruncated = capability.bestReagentTruncated == true
	item.bestReagentPendingNames = capability.bestReagentPendingNames == true
	item.debugBestCandidateQuality = capability.debugBestCandidateQuality
	item.debugBestCandidateAtlas = capability.debugBestCandidateAtlas
	item.debugBestCandidateRawQuality = capability.debugBestCandidateRawQuality
	item.debugBestCandidateSummary = capability.debugBestCandidateSummary
	item.debugBestCandidateAccepted = capability.debugBestCandidateAccepted == true
	item.debugBestCandidateOperation = capability.debugBestCandidateOperation
	item.debugBaseOperation = capability.debugBaseOperation
	item.debugBestCandidateReason = capability.debugBestCandidateReason
	item.professionLink = capability.professionLink or item.professionLink
end

local function GetScanJobKey(recipeID, itemID)
	return tostring(recipeID or 0) .. ":" .. tostring(itemID or 0)
end

function AF:PrepareProfessionForScan(profession)
	local profile = self.db.artisanProfile
	local professionKey = tostring(profession.id)
	profile.professions[professionKey] = profile.professions[professionKey] or {
		id = profession.id,
		name = profession.name,
		recipes = {},
		updatedAt = self:Now(),
	}
	local professionEntry = profile.professions[professionKey]
	professionEntry.id = profession.id
	professionEntry.name = profession.name
	professionEntry.updatedAt = self:Now()
	professionEntry.professionLink = self:GetProfessionLink()
	professionEntry.recipes = professionEntry.recipes or {}
	return professionEntry
end

function AF:BuildScanProgress(profession, professionEntry, signature, force)
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
	if type(recipeIDs) ~= "table" then
		return nil, self:Text("SCAN_NO_RECIPES")
	end

	local previous = professionEntry.scanProgress
	local completed = {}
	if not force and previous and previous.signature == signature and type(previous.completed) == "table" then
		completed = previous.completed
	end

	local pending = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
		local learned = not recipeInfo or recipeInfo.learned ~= false
		if learned then
			local outputs = self:GetRecipeOutputItemIDs(recipeID)
			for itemID in pairs(outputs) do
				local key = GetScanJobKey(recipeID, itemID)
				if force or not completed[key] then
					table.insert(pending, {
						key = key,
						recipeID = recipeID,
						itemID = itemID,
						recipeName = recipeInfo and recipeInfo.name,
					})
				end
			end
		end
	end

	professionEntry.scanProgress = {
		signature = signature,
		pending = pending,
		completed = completed,
		total = #pending + self:TableCount(completed),
		scanned = self:TableCount(completed),
		startedAt = previous and previous.startedAt or self:Now(),
		updatedAt = self:Now(),
	}
	return professionEntry.scanProgress
end

function AF:ScanJob(profession, professionEntry, job)
	local profile = self.db.artisanProfile
	local itemKey = tostring(job.itemID)
	local existing = profile.items[itemKey] or {}
	profile.items[itemKey] = existing
	existing.itemID = job.itemID
	existing.recipeID = job.recipeID
	existing.recipeName = job.recipeName or existing.recipeName or self:Text("RECIPE_FALLBACK", tostring(job.recipeID))
	existing.itemName = self:GetDisplayItemName(job.itemID, existing.itemName)
	existing.professionID = profession.id
	existing.professionName = profession.name
	self:ApplyRecipeCapability(existing, job.recipeID)
	existing.updatedAt = self:Now()
	professionEntry.recipes[tostring(job.recipeID)] = true
end

function AF:IsCurrentProfessionScanAvailable(professionID)
	if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady or not C_TradeSkillUI.IsTradeSkillReady() then
		return false
	end
	if self:IsLinkedProfessionOpen() then
		return false
	end
	local current = self:GetCurrentProfessionInfo()
	return current and tonumber(current.id) == tonumber(professionID)
end

function AF:ProcessScanQueue()
	if self.scanProcessing then
		return
	end
	self.scanProcessing = true
	C_Timer.After(0.03, function()
		AF.scanProcessing = false

		local active = AF.activeScan
		if not active or not active.professionID then
			return
		end
		if not AF:IsCurrentProfessionScanAvailable(active.professionID) then
			AF.activeScan = nil
			return
		end

		local profile = AF.db and AF.db.artisanProfile
		local professionEntry = profile and profile.professions and profile.professions[tostring(active.professionID)]
		local progress = professionEntry and professionEntry.scanProgress
		if not progress or progress.signature ~= active.signature then
			AF.activeScan = nil
			return
		end

		local job = table.remove(progress.pending, 1)
		if job then
			local profession = { id = active.professionID, name = professionEntry.name }
			AF:ScanJob(profession, professionEntry, job)
			progress.completed[job.key] = true
			progress.scanned = (tonumber(progress.scanned) or 0) + 1
			progress.updatedAt = AF:Now()
			AF.scanRefreshCounter = (AF.scanRefreshCounter or 0) + 1
			if AF.scanRefreshCounter >= 8 then
				AF.scanRefreshCounter = 0
				if AF.RefreshCrafterUI then
					AF:RefreshCrafterUI()
				end
				if AF.RefreshMinimap then
					AF:RefreshMinimap()
				end
			end
		end

		if #progress.pending == 0 then
			professionEntry.scanSignature = progress.signature
			professionEntry.scannedAt = AF:Now()
			professionEntry.scanProgress = nil
			AF.activeScan = nil
			AF.lastCompletedScan = {
				professionID = active.professionID,
				signature = progress.signature,
				completedAt = AF:Now(),
			}
			if AF.RefreshCrafterUI then
				AF:RefreshCrafterUI()
			end
			if AF.RefreshMinimap then
				AF:RefreshMinimap()
			end
			AF:Print(AF:Text("SCAN_COMPLETE", tonumber(progress.scanned) or 0, professionEntry.name))
		else
			AF:ProcessScanQueue()
		end
	end)
end

function AF:PauseActiveProfessionScan()
	local active = self.activeScan
	if not active or not active.professionID then
		return
	end

	local professionEntry = self.db
		and self.db.artisanProfile
		and self.db.artisanProfile.professions
		and self.db.artisanProfile.professions[tostring(active.professionID)]
	if professionEntry and professionEntry.scanSignature == active.signature then
		professionEntry.scanProgress = nil
		self.activeScan = nil
		return
	end
	local progress = professionEntry and professionEntry.scanProgress
	local remaining = progress and progress.pending and #progress.pending or 0
	self.activeScan = nil

	if remaining > 0 then
		self:Print(self:Text("SCAN_PAUSED", professionEntry.name or self:Text("PROFESSION_FALLBACK", tostring(active.professionID)), remaining))
	end
end

function AF:StartOrResumeCurrentProfessionScan(force, silent)
	if self:IsLinkedProfessionOpen() then
		self.activeScan = nil
		return 0
	end

	if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady or not C_TradeSkillUI.IsTradeSkillReady() then
		if not silent then
			self:Print(self:Text("SCAN_OPEN_PROFESSION"))
		end
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		if not silent then
			self:Print(self:Text("SCAN_NO_PROFESSION"))
		end
		return 0
	end

	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		return 0
	end

	if self.activeScan and tonumber(self.activeScan.professionID) == tonumber(profession.id) and self.activeScan.signature == currentSignature then
		return 0
	end

	local professionEntry = self:PrepareProfessionForScan(profession)
	if professionEntry.scanSignature == currentSignature and professionEntry.scanProgress then
		local remaining = professionEntry.scanProgress.pending and #professionEntry.scanProgress.pending or 0
		if remaining == 0 then
			professionEntry.scanProgress = nil
		end
	end
	if not force and professionEntry.scanSignature == currentSignature and not professionEntry.scanProgress then
		return 0
	end

	local progress
	if not force and professionEntry.scanProgress and professionEntry.scanProgress.signature == currentSignature then
		progress = professionEntry.scanProgress
	else
		progress = self:BuildScanProgress(profession, professionEntry, currentSignature, force)
	end
	if not progress then
		if not silent then
			self:Print(self:Text("SCAN_NO_RECIPES"))
		end
		return 0
	end
	if #progress.pending == 0 then
		professionEntry.scanSignature = currentSignature
		professionEntry.scannedAt = self:Now()
		professionEntry.scanProgress = nil
		return 0
	end

	self.activeScan = {
		professionID = profession.id,
		signature = currentSignature,
	}
	professionEntry.scanSignature = nil
	self:Print(self:Text(progress.scanned and progress.scanned > 0 and "SCAN_RESUMED" or "SCAN_STARTED", profession.name))
	self:ProcessScanQueue()
	return #progress.pending
end

function AF:ScanCurrentProfession(silent)
	return self:StartOrResumeCurrentProfessionScan(true, silent)
end

function AF:AutoScanCurrentProfession(force)
	return self:StartOrResumeCurrentProfessionScan(force == true, true)
end

function AF:IsKnowledgeApplyPending(professionID)
	if not professionID or not C_ProfSpecs or not C_Traits or not C_ProfSpecs.GetConfigIDForSkillLine or not C_Traits.ConfigHasStagedChanges then
		return false
	end
	local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionID)
	return configID and configID ~= 0 and C_Traits.ConfigHasStagedChanges(configID) == true
end

function AF:QueueAutoScan(force)
	return self:QueueAutoScanForChange(force and "FORCE" or "AUTO")
end

function AF:QueueAutoScanForChange(reason)
	if self:IsLinkedProfessionOpen() then
		self.pendingAutoScanReason = nil
		return
	end

	if self.autoScanQueued then
		self.pendingAutoScanReason = reason or self.pendingAutoScanReason
		return
	end

	self.autoScanQueued = true
	self.pendingAutoScanReason = reason or self.pendingAutoScanReason
	C_Timer.After(1.0, function()
		AF.autoScanQueued = false
		if AF:IsLinkedProfessionOpen() then
			AF.pendingAutoScanReason = nil
			return
		end
		local profession = AF:GetCurrentProfessionInfo()
		if not profession then
			return
		end
		if AF:IsKnowledgeApplyPending(profession.id) then
			if not AF.knowledgeScanWaitPrinted then
				AF.knowledgeScanWaitPrinted = true
				AF:Print(AF:Text("SCAN_WAITING_KNOWLEDGE", profession.name))
			end
			AF:QueueAutoScanForChange(AF.pendingAutoScanReason or "TRAIT_PENDING")
			return
		end
		AF.knowledgeScanWaitPrinted = false
		local reason = AF.pendingAutoScanReason
		AF.pendingAutoScanReason = nil
		local force = reason == "FORCE"
		AF:StartOrResumeCurrentProfessionScan(force, true)
	end)
end

function AF:ResumeCurrentProfessionScanIfNeeded()
	if self:IsLinkedProfessionOpen() then
		self.activeScan = nil
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		return 0
	end
	local professionEntry = self.db and self.db.artisanProfile and self.db.artisanProfile.professions[tostring(profession.id)]
	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		return 0
	end
	if professionEntry and professionEntry.scanSignature == currentSignature then
		professionEntry.scanProgress = nil
		return 0
	end
	if not professionEntry or professionEntry.scanSignature ~= currentSignature or professionEntry.scanProgress then
		return self:StartOrResumeCurrentProfessionScan(false, true)
	end
	return 0
end
