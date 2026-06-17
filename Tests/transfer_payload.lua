local AF = {
	SCHEMA_VERSION = 17,
	SCAN_MODEL_VERSION = 5,
}
local LoadFile = rawget(_G, "loadfile")

local function Check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function LoadAddonFile(path)
	local chunk, err = LoadFile(path)
	Check(chunk, err)
	return chunk("ArtisanFinder", AF)
end

local capturedEnvelope
local decodedEnvelope
local decodeCalls = 0
local serializer = {
	Serialize = function(_, envelope)
		capturedEnvelope = envelope
		return "serialized"
	end,
	Deserialize = function(_, serialized)
		return serialized == "serialized", decodedEnvelope
	end,
}
local deflater = {
	CompressDeflate = function(_, serialized)
		return serialized
	end,
	EncodeForPrint = function(_, compressed)
		return compressed == "serialized" and "encoded" or nil
	end,
	DecodeForPrint = function(_, encoded)
		decodeCalls = decodeCalls + 1
		return encoded == "encoded" and "serialized" or nil
	end,
	DecompressDeflate = function(_, decoded)
		return decoded
	end,
}

LibStub = {
	GetLibrary = function(_, name)
		if name == "LibSerialize" then
			return serializer
		end
		if name == "LibDeflate" then
			return deflater
		end
		return nil
	end,
}

local professionLink = "trade:profession:164:very-long-link"
local profile = {
	characterName = "Crafter-Realm",
	professions = {
		["164"] = {
			id = 164,
			name = "Blacksmithing",
			icon = 123,
			professionLink = professionLink,
			recipes = {
				["100"] = true,
				["101"] = true,
			},
			scanSignature = "37|164|abc",
			scanMode = "full",
			scannedAt = 1000,
			updatedAt = 1001,
			scanProgress = {
				pending = {
					{ key = "full:100:2000", recipeID = 100, itemID = 2000 },
				},
				completed = {
					["full:100:2000"] = true,
				},
			},
			equipmentSignature = "equipped:volatile",
			bestProfessionSkillTotals = {
				main = 425,
			},
			bestProfessionSkillAt = 990,
		},
	},
	items = {
		["2000"] = {
			itemID = 2000,
			recipeID = 100,
			professionID = 164,
			itemName = "Localized Item",
			recipeName = "Localized Recipe",
			professionName = "Localized Profession",
			professionLink = professionLink,
			recipeDifficulty = 400,
			totalSkill = 425,
			quality = 4,
			rawQuality = 4,
			concentrationQuality = nil,
			concentrationCost = 123,
			outputItemLevel = 650,
			bestQuality = 5,
			rawBestQuality = 5,
			bestConcentrationCost = 456,
			bestOutputItemLevel = 660,
			bestTotalSkill = 575,
			bestReagents = {
				{
					kind = "item",
					itemID = 3000,
					quantity = 1,
					quality = 3,
					qualityAtlas = "Professions-Icon-Quality-Tier3",
					link = "|Hitem:3000|h[Localized]|h",
					icon = 999,
				},
			},
			bestReagentSummary = "localized summary",
			bestReagentDetails = "localized details",
			bestReagentSummaryUpdatedAt = 999,
			bestReagentTruncated = false,
			bestReagentPendingNames = false,
			debugBestCandidateSummary = "debug",
			skillProbeSignature = "SP1:100",
			fullScanSignature = "FS4:100:2000",
			scanModelVersion = 5,
			maxOutputQuality = 5,
			reagentSkillFacts = {
				scanModelVersion = 5,
				baseSkill = 425,
				baseRecipeDifficulty = 400,
				maxOutputQuality = 5,
				requiredSlots = {
					{
						slotIndex = 1,
						reagents = {
							{ itemID = 3000, quality = 3, link = "localized", icon = 999 },
						},
						qualityBonuses = {
							[3] = 10,
						},
					},
				},
				optionalSlots = {},
				debugScanStats = {
					evaluated = 1000,
				},
			},
			optionalOutputItemLevel = 670,
			optionalOutputItemLevelDelta = 20,
			optionalBestReagentTruncated = false,
			priceCopper = 50000,
			freeCommission = false,
			commissionSpecified = true,
			note = "bring mats",
			updatedAt = 1002,
		},
	},
	professionPrices = {
		["164"] = {
			priceCopper = 25000,
			freeCommission = false,
			commissionSpecified = true,
			note = "profession default",
			updatedAt = 1003,
			debug = "drop me",
		},
	},
}

