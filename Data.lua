local _, AF = ...

local MIGRATIONS = {}
local SUPPORTED_PROFESSIONS = {
	[164] = true, -- Blacksmithing
	[165] = true, -- Leatherworking
	[171] = true, -- Alchemy
	[197] = true, -- Tailoring
	[202] = true, -- Engineering
	[333] = true, -- Enchanting
	[755] = true, -- Jewelcrafting
	[773] = true, -- Inscription
}
local PROFESSION_ID_ALIASES = {
	[5] = 185, -- Midnight Cooking
	[6] = 186, -- Midnight Mining
	[10] = 356, -- Midnight Fishing
	[12] = 755, -- Midnight Jewelcrafting
}
local REALM_CONNECTION_CACHE_MAX_AGE = 30 * 24 * 60 * 60
local ApplyDBDefaults
local legacyReagentDisplayCache = {}
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

local function GetSupportedProfessionID(professionID)
	professionID = GetBaseProfessionID(professionID)
	return professionID and SUPPORTED_PROFESSIONS[professionID] and professionID or nil
end

local function GetSupportedProfessionIDForEntry(professionID, entry)
	if type(entry) == "table" then
		return GetSupportedProfessionID(entry.parentProfessionID)
			or GetSupportedProfessionID(entry.baseProfessionID)
			or GetSupportedProfessionID(entry.id)
			or GetSupportedProfessionID(professionID)
	end
	return GetSupportedProfessionID(professionID)
end

local function GetProfessionKey(professionID)
	professionID = GetSupportedProfessionID(professionID)
	return professionID and tostring(professionID) or nil
end

function AF:GetBaseProfessionID(professionID)
	return GetBaseProfessionID(professionID)
end

function AF:GetSupportedProfessionID(professionID, entry)
	return GetSupportedProfessionIDForEntry(professionID, entry)
end

function AF:IsSupportedProfession(professionID, entry)
	return GetSupportedProfessionIDForEntry(professionID, entry) ~= nil
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
	return GetSupportedProfessionIDForEntry(professionKey, profession)
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

local function NormalizeProfessionKeyedTable(tbl)
	if type(tbl) ~= "table" then
		return
	end
	for professionKey, value in pairs(tbl) do
		local baseProfessionKey = GetProfessionKey(professionKey)
		if baseProfessionKey and baseProfessionKey ~= professionKey then
			if tbl[baseProfessionKey] == nil then
				tbl[baseProfessionKey] = value
			end
			tbl[professionKey] = nil
		end
	end
end

local function NormalizeProfessionKeyedSettings(db)
	for _, characterSettings in pairs(db.advertising or {}) do
		NormalizeProfessionKeyedTable(characterSettings)
	end

	local function normalizeProfilePrices(profile)
		NormalizeProfessionKeyedTable(type(profile) == "table" and profile.professionPrices or nil)
	end

	normalizeProfilePrices(db.artisanProfile)
	for _, profile in pairs(db.artisanCharacters or {}) do
		normalizeProfilePrices(profile)
	end
end

local function ClearLocalizedCraftFields(item)
	if type(item) ~= "table" then
		return
	end
	item.itemName = nil
	item.recipeName = nil
	item.professionName = nil
	item.bestReagentSummary = nil
	item.bestReagentDetails = nil
	item.bestReagentSummaryUpdatedAt = nil
	item.hasReagentSummary = nil
	item.reagentDetailRequested = nil
	item.optionalReagentSummary = nil
	item.debugBestCandidateSummary = nil
end

local function ClearVolatileCraftFields(item)
	if type(item) ~= "table" then
		return
	end
	item.baseSkill = nil
	item.bonusSkill = nil
	item.bonusDifficulty = nil
	item.lowerSkillThreshold = nil
	item.upperSkillThreshold = nil
	item.rawConcentrationQuality = nil
	item.debugBaseOperation = nil
	item.debugBestCandidateQuality = nil
	item.debugBestCandidateAtlas = nil
	item.debugBestCandidateRawQuality = nil
	item.debugBestCandidateAccepted = nil
	item.debugBestCandidateOperation = nil
	item.debugBestCandidateReason = nil
	item.skillProbeAt = nil
	item.fullScanAt = nil
end

