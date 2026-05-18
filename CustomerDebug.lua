local _, AF = ...

local DEBUG_CERTIFIED_COUNT = 10

local DEBUG_CRAFTER_NAMES = {
	"Aeloria",
	"Brund",
	"Caelwyn",
	"Dorrik",
	"Elyssia",
	"Faelorn",
	"Grimbolt",
	"Haldrin",
	"Ilyra",
	"Kaevan",
}

local DEBUG_NOTES = {
	"",
	"/w for details",
	"Feel free to send private orders",
	"",
	"Can recraft too",
	"",
	"/w if mats are ready",
}

local DEBUG_ALT_NAMES = {
	"Altora",
	"Bellwyn",
	"Craftelle",
}
local function GetDebugValue(values, index)
	return values[((index - 1) % #values) + 1]
end

local function GetDebugCommissionCopper(index)
	local values = {
		0,
		5000000,
		10000000,
		15000000,
		20000000,
		25000000,
		30000000,
		50000000,
		75000000,
		100000000,
	}
	local copper = GetDebugValue(values, index)
	return copper, copper == 0
end

local function GetDebugQuality(index, offset)
	offset = offset or 0
	return math.max(1, math.min(5, 3 + ((index + offset) % 3)))
end
function AF:ClearDebugSelfResults(itemID)
	local cache = self.db.customerCache[tostring(itemID or "")]
	if not cache then
		return
	end
	for key, entry in pairs(cache) do
		if entry.debug then
			cache[key] = nil
		end
	end
end

function AF:InjectDebugSelfResult(itemID, professionID)
	self:ClearDebugSelfResults(itemID)
	if not self.db.debugSelfResults then
		return
	end
	if not self.currentCustomerQueryToken then
		return
	end

	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	if professionID and professionID ~= 0 and tonumber(item.professionID) ~= tonumber(professionID) then
		return
	end
	if not self:IsProfessionAdvertised(self:GetPlayerFullName(), item.professionID) then
		return
	end

	local itemKey = tostring(itemID)
	local now = self:Now()
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}

	local actualName = self:GetPlayerFullName()
	local actualPriceCopper, actualFreeCommission, actualNote = self:GetItemPrice(itemID, item.professionID)
	self.db.customerCache[itemKey].__debug_self_actual = {
		name = actualName,
		target = actualName,
		orderTarget = actualName,
		itemID = itemID,
		professionID = item.professionID,
		professionName = item.professionName or self:GetProfessionName(item.professionID),
		priceCopper = actualPriceCopper,
		freeCommission = actualFreeCommission,
		note = actualNote,
		recipeID = item.recipeID,
		recipeDifficulty = item.recipeDifficulty,
		totalSkill = item.totalSkill,
		quality = item.quality,
		rawQuality = item.rawQuality,
		qualityAtlas = item.qualityAtlas,
		concentrationQuality = nil,
		concentrationCost = nil,
		bestQuality = item.bestQuality,
		rawBestQuality = item.rawBestQuality,
		bestQualityAtlas = item.bestQualityAtlas,
		bestConcentrationQuality = nil,
		bestTotalSkill = item.bestTotalSkill,
		bestConcentrationCost = nil,
		bestReagentSummary = item.bestReagentSummary,
		bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
		bestReagentTruncated = item.bestReagentTruncated,
		bestReagentPendingNames = item.bestReagentPendingNames,
		professionLink = item.professionLink,
		updatedAt = now,
		verifiedAt = now,
		lastQueryToken = self.currentCustomerQueryToken,
		lastQueryAt = self.lastQueryAt,
		debug = true,
		debugActual = true,
	}

	for i, altBaseName in ipairs(DEBUG_ALT_NAMES) do
		local altName = altBaseName .. "-" .. (GetRealmName() or "")
		local priceCopper = i == 1 and 0 or (i * 12500000)
		local baseQuality = math.min(5, 2 + i)
		local bestQuality = math.min(5, baseQuality + 1)
		self:SetFavoriteArtisan(altName, i == 1)
		self.db.customerCache[itemKey]["__debug_alt_" .. i] = {
			name = altName,
			target = actualName,
			orderTarget = altName,
			itemID = itemID,
			professionID = item.professionID,
			professionName = item.professionName or self:GetProfessionName(item.professionID),
			priceCopper = priceCopper,
			freeCommission = priceCopper == 0,
			note = i == 1 and "Alt crafter, whisper main" or "",
			recipeID = item.recipeID,
			recipeDifficulty = item.recipeDifficulty,
			totalSkill = item.totalSkill,
			quality = baseQuality,
			rawQuality = baseQuality,
			qualityAtlas = "Professions-Icon-Quality-Tier" .. baseQuality .. "-Small",
			concentrationQuality = nil,
			concentrationCost = nil,
			bestQuality = bestQuality,
			rawBestQuality = bestQuality,
			bestQualityAtlas = "Professions-Icon-Quality-Tier" .. bestQuality .. "-Small",
			bestConcentrationQuality = nil,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = nil,
			bestReagentSummary = item.bestReagentSummary,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			professionLink = item.professionLink,
			updatedAt = now,
			verifiedAt = now,
			lastQueryToken = self.currentCustomerQueryToken,
			lastQueryAt = self.lastQueryAt,
			debug = true,
			debugAlt = true,
		}
	end

	for i = 1, DEBUG_CERTIFIED_COUNT - 1 do
		local priceCopper, isFree = GetDebugCommissionCopper(i)
		local baseQuality = GetDebugQuality(i)
		local bestQuality = math.min(5, baseQuality + (i % 3 == 0 and 0 or 1))
		local note = GetDebugValue(DEBUG_NOTES, i)
		local debugName = GetDebugValue(DEBUG_CRAFTER_NAMES, i) .. "-" .. (GetRealmName() or "")
		if i <= 6 then
			self:SetFavoriteArtisan(debugName, true)
		else
			self:SetFavoriteArtisan(debugName, false)
		end
		self.db.customerCache[itemKey]["__debug_self_" .. i] = {
			name = debugName,
			target = debugName,
			orderTarget = debugName,
			itemID = itemID,
			professionID = item.professionID,
			professionName = item.professionName or self:GetProfessionName(item.professionID),
			priceCopper = isFree and 0 or priceCopper,
			freeCommission = isFree,
			note = note,
			recipeID = item.recipeID,
			recipeDifficulty = item.recipeDifficulty,
			totalSkill = item.totalSkill,
			quality = baseQuality,
			rawQuality = baseQuality,
			qualityAtlas = "Professions-Icon-Quality-Tier" .. baseQuality .. "-Small",
			concentrationQuality = nil,
			concentrationCost = nil,
			bestQuality = bestQuality,
			rawBestQuality = bestQuality,
			bestQualityAtlas = "Professions-Icon-Quality-Tier" .. bestQuality .. "-Small",
			bestConcentrationQuality = nil,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = nil,
			bestReagentSummary = item.bestReagentSummary,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			professionLink = item.professionLink,
			updatedAt = now,
			verifiedAt = i == 6 and nil or now,
			lastQueryToken = i == 6 and 0 or self.currentCustomerQueryToken,
			lastQueryAt = i == 6 and nil or self.lastQueryAt,
			debug = true,
		}
	end
end
