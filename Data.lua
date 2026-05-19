local _, AF = ...

local MIGRATIONS = {}
local DEFAULT_OFF_ADVERTISING_PROFESSIONS = {
	[182] = true, -- Herbalism
	[185] = true, -- Cooking
	[186] = true, -- Mining
	[356] = true, -- Fishing
	[393] = true, -- Skinning
}
local PROFESSION_ID_ALIASES = {
	[5] = 185, -- Midnight Cooking
	[6] = 186, -- Midnight Mining
	[10] = 356, -- Midnight Fishing
	[12] = 755, -- Midnight Jewelcrafting
}
local DEFAULT_OFF_ADVERTISING_NAMES = {
	["cooking"] = true,
	["fishing"] = true,
	["herbalism"] = true,
	["mining"] = true,
	["skinning"] = true,
}
local BASE_PROFESSION_SPELLS = {
	[164] = 2018, -- Blacksmithing
	[165] = 2108, -- Leatherworking
	[171] = 2259, -- Alchemy
	[182] = 2366, -- Herbalism
	[185] = 2550, -- Cooking
	[186] = 2575, -- Mining
	[197] = 3908, -- Tailoring
	[202] = 4036, -- Engineering
	[333] = 7411, -- Enchanting
	[356] = 7620, -- Fishing
	[393] = 8613, -- Skinning
	[755] = 25229, -- Jewelcrafting
	[773] = 45357, -- Inscription
}
local BASE_PROFESSION_NAMES = {
	[164] = "Blacksmithing",
	[165] = "Leatherworking",
	[171] = "Alchemy",
	[182] = "Herbalism",
	[185] = "Cooking",
	[186] = "Mining",
	[197] = "Tailoring",
	[202] = "Engineering",
	[333] = "Enchanting",
	[356] = "Fishing",
	[393] = "Skinning",
	[755] = "Jewelcrafting",
	[773] = "Inscription",
}

local function GetBaseProfessionID(professionID)
	professionID = tonumber(professionID)
	return PROFESSION_ID_ALIASES[professionID] or professionID
end

function AF:GetBaseProfessionID(professionID)
	return GetBaseProfessionID(professionID)
end

local function GetBaseProfessionIDFromName(professionName)
	professionName = tostring(professionName or ""):lower()
	for professionID, professionNamePattern in pairs(BASE_PROFESSION_NAMES) do
		if professionName:find(professionNamePattern:lower(), 1, true) then
			return professionID
		end
	end
	return nil
end

local function EnsureProfileContainers(profile)
	profile = profile or {}
	profile.professions = profile.professions or {}
	profile.items = profile.items or {}
	profile.professionPrices = profile.professionPrices or {}
	return profile
end

local function InvalidateScannedProfileData(profile)
	if type(profile) ~= "table" then
		return
	end
	profile.professions = {}
	profile.items = {}
end

local function InvalidateScannedData(db)
	InvalidateScannedProfileData(db.artisanProfile)
	for _, profile in pairs(db.artisanCharacters or {}) do
		InvalidateScannedProfileData(profile)
	end
	db.professionLinks = {}
end

local function GetMigrationProfessionID(professionKey, profession)
	return GetBaseProfessionID(profession and (profession.parentProfessionID or profession.baseProfessionID))
		or GetBaseProfessionIDFromName(profession and profession.name)
		or GetBaseProfessionID(profession and profession.id)
		or GetBaseProfessionID(professionKey)
end

