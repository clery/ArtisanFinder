local _, AF = ...

local TRANSFER_PREFIX = "AFART3:"
local TRANSFER_FORMAT = "ArtisanFinderArtisans"
local TRANSFER_VERSION = 3
local MAX_ENCODED_BYTES = 2 * 1024 * 1024
local MAX_SERIALIZED_BYTES = 8 * 1024 * 1024
local MAX_ARTISANS = 100
local MAX_TABLE_DEPTH = 16
local MAX_TABLE_ENTRIES = 250000
local MAX_STRING_BYTES = 1024 * 1024

local function CopyScalarField(source, target, key)
	local value = source and source[key]
	local valueType = type(value)
	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		target[key] = value
	end
end

local function CopyScalarFields(source, keys)
	local target = {}
	for _, key in ipairs(keys) do
		CopyScalarField(source, target, key)
	end
	return next(target) and target or nil
end

local function CopyScalarArray(source, itemFields)
	if type(source) ~= "table" then
		return nil
	end
	local target = {}
	for _, entry in ipairs(source) do
		local copied = CopyScalarFields(entry, itemFields)
		if copied then
			target[#target + 1] = copied
		end
	end
	return #target > 0 and target or nil
end

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

local function AddTransferProfessionLink(links, professionID, link)
	professionID = tonumber(professionID)
	if professionID and type(link) == "string" and link ~= "" then
		links[tostring(professionID)] = links[tostring(professionID)] or link
	end
end

local function CopyTransferProfessionLinks(AF, db, characterName, profile)
	local links = CopyCharacterLinks(db, characterName)
	for professionKey, profession in pairs(profile and profile.professions or {}) do
		if type(profession) == "table" then
			AddTransferProfessionLink(links, AF:GetSupportedProfessionID(professionKey, profession), profession.professionLink)
		end
	end
	for _, item in pairs(profile and profile.items or {}) do
		if type(item) == "table" then
			AddTransferProfessionLink(links, AF:GetSupportedProfessionID(item.professionID, item), item.professionLink)
		end
	end
	return links
end

local function CopyProfessionTransferEntry(professionID, profession, professionLinks)
	local entry = CopyScalarFields(profession, {
		"parentProfessionID",
		"baseProfessionID",
		"skillLineID",
		"childProfessionID",
		"icon",
		"scanSignature",
		"scanMode",
		"scannedAt",
		"updatedAt",
	}) or {}
	entry.id = professionID
	entry.professionLink = professionLinks and professionLinks[tostring(professionID)] or entry.professionLink
	return entry
end

local function CopyReagentList(source)
	return CopyScalarArray(source, {
		"kind",
		"itemID",
		"currencyID",
		"quantity",
		"quality",
		"dataSlotIndex",
		"slotText",
		"difficultyAdjustment",
		"difficultyDelta",
		"skillDelta",
		"optional",
	})
end

local function CopyOptionalDeltaMap(source)
	if type(source) ~= "table" then
		return nil
	end
	local target = {}
	for itemID, delta in pairs(source) do
		local copied = CopyScalarFields(delta, { "difficultyDelta", "skillDelta" })
		if copied then
			target[itemID] = copied
		end
	end
	return next(target) and target or nil
end

local function BuildOptionalDeltaMapFromWire(wire)
	local target = {}
	for _, reagent in ipairs(type(wire) == "table" and type(wire.o) == "table" and wire.o or {}) do
		local itemID = tonumber(reagent.m)
		if itemID then
			local difficultyDelta = tonumber(reagent.d)
			local skillDelta = tonumber(reagent.k)
			if difficultyDelta ~= nil or skillDelta ~= nil then
				target[itemID] = {
					difficultyDelta = difficultyDelta,
					skillDelta = skillDelta,
				}
			end
		end
	end
	return next(target) and target or nil
end

local function BuildCompactReagentSkillFacts(AF, item)
	local facts = type(item) == "table" and item.reagentSkillFacts or nil
	if type(facts) ~= "table" then
		return nil, nil, CopyOptionalDeltaMap(item and item.compactOptionalReagentDeltas)
	end
	local scanModelVersion = tonumber(facts.scanModelVersion)
	if scanModelVersion ~= tonumber(AF.SCAN_MODEL_VERSION or 2) then
		return nil, nil, CopyOptionalDeltaMap(item.compactOptionalReagentDeltas)
	end

	local wireFacts = type(item.wireReagentSkillFacts) == "table" and item.wireReagentSkillFacts or nil
	if type(AF.BuildWireReagentSkillFacts) == "function" and facts.compact ~= true then
		local ok, builtWireFacts = pcall(AF.BuildWireReagentSkillFacts, AF, facts)
		if ok and type(builtWireFacts) == "table" then
			wireFacts = builtWireFacts
		end
	end

	local compactFacts = {
		scanModelVersion = scanModelVersion,
		baseSkill = tonumber(facts.baseSkill) or tonumber(item.totalSkill) or 0,
		baseRecipeDifficulty = tonumber(facts.baseRecipeDifficulty) or tonumber(item.recipeDifficulty) or 0,
		maxOutputQuality = tonumber(facts.maxOutputQuality) or tonumber(item.maxOutputQuality) or 0,
		compact = true,
	}
	return compactFacts, wireFacts, BuildOptionalDeltaMapFromWire(wireFacts) or CopyOptionalDeltaMap(item.compactOptionalReagentDeltas)
end

local function CopyItemTransferEntry(AF, item, professionID)
	local entry = CopyScalarFields(item, {
		"itemID",
		"recipeID",
		"recipeDifficulty",
		"totalSkill",
		"quality",
		"concentrationQuality",
		"bestQuality",
		"bestConcentrationQuality",
		"bestTotalSkill",
		"bestReagentTruncated",
		"bestReagentPendingNames",
		"optionalDifficultyDelta",
		"optionalQuality",
		"optionalConcentrationQuality",
		"optionalSlotCount",
		"optionalBestReagentTruncated",
		"priceCopper",
		"freeCommission",
		"commissionSpecified",
		"note",
		"updatedAt",
	}) or {}
	entry.professionID = professionID or entry.professionID
	entry.bestReagents = CopyReagentList(item.bestReagents)
	entry.optionalReagents = CopyReagentList(item.optionalReagents)
	entry.optionalBestReagents = CopyReagentList(item.optionalBestReagents)
	entry.reagentSkillFacts, entry.wireReagentSkillFacts, entry.compactOptionalReagentDeltas = BuildCompactReagentSkillFacts(AF, item)
	return entry
end

local function CopyProfessionPriceEntry(entry)
	return CopyScalarFields(entry, {
		"priceCopper",
		"freeCommission",
		"commissionSpecified",
		"note",
		"updatedAt",
	})
end

local function CopyProfessionSettings(settings)
	local target = {}
	for professionKey, value in pairs(settings or {}) do
		local valueType = type(value)
		if valueType == "boolean" or valueType == "number" or valueType == "string" then
			target[professionKey] = value
		end
	end
	return next(target) and target or nil
end

local function CopyProfileForTransfer(AF, profile, professionLinks)
	local exportProfile = {
		professions = {},
		items = {},
		professionPrices = {},
	}
	for professionKey, profession in pairs(profile.professions or {}) do
		if type(profession) == "table" then
			local professionID = AF:GetSupportedProfessionID(professionKey, profession)
			if professionID then
				exportProfile.professions[tostring(professionID)] = CopyProfessionTransferEntry(professionID, profession, professionLinks)
			end
		end
	end
	for itemKey, item in pairs(profile.items or {}) do
		if type(item) == "table" then
			local professionID = AF:GetSupportedProfessionID(item.professionID, item)
			if professionID then
				local professionKey = tostring(professionID)
				exportProfile.items[itemKey] = CopyItemTransferEntry(AF, item, professionID)
				if not exportProfile.professions[professionKey] then
					exportProfile.professions[professionKey] = CopyProfessionTransferEntry(professionID, {}, professionLinks)
				end
			end
		end
	end
	for professionKey, entry in pairs(profile.professionPrices or {}) do
		local professionID = AF:GetSupportedProfessionID(professionKey)
		local copied = professionID and type(entry) == "table" and CopyProfessionPriceEntry(entry) or nil
		if copied then
			exportProfile.professionPrices[tostring(professionID)] = copied
		end
	end
	return exportProfile
end

local function SetPackedField(record, key, value)
	if value ~= nil and value ~= false then
		record[key] = value
	end
end

local function PackCommission(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local packed = {}
	local priceCopper = tonumber(entry.priceCopper)
	if entry.freeCommission == true then
		packed.f = true
	elseif priceCopper and priceCopper > 0 then
		packed.p = priceCopper
	end
	if type(entry.note) == "string" and entry.note ~= "" then
		packed.n = entry.note
	end
	return next(packed) and packed or nil
end

local function UnpackCommission(target, packed)
	if type(target) ~= "table" or type(packed) ~= "table" then
		return
	end
	if packed.f == true then
		target.priceCopper = 0
		target.freeCommission = true
		target.commissionSpecified = true
	elseif tonumber(packed.p) then
		target.priceCopper = tonumber(packed.p)
		target.commissionSpecified = true
	end
	if type(packed.n) == "string" and packed.n ~= "" then
		target.note = packed.n
	end
end

local function PackProfession(profession)
	if type(profession) ~= "table" or not profession.id then
		return nil
	end
	local packed = { profession.id }
	SetPackedField(packed, "p", profession.parentProfessionID)
	SetPackedField(packed, "b", profession.baseProfessionID)
	SetPackedField(packed, "s", profession.skillLineID)
	SetPackedField(packed, "c", profession.childProfessionID)
	SetPackedField(packed, "i", profession.icon)
	SetPackedField(packed, "g", profession.scanSignature)
	SetPackedField(packed, "m", profession.scanMode)
	SetPackedField(packed, "a", profession.scannedAt)
	SetPackedField(packed, "u", profession.updatedAt)
	return packed
end

local function UnpackProfession(packed)
	if type(packed) ~= "table" or not tonumber(packed[1]) then
		return nil
	end
	return {
		id = tonumber(packed[1]),
		parentProfessionID = packed.p,
		baseProfessionID = packed.b,
		skillLineID = packed.s,
		childProfessionID = packed.c,
		icon = packed.i,
		scanSignature = packed.g,
		scanMode = packed.m,
		scannedAt = packed.a,
		updatedAt = packed.u,
	}
end

local function PackReagent(reagent)
	if type(reagent) ~= "table" then
		return nil
	end
	local packed = {}
	SetPackedField(packed, 1, reagent.itemID)
	SetPackedField(packed, "c", reagent.currencyID)
	local quantity = tonumber(reagent.quantity)
	if quantity and quantity ~= 1 then
		packed.n = quantity
	end
	SetPackedField(packed, "q", reagent.quality)
	SetPackedField(packed, "x", reagent.dataSlotIndex)
	SetPackedField(packed, "t", reagent.slotText)
	SetPackedField(packed, "d", reagent.difficultyAdjustment)
	SetPackedField(packed, "D", reagent.difficultyDelta)
	SetPackedField(packed, "s", reagent.skillDelta)
	if reagent.optional == true then
		packed.o = true
	end
	return next(packed) and packed or nil
end

local function UnpackReagent(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local reagent = {
		kind = packed.c and "currency" or "item",
		itemID = packed[1],
		currencyID = packed.c,
		quantity = tonumber(packed.n) or 1,
		quality = packed.q,
		dataSlotIndex = packed.x,
		slotText = packed.t,
		difficultyAdjustment = packed.d,
		difficultyDelta = packed.D,
		skillDelta = packed.s,
		optional = packed.o == true or nil,
	}
	if reagent.itemID == nil and reagent.currencyID == nil then
		return nil
	end
	return reagent
end

local function PackReagentListForTransfer(reagents)
	if type(reagents) ~= "table" then
		return nil
	end
	local packed = {}
	for _, reagent in ipairs(reagents) do
		local packedReagent = PackReagent(reagent)
		if packedReagent then
			packed[#packed + 1] = packedReagent
		end
	end
	return #packed > 0 and packed or nil
end

local function UnpackReagentList(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local reagents = {}
	for _, packedReagent in ipairs(packed) do
		local reagent = UnpackReagent(packedReagent)
		if reagent then
			reagents[#reagents + 1] = reagent
		end
	end
	return #reagents > 0 and reagents or nil
end

local function PackOptionalDeltas(deltas)
	if type(deltas) ~= "table" then
		return nil
	end
	local packed = {}
	for itemID, delta in pairs(deltas) do
		if type(delta) == "table" then
			local entry = { tonumber(itemID) or itemID }
			SetPackedField(entry, "d", delta.difficultyDelta)
			SetPackedField(entry, "s", delta.skillDelta)
			if entry.d ~= nil or entry.s ~= nil then
				packed[#packed + 1] = entry
			end
		end
	end
	return #packed > 0 and packed or nil
end

local function UnpackOptionalDeltas(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local deltas = {}
	for _, entry in ipairs(packed) do
		local itemID = type(entry) == "table" and entry[1] or nil
		if itemID then
			deltas[itemID] = {
				difficultyDelta = entry.d,
				skillDelta = entry.s,
			}
		end
	end
	return next(deltas) and deltas or nil
end

local function PackCompactFacts(facts)
	if type(facts) ~= "table" then
		return nil
	end
	return {
		tonumber(facts.scanModelVersion) or 0,
		tonumber(facts.baseSkill) or 0,
		tonumber(facts.baseRecipeDifficulty) or 0,
		tonumber(facts.maxOutputQuality) or 0,
	}
end

local function UnpackCompactFacts(packed, wire)
	local scanModelVersion = wire and tonumber(wire.v) or type(packed) == "table" and tonumber(packed[1])
	local baseSkill = wire and tonumber(wire.s) or type(packed) == "table" and tonumber(packed[2])
	local baseRecipeDifficulty = wire and tonumber(wire.d) or type(packed) == "table" and tonumber(packed[3])
	local maxOutputQuality = wire and tonumber(wire.q) or type(packed) == "table" and tonumber(packed[4])
	if not scanModelVersion or not baseSkill or not baseRecipeDifficulty or not maxOutputQuality then
		return nil
	end
	return {
		scanModelVersion = scanModelVersion,
		baseSkill = baseSkill,
		baseRecipeDifficulty = baseRecipeDifficulty,
		maxOutputQuality = maxOutputQuality,
		compact = true,
	}
end

local function PackItem(itemKey, item)
	if type(item) ~= "table" then
		return nil
	end
	local packed = { tostring(itemKey or item.itemID or "") }
	if tonumber(item.itemID) ~= tonumber(packed[1]) then
		SetPackedField(packed, "i", item.itemID)
	end
	SetPackedField(packed, "r", item.recipeID)
	SetPackedField(packed, "p", item.professionID)
	SetPackedField(packed, "d", item.recipeDifficulty)
	SetPackedField(packed, "s", item.totalSkill)
	SetPackedField(packed, "q", item.quality)
	SetPackedField(packed, "c", item.concentrationQuality)
	SetPackedField(packed, "b", item.bestQuality)
	SetPackedField(packed, "B", item.bestConcentrationQuality)
	SetPackedField(packed, "t", item.bestTotalSkill)
	SetPackedField(packed, "R", PackReagentListForTransfer(item.bestReagents))
	if item.bestReagentTruncated == true then
		packed.T = true
	end
	if item.bestReagentPendingNames == true then
		packed.P = true
	end
	SetPackedField(packed, "D", item.optionalDifficultyDelta)
	SetPackedField(packed, "Q", item.optionalQuality)
	SetPackedField(packed, "C", item.optionalConcentrationQuality)
	SetPackedField(packed, "S", item.optionalSlotCount)
	SetPackedField(packed, "A", PackReagentListForTransfer(item.optionalReagents))
	SetPackedField(packed, "O", PackReagentListForTransfer(item.optionalBestReagents))
	if item.optionalBestReagentTruncated == true then
		packed.U = true
	end
	if type(item.wireReagentSkillFacts) == "table" then
		packed.w = item.wireReagentSkillFacts
	else
		SetPackedField(packed, "f", PackCompactFacts(item.reagentSkillFacts))
		SetPackedField(packed, "o", PackOptionalDeltas(item.compactOptionalReagentDeltas))
	end
	SetPackedField(packed, "m", PackCommission(item))
	SetPackedField(packed, "u", item.updatedAt)
	return packed
end

local function UnpackItem(packed)
	if type(packed) ~= "table" then
		return nil, nil
	end
	local itemKey = tostring(packed[1] or packed.i or "")
	if itemKey == "" then
		return nil, nil
	end
	local item = {
		itemID = packed.i or tonumber(itemKey),
		recipeID = packed.r,
		professionID = packed.p,
		recipeDifficulty = packed.d,
		totalSkill = packed.s,
		quality = packed.q,
		concentrationQuality = packed.c,
		bestQuality = packed.b,
		bestConcentrationQuality = packed.B,
		bestTotalSkill = packed.t,
		bestReagents = UnpackReagentList(packed.R),
		bestReagentTruncated = packed.T == true or nil,
		bestReagentPendingNames = packed.P == true or nil,
		optionalDifficultyDelta = packed.D,
		optionalQuality = packed.Q,
		optionalConcentrationQuality = packed.C,
		optionalSlotCount = packed.S,
		optionalReagents = UnpackReagentList(packed.A),
		optionalBestReagents = UnpackReagentList(packed.O),
		optionalBestReagentTruncated = packed.U == true or nil,
		wireReagentSkillFacts = type(packed.w) == "table" and packed.w or nil,
		compactOptionalReagentDeltas = BuildOptionalDeltaMapFromWire(packed.w) or UnpackOptionalDeltas(packed.o),
		updatedAt = packed.u,
	}
	item.reagentSkillFacts = UnpackCompactFacts(packed.f, item.wireReagentSkillFacts)
	if item.reagentSkillFacts then
		item.scanModelVersion = item.reagentSkillFacts.scanModelVersion
		item.maxOutputQuality = item.reagentSkillFacts.maxOutputQuality
	end
	UnpackCommission(item, packed.m)
	return itemKey, item
end

local function PackProfessionPrice(professionID, entry)
	local packed = PackCommission(entry)
	if not packed then
		return nil
	end
	packed[1] = professionID
	SetPackedField(packed, "u", entry.updatedAt)
	return packed
end

local function UnpackProfessionPrice(packed)
	if type(packed) ~= "table" or not packed[1] then
		return nil, nil
	end
	local entry = {}
	UnpackCommission(entry, packed)
	entry.updatedAt = packed.u
	return tostring(packed[1]), next(entry) and entry or nil
end

local function PackSettings(settings)
	if type(settings) ~= "table" then
		return nil
	end
	local packed = {}
	for professionID, value in pairs(settings) do
		if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
			packed[#packed + 1] = { professionID, value }
		end
	end
	return #packed > 0 and packed or nil
end

local function UnpackSettings(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local settings = {}
	for _, entry in ipairs(packed) do
		if type(entry) == "table" and entry[1] ~= nil then
			settings[tostring(entry[1])] = entry[2]
		end
	end
	return next(settings) and settings or nil
end

local function PackProfessionLinks(links)
	if type(links) ~= "table" then
		return nil
	end
	local packed = {}
	for professionID, link in pairs(links) do
		if type(link) == "string" and link ~= "" then
			packed[#packed + 1] = { professionID, link }
		end
	end
	return #packed > 0 and packed or nil
end

local function UnpackProfessionLinks(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local links = {}
	for _, entry in ipairs(packed) do
		if type(entry) == "table" and entry[1] ~= nil and type(entry[2]) == "string" then
			links[tostring(entry[1])] = entry[2]
		end
	end
	return next(links) and links or nil
end

local function PackProfile(profile)
	local packed = {}
	local professions = {}
	for _, profession in pairs(profile.professions or {}) do
		local packedProfession = PackProfession(profession)
		if packedProfession then
			professions[#professions + 1] = packedProfession
		end
	end
	if #professions > 0 then
		packed[1] = professions
	end
	local items = {}
	for itemKey, item in pairs(profile.items or {}) do
		local packedItem = PackItem(itemKey, item)
		if packedItem then
			items[#items + 1] = packedItem
		end
	end
	if #items > 0 then
		packed[2] = items
	end
	local prices = {}
	for professionID, entry in pairs(profile.professionPrices or {}) do
		local packedPrice = PackProfessionPrice(professionID, entry)
		if packedPrice then
			prices[#prices + 1] = packedPrice
		end
	end
	if #prices > 0 then
		packed[3] = prices
	end
	return packed
end

local function UnpackProfile(packed)
	if type(packed) ~= "table" then
		return nil
	end
	local profile = {
		professions = {},
		items = {},
		professionPrices = {},
	}
	for _, packedProfession in ipairs(packed[1] or {}) do
		local profession = UnpackProfession(packedProfession)
		if profession and profession.id then
			profile.professions[tostring(profession.id)] = profession
		end
	end
	for _, packedItem in ipairs(packed[2] or {}) do
		local itemKey, item = UnpackItem(packedItem)
		if itemKey and item then
			profile.items[itemKey] = item
		end
	end
	for _, packedPrice in ipairs(packed[3] or {}) do
		local professionID, entry = UnpackProfessionPrice(packedPrice)
		if professionID and entry then
			profile.professionPrices[professionID] = entry
		end
	end
	return profile
end

local function PackTransferEnvelope(schemaVersion, artisans)
	local packedArtisans = {}
	for characterName, transfer in pairs(artisans or {}) do
		local packedArtisan = {
			characterName,
			PackProfile(transfer.profile),
		}
		SetPackedField(packedArtisan, "a", PackSettings(transfer.advertising))
		SetPackedField(packedArtisan, "k", PackSettings(transfer.advertisingKnown))
		SetPackedField(packedArtisan, "l", PackProfessionLinks(transfer.professionLinks))
		packedArtisans[#packedArtisans + 1] = packedArtisan
	end
	return {
		TRANSFER_VERSION,
		schemaVersion,
		packedArtisans,
	}
end

local function UnpackTransferEnvelope(packed)
	if type(packed) ~= "table" or tonumber(packed[1]) ~= TRANSFER_VERSION then
		return nil, "version"
	end
	if type(packed[3]) ~= "table" then
		return nil, "malformed"
	end
	local envelope = {
		format = TRANSFER_FORMAT,
		version = TRANSFER_VERSION,
		schemaVersion = packed[2],
		artisans = {},
	}
	for _, packedArtisan in ipairs(packed[3]) do
		if type(packedArtisan) ~= "table" or type(packedArtisan[1]) ~= "string" then
			return nil, "malformed"
		end
		local profile = UnpackProfile(packedArtisan[2])
		if not profile then
			return nil, "malformed"
		end
		local professionLinks = UnpackProfessionLinks(packedArtisan.l)
		for professionID, link in pairs(professionLinks or {}) do
			local profession = profile.professions and profile.professions[tostring(professionID)]
			if profession and profession.professionLink == nil then
				profession.professionLink = link
			end
		end
		envelope.artisans[packedArtisan[1]] = {
			profile = profile,
			advertising = UnpackSettings(packedArtisan.a),
			advertisingKnown = UnpackSettings(packedArtisan.k),
			professionLinks = professionLinks,
		}
	end
	return envelope
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

local LEGACY_PROFESSION_FIELDS = {
	"name",
	"recipes",
	"scanProgress",
	"equipmentSignature",
	"bestProfessionSkillTotals",
	"bestProfessionSkillAt",
}

local LEGACY_ITEM_FIELDS = {
	"itemName",
	"recipeName",
	"professionName",
	"professionLink",
	"bestReagentSummary",
	"bestReagentDetails",
	"bestReagentSummaryUpdatedAt",
	"optionalReagentSummary",
	"optionalBestReagentSummaryUpdatedAt",
	"debugBestCandidateSummary",
	"debugBestCandidateQuality",
	"debugBestCandidateAtlas",
	"debugBestCandidateRawQuality",
	"debugBestCandidateAccepted",
	"debugBestCandidateOperation",
	"debugBestCandidateReason",
	"skillProbeSignature",
	"fullScanSignature",
}

local function HasAnyField(tbl, fields)
	if type(tbl) ~= "table" then
		return false
	end
	for _, fieldName in ipairs(fields) do
		if tbl[fieldName] ~= nil then
			return true
		end
	end
	return false
end

local function IsSlimReagentFactsValid(facts)
	if facts == nil then
		return true
	end
	if type(facts) ~= "table" or facts.compact ~= true then
		return false
	end
	if facts.requiredSlots ~= nil and (type(facts.requiredSlots) ~= "table" or next(facts.requiredSlots) ~= nil) then
		return false
	end
	if facts.optionalSlots ~= nil and (type(facts.optionalSlots) ~= "table" or next(facts.optionalSlots) ~= nil) then
		return false
	end
	return tonumber(facts.scanModelVersion) ~= nil
		and tonumber(facts.baseSkill) ~= nil
		and tonumber(facts.baseRecipeDifficulty) ~= nil
		and tonumber(facts.maxOutputQuality) ~= nil
end

local function IsSlimTransferProfileValid(profile)
	if type(profile) ~= "table" or profile.characterName ~= nil then
		return false
	end
	for _, profession in pairs(profile.professions or {}) do
		if type(profession) ~= "table" or HasAnyField(profession, LEGACY_PROFESSION_FIELDS) then
			return false
		end
	end
	for _, item in pairs(profile.items or {}) do
		if type(item) ~= "table" or HasAnyField(item, LEGACY_ITEM_FIELDS) or not IsSlimReagentFactsValid(item.reagentSkillFacts) then
			return false
		end
	end
	return true
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
		and IsSlimTransferProfileValid(profile)
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
			local professionLinks = CopyTransferProfessionLinks(self, self.db, characterName, profile)
			artisans[characterName] = {
				profile = CopyProfileForTransfer(self, profile, professionLinks),
				advertising = CopyProfessionSettings(self.db.advertising and self.db.advertising[characterName]),
				advertisingKnown = CopyProfessionSettings(self.db.advertisingKnown and self.db.advertisingKnown[characterName]),
				professionLinks = professionLinks,
			}
		end
	end)

	local envelope = PackTransferEnvelope(self.SCHEMA_VERSION, artisans)
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
	local unpackedEnvelope, unpackError = UnpackTransferEnvelope(envelope)
	if not unpackedEnvelope and unpackError == "version" then
		return nil, self:Text("TRANSFER_ERROR_VERSION")
	end
	if not unpackedEnvelope then
		return nil, self:Text("TRANSFER_ERROR_MALFORMED")
	end
	if (tonumber(unpackedEnvelope.schemaVersion) or 0) > self.SCHEMA_VERSION then
		return nil, self:Text("TRANSFER_ERROR_FUTURE_SCHEMA", tonumber(unpackedEnvelope.schemaVersion) or 0, self.SCHEMA_VERSION)
	end
	if type(unpackedEnvelope.artisans) ~= "table" then
		return nil, self:Text("TRANSFER_ERROR_MALFORMED")
	end
	return unpackedEnvelope, nil
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