AF.db = {
	advertising = {
		["Crafter-Realm"] = {
			["164"] = false,
			debug = {},
		},
	},
	advertisingKnown = {
		["Crafter-Realm"] = {
			["164"] = true,
		},
	},
	professionLinks = {
		["Crafter-Realm:164"] = professionLink,
	},
}

function AF:NormalizeName(name)
	return name
end

function AF:Now()
	return 12345
end

function AF:Text(key)
	return key
end

function AF:IsArtisanProfileEmpty(candidate)
	return next(candidate.professions or {}) == nil
		and next(candidate.items or {}) == nil
		and next(candidate.professionPrices or {}) == nil
end

function AF:ForEachArtisanProfile(callback)
	callback("Crafter-Realm", profile)
end

function AF:GetSupportedProfessionID(professionID, entry)
	local id = tonumber(entry and (entry.parentProfessionID or entry.baseProfessionID or entry.id) or professionID)
	return id == 164 and 164 or nil
end

function AF:BuildWireReagentSkillFacts(facts)
	return {
		w = 2,
		v = facts.scanModelVersion,
		s = facts.baseSkill,
		d = facts.baseRecipeDifficulty,
		q = facts.maxOutputQuality,
		b = {
			{ i = 1, n = 1, t = { [3] = 10 } },
		},
		o = {
			{ m = 4000, d = 73 },
		},
	}
end

LoadAddonFile("Core/Transfer.lua")

local function FindPackedArtisan(envelope, characterName)
	for _, artisan in ipairs(envelope[3] or {}) do
		if artisan[1] == characterName then
			return artisan
		end
	end
	return nil
end

local payload, err = AF:BuildArtisanTransferPayload()
Check(payload == "AFART3:encoded", "payload should be encoded with transfer prefix")
Check(err == nil, "export should not fail")
Check(capturedEnvelope and capturedEnvelope[1] == 3, "serializer should receive packed v3 envelope")
Check(capturedEnvelope[2] == AF.SCHEMA_VERSION, "schema version should be positional")
Check(type(capturedEnvelope[3]) == "table", "artisan list should be positional")
Check(capturedEnvelope.format == nil, "format string should not be exported")
Check(capturedEnvelope.version == nil, "verbose version key should not be exported")
Check(capturedEnvelope.profileFormat == nil, "profileFormat should not be exported")
Check(capturedEnvelope.exportedAt == nil, "exportedAt should not be exported")
Check(capturedEnvelope.artisans == nil, "verbose artisan map should not be exported")

local packedArtisan = FindPackedArtisan(capturedEnvelope, "Crafter-Realm")
if not packedArtisan then
	error("artisan should be exported", 2)
end
Check(packedArtisan[2] ~= profile, "export should copy profile, not reuse saved table")
local packedAdvertising = type(packedArtisan.a) == "table" and packedArtisan.a[1] or nil
local packedKnownAdvertising = type(packedArtisan.k) == "table" and packedArtisan.k[1] or nil
local packedProfessionLink = type(packedArtisan.l) == "table" and packedArtisan.l[1] or nil
Check(type(packedAdvertising) == "table" and packedAdvertising[1] == "164" and packedAdvertising[2] == false, "advertising should keep scalar settings only")
Check(type(packedKnownAdvertising) == "table" and packedKnownAdvertising[1] == "164" and packedKnownAdvertising[2] == true, "known advertising should be packed")
Check(type(packedProfessionLink) == "table" and packedProfessionLink[1] == "164" and packedProfessionLink[2] == professionLink, "profession link should be exported once per profession")

local packedProfile = packedArtisan[2]
if type(packedProfile) ~= "table" then
	error("packed profile should be table", 2)
end
local packedProfession = packedProfile[1][1]
Check(packedProfession[1] == 164 and packedProfession.i == 123, "profession identity should be preserved")
Check(packedProfession.l == nil, "profession link should not be duplicated on profession row")
Check(packedProfession.g == "37|164|abc" and packedProfession.a == 1000, "scan freshness metadata should remain")
Check(packedProfession.recipes == nil, "recipe set should be removed as derivable")
Check(packedProfession.name == nil, "localized profession name should be removed")
Check(packedProfession.scanProgress == nil, "runtime scan progress should be removed")
Check(packedProfession.equipmentSignature == nil, "equipment signature should be removed")
Check(packedProfession.bestProfessionSkillTotals == nil, "equipment skill totals should be removed")