local function PreserveEffectiveAdvertising(db)
	db.advertising = db.advertising or {}
	db.advertisingKnown = db.advertisingKnown or {}
	local function preserveProfile(characterName, profile)
		if type(profile) ~= "table" then
			return
		end
		characterName = tostring(characterName or profile.characterName or "")
		if characterName == "" then
			return
		end
		local characterSettings = db.advertising[characterName]
		local knownSettings = db.advertisingKnown[characterName]
		for professionKey, profession in pairs(profile.professions or {}) do
			local baseProfessionID = GetMigrationProfessionID(professionKey, profession)
			if baseProfessionID then
				local baseProfessionKey = tostring(baseProfessionID)
				characterSettings = characterSettings or {}
				knownSettings = knownSettings or {}
				local oldValue = characterSettings[tostring(professionKey)]
				if oldValue == nil then
					oldValue = characterSettings[baseProfessionKey]
				end
				characterSettings[baseProfessionKey] = oldValue ~= false
				knownSettings[baseProfessionKey] = true
				if tostring(professionKey) ~= baseProfessionKey then
					characterSettings[tostring(professionKey)] = nil
					knownSettings[tostring(professionKey)] = nil
				end
			end
		end
		if characterSettings and next(characterSettings) ~= nil then
			db.advertising[characterName] = characterSettings
		end
		if knownSettings and next(knownSettings) ~= nil then
			db.advertisingKnown[characterName] = knownSettings
		end
	end
	for characterName, profile in pairs(db.artisanCharacters or {}) do
		preserveProfile(characterName, profile)
	end
	if type(db.artisanProfile) == "table" then
		preserveProfile(db.artisanProfile.characterName, db.artisanProfile)
	end
end

local function NormalizeProfessionKeyedSettings(db)
	for _, characterSettings in pairs(db.advertising or {}) do
		if type(characterSettings) == "table" then
			for professionKey, value in pairs(characterSettings) do
				local baseProfessionID = GetBaseProfessionID(professionKey)
				local baseProfessionKey = baseProfessionID and tostring(baseProfessionID) or nil
				if baseProfessionKey and baseProfessionKey ~= professionKey then
					if characterSettings[baseProfessionKey] == nil then
						characterSettings[baseProfessionKey] = value
					end
					characterSettings[professionKey] = nil
				end
			end
		end
	end

	local function normalizeProfilePrices(profile)
		local professionPrices = type(profile) == "table" and profile.professionPrices or nil
		if type(professionPrices) ~= "table" then
			return
		end
		for professionKey, value in pairs(professionPrices) do
			local baseProfessionID = GetBaseProfessionID(professionKey)
			local baseProfessionKey = baseProfessionID and tostring(baseProfessionID) or nil
			if baseProfessionKey and baseProfessionKey ~= professionKey then
				if professionPrices[baseProfessionKey] == nil then
					professionPrices[baseProfessionKey] = value
				end
				professionPrices[professionKey] = nil
			end
		end
	end

	normalizeProfilePrices(db.artisanProfile)
	for _, profile in pairs(db.artisanCharacters or {}) do
		normalizeProfilePrices(profile)
	end
end

local function ApplyDBDefaults(db)
	db.artisanProfile = EnsureProfileContainers(db.artisanProfile)
	db.artisanCharacters = db.artisanCharacters or {}
	db.advertising = db.advertising or {}
	db.advertisingKnown = db.advertisingKnown or {}
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
	db.advertisingKnown = db.advertisingKnown or {}
end

MIGRATIONS[7] = function(db)
	if db.fastScan == nil then
		db.fastScan = false
	end
end

MIGRATIONS[8] = function(db)
	db.professionLinks = db.professionLinks or {}
end

MIGRATIONS[9] = function(db)
	ApplyDBDefaults(db)
	PreserveEffectiveAdvertising(db)
	NormalizeProfessionKeyedSettings(db)
	InvalidateScannedData(db)
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

function AF:IsProfessionAdvertisedByDefault(professionID)
	professionID = GetBaseProfessionID(professionID)
	if not professionID then
		return false
	end
	return DEFAULT_OFF_ADVERTISING_PROFESSIONS[professionID] ~= true
end

