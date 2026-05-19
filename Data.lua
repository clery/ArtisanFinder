local _, AF = ...

local MIGRATIONS = {}

local function EnsureProfileContainers(profile)
	profile = profile or {}
	profile.professions = profile.professions or {}
	profile.items = profile.items or {}
	profile.professionPrices = profile.professionPrices or {}
	return profile
end

local function ApplyDBDefaults(db)
	db.artisanProfile = EnsureProfileContainers(db.artisanProfile)
	db.artisanCharacters = db.artisanCharacters or {}
	db.advertising = db.advertising or {}
	db.customerCache = db.customerCache or {}
	db.favoriteArtisans = db.favoriteArtisans or {}
	db.responseThrottle = db.responseThrottle or {}
	db.professionLinks = db.professionLinks or {}
	db.tradeLeads = db.tradeLeads or {}
	db.tradeLeadCache = db.tradeLeadCache or {}
	db.minimap = db.minimap or { angle = 225, hide = false }

	if db.debugSelfResults == nil then
		db.debugSelfResults = false
	end
	if db.defaultSort == nil then
		db.defaultSort = "best"
	end
	if db.cacheCleanupDays == nil then
		db.cacheCleanupDays = 7
	end
	if db.autoAvailability == nil then
		db.autoAvailability = false
	end
	if db.fastScan == nil then
		db.fastScan = false
	end
	if db.tradeLeadMinutes == nil then
		db.tradeLeadMinutes = 15
	end
	if db.offlineFallbackResults == nil then
		db.offlineFallbackResults = 10
	end
	if db.offlineFallbackMax == nil then
		db.offlineFallbackMax = 20
	end
	if db.minimap.angle == nil then
		db.minimap.angle = 225
	end
	if db.minimap.hide == nil then
		db.minimap.hide = false
	end
end

MIGRATIONS[1] = function(db)
	ApplyDBDefaults(db)
end

MIGRATIONS[2] = function(db)
	if db.tradeLeadMinutes == nil then
		db.tradeLeadMinutes = 15
	end
end

MIGRATIONS[3] = function(db)
	db.tradeLeads = db.tradeLeads or {}
end

MIGRATIONS[4] = function(db)
	db.artisanProfile = EnsureProfileContainers(db.artisanProfile)
end

MIGRATIONS[5] = function(db)
	db.tradeLeadCache = db.tradeLeadCache or {}
	if db.offlineFallbackResults == nil then
		db.offlineFallbackResults = 10
	end
	if db.offlineFallbackMax == nil then
		db.offlineFallbackMax = 20
	end
end

MIGRATIONS[6] = function(db)
	db.artisanCharacters = db.artisanCharacters or {}
	db.advertising = db.advertising or {}
end

MIGRATIONS[7] = function(db)
	if db.fastScan == nil then
		db.fastScan = false
	end
end

MIGRATIONS[8] = function(db)
	db.professionLinks = db.professionLinks or {}
end

function AF:MigrateDB(db)
	local version = tonumber(db.schemaVersion) or 0
	while version < self.SCHEMA_VERSION do
		local nextVersion = version + 1
		local migration = MIGRATIONS[nextVersion]
		if migration then
			migration(db)
		end
		db.schemaVersion = nextVersion
		version = nextVersion
	end
end

function AF:EnsureDB()
	ArtisanFinderDB = ArtisanFinderDB or {}
	local db = ArtisanFinderDB
	self:MigrateDB(db)

	ApplyDBDefaults(db)
	db.schemaVersion = self.SCHEMA_VERSION

	self.db = db
	self.available = false
	return db
end

