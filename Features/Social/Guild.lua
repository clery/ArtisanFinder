local _, AF = ...

local GUILD_RECIPE_QUERY_THROTTLE = 8
local GUILD_TRADE_SKILL_REFRESH_THROTTLE = 30
local GUILD_TRADE_SKILL_PARSE_THROTTLE = 10
local GUILD_OFFLINE_MAX_AGE = 30 * 24 * 60 * 60
local GUILD_PROFESSION_SPELL_IDS = {
	[2018] = 164, -- Blacksmithing
	[2108] = 165, -- Leatherworking
	[2259] = 171, -- Alchemy
	[2366] = 182, -- Herbalism
	[2550] = 185, -- Cooking
	[2575] = 186, -- Mining
	[3908] = 197, -- Tailoring
	[4036] = 202, -- Engineering
	[7411] = 333, -- Enchanting
	[7620] = 356, -- Fishing
	[8613] = 393, -- Skinning
	[25229] = 755, -- Jewelcrafting
	[45357] = 773, -- Inscription
}

local function NormalizeGuildProfessionID(addon, professionID)
	professionID = tonumber(professionID)
	return addon:GetBaseProfessionID(GUILD_PROFESSION_SPELL_IDS[professionID] or professionID)
end

local function IsOnlineFlag(value)
	return value == true or value == 1
end

local function IsGuildMemberTooStale(addon, online, lastAvailableAt)
	if online then
		return false
	end
	lastAvailableAt = tonumber(lastAvailableAt)
	return lastAvailableAt and addon:Now() - lastAvailableAt > GUILD_OFFLINE_MAX_AGE
end

local function GetGuildCacheNameKey(name)
	if AF.IsForever then return AF:NormalizeName(name) and AF:NormalizeName(name):lower() end
	name = tostring(name or ""):gsub("%s+", "")
	name = name:lower()
	return name ~= "" and name or nil
end

local function GetCurrentGuildInfo()
	if not IsInGuild or not IsInGuild() or not GetGuildInfo then
		return nil, nil
	end
	local guildName, _, _, guildRealm = GetGuildInfo("player")
	if not guildName or guildName == "" then
		return nil, nil
	end
	if AF.IsForever then return guildName end
	guildRealm = guildRealm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
	return guildName, guildRealm
end

local function BuildGuildCacheKey(guildName, guildRealm)
	local guildKey = GetGuildCacheNameKey(guildName)
	if not guildKey then
		return nil
	end
	if AF.IsForever then return guildKey end
	local realmKey = GetGuildCacheNameKey(guildRealm)
	return realmKey and (guildKey .. "-" .. realmKey) or guildKey
end

local function CreateGuildCache(guildKey, guildName, guildRealm)
	return {
		guildKey = guildKey,
		guildName = guildName,
		guildRealm = guildRealm,
		rosterByName = {},
		recipeMembers = {},
		professionMembers = {},
	}
end

local function HasLegacyGuildCacheData(guildCache)
	return type(guildCache) == "table"
		and (
			next(guildCache.rosterByName or {}) ~= nil
			or next(guildCache.recipeMembers or {}) ~= nil
			or next(guildCache.professionMembers or {}) ~= nil
		)
end

local function GetGuildShortNameKey(name)
	if AF.IsForever then return AF:NormalizeName(name) and AF:NormalizeName(name):lower() end
	name = tostring(name or ""):gsub("%s+", "")
	local shortName = name:match("^([^-]+)") or name
	shortName = shortName:lower()
	return shortName ~= "" and shortName or nil
end

local function HasExplicitRealm(name)
	if AF.IsForever then return false end
	return tostring(name or ""):find("-", 1, true) ~= nil
end

local function IsLocalRealmName(addon, name)
	if addon.IsForever then return true end
	local realm = addon.GetNameRealm and addon:GetNameRealm(name) or tostring(name or ""):match("^[^-]+%-(.+)$")
	local realmKey = GetGuildCacheNameKey(realm)
	if not realmKey then
		return false
	end
	return realmKey == GetGuildCacheNameKey(GetRealmName and GetRealmName() or nil)
		or realmKey == GetGuildCacheNameKey(GetNormalizedRealmName and GetNormalizedRealmName() or nil)
end

local function IsConnectedRealmName(addon, name)
	return not addon.IsNameOnConnectedRealm or addon:IsNameOnConnectedRealm(name)
end

local function IsRemoteConnectedRealmName(addon, name)
	return HasExplicitRealm(name) and not IsLocalRealmName(addon, name) and IsConnectedRealmName(addon, name)
end

local function CreateGuildRosterLookup()
	return {
		names = {},
		shortNames = {},
		guids = {},
		namesByGUID = {},
	}
end

local function AddGuildRosterLookupName(addon, lookup, name)
	local normalizedName = addon:NormalizeName(name)
	if not normalizedName then
		return nil
	end
	lookup.names[normalizedName] = true
	local shortKey = GetGuildShortNameKey(name)
	if shortKey then
		lookup.shortNames[shortKey] = true
	end
	return normalizedName
end

local function AddGuildRosterLookupGUID(lookup, guid, name)
	guid = guid and tostring(guid) or nil
	if guid and guid ~= "" then
		lookup.guids[guid] = true
		if name then
			lookup.namesByGUID[guid] = name
		end
	end
end

local function EnsureGuildRosterLookup(addon, rosterNames)
	if type(rosterNames) == "table" and rosterNames.names then
		return rosterNames
	end
	local lookup = CreateGuildRosterLookup()
	for name in pairs(rosterNames or {}) do
		AddGuildRosterLookupName(addon, lookup, name)
	end
	return lookup
end

local function GuildRosterLookupHasName(addon, lookup, name)
	local normalizedName = addon:NormalizeName(name)
	if normalizedName and lookup.names[normalizedName] then
		return true
	end
	local shortKey = GetGuildShortNameKey(name)
	if shortKey and lookup.shortNames[shortKey] then
		return true
	end
	return false
end

local function GuildRosterLookupHasGUID(lookup, guid)
	guid = guid and tostring(guid) or nil
	return guid and guid ~= "" and lookup.guids[guid] == true or false
end

local function GuildRosterLookupHasMember(addon, lookup, name, guid)
	return GuildRosterLookupHasGUID(lookup, guid) or GuildRosterLookupHasName(addon, lookup, name)
end