function AF:GetProfessionDefaultAdvertisingID(professionID, profileOrRow)
	professionID = GetBaseProfessionID(professionID)
	if type(profileOrRow) == "table" then
		local parentProfessionID = GetBaseProfessionID(profileOrRow.parentProfessionID or profileOrRow.baseProfessionID)
		if parentProfessionID then
			return parentProfessionID
		end
		local namedProfessionID = GetBaseProfessionIDFromName(profileOrRow.name or profileOrRow.professionName)
		if namedProfessionID then
			return namedProfessionID
		end
		if profileOrRow.professions and professionID then
			local profession = profileOrRow.professions[tostring(professionID)]
			parentProfessionID = GetBaseProfessionID(profession and profession.parentProfessionID)
			if parentProfessionID then
				return parentProfessionID
			end
		end
	end
	return professionID
end

function AF:IsProfessionDefaultOffByName(professionName)
	professionName = tostring(professionName or ""):lower()
	for name in pairs(DEFAULT_OFF_ADVERTISING_NAMES) do
		if professionName:find(name, 1, true) then
			return true
		end
	end
	return false
end

function AF:IsProfessionAdvertised(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	professionID = tostring(professionID or "")
	if not characterName or professionID == "" then
		return false
	end
	local characterSettings = self.db and self.db.advertising and self.db.advertising[characterName]
	local setting = characterSettings and characterSettings[professionID]
	if setting ~= nil then
		return setting == true
	end
	local profile = self.db and self.db.artisanCharacters and self.db.artisanCharacters[characterName]
	local profession = profile and profile.professions and profile.professions[professionID]
	local defaultID = self:GetProfessionDefaultAdvertisingID(professionID, profession)
	if self:IsProfessionDefaultOffByName(profession and profession.name) then
		return false
	end
	return self:IsProfessionAdvertisedByDefault(defaultID)
end

function AF:SetProfessionAdvertised(characterName, professionID, enabled)
	characterName = self:NormalizeName(characterName)
	local professionKey = tostring(professionID or "")
	if not characterName or professionKey == "" or not self.db then
		return
	end
	self.db.advertising = self.db.advertising or {}
	self.db.advertisingKnown = self.db.advertisingKnown or {}
	self.db.advertisingKnown[characterName] = self.db.advertisingKnown[characterName] or {}
	self.db.advertisingKnown[characterName][professionKey] = true
	self.db.advertising[characterName] = self.db.advertising[characterName] or {}
	local profile = self.db and self.db.artisanCharacters and self.db.artisanCharacters[characterName]
	local profession = profile and profile.professions and profile.professions[professionKey]
	local defaultAdvertised = (not self:IsProfessionDefaultOffByName(profession and profession.name))
		and self:IsProfessionAdvertisedByDefault(self:GetProfessionDefaultAdvertisingID(professionKey, profession))
	enabled = enabled == true
	if enabled == defaultAdvertised then
		self.db.advertising[characterName][professionKey] = nil
	else
		self.db.advertising[characterName][professionKey] = enabled
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
	if not profession.icon and self.GetCurrentProfessionInfo then
		local currentProfession = self:GetCurrentProfessionInfo()
		if currentProfession and tonumber(currentProfession.id) == professionID then
			profession.icon = currentProfession.icon
		end
	end

	for _, item in pairs(profile.items or {}) do
		if tonumber(item.professionID) == professionID then
			item.professionLink = professionLink
			item.professionIcon = item.professionIcon or profession.icon
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
	local baseProfessionID = self:GetBaseProfessionID(professionID)
	local count = 0
	for _, item in pairs(profile.items or {}) do
		if self:GetBaseProfessionID(item.professionID) == baseProfessionID then
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
				local displayProfessionID = self:GetProfessionDefaultAdvertisingID(professionID, profession)
				added[professionID] = true
				table.insert(rows, {
					characterName = characterName,
					professionID = professionID,
					baseProfessionID = displayProfessionID,
					parentProfessionID = profession.parentProfessionID,
					professionName = self:GetProfessionName(displayProfessionID, profile),
					professionIcon = profession.icon or profession.professionIcon or profession.iconTexture,
					count = count,
					advertised = self:IsProfessionAdvertised(characterName, professionID),
				})
			end
		end
		for _, item in pairs(profile.items or {}) do
			local professionID = tonumber(item.professionID)
			if professionID and not added[professionID] then
				local displayProfessionID = self:GetProfessionDefaultAdvertisingID(professionID, item)
				added[professionID] = true
				table.insert(rows, {
					characterName = characterName,
					professionID = professionID,
					baseProfessionID = displayProfessionID,
					parentProfessionID = item.parentProfessionID,
					professionName = self:GetProfessionName(displayProfessionID, profile),
					professionIcon = item.professionIcon or item.icon or item.iconTexture,
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

function AF:GetAdvertisingProfessionRows()
	local rows = self:GetScannedProfessionRows()
	local added = {}
	for _, row in ipairs(rows) do
		local key = tostring(row.characterName or "") .. ":" .. tostring(row.professionID or "")
		added[key] = true
		row.hasScanned = true
	end

	for characterName, characterSettings in pairs(self.db and self.db.advertising or {}) do
		if type(characterSettings) == "table" then
			for professionKey in pairs(characterSettings) do
				local professionID = tonumber(professionKey)
				local key = tostring(characterName or "") .. ":" .. tostring(professionID or "")
				if professionID and not added[key] then
					local baseProfessionID = self:GetProfessionDefaultAdvertisingID(professionID)
					table.insert(rows, {
						characterName = characterName,
						professionID = professionID,
						baseProfessionID = baseProfessionID,
						professionName = self:GetProfessionName(baseProfessionID),
						count = 0,
						advertised = self:IsProfessionAdvertised(characterName, professionID),
						preservedSetting = true,
					})
					added[key] = true
				end
			end
		end
	end

	for characterName, characterSettings in pairs(self.db and self.db.advertisingKnown or {}) do
		if type(characterSettings) == "table" then
			for professionKey in pairs(characterSettings) do
				local professionID = tonumber(professionKey)
				local key = tostring(characterName or "") .. ":" .. tostring(professionID or "")
				if professionID and not added[key] then
					local baseProfessionID = self:GetProfessionDefaultAdvertisingID(professionID)
					table.insert(rows, {
						characterName = characterName,
						professionID = professionID,
						baseProfessionID = baseProfessionID,
						professionName = self:GetProfessionName(baseProfessionID),
						count = 0,
						advertised = self:IsProfessionAdvertised(characterName, professionID),
						preservedSetting = true,
					})
					added[key] = true
				end
			end
		end
	end

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
	local namedProfessionID = GetBaseProfessionIDFromName(info and info.name)
	if namedProfessionID and namedProfessionID ~= tonumber(professionID) then
		return self:GetProfessionName(namedProfessionID)
	end
	if info and info.name then
		return info.name
	end
	professionID = GetBaseProfessionID(professionID)
	local spellID = BASE_PROFESSION_SPELLS[professionID]
	if spellID and C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and name and name ~= "" then
			return name
		end
	end
	if spellID and GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and name and name ~= "" then
			return name
		end
	end
	return BASE_PROFESSION_NAMES[professionID] or self:Text("PROFESSION_FALLBACK", tostring(professionID or "?"))
end

function AF:GetItemPriceForProfile(profile, itemID, professionID)
	profile = self:NormalizeArtisanProfile(profile)
	local item = profile.items[tostring(itemID or "")]
	local professionPrice = profile.professionPrices[tostring(professionID or "")]
	local baseProfessionID = self:GetProfessionDefaultAdvertisingID(professionID, item)
	local baseProfessionPrice = baseProfessionID and profile.professionPrices[tostring(baseProfessionID)] or nil
	local priceCopper, freeCommission = self:GetEntryCommission(item)
	local note = self:GetEntryNote(item)
	if not priceCopper then
		priceCopper, freeCommission = self:GetEntryCommission(professionPrice)
		if not priceCopper then
			priceCopper, freeCommission = self:GetEntryCommission(baseProfessionPrice)
		end
	end
	if not note then
		note = self:GetEntryNote(professionPrice) or self:GetEntryNote(baseProfessionPrice)
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
