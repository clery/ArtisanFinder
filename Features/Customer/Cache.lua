local _, AF = ...

local CopyTable = AF.CopyTable

local function GetSortQuality(entry)
	if entry and entry.rescanNeeded and not entry.legacyFallback then
		return 0
	end
	return tonumber(entry and entry.bestQuality)
		or tonumber(entry and entry.quality)
		or 0
end

local function GetTradeLeadMatchSort(entry)
	if not entry or not entry.tradeLead then
		return 0
	end
	return entry.tradeProfessionMatch and 0 or 1
end

local function IsAddonEnabledEntry(entry)
	return entry and not entry.tradeLead
end

local function GetSourceCategorySort(_, entry)
	if IsAddonEnabledEntry(entry) then
		return entry.guildMember and 0 or 1
	end
	if entry and entry.guildMember then
		return 2
	end
	return 3
end

local function GetAvailabilitySort(AF, entry)
	if not entry then
		return 3
	end
	if entry.ownAlt then
		return 0
	end
	if entry.unavailableCached then
		return 1
	end
	if entry.unavailableFavorite then
		return 2
	end
	if AF:IsCustomerEntryOnline(entry) then
		return 0
	end
	if AF:IsCustomerEntryOffline(entry) or entry.offlineCached then
		return 2
	end
	return 1
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
	return tostring(entry and (entry.displayName or entry.name) or ""):lower()
end

local function GetSeenKey(AF, entry)
	if not entry then
		return nil
	end
	if entry.tradeLead and entry.professionLink then
		return "trade:" .. tostring(entry.target or entry.name or "") .. ":" .. tostring(entry.professionLink)
	end
	if not entry.tradeLead then
		return AF:GetFavoriteArtisanKey(entry) or entry.orderTarget or entry.name or entry.target
	end
	return entry.target or entry.name
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
	if entry and not entry.tradeLead then
		if entry.orderTarget then
			seenNames[entry.orderTarget] = true
		end
		if entry.name then
			seenNames[entry.name] = true
		end
		return
	end
	if entry then
		if entry.name then
			seenNames[entry.name] = true
		end
		if entry.target then
			seenNames[entry.target] = true
		end
	end
end

local function EntryMatchesCustomerFilter(AF, entry, filterText)
	if filterText == "" then
		return true
	end
	local haystack = table.concat({
		entry.displayName or "",
		entry.name or "",
		entry.professionName or "",
		entry.note or "",
		AF:FormatMoney(entry.priceCopper, entry.freeCommission),
		AF:FormatCapability(entry),
	}, " "):lower()
	return haystack:find(filterText, 1, true)
end

local function EntryMatchesCustomerContext(AF, entry, itemID, professionID, recipeID)
	if not entry then
		return false
	end
	if tonumber(entry.itemID) ~= tonumber(itemID) then
		return false
	end
	professionID = tonumber(professionID) or 0
	if professionID ~= 0 and AF:GetBaseProfessionID(entry.professionID) ~= AF:GetBaseProfessionID(professionID) then
		return false
	end
	recipeID = tonumber(recipeID) or 0
	if recipeID ~= 0 and entry.recipeID and tonumber(entry.recipeID) ~= recipeID then
		return false
	end
	return true
end

function AF:CustomerEntryMatchesFilter(entry, filterText)
	return EntryMatchesCustomerFilter(self, entry, filterText)
end

local FAVORITE_CACHE_ROW_OPTIONS = { unavailableFavorite = true, useOrderTarget = true }
local OFFLINE_CACHE_ROW_OPTIONS = { offlineCached = true, offlineFallback = true, useOrderTarget = true }

local function PrepareCachedCustomerEntry(AF, entry, options)
	local copy = CopyTable(entry)
	if not AF:IsCurrentScanModelEntry(copy) and AF.MarkScanModelRescanNeeded then
		AF:MarkScanModelRescanNeeded(copy)
	end
	copy.certified = true
	copy.tradeLead = false
	copy.unavailableFavorite = options and options.unavailableFavorite or nil
	copy.offlineCached = options and options.offlineCached or nil
	copy.offlineFallback = options and options.offlineFallback or nil
	if options and options.useOrderTarget then
		copy.target = copy.orderTarget or copy.name
	end
	copy.professionLink = copy.professionLink or AF:GetRememberedProfessionLink(copy.orderTarget or copy.name, copy.professionID)
	return copy