-- Snapshot keys for loops that insert entries while iterating; adding keys
-- during pairs() is undefined behavior (deleting is fine).
local function GetTableKeys(tbl)
	local keys = {}
	for key in pairs(tbl or {}) do
		table.insert(keys, key)
	end
	return keys
end

local function IsCurrentPlayer(addon, name)
	return addon:NormalizeName(name) == addon:NormalizeName(addon.playerName or addon:GetPlayerFullName())
end

local function GetOnlineGuildContact(addon, name)
	if not addon.GetRememberedArtisanContact then
		return nil, nil
	end
	local normalizedName = addon:NormalizeName(name)
	local contactName = addon:GetRememberedArtisanContact(normalizedName, addon:GetCurrentGuildCacheKey())
	if not contactName or contactName == normalizedName then
		return nil, nil
	end
	local contactEntry = addon:GetCachedGuildRosterEntry(contactName)
	if contactEntry and contactEntry.online == true then
		return contactName, contactEntry
	end
	return nil, nil
end

local function HasSeenGuildContact(seenNames, name, contactName)
	return seenNames and (seenNames[name] or (contactName and seenNames[contactName]))
end

local function MarkSeenGuildContact(seenNames, name, contactName)
	if not seenNames then
		return
	end
	if name then
		seenNames[name] = true
	end
	if contactName then
		seenNames[contactName] = true
	end
end

local function EnsureOfflineRoster()
    local needsOffline = not AF.guildRosterOfflineConfigured
    if GetGuildRosterShowOffline then needsOffline = not GetGuildRosterShowOffline() end
    if SetGuildRosterShowOffline and (not AF.IsForever or needsOffline) then
        pcall(SetGuildRosterShowOffline, true)
        AF.guildRosterOfflineConfigured = true
    end
end

local function RequestGuildRoster()
    EnsureOfflineRoster()
    pcall(C_GuildInfo.GuildRoster)
end

local function QueryGuildRecipeData()
	if QueryGuildRecipes then
		pcall(QueryGuildRecipes)
	end
end

local function GetGuildRosterCount()
	if not GetNumGuildMembers then
		return 0
	end
	local total = GetNumGuildMembers()
	return tonumber(total) or 0
end

local function BuildRecipeKey(professionID, recipeID)
	return tostring(tonumber(professionID) or 0) .. ":" .. tostring(tonumber(recipeID) or 0)
end

local function GetRosterInfo(index)
	if not GetGuildRosterInfo then
		return nil
	end
	local name, _, _, _, _, _, _, _, online, _, _, _, _, isMobile, _, _, guid = GetGuildRosterInfo(index)
	return name, online, isMobile, guid
end

local function GetGuildRosterLastAvailableAt(addon, index, online)
	local now = addon:Now()
	if IsOnlineFlag(online) then
		return now
	end
	if not GetGuildRosterLastOnline then
		return nil
	end
	local ok, yearsOffline, monthsOffline, daysOffline, hoursOffline = pcall(GetGuildRosterLastOnline, index)
	if not ok or yearsOffline == nil then
		return nil
	end
	local hours = (tonumber(hoursOffline) or 0)
		+ ((tonumber(daysOffline) or 0) * 24)
		+ ((tonumber(monthsOffline) or 0) * 30.5 * 24)
		+ ((tonumber(yearsOffline) or 0) * 365 * 24)
	return math.max(0, now - (hours * 3600))
end

function AF:EnsureGuildCache()
	self.db = self.db or {}
	self.db.guildCache = self.db.guildCache or {}
	self.db.guildCache.byGuild = self.db.guildCache.byGuild or {}

	local guildName, guildRealm = GetCurrentGuildInfo()
	local guildKey = BuildGuildCacheKey(guildName, guildRealm)
	if self.currentGuildCacheKey ~= guildKey then
		self.guildRosterNameByShort = {}
		self.guildTradeSkillParsedAt = {}
		self.guildRecipeQueries = {}
		self.guildTradeSkillLastRefresh = 0
	end
	self.currentGuildCacheKey = guildKey

	if not guildKey then
		self.guildCache = CreateGuildCache(nil)
		self.guildRosterByName = self.guildCache.rosterByName
		self.guildRecipeMembers = self.guildCache.recipeMembers
		self.guildProfessionMembers = self.guildCache.professionMembers
		self.guildRosterNameByShort = self.guildRosterNameByShort or {}
		return self.guildCache
	end

	if not self.db.guildCache.byGuild[guildKey] then
		if HasLegacyGuildCacheData(self.db.guildCache) and not self.db.guildCache.legacyMigrated then
			self.db.guildCache.byGuild[guildKey] = {
				guildKey = guildKey,
				guildName = guildName,
				guildRealm = guildRealm,
				rosterByName = self.db.guildCache.rosterByName or {},
				recipeMembers = self.db.guildCache.recipeMembers or {},
				professionMembers = self.db.guildCache.professionMembers or {},
			}
			self.db.guildCache.rosterByName = nil
			self.db.guildCache.recipeMembers = nil
			self.db.guildCache.professionMembers = nil
			self.db.guildCache.legacyMigrated = true
		else
			self.db.guildCache.byGuild[guildKey] = CreateGuildCache(guildKey, guildName, guildRealm)
		end
	end

	self.guildCache = self.db.guildCache.byGuild[guildKey]
	self.guildCache.guildKey = guildKey
	self.guildCache.guildName = guildName
	self.guildCache.guildRealm = guildRealm
	self.guildCache.rosterByName = self.guildCache.rosterByName or {}
	self.guildCache.recipeMembers = self.guildCache.recipeMembers or {}
	self.guildCache.professionMembers = self.guildCache.professionMembers or {}
	self.guildRosterByName = self.guildCache.rosterByName
	self.guildRecipeMembers = self.guildCache.recipeMembers
	self.guildProfessionMembers = self.guildCache.professionMembers
	self.guildRosterNameByShort = self.guildRosterNameByShort or {}
	return self.guildCache
end

function AF:GetCurrentGuildCacheKey()
	self:EnsureGuildCache()
	return self.currentGuildCacheKey
end

function AF:RememberGuildRosterNameLookup(name)
	name = self:NormalizeName(name)
	if not name then
		return nil
	end
	self.guildRosterNameByShort = self.guildRosterNameByShort or {}
	local shortKey = GetGuildShortNameKey(name)
	if not shortKey then
		return name
	end
	local existing = self.guildRosterNameByShort[shortKey]
	if existing and existing ~= name then
		self.guildRosterNameByShort[shortKey] = false
	else
		self.guildRosterNameByShort[shortKey] = name
	end
	return name
