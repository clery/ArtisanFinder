local AF = {
	HEAVY_JOB_QUALITY_TIER_THRESHOLD = 12,
}

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

local function Measure(callback)
	local started = os.clock()
	callback()
	return os.clock() - started
end

local NativePairs = pairs
local watchedPairsTable
local watchedPairsIterations = 0
_G.pairs = function(tbl)
	local iterator, state, initial = NativePairs(tbl)
	if tbl ~= watchedPairsTable then
		return iterator, state, initial
	end
	return function(iteratorState, key)
		local nextKey, value = iterator(iteratorState, key)
		if nextKey ~= nil then
			watchedPairsIterations = watchedPairsIterations + 1
		end
		return nextKey, value
	end, state, initial
end

local function NewCountedPairsTable(backing)
	watchedPairsTable = backing
	return backing, function()
		return watchedPairsIterations
	end, function()
		watchedPairsIterations = 0
	end
end

local function NewCountedIndexTable(backing)
	local reads = 0
	local proxy = setmetatable({}, {
		__index = function(_, key)
			reads = reads + 1
			return backing[key]
		end,
	})
	return proxy, function()
		return reads
	end
end

_G.issecretvalue = function(value)
	return type(value) == "table" and value.secret == true
end
_G.GetTime = os.clock
_G.C_Item = {}

LoadAddonFile("Core/Util.lua")
LoadAddonFile("Core/Data.lua")
LoadAddonFile("Features/Crafter/RecipeCapability.lua")
LoadAddonFile("Features/Crafter/Scanner.lua")
LoadAddonFile("Features/Crafter/UI.lua")

local professionIDs = { 164, 165, 171, 197, 202, 333, 755, 773 }
local characterCount = 40
local activeItemCount = 50000
local altItemCount = 1000
local totalItemCount = activeItemCount + ((characterCount - 1) * altItemCount)
local activeCharacter = "Crafter01-Realm"
local currentLink = "trade:profession-v1"

AF.NormalizeName = function(_, value)
	return value
end
AF.GetPlayerFullName = function()
	return activeCharacter
end
AF.IsOwnProfessionWindowOpen = function()
	return true
end
AF.GetCurrentProfessionInfo = function()
	return { id = 755, icon = 12345 }
end
AF.IsProtectedActionRestricted = function()
	return false
end
AF.DebugLog = function()
end
AF.Now = function()
	return 1
end

_G.C_TradeSkillUI = {
	CanTradeSkillListLink = function()
		return true
	end,
	GetTradeSkillListLink = function()
		return currentLink
	end,
	IsTradeSkillReady = function()
		return true
	end,
}

