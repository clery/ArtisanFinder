local _, AF = ...

local function GetSortQuality(entry)
	return tonumber(entry and entry.bestQuality)
		or tonumber(entry and entry.quality)
		or 0
end

local function GetCertificationSort(entry)
	return entry and entry.tradeLead and 1 or 0
end

local function GetTradeLeadMatchSort(entry)
	if not entry or not entry.tradeLead then
		return 0
	end
	return entry.tradeProfessionMatch and 0 or 1
end

local function GetCommissionSort(entry)
	if entry and entry.freeCommission == true then
		return 0, 0
	end
	local priceCopper = tonumber(entry and entry.priceCopper) or 0
	if priceCopper > 0 then
		return 1, priceCopper
	end
	return 2, 0
end

local function GetSortName(entry)
	return tostring(entry and entry.name or ""):lower()
end

local function GetSeenKey(AF, entry)
	if not entry then
		return nil
	end
	if entry.tradeLead and entry.professionLink then
		return "trade:" .. tostring(entry.target or entry.name or "") .. ":" .. tostring(entry.professionLink)
	end
	return AF:GetFavoriteArtisanKey(entry) or entry.target or entry.name
end

local function MarkSeen(AF, seenNames, entry)
	local key = GetSeenKey(AF, entry)
	if key then
		seenNames[key] = true
	end
	local favoriteKey = AF:GetFavoriteArtisanKey(entry)
	if favoriteKey then
		seenNames[favoriteKey] = true
	end
	if entry and entry.name then
		seenNames[entry.name] = true
	end
	if entry and entry.target then
		seenNames[entry.target] = true
	end
end

local function EntryMatchesCustomerFilter(AF, entry, filterText)
	local haystack = table.concat({
		entry.name or "",
		entry.professionName or "",
		entry.note or "",
		AF:FormatMoney(entry.priceCopper, entry.freeCommission),
		AF:FormatCapability(entry),
		entry.bestReagentSummary or "",
	}, " "):lower()
	return filterText == "" or haystack:find(filterText, 1, true)
end

local function CopyCustomerEntry(entry)
	local copy = {}
	for key, value in pairs(entry or {}) do
		copy[key] = value
	end
	return copy
end

function AF:GetOwnAltRows(itemID, professionID, filterText, seenNames, recipeID)
	local rows = {}
	local currentName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	local itemKey = tostring(itemID or "")
	professionID = tonumber(professionID) or 0
	recipeID = tonumber(recipeID) or 0

	self:ForEachArtisanProfile(function(characterName, profile)
		characterName = self:NormalizeName(characterName)
		if not characterName or characterName == currentName then
			return
		end
		local item = profile.items and profile.items[itemKey]
		if not item then
			return
		end
		if professionID ~= 0 and tonumber(item.professionID) ~= professionID then
			return
		end
		if recipeID ~= 0 and item.recipeID and tonumber(item.recipeID) ~= recipeID then
			return
		end
		local priceCopper, freeCommission, note = self:GetItemPriceForProfile(profile, itemID, item.professionID)
		local profession = profile.professions and profile.professions[tostring(item.professionID or "")]
		local professionLink = item.professionLink or (profession and profession.professionLink) or self:GetRememberedProfessionLink(characterName, item.professionID)
		local entry = {
			name = characterName,
			target = characterName,
			orderTarget = characterName,
			itemID = itemID,
			professionID = item.professionID,
			professionName = item.professionName or self:GetProfessionName(item.professionID, profile),
			priceCopper = priceCopper,
			freeCommission = freeCommission,
			note = note,
			recipeID = item.recipeID,
			recipeDifficulty = item.recipeDifficulty,
			totalSkill = item.totalSkill,
			quality = item.quality,
			rawQuality = item.rawQuality,
			qualityAtlas = item.qualityAtlas,
			concentrationQuality = item.concentrationQuality,
			concentrationCost = item.concentrationCost,
			bestQuality = item.bestQuality,
			rawBestQuality = item.rawBestQuality,
			bestQualityAtlas = item.bestQualityAtlas,
			bestConcentrationQuality = item.bestConcentrationQuality,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = item.bestConcentrationCost,
			bestReagentSummary = item.bestReagentSummary,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			professionLink = professionLink,
			updatedAt = item.updatedAt or profile.updatedAt or self:Now(),
			verifiedAt = self:Now(),
			certified = true,
			tradeLead = false,
			ownAlt = true,
		}
		if EntryMatchesCustomerFilter(self, entry, filterText) then
			local seenKey = GetSeenKey(self, entry)
			if seenKey and not seenNames[seenKey] then
				table.insert(rows, entry)
				MarkSeen(self, seenNames, entry)
			end
		end
	end)

	return rows