end

function AF:RebuildGuildRosterNameLookup()
	self.guildRosterNameByShort = {}
	for name in pairs(self.guildRosterByName or {}) do
		self:RememberGuildRosterNameLookup(name)
	end
end

local function RenameGuildRosterMember(addon, oldName, newName)
	if not oldName or not newName or oldName == newName then
		return false
	end
	local rosterEntry = addon.guildRosterByName and addon.guildRosterByName[oldName]
	if not rosterEntry or addon.guildRosterByName[newName] then
		return false
	end

	addon.guildRosterByName[oldName] = nil
	addon.guildRosterByName[newName] = rosterEntry
	rosterEntry.name = newName
	rosterEntry.rosterName = newName
	rosterEntry.rosterNameHasExplicitRealm = true

	for _, professionCache in pairs(addon.guildProfessionMembers or {}) do
		local members = professionCache.members
		local member = members and members[oldName]
		if member and not members[newName] then
			members[oldName] = nil
			members[newName] = member
			member.name = newName
		end
	end

	for _, recipeCache in pairs(addon.guildRecipeMembers or {}) do
		for index, memberName in ipairs(recipeCache.members or {}) do
			if memberName == oldName then
				recipeCache.members[index] = newName
			end
		end
		if recipeCache.online and recipeCache.online[oldName] ~= nil and recipeCache.online[newName] == nil then
			recipeCache.online[newName] = recipeCache.online[oldName]
			recipeCache.online[oldName] = nil
		end
		if recipeCache.lastAvailableAt and recipeCache.lastAvailableAt[oldName] ~= nil and recipeCache.lastAvailableAt[newName] == nil then
			recipeCache.lastAvailableAt[newName] = recipeCache.lastAvailableAt[oldName]
			recipeCache.lastAvailableAt[oldName] = nil
		end
	end

	addon:RebuildGuildRosterNameLookup()
	return true
end

local function FindCachedRemoteRosterNameByGUID(addon, guid, name)
	guid = guid and tostring(guid) or nil
	if not guid or guid == "" then
		return nil
	end
	local shortKey = GetGuildShortNameKey(name)
	if not shortKey then
		return nil
	end
	for cachedName, entry in pairs(addon.guildRosterByName or {}) do
		if entry and tostring(entry.guid or "") == guid
			and GetGuildShortNameKey(cachedName) == shortKey
			and IsRemoteConnectedRealmName(addon, cachedName)
		then
			return cachedName
		end
	end
	return nil
end

local function GetCanonicalGuildRosterName(addon, rawName, guid)
	local name = addon:NormalizeName(rawName)
	if not name then
		return nil
	end
	if addon.IsForever or HasExplicitRealm(rawName) then
		return name
	end
	return FindCachedRemoteRosterNameByGUID(addon, guid, name) or name
end

local function PromoteResolvedGuildMemberName(addon, resolvedName, normalizedName, sourceName)
	if normalizedName
		and HasExplicitRealm(sourceName)
		and IsRemoteConnectedRealmName(addon, normalizedName)
		and resolvedName
		and resolvedName ~= normalizedName
		and addon.guildRosterByName
		and addon.guildRosterByName[resolvedName]
		and not addon.guildRosterByName[normalizedName]
		and addon.guildRosterByName[resolvedName].rosterNameHasExplicitRealm == false
	then
		RenameGuildRosterMember(addon, resolvedName, normalizedName)
		return normalizedName
	end
	return resolvedName
end

local function ClearCachedCustomerGuildAffiliation(entry, orderTarget)
	if type(entry) ~= "table" then
		return false
	end
	local changed = entry.guildMember ~= nil
		or entry.guildOnline ~= nil
		or entry.guildMemberGUID ~= nil
		or entry.guildRecipeKnown ~= nil
		or entry.guildKey ~= nil
	if not changed then
		return false
	end
	entry.guildMember = nil
	entry.guildOnline = nil
	entry.guildMemberGUID = nil
	entry.guildRecipeKnown = nil
	entry.guildKey = nil
	if orderTarget then
		entry.target = orderTarget
	end
	return true
end

local function EntryHasCachedGuildAffiliation(entry, guildKey)
	return entry.guildMember ~= nil
		or entry.guildOnline ~= nil
		or entry.guildMemberGUID ~= nil
		or entry.guildRecipeKnown ~= nil
		or entry.guildKey ~= nil
		or guildKey ~= nil and entry.guildKey == guildKey
end

local function ForEachCustomerGuildNameCandidate(addon, entry, cacheKey, callback)
	if type(entry) ~= "table" then
		return
	end
	local candidates = {
		entry.orderTarget,
		entry.name,
		cacheKey,
	}
	if not entry.orderTarget and not entry.name then
		table.insert(candidates, entry.target)
	end
	local seen = {}
	for _, candidate in ipairs(candidates) do
		local normalizedName = addon:NormalizeName(candidate)
		if normalizedName and not seen[normalizedName] then
			seen[normalizedName] = true
			if callback(candidate, normalizedName) then
				return
			end
		end
	end
end

local function CacheEntryMatchesDepartedGuildMember(addon, entry, cacheKey, rosterLookup, departedLookup, guildKey)
	if not EntryHasCachedGuildAffiliation(entry, guildKey) then
		return nil
	end
	if GuildRosterLookupHasGUID(rosterLookup, entry.guildMemberGUID) then
		return nil
	end
	local matchedRoster
	local departedName
	local firstName
	ForEachCustomerGuildNameCandidate(addon, entry, cacheKey, function(candidate, normalizedName)
		firstName = firstName or normalizedName
		if departedLookup.names[normalizedName] then
			departedName = normalizedName
			return true
		end
		if GuildRosterLookupHasName(addon, rosterLookup, candidate) then
			matchedRoster = true
			return true
		end
		return false
	end)
	if matchedRoster then
		return nil
	end
	if departedName then
		return departedName
	end
	if entry.guildMemberGUID and departedLookup.guids[tostring(entry.guildMemberGUID)] then
		return firstName or tostring(entry.guildMemberGUID)
	end
	return firstName or tostring(entry.guildMemberGUID or "")
end