local activeItemsBacking = {}
local expectedJewelcraftingItems = 0
for itemIndex = 1, activeItemCount do
	local professionID = professionIDs[((itemIndex - 1) % #professionIDs) + 1]
	if itemIndex == 1 then
		professionID = 12
	end
	if AF:GetSupportedProfessionID(professionID) == 755 then
		expectedJewelcraftingItems = expectedJewelcraftingItems + 1
	end
	activeItemsBacking[tostring(itemIndex)] = {
		itemID = itemIndex,
		professionID = professionID,
		professionLink = professionID == 165 and "other-profession-link" or currentLink,
	}
end

local activeItems, GetActiveIterations, ResetActiveIterations = NewCountedPairsTable(activeItemsBacking)
local activeProfile = {
	characterName = activeCharacter,
	professions = {
		["755"] = {
			id = 755,
			recipes = {},
			professionLink = currentLink,
		},
	},
	items = activeItems,
	professionPrices = {},
}

AF.db = {
	artisanCharacters = {
		[activeCharacter] = activeProfile,
	},
	artisanProfile = activeProfile,
	professionLinks = {},
	disableAutomaticScans = false,
}
AF.activeArtisanCharacter = activeCharacter
AF.playerName = activeCharacter

for characterIndex = 2, characterCount do
	local characterName = string.format("Crafter%02d-Realm", characterIndex)
	local items = {}
	for itemIndex = 1, altItemCount do
		items[tostring(itemIndex)] = {
			itemID = itemIndex,
			professionID = professionIDs[((itemIndex + characterIndex) % #professionIDs) + 1],
			professionLink = "alt-link",
		}
	end
	AF.db.artisanCharacters[characterName] = {
		characterName = characterName,
		professions = {},
		items = items,
		professionPrices = {},
	}
end

ResetActiveIterations()
local unchangedCaptureSeconds = Measure(function()
	for _ = 1, 1000 do
		Check(AF:CaptureCurrentProfessionLink() == currentLink, "unchanged capture failed")
	end
end)
Check(GetActiveIterations() == 0, "unchanged profession-link captures traversed saved items")
Check(unchangedCaptureSeconds < 5, "unchanged capture benchmark exceeded generous 5 second limit")

currentLink = "trade:profession-v2"
ResetActiveIterations()
local changedCaptureSeconds = Measure(function()
	Check(AF:CaptureCurrentProfessionLink() == currentLink, "changed capture failed")
end)
Check(GetActiveIterations() == activeItemCount, "changed link did not perform exactly one active-profile item traversal")
local changedCaptureIterations = GetActiveIterations()

local updatedJewelcraftingItems = 0
for _, item in pairs(activeItemsBacking) do
	if AF:GetSupportedProfessionID(item.professionID, item) == 755 then
		Check(item.professionLink == currentLink, "changed link missed matching item")
		updatedJewelcraftingItems = updatedJewelcraftingItems + 1
	elseif item.professionID == 165 then
		Check(item.professionLink == "other-profession-link", "changed link modified unrelated profession item")
	end
end
Check(updatedJewelcraftingItems == expectedJewelcraftingItems, "unexpected matching profession item count")
Check(AF.db.artisanCharacters["Crafter40-Realm"].items["1"].professionLink == "alt-link", "capture modified another character")

currentLink = nil
Check(AF:CaptureCurrentProfessionLink() == nil, "missing link should not be captured")
Check(activeProfile.professions["755"].professionLink == "trade:profession-v2", "transient missing link cleared last valid link")

local professionInfoCalls = 0
local signatureCalls = 0
local manualBuildCalls = 0
AF.GetCurrentProfessionInfo = function()
	professionInfoCalls = professionInfoCalls + 1
	return { id = 755, name = "Jewelcrafting" }
end
AF.GetCurrentProfessionScanSignature = function()
	signatureCalls = signatureCalls + 1
	return "34|test|755|100"
end
AF.PrepareProfessionForScan = function()
	return activeProfile.professions["755"]
end
AF.BuildScanProgressAsync = function()
	manualBuildCalls = manualBuildCalls + 1
end
activeProfile.professions["755"].scanProgress = {
	professionSignature = "34|test|755|100",
	pending = { { key = "probe:1:1" } },
	pendingTotal = 1,
}
AF.db.disableAutomaticScans = true
Check(AF:ResumeCurrentProfessionScanIfNeeded() == 0, "disabled automatic scan resumed persisted work")
Check(professionInfoCalls == 0 and signatureCalls == 0, "disabled automatic resume queried profession scan data")
local disabledResumeProfessionInfoCalls = professionInfoCalls
local disabledResumeSignatureCalls = signatureCalls
AF:StartOrResumeCurrentProfessionScan(true, true)
Check(manualBuildCalls == 1, "manual force scan did not remain available while automatic scans disabled")

local pendingCount = 100000
local pendingBacking = {}
for index = 1, pendingCount do
	pendingBacking[index] = {
		key = "probe:" .. index .. ":" .. (index + 100000),
		recipeID = index,
		itemID = index + 100000,
	}
end
local pending, GetPendingReads = NewCountedIndexTable(pendingBacking)
local progress = {
	pending = pending,
	pendingIndex = 1,
	pendingTotal = pendingCount,
	completed = {},
	signature = "active-scan",
}
activeProfile.professions["755"].scanProgress = progress
AF.activeScan = {
	professionID = 755,
	signature = "active-scan",
}
local scannedItem = {
	bestReagents = {},
}
local pendingIndexBuildSeconds = Measure(function()
	Check(not AF:IsRecipeEntryScanComplete({
		professionID = 755,
		recipeID = pendingCount,
		itemID = pendingCount + 100000,
	}, scannedItem), "pending recipe entry reported complete")
end)
Check(GetPendingReads() == pendingCount, "legacy pending index did not build exactly once")
local readsAfterBuild = GetPendingReads()
local indexedLookupSeconds = Measure(function()
	for index = 1, 10000 do
		local recipeID = ((index - 1) % pendingCount) + 1
		Check(not AF:IsRecipeEntryScanComplete({
			professionID = 755,
			recipeID = recipeID,
			itemID = recipeID + 100000,
		}, scannedItem), "indexed pending recipe entry reported complete")
	end
end)
Check(GetPendingReads() == readsAfterBuild, "indexed pending lookups traversed pending jobs")
Check(indexedLookupSeconds < 5, "indexed pending lookup benchmark exceeded generous 5 second limit")

print(string.format(
	"profession-open regression: PASS characters=%d professions=%d items=%d activeItems=%d",
	characterCount,
	#professionIDs,
	totalItemCount,
	activeItemCount
))
print(string.format(
	"unchanged captures: count=1000 itemIterations=%d seconds=%.6f",
	0,
	unchangedCaptureSeconds
))
print(string.format(
	"changed capture: itemIterations=%d matchingUpdates=%d seconds=%.6f",
	changedCaptureIterations,
	updatedJewelcraftingItems,
	changedCaptureSeconds
))
print(string.format(
	"pending index: jobs=%d initialReads=%d buildSeconds=%.6f indexedLookups=10000 extraReads=%d lookupSeconds=%.6f",
	pendingCount,
	readsAfterBuild,
	pendingIndexBuildSeconds,
	GetPendingReads() - readsAfterBuild,
	indexedLookupSeconds
))
print(string.format(
	"disabled auto resume: professionInfoCalls=%d signatureCalls=%d manualForceBuilds=%d",
	disabledResumeProfessionInfoCalls,
	disabledResumeSignatureCalls,
	manualBuildCalls
))