local function GetLegacyReagentDisplayKey(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local itemID = tonumber(entry.itemID)
	local recipeID = tonumber(entry.recipeID) or 0
	local professionID = GetSupportedProfessionIDForEntry(entry.professionID, entry) or 0
	local name = AF:NormalizeName(entry.orderTarget or entry.name or entry.target)
	if not itemID or not name then
		return nil
	end
	return table.concat({ name, itemID, recipeID, professionID }, ":")
end

local function PreserveLegacyReagentDisplay(entry)
	if type(entry) ~= "table" or entry.bestReagents then
		return
	end
	local details = type(entry.bestReagentDetails) == "string" and entry.bestReagentDetails or nil
	local summary = type(entry.bestReagentSummary) == "string" and entry.bestReagentSummary or nil
	if (not details or details == "") and (not summary or summary == "") then
		return
	end
	local key = GetLegacyReagentDisplayKey(entry)
	if key then
		legacyReagentDisplayCache[key] = {
			details = details,
			summary = summary,
			truncated = entry.bestReagentTruncated,
		}
	end
end

function AF:GetLegacyReagentDisplay(entry)
	local key = GetLegacyReagentDisplayKey(entry)
	return key and legacyReagentDisplayCache[key] or nil
end

local function MergeProfessionEntry(target, source, professionID)
	target.id = professionID
	target.recipes = target.recipes or {}
	for recipeID, value in pairs(source.recipes or {}) do
		target.recipes[recipeID] = value
	end
	for _, key in ipairs({
		"parentProfessionID",
		"baseProfessionID",
		"skillLineID",
		"childProfessionID",
		"icon",
		"professionLink",
		"scanSignature",
		"scanMode",
		"scannedAt",
		"updatedAt",
		"equipmentSignature",
		"bestProfessionSkillAt",
	}) do
		if source[key] ~= nil and (target[key] == nil or key == "updatedAt" and (tonumber(source[key]) or 0) > (tonumber(target[key]) or 0)) then
			target[key] = source[key]
		end
	end
	if type(source.bestProfessionSkillTotals) == "table" then
		target.bestProfessionSkillTotals = target.bestProfessionSkillTotals or {}
		for key, value in pairs(source.bestProfessionSkillTotals) do
			local total = tonumber(value)
			if total and total > (tonumber(target.bestProfessionSkillTotals[key]) or 0) then
				target.bestProfessionSkillTotals[key] = total
			end
		end
	end
end

local function NormalizeCraftProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	EnsureProfileContainers(profile)

	local professionMap = {}
	local normalizedProfessions = {}
	for professionKey, profession in pairs(profile.professions or {}) do
		if type(profession) == "table" then
			local supportedID = GetMigrationProfessionID(professionKey, profession)
			if supportedID then
				local normalizedKey = tostring(supportedID)
				professionMap[tostring(professionKey)] = supportedID
				if profession.id then
					professionMap[tostring(profession.id)] = supportedID
				end
				if profession.parentProfessionID then
					professionMap[tostring(profession.parentProfessionID)] = supportedID
				end
				if profession.baseProfessionID then
					professionMap[tostring(profession.baseProfessionID)] = supportedID
				end
				local target = normalizedProfessions[normalizedKey] or { id = supportedID, recipes = {} }
				normalizedProfessions[normalizedKey] = target
				profession.name = nil
				MergeProfessionEntry(target, profession, supportedID)
			end
		end
	end
	profile.professions = normalizedProfessions

	local normalizedPrices = {}
	for professionKey, entry in pairs(profile.professionPrices or {}) do
		local supportedID = professionMap[tostring(professionKey)] or GetSupportedProfessionID(professionKey)
		if supportedID and type(entry) == "table" then
			normalizedPrices[tostring(supportedID)] = entry
		end
	end
	profile.professionPrices = normalizedPrices

	for itemKey, item in pairs(profile.items or {}) do
		if type(item) ~= "table" then
			profile.items[itemKey] = nil
		else
			local supportedID = professionMap[tostring(item.professionID or "")]
				or GetSupportedProfessionIDForEntry(item.professionID, item)
			if supportedID then
				item.professionID = supportedID
				ClearLocalizedCraftFields(item)
				ClearVolatileCraftFields(item)
			else
				profile.items[itemKey] = nil
			end
		end
	end
end

local function NormalizeCharacterProfessionSettings(settings)
	if type(settings) ~= "table" then
		return
	end
	for professionKey, value in pairs(settings) do
		local supportedID = GetSupportedProfessionID(professionKey)
		settings[professionKey] = nil
		if supportedID then
			settings[tostring(supportedID)] = value
		end
	end
end

local function NormalizeProfessionLinks(db)
	local normalized = {}
	for key, link in pairs(db.professionLinks or {}) do
		local characterName, professionKey = tostring(key):match("^(.-):([^:]+)$")
		local supportedID = GetSupportedProfessionID(professionKey)
		if characterName and supportedID then
			normalized[characterName .. ":" .. tostring(supportedID)] = link
		end
	end
	db.professionLinks = normalized
end

local function NormalizeCustomerCacheEntry(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local supportedID = GetSupportedProfessionIDForEntry(entry.professionID, entry)
	if not supportedID then
		return nil
	end
	entry.professionID = supportedID
	PreserveLegacyReagentDisplay(entry)
	ClearLocalizedCraftFields(entry)
	ClearVolatileCraftFields(entry)
	return entry
end

local function NormalizeCustomerCache(db)
	for itemKey, itemCache in pairs(db.customerCache or {}) do
		if type(itemCache) == "table" then
			for cacheKey, entry in pairs(itemCache) do
				itemCache[cacheKey] = NormalizeCustomerCacheEntry(entry)
			end
			if next(itemCache) == nil then
				db.customerCache[itemKey] = nil
			end
		else
			db.customerCache[itemKey] = nil
		end
	end
end

local function NormalizeTradeLead(lead)
	if type(lead) ~= "table" then
		return nil
	end
	lead.professionName = nil
	local candidates = {}
	for professionID in pairs(lead.professionCandidates or {}) do
		local supportedID = GetSupportedProfessionID(professionID)
		if supportedID then
			candidates[supportedID] = true
		end
	end
	if next(candidates) == nil then
		return nil
	end
	lead.professionCandidates = candidates
	return lead
end

local function NormalizeTradeLeads(tbl)
	for key, lead in pairs(tbl or {}) do
		tbl[key] = NormalizeTradeLead(lead)
	end
end

local function NormalizeGuildProfessionCache(db)
	local professionMembers = db.guildCache and db.guildCache.professionMembers
	if type(professionMembers) ~= "table" then
		return
	end
	for professionKey, cache in pairs(professionMembers) do
		local supportedID = GetSupportedProfessionID(professionKey)
		professionMembers[professionKey] = nil
		if supportedID and type(cache) == "table" then
			cache.professionID = supportedID
			cache.professionName = nil
			for _, member in pairs(cache.members or {}) do
				if type(member) == "table" then
					member.professionName = nil
				end
			end
			professionMembers[tostring(supportedID)] = cache
		end
	end
end

local function NormalizeIDOnlyCraftData(db)
	ApplyDBDefaults(db)
	NormalizeCraftProfile(db.artisanProfile)
	for _, profile in pairs(db.artisanCharacters or {}) do
		NormalizeCraftProfile(profile)
	end
	for _, settings in pairs(db.advertising or {}) do
		NormalizeCharacterProfessionSettings(settings)
	end
	for _, settings in pairs(db.advertisingKnown or {}) do
		NormalizeCharacterProfessionSettings(settings)
	end
	NormalizeProfessionLinks(db)
	NormalizeCustomerCache(db)
	NormalizeTradeLeads(db.tradeLeads)
	NormalizeTradeLeads(db.tradeLeadCache)
	NormalizeGuildProfessionCache(db)
	db.responseThrottle = nil
end

function ApplyDBDefaults(db)
	db.artisanProfile = EnsureProfileContainers(db.artisanProfile)
	db.artisanCharacters = db.artisanCharacters or {}
	db.advertising = db.advertising or {}
	db.advertisingKnown = db.advertisingKnown or {}
	db.customerCache = db.customerCache or {}
	db.favoriteArtisans = db.favoriteArtisans or {}
	db.professionLinks = db.professionLinks or {}
	db.artisanContacts = db.artisanContacts or {}
	db.tradeLeads = db.tradeLeads or {}
	db.tradeLeadCache = db.tradeLeadCache or {}
	db.whoOnlineCache = db.whoOnlineCache or {}
	db.connectedRealmCache = db.connectedRealmCache or {}
	db.guildCache = db.guildCache or {}
	db.guildCache.rosterByName = db.guildCache.rosterByName or {}
	db.guildCache.recipeMembers = db.guildCache.recipeMembers or {}
	db.guildCache.professionMembers = db.guildCache.professionMembers or {}
	db.minimap = db.minimap or { angle = 225, hide = false }
	db.tutorial = db.tutorial or {}

	if db.debugSelfResults == true then
		db.debugEnabled = true
		db.devEnabled = true
		db.devFakeRows = true
	end
	db.debugSelfResults = false
	if db.debugEnabled == nil then
		db.debugEnabled = false
	end
	if db.devEnabled == nil then
		db.devEnabled = false
	end
	if db.devFakeRows == nil then
		db.devFakeRows = false
	end
	if db.devTrafficLogs == nil then
		db.devTrafficLogs = false
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
	if db.freezeTradeLeadRows == nil then
		db.freezeTradeLeadRows = false
	end
	if db.offlineFallbackResults == nil then
		db.offlineFallbackResults = 10
	end
	if db.offlineFallbackMax == nil then
		db.offlineFallbackMax = 20
	end
	if db.showUncertifiedPeople == nil then
		db.showUncertifiedPeople = true
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

MIGRATIONS[10] = function(db)
	db.tutorial = db.tutorial or {}
end

MIGRATIONS[11] = function(db)
	db.connectedRealmCache = db.connectedRealmCache or {}
end

MIGRATIONS[12] = function(db)
	db.artisanContacts = db.artisanContacts or {}
end

MIGRATIONS[13] = function(db)
	NormalizeIDOnlyCraftData(db)
end

MIGRATIONS[14] = function(db)
	NormalizeIDOnlyCraftData(db)
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
	for name, updatedAt in pairs(self.db.whoOnlineCache or {}) do
		updatedAt = tonumber(updatedAt) or 0
		if updatedAt <= 0 or updatedAt < cutoff then
			self.db.whoOnlineCache[name] = nil
			removed = removed + 1
		end
	end
	for cacheKey, entry in pairs(self.db.connectedRealmCache or {}) do
		local updatedAt = tonumber(entry and entry.updatedAt) or 0
		if updatedAt <= 0 or self:Now() - updatedAt > REALM_CONNECTION_CACHE_MAX_AGE then
			self.db.connectedRealmCache[cacheKey] = nil
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
	return GetSupportedProfessionID(professionID) ~= nil
end

function AF:GetProfessionDefaultAdvertisingID(professionID, profileOrRow)
	professionID = GetSupportedProfessionID(professionID)
	if type(profileOrRow) == "table" then
		local parentProfessionID = GetSupportedProfessionID(profileOrRow.parentProfessionID or profileOrRow.baseProfessionID)
		if parentProfessionID then
			return parentProfessionID
		end
		if profileOrRow.professions and professionID then
			local profession = profileOrRow.professions[tostring(professionID)]
			parentProfessionID = GetSupportedProfessionID(profession and profession.parentProfessionID)
			if parentProfessionID then
				return parentProfessionID
			end
		end
	end
	return professionID
end

function AF:IsProfessionAdvertised(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	local professionKey = GetProfessionKey(professionID)
	if not characterName or not professionKey then
		return false
	end
	local characterSettings = self.db and self.db.advertising and self.db.advertising[characterName]
	local setting = characterSettings and characterSettings[professionKey]
	if setting == nil and characterSettings then
		setting = characterSettings[tostring(professionID)]
	end
	if setting ~= nil then
		return setting == true
	end
	local profile = self.db and self.db.artisanCharacters and self.db.artisanCharacters[characterName]
	local profession = profile and profile.professions and profile.professions[professionKey]
	local defaultID = self:GetProfessionDefaultAdvertisingID(professionKey, profession)
	return self:IsProfessionAdvertisedByDefault(defaultID)
end

function AF:SetProfessionAdvertised(characterName, professionID, enabled)
	characterName = self:NormalizeName(characterName)
	local professionKey = GetProfessionKey(professionID)
	if not characterName or not professionKey or not self.db then
		return
	end
	self.db.advertising = self.db.advertising or {}
	self.db.advertisingKnown = self.db.advertisingKnown or {}
	self.db.advertisingKnown[characterName] = self.db.advertisingKnown[characterName] or {}
	self.db.advertisingKnown[characterName][professionKey] = true
	self.db.advertising[characterName] = self.db.advertising[characterName] or {}
	local profile = self.db and self.db.artisanCharacters and self.db.artisanCharacters[characterName]
	local profession = profile and profile.professions and profile.professions[professionKey]
	local defaultAdvertised = self:IsProfessionAdvertisedByDefault(self:GetProfessionDefaultAdvertisingID(professionKey, profession))
	enabled = enabled == true
	if enabled == defaultAdvertised then
		self.db.advertising[characterName][professionKey] = nil
	else
		self.db.advertising[characterName][professionKey] = enabled
	end
	local legacyProfessionKey = tostring(professionID)
	if legacyProfessionKey ~= professionKey then
		self.db.advertising[characterName][legacyProfessionKey] = nil
	end
	if next(self.db.advertising[characterName]) == nil then
		self.db.advertising[characterName] = nil
	end
	self:RefreshMinimap()
	self:RefreshCrafterUI()
	self:RefreshOptionsPanel()
end

function AF:GetProfessionLinkKey(characterName, professionID)
	characterName = self:NormalizeName(characterName)
	local professionKey = GetProfessionKey(professionID)
	if not characterName or not professionKey then
		return nil
	end
	return characterName .. ":" .. professionKey
end

local function GetLegacyProfessionLinkKey(AF, characterName, professionID)
	characterName = AF:NormalizeName(characterName)
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

function AF:StoreProfessionLink(characterName, professionID, professionLink)
	if type(professionLink) ~= "string" or professionLink == "" or not self.db then
		return nil
	end

	characterName = self:NormalizeName(characterName or self.activeArtisanCharacter or self.playerName or self:GetPlayerFullName())
	professionID = GetSupportedProfessionID(professionID)
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
		recipes = {},
	}
	profile.professions[professionKey] = profession
	profession.id = professionID
	profession.professionLink = professionLink
	if not profession.icon then
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
	local links = self.db and self.db.professionLinks
	if key and links and links[key] then
		return links[key]
	end
	local legacyKey = GetLegacyProfessionLinkKey(self, characterName, professionID)
	return legacyKey and links and links[legacyKey] or nil
end

function AF:RememberArtisanContact(crafterName, contactName)
	crafterName = self:NormalizeName(crafterName)
	contactName = self:NormalizeName(contactName)
	if not crafterName or not contactName or not self.db then
		return
	end
	self.db.artisanContacts = self.db.artisanContacts or {}
	self.db.artisanContacts[crafterName] = {
		target = contactName,
		updatedAt = self:Now(),
	}
end

function AF:GetRememberedArtisanContact(crafterName)
	crafterName = self:NormalizeName(crafterName)
	local entry = crafterName and self.db and self.db.artisanContacts and self.db.artisanContacts[crafterName]
	return entry and self:NormalizeName(entry.target) or nil
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

local function GetRealmKey(realm)
	return tostring(realm or ""):gsub("%s+", ""):lower()
end

local function AddRealmKey(keys, realm)
	local key = GetRealmKey(realm)
	if key ~= "" then
		keys[key] = true
	end
	return key
end

local function BuildConnectedRealmKeys()
	local keys = {}
	AddRealmKey(keys, GetRealmName())
	if GetNormalizedRealmName then
		AddRealmKey(keys, GetNormalizedRealmName())
	end
	if GetAutoCompleteRealms then
		local realms = { GetAutoCompleteRealms() }
		realms = type(realms[1]) == "table" and realms[1] or realms
		for _, realm in ipairs(realms) do
			AddRealmKey(keys, realm)
		end
	end
	return keys
end

local function GetConnectedRealmCacheKey()
	local key = AddRealmKey({}, GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName())
	if key ~= "" then
		return key
	end
	key = AddRealmKey({}, GetRealmName())
	return key ~= "" and key or nil
end

local function IsConnectedRealmCacheFresh(AF, cacheEntry)
	local updatedAt = tonumber(cacheEntry and cacheEntry.updatedAt) or 0
	return updatedAt > 0 and AF:Now() - updatedAt <= REALM_CONNECTION_CACHE_MAX_AGE
end

local function GetConnectedRealmKeys(AF)
	if AF.connectedRealmKeys then
		return AF.connectedRealmKeys
	end

	local cacheKey = GetConnectedRealmCacheKey()
	local cached = cacheKey and AF.db and AF.db.connectedRealmCache and AF.db.connectedRealmCache[cacheKey]
	local keys = cached and cached.realms
	if type(keys) == "table" and next(keys) and IsConnectedRealmCacheFresh(AF, cached) then
		AddRealmKey(keys, GetRealmName())
		if GetNormalizedRealmName then
			AddRealmKey(keys, GetNormalizedRealmName())
		end
		AF.connectedRealmKeys = keys
		return keys
	end

	keys = BuildConnectedRealmKeys()
	if cacheKey and AF.db then
		AF.db.connectedRealmCache = AF.db.connectedRealmCache or {}
		AF.db.connectedRealmCache[cacheKey] = {
			realms = keys,
			updatedAt = AF:Now(),
		}
	end

	AF.connectedRealmKeys = keys
	return keys
end

function AF:GetNameRealm(name)
	name = self:NormalizeName(name)
	return name and name:match("^[^-]+%-(.+)$") or nil
end

function AF:IsNameOnConnectedRealm(name)
	local targetRealm = GetRealmKey(self:GetNameRealm(name))
	if targetRealm == "" then
		return true
	end

	self.connectedRealmNameCache = self.connectedRealmNameCache or {}
	if self.connectedRealmNameCache[targetRealm] ~= nil then
		return self.connectedRealmNameCache[targetRealm]
	end
	local connected = GetConnectedRealmKeys(self)[targetRealm] == true
	self.connectedRealmNameCache[targetRealm] = connected
	return connected
end

function AF:IsGuildOrderEntry(entry)
	if not entry or not entry.guildMember then
		return false
	end
	if entry.ownAlt and self:IsNameOnConnectedRealm(entry.orderTarget or entry.name or entry.target) then
		return false
	end
	return Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Guild ~= nil
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
	local baseProfessionID = self:GetSupportedProfessionID(professionID)
	if not baseProfessionID then
		return 0
	end
	local count = 0
	for _, item in pairs(profile.items or {}) do
		if self:GetSupportedProfessionID(item.professionID, item) == baseProfessionID then
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
			local professionID = self:GetSupportedProfessionID(professionKey, profession)
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
			local professionID = self:GetSupportedProfessionID(item.professionID, item)
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
				local professionID = self:GetSupportedProfessionID(professionKey)
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
				local professionID = self:GetSupportedProfessionID(professionKey)
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
	professionID = GetSupportedProfessionID(professionID) or GetBaseProfessionID(professionID)
	local spellID = BASE_PROFESSION_SPELLS[professionID]
	if spellID then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and name and name ~= "" then
			return name
		end
	end
	return BASE_PROFESSION_NAMES[professionID] or self:Text("PROFESSION_FALLBACK", tostring(professionID or "?"))
end

function AF:GetItemPriceForProfile(profile, itemID, professionID)
	profile = self:NormalizeArtisanProfile(profile)
	local item = profile.items[tostring(itemID or "")]
	local professionKey = GetProfessionKey(professionID)
	local legacyProfessionKey = professionID and tostring(professionID) or nil
	local professionPrice = professionKey and profile.professionPrices[professionKey] or nil
	if not professionPrice and legacyProfessionKey then
		professionPrice = profile.professionPrices[legacyProfessionKey]
	end
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

function AF:GetProfessionPriceEntry(profile, professionID)
	profile = profile or (self.db and self.db.artisanProfile)
	local professionKey = GetProfessionKey(professionID)
	local professionPrices = profile and profile.professionPrices
	local entry = professionKey and professionPrices and professionPrices[professionKey] or nil
	if entry then
		return entry
	end
	local legacyProfessionKey = professionID and tostring(professionID) or nil
	return legacyProfessionKey and professionPrices and professionPrices[legacyProfessionKey] or nil
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
	local professionKey = GetProfessionKey(professionID)
	if not professionKey then
		return
	end
	local entry = self.db.artisanProfile.professionPrices[professionKey] or {}
	self.db.artisanProfile.professionPrices[professionKey] = entry
	self:SetCommissionFields(entry, priceCopper, freeCommission, commissionState)
	entry.note = note or ""
	entry.updatedAt = self:Now()
end
