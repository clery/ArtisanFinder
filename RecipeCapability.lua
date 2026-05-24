local _, AF = ...

local MAX_REAGENT_COMBINATIONS = 72
local MAX_OPTIONAL_REAGENT_TESTS_PER_SLOT = 8
local SCAN_SIGNATURE_VERSION = 24
local SKILL_PROBE_SIGNATURE_VERSION = 1
local FULL_SCAN_SIGNATURE_VERSION = 3
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
	if not reagent or not reagent.itemID then
		return 0
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, reagent.itemID)
	if ok and qualityInfo then
		return tonumber(qualityInfo.quality) or 0
	end
	return 0
end

local function GetReagentQualityMarkup(reagent)
	if not reagent or not reagent.itemID then
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
	if not itemID then
		return nil, nil
	end
	local ok, reagentQualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
	if ok and reagentQualityInfo then
		return tonumber(reagentQualityInfo.quality), reagentQualityInfo.iconSmall or reagentQualityInfo.icon
	end
	return nil, nil
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
	target.quality, target.qualityAtlas = GetRecipeDisplayQualityInfo(recipeID, operationInfo, {})
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

local function CopyReagentInfo(reagentInfo)
	local copy = {}
	for _, info in ipairs(reagentInfo or {}) do
		copy[#copy + 1] = {
			reagent = info.reagent,
			dataSlotIndex = info.dataSlotIndex,
			quantity = info.quantity,
		}
	end
	return copy
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
	return IsModifiedReagentSlot(reagentSlotSchematic)
		or not Enum
		or not Enum.CraftingReagentType
		or reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Modifying
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

local function BuildReagentEntry(reagentSlotSchematic, reagent)
	local quantity = GetQuantityRequired(reagentSlotSchematic, reagent)
	if reagent.itemID and reagent.itemID ~= 0 then
		local quality, qualityAtlas = GetReagentQualityInfoFromItemID(reagent.itemID)
		return {
			kind = "item",
			itemID = reagent.itemID,
			quantity = quantity,
			quality = quality or GetReagentQuality(reagent),
			qualityAtlas = qualityAtlas,
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
		}
	end
	if reagent.currencyID and reagent.currencyID ~= 0 then
		return {
			kind = "currency",
			currencyID = reagent.currencyID,
			quantity = quantity,
			dataSlotIndex = reagentSlotSchematic.dataSlotIndex,
		}
	end
	return nil
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
	local qualityItemID = recipeInfo and recipeInfo.qualityItemIDs and recipeInfo.qualityItemIDs[quality]
	local reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(qualityItemID)
	if reagentQuality then
		return reagentQuality, reagentQualityAtlas
	end

	local okQualityItems, qualityItemIDs = pcall(C_TradeSkillUI.GetRecipeQualityItemIDs, recipeID)
	qualityItemID = okQualityItems and type(qualityItemIDs) == "table" and qualityItemIDs[quality] or nil
	reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(qualityItemID)
	if reagentQuality then
		return reagentQuality, reagentQualityAtlas
	end

	local overrideQualityID = recipeInfo and recipeInfo.qualityIDs and recipeInfo.qualityIDs[quality] or quality
	local okOutput, outputInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, reagentInfo or {}, nil, overrideQualityID)
	if okOutput and type(outputInfo) == "table" and outputInfo.itemID then
		reagentQuality, reagentQualityAtlas = GetReagentQualityInfoFromItemID(outputInfo.itemID)
		if reagentQuality then
			return reagentQuality, reagentQualityAtlas
		end
	end

	local maxQuality = tonumber(recipeInfo and recipeInfo.maxQuality)
	local qualityCount = recipeInfo and recipeInfo.qualityIDs and #recipeInfo.qualityIDs or nil
	if maxQuality and qualityCount and qualityCount > 0 and qualityCount < maxQuality and quality <= qualityCount then
		return quality + (maxQuality - qualityCount), nil
	end

	local ok, qualityInfo = pcall(C_TradeSkillUI.GetRecipeItemQualityInfo, recipeID, quality)
	if ok and qualityInfo then
		return GetQualityTierFromAtlas(qualityInfo.iconSmall)
			or GetQualityTierFromAtlas(qualityInfo.icon)
			or tonumber(qualityInfo.quality)
			or quality,
			qualityInfo.iconSmall or qualityInfo.icon
	end
	return quality, nil
