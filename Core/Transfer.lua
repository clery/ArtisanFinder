local _, AF = ...

local TRANSFER_PREFIX = "AFART1:"
local TRANSFER_FORMAT = "ArtisanFinderArtisans"
local TRANSFER_VERSION = 1
local MAX_ENCODED_BYTES = 2 * 1024 * 1024
local MAX_SERIALIZED_BYTES = 8 * 1024 * 1024
local MAX_ARTISANS = 100
local MAX_TABLE_DEPTH = 16
local MAX_TABLE_ENTRIES = 250000
local MAX_STRING_BYTES = 1024 * 1024

local function GetTransferLibraries()
	if not LibStub then
		return nil, nil
	end
	return LibStub:GetLibrary("LibSerialize", true), LibStub:GetLibrary("LibDeflate", true)
end

local function CopyCharacterLinks(db, characterName)
	local links = {}
	local prefix = characterName .. ":"
	for key, link in pairs(db.professionLinks or {}) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix and type(link) == "string" then
			links[key:sub(#prefix + 1)] = link
		end
	end
	return links
end

local function ValidateSafeValue(value, state, depth)
	local valueType = type(value)
	if valueType == "string" then
		return #value <= MAX_STRING_BYTES
	end
	if valueType == "number" or valueType == "boolean" or valueType == "nil" then
		return true
	end
	if valueType ~= "table" or depth > MAX_TABLE_DEPTH or state.active[value] then
		return false
	end
	if state.seen[value] then
		return true
	end
	state.seen[value] = true
	state.active[value] = true
	for key, child in pairs(value) do
		local keyType = type(key)
		if keyType ~= "string" and keyType ~= "number" then
			return false
		end
		state.entries = state.entries + 1
		if state.entries > MAX_TABLE_ENTRIES
			or not ValidateSafeValue(key, state, depth + 1)
			or not ValidateSafeValue(child, state, depth + 1)
		then
			return false
		end
	end
	state.active[value] = nil
	return true
end

local function GetEntryTimestamp(entry)
	if type(entry) ~= "table" then
		return 0
	end
	return tonumber(entry.updatedAt) or tonumber(entry.scannedAt) or 0
end

local function MergeTimestampedEntries(target, source)
	local added = 0
	local updated = 0
	for key, sourceEntry in pairs(source or {}) do
		local targetEntry = target[key]
		if targetEntry == nil then
			target[key] = sourceEntry
			added = added + 1
		elseif GetEntryTimestamp(sourceEntry) > GetEntryTimestamp(targetEntry) then
			target[key] = sourceEntry
			updated = updated + 1
		end
	end
	return added, updated
end

local function MergeMissingSettings(target, source)
	for key, value in pairs(source or {}) do
		if target[key] == nil then
			target[key] = value
		end
	end
end

local function IsTransferArtisanShapeValid(transfer)
	if type(transfer) ~= "table" or type(transfer.profile) ~= "table" then
		return false
	end
	local profile = transfer.profile
	return (profile.professions == nil or type(profile.professions) == "table")
		and (profile.items == nil or type(profile.items) == "table")
		and (profile.professionPrices == nil or type(profile.professionPrices) == "table")
		and (transfer.advertising == nil or type(transfer.advertising) == "table")
		and (transfer.advertisingKnown == nil or type(transfer.advertisingKnown) == "table")
		and (transfer.professionLinks == nil or type(transfer.professionLinks) == "table")
end

local function IsValidTransferCharacterName(characterName)
	return type(characterName) == "string"
		and #characterName <= 128
		and characterName:find("-", 1, true) ~= nil
		and characterName:find("[%c]") == nil
end

function AF:BuildArtisanTransferPayload()
	local serializer, deflater = GetTransferLibraries()
	if not serializer or not deflater then
		return nil, self:Text("TRANSFER_ERROR_LIBRARIES")
	end

	local artisans = {}
	self:ForEachArtisanProfile(function(characterName, profile)
		characterName = self:NormalizeName(characterName)
		if characterName and not self:IsArtisanProfileEmpty(profile) then
			artisans[characterName] = {
				profile = profile,
				advertising = self.db.advertising and self.db.advertising[characterName] or nil,
				advertisingKnown = self.db.advertisingKnown and self.db.advertisingKnown[characterName] or nil,
				professionLinks = CopyCharacterLinks(self.db, characterName),
			}
		end
	end)

	local envelope = {
		format = TRANSFER_FORMAT,
		version = TRANSFER_VERSION,
		schemaVersion = self.SCHEMA_VERSION,
		exportedAt = self:Now(),
		artisans = artisans,
	}
	local ok, serialized = pcall(serializer.Serialize, serializer, envelope)
	if not ok or type(serialized) ~= "string" then
		return nil, self:Text("TRANSFER_ERROR_EXPORT")
	end
	local compressedOK, compressed = pcall(deflater.CompressDeflate, deflater, serialized)
	local encodedOK, encoded = false, nil
	if compressedOK and type(compressed) == "string" then
		encodedOK, encoded = pcall(deflater.EncodeForPrint, deflater, compressed)
	end
	if not encodedOK or type(encoded) ~= "string" or encoded == "" then
		return nil, self:Text("TRANSFER_ERROR_EXPORT")
	end
	return TRANSFER_PREFIX .. encoded, nil
end

function AF:DecodeArtisanTransferPayload(text)
	text = tostring(text or ""):match("^%s*(.-)%s*$")
	if text:sub(1, #TRANSFER_PREFIX) ~= TRANSFER_PREFIX then
		return nil, self:Text("TRANSFER_ERROR_PREFIX")
	end
	if #text > MAX_ENCODED_BYTES then
		return nil, self:Text("TRANSFER_ERROR_TOO_LARGE")
	end

	local serializer, deflater = GetTransferLibraries()
	if not serializer or not deflater then
		return nil, self:Text("TRANSFER_ERROR_LIBRARIES")
	end
	local decodedOK, decoded = pcall(deflater.DecodeForPrint, deflater, text:sub(#TRANSFER_PREFIX + 1))
	local decompressedOK, serialized = false, nil
	if decodedOK and type(decoded) == "string" then
		decompressedOK, serialized = pcall(deflater.DecompressDeflate, deflater, decoded)
	end
	if not decompressedOK or type(serialized) ~= "string" then
		return nil, self:Text("TRANSFER_ERROR_DECODE")
	end
	if #serialized > MAX_SERIALIZED_BYTES then
		return nil, self:Text("TRANSFER_ERROR_TOO_LARGE")
	end
	local callOK, ok, envelope = pcall(serializer.Deserialize, serializer, serialized)
	if not callOK or not ok or type(envelope) ~= "table" then
		return nil, self:Text("TRANSFER_ERROR_DECODE")
	end
	if not ValidateSafeValue(envelope, { seen = {}, active = {}, entries = 0 }, 1) then
		return nil, self:Text("TRANSFER_ERROR_MALFORMED")
	end
	if envelope.format ~= TRANSFER_FORMAT or tonumber(envelope.version) ~= TRANSFER_VERSION then
		return nil, self:Text("TRANSFER_ERROR_VERSION")
	end
	if (tonumber(envelope.schemaVersion) or 0) > self.SCHEMA_VERSION then
		return nil, self:Text("TRANSFER_ERROR_FUTURE_SCHEMA", tonumber(envelope.schemaVersion) or 0, self.SCHEMA_VERSION)
	end
	if type(envelope.artisans) ~= "table" then
		return nil, self:Text("TRANSFER_ERROR_MALFORMED")
	end
	return envelope, nil
end

function AF:ImportArtisanTransferPayload(text)
	local envelope, errorMessage = self:DecodeArtisanTransferPayload(text)
	if not envelope then
		return nil, errorMessage
	end

	local currentName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	local summary = {
		addedArtisans = 0,
		mergedArtisans = 0,
		skippedCurrent = 0,
		skippedInvalid = 0,
		addedEntries = 0,
		updatedEntries = 0,
	}
	local candidates = {}
	local seenNames = {}
	local currentIdentity = currentName and currentName:lower() or nil
	local localNamesByIdentity = {}
	for localName in pairs(self.db.artisanCharacters or {}) do
		if type(localName) == "string" then
			localNamesByIdentity[localName:lower()] = localName
		end
	end
	local artisanCount = 0
	for rawName, transfer in pairs(envelope.artisans) do
		artisanCount = artisanCount + 1
		if artisanCount > MAX_ARTISANS then
			return nil, self:Text("TRANSFER_ERROR_TOO_MANY_ARTISANS", MAX_ARTISANS)
		end
		local characterName = type(rawName) == "string" and self:NormalizeName(rawName) or nil
		local characterIdentity = characterName and characterName:lower() or nil
		characterName = characterIdentity and localNamesByIdentity[characterIdentity] or characterName
		if not IsValidTransferCharacterName(characterName) or not IsTransferArtisanShapeValid(transfer) then
			summary.skippedInvalid = summary.skippedInvalid + 1
		elseif characterIdentity == currentIdentity then
			summary.skippedCurrent = summary.skippedCurrent + 1
		elseif seenNames[characterIdentity] then
			return nil, self:Text("TRANSFER_ERROR_DUPLICATE_NAME", characterName)
		else
			local preparedOK, profile = pcall(self.PrepareImportedArtisanProfile, self, transfer.profile, characterName)
			if not preparedOK or self:IsArtisanProfileEmpty(profile) then
				summary.skippedInvalid = summary.skippedInvalid + 1
			else
				seenNames[characterIdentity] = true
				local advertisingOK, advertising = pcall(self.PrepareImportedProfessionSettings, self, transfer.advertising)
				local knownOK, advertisingKnown = pcall(self.PrepareImportedProfessionSettings, self, transfer.advertisingKnown)
				if not advertisingOK or not knownOK then
					return nil, self:Text("TRANSFER_ERROR_MALFORMED")
				end
				table.insert(candidates, {
					characterName = characterName,
					profile = profile,
					advertising = advertising,
					advertisingKnown = advertisingKnown,
					professionLinks = transfer.professionLinks,
				})
			end
		end
	end

	for _, candidate in ipairs(candidates) do
		local characterName = candidate.characterName
		local profile = candidate.profile
		local target = self.db.artisanCharacters[characterName]
		if type(target) ~= "table" then
			self.db.artisanCharacters[characterName] = profile
			summary.addedArtisans = summary.addedArtisans + 1
			summary.addedEntries = summary.addedEntries
				+ self:GetArtisanProfileEntryCount(profile)
		else
			target = self:NormalizeArtisanProfile(target, characterName)
			local added, updated = MergeTimestampedEntries(target.professions, profile.professions)
			summary.addedEntries = summary.addedEntries + added
			summary.updatedEntries = summary.updatedEntries + updated
			added, updated = MergeTimestampedEntries(target.items, profile.items)
			summary.addedEntries = summary.addedEntries + added
			summary.updatedEntries = summary.updatedEntries + updated
			added, updated = MergeTimestampedEntries(target.professionPrices, profile.professionPrices)
			summary.addedEntries = summary.addedEntries + added
			summary.updatedEntries = summary.updatedEntries + updated
			summary.mergedArtisans = summary.mergedArtisans + 1
		end

		self.db.advertising[characterName] = self.db.advertising[characterName] or {}
		self.db.advertisingKnown[characterName] = self.db.advertisingKnown[characterName] or {}
		MergeMissingSettings(self.db.advertising[characterName], candidate.advertising)
		MergeMissingSettings(self.db.advertisingKnown[characterName], candidate.advertisingKnown)
		if next(self.db.advertising[characterName]) == nil then
			self.db.advertising[characterName] = nil
		end
		if next(self.db.advertisingKnown[characterName]) == nil then
			self.db.advertisingKnown[characterName] = nil
		end
		for professionKey, link in pairs(candidate.professionLinks or {}) do
			local key = self:GetProfessionLinkKey(characterName, professionKey)
			if key and self.db.professionLinks[key] == nil and type(link) == "string" then
				self.db.professionLinks[key] = link
			end
		end
	end

	self:RefreshMainUI()
	return summary, nil
end
