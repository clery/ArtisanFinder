local _, AF = ...

local MAX_OPTIONAL_REAGENT_COMBINATIONS = 96
local HEAVY_JOB_QUALITY_TIER_THRESHOLD = AF.HEAVY_JOB_QUALITY_TIER_THRESHOLD
local SCAN_SIGNATURE_VERSION = 36
local SKILL_PROBE_SIGNATURE_VERSION = 1
local FULL_SCAN_SIGNATURE_VERSION = 4
local GetOperationQuality
local GetRecipeDisplayQuality
local GetRecipeDisplayQualityInfo
local GetRecipeCapabilityTimeMS

local SortNumbers = AF.SortNumbers
local CopyTable = AF.CopyTable

GetRecipeCapabilityTimeMS = function()
	if debugprofilestop then
		return debugprofilestop()
	end
	return GetTime() * 1000
end

local skillFactsYieldState

local function YieldSkillFactsBuildIfNeeded()
	if not skillFactsYieldState then
		return
	end
	if GetRecipeCapabilityTimeMS() - skillFactsYieldState.startedMS >= skillFactsYieldState.budgetMS then
		coroutine.yield()
		skillFactsYieldState.startedMS = GetRecipeCapabilityTimeMS()
	end
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

local function GetQualityTierFromAtlas(atlas)
	return tonumber(tostring(atlas or ""):match("[Tt]ier(%d+)"))
end

local function GetReagentQuality(reagent)
	if not reagent or not reagent.itemID then
		return 0
	end
	if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
		local okQuality, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, reagent.itemID)
		if okQuality and not AF:IsSecretValue(quality) then
			local numericQuality = tonumber(quality)
			if numericQuality then
				return numericQuality
			end
		end
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, reagent.itemID)
	if ok and qualityInfo then
		return tonumber(qualityInfo.quality)
			or GetQualityTierFromAtlas(qualityInfo.iconInventory)
			or GetQualityTierFromAtlas(qualityInfo.iconSmall)
			or GetQualityTierFromAtlas(qualityInfo.icon)
			or GetQualityTierFromAtlas(qualityInfo.iconChat)
			or 0
	end
	return 0
end

local function GetReagentQualityInfoFromItemID(itemID)
	if not itemID then
		return nil
	end
	if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
		local okQuality, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
		if okQuality and not AF:IsSecretValue(quality) then
			local numericQuality = tonumber(quality)
			if numericQuality then
				return numericQuality
			end
		end
	end
	local ok, reagentQualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
	if ok and reagentQualityInfo then
		return tonumber(reagentQualityInfo.quality)
			or GetQualityTierFromAtlas(reagentQualityInfo.iconInventory)
			or GetQualityTierFromAtlas(reagentQualityInfo.iconSmall)
			or GetQualityTierFromAtlas(reagentQualityInfo.icon)
			or GetQualityTierFromAtlas(reagentQualityInfo.iconChat)
	end
	return nil
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

local function GetOperationTotalSkill(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	local totalSkill = (tonumber(operationInfo.baseSkill) or 0) + (tonumber(operationInfo.bonusSkill) or 0)
	return totalSkill > 0 and totalSkill or nil
end

local function GetOperationUpperThreshold(operationInfo)
	return operationInfo and (operationInfo.upperSkillTreshold or operationInfo.upperSkillThreshold) or nil
end

local function GetOperationDifficulty(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	local difficulty = (tonumber(operationInfo.baseDifficulty) or 0) + (tonumber(operationInfo.bonusDifficulty) or 0)
	return difficulty > 0 and difficulty or nil
end

local function ApplyOperationInfo(target, recipeID, operationInfo)
	target.recipeDifficulty = operationInfo.baseDifficulty
	target.baseSkill = operationInfo.baseSkill
	target.bonusSkill = operationInfo.bonusSkill
	target.bonusDifficulty = operationInfo.bonusDifficulty
	target.lowerSkillThreshold = operationInfo.lowerSkillThreshold
	target.upperSkillThreshold = GetOperationUpperThreshold(operationInfo)
	target.totalSkill = GetOperationTotalSkill(operationInfo)
	target.rawQuality = GetOperationQuality(operationInfo)
	target.quality = GetRecipeDisplayQualityInfo(recipeID, operationInfo, {})
end

local RECIPE_INFO_CACHE = {}

local function WipeTable(tbl)
	if not tbl then
		return
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function GetCachedRecipeInfo(recipeID)
	local recipeInfo = RECIPE_INFO_CACHE[recipeID]
	if not recipeInfo then
		recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
		RECIPE_INFO_CACHE[recipeID] = recipeInfo
	end
	return recipeInfo
end

local function GetRecipeOutputItemLevel(recipeID, operationInfo, reagentInfo)
	local recipeInfo = GetCachedRecipeInfo(recipeID)
	local quality = tonumber(GetOperationQuality(operationInfo))
	local recipeItemLevel = tonumber(recipeInfo and recipeInfo.itemLevel)
	if recipeItemLevel and quality and type(recipeInfo.qualityIlvlBonuses) == "table" and recipeInfo.qualityIlvlBonuses[quality] ~= nil then
		return recipeItemLevel + (tonumber(recipeInfo.qualityIlvlBonuses[quality]) or 0)
	end
	local overrideQualityID = quality and recipeInfo and recipeInfo.qualityIDs and recipeInfo.qualityIDs[quality] or quality
	local okOutput, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, reagentInfo or {}, nil, overrideQualityID)
	if okOutput and type(outputInfo) == "table" and outputInfo.hyperlink then
		local okLevel, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, outputInfo.hyperlink)
		if okLevel and tonumber(itemLevel) then
			return tonumber(itemLevel)
		end
	end
	if recipeItemLevel and quality and type(recipeInfo.qualityIlvlBonuses) == "table" then
		return recipeItemLevel + (tonumber(recipeInfo.qualityIlvlBonuses[quality]) or 0)
	end
	return recipeItemLevel
end