function AF:CleanupCustomerCache()
	if not self.db or not self.db.customerCache then
		return 0
	end
	local days = tonumber(self.db.cacheCleanupDays) or 7
	if days <= 0 then
		return 0
	end
	local cutoff = self:Now() - (days * 24 * 60 * 60)
	local removed = 0
	for itemKey, itemCache in pairs(self.db.customerCache) do
		if type(itemCache) == "table" then
			for cacheKey, entry in pairs(itemCache) do
				local updatedAt = tonumber(entry and entry.updatedAt) or 0
				if (updatedAt <= 0 or updatedAt < cutoff) and not self:IsFavoriteArtisan(entry) then
					itemCache[cacheKey] = nil
					removed = removed + 1
				end
			end
			if next(itemCache) == nil then
				self.db.customerCache[itemKey] = nil
			end
		end
	end
	for leadKey, entry in pairs(self.db.tradeLeadCache or {}) do
		local updatedAt = tonumber(entry and entry.updatedAt) or 0
		if updatedAt <= 0 or updatedAt < cutoff then
			self.db.tradeLeadCache[leadKey] = nil
			removed = removed + 1
		end
	end
	if removed > 0 then
		self:Print(self:Text("CACHE_CLEANUP_DONE", removed, days))
	end
	return removed
end

function AF:GetPlayerFullName()
	local name, realm = UnitFullName("player")
	realm = realm or GetRealmName()
	realm = realm and realm:gsub("%s+", "") or ""
	if realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

function AF:NormalizeArtisanProfile(profile, characterName)
	profile = profile or {}
	profile.characterName = characterName or profile.characterName
	profile.professions = profile.professions or {}
	profile.items = profile.items or {}
	profile.professionPrices = profile.professionPrices or {}
	return profile
end

function AF:IsArtisanProfileEmpty(profile)
	if type(profile) ~= "table" then
		return true
	end
	return next(profile.professions or {}) == nil
		and next(profile.items or {}) == nil
		and next(profile.professionPrices or {}) == nil
end

function AF:SelectActiveArtisanProfile(characterName)
	if not self.db then
		return nil
	end
	characterName = self:NormalizeName(characterName or self.playerName or self:GetPlayerFullName())
	if not characterName then
		return nil
	end

	self.db.artisanCharacters = self.db.artisanCharacters or {}
	self.db.advertising = self.db.advertising or {}

	if not self.db.legacyArtisanProfileMigrated then
		local legacyProfile = self.db.artisanProfile
		if not self:IsArtisanProfileEmpty(legacyProfile) and not self.db.artisanCharacters[characterName] then
			self.db.artisanCharacters[characterName] = legacyProfile
		end
		self.db.legacyArtisanProfileMigrated = true
	end

	local profile = self:NormalizeArtisanProfile(self.db.artisanCharacters[characterName], characterName)
	self.db.artisanCharacters[characterName] = profile
	self.db.artisanProfile = profile
	self.activeArtisanCharacter = characterName
	return profile
end

function AF:GetActiveArtisanProfile()
	if not self.db then
		return nil
	end
	if not self.db.artisanProfile or not self.db.artisanProfile.items then
		return self:SelectActiveArtisanProfile(self.playerName or self:GetPlayerFullName())
	end
	return self.db.artisanProfile
end

function AF:ForEachArtisanProfile(callback)
	if not self.db or type(callback) ~= "function" then
		return
	end
	self.db.artisanCharacters = self.db.artisanCharacters or {}
	for characterName, profile in pairs(self.db.artisanCharacters) do
		if type(profile) == "table" then
			callback(self:NormalizeName(characterName) or characterName, self:NormalizeArtisanProfile(profile, characterName))
		end
	end
end

