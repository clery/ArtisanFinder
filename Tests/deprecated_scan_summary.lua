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

GetRealmName = function()
	return "Realm"
end

C_Spell = {
	GetSpellName = function()
		return "Profession"
	end,
}

LoadAddonFile("Core/Bootstrap.lua")
LoadAddonFile("Locales/enUS.lua")
LoadAddonFile("Core/Util.lua")
LoadAddonFile("Utils/Formatting.lua")
LoadAddonFile("Core/Data.lua")

function AF:GetCurrentProfessionScanSignatureVersion()
	return 34
end

function AF:GetProfessionName(professionID)
	return ({
		[164] = "Blacksmithing",
		[165] = "Leatherworking",
	})[professionID] or tostring(professionID)
end

local function NewFacts()
	return {
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		baseSkill = 100,
		baseRecipeDifficulty = 100,
		maxOutputQuality = 5,
		requiredSlots = {},
		optionalSlots = {},
	}
end

local function NewItem(professionID, overrides)
	local item = {
		itemID = 1000 + professionID,
		professionID = professionID,
		recipeID = 2000 + professionID,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = NewFacts(),
	}
	for key, value in pairs(overrides or {}) do
		item[key] = value
	end
	return item
end

local profile = {
	characterName = "Crafter-Realm",
	professions = {
		["164"] = { id = 164, scanSignature = "33|old" },
		["165"] = { id = 165, scanSignature = "33|old" },
	},
	items = {
		["1164"] = NewItem(164),
		["2164"] = NewItem(164, { scanModelVersion = AF.SCAN_MODEL_VERSION - 1 }),
		["1165"] = NewItem(165),
	},
	professionPrices = {},
}
profile.items["2164"].reagentSkillFacts.scanModelVersion = AF.SCAN_MODEL_VERSION - 1

local summary = AF:GetProfileProfessionScanSummary(profile)
Check(summary[164].count == 2, "summary should count all blacksmithing items")
Check(summary[164].coreDataUsable == false, "summary should mark stale blacksmithing core data")
Check(summary[165].count == 1, "summary should count leatherworking items")
Check(summary[165].coreDataUsable == true, "summary should mark current leatherworking core data usable")

Check(AF:IsDeprecatedScannedProfession(profile, 164, profile.professions["164"], summary, 34) == true, "stale compatible scan should be deprecated")
Check(AF:IsDeprecatedScannedProfession(profile, 165, profile.professions["165"], summary, 34) == false, "compatible scan with usable data should not be deprecated")

AF.db = {
	artisanCharacters = {
		["Crafter-Realm"] = profile,
	},
}

local summaries = AF:GetDeprecatedScanSummaries()
Check(#summaries == 1, "only the stale profession should be summarized")
Check(summaries[1]:match("Blacksmithing") ~= nil, "summary should include stale profession name")
Check(summaries[1]:match("Leatherworking") == nil, "summary should omit compatible usable profession")

print("deprecated scan summary tests: PASS")

-- Exercise actual Forever signature generation against the shared status path.
LoadAddonFile("Flavors/Forever.lua")
LoadAddonFile("Features/Forever/RecipeCapability.lua")
LoadAddonFile("Features/Crafter/ProfessionRecipes.lua")
AF.GetProfessionRecipeSignature = function() return "2001,2002" end
local profession = {id=164}
profession.scanSignature = AF:GetCurrentProfessionScanSignature(profession)
local foreverProfile = {
    characterName="Test Crafter", professions={["164"]=profession},
    items={["1001"]={itemID=1001, recipeID=2001, professionID=164,
        foreverRecipe=true, scanModelVersion=AF.SCAN_MODEL_VERSION}},
}
local foreverSummary=AF:GetProfileProfessionScanSummary(foreverProfile)
Check(not AF:IsDeprecatedScannedProfession(foreverProfile,164,profession), "fresh Forever scan is current")
Check(not AF:IsDeprecatedScannedProfession(foreverProfile,164,profession,foreverSummary), "cached summary agrees with fresh status")
profession.scanSignature="forever-0|164|2001"
Check(AF:IsDeprecatedScannedProfession(foreverProfile,164,profession), "older Forever format remains outdated")
profession.scanSignature="34|legacy-retail"
Check(AF:IsDeprecatedScannedProfession(foreverProfile,164,profession), "Retail format cannot satisfy Forever scan version")
profession.scanSignature=nil
Check(AF:IsDeprecatedScannedProfession(foreverProfile,164,profession), "missing signature still needs scanning")
profession.scanSignature=AF:GetCurrentProfessionScanSignature(profession)
AF.db={artisanCharacters={["Test Crafter"]=foreverProfile}}
AF.ForEachArtisanProfile=function(self,callback) callback("Test Crafter",foreverProfile) end
Check(#AF:GetDeprecatedScanSummaries()==0,"fresh Forever scans do not produce startup warnings")
print("Forever scan freshness tests: PASS")