function AF:ClearDepartedGuildCustomerCacheAffiliations(rosterNames, departedNames)
	if type(rosterNames) ~= "table" or type(departedNames) ~= "table" then
		return 0
	end
	local rosterLookup = EnsureGuildRosterLookup(self, rosterNames)
	local departedLookup = EnsureGuildRosterLookup(self, departedNames)
	local cleared = 0
	local guildKey = self.currentGuildCacheKey
	for _, itemCache in pairs(self.db and self.db.customerCache or {}) do
		if type(itemCache) == "table" then
			for cacheKey, entry in pairs(itemCache) do
				local name = CacheEntryMatchesDepartedGuildMember(self, entry, cacheKey, rosterLookup, departedLookup, guildKey)
				if name then
					local orderTarget = name ~= "" and self:IsNameOnConnectedRealm(name) and name or nil
					if ClearCachedCustomerGuildAffiliation(entry, orderTarget) then
						cleared = cleared + 1
					end
				end
			end
		end
	end
	return cleared
end

function AF:ClearDepartedGuildArtisanContacts(rosterNames, departedNames)
	if type(rosterNames) ~= "table" or type(departedNames) ~= "table" then
		return 0
	end
	local rosterLookup = EnsureGuildRosterLookup(self, rosterNames)
	local departedLookup = EnsureGuildRosterLookup(self, departedNames)
	local cleared = 0
	local guildKey = self.currentGuildCacheKey
	for crafterName, entry in pairs(self.db and self.db.artisanContacts or {}) do
		if type(entry) == "table" and (guildKey == nil or entry.guildKey == nil or entry.guildKey == guildKey) then
			local normalizedName = self:NormalizeName(crafterName)
			if normalizedName
				and (departedLookup.names[normalizedName] or not GuildRosterLookupHasName(self, rosterLookup, crafterName))
			then
				self.db.artisanContacts[crafterName] = nil
				cleared = cleared + 1
			end
		end
	end
	return cleared
end

function AF:ReconcileGuildCachesToRoster(rosterNames)
	local rosterLookup = EnsureGuildRosterLookup(self, rosterNames)
	if type(rosterLookup.names) ~= "table" or not next(rosterLookup.names) then
		return 0
	end

	local departedLookup = CreateGuildRosterLookup()
	local removedRoster = 0
	local removedProfession = 0
	local removedRecipe = 0
	for name, entry in pairs(self.guildRosterByName or {}) do
		local normalizedName = self:NormalizeName(name)
		local rosterName = entry and entry.guid and rosterLookup.namesByGUID[tostring(entry.guid)]
		if not normalizedName or not GuildRosterLookupHasMember(self, rosterLookup, name, entry and entry.guid) then
			if normalizedName then
				AddGuildRosterLookupName(self, departedLookup, normalizedName)
			end
			AddGuildRosterLookupGUID(departedLookup, entry and entry.guid)
			self.guildRosterByName[name] = nil
			removedRoster = removedRoster + 1
		elseif rosterName and rosterName ~= name then
			self.guildRosterByName[name] = nil
		elseif normalizedName ~= name then
			self.guildRosterByName[name] = nil
		end
	end

	for _, professionCache in pairs(self.guildProfessionMembers or {}) do
		for _, name in ipairs(GetTableKeys(professionCache.members)) do
			local normalizedName = self:NormalizeName(name)
			local member = professionCache.members[name]
			local rosterName = member and member.guid and rosterLookup.namesByGUID[tostring(member.guid)]
			if not normalizedName or not GuildRosterLookupHasMember(self, rosterLookup, name, member and member.guid) then
				if normalizedName then
					AddGuildRosterLookupName(self, departedLookup, normalizedName)
				end
				AddGuildRosterLookupGUID(departedLookup, member and member.guid)
				professionCache.members[name] = nil
				removedProfession = removedProfession + 1
			elseif rosterName and rosterName ~= name then
				professionCache.members[name] = nil
				if type(member) == "table" and not professionCache.members[rosterName] then
					member.name = rosterName
					professionCache.members[rosterName] = member
				end
			elseif normalizedName ~= name then
				professionCache.members[name] = nil
				if type(member) == "table" and not professionCache.members[normalizedName] then
					member.name = normalizedName
					professionCache.members[normalizedName] = member
				end
			end
		end
	end

	for _, recipeCache in pairs(self.guildRecipeMembers or {}) do
		local prunedMembers = {}
		for _, name in ipairs(recipeCache.members or {}) do
			local normalizedName = self:NormalizeName(name)
			if normalizedName and GuildRosterLookupHasName(self, rosterLookup, name) then
				table.insert(prunedMembers, normalizedName)
			elseif normalizedName then
				AddGuildRosterLookupName(self, departedLookup, normalizedName)
				removedRecipe = removedRecipe + 1
			end
		end
		recipeCache.members = prunedMembers
		for _, name in ipairs(GetTableKeys(recipeCache.online)) do
			local normalizedName = self:NormalizeName(name)
			if not normalizedName or not GuildRosterLookupHasName(self, rosterLookup, name) then
				if normalizedName then
					AddGuildRosterLookupName(self, departedLookup, normalizedName)
				end
				recipeCache.online[name] = nil
			elseif normalizedName ~= name then
				recipeCache.online[normalizedName] = recipeCache.online[normalizedName] or recipeCache.online[name]
				recipeCache.online[name] = nil
			end
		end
		for _, name in ipairs(GetTableKeys(recipeCache.lastAvailableAt)) do
			local normalizedName = self:NormalizeName(name)
			if not normalizedName or not GuildRosterLookupHasName(self, rosterLookup, name) then
				if normalizedName then
					AddGuildRosterLookupName(self, departedLookup, normalizedName)
				end
				recipeCache.lastAvailableAt[name] = nil
			elseif normalizedName ~= name then
				recipeCache.lastAvailableAt[normalizedName] = recipeCache.lastAvailableAt[normalizedName] or recipeCache.lastAvailableAt[name]
				recipeCache.lastAvailableAt[name] = nil
			end
		end
	end
	local clearedCustomers = self:ClearDepartedGuildCustomerCacheAffiliations(rosterLookup, departedLookup)
	local clearedContacts = self:ClearDepartedGuildArtisanContacts(rosterLookup, departedLookup)
	self:RebuildGuildRosterNameLookup()
	local changed = removedRoster + removedProfession + removedRecipe + clearedCustomers + clearedContacts
	if changed > 0 then
		self:DebugLog("guild", string.format(
			"reconciled roster=%d removedRoster=%d removedProfession=%d removedRecipe=%d clearedCustomers=%d clearedContacts=%d",
			self.guildRosterCount or 0,
			removedRoster,
			removedProfession,
			removedRecipe,
			clearedCustomers,
			clearedContacts
		))
	end
	return changed