function AF:IsProfessionAdvertised(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	professionID = tostring(professionID or "")
	if not characterName or professionID == "" then
		return false
	end
	local characterSettings = self.db and self.db.advertising and self.db.advertising[characterName]
	return not (characterSettings and characterSettings[professionID] == false)
end

function AF:SetProfessionAdvertised(characterName, professionID, enabled)
	characterName = self:NormalizeName(characterName)
	professionID = tostring(professionID or "")
	if not characterName or professionID == "" or not self.db then
		return
	end
	self.db.advertising = self.db.advertising or {}
	self.db.advertising[characterName] = self.db.advertising[characterName] or {}
	if enabled == false then
		self.db.advertising[characterName][professionID] = false
	else
		self.db.advertising[characterName][professionID] = nil
	end
	if next(self.db.advertising[characterName]) == nil then
		self.db.advertising[characterName] = nil
	end
	if self.RefreshMinimap then
		self:RefreshMinimap()
	end
	if self.RefreshCrafterUI then
		self:RefreshCrafterUI()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:GetProfessionLinkKey(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	professionID = tonumber(professionID)
	if not characterName or not professionID then
		return nil
	end
	return characterName .. ":" .. tostring(professionID)
end

function AF:RememberProfessionLink(characterName, professionID, professionLink)
	local key = self:GetProfessionLinkKey(characterName, professionID)
	if not key or type(professionLink) ~= "string" or professionLink == "" or not self.db then
		return
	end
	self.db.professionLinks = self.db.professionLinks or {}
	self.db.professionLinks[key] = professionLink
end

function AF:StoreProfessionLink(characterName, professionID, professionLink, professionName)
	if type(professionLink) ~= "string" or professionLink == "" or not self.db then
		return nil
	end

	characterName = self:NormalizeName(characterName or self.activeArtisanCharacter or self.playerName or self:GetPlayerFullName())
	professionID = tonumber(professionID)
	if not characterName or not professionID then
		return nil
	end
	local activeCharacter = self:NormalizeName(self.activeArtisanCharacter or self.playerName or self:GetPlayerFullName())
	if characterName == activeCharacter and self.IsOwnProfessionWindowOpen and not self:IsOwnProfessionWindowOpen() then
		return nil
	end

	self:RememberProfessionLink(characterName, professionID, professionLink)
	self.db.artisanCharacters = self.db.artisanCharacters or {}
	local profile = self.db.artisanCharacters[characterName]
	if not profile and characterName == activeCharacter then
		profile = self:GetActiveArtisanProfile()
	end
	if not profile then
		return professionLink
	end

	profile = self:NormalizeArtisanProfile(profile, characterName)
	self.db.artisanCharacters[characterName] = profile
	if characterName == activeCharacter then
		self.db.artisanProfile = profile
	end

	local professionKey = tostring(professionID)
	local profession = profile.professions[professionKey] or {
		id = professionID,
		name = professionName or self:GetProfessionName(professionID, profile),
		recipes = {},
	}
	profile.professions[professionKey] = profession
	profession.id = professionID
	profession.name = professionName or profession.name
	profession.professionLink = professionLink

	for _, item in pairs(profile.items or {}) do
		if tonumber(item.professionID) == professionID then
			item.professionLink = professionLink
		end
	end

	return professionLink
end

function AF:GetRememberedProfessionLink(characterName, professionID)
	local key = self:GetProfessionLinkKey(characterName, professionID)
	return key and self.db and self.db.professionLinks and self.db.professionLinks[key] or nil
end

function AF:NormalizeName(name)
	if not name or name == "" then
		return nil
	end
	name = name:gsub("%s+", "")
	if not name:find("-", 1, true) then
		local realm = GetRealmName()
		if realm and realm ~= "" then
			name = name .. "-" .. realm:gsub("%s+", "")
		end
	end
	return name
end

function AF:GetDisplayPlayerName(name)
	name = tostring(name or "")
	local playerName, realm = name:match("^([^-]+)-(.+)$")
	if not playerName or not realm then
		return name
	end

	local currentRealm = GetRealmName()
	currentRealm = currentRealm and currentRealm:gsub("%s+", "") or ""
	if realm == currentRealm then
		return playerName
	end
	return name
end

function AF:GetFavoriteArtisanKey(entryOrName)
	local name = type(entryOrName) == "table" and (entryOrName.orderTarget or entryOrName.name or entryOrName.target) or entryOrName
	return self:NormalizeName(name)
end

function AF:IsFavoriteArtisan(entryOrName)
	local key = self:GetFavoriteArtisanKey(entryOrName)
	return key and self.db and self.db.favoriteArtisans and self.db.favoriteArtisans[key] == true
end

function AF:SetFavoriteArtisan(entryOrName, favorite)
	local key = self:GetFavoriteArtisanKey(entryOrName)
	if not key then
		return
	end
	self.db.favoriteArtisans[key] = favorite == true or nil
end

function AF:ToggleFavoriteArtisan(entryOrName)
	local favorite = not self:IsFavoriteArtisan(entryOrName)
	self:SetFavoriteArtisan(entryOrName, favorite)
	return favorite
end

function AF:TableCount(tbl)
	local count = 0
	for _ in pairs(tbl or {}) do
		count = count + 1
	end
	return count
end

function AF:GetProfessionScannedCount(profile, professionID)
	if not profile or not professionID then
		return 0
	end
	local count = 0
	for _, item in pairs(profile.items or {}) do
		if tonumber(item.professionID) == tonumber(professionID) then
			count = count + 1
		end
	end
	return count
end

function AF:HasScannedProfession(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	professionID = tonumber(professionID)
	if not characterName or not professionID or not self.db or not self.db.artisanCharacters then
		return false
	end
	local profile = self.db.artisanCharacters[characterName]
	return self:GetProfessionScannedCount(profile, professionID) > 0
end

function AF:GetScannedProfessionRows()
	local rows = {}
	self:ForEachArtisanProfile(function(characterName, profile)
		local added = {}
		for professionKey, profession in pairs(profile.professions or {}) do
			local professionID = tonumber(profession.id) or tonumber(professionKey)
			local count = self:GetProfessionScannedCount(profile, professionID)
			if professionID and count > 0 then
				added[professionID] = true
				table.insert(rows, {
					characterName = characterName,
					professionID = professionID,
					professionName = profession.name or self:GetProfessionName(professionID, profile),
					count = count,
					advertised = self:IsProfessionAdvertised(characterName, professionID),
				})
			end
		end
		for _, item in pairs(profile.items or {}) do
			local professionID = tonumber(item.professionID)
			if professionID and not added[professionID] then
				added[professionID] = true
				table.insert(rows, {
					characterName = characterName,
					professionID = professionID,
					professionName = item.professionName or self:GetProfessionName(professionID, profile),
					count = self:GetProfessionScannedCount(profile, professionID),
					advertised = self:IsProfessionAdvertised(characterName, professionID),
				})
			end
		end
	end)
	table.sort(rows, function(a, b)
		local aCharacter = tostring(a.characterName or "")
		local bCharacter = tostring(b.characterName or "")
		if aCharacter ~= bCharacter then
			return aCharacter < bCharacter
		end
		return tostring(a.professionName or "") < tostring(b.professionName or "")
	end)
	return rows
end

function AF:GetProfessionName(professionID, profile)
	profile = profile or (self.db and self.db.artisanProfile)
	local info = profile and profile.professions and profile.professions[tostring(professionID or "")]
	return info and info.name or self:Text("PROFESSION_FALLBACK", tostring(professionID or "?"))
end

function AF:GetItemPriceForProfile(profile, itemID, professionID)
	profile = self:NormalizeArtisanProfile(profile)
	local item = profile.items[tostring(itemID or "")]
	local professionPrice = profile.professionPrices[tostring(professionID or "")]
	local priceCopper, freeCommission = self:GetEntryCommission(item)
	local note = self:GetEntryNote(item)
	if not priceCopper then
		priceCopper, freeCommission = self:GetEntryCommission(professionPrice)
	end
	if not note then
		note = self:GetEntryNote(professionPrice)
	end
	return tonumber(priceCopper) or 0, freeCommission == true, note or ""
end

function AF:GetItemPrice(itemID, professionID)
	return self:GetItemPriceForProfile(self:GetActiveArtisanProfile(), itemID, professionID)
end

function AF:SetItemPrice(itemID, priceCopper, freeCommission, note, commissionState)
	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	self:SetCommissionFields(item, priceCopper, freeCommission, commissionState)
	item.note = note or ""
	item.updatedAt = self:Now()
end

function AF:SetProfessionPrice(professionID, priceCopper, freeCommission, note, commissionState)
	local entry = self.db.artisanProfile.professionPrices[tostring(professionID or "")] or {}
	self.db.artisanProfile.professionPrices[tostring(professionID or "")] = entry
	self:SetCommissionFields(entry, priceCopper, freeCommission, commissionState)
	entry.note = note or ""
	entry.updatedAt = self:Now()
end