end

local function ClearGuildAffiliation(entry)
	entry.guildMember = nil
	entry.guildOnline = nil
	entry.guildMemberGUID = nil
	entry.guildRecipeKnown = nil
	entry.guildKey = nil
	return entry
end

local function MarkGuildAffiliation(AF, entry)
	if not entry then
		return entry
	end
	if entry.debug then
		return ClearGuildAffiliation(entry)
	end

	local rosterEntry = AF:GetCachedGuildRosterEntry(entry.orderTarget or entry.name or entry.target)
	if rosterEntry then
		entry.guildMember = true
		entry.guildOnline = rosterEntry.online
		entry.guildMemberGUID = rosterEntry.guid
		entry.guildKey = AF.GetCurrentGuildCacheKey and AF:GetCurrentGuildCacheKey() or entry.guildKey
		return entry
	end

	return ClearGuildAffiliation(entry)
end

local function AddCachedAddonGuildMemberRows(AF, rows, itemCache, itemID, professionID, recipeID, filterText, seenNames)
	local now = AF:Now()
	for _, entry in pairs(itemCache or {}) do
		local updatedAt = tonumber(entry and entry.updatedAt) or 0
		local seenKey = GetSeenKey(AF, entry)
		if entry
			and seenKey
			and not seenNames[seenKey]
			and entry.tradeLead ~= true
			and not entry.debug
			and updatedAt > 0
			and now - updatedAt <= AF.CACHE_MAX_AGE
			and EntryMatchesCustomerContext(AF, entry, itemID, professionID, recipeID)
			and EntryMatchesCustomerFilter(AF, entry, filterText)
		then
			local rosterEntry = AF:GetCachedGuildRosterEntry(entry.orderTarget or entry.name or entry.target)
			if rosterEntry then
				local rowEntry = PrepareCachedCustomerEntry(AF, entry)
				MarkGuildAffiliation(AF, rowEntry)
				rowEntry.unavailableCached = true
				rowEntry.availabilityState = "unavailable"
				rowEntry.customerSource = "cached-addon-guild"
				if AF:IsCustomerEntryOrderEligible(rowEntry) then
					table.insert(rows, rowEntry)
					MarkSeen(AF, seenNames, rowEntry)
				end
			end
		end
	end
end

local function PrepareOwnAltOrderEligibility(AF, entry)
	if not entry or not entry.ownAlt then
		return true
	end
	if entry.importedAlt == true then
		return true
	end
	if AF:IsNameOnConnectedRealm(entry.orderTarget or entry.name or entry.target) then
		MarkGuildAffiliation(AF, entry)
		return true
	end

	MarkGuildAffiliation(AF, entry)
	return entry.guildMember == true
end

function AF:IsCustomerEntryOrderEligible(entry)
	if not entry then
		return false
	end
	if entry.guildMember then
		MarkGuildAffiliation(self, entry)
		if entry.guildMember then
			return true
		end
	end
	if entry.ownAlt then
		return PrepareOwnAltOrderEligibility(self, entry)
	end
	if self:IsNameOnConnectedRealm(entry.orderTarget or entry.name or entry.target) then
		return true
	end

	MarkGuildAffiliation(self, entry)
	return entry.guildMember == true
end