local function ScoreOperationPair(normalInfo, concentrationInfo, outputItemLevel)
	local normalQuality = GetOperationQuality(normalInfo) or 0
	local concentrationQuality = GetOperationQuality(concentrationInfo) or 0
	local totalSkill = GetOperationTotalSkill(normalInfo) or GetOperationTotalSkill(concentrationInfo) or 0
	local concentrationCost = tonumber(concentrationInfo and concentrationInfo.concentrationCost) or 999999
	return tonumber(outputItemLevel) or 0, normalQuality, concentrationQuality, totalSkill, -concentrationCost
end

local function IsBetterOperation(normalInfo, concentrationInfo, reagentQualityScore, best, normalOnly, outputItemLevel)
	local itemLevel, quality, concentrationQuality, totalSkill, inverseCost = ScoreOperationPair(normalInfo, concentrationInfo, outputItemLevel)
	if not best then
		return true
	end
	local bestItemLevel, bestQuality, bestConcentrationQuality, bestSkill, bestInverseCost = ScoreOperationPair(best.normalInfo, best.concentrationInfo, best.outputItemLevel)
	if itemLevel ~= bestItemLevel then
		return itemLevel > bestItemLevel
	end
	if quality ~= bestQuality then
		return quality > bestQuality
	end
	if not normalOnly and concentrationQuality ~= bestConcentrationQuality then
		return concentrationQuality > bestConcentrationQuality
	end
	if reagentQualityScore ~= (best.reagentQualityScore or 0) then
		return reagentQualityScore < (best.reagentQualityScore or 0)
	end
	if not normalOnly and inverseCost ~= bestInverseCost then
		return inverseCost > bestInverseCost
	end
	return totalSkill > bestSkill
end

local function IsOperationBelowBest(normalInfo, concentrationInfo, best, normalOnly, outputItemLevel)
	if not best then
		return false
	end
	local itemLevel, quality, concentrationQuality = ScoreOperationPair(normalInfo, concentrationInfo, outputItemLevel)
	local bestItemLevel, bestQuality, bestConcentrationQuality = ScoreOperationPair(best.normalInfo, best.concentrationInfo, best.outputItemLevel)
	if itemLevel ~= bestItemLevel then
		return itemLevel < bestItemLevel
	end
	if quality ~= bestQuality then
		return quality < bestQuality
	end
	if not normalOnly and concentrationQuality ~= bestConcentrationQuality then
		return concentrationQuality < bestConcentrationQuality
	end
	return false
end

local function BuildBestReagentCapability(recipeID, best)
	if not best or not best.normalInfo then
		return best or {}
	end
	if best.bestQuality or best.rawBestQuality or best.bestReagentTruncated ~= nil then
		best.debugScanStats = CopyTable(best.debugScanStats)
		return best
	end
	return {
		normalInfo = best.normalInfo,
		concentrationInfo = best.concentrationInfo,
		reagentInfo = best.reagentInfo,
		rawBestQuality = GetOperationQuality(best.normalInfo),
		bestQuality = GetRecipeDisplayQuality(recipeID, best.normalInfo, best.reagentInfo),
		bestConcentrationQuality = GetRecipeDisplayQuality(recipeID, best.concentrationInfo, best.reagentInfo),
		bestTotalSkill = GetOperationTotalSkill(best.normalInfo) or GetOperationTotalSkill(best.concentrationInfo),
		bestConcentrationCost = best.concentrationInfo and best.concentrationInfo.concentrationCost or nil,
		bestOutputItemLevel = best.outputItemLevel,
		bestReagents = best.bestReagents,
		bestReagentSignature = best.bestReagentSignature,
		bestReagentTruncated = best.truncated == true,
		reagentQualityScore = best.reagentQualityScore,
		debugScanStats = CopyTable(best.debugScanStats),
		optionalImpact = best.optionalImpact,
	}
end

local function CreateRecipeScanStats()
	return {
		evaluated = 0,
		normalCalls = 0,
		concentrationCalls = 0,
		outputItemLevelCalls = 0,
		skippedByQuality = 0,
		skippedConcentration = 0,
		prunedBelowBest = 0,
		noNormalInfo = 0,
		qualityTierCombinations = 1,
		endpointShortcut = false,
		endpointShortcutSaved = 0,
		skippedMaxQualityConcentration = 0,
	}
end

local function SelectEndpointReagents(candidateSlots, highest)
	local selected = {}
	for slotIndex, candidate in ipairs(candidateSlots or {}) do
		local selectedReagent
		for _, reagent in ipairs(candidate.slot.reagents) do
			if highest then
				if IsHigherQualityReagent(reagent, selectedReagent) then
					selectedReagent = reagent
				end
			elseif IsLowerQualityReagent(reagent, selectedReagent) then
				selectedReagent = reagent
			end
		end
		selected[slotIndex] = selectedReagent
	end
	return selected
end

local function HasSamePrimaryOutcome(left, right, normalOnly)
	if not left or not right then
		return false
	end
	local leftItemLevel, leftQuality, leftConcentrationQuality = ScoreOperationPair(left.normalInfo, left.concentrationInfo, left.outputItemLevel)
	local rightItemLevel, rightQuality, rightConcentrationQuality = ScoreOperationPair(right.normalInfo, right.concentrationInfo, right.outputItemLevel)
	if leftItemLevel ~= rightItemLevel or leftQuality ~= rightQuality then
		return false
	end
	return normalOnly or leftConcentrationQuality == rightConcentrationQuality
end

local function AddReagentInfo(tbl, reagentSlotSchematic, reagent)
	local quantity = GetQuantityRequired(reagentSlotSchematic, reagent)
	table.insert(tbl, {
		reagent = reagent,
		dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
		quantity = quantity,
	})
end

local function IsSameReagent(left, right)
	if not left or not right then
		return false
	end
	if left.itemID and right.itemID then
		return tonumber(left.itemID) == tonumber(right.itemID)
	end
	if left.currencyID and right.currencyID then
		return tonumber(left.currencyID) == tonumber(right.currencyID)
	end
	return false
end

local function IsQualityReagentSlot(reagentSlotSchematic)
	for _, reagent in ipairs(reagentSlotSchematic and reagentSlotSchematic.reagents or {}) do
		if (GetReagentQuality(reagent) or 0) > 0 then
			return true
		end
	end
	return false
end