end

function AF:GetCachedArtisans(itemID, filterText, sortMode, queryToken)
	local itemCache = self.db.customerCache[tostring(itemID or "")]
	local rows = {}
	local now = self:Now()
	filterText = tostring(filterText or ""):lower()
	local seenNames = {}
	for _, entry in ipairs(self:GetOwnAltRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
		table.insert(rows, entry)
	end

	for _, entry in pairs(itemCache or {}) do
		local verifiedForQuery = queryToken and tonumber(entry.lastQueryToken) == tonumber(queryToken) and entry.verifiedAt
		if verifiedForQuery and entry.updatedAt and now - entry.updatedAt <= self.CACHE_MAX_AGE then
			if EntryMatchesCustomerFilter(self, entry, filterText) then
				local rowEntry = CopyCustomerEntry(entry)
				rowEntry.certified = true
				rowEntry.tradeLead = false
				rowEntry.unavailableFavorite = nil
				rowEntry.professionLink = rowEntry.professionLink or self:GetRememberedProfessionLink(rowEntry.orderTarget or rowEntry.name, rowEntry.professionID)
				table.insert(rows, rowEntry)
				MarkSeen(self, seenNames, rowEntry)
			end
		end
	end

	for _, entry in pairs(itemCache or {}) do
		local favoriteKey = self:GetFavoriteArtisanKey(entry)
		if favoriteKey and not seenNames[favoriteKey] and self:IsFavoriteArtisan(entry) and EntryMatchesCustomerFilter(self, entry, filterText) then
			local favoriteEntry = CopyCustomerEntry(entry)
			favoriteEntry.certified = true
			favoriteEntry.tradeLead = false
			favoriteEntry.unavailableFavorite = true
			favoriteEntry.target = favoriteEntry.orderTarget or favoriteEntry.name
			favoriteEntry.professionLink = favoriteEntry.professionLink or self:GetRememberedProfessionLink(favoriteEntry.orderTarget or favoriteEntry.name, favoriteEntry.professionID)
			table.insert(rows, favoriteEntry)
			MarkSeen(self, seenNames, favoriteEntry)
		end
	end
	if self.GetTradeLeadRows then
		for _, entry in ipairs(self:GetTradeLeadRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
			table.insert(rows, entry)
			MarkSeen(self, seenNames, entry)
		end
	end

	local offlineTrigger = tonumber(self.db.offlineFallbackResults) or 10
	local offlineMax = tonumber(self.db.offlineFallbackMax) or 20
	if offlineTrigger > 0 and offlineMax > 0 and #rows < offlineTrigger then
		local candidates = {}
		for _, entry in pairs(itemCache or {}) do
			local seenKey = GetSeenKey(self, entry)
			local updatedAt = tonumber(entry and entry.updatedAt) or 0
			local isDebug = entry and (entry.debug or tostring(entry.name or ""):find("__debug", 1, true))
			if entry
				and seenKey
				and not seenNames[seenKey]
				and not self:IsFavoriteArtisan(entry)
				and not isDebug
				and updatedAt > 0
				and now - updatedAt <= self.CACHE_MAX_AGE
				and EntryMatchesCustomerFilter(self, entry, filterText)
			then
				local offlineEntry = CopyCustomerEntry(entry)
				offlineEntry.certified = true
				offlineEntry.tradeLead = false
				offlineEntry.offlineCached = true
				offlineEntry.target = offlineEntry.orderTarget or offlineEntry.name
				offlineEntry.professionLink = offlineEntry.professionLink or self:GetRememberedProfessionLink(offlineEntry.orderTarget or offlineEntry.name, offlineEntry.professionID)
				table.insert(candidates, offlineEntry)
			end
		end
		if self.GetCachedTradeLeadFallbackRows then
			for _, entry in ipairs(self:GetCachedTradeLeadFallbackRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
				table.insert(candidates, entry)
			end
		end
		table.sort(candidates, function(a, b)
			local aUpdated = tonumber(a.updatedAt) or 0
			local bUpdated = tonumber(b.updatedAt) or 0
			if aUpdated ~= bUpdated then
				return aUpdated > bUpdated
			end
			return GetSortName(a) < GetSortName(b)
		end)
		local offlineAdded = 0
		for _, entry in ipairs(candidates) do
			if #rows >= offlineTrigger or offlineAdded >= offlineMax then
				break
			end
			local seenKey = GetSeenKey(self, entry)
			if seenKey and not seenNames[seenKey] then
				table.insert(rows, entry)
				MarkSeen(self, seenNames, entry)
				offlineAdded = offlineAdded + 1
			end
		end
	end

	sortMode = sortMode or "best"
	table.sort(rows, function(a, b)
		local aOwnAlt = a.ownAlt and 0 or 1
		local bOwnAlt = b.ownAlt and 0 or 1
		if aOwnAlt ~= bOwnAlt then
			return aOwnAlt < bOwnAlt
		end
		local aFavorite = self:IsFavoriteArtisan(a) and 0 or 1
		local bFavorite = self:IsFavoriteArtisan(b) and 0 or 1
		if aFavorite ~= bFavorite then
			return aFavorite < bFavorite
		end
		if aFavorite == 0 then
			local aUnavailable = a.unavailableFavorite and 1 or 0
			local bUnavailable = b.unavailableFavorite and 1 or 0
			if aUnavailable ~= bUnavailable then
				return aUnavailable < bUnavailable
			end
		end

		local aCertified = GetCertificationSort(a)
		local bCertified = GetCertificationSort(b)
		if aCertified ~= bCertified then
			return aCertified < bCertified
		end
		local aTradeMatch = GetTradeLeadMatchSort(a)
		local bTradeMatch = GetTradeLeadMatchSort(b)
		if aTradeMatch ~= bTradeMatch then
			return aTradeMatch < bTradeMatch
		end
		local aOffline = a.offlineCached and 1 or 0
		local bOffline = b.offlineCached and 1 or 0
		if aOffline ~= bOffline then
			return aOffline < bOffline
		end
		if aOffline == 1 then
			local aUpdated = tonumber(a.updatedAt) or 0
			local bUpdated = tonumber(b.updatedAt) or 0
			if aUpdated ~= bUpdated then
				return aUpdated > bUpdated
			end
		end

		local aCommissionRank, aPrice = GetCommissionSort(a)
		local bCommissionRank, bPrice = GetCommissionSort(b)
		local aQuality = GetSortQuality(a)
		local bQuality = GetSortQuality(b)

		if sortMode == "commission" or sortMode == "price" then
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
		elseif sortMode == "quality" then
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
		else
			if aCommissionRank == 0 or bCommissionRank == 0 then
				if aCommissionRank ~= bCommissionRank then
					return aCommissionRank < bCommissionRank
				end
			end
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
		end
		return GetSortName(a) < GetSortName(b)
	end)
	return rows
end
