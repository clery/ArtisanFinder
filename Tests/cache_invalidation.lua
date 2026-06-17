local AF = {}
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

time = function()
	return 1000
end

C_Spell = {
	GetSpellName = function()
		return "Blacksmithing"
	end,
}

LoadAddonFile("Core/Bootstrap.lua")
LoadAddonFile("Locales/enUS.lua")
LoadAddonFile("Core/Util.lua")
LoadAddonFile("Utils/Formatting.lua")
LoadAddonFile("Core/Data.lua")
LoadAddonFile("Features/Customer/Cache.lua")
LoadAddonFile("Features/Customer/Recommendation.lua")

AF.playerName = "Buyer-Realm"
AF.GetRecipeQualityIconMarkup = function()
	return nil
end
AF.IsAvailable = function()
	return true
end
AF.IsNameOnConnectedRealm = function()
	return true
end
AF.IsCustomerEntryOnline = function()
	return false
end
AF.IsCustomerEntryOffline = function()
	return false
end
AF.IsDevFakeRowsEnabled = function()
	return false
end
AF.GetCachedGuildRosterEntry = function()
	return nil
end

local function NewFacts(overrides)
	local facts = {
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		recipeID = 100,
		baseSkill = 100,
		baseRecipeDifficulty = 100,
		maxOutputQuality = 5,
		requiredSlots = {},
		optionalSlots = {},
	}
	for key, value in pairs(overrides or {}) do
		facts[key] = value
	end
	return facts
end

local function NewLegacyEntry(name, overrides)
	local facts = NewFacts()
	facts.optionalSlots = nil
	local entry = {
		name = name,
		target = name,
		orderTarget = name,
		itemID = 2000,
		professionID = 164,
		recipeID = 100,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = facts,
		recipeDifficulty = 100,
		totalSkill = 100,
		quality = 5,
		bestQuality = 5,
		bestConcentrationQuality = 5,
		bestTotalSkill = 100,
		bestReagents = {
			{ itemID = 3000, quantity = 1, quality = 3 },
		},
		bestReagentSummaryUpdatedAt = 900,
		hasReagentSummary = true,
		priceCopper = 10000,
		updatedAt = 990,
	}
	for key, value in pairs(overrides or {}) do
		if value == false then
			entry[key] = nil
		else
			entry[key] = value
		end
	end
	return entry
end

local function NewStaleNoCapabilityEntry(name)
	local facts = NewFacts()
	facts.optionalSlots = nil
	return {
		name = name,
		target = name,
		orderTarget = name,
		itemID = 2000,
		professionID = 164,
		recipeID = 100,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = facts,
		priceCopper = 10000,
		updatedAt = 990,
	}
end

AF.db = {
	artisanCharacters = {
		["Alt-Realm"] = {
			professions = {
				["164"] = { id = 164, recipes = { [100] = true } },
			},
			items = {
				["2000"] = NewLegacyEntry("Alt-Realm", {
					quality = 4,
					bestQuality = false,
					bestConcentrationQuality = false,
					bestReagents = false,
				}),
			},
			professionPrices = {},
		},
		["NoData-Realm"] = {
			professions = {
				["164"] = { id = 164, recipes = { [100] = true } },
			},
			items = {
				["2000"] = NewStaleNoCapabilityEntry("NoData-Realm"),
			},
			professionPrices = {},
		},
	},
	advertising = {},
	advertisingKnown = {},
	customerCache = {
		["2000"] = {
			["Remote-Realm"] = NewLegacyEntry("Remote-Realm", {
				quality = false,
				bestQuality = 5,
				bestConcentrationQuality = false,
				bestReagents = false,
			}),
		},
	},
	favoriteArtisans = {},
	professionLinks = {},
	connectedRealmCache = {},
	showUncertifiedPeople = false,
	offlineFallbackResults = 0,
}
AF.db.customerCache["2000"]["Remote-Realm"].lastQueryToken = 77
AF.db.customerCache["2000"]["Remote-Realm"].verifiedAt = 995

local imported = {
	professions = {
		["164"] = { id = 164, recipes = { [100] = true } },
	},
	items = {
		["2000"] = NewLegacyEntry("Imported-Realm"),
	},
	professionPrices = {},
}
AF:PrepareImportedArtisanProfile(imported, "Imported-Realm")
Check(imported.items["2000"].rescanNeeded == true, "normalization should preserve stale profile item as rescan-needed")
Check(imported.items["2000"].legacyFallback == true, "normalization should mark useful stale profile item as legacy fallback")
Check(imported.items["2000"].bestQuality == 5, "normalization should preserve legacy best quality")
Check(imported.items["2000"].bestReagents ~= nil, "normalization should preserve legacy reagent display fields")

local rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 3, "expected stale alt, stale remote cache, and no-data rows")

local byName = {}
for _, row in ipairs(rows) do
	byName[row.name] = row
end

local alt = byName["Alt-Realm"]
local remote = byName["Remote-Realm"]
local noData = byName["NoData-Realm"]
Check(alt and alt.ownAlt == true, "stale local alt row should be included")
Check(remote and remote.ownAlt ~= true, "stale remote cache row should be included")
Check(noData and noData.ownAlt == true, "stale no-data alt row should be included")

Check(alt.legacyFallback == true, "stale local alt quality should be marked legacy fallback")
Check(alt.quality == 4, "stale local alt quality should remain visible as fallback")
Check(alt.bestQuality == nil, "stale local alt should not invent best quality")
Check(AF:FormatCapability(alt) == "Outdated scan - Rescan recommended - Base Q4", "stale local alt should display outdated base quality")

Check(remote.legacyFallback == true, "stale remote best quality should be marked legacy fallback")
Check(remote.bestQuality == 5, "stale remote best quality should remain visible as fallback")
Check(AF:FormatCapability(remote) == "Outdated scan - Rescan recommended - With recommended Q5", "stale remote should display outdated recommended quality")

for _, entry in ipairs({ alt, remote, noData }) do
	Check(entry.rescanNeeded == true, "stale entry should be marked rescan needed")
	Check(entry.missingData and entry.missingData.reagentSkillFacts == true, "stale entry should report missing reagent facts")
	Check(AF:ComputeCraftOutcome(entry).rescanNeeded == true, "stale entry outcome should require rescan")
	Check(AF:BuildReagentSuggestion(entry).rescanNeeded == true, "stale entry suggestion should require rescan")
end

Check(noData.legacyFallback == nil, "stale no-data entry should not be marked legacy fallback")
Check(AF:FormatCapability(noData) == "Rescan needed", "stale no-data entry should display rescan needed")

local valid = {
	scanModelVersion = AF.SCAN_MODEL_VERSION,
	reagentSkillFacts = NewFacts(),
}
Check(AF:IsCurrentScanModelEntry(valid) == true, "current scan model entry should be valid")
Check(AF:ComputeCraftOutcome(valid).rescanNeeded == false, "valid facts should compute without rescan")

print("cache invalidation tests: PASS")