end

function AF:ResolveGuildMemberName(name, requestRefresh)
	if not name or name == "" then
		return nil
	end
	self:EnsureGuildCache()
	if not self.guildRosterNameByShort or next(self.guildRosterNameByShort) == nil then
		self:RebuildGuildRosterNameLookup()
	end

	local normalizedName = self:NormalizeName(name)
	if normalizedName and self.guildRosterByName and self.guildRosterByName[normalizedName] then
		return normalizedName
	end

	local shortKey = GetGuildShortNameKey(name)
	local resolvedName = shortKey and self.guildRosterNameByShort and self.guildRosterNameByShort[shortKey]
	if resolvedName then
		return PromoteResolvedGuildMemberName(self, resolvedName, normalizedName, name)
	end

    if requestRefresh and self.IsForever then
        -- Cache misses include nonguild crafters: never rescan the entire roster per lookup.
        -- Once a snapshot exists, absence is a valid nonguild result. Requesting
        -- again here creates render -> miss -> roster -> render feedback loops.
        if not self.currentGuildCacheKey or self.foreverGuildRosterReadyKey~=self.currentGuildCacheKey then
            self:QueueGuildRosterCacheRefresh(true)
        end
        return normalizedName
    end
	if requestRefresh and self:RefreshGuildRosterCache(true) > 0 then
		resolvedName = shortKey and self.guildRosterNameByShort and self.guildRosterNameByShort[shortKey]
		if resolvedName then
			return PromoteResolvedGuildMemberName(self, resolvedName, normalizedName, name)
		end
		if normalizedName and self.guildRosterByName and self.guildRosterByName[normalizedName] then
			return normalizedName
		end
	end

	return normalizedName
end

function AF:MarkCachedGuildMembersOffline()
	for _, entry in pairs(self.guildRosterByName or {}) do
		entry.online = false
	end
	for _, professionCache in pairs(self.guildProfessionMembers or {}) do
		for _, member in pairs(professionCache.members or {}) do
			member.online = false
		end
	end
	for _, recipeCache in pairs(self.guildRecipeMembers or {}) do
		for name in pairs(recipeCache.online or {}) do
			recipeCache.online[name] = false
		end
	end
end

function AF:InitializeGuild()
	self:EnsureGuildCache()
	self:MarkCachedGuildMembersOffline()
	self.guildRecipeQueries = self.guildRecipeQueries or {}
	self.guildTradeSkillLastRefresh = 0
	self:RefreshGuildRosterCache(true)
	QueryGuildRecipeData()
end

function AF:ClearGuildMemberData(skipRefresh)
	self:EnsureGuildCache()
	if self.currentGuildCacheKey and self.db.guildCache and self.db.guildCache.byGuild then
		self.db.guildCache.byGuild[self.currentGuildCacheKey] = CreateGuildCache(self.currentGuildCacheKey, self.guildCache and self.guildCache.guildName, self.guildCache and self.guildCache.guildRealm)
	else
		self.db.guildCache = {
			byGuild = {},
			legacyMigrated = true,
		}
	end
	self.guildRosterNameByShort = {}
	self:EnsureGuildCache()
	self.guildRecipeQueries = {}
	self.guildTradeSkillLastRefresh = 0
	if skipRefresh then
		return
	end
	self:RefreshGuildRosterCache(true)
	QueryGuildRecipeData()
	if self.currentCustomerProfessionID and self.currentCustomerRecipeID and self.QueueGuildRecipeMemberQuery then
		self:QueueGuildRecipeMemberQuery(self.currentCustomerProfessionID, self.currentCustomerRecipeID)
	end
	if self.RefreshCustomerResults then
		self:RequestCustomerResultsRefresh()
	end
end

function AF:RefreshGuildRosterCache(requestRefresh)
	self:EnsureGuildCache()
	if not IsInGuild or not IsInGuild() then
		self:EnsureGuildCache()
		return 0
	end
	EnsureOfflineRoster()
	if requestRefresh then
		RequestGuildRoster()
	end

	self.guildRosterByName = self.guildRosterByName or {}
	self.guildRosterNameByShort = {}
	local rosterLookup = CreateGuildRosterLookup()
	local count = 0
    local availability={}
    local changed=false
	for index = 1, GetGuildRosterCount() do
		local rawName, online, isMobile, guid = GetRosterInfo(index)
		local name = GetCanonicalGuildRosterName(self, rawName, guid)
		AddGuildRosterLookupName(self, rosterLookup, rawName)
		AddGuildRosterLookupName(self, rosterLookup, name)
		AddGuildRosterLookupGUID(rosterLookup, guid, name)
		if name then
			self:RememberGuildRosterNameLookup(name)
			local entry = self.guildRosterByName[name] or {}
			local isOnline = IsOnlineFlag(online)
            if entry.name~=name or entry.online~=isOnline or entry.guid~=guid
                or entry.isMobile~=IsOnlineFlag(isMobile) then changed=true end
			local lastAvailableAt = GetGuildRosterLastAvailableAt(self, index, online)
			self.guildRosterByName[name] = entry
			entry.name = name
			entry.rosterName = rawName
			entry.rosterNameHasExplicitRealm = HasExplicitRealm(rawName)
			entry.online = isOnline
			entry.isMobile = IsOnlineFlag(isMobile)
			entry.guid = guid
			local now = self:Now()
			entry.updatedAt = now
            if isOnline then entry.lastObservedOnlineAt=now end
			if lastAvailableAt then
				entry.lastAvailableAt = lastAvailableAt
			end
            availability[name]=lastAvailableAt

			count = count + 1
		end
	end
    changed=changed or self.guildRosterCount~=count
    if count>0 then self.foreverGuildRosterReadyKey=self.currentGuildCacheKey end
    local needsReconcile=self.guildRosterNeedsReconcile
    self.guildRosterNeedsReconcile=requestRefresh==true
    if self.IsForever and not changed and not needsReconcile then return count,false end
    for _,professionCache in pairs(self.guildProfessionMembers or {}) do
        for name,member in pairs(professionCache.members or {}) do
            local entry=self.guildRosterByName[name]
            if entry then
                member.online=entry.online
                local stamp=availability[name]
                if stamp then member.lastAvailableAt=stamp end
                if entry.online or stamp then member.updatedAt=entry.updatedAt end
            end
        end
    end
    for _,recipeCache in pairs(self.guildRecipeMembers or {}) do
        for name in pairs(recipeCache.online or {}) do
            local entry=self.guildRosterByName[name]
            if entry then
                recipeCache.online[name]=entry.online
                if availability[name] then
                    recipeCache.lastAvailableAt=recipeCache.lastAvailableAt or {}
                    recipeCache.lastAvailableAt[name]=availability[name]
                end
            end
        end
    end
	self.guildRosterCount = count
	if count > 0 and not requestRefresh then
		self:ReconcileGuildCachesToRoster(rosterLookup)
	elseif count > 0 then
		self:RebuildGuildRosterNameLookup()
	end
	return count,changed