local function AddReagentInfoForOperation(tbl, reagentSlotSchematic, selectedReagent)
	if not reagentSlotSchematic or not selectedReagent then
		return
	end
	if IsQualityReagentSlot(reagentSlotSchematic) then
		for _, reagent in ipairs(reagentSlotSchematic.reagents or {}) do
			if (GetReagentQuality(reagent) or 0) > 0 then
				table.insert(tbl, {
					reagent = reagent,
					dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
					quantity = IsSameReagent(reagent, selectedReagent) and GetQuantityRequired(reagentSlotSchematic, selectedReagent) or 0,
				})
			end
		end
	end
end

local function IsModifiedReagentSlot(reagentSlotSchematic)
	return not Enum
		or not Enum.TradeskillSlotDataType
		or reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent
end

local function IsOptionalDifficultySlot(reagentSlotSchematic)
	if reagentSlotSchematic.required or reagentSlotSchematic.hiddenInCraftingForm then
		return false
	end
	if type(reagentSlotSchematic.reagents) ~= "table" or #reagentSlotSchematic.reagents == 0 then
		return false
	end
	if Enum and Enum.CraftingReagentType and reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Finishing then
		return false
	end
	return IsModifiedReagentSlot(reagentSlotSchematic)
		or not Enum
		or not Enum.CraftingReagentType
		or reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Modifying
end

local function GetCustomerOptionalSlotText(reagentSlotSchematic)
	if not IsOptionalDifficultySlot(reagentSlotSchematic) then
		return nil
	end
	local slotInfo = reagentSlotSchematic.slotInfo
	local slotText = slotInfo and slotInfo.slotText
	return slotText and slotText ~= "" and slotText or nil
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

local function GetReagentDifficultyAdjustment(reagentSlotSchematic, reagent)
	return tonumber(reagent.difficultyAdjustment)
		or tonumber(reagentSlotSchematic.difficultyAdjustment)
		or tonumber(reagent.bonusDifficulty)
		or tonumber(reagentSlotSchematic.bonusDifficulty)
end

local function BuildReagentEntry(reagentSlotSchematic, reagent)
	local quantity = GetQuantityRequired(reagentSlotSchematic, reagent)
	local slotText = GetCustomerOptionalSlotText(reagentSlotSchematic)
	local difficultyAdjustment = GetReagentDifficultyAdjustment(reagentSlotSchematic, reagent)
	if reagent.itemID and reagent.itemID ~= 0 then
		local quality = GetReagentQualityInfoFromItemID(reagent.itemID)
		return {
			kind = "item",
			itemID = reagent.itemID,
			quantity = quantity,
			quality = quality or GetReagentQuality(reagent),
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
			slotText = slotText,
			difficultyAdjustment = difficultyAdjustment,
		}
	end
	if reagent.currencyID and reagent.currencyID ~= 0 then
		return {
			kind = "currency",
			currencyID = reagent.currencyID,
			quantity = quantity,
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
			slotText = slotText,
			difficultyAdjustment = difficultyAdjustment,
		}
	end
	return nil
end

local function AddRecommendedReagentEntry(reagents, reagentSlotSchematic, reagent)
	local reagentType = reagentSlotSchematic.reagentType
	local isBasic = Enum and Enum.CraftingReagentType and reagentType == Enum.CraftingReagentType.Basic
	local difficultyAdjustment = GetReagentDifficultyAdjustment(reagentSlotSchematic, reagent)
	if (reagentSlotSchematic.required == true or isBasic) and (GetReagentQuality(reagent) or 0) <= 0 and (tonumber(difficultyAdjustment) or 0) <= 0 then
		return
	end
	local reagentEntry = BuildReagentEntry(reagentSlotSchematic, reagent)
	if reagentEntry then
		table.insert(reagents, reagentEntry)
	end
end

local function BuildReagentSignature(reagents)
	local parts = {}
	for _, reagent in ipairs(reagents or {}) do
		local kind = reagent.kind == "currency" and "c" or "i"
		table.insert(parts, table.concat({
			kind,
			tostring(reagent.itemID or reagent.currencyID or 0),
			tostring(reagent.quantity or 1),
			tostring(reagent.quality or 0),
			tostring(reagent.dataSlotIndex or 0),
		}, ":"))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function AF:GetCurrentProfessionInfo()
	local info = C_TradeSkillUI.GetChildProfessionInfo()
	if not info then
		return nil
	end
	local childProfessionID = C_TradeSkillUI.GetProfessionChildSkillLineID() or info.professionID
	local parentProfessionID = info.parentProfessionID
	local professionID = parentProfessionID or childProfessionID
	if not professionID then
		return nil
	end
	return {
		id = professionID,
		name = info.parentProfessionName or info.professionName or self:Text("PROFESSION_FALLBACK", tostring(professionID)),
		parentProfessionID = parentProfessionID,
		skillLineID = childProfessionID,
		childProfessionID = childProfessionID,
	}
end

function AF:GetRecipeOutputItemIDs(recipeID)
	local outputs = {}

	local okQualityItems, qualityItemIDs = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
	if okQualityItems and type(qualityItemIDs) == "table" then
		for _, itemID in pairs(qualityItemIDs) do
			AddOutput(outputs, itemID)
		end
	end

	local okLink, link = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
	if okLink then
		AddOutput(outputs, self:GetItemIDFromLink(link))
	end

	for quality = 1, 5 do
		local ok, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, {}, nil, quality)
		if ok and type(outputInfo) == "table" then
			AddOutput(outputs, outputInfo.itemID)
			AddOutput(outputs, self:GetItemIDFromLink(outputInfo.hyperlink))
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

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local maxQuality = tonumber(recipeInfo and recipeInfo.maxQuality)
	local qualityCount = recipeInfo and recipeInfo.qualityIDs and #recipeInfo.qualityIDs or nil
	if maxQuality and qualityCount and qualityCount > 0 and qualityCount < maxQuality and quality <= qualityCount then
		quality = quality + (maxQuality - qualityCount)
	end

	local ok, qualityInfo = pcall(C_TradeSkillUI.GetRecipeItemQualityInfo, recipeID, quality)
	if ok and qualityInfo then
		return GetQualityTierFromAtlas(qualityInfo.iconSmall)
			or GetQualityTierFromAtlas(qualityInfo.icon)
			or tonumber(qualityInfo.quality)
			or quality
	end

	local qualityItemID = recipeInfo and recipeInfo.qualityItemIDs and recipeInfo.qualityItemIDs[quality]
	local reagentQuality = GetReagentQualityInfoFromItemID(qualityItemID)
	if reagentQuality then
		return reagentQuality
	end

	local okQualityItems, qualityItemIDs = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
	qualityItemID = okQualityItems and type(qualityItemIDs) == "table" and qualityItemIDs[quality] or nil
	reagentQuality = GetReagentQualityInfoFromItemID(qualityItemID)
	if reagentQuality then
		return reagentQuality
	end

	local overrideQualityID = recipeInfo and recipeInfo.qualityIDs and recipeInfo.qualityIDs[quality] or quality
	local okOutput, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, reagentInfo or {}, nil, overrideQualityID)
	if okOutput and type(outputInfo) == "table" and outputInfo.itemID then
		reagentQuality = GetReagentQualityInfoFromItemID(outputInfo.itemID)
		if reagentQuality then
			return reagentQuality
		end
	end

	return quality