end

GetRecipeDisplayQuality = function(recipeID, operationInfo, reagentInfo)
	local quality = GetRecipeDisplayQualityInfo(recipeID, operationInfo, reagentInfo)
	return quality
end

function AF:GetOptionalReagentImpact(recipeID, baseReagentInfo, baseOperationInfo)
	local baseDifficulty = GetOperationDifficulty(baseOperationInfo)
	if not baseDifficulty then
		return nil
	end

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local okSchematic, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if not okSchematic or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return nil
	end

	local selected = {}
	for _, slot in ipairs(schematic.reagentSlotSchematics) do
		if IsOptionalDifficultySlot(slot) then
			local bestReagent
			local bestDifficulty = baseDifficulty
			for reagentIndex, reagent in ipairs(slot.reagents) do
				if reagentIndex > MAX_OPTIONAL_REAGENT_TESTS_PER_SLOT and bestReagent then
					break
				end
				local reagentInfo = CopyReagentInfo(baseReagentInfo)
				AddReagentInfo(reagentInfo, slot, reagent)
				local optionalOnly = {}
				AddReagentInfo(optionalOnly, slot, reagent)
				local normalInfo = TryCraftingOperationInfo(recipeID, {
					{ name = "base+optional", reagents = reagentInfo },
					{ name = "optional", reagents = optionalOnly },
				}, false)
				local difficulty = GetOperationDifficulty(normalInfo) or 0
				if difficulty > bestDifficulty then
					bestReagent = reagent
					bestDifficulty = difficulty
				end
			end
			if bestReagent then
				selected[#selected + 1] = { slot = slot, reagent = bestReagent }
			end
		end
	end
	if #selected == 0 then
		return nil
	end

	local reagentInfo = CopyReagentInfo(baseReagentInfo)
	local optionalOnly = {}
	local optionalReagents = {}
	for _, selection in ipairs(selected) do
		AddReagentInfo(reagentInfo, selection.slot, selection.reagent)
		AddReagentInfo(optionalOnly, selection.slot, selection.reagent)
		local reagentEntry = BuildReagentEntry(selection.slot, selection.reagent)
		if reagentEntry then
			optionalReagents[#optionalReagents + 1] = reagentEntry
		end
	end

	local normalInfo = TryCraftingOperationInfo(recipeID, {
		{ name = "base+optional-all", reagents = reagentInfo },
		{ name = "optional-all", reagents = optionalOnly },
	}, false)
	local optionalDifficulty = GetOperationDifficulty(normalInfo)
	if not optionalDifficulty or optionalDifficulty <= baseDifficulty then
		return nil
	end
	local concentrationInfo = TryCraftingOperationInfo(recipeID, {
		{ name = "base+optional-all", reagents = reagentInfo },
		{ name = "optional-all", reagents = optionalOnly },
	}, true)

	return {
		difficultyDelta = optionalDifficulty - baseDifficulty,
		quality = GetRecipeDisplayQuality(recipeID, normalInfo, reagentInfo),
		qualityAtlas = select(2, GetRecipeDisplayQualityInfo(recipeID, normalInfo, reagentInfo)),
		concentrationQuality = GetRecipeDisplayQuality(recipeID, concentrationInfo, reagentInfo),
		concentrationQualityAtlas = select(2, GetRecipeDisplayQualityInfo(recipeID, concentrationInfo, reagentInfo)),
		reagents = optionalReagents,
		slotCount = #selected,
	}
end

function AF:GetProfessionLink()
	local okCanLink, canLink = pcall(C_TradeSkillUI.CanTradeSkillListLink)
	if not okCanLink then
		return nil, "CanTradeSkillListLink error: " .. tostring(canLink)
	end
	if okCanLink and canLink == false then
		return nil, "CanTradeSkillListLink returned false"
	end
	local ok, link = pcall(C_TradeSkillUI.GetTradeSkillListLink)
	if ok and type(link) == "string" and link ~= "" then
		return link
	end
	return nil, ok and "GetTradeSkillListLink returned no link" or ("GetTradeSkillListLink error: " .. tostring(link))
end

function AF:CaptureCurrentProfessionLink(profession, reason)
	if self.IsOwnProfessionWindowOpen and not self:IsOwnProfessionWindowOpen() then
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

function AF:GetRecipeCapability(recipeID)
	local capability = {}
	local ok, operationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, false)
	if ok and type(operationInfo) == "table" then
		ApplyOperationInfo(capability, recipeID, operationInfo)
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
	if best then
		capability.bestQuality = best.bestQuality
		capability.bestQualityAtlas = best.bestQualityAtlas
		capability.rawBestQuality = best.rawBestQuality
		capability.bestConcentrationQuality = best.bestConcentrationQuality
		capability.bestConcentrationQualityAtlas = best.bestConcentrationQualityAtlas
		capability.bestTotalSkill = best.bestTotalSkill
		capability.bestConcentrationCost = best.bestConcentrationCost
		capability.bestReagents = best.bestReagents
		capability.bestReagentSignature = best.bestReagentSignature
		capability.bestReagentTruncated = best.bestReagentTruncated
		capability.bestReagentPendingNames = false
	end

	local optionalImpact = self:GetOptionalReagentImpact(recipeID, best and best.reagentInfo, best and best.normalInfo or operationInfo)
	if optionalImpact then
		capability.optionalDifficultyDelta = optionalImpact.difficultyDelta
		capability.optionalQuality = optionalImpact.quality
		capability.optionalQualityAtlas = optionalImpact.qualityAtlas
		capability.optionalConcentrationQuality = optionalImpact.concentrationQuality
		capability.optionalConcentrationQualityAtlas = optionalImpact.concentrationQualityAtlas
		capability.optionalReagents = optionalImpact.reagents
		capability.optionalSlotCount = optionalImpact.slotCount
	end

	capability.professionLink = self:CaptureCurrentProfessionLink()
	capability.skillProbeSignature = self:BuildSkillProbeSignature(recipeID, capability)
	return capability
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
		tostring(probe.qualityAtlas or ""),
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
	item.qualityAtlas = probe.qualityAtlas
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
	if not item.bestReagents or item.bestReagentPendingNames then
		return true
	end
	if not item.bestQuality then
		return true
	end
	if tonumber(item.quality) ~= tonumber(probe.quality) then
		return true
	end
	if tonumber(item.rawQuality) ~= tonumber(probe.rawQuality) then
		return true
	end
	if tostring(item.qualityAtlas or "") ~= tostring(probe.qualityAtlas or "") then
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

	local recipeSignature = self:GetProfessionRecipeSignature()
	if not recipeSignature then
		return nil
	end

	return table.concat({ SCAN_SIGNATURE_VERSION, recipeSignature }, "|")
end

function AF:GetBestReagentCapability(recipeID)
	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	local recipeLevel = recipeInfo and recipeInfo.unlockedRecipeLevel
	local okSchematic, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
	if not okSchematic or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return { debugReason = "recipe schematic unavailable" }
	end

	local candidateSlots = {}
	local fixedReagents = {}
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
		local bestReagents = {}
		local reagentQualityScore = 0
		for _, fixed in ipairs(fixedReagents) do
			AddReagentInfo(allReagentInfo, fixed.slot, fixed.reagent)
			if IsModifiedReagentSlot(fixed.slot) then
				AddReagentInfo(modifiedReagentInfo, fixed.slot, fixed.reagent)
			end
			local reagentEntry = BuildReagentEntry(fixed.slot, fixed.reagent)
			if reagentEntry then
				table.insert(bestReagents, reagentEntry)
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
				local reagentEntry = BuildReagentEntry(slot, reagent)
				if reagentEntry then
					table.insert(bestReagents, reagentEntry)
				end
				reagentQualityScore = reagentQualityScore + ((GetReagentQuality(reagent) or 0) * (GetQuantityRequired(slot, reagent) or 1))
			end
		end

		local reagentVariants = {
			{ name = "modified", reagents = modifiedReagentInfo },
			{ name = "all", reagents = allReagentInfo },
			{ name = "empty", reagents = {} },
		}
		local normalInfo, normalVariant = TryCraftingOperationInfo(recipeID, reagentVariants, false)
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
				bestReagents = bestReagents,
				bestReagentSignature = BuildReagentSignature(bestReagents),
				truncated = truncated,
			}
		end
	end

	if useGreedy then
		local function SelectReagents(isBetter)
			local selected = {}
			for slotIndex, candidate in ipairs(candidateSlots) do
				local slot = candidate.slot
				local bestReagent = candidate.optional and nil or slot.reagents[1]
				for _, reagent in ipairs(slot.reagents) do
					if isBetter(reagent, bestReagent) then
						bestReagent = reagent
					end
				end
				selected[slotIndex] = bestReagent
			end
			return selected
		end
		Evaluate(SelectReagents(IsLowerQualityReagent), true)
		Evaluate(SelectReagents(IsHigherQualityReagent), true)
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
		return {}
	end

	return {
		normalInfo = best.normalInfo,
		reagentInfo = best.reagentInfo,
		rawBestQuality = GetOperationQuality(best.normalInfo),
		bestQuality = GetRecipeDisplayQuality(recipeID, best.normalInfo, best.reagentInfo),
		bestQualityAtlas = select(2, GetRecipeDisplayQualityInfo(recipeID, best.normalInfo, best.reagentInfo)),
		bestConcentrationQuality = GetRecipeDisplayQuality(recipeID, best.concentrationInfo, best.reagentInfo),
		bestConcentrationQualityAtlas = select(2, GetRecipeDisplayQualityInfo(recipeID, best.concentrationInfo, best.reagentInfo)),
		bestTotalSkill = GetOperationTotalSkill(best.normalInfo) or GetOperationTotalSkill(best.concentrationInfo),
		bestConcentrationCost = best.concentrationInfo and best.concentrationInfo.concentrationCost or nil,
		bestReagents = best.bestReagents,
		bestReagentSignature = best.bestReagentSignature,
		bestReagentTruncated = best.truncated == true,
	}
