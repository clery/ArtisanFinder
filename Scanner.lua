local _, AF = ...

local function AddOutput(outputs, itemID)
	itemID = tonumber(itemID)
	if itemID then
		outputs[itemID] = true
	end
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
		name = info.professionName or info.parentProfessionName or ("Profession " .. tostring(professionID)),
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

local function GetOperationQuality(operationInfo)
	if type(operationInfo) ~= "table" then
		return nil
	end
	return operationInfo.craftingQuality or operationInfo.quality or operationInfo.guaranteedCraftingQualityID
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
		capability.quality = GetOperationQuality(operationInfo)
	end

	local okConcentration, concentrationInfo = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {}, nil, true)
	if okConcentration and type(concentrationInfo) == "table" then
		capability.concentrationQuality = GetOperationQuality(concentrationInfo)
		capability.concentrationCost = concentrationInfo.concentrationCost
		capability.recipeDifficulty = capability.recipeDifficulty or concentrationInfo.baseDifficulty
		if not capability.totalSkill then
			local totalSkill = (tonumber(concentrationInfo.baseSkill) or 0) + (tonumber(concentrationInfo.bonusSkill) or 0)
			if totalSkill > 0 then
				capability.totalSkill = totalSkill
			end
		end
	end

	capability.professionLink = self:GetProfessionLink()
	return capability
end

function AF:ApplyRecipeCapability(item, recipeID)
	if not item or not recipeID then
		return
	end
	local capability = self:GetRecipeCapability(recipeID)
	item.recipeDifficulty = capability.recipeDifficulty
	item.totalSkill = capability.totalSkill
	item.quality = capability.quality
	item.concentrationQuality = capability.concentrationQuality
	item.concentrationCost = capability.concentrationCost
	item.professionLink = capability.professionLink or item.professionLink
end

function AF:ScanCurrentProfession(silent)
	if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady or not C_TradeSkillUI.IsTradeSkillReady() then
		if not silent then
			self:Print("open a profession and wait for it to finish loading before scanning.")
		end
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		if not silent then
			self:Print("could not identify the current profession.")
		end
		return 0
	end

	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
	if type(recipeIDs) ~= "table" then
		if not silent then
			self:Print("no recipes were available to scan.")
		end
		return 0
	end

	local profile = self.db.artisanProfile
	local professionKey = tostring(profession.id)
	profile.professions[professionKey] = profile.professions[professionKey] or {
		id = profession.id,
		name = profession.name,
		recipes = {},
		updatedAt = self:Now(),
	}
	profile.professions[professionKey].name = profession.name
	profile.professions[professionKey].updatedAt = self:Now()
	profile.professions[professionKey].professionLink = self:GetProfessionLink()
	profile.professions[professionKey].recipes = profile.professions[professionKey].recipes or {}

	local scanned = 0
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
		local learned = not recipeInfo or recipeInfo.learned ~= false
		if learned then
			local outputs = self:GetRecipeOutputItemIDs(recipeID)
			for itemID in pairs(outputs) do
				local itemKey = tostring(itemID)
				local existing = profile.items[itemKey] or {}
				profile.items[itemKey] = existing
				existing.itemID = itemID
				existing.recipeID = recipeID
				existing.recipeName = recipeInfo and recipeInfo.name or existing.recipeName or ("Recipe " .. tostring(recipeID))
				existing.itemName = self:GetDisplayItemName(itemID, existing.itemName)
				existing.professionID = profession.id
				existing.professionName = profession.name
				self:ApplyRecipeCapability(existing, recipeID)
				existing.updatedAt = self:Now()
				profile.professions[professionKey].recipes[tostring(recipeID)] = true
				scanned = scanned + 1
			end
		end
	end

	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end

	if not silent then
		self:Print("scanned " .. scanned .. " craftable item entries for " .. profession.name .. ".")
	end
	return scanned
end

function AF:AutoScanCurrentProfession(force)
	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		return 0
	end

	self.autoScannedProfessions = self.autoScannedProfessions or {}
	local key = tostring(profession.id)
	if self.autoScannedProfessions[key] and not force then
		return 0
	end

	local scanned = self:ScanCurrentProfession(true)
	if scanned > 0 then
		self.autoScannedProfessions[key] = true
	end
	return scanned
end

function AF:QueueAutoScan(force)
	self.pendingAutoScanForce = self.pendingAutoScanForce or force == true
	if force then
		self.autoScannedProfessions = {}
	end
	if self.autoScanQueued then
		return
	end

	self.autoScanQueued = true
	C_Timer.After(0.5, function()
		AF.autoScanQueued = false
		local shouldForce = AF.pendingAutoScanForce == true
		AF.pendingAutoScanForce = false
		if AF.AutoScanCurrentProfession then
			AF:AutoScanCurrentProfession(shouldForce)
		end
	end)
end

function AF:ScheduleAutoScan()
	for i = 1, 5 do
		C_Timer.After(i * 2, function()
			if AF.QueueAutoScan then
				AF:QueueAutoScan(false)
			end
		end)
	end
end
