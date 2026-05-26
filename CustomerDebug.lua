local _, AF = ...

local DEBUG_CERTIFIED_COUNT = 10
local DEBUG_PINNED_COUNT = 6
local DEBUG_OFFLINE_ROWS = {
	[4] = true,
	[7] = true,
	[9] = true,
}

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

local DEBUG_ALT_CONTACT_NAMES = {
	"Mainora",
	"Brokerwyn",
	"Guildelle",
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

local function GetDebugConcentrationQuality(bestQuality, enabled)
	bestQuality = tonumber(bestQuality) or 0
	if enabled and bestQuality > 0 and bestQuality < 5 then
		return bestQuality + 1
	end
	return nil
end

local function SetDebugWhoStatus(AF, name, online, failed)
	name = AF:NormalizeName(name)
	if not name then
		return
	end
	AF.whoStatus = AF.whoStatus or {}
	AF.whoStatus[name] = AF.whoStatus[name] or {}
	local status = AF.whoStatus[name]
	status.pending = nil
	status.checkedAt = AF:Now()
	status.online = online
	status.checkFailedAt = failed and AF:Now() or nil
	if online ~= true and AF.ClearCustomerWhoOnline then
		AF:ClearCustomerWhoOnline(name)
	end
end

local function HasDebugSelfResults(AF, itemKey)
	local cache = AF.db.customerCache[tostring(itemKey or "")]
	if not cache then
		return false
	end
	for _, entry in pairs(cache) do
		if entry.debug then
			return true
		end
	end
	return false
end

local function RefreshExistingDebugSelfResults(AF, itemKey)
	local cache = AF.db.customerCache[tostring(itemKey or "")]
	if not cache then
		return
	end
	local now = AF:Now()
	for key, entry in pairs(cache) do
		if entry.debug then
			entry.debugWhoRefresh = nil
			if key == "__debug_self_5" then
				SetDebugWhoStatus(AF, entry.orderTarget or entry.name or entry.target, true)
			end
			if key == "__debug_self_6" then
				entry.verifiedAt = nil
				entry.lastQueryToken = 0
				entry.lastQueryAt = nil
			else
				entry.verifiedAt = entry.verifiedAt or now
				entry.lastQueryToken = AF.currentCustomerQueryToken
				entry.lastQueryAt = AF.lastQueryAt
			end
		end
	end
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

function AF:ClearAllDebugSelfResults()
	for itemID in pairs(self.db and self.db.customerCache or {}) do
		self:ClearDebugSelfResults(itemID)
	end
end

function AF:InjectDebugSelfResult(itemID, professionID)
	if not self:IsDevFakeRowsEnabled() then
		return
	end
	if not self.currentCustomerQueryToken then
		return
	end

	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	if professionID and professionID ~= 0 and self:GetBaseProfessionID(item.professionID) ~= self:GetBaseProfessionID(professionID) then
		return
	end
	if not self:IsProfessionAdvertised(self:GetPlayerFullName(), item.professionID) then
		return
	end

	local itemKey = tostring(itemID)
	if HasDebugSelfResults(self, itemKey) then
		RefreshExistingDebugSelfResults(self, itemKey)
		return
	end

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
		outputItemLevel = item.outputItemLevel,
		bestQuality = item.bestQuality,
		rawBestQuality = item.rawBestQuality,
		bestQualityAtlas = item.bestQualityAtlas,
		bestConcentrationQuality = nil,
		bestTotalSkill = item.bestTotalSkill,
		bestConcentrationCost = nil,
		bestOutputItemLevel = item.bestOutputItemLevel,
		bestReagents = item.bestReagents,
		bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
		bestReagentTruncated = item.bestReagentTruncated,
		bestReagentPendingNames = item.bestReagentPendingNames,
		optionalBestReagents = item.optionalBestReagents,
		optionalBestReagentSummaryUpdatedAt = item.optionalBestReagentSummaryUpdatedAt or now,
		optionalBestReagentTruncated = item.optionalBestReagentTruncated,
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
		local contactName = GetDebugValue(DEBUG_ALT_CONTACT_NAMES, i) .. "-" .. (GetRealmName() or "")
		local priceCopper = i == 1 and 0 or (i * 12500000)
		local baseQuality = math.min(5, 2 + i)
		local bestQuality = math.min(5, baseQuality + 1)
		local concentrationQuality = GetDebugConcentrationQuality(bestQuality, i ~= 2)
		self:SetFavoriteArtisan(altName, i == 1)
		SetDebugWhoStatus(self, altName, i == 1 and true or nil)
		self.db.customerCache[itemKey]["__debug_alt_" .. i] = {
			name = altName,
			target = contactName,
			orderTarget = altName,
			itemID = itemID,
			professionID = item.professionID,
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
			outputItemLevel = item.outputItemLevel,
			bestQuality = bestQuality,
			rawBestQuality = bestQuality,
			bestQualityAtlas = "Professions-Icon-Quality-Tier" .. bestQuality .. "-Small",
			bestConcentrationQuality = concentrationQuality,
			bestConcentrationQualityAtlas = concentrationQuality and ("Professions-Icon-Quality-Tier" .. concentrationQuality .. "-Small") or nil,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = concentrationQuality and (60 + i * 15) or nil,
			bestOutputItemLevel = item.bestOutputItemLevel,
			bestReagents = item.bestReagents,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			optionalBestReagents = item.optionalBestReagents,
			optionalBestReagentSummaryUpdatedAt = item.optionalBestReagentSummaryUpdatedAt or now,
			optionalBestReagentTruncated = item.optionalBestReagentTruncated,
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
		local concentrationQuality = GetDebugConcentrationQuality(bestQuality, i % 2 == 0)
		local note = GetDebugValue(DEBUG_NOTES, i)
		local debugName = GetDebugValue(DEBUG_CRAFTER_NAMES, i) .. "-" .. (GetRealmName() or "")
		local pinned = i <= DEBUG_PINNED_COUNT
		local offline = DEBUG_OFFLINE_ROWS[i] == true
		if pinned then
			self:SetFavoriteArtisan(debugName, true)
		else
			self:SetFavoriteArtisan(debugName, false)
		end
		if offline then
			SetDebugWhoStatus(self, debugName, false)
		else
			SetDebugWhoStatus(self, debugName, (i <= 3 or i == 5) and true or nil)
		end
		self.db.customerCache[itemKey]["__debug_self_" .. i] = {
			name = debugName,
			target = debugName,
			orderTarget = debugName,
			itemID = itemID,
			professionID = item.professionID,
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
			outputItemLevel = item.outputItemLevel,
			bestQuality = bestQuality,
			rawBestQuality = bestQuality,
			bestQualityAtlas = "Professions-Icon-Quality-Tier" .. bestQuality .. "-Small",
			bestConcentrationQuality = concentrationQuality,
			bestConcentrationQualityAtlas = concentrationQuality and ("Professions-Icon-Quality-Tier" .. concentrationQuality .. "-Small") or nil,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = concentrationQuality and (80 + i * 10) or nil,
			bestOutputItemLevel = item.bestOutputItemLevel,
			bestReagents = item.bestReagents,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt or now,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			optionalBestReagents = item.optionalBestReagents,
			optionalBestReagentSummaryUpdatedAt = item.optionalBestReagentSummaryUpdatedAt or now,
			optionalBestReagentTruncated = item.optionalBestReagentTruncated,
			professionLink = item.professionLink,
			updatedAt = pinned and now or (now - (i * 300)),
			verifiedAt = i == 6 and nil or now,
			lastQueryToken = i == 6 and 0 or self.currentCustomerQueryToken,
			lastQueryAt = i == 6 and nil or self.lastQueryAt,
			debug = true,
		}
	end
end