end

function AF:QueueGuildRosterCacheRefresh(requestRefresh)
	if self.guildRosterRefreshQueued then
		self.guildRosterRefreshRequest = self.guildRosterRefreshRequest or requestRefresh == true
		return
	end
	self.guildRosterRefreshQueued = true
	self.guildRosterRefreshRequest = requestRefresh == true
    local delay=0.2
    if self.IsForever then
        delay=math.max(0.5,5-(self:Now()-(self.guildRosterRefreshAt or -5)))
    end
    C_Timer.After(delay, function()
        AF.guildRosterRefreshAt=AF:Now()
		AF.guildRosterRefreshQueued = nil
		local shouldRequest = AF.guildRosterRefreshRequest == true
		AF.guildRosterRefreshRequest = nil
        local started=debugprofilestop and debugprofilestop()
        local count,changed=AF:RefreshGuildRosterCache(shouldRequest)
        if started and AF.DebugLog then
            AF:DebugLog("guild-performance",string.format("roster=%.2fms members=%d changed=%s requested=%s",
                debugprofilestop()-started,count,tostring(changed),tostring(shouldRequest)))
        end
		if AF.RefreshCustomerResults then
			AF:RequestCustomerResultsRefresh()
		end
	end)
end

function AF:GetGuildRosterEntry(name)
	if not IsInGuild or not IsInGuild() then
		return nil
	end
	name = self:ResolveGuildMemberName(name, true)
	if not name then
		return nil
	end
	if not self.guildRosterByName then
		self:RefreshGuildRosterCache(false)
	end
	if self.guildRosterByName and not self.guildRosterByName[name] then
		name = self:ResolveGuildMemberName(name, false)
	end
	return self.guildRosterByName and self.guildRosterByName[name] or nil
end

function AF:GetCachedGuildRosterEntry(name)
	if not IsInGuild or not IsInGuild() then
		return nil
	end
	self:EnsureGuildCache()
	local normalizedName = self:NormalizeName(name)
	if normalizedName and self.guildRosterByName and self.guildRosterByName[normalizedName] then
		return self.guildRosterByName[normalizedName]
	end
	local shortKey = GetGuildShortNameKey(name)
	local resolvedName = shortKey and self.guildRosterNameByShort and self.guildRosterNameByShort[shortKey]
	return resolvedName and self.guildRosterByName and self.guildRosterByName[resolvedName] or nil
end

function AF:GetGuildMemberGUID(name)
	local entry = self:GetGuildRosterEntry(name)
	return entry and entry.guid or nil
end

function AF:IsKnownGuildMember(name)
	return self:GetGuildRosterEntry(name) ~= nil
end

function AF:RefreshGuildTradeSkills()
	if not IsInGuild or not IsInGuild() then
		return
	end
	local now = self:Now()
	if now - (tonumber(self.guildTradeSkillLastRefresh) or 0) < GUILD_TRADE_SKILL_REFRESH_THROTTLE then
		return
	end
	self.guildTradeSkillLastRefresh = now
	self:RefreshGuildRosterCache(true)
	QueryGuildRecipeData()
end

function AF:RememberGuildProfessionMember(professionID, name, _, online, recipeID, knowsRecipe, updatedAt)
	self:EnsureGuildCache()
	professionID = NormalizeGuildProfessionID(self, professionID)
	name = self:ResolveGuildMemberName(name, true)
	if not professionID or not name then
		return nil
	end

	local professionKey = tostring(professionID)
	self.guildProfessionMembers = self.guildProfessionMembers or {}
	local professionCache = self.guildProfessionMembers[professionKey] or {
		professionID = professionID,
		members = {},
	}
	self.guildProfessionMembers[professionKey] = professionCache
	professionCache.professionName = nil

	local member = professionCache.members[name] or { name = name }
	local now = updatedAt or self:Now()
	local rosterEntry = self:GetGuildRosterEntry(name)
	if not rosterEntry then
		return nil
	end
	local isOnline = IsOnlineFlag(online)
	if online == nil and rosterEntry then
		isOnline = rosterEntry.online == true
	end
	local rosterLastAvailableAt = rosterEntry and rosterEntry.lastAvailableAt
	if isOnline or not professionCache.updatedAt then
		professionCache.updatedAt = now
	end
	professionCache.members[name] = member
	member.name = name
	member.online = isOnline
	member.guid = rosterEntry.guid
	member.professionName = nil
	if isOnline then
		member.updatedAt = now
		member.lastAvailableAt = now
	elseif rosterLastAvailableAt then
		member.lastAvailableAt = rosterLastAvailableAt
	elseif not member.updatedAt then
		member.updatedAt = now
	end
	member.recipeIDs = member.recipeIDs or {}
	if tonumber(recipeID) and tonumber(recipeID) ~= 0 then
		member.recipeIDs[tostring(recipeID)] = knowsRecipe == true
	end

	if rosterEntry then
		rosterEntry.online = member.online
	end

	return member
end