end

GetRecipeDisplayQuality = function(recipeID, operationInfo, reagentInfo)
	local quality = GetRecipeDisplayQualityInfo(recipeID, operationInfo, reagentInfo)
	return quality
end

function AF:GetProfessionLink()
	local okCanLink, canLink = pcall(C_TradeSkillUI.CanTradeSkillListLink)
	if not okCanLink then
		return nil, "CanTradeSkillListLink error: " .. tostring(canLink)
	end
	if self:IsSecretValue(canLink) then
		return nil, "CanTradeSkillListLink returned secret value"
	end
	if okCanLink and canLink == false then
		return nil, "CanTradeSkillListLink returned false"
	end
	local ok, link = pcall(C_TradeSkillUI.GetTradeSkillListLink)
	if ok and not self:IsSecretValue(link) and type(link) == "string" and link ~= "" then
		return link
	end
	return nil, ok and "GetTradeSkillListLink returned no link" or ("GetTradeSkillListLink error: " .. tostring(link))
end

function AF:CaptureCurrentProfessionLink(profession, reason)
	if not self:IsOwnProfessionWindowOpen() then
		return nil
	end

	profession = profession or self:GetCurrentProfessionInfo()
	local professionID = profession and profession.id
	if not professionID then
		return nil
	end

	local link = self:GetProfessionLink()
	if not link then
		return nil
	end

	local characterName = self:NormalizeName(self.activeArtisanCharacter or self.playerName or self:GetPlayerFullName())
	return self:StoreProfessionLink(characterName, professionID, link)
end

local function GetSlotKey(reagentSlotSchematic, fallbackIndex)
	return tostring(reagentSlotSchematic.slotIndex or reagentSlotSchematic.dataSlotIndex or fallbackIndex or "slot")
end

local function GetReagentSlotText(reagentSlotSchematic)
	local slotInfo = reagentSlotSchematic and reagentSlotSchematic.slotInfo
	local slotText = slotInfo and slotInfo.slotText
	return slotText and slotText ~= "" and slotText or nil
end

local function GetReagentIcon(reagent)
	local itemID = tonumber(reagent and reagent.itemID)
	if itemID and C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
		if ok then
			return icon
		end
	end
	return nil
end

local function GetReagentLink(reagent)
	local itemID = tonumber(reagent and reagent.itemID)
	if itemID and C_Item and C_Item.GetItemInfo then
		local ok, _, link = pcall(C_Item.GetItemInfo, itemID)
		if ok and type(link) == "string" then
			return link
		end
	end
	return nil
end

local function AddCraftingReagentInfo(reagentInfo, reagentSlotSchematic, reagent)
	if not reagent then
		return
	end
	AddReagentInfoForOperation(reagentInfo, reagentSlotSchematic, reagent)
end

local function GetOperationInfoForReagentInfo(recipeID, reagentInfo)
	local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, reagentInfo or {}, nil, false)
	return ok and type(operationInfo) == "table" and operationInfo or nil
end

local function SelectLowestQualityReagent(reagentSlotSchematic)
	local selected
	for _, reagent in ipairs(reagentSlotSchematic and reagentSlotSchematic.reagents or {}) do
		if IsLowerQualityReagent(reagent, selected) then
			selected = reagent
		end
	end
	return selected
end

local function SelectRepresentativeQualityReagent(reagentSlotSchematic, quality)
	local selected
	for _, reagent in ipairs(reagentSlotSchematic and reagentSlotSchematic.reagents or {}) do
		if (GetReagentQuality(reagent) or 0) == quality then
			if not selected or (tonumber(reagent.itemID) or 0) < (tonumber(selected.itemID) or 0) then
				selected = reagent
			end
		end
	end
	return selected
end

