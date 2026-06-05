local AF = {}

assert(loadfile("Core/Data.lua"))("ArtisanFinder", AF)

AF.GetCurrentProfessionScanSignatureVersion = function()
	return 34
end

local function MakeProfile(scanSignature, item)
	return {
		professions = {
			["164"] = {
				id = 164,
				scanSignature = scanSignature,
			},
		},
		items = {
			[tostring(item and item.itemID or 1001)] = item,
		},
	}
end

local usableItem = {
	itemID = 1001,
	recipeID = 2001,
	professionID = 164,
	quality = 5,
	bestQuality = 5,
	bestReagents = {
		{ kind = "item", itemID = 3001, quantity = 1, quality = 3 },
	},
}

local compatibleProfile = MakeProfile("33|120005|164|1", usableItem)
assert(not AF:IsDeprecatedScannedProfession(compatibleProfile, 164, compatibleProfile.professions["164"]), "v33 core scan data should remain usable")

local currentProfile = MakeProfile("34|120005|164|1", usableItem)
assert(not AF:IsDeprecatedScannedProfession(currentProfile, 164, currentProfile.professions["164"]), "current scan data should not be outdated")

local missingOptionalProfile = MakeProfile("33|120005|164|1", {
	itemID = 1002,
	recipeID = 2002,
	professionID = 164,
	quality = 4,
	bestQuality = 4,
})
assert(not AF:IsDeprecatedScannedProfession(missingOptionalProfile, 164, missingOptionalProfile.professions["164"]), "missing optional recommendations should not force rescan")

local qualityAtlasOnlyProfile = MakeProfile("33|120005|164|1", {
	itemID = 1003,
	recipeID = 2003,
	professionID = 164,
	quality = 4,
	qualityAtlas = "Professions-Icon-Quality-Tier3",
})
assert(not AF:IsDeprecatedScannedProfession(qualityAtlasOnlyProfile, 164, qualityAtlasOnlyProfile.professions["164"]), "quality atlas cleanup should not force rescan")

local incompatibleProfile = MakeProfile("32|120005|164|1", usableItem)
assert(AF:IsDeprecatedScannedProfession(incompatibleProfile, 164, incompatibleProfile.professions["164"]), "old incompatible scan version should force rescan")

local corruptProfile = MakeProfile("33|120005|164|1", {
	itemID = 1004,
	professionID = 164,
})
assert(AF:IsDeprecatedScannedProfession(corruptProfile, 164, corruptProfile.professions["164"]), "missing recipe capability core data should force rescan")

local noScanProfile = {
	professions = {
		["164"] = {
			id = 164,
			scanSignature = "32|120005|164|0",
		},
	},
	items = {},
}
assert(not AF:IsDeprecatedScannedProfession(noScanProfile, 164, noScanProfile.professions["164"]), "empty professions should not warn")

print("scan_outdated: ok")
