local _, AF = ...

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