function AF:GetGuildCachedProfessionMemberRows(itemID, professionID, filterText, seenNames, recipeID)
	self:EnsureGuildCache()
	local rows = {}
	professionID = NormalizeGuildProfessionID(self, professionID)
	if not professionID then
		return rows
	end

	local professionCache = self.guildProfessionMembers and self.guildProfessionMembers[tostring(professionID)]
	if not professionCache then
		return rows
	end

	filterText = tostring(filterText or ""):lower()
	seenNames = seenNames or {}
	recipeID = tonumber(recipeID) or 0
	for name, member in pairs(professionCache.members or {}) do
		name = self:ResolveGuildMemberName(name, true)
		local contactName, contactRosterEntry = GetOnlineGuildContact(self, name)
		if name and not IsCurrentPlayer(self, name) and not HasSeenGuildContact(seenNames, name, contactName) then
			local knowsRecipe = recipeID ~= 0 and member.recipeIDs and member.recipeIDs[tostring(recipeID)] == true
			local rosterEntry = self:GetGuildRosterEntry(name)
			local online = rosterEntry and rosterEntry.online
			if not rosterEntry then
				online = member.online == true
			end
			if contactRosterEntry then
				online = true
			end
			local isOnline = online == true
			local rowUpdatedAt = isOnline and (member.lastAvailableAt or member.updatedAt)
				or member.lastAvailableAt
				or (rosterEntry and rosterEntry.lastAvailableAt)
				or member.updatedAt
			if rosterEntry and knowsRecipe and not IsGuildMemberTooStale(self, isOnline, rowUpdatedAt) then
				local entry = {
					name = name,
					target = name,
					orderTarget = name,
					itemID = itemID,
					professionID = professionID,
					professionName = self:GetProfessionName(professionID),
					updatedAt = rowUpdatedAt,
					verifiedAt = member.updatedAt or professionCache.updatedAt or self:Now(),
					certified = false,
					tradeLead = true,
					guildMember = true,
					guildRecipeKnown = true,
					guildOnline = online,
					lastAvailableAt = member.lastAvailableAt,
					guildMemberGUID = rosterEntry and rosterEntry.guid or nil,
					guildKey = self.currentGuildCacheKey,
					recipeID = recipeID,
				}
				if contactName then
					entry.target = contactName
					entry.displayName = contactName
				end
				if filterText == "" or self:CustomerEntryMatchesFilter(entry, filterText) then
					table.insert(rows, entry)
					MarkSeenGuildContact(seenNames, name, contactName)
				end
			end
		end
	end

	return rows
end

function AF:GetGuildRecipeMemberRows(itemID, professionID, filterText, seenNames, recipeID)
	self:EnsureGuildCache()
	local rows = {}
	professionID = NormalizeGuildProfessionID(self, professionID)
	recipeID = tonumber(recipeID) or 0
	if not professionID or recipeID == 0 then
		return rows
	end

	local recipeData = self.guildRecipeMembers and self.guildRecipeMembers[BuildRecipeKey(professionID, recipeID)]
	if not recipeData then
		return rows
	end

	filterText = tostring(filterText or ""):lower()
	seenNames = seenNames or {}
	for _, memberName in ipairs(recipeData.members or {}) do
		local name = self:ResolveGuildMemberName(memberName, true)
		local contactName, contactRosterEntry = GetOnlineGuildContact(self, name)
		if name and not IsCurrentPlayer(self, name) and not HasSeenGuildContact(seenNames, name, contactName) then
			local rosterEntry = self:GetGuildRosterEntry(name)
			local online = rosterEntry and rosterEntry.online
			if not rosterEntry then
				online = recipeData.online and recipeData.online[name] == true
			end
			if contactRosterEntry then
				online = true
			end
			local isOnline = online == true
			local professionCache = self.guildProfessionMembers and self.guildProfessionMembers[tostring(professionID)]
			local cachedMember = professionCache and professionCache.members and professionCache.members[name]
			local lastAvailableAt = (recipeData.lastAvailableAt and recipeData.lastAvailableAt[name])
				or (cachedMember and cachedMember.lastAvailableAt)
				or (rosterEntry and rosterEntry.lastAvailableAt)
			local fallbackUpdatedAt = cachedMember and cachedMember.updatedAt
			if rosterEntry and not IsGuildMemberTooStale(self, isOnline, lastAvailableAt or fallbackUpdatedAt) then
				local entry = {
					name = name,
					target = name,
					orderTarget = name,
					itemID = itemID,
					professionID = professionID,
					professionName = self:GetProfessionName(professionID),
					updatedAt = isOnline and (lastAvailableAt or recipeData.updatedAt) or (lastAvailableAt or fallbackUpdatedAt),
					verifiedAt = self:Now(),
					certified = false,
					tradeLead = true,
					guildMember = true,
					guildRecipeKnown = true,
					guildOnline = online,
					lastAvailableAt = lastAvailableAt,
					guildMemberGUID = rosterEntry and rosterEntry.guid or nil,
					guildKey = self.currentGuildCacheKey,
					recipeID = recipeID,
				}
				if contactName then
					entry.target = contactName
					entry.displayName = contactName
				end
				if filterText == "" or self:CustomerEntryMatchesFilter(entry, filterText) then
					table.insert(rows, entry)
					MarkSeenGuildContact(seenNames, name, contactName)
				end
			end
		end
	end

	return rows
end

function AF:EnsureGuildTradeSkillHeaderExpanded(professionID)
	professionID = NormalizeGuildProfessionID(self, professionID)
	if not professionID or not GetNumGuildTradeSkill or not GetGuildTradeSkillInfo or not ExpandGuildTradeSkillHeader then
		return false
	end

	for index = 1, tonumber(GetNumGuildTradeSkill()) or 0 do
		local skillID, isCollapsed, _, headerName = GetGuildTradeSkillInfo(index)
		if headerName and NormalizeGuildProfessionID(self, skillID) == professionID and isCollapsed then
			pcall(ExpandGuildTradeSkillHeader, skillID)
			return true
		end
	end
	return false
end

function AF:QueueGuildRecipeMemberQuery(professionID, recipeID)
	professionID = NormalizeGuildProfessionID(self, professionID) or 0
	recipeID = tonumber(recipeID) or 0
	if professionID == 0 or recipeID == 0 or not IsInGuild or not IsInGuild() then
		return false
	end
	self.guildRecipeQueries = self.guildRecipeQueries or {}
	local key = BuildRecipeKey(professionID, recipeID)
	local now = self:Now()
	if self.guildRecipeQueries[key] and now - self.guildRecipeQueries[key] < GUILD_RECIPE_QUERY_THROTTLE then
		return false
	end
	self.guildRecipeQueries[key] = now
	QueryGuildRecipeData()
	local ok, updatedRecipeID = pcall(C_GuildInfo.QueryGuildMembersForRecipe, professionID, recipeID)
	if ok and tonumber(updatedRecipeID) and tonumber(updatedRecipeID) ~= recipeID then
		local updatedKey = BuildRecipeKey(professionID, updatedRecipeID)
		self.guildRecipeQueries[updatedKey] = now
	end
	return ok == true