local packedItem = packedProfile[2][1]
Check(packedItem[1] == "2000" and packedItem.i == nil, "item key should carry item id")
Check(packedItem.r == 100 and packedItem.p == 164, "item identity should remain with short keys")
Check(packedItem.itemName == nil and packedItem.recipeName == nil and packedItem.professionName == nil, "localized item fields should be removed")
Check(packedItem.professionLink == nil, "per-item profession link should be deduped")
Check(packedItem.bestReagentSummary == nil and packedItem.bestReagentDetails == nil, "localized reagent text should be removed")
Check(packedItem.debugBestCandidateSummary == nil, "debug fields should be removed")
Check(packedItem.skillProbeSignature == nil and packedItem.fullScanSignature == nil, "derivable scan signatures should be removed")
Check(packedItem.rawQuality == nil and packedItem.rawBestQuality == nil, "raw quality fields should not export")
Check(packedItem.concentrationCost == nil and packedItem.bestConcentrationCost == nil, "concentration cost fields should not export")
Check(packedItem.outputItemLevel == nil and packedItem.bestOutputItemLevel == nil, "item level fields should not export")
Check(packedItem.optionalOutputItemLevel == nil and packedItem.optionalOutputItemLevelDelta == nil, "optional item level fields should not export")
Check(packedItem.scanModelVersion == nil and packedItem.maxOutputQuality == nil, "duplicate item model fields should not export")
Check(packedItem.freeCommission == nil and packedItem.commissionSpecified == nil, "verbose commission booleans should not export")
Check(packedItem.T == nil and packedItem.P == nil and packedItem.U == nil, "false reagent booleans should be omitted")
Check(packedItem.f == nil and packedItem.w and packedItem.w.v == 5, "wire facts should be exported with short keys")
Check(packedItem.w.b[1].t[3] == 10, "wire facts should preserve skill deltas")
Check(packedItem.o == nil, "optional deltas should not duplicate wire optional facts")
Check(packedItem.m and packedItem.m.p == 50000 and packedItem.m.f == nil, "commission should be packed by price")
Check(packedItem.R[1][1] == 3000 and packedItem.R[1].q == 3, "reagent list should keep IDs and quality")
Check(packedItem.R[1].n == nil and packedItem.R[1].kind == nil, "default quantity and kind should be omitted")
Check(packedItem.R[1].qualityAtlas == nil and packedItem.R[1].link == nil and packedItem.R[1].icon == nil, "reagent UI fields should be removed")

local packedPrice = packedProfile[3][1]
Check(packedPrice[1] == "164" and packedPrice.p == 25000, "profession price should use compact price row")
Check(packedPrice.f == nil and packedPrice.commissionSpecified == nil, "false/default profession price booleans should be omitted")
Check(profile.professions["164"].scanProgress ~= nil, "source profession should not be mutated")
Check(profile.items["2000"].reagentSkillFacts.requiredSlots[1].reagents[1].link == "localized", "source facts should not be mutated")

decodeCalls = 0
local oldEnvelope, oldError = AF:DecodeArtisanTransferPayload("AFART2:encoded")
Check(oldEnvelope == nil and oldError == "TRANSFER_ERROR_PREFIX", "old AFART2 exports should be rejected before decode")
Check(decodeCalls == 0, "old AFART2 exports should not be decompressed")

decodedEnvelope = { 2, AF.SCHEMA_VERSION, {} }
local wrongVersionEnvelope, wrongVersionError = AF:DecodeArtisanTransferPayload("AFART3:encoded")
Check(wrongVersionEnvelope == nil and wrongVersionError == "TRANSFER_ERROR_VERSION", "wrong packed version should be rejected")
Check(decodeCalls == 1, "current prefix should reach decode path")

decodedEnvelope = {
	format = "ArtisanFinderArtisans",
	version = 3,
	schemaVersion = AF.SCHEMA_VERSION,
	artisans = {},
}
local namedEnvelope, namedError = AF:DecodeArtisanTransferPayload("AFART3:encoded")
Check(namedEnvelope == nil and namedError == "TRANSFER_ERROR_VERSION", "named legacy envelope should be rejected")