function AF:GetOwnAltRows(itemID, professionID, filterText, seenNames, recipeID)
	local rows = {}
	local currentName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	local itemKey = tostring(itemID or "")
	professionID = tonumber(professionID) or 0
	recipeID = tonumber(recipeID) or 0

	self:ForEachArtisanProfile(function(characterName, profile)
		characterName = self:NormalizeName(characterName)
		if not characterName then
			return
		end
		local isCurrentCharacter = characterName == currentName
		if isCurrentCharacter and not (self.db and self.db.showOwnCharacterRows == true) then
			return
		end
		if isCurrentCharacter and not self:IsAvailable() then
			return
		end
		local item = profile.items and profile.items[itemKey]
		if not item then
			return
		end
		if profile.importedAlt == true then
			local itemCache = self.db and self.db.customerCache and self.db.customerCache[itemKey]
			local cachedEntry = itemCache and itemCache[characterName]
			if cachedEntry and self.ApplyCustomerCacheEntryToImportedArtisan and self:ApplyCustomerCacheEntryToImportedArtisan(characterName, cachedEntry) then
				itemCache[characterName] = nil
				if next(itemCache) == nil then
					self.db.customerCache[itemKey] = nil
				end
				item = profile.items and profile.items[itemKey] or item
			end
		end
		if professionID ~= 0 and self:GetBaseProfessionID(item.professionID) ~= self:GetBaseProfessionID(professionID) then
			return
		end
		if not self:IsProfessionAdvertised(characterName, item.professionID) then
			return
		end
		if recipeID ~= 0
			and item.recipeID
			and tonumber(item.recipeID) ~= recipeID
			and self:GetBaseProfessionID(item.professionID) ~= self:GetBaseProfessionID(professionID)
		then
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
			professionName = self:GetProfessionName(item.professionID, profile),
			priceCopper = priceCopper,
			freeCommission = freeCommission,
			note = note,
			recipeID = item.recipeID,
			recipeDifficulty = item.recipeDifficulty,
			totalSkill = item.totalSkill,
			quality = item.quality,
			rawQuality = item.rawQuality,
			concentrationQuality = item.concentrationQuality,
			concentrationCost = item.concentrationCost,
			outputItemLevel = item.outputItemLevel,
			bestQuality = item.bestQuality,
			rawBestQuality = item.rawBestQuality,
			bestConcentrationQuality = item.bestConcentrationQuality,
			bestTotalSkill = item.bestTotalSkill,
			bestConcentrationCost = item.bestConcentrationCost,
			bestOutputItemLevel = item.bestOutputItemLevel,
			bestReagents = item.bestReagents,
			bestReagentSummaryUpdatedAt = item.bestReagentSummaryUpdatedAt,
			bestReagentTruncated = item.bestReagentTruncated,
			bestReagentPendingNames = item.bestReagentPendingNames,
			scanModelVersion = item.scanModelVersion,
			reagentSkillFacts = item.reagentSkillFacts,
			wireReagentSkillFacts = item.wireReagentSkillFacts,
			maxOutputQuality = item.maxOutputQuality,
			compactOptionalReagentDeltas = item.compactOptionalReagentDeltas,
			optionalDifficultyDelta = item.optionalDifficultyDelta,
			optionalQuality = item.optionalQuality,
			optionalOutputItemLevel = item.optionalOutputItemLevel,
			optionalOutputItemLevelDelta = item.optionalOutputItemLevelDelta,
			optionalConcentrationQuality = item.optionalConcentrationQuality,
			optionalReagents = item.optionalReagents,
			optionalSlotCount = item.optionalSlotCount,
			optionalBestReagents = item.optionalBestReagents,
			optionalBestReagentSummaryUpdatedAt = item.optionalBestReagentSummaryUpdatedAt,
			optionalBestReagentTruncated = item.optionalBestReagentTruncated,
			professionLink = professionLink,
			updatedAt = item.updatedAt or profile.updatedAt or self:Now(),
			verifiedAt = self:Now(),
			certified = true,
			tradeLead = false,
			ownAlt = true,
			importedAlt = profile.importedAlt == true or nil,
			ownSelf = isCurrentCharacter,
		}
		if not self:IsCurrentScanModelEntry(entry) and self.MarkScanModelRescanNeeded then
			self:MarkScanModelRescanNeeded(entry)
		end
		if EntryMatchesCustomerFilter(self, entry, filterText) then
			local seenKey = GetSeenKey(self, entry)
			if seenKey and not seenNames[seenKey] and self:IsCustomerEntryOrderEligible(entry) then
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
		if verifiedForQuery and not (entry.debug and not self:IsDevFakeRowsEnabled()) and entry.updatedAt and now - entry.updatedAt <= self.CACHE_MAX_AGE then
			if EntryMatchesCustomerFilter(self, entry, filterText) then
				local rowEntry = PrepareCachedCustomerEntry(self, entry)
				if self:IsCustomerEntryOrderEligible(rowEntry) then
					table.insert(rows, rowEntry)
					MarkSeen(self, seenNames, rowEntry)
				end
			end
		end
	end

	for _, entry in pairs(itemCache or {}) do
		local favoriteKey = self:GetFavoriteArtisanKey(entry)
		if favoriteKey and not (entry.debug and not self:IsDevFakeRowsEnabled()) and not seenNames[favoriteKey] and self:IsFavoriteArtisan(entry) and EntryMatchesCustomerFilter(self, entry, filterText) then
			local favoriteEntry = PrepareCachedCustomerEntry(self, entry, FAVORITE_CACHE_ROW_OPTIONS)
			if self:IsCustomerEntryOrderEligible(favoriteEntry) then
				table.insert(rows, favoriteEntry)
				MarkSeen(self, seenNames, favoriteEntry)
			end
		end
	end
	local showUncertifiedPeople = self.db.showUncertifiedPeople ~= false
	local includeGuildRows = showUncertifiedPeople and not self:IsDevFakeRowsEnabled()
	AddCachedAddonGuildMemberRows(self, rows, itemCache, itemID, self.currentCustomerProfessionID, self.currentCustomerRecipeID, filterText, seenNames)
	if includeGuildRows and self.GetGuildProfessionRows then
		for _, entry in ipairs(self:GetGuildProfessionRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
			table.insert(rows, entry)
			MarkSeen(self, seenNames, entry)
		end
	end
	if showUncertifiedPeople and self.GetTradeLeadRows then
		for _, entry in ipairs(self:GetTradeLeadRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
			if self:IsCustomerEntryOrderEligible(entry) then
				table.insert(rows, entry)
				MarkSeen(self, seenNames, entry)
			end
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
				local offlineEntry = PrepareCachedCustomerEntry(self, entry, OFFLINE_CACHE_ROW_OPTIONS)
				if self:IsCustomerEntryOrderEligible(offlineEntry) then
					table.insert(candidates, offlineEntry)
				end
			end
		end
		if showUncertifiedPeople and self.GetCachedTradeLeadFallbackRows then
			for _, entry in ipairs(self:GetCachedTradeLeadFallbackRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
				if self:IsCustomerEntryOrderEligible(entry) then
					table.insert(candidates, entry)
				end
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
			if offlineAdded >= offlineMax then
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
		local aFavorite = self:IsFavoriteArtisan(a)
		local bFavorite = self:IsFavoriteArtisan(b)
		if aFavorite ~= bFavorite then
			return aFavorite
		end

		local aOwnAlt = a and a.ownAlt == true
		local bOwnAlt = b and b.ownAlt == true
		if aOwnAlt ~= bOwnAlt then
			return aOwnAlt
		end

		local aCategory = GetSourceCategorySort(self, a)
		local bCategory = GetSourceCategorySort(self, b)
		if aCategory ~= bCategory then
			return aCategory < bCategory
		end

		local aAvailability = GetAvailabilitySort(self, a)
		local bAvailability = GetAvailabilitySort(self, b)
		if aAvailability ~= bAvailability then
			return aAvailability < bAvailability
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
		local aTradeMatch = GetTradeLeadMatchSort(a)
		local bTradeMatch = GetTradeLeadMatchSort(b)
		if aTradeMatch ~= bTradeMatch then
			return aTradeMatch < bTradeMatch
		end
		local aUpdated = tonumber(a.updatedAt) or 0
		local bUpdated = tonumber(b.updatedAt) or 0
		if aUpdated ~= bUpdated then
			return aUpdated > bUpdated
		end
		return GetSortName(a) < GetSortName(b)
	end)
	return rows
end