end

function AF:HandleGuildRecipeKnownByMembers()
	self:EnsureGuildCache()
	if not GetGuildRecipeInfoPostQuery or not GetGuildRecipeMember then
		return
	end
	local ok, professionID, recipeID, numMembers = pcall(GetGuildRecipeInfoPostQuery)
	if not ok or not professionID or not recipeID then
		return
	end

	self:RefreshGuildRosterCache(false)
	professionID = NormalizeGuildProfessionID(self, professionID)
	local key = BuildRecipeKey(professionID, recipeID)
	self.guildRecipeMembers = self.guildRecipeMembers or {}
	local members = {}
	local onlineByName = {}
	local lastAvailableAt = {}
	local previous = self.guildRecipeMembers and self.guildRecipeMembers[key]
	if previous and type(previous.lastAvailableAt) == "table" then
		for name, timestamp in pairs(previous.lastAvailableAt) do
			lastAvailableAt[name] = timestamp
		end
	end
	for index = 1, tonumber(numMembers) or 0 do
		local memberOk, displayName, fullName, _, onlineFlag = pcall(GetGuildRecipeMember, index)
		local name = memberOk and self:ResolveGuildMemberName(fullName or displayName, true) or nil
		local isOnline = IsOnlineFlag(onlineFlag)
		if name then
			table.insert(members, name)
			onlineByName[name] = isOnline
			local member = self:RememberGuildProfessionMember(professionID, name, self:GetProfessionName(professionID), isOnline, recipeID, true)
			if member and member.lastAvailableAt then
				lastAvailableAt[name] = member.lastAvailableAt
			end
		end
	end
	self.guildRecipeMembers[key] = {
		professionID = tonumber(professionID) or 0,
		recipeID = tonumber(recipeID) or 0,
		members = members,
		online = onlineByName,
		lastAvailableAt = lastAvailableAt,
		updatedAt = self:Now(),
	}
	if self.RefreshCustomerResults then
		self:RequestCustomerResultsRefresh()
	end
end

function AF:GetOnlineGuildQueryTargets(professionID, recipeID, limit)
	self:EnsureGuildCache()
	local targets = {}
	local added = {}
	professionID = NormalizeGuildProfessionID(self, professionID) or 0
	recipeID = tonumber(recipeID) or 0
	limit = tonumber(limit) or 30
	if professionID == 0 or recipeID == 0 or limit <= 0 or not IsInGuild or not IsInGuild() then
		return targets
	end

	local function addTarget(name)
		name = self:ResolveGuildMemberName(name, false)
		if not name or added[name] or IsCurrentPlayer(self, name) then
			return
		end
		local rosterEntry = self:GetCachedGuildRosterEntry(name)
		if rosterEntry and rosterEntry.online == true then
			table.insert(targets, name)
			added[name] = true
		end
	end

	local function addMemberTarget(name)
		local contactName = self:GetRememberedArtisanContact(name, self:GetCurrentGuildCacheKey())
		if contactName and contactName ~= self:NormalizeName(name) then
			addTarget(contactName)
		end
		addTarget(name)
	end

	local recipeData = self.guildRecipeMembers and self.guildRecipeMembers[BuildRecipeKey(professionID, recipeID)]
	for _, memberName in ipairs(recipeData and recipeData.members or {}) do
		addMemberTarget(memberName)
		if #targets >= limit then
			return targets
		end
	end

	local professionCache = self.guildProfessionMembers and self.guildProfessionMembers[tostring(professionID)]
	for name, member in pairs(professionCache and professionCache.members or {}) do
		if member.recipeIDs and member.recipeIDs[tostring(recipeID)] == true then
			addMemberTarget(name)
			if #targets >= limit then
				return targets
			end
		end
	end

	return targets
end

function AF:GetGuildProfessionRows(itemID, professionID, filterText, seenNames, recipeID)
	self:EnsureGuildCache()
	local rows = {}
	professionID = NormalizeGuildProfessionID(self, professionID) or 0
	if professionID == 0 or not IsInGuild or not IsInGuild() then
		return rows
	end

	seenNames = seenNames or {}
	local professionKey = tostring(professionID)
	self.guildTradeSkillParsedAt = self.guildTradeSkillParsedAt or {}
	local now = self:Now()
	local shouldParseGuildTradeSkills = GetNumGuildTradeSkill
		and GetGuildTradeSkillInfo
		and now - (tonumber(self.guildTradeSkillParsedAt[professionKey]) or 0) >= GUILD_TRADE_SKILL_PARSE_THROTTLE
	if shouldParseGuildTradeSkills then
		self:RefreshGuildTradeSkills()
		self:EnsureGuildTradeSkillHeaderExpanded(professionID)
		local currentProfessionID
		local currentProfessionName
		local exactRecipeMembers = {}
		local recipeData = self.guildRecipeMembers and self.guildRecipeMembers[BuildRecipeKey(professionID, recipeID)]
		if recipeData then
			for _, memberName in ipairs(recipeData.members or {}) do
				memberName = self:ResolveGuildMemberName(memberName, true)
				if memberName then
					exactRecipeMembers[memberName] = true
				end
			end
		end

		for index = 1, tonumber(GetNumGuildTradeSkill()) or 0 do
			local skillID, _, _, headerName, _, _, _, playerName, playerNameWithRealm, _, online = GetGuildTradeSkillInfo(index)
			if headerName then
				currentProfessionID = NormalizeGuildProfessionID(self, skillID)
				currentProfessionName = headerName
			elseif currentProfessionID == NormalizeGuildProfessionID(self, professionID) then
				local name = self:ResolveGuildMemberName(playerNameWithRealm or playerName, true)
				if name and not IsCurrentPlayer(self, name) then
					self:RememberGuildProfessionMember(currentProfessionID, name, currentProfessionName, IsOnlineFlag(online), recipeID, exactRecipeMembers[name] == true)
				end
			end
		end
		self.guildTradeSkillParsedAt[professionKey] = now
	end

	for _, entry in ipairs(self:GetGuildRecipeMemberRows(itemID, professionID, filterText, seenNames, recipeID)) do
		table.insert(rows, entry)
	end

	for _, entry in ipairs(self:GetGuildCachedProfessionMemberRows(itemID, professionID, filterText, seenNames, recipeID)) do
		table.insert(rows, entry)
	end

	return rows
end