decodedEnvelope = capturedEnvelope
local slimEnvelope, slimError = AF:DecodeArtisanTransferPayload("AFART3:encoded")
Check(slimEnvelope and slimError == nil, "current packed envelope should decode")
local transfer = slimEnvelope.artisans["Crafter-Realm"]
Check(transfer, "decoded artisan should use name map")
Check(transfer.profile.characterName == nil, "characterName should be derived from transfer key")
Check(transfer.professionLinks["164"] == professionLink, "profession link map should decode")
Check(transfer.advertising["164"] == false, "false settings should survive decode")
local profession = transfer.profile.professions["164"]
Check(profession.id == 164 and profession.professionLink == professionLink, "profession link should be restored after decode")
local item = transfer.profile.items["2000"]
Check(item.itemID == 2000 and item.recipeID == 100 and item.professionID == 164, "item identity should round-trip")
Check(item.rawQuality == nil and item.rawBestQuality == nil, "raw quality fields should stay absent after decode")
Check(item.outputItemLevel == nil and item.bestOutputItemLevel == nil, "item level fields should stay absent after decode")
Check(item.concentrationCost == nil and item.bestConcentrationCost == nil, "concentration cost fields should stay absent after decode")
Check(item.scanModelVersion == 5 and item.maxOutputQuality == 5, "item model fields should be reconstructed")
Check(item.reagentSkillFacts.compact == true, "full reagent facts should compact after decode")
Check(item.reagentSkillFacts.requiredSlots == nil and item.reagentSkillFacts.optionalSlots == nil, "compact facts should not embed empty slot skeleton")
Check(item.wireReagentSkillFacts and item.wireReagentSkillFacts.b[1].t[3] == 10, "wire facts should preserve skill deltas")
Check(item.compactOptionalReagentDeltas[4000].difficultyDelta == 73, "optional deltas should be rebuilt from wire facts")
Check(item.bestReagents[1].itemID == 3000 and item.bestReagents[1].quantity == 1, "default reagent quantity should be restored")
Check(item.freeCommission == nil and item.commissionSpecified == true, "commission should use nil false and true only when specified")
Check(item.bestReagentTruncated == nil and item.bestReagentPendingNames == nil, "false reagent booleans should import as nil")

AF.db = {
	artisanCharacters = {},
	advertising = {},
	advertisingKnown = {},
	professionLinks = {},
}
AF.playerName = "Buyer-Realm"

function AF:GetPlayerFullName()
	return "Buyer-Realm"
end

function AF:PrepareImportedArtisanProfile(candidate, characterName)
	candidate.characterName = characterName
	return candidate
end

function AF:PrepareImportedProfessionSettings(settings)
	return settings or {}
end

function AF:GetArtisanProfileEntryCount(candidate)
	local count = 0
	for _ in pairs(candidate.professions or {}) do
		count = count + 1
	end
	for _ in pairs(candidate.items or {}) do
		count = count + 1
	end
	for _ in pairs(candidate.professionPrices or {}) do
		count = count + 1
	end
	return count
end

function AF:GetProfessionLinkKey(characterName, professionID)
	return tostring(characterName) .. ":" .. tostring(professionID)
end

function AF:RefreshMainUI()
	self.refreshedMainUI = true
end

decodedEnvelope = capturedEnvelope
local summary, importError = AF:ImportArtisanTransferPayload("AFART3:encoded")
Check(importError == nil and summary ~= nil, "packed payload should import")
Check(summary.addedArtisans == 1 and summary.addedEntries == 3, "import summary should count decoded entries")
Check(AF.refreshedMainUI == true, "import should refresh UI")
local saved = AF.db.artisanCharacters["Crafter-Realm"].items["2000"]
Check(saved.scanModelVersion == 5 and saved.maxOutputQuality == 5, "import should reconstruct item scan metadata")
Check(saved.reagentSkillFacts.compact == true, "import should save compact facts")
Check(saved.reagentSkillFacts.requiredSlots == nil and saved.reagentSkillFacts.optionalSlots == nil, "import should keep compact facts skeleton-free")
Check(saved.rawQuality == nil and saved.rawBestQuality == nil, "import should not restore raw quality fields")
Check(saved.outputItemLevel == nil and saved.bestOutputItemLevel == nil, "import should not restore item level fields")
Check(saved.optionalOutputItemLevel == nil and saved.optionalOutputItemLevelDelta == nil, "import should not restore optional item level fields")
Check(saved.concentrationCost == nil and saved.bestConcentrationCost == nil, "import should not restore concentration cost fields")
Check(saved.priceCopper == 50000 and saved.commissionSpecified == true and saved.freeCommission == nil, "import should restore commission without false boolean")
Check(saved.bestReagentTruncated == nil and saved.bestReagentPendingNames == nil, "import should treat nil as false reagent state")
Check(saved.bestReagents[1].quantity == 1, "import should restore default reagent quantity")
Check(saved.compactOptionalReagentDeltas[4000].difficultyDelta == 73, "import should save optional deltas from wire facts")
Check(AF.db.artisanCharacters["Crafter-Realm"].professions["164"].professionLink == professionLink, "import should restore profession link onto profile")
Check(AF.db.professionLinks["Crafter-Realm:164"] == professionLink, "import should persist profession link map")
Check(AF.db.advertising["Crafter-Realm"]["164"] == false, "import should preserve false settings")
Check(AF.db.advertisingKnown["Crafter-Realm"]["164"] == true, "import should preserve true settings")

print("transfer payload tests: PASS")
