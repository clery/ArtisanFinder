local AF = {}

local function Check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function LoadAddonFile(path)
	local chunk, err = loadfile(path)
	Check(chunk, err)
	return chunk("ArtisanFinder", AF)
end

time = function()
	return 250
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
LoadAddonFile("Features/Social/Comms.lua")
LoadAddonFile("Core/Slash.lua")

function AF:Now()
	return 250
end

function AF:GetPlayerFullName()
	return self.playerName
end

function AF:IsAvailable()
	return true
end

function AF:IsNameOnConnectedRealm()
	return false
end

function AF:IsCustomerEntryOnline()
	return false
end

function AF:IsCustomerEntryOffline()
	return false
end

function AF:IsDevFakeRowsEnabled()
	return false
end

function AF:IsDevTrafficLogsEnabled()
	return false
end

function AF:GetCachedGuildRosterEntry()
	return nil
end

function AF:IsSecretValue()
	return false
end

function AF:DebugLog()
end

function AF:ApplyPendingReagentDetail()
end

function AF:RefreshCustomerResults()
	self.customerRefreshes = (self.customerRefreshes or 0) + 1
end

function AF:RefreshMainUI()
	self.mainRefreshes = (self.mainRefreshes or 0) + 1
end

function AF:RefreshLocalizedUI()
end

function AF:Print()
end

local function NewFacts(skill, difficulty)
	return {
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		baseSkill = skill,
		baseRecipeDifficulty = difficulty,
		maxOutputQuality = 5,
		requiredSlots = {},
		optionalSlots = {},
	}
end

local function NewProfileItem(quality, updatedAt)
	return {
		itemID = 2000,
		professionID = 164,
		recipeID = 100,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = NewFacts(100 + quality, 100),
		recipeDifficulty = 100,
		totalSkill = 100 + quality,
		quality = quality,
		bestQuality = quality,
		bestTotalSkill = 100 + quality,
		maxOutputQuality = 5,
		priceCopper = 10000,
		commissionSpecified = true,
		updatedAt = updatedAt,
	}
end

local function NewCacheEntry(quality, updatedAt, name)
	name = name or "Imported-Realm"
	return {
		name = name,
		target = name,
		orderTarget = name,
		itemID = 2000,
		professionID = 164,
		recipeID = 100,
		priceCopper = 20000,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = NewFacts(100 + quality, 100),
		recipeDifficulty = 100,
		totalSkill = 100 + quality,
		quality = quality,
		bestQuality = quality,
		bestTotalSkill = 100 + quality,
		maxOutputQuality = 5,
		updatedAt = updatedAt,
		verifiedAt = 240,
		lastQueryToken = 77,
	}
end

AF.playerName = "Buyer-Realm"
AF.currentCustomerQueryToken = 77
AF.currentCustomerQueryItemID = 2000
AF.currentCustomerProfessionID = 164
AF.currentCustomerRecipeID = 100
AF.lastQueryAt = 240
AF.db = {
	artisanCharacters = {
		["Imported-Realm"] = {
			characterName = "Imported-Realm",
			importedAlt = true,
			professions = {
				["164"] = { id = 164, professionLink = "trade:old" },
			},
			items = {
				["2000"] = NewProfileItem(2, 100),
			},
			professionPrices = {},
		},
	},
	advertising = {},
	advertisingKnown = {},
	customerCache = {
		["2000"] = {
			["Imported-Realm"] = NewCacheEntry(3, 150),
		},
	},
	favoriteArtisans = {},
	professionLinks = {},
	connectedRealmCache = {},
	showUncertifiedPeople = false,
	offlineFallbackResults = 0,
}

local rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 1, "imported alt and same-name cache should collapse to one row")
Check(rows[1].ownAlt == true and rows[1].importedAlt == true, "collapsed row should stay Your alt")
Check(rows[1].quality == 3, "collapsed row should use newer cached data")
Check(AF.db.artisanCharacters["Imported-Realm"].items["2000"].quality == 3, "cached data should update imported profile")
Check(AF.db.customerCache["2000"] == nil, "absorbed cache duplicate should be removed")

local compactParts = {
	"R", AF.PROTOCOL_VERSION, "2000", "164", "30000", "0", "live note",
	"100", "200", "trade:new", "77", "Imported-Realm", "", "0", "C1",
	"100", "140", "4", "4", "5", "5", "140", "5", "0", "1",
}
AF:HandleResponse(compactParts, "Imported-Realm")
local importedItem = AF.db.artisanCharacters["Imported-Realm"].items["2000"]
Check(importedItem.quality == 4 and importedItem.bestQuality == 5, "live response should update imported profile")
Check(importedItem.priceCopper == 30000 and importedItem.note == "live note", "live response should update imported price/note")
Check(importedItem.professionLink == "trade:new", "live response should update imported profession link")
Check(AF.db.customerCache["2000"] == nil, "live response for imported alt should not leave cache duplicate")

rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 1, "live-updated imported alt should still render once")
Check(rows[1].ownAlt == true and rows[1].quality == 4, "live-updated row should stay Your alt with latest data")

AF:ClearCharacterScans("Imported-Realm")
Check(AF.db.artisanCharacters["Imported-Realm"] == nil, "cleared imported alt should remove ownership profile")
Check(AF.db.advertising["Imported-Realm"] == nil, "cleared imported alt should remove advertising state")
Check(AF.db.customerCache["2000"] and AF.db.customerCache["2000"]["Imported-Realm"], "cleared imported alt should move data to customer cache")
local movedEntry = AF.db.customerCache["2000"]["Imported-Realm"]
Check(movedEntry.quality == 4 and movedEntry.lastQueryToken == 77, "moved cache entry should preserve craft data and current query marker")

AF.IsNameOnConnectedRealm = function()
	return true
end
rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 1 and rows[1].ownAlt ~= true, "cleared imported alt should become normal cache row")

AF.db.artisanCharacters["Local-Realm"] = {
	characterName = "Local-Realm",
	localCharacter = true,
	professions = {
		["164"] = { id = 164 },
	},
	items = {
		["2000"] = NewProfileItem(5, 220),
	},
	professionPrices = {},
}
AF:ClearCharacterScans("Local-Realm")
Check(AF.db.artisanCharacters["Local-Realm"] ~= nil, "local alt clear should keep profile shell")
Check(next(AF.db.artisanCharacters["Local-Realm"].items) == nil, "local alt clear should wipe scan items")
Check(not (AF.db.customerCache["2000"] and AF.db.customerCache["2000"]["Local-Realm"]), "local alt clear should not move data to remote cache")

AF.IsNameOnConnectedRealm = function()
	return true
end
AF.customerRefreshes = 0
AF.db = {
	artisanCharacters = {
		["OriginalAlt-Realm"] = {
			characterName = "OriginalAlt-Realm",
			localCharacter = true,
			professions = {
				["164"] = { id = 164, professionLink = "trade:local-old" },
			},
			items = {
				["2000"] = NewProfileItem(2, 100),
			},
			professionPrices = {},
		},
	},
	advertising = {},
	advertisingKnown = {},
	customerCache = {
		["2000"] = {
			["OriginalAlt-Realm"] = NewCacheEntry(5, 260, "OriginalAlt-Realm"),
		},
	},
	favoriteArtisans = {},
	professionLinks = {},
	connectedRealmCache = {},
	showUncertifiedPeople = false,
	offlineFallbackResults = 0,
}

rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 1, "local alt and same-name cache should collapse to one row")
Check(rows[1].ownAlt == true and rows[1].importedAlt ~= true, "collapsed local row should stay Your alt")
Check(rows[1].quality == 5, "collapsed local row should use newer cached data")
Check(AF.db.artisanCharacters["OriginalAlt-Realm"].items["2000"].quality == 5, "cached data should update local profile")
Check(AF.db.customerCache["2000"] == nil, "absorbed local cache duplicate should be removed")

local localLiveParts = {
	"R", AF.PROTOCOL_VERSION, "2000", "164", "40000", "0", "local live note",
	"100", "300", "trade:local-new", "77", "OriginalAlt-Realm", "", "0", "C1",
	"100", "150", "4", "4", "5", "5", "150", "5", "0", "1",
}
AF:HandleResponse(localLiveParts, "OtherAccount-Realm")
local localItem = AF.db.artisanCharacters["OriginalAlt-Realm"].items["2000"]
Check(localItem.quality == 4 and localItem.bestQuality == 5, "live response should update local profile")
Check(localItem.priceCopper == 40000 and localItem.note == "local live note", "live response should update local price/note")
Check(localItem.professionLink == "trade:local-new", "live response should update local profession link")
Check(AF.db.customerCache["2000"] == nil, "live response for local alt should not leave cache duplicate")

rows = AF:GetCachedArtisans(2000, "", "quality", 77)
Check(#rows == 1, "live-updated local alt should still render once")
Check(rows[1].ownAlt == true and rows[1].quality == 4, "live-updated local row should stay Your alt with latest data")

print("imported alt merge tests: PASS")