local function GetRequiredQualityList(reagentSlotSchematic)
	local qualities = {}
	local seen = {}
	for _, reagent in ipairs(reagentSlotSchematic and reagentSlotSchematic.reagents or {}) do
		local quality = GetReagentQuality(reagent) or 0
		if quality > 0 and not seen[quality] then
			seen[quality] = true
			qualities[#qualities + 1] = quality
		end
	end
	table.sort(qualities)
	return qualities
end

local function BuildStoredReagent(reagentSlotSchematic, reagent, slotIndex, optional)
	local entry = BuildReagentEntry(reagentSlotSchematic, reagent)
	if not entry then
		return nil
	end
	entry.slotIndex = reagentSlotSchematic.slotIndex or slotIndex
	entry.slotKey = GetSlotKey(reagentSlotSchematic, slotIndex)
	entry.icon = GetReagentIcon(reagent)
	entry.link = GetReagentLink(reagent)
	entry.optional = optional == true or nil
	return entry
end

local function BuildBaselineRequiredReagents(requiredSlots)
	local reagentInfo = {}
	local baselineBySlot = {}
	for slotIndex, slot in ipairs(requiredSlots or {}) do
		local reagent = SelectLowestQualityReagent(slot)
		baselineBySlot[slotIndex] = reagent
		AddCraftingReagentInfo(reagentInfo, slot, reagent)
	end
	return reagentInfo, baselineBySlot
end

-- Builds the schematic-derived portion of reagent skill facts (slots, reagents,
-- quantities) without any crafter-specific GetCraftingOperationInfo probing.
-- Shared by the crafter-side facts builder and the customer-side wire-format
-- rehydration: both sides reconstruct identical slot structures from the same
-- local recipe schematic data.
local function BuildReagentFactsSkeleton(recipeID)
	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local okSchematic, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if not okSchematic or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return nil
	end

	local requiredSlots = {}
	local optionalSlots = {}
	for slotIndex, reagentSlotSchematic in ipairs(schematic.reagentSlotSchematics) do
		if not reagentSlotSchematic.hiddenInCraftingForm and type(reagentSlotSchematic.reagents) == "table" and #reagentSlotSchematic.reagents > 0 then
			local reagentType = reagentSlotSchematic.reagentType
			local isBasic = Enum and Enum.CraftingReagentType and reagentType == Enum.CraftingReagentType.Basic
			if reagentSlotSchematic.required == true or isBasic then
				requiredSlots[#requiredSlots + 1] = reagentSlotSchematic
			elseif IsOptionalDifficultySlot(reagentSlotSchematic) then
				optionalSlots[#optionalSlots + 1] = reagentSlotSchematic
			end
		end
	end

	local baselineReagentInfo, baselineBySlot = BuildBaselineRequiredReagents(requiredSlots)

	local facts = {
		scanModelVersion = AF.SCAN_MODEL_VERSION or 2,
		recipeID = tonumber(recipeID),
		requiredSlots = {},
		optionalSlots = {},
	}

	for slotIndex, reagentSlotSchematic in ipairs(requiredSlots) do
		local baselineReagent = baselineBySlot[slotIndex]
		local slotFact = {
			slotIndex = reagentSlotSchematic.slotIndex or slotIndex,
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
			slotKey = GetSlotKey(reagentSlotSchematic, slotIndex),
			slotText = GetReagentSlotText(reagentSlotSchematic),
			quantity = baselineReagent and GetQuantityRequired(reagentSlotSchematic, baselineReagent) or tonumber(reagentSlotSchematic.quantityRequired) or 1,
			reagents = {},
			qualityBonuses = {},
		}
		for _, reagent in ipairs(reagentSlotSchematic.reagents or {}) do
			local entry = BuildStoredReagent(reagentSlotSchematic, reagent, slotIndex, false)
			if entry then
				slotFact.reagents[#slotFact.reagents + 1] = entry
			end
		end
		facts.requiredSlots[#facts.requiredSlots + 1] = slotFact
	end

	for slotIndex, reagentSlotSchematic in ipairs(optionalSlots) do
		local slotFact = {
			slotIndex = reagentSlotSchematic.slotIndex or slotIndex,
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
			slotKey = GetSlotKey(reagentSlotSchematic, slotIndex),
			slotText = GetReagentSlotText(reagentSlotSchematic),
			reagents = {},
		}
		for _, reagent in ipairs(reagentSlotSchematic.reagents or {}) do
			local entry = BuildStoredReagent(reagentSlotSchematic, reagent, slotIndex, true)
			if entry then
				slotFact.reagents[#slotFact.reagents + 1] = entry
			end
		end
		facts.optionalSlots[#facts.optionalSlots + 1] = slotFact
	end

	return facts, requiredSlots, baselineReagentInfo, baselineBySlot, recipeInfo
end

function AF:BuildRecipeReagentSkillFacts(recipeID)
	if self:IsSecretValue(recipeID) then
		return nil
	end
	local facts, requiredSlots, baselineReagentInfo, baselineBySlot, recipeInfo = BuildReagentFactsSkeleton(recipeID)
	if not facts then
		return nil
	end

	local baselineOperationInfo = GetOperationInfoForReagentInfo(recipeID, baselineReagentInfo)
	if not baselineOperationInfo then
		baselineOperationInfo = GetOperationInfoForReagentInfo(recipeID, {})
	end
	if not baselineOperationInfo then
		return nil
	end

	local baselineTotalSkill = GetOperationTotalSkill(baselineOperationInfo) or 0
	facts.baseSkill = baselineTotalSkill
	facts.baseRecipeDifficulty = GetOperationDifficulty(baselineOperationInfo) or tonumber(baselineOperationInfo.baseDifficulty) or 0
	facts.maxOutputQuality = tonumber(recipeInfo and recipeInfo.maxQuality) or tonumber(GetRecipeDisplayQualityInfo(recipeID, baselineOperationInfo, baselineReagentInfo)) or 1
	facts.probeMethod = "GetCraftingOperationInfo reagent quality deltas"
	facts.operationInfoFields = {
		"baseDifficulty",
		"bonusDifficulty",
		"baseSkill",
		"bonusSkill",
		"craftingQuality",
		"quality",
		"guaranteedCraftingQualityID",
	}

	for slotIndex, reagentSlotSchematic in ipairs(requiredSlots) do
		local slotFact = facts.requiredSlots[slotIndex]
		for _, quality in ipairs(GetRequiredQualityList(reagentSlotSchematic)) do
			YieldSkillFactsBuildIfNeeded()
			local reagent = SelectRepresentativeQualityReagent(reagentSlotSchematic, quality)
			local probeReagentInfo = {}
			for baselineSlotIndex, baselineSlot in ipairs(requiredSlots) do
				AddCraftingReagentInfo(probeReagentInfo, baselineSlot, baselineSlotIndex == slotIndex and reagent or baselineBySlot[baselineSlotIndex])
			end
			local operationInfo = GetOperationInfoForReagentInfo(recipeID, probeReagentInfo)
			local delta = operationInfo and ((GetOperationTotalSkill(operationInfo) or baselineTotalSkill) - baselineTotalSkill) or 0
			slotFact.qualityBonuses[quality] = delta / math.max(1, tonumber(slotFact.quantity) or 1)
		end
	end

	return facts, baselineOperationInfo, baselineReagentInfo
end

-- Customer-side: rebuilds full reagent skill facts from the lean wire format
-- (see AF:BuildWireReagentSkillFacts in Comms.lua) plus the local recipe
-- schematic. Returns nil when the wire data targets a different scan model
-- version or the local schematic cannot be matched to the transmitted slots.
function AF:RehydrateWireReagentSkillFacts(wire, recipeID)
	if type(wire) ~= "table" then
		return nil
	end
	if tonumber(wire.v) ~= tonumber(self.SCAN_MODEL_VERSION or 2) then
		return nil
	end
	recipeID = tonumber(recipeID)
	if not recipeID or self:IsSecretValue(recipeID) then
		return nil
	end
	local facts = BuildReagentFactsSkeleton(recipeID)
	if not facts then
		return nil
	end
	facts.baseSkill = tonumber(wire.s) or 0
	facts.baseRecipeDifficulty = tonumber(wire.d) or 0
	facts.maxOutputQuality = tonumber(wire.q) or 1
	facts.rehydrated = true

	local bySlotIndex = {}
	local byDataSlotIndex = {}
	for _, slotFact in ipairs(facts.requiredSlots) do
		if tonumber(slotFact.slotIndex) then
			bySlotIndex[tonumber(slotFact.slotIndex)] = slotFact
		end
		if tonumber(slotFact.dataSlotIndex) then
			byDataSlotIndex[tonumber(slotFact.dataSlotIndex)] = slotFact
		end
	end
	for _, wireSlot in ipairs(type(wire.b) == "table" and wire.b or {}) do
		local slotFact = (tonumber(wireSlot.i) and bySlotIndex[tonumber(wireSlot.i)])
			or (tonumber(wireSlot.x) and byDataSlotIndex[tonumber(wireSlot.x)])
		if not slotFact then
			return nil
		end
		slotFact.quantity = tonumber(wireSlot.n) or slotFact.quantity
		for quality, bonus in pairs(type(wireSlot.t) == "table" and wireSlot.t or {}) do
			quality = tonumber(quality)
			if quality then
				slotFact.qualityBonuses[quality] = tonumber(bonus) or 0
			end
		end
	end
	return facts
end

function AF:CreateRecipeReagentSkillFactsCoroutine(recipeID)
	local state = {
		recipeID = recipeID,
		stats = {
			evaluated = 1,
			qualityTierCombinations = self:EstimateRecipeQualityTierCombinations(recipeID),
			normalCalls = 1,
			concentrationCalls = 0,
			outputItemLevelCalls = 0,
			skippedByQuality = 0,
			skippedConcentration = 0,
			skippedMaxQualityConcentration = 0,
			prunedBelowBest = 0,
			noNormalInfo = 0,
			endpointShortcut = false,
			endpointShortcutSaved = 0,
		},
	}
	state.co = coroutine.create(function()
		local facts = AF:BuildRecipeReagentSkillFacts(recipeID)
		if not facts then
			return { debugReason = "recipe skill facts unavailable", debugScanStats = state.stats }
		end
		facts.debugScanStats = state.stats
		return facts
	end)
	return state
end

function AF:ResumeRecipeReagentSkillFactsState(state, workBudgetMS)
	if not state or type(state) ~= "table" or not state.co then
		return nil, "invalid skill facts state"
	end
	skillFactsYieldState = {
		startedMS = GetRecipeCapabilityTimeMS(),
		budgetMS = tonumber(workBudgetMS) or 5,
	}
	local ok, result = coroutine.resume(state.co)
	skillFactsYieldState = nil
	if not ok then
		return nil, result
	end
	if coroutine.status(state.co) == "dead" then
		return result
	end
	return nil
end

function AF:GetRecipeCapability(recipeID, best)
	local capability = {}
	local facts, operationInfo, baselineReagentInfo = self:BuildRecipeReagentSkillFacts(recipeID)
	if facts then
		capability.reagentSkillFacts = facts
		capability.scanModelVersion = facts.scanModelVersion
	end
	if not operationInfo then
		local ok
		ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
		if not ok then
			operationInfo = nil
		end
	end
	if type(operationInfo) == "table" then
		ApplyOperationInfo(capability, recipeID, operationInfo)
		capability.outputItemLevel = GetRecipeOutputItemLevel(recipeID, operationInfo, baselineReagentInfo or {})
	end

	if capability.reagentSkillFacts and self.BuildReagentSuggestion then
		local suggestionEntry = CopyTable(capability)
		suggestionEntry.recipeID = recipeID
		local suggestion = self:BuildReagentSuggestion(suggestionEntry)
		local outcome = self:ComputeCraftOutcome(suggestionEntry)
		capability.concentrationQuality = outcome and outcome.concentrationQuality or nil
		capability.concentrationCost = nil
		capability.bestQuality = suggestion and suggestion.quality or nil
		capability.rawBestQuality = capability.bestQuality
		capability.bestConcentrationQuality = suggestion and suggestion.concentrationQuality or nil
		capability.bestTotalSkill = suggestion and suggestion.skill or nil
		capability.bestConcentrationCost = nil
		capability.bestOutputItemLevel = capability.outputItemLevel
		capability.bestReagents = suggestion and suggestion.reagents or nil
		capability.bestReagentSignature = BuildReagentSignature(capability.bestReagents)
		capability.bestReagentTruncated = false
		capability.bestReagentPendingNames = false
	end

	capability.professionLink = self:CaptureCurrentProfessionLink()
	capability.skillProbeSignature = self:BuildSkillProbeSignature(recipeID, capability)
	return capability
end

function AF:ClearRecipeCapabilityRuntimeCaches()
	WipeTable(RECIPE_INFO_CACHE)
	WipeTable(self.recipeCapabilityCache)
	self.recipeCapabilityCache = nil
	self.recipeCapabilityCacheSignature = nil
end

function AF:GetRecipeSkillProbe(recipeID)
	local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
	if not ok or type(operationInfo) ~= "table" then
		return nil
	end

	local probe = {}
	ApplyOperationInfo(probe, recipeID, operationInfo)
	probe.skillProbeSignature = self:BuildSkillProbeSignature(recipeID, probe)
	return probe
end

function AF:BuildSkillProbeSignature(recipeID, probe)
	if not recipeID or not probe then
		return nil
	end
	return table.concat({
		"SP" .. SKILL_PROBE_SIGNATURE_VERSION,
		tonumber(recipeID) or 0,
		tonumber(probe.recipeDifficulty) or 0,
		tonumber(probe.bonusDifficulty) or 0,
		tonumber(probe.lowerSkillThreshold) or 0,
		tonumber(probe.upperSkillThreshold) or 0,
		tonumber(probe.baseSkill) or 0,
		tonumber(probe.bonusSkill) or 0,
		tonumber(probe.totalSkill) or 0,
		tonumber(probe.rawQuality) or 0,
		tonumber(probe.quality) or 0,
	}, ":")
end

function AF:BuildFullScanSignature(recipeID, itemID, skillProbeSignature)
	if not recipeID or not itemID or not skillProbeSignature then
		return nil
	end
	return table.concat({
		"FS" .. FULL_SCAN_SIGNATURE_VERSION,
		tonumber(recipeID) or 0,
		tonumber(itemID) or 0,
		skillProbeSignature,
	}, ":")
end

function AF:ApplyRecipeSkillProbe(item, recipeID, probe)
	if not item or not recipeID or not probe then
		return
	end
	item.recipeDifficulty = probe.recipeDifficulty
	item.totalSkill = probe.totalSkill
	item.quality = probe.quality
	item.rawQuality = probe.rawQuality
	item.skillProbeSignature = probe.skillProbeSignature or self:BuildSkillProbeSignature(recipeID, probe)
end

function AF:ProbeRequiresFullScan(item, recipeID, itemID, probe)
	if not item or not probe then
		return true
	end
	if tonumber(item.recipeID) ~= tonumber(recipeID) or tonumber(item.itemID) ~= tonumber(itemID) then
		return true
	end
	if not self:IsCurrentScanModelEntry(item) then
		return true
	end
	if tonumber(item.quality) ~= tonumber(probe.quality) then
		return true
	end
	if tonumber(item.rawQuality) ~= tonumber(probe.rawQuality) then
		return true
	end
	if tonumber(item.recipeDifficulty) ~= tonumber(probe.recipeDifficulty) then
		return true
	end
	local fullScanSignature = self:BuildFullScanSignature(recipeID, itemID, probe.skillProbeSignature or self:BuildSkillProbeSignature(recipeID, probe))
	if item.fullScanSignature ~= fullScanSignature then
		return true
	end
	return false
end

function AF:GetProfessionRecipeSignature()
	local profession = self:GetCurrentProfessionInfo()
	local recipeIDs = self:GetCurrentProfessionRecipeIDs(profession)
	if type(recipeIDs) ~= "table" then
		return nil
	end

	local learnedRecipeIDs = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if not recipeInfo or recipeInfo.learned ~= false then
			table.insert(learnedRecipeIDs, tonumber(recipeID) or 0)
		end
	end
	table.sort(learnedRecipeIDs, SortNumbers)
	return table.concat(learnedRecipeIDs, ",")
end

local function AddCategoryID(categoryIDs, category)
	local categoryID = tonumber(category)
	if categoryID then
		categoryIDs[categoryID] = true
	end
end

function AF:ProfessionInfoMatchesProfession(profession, info)
	if not profession or type(info) ~= "table" then
		return false
	end

	local professionID = tonumber(info.professionID)
	local parentProfessionID = tonumber(info.parentProfessionID)
	local candidates = {
		tonumber(profession.id),
		tonumber(profession.skillLineID),
		tonumber(profession.parentProfessionID),
	}
	for _, candidate in ipairs(candidates) do
		if candidate and professionID == candidate then
			return true
		end
	end
	return parentProfessionID
		and (parentProfessionID == tonumber(profession.id) or parentProfessionID == tonumber(profession.parentProfessionID))
		or false
end

function AF:GetCurrentProfessionCategoryIDs()
	local ok, categories = pcall(C_TradeSkillUI.GetCategories)
	if not ok or type(categories) ~= "table" then
		return nil
	end

	local categoryIDs = {}
	for _, category in ipairs(categories) do
		AddCategoryID(categoryIDs, category)
	end
	return next(categoryIDs) and categoryIDs or nil
end

function AF:CategoryBelongsToCurrentProfession(categoryID, categoryIDs)
	categoryID = tonumber(categoryID)
	if not categoryID or not categoryIDs then
		return false
	end
	if categoryIDs[categoryID] then
		return true
	end
	local seen = {}
	for _ = 1, 8 do
		if not categoryID or seen[categoryID] then
			return false
		end
		seen[categoryID] = true
		local info = {}
		local ok, result = pcall(C_TradeSkillUI.GetCategoryInfo, categoryID, info)
		if not ok then
			return false
		end
		if type(result) == "table" then
			info = result
		end
		local parentCategoryID = tonumber(info.parentCategoryID)
		if parentCategoryID and categoryIDs[parentCategoryID] then
			return true
		end
		categoryID = parentCategoryID
	end
	return false
end

function AF:RecipeBelongsToProfession(profession, recipeInfo, categoryIDs, recipeID)
	if not profession or type(recipeInfo) ~= "table" then
		return false
	end
	recipeID = tonumber(recipeID or recipeInfo.recipeID)

	if recipeID then
		local ok, professionInfo = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if ok and type(professionInfo) == "table" then
			return self:ProfessionInfoMatchesProfession(profession, professionInfo)
		end
	end

	local professionCandidates = {
		tonumber(profession.id),
		tonumber(profession.skillLineID),
		tonumber(profession.parentProfessionID),
	}
	local sawProfessionField = false
	for _, field in ipairs({ "professionID", "parentProfessionID" }) do
		local value = tonumber(recipeInfo[field])
		if value then
			sawProfessionField = true
			for _, candidate in ipairs(professionCandidates) do
				if candidate and value == candidate then
					return true
				end
			end
		end
	end
	if sawProfessionField then
		return false
	end

	local categoryID = tonumber(recipeInfo.categoryID or recipeInfo.category)
	if categoryID then
		return self:CategoryBelongsToCurrentProfession(categoryID, categoryIDs)
	end

	return categoryID == nil and categoryIDs == nil
end

function AF:GetCurrentProfessionRecipeIDs(profession)
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
	if type(recipeIDs) ~= "table" then
		return nil
	end

	local categoryIDs = self:GetCurrentProfessionCategoryIDs()
	local filtered = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if self:RecipeBelongsToProfession(profession, recipeInfo, categoryIDs, recipeID) then
			table.insert(filtered, recipeID)
		end
		if self.YieldScanBuildIfNeeded then
			self:YieldScanBuildIfNeeded()
		end
	end

	return filtered
end

function AF:GetProfessionSpecSignature(professionID)
	if not professionID then
		return "nospec"
	end
	if not C_ProfSpecs.SkillLineHasSpecialization(professionID) then
		return "nospec"
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

	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
	local recipeCount = type(recipeIDs) == "table" and #recipeIDs or 0
	return table.concat({
		SCAN_SIGNATURE_VERSION,
		self.SCAN_MODEL_VERSION or 2,
		self:GetOrderableRecipeDataVersion(),
		tonumber(profession.id) or 0,
		recipeCount,
	}, "|")
end

function AF:GetCurrentProfessionScanSignatureVersion()
	return SCAN_SIGNATURE_VERSION
end

function AF:EstimateRecipeQualityTierCombinations(recipeID)
	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local okSchematic, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if not okSchematic or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return 0
	end

	local combinations = 1
	for _, reagentSlotSchematic in ipairs(schematic.reagentSlotSchematics) do
		if not reagentSlotSchematic.hiddenInCraftingForm and type(reagentSlotSchematic.reagents) == "table" and #reagentSlotSchematic.reagents > 0 then
			local reagentType = reagentSlotSchematic.reagentType
			local isBasic = Enum and Enum.CraftingReagentType and reagentType == Enum.CraftingReagentType.Basic
			local isRequired = reagentSlotSchematic.required == true
			if (isBasic or isRequired) and #reagentSlotSchematic.reagents > 1 then
				local uniqueQualities = {}
				for _, reagent in ipairs(reagentSlotSchematic.reagents) do
					local quality = GetReagentQuality(reagent) or 0
					uniqueQualities[quality] = true
				end
				local tierCount = 0
				for _ in pairs(uniqueQualities) do
					tierCount = tierCount + 1
				end
				combinations = combinations * math.max(1, tierCount)
			end
		end
	end
	return combinations
end

function AF:ApplyRecipeCapability(item, recipeID, best)
	if not item or not recipeID then
		return
	end
	local capability
	if type(best) == "table" and tonumber(best.scanModelVersion) == (self.SCAN_MODEL_VERSION or 2) then
		capability = {}
		capability.reagentSkillFacts = best
		capability.scanModelVersion = best.scanModelVersion
		local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
		if ok and type(operationInfo) == "table" then
			ApplyOperationInfo(capability, recipeID, operationInfo)
			capability.outputItemLevel = GetRecipeOutputItemLevel(recipeID, operationInfo, {})
		end
		if self.BuildReagentSuggestion then
			local suggestionEntry = CopyTable(capability)
			suggestionEntry.recipeID = recipeID
			local suggestion = self:BuildReagentSuggestion(suggestionEntry)
			local outcome = self:ComputeCraftOutcome(suggestionEntry)
			capability.recipeDifficulty = best.baseRecipeDifficulty or capability.recipeDifficulty
			capability.totalSkill = best.baseSkill or capability.totalSkill
			capability.quality = outcome and outcome.quality or capability.quality
			capability.rawQuality = capability.quality
			capability.concentrationQuality = outcome and outcome.concentrationQuality or nil
			capability.bestQuality = suggestion and suggestion.quality or nil
			capability.rawBestQuality = capability.bestQuality
			capability.bestConcentrationQuality = suggestion and suggestion.concentrationQuality or nil
			capability.bestTotalSkill = suggestion and suggestion.skill or nil
			capability.bestOutputItemLevel = capability.outputItemLevel
			capability.bestReagents = suggestion and suggestion.reagents or nil
			capability.bestReagentSignature = BuildReagentSignature(capability.bestReagents)
			capability.bestReagentTruncated = false
			capability.bestReagentPendingNames = false
		end
		capability.professionLink = self:CaptureCurrentProfessionLink()
		capability.skillProbeSignature = self:BuildSkillProbeSignature(recipeID, capability)
	else
		capability = self:GetRecipeCapability(recipeID, best)
	end
	item.scanModelVersion = capability.scanModelVersion or self.SCAN_MODEL_VERSION or 2
	item.reagentSkillFacts = capability.reagentSkillFacts
	item.maxOutputQuality = capability.reagentSkillFacts and capability.reagentSkillFacts.maxOutputQuality or item.maxOutputQuality
	item.concentrationQuality = capability.concentrationQuality
	item.concentrationCost = nil
	item.outputItemLevel = capability.outputItemLevel
	item.bestQuality = capability.bestQuality
	item.rawBestQuality = capability.rawBestQuality
	item.bestConcentrationQuality = capability.bestConcentrationQuality
	item.bestTotalSkill = capability.bestTotalSkill
	item.bestConcentrationCost = nil
	item.bestOutputItemLevel = capability.bestOutputItemLevel
	item.bestReagents = capability.bestReagents
	item.bestReagentSignature = capability.bestReagentSignature
	item.bestReagentSummary = nil
	item.bestReagentDetails = nil
	item.bestReagentSummaryUpdatedAt = capability.bestReagents and self:Now() or nil
	item.bestReagentTruncated = capability.bestReagentTruncated == true
	item.bestReagentPendingNames = capability.bestReagentPendingNames == true
	item.optionalDifficultyDelta = nil
	item.optionalQuality = nil
	item.optionalOutputItemLevel = nil
	item.optionalOutputItemLevelDelta = nil
	item.optionalConcentrationQuality = nil
	item.optionalReagents = nil
	item.optionalReagentSummary = nil
	item.optionalSlotCount = capability.reagentSkillFacts and #(capability.reagentSkillFacts.optionalSlots or {}) or nil
	item.optionalBestReagents = nil
	item.optionalBestReagentSignature = nil
	item.optionalBestReagentSummaryUpdatedAt = nil
	item.optionalBestReagentTruncated = nil
	item.debugBestCandidateSummary = nil
	item.professionLink = capability.professionLink or item.professionLink
	self:ApplyRecipeSkillProbe(item, recipeID, capability)
	item.fullScanSignature = self:BuildFullScanSignature(recipeID, item.itemID, item.skillProbeSignature)
end