end

function AF:ApplyRecipeCapability(item, recipeID)
	if not item or not recipeID then
		return
	end
	local capability = self:GetRecipeCapability(recipeID)
	item.concentrationQuality = capability.concentrationQuality
	item.concentrationQualityAtlas = capability.concentrationQualityAtlas
	item.concentrationCost = capability.concentrationCost
	item.bestQuality = capability.bestQuality
	item.bestQualityAtlas = capability.bestQualityAtlas
	item.rawBestQuality = capability.rawBestQuality
	item.bestConcentrationQuality = capability.bestConcentrationQuality
	item.bestConcentrationQualityAtlas = capability.bestConcentrationQualityAtlas
	item.bestTotalSkill = capability.bestTotalSkill
	item.bestConcentrationCost = capability.bestConcentrationCost
	item.bestReagents = capability.bestReagents
	item.bestReagentSignature = capability.bestReagentSignature
	item.bestReagentSummary = nil
	item.bestReagentDetails = nil
	item.bestReagentSummaryUpdatedAt = capability.bestReagents and self:Now() or nil
	item.bestReagentTruncated = capability.bestReagentTruncated == true
	item.bestReagentPendingNames = capability.bestReagentPendingNames == true
	item.optionalDifficultyDelta = capability.optionalDifficultyDelta
	item.optionalQuality = capability.optionalQuality
	item.optionalQualityAtlas = capability.optionalQualityAtlas
	item.optionalConcentrationQuality = capability.optionalConcentrationQuality
	item.optionalConcentrationQualityAtlas = capability.optionalConcentrationQualityAtlas
	item.optionalReagents = capability.optionalReagents
	item.optionalReagentSummary = nil
	item.optionalSlotCount = capability.optionalSlotCount
	item.debugBestCandidateSummary = nil
	item.professionLink = capability.professionLink or item.professionLink
	self:ApplyRecipeSkillProbe(item, recipeID, capability)
	item.fullScanSignature = self:BuildFullScanSignature(recipeID, item.itemID, item.skillProbeSignature)
end
