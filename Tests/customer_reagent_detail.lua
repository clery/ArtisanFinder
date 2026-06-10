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

local function Noop()
end

local function SplitPayload(payload)
	local parts = {}
	for part in (tostring(payload or "") .. "|"):gmatch("(.-)|") do
		parts[#parts + 1] = part
	end
	return parts
end

local function NewRegion()
	return {
		ClearAllPoints = Noop,
		Hide = Noop,
		SetEnabled = Noop,
		SetHeight = Noop,
		SetPoint = Noop,
		SetShown = Noop,
		SetText = Noop,
		SetTextColor = Noop,
		SetWidth = Noop,
		Show = Noop,
	}
end

LoadAddonFile("Utils/Formatting.lua")
LoadAddonFile("Features/Social/Comms.lua")
LoadAddonFile("Features/Customer/ShoppingList.lua")

AF.db = {
	customerCache = {
		["244569"] = {
			["cached-entry-key"] = {
				name = "Megamanexe-Dalaran",
				target = "Megamanexe-Dalaran",
				orderTarget = "Megamanexe-Dalaran",
				itemID = 244569,
				recipeID = 1237508,
				lastQueryToken = 1780528424,
				hasReagentSummary = true,
			},
		},
	},
}
AF.currentCustomerQueryToken = 1781052862
AF.currentCustomerQueryItemID = 244569
AF.reagentDetailRequests = {}
AF.refreshed = 0

function AF:NormalizeName(name)
	if name == nil or name == "" then
		return nil
	end
	return name
end

function AF:DecodeField(value)
	return value or ""
end

function AF:Now()
	return 100
end

function AF:GetDistinctOptionalBestReagents(_, optionalReagents)
	return optionalReagents
end

function AF:RefreshCustomerResults()
	self.refreshed = self.refreshed + 1
end

function AF:DebugLog()
end

local detailKey = AF:GetReagentDetailKey("Megamanexe-Dalaran", 244569, 1237508, 1780528424, "Megamanexe-Dalaran")
AF.reagentDetailRequests[detailKey] = AF:Now()
AF:HandleReagentDetail({
	"D",
	"5",
	"244569",
	"1237508",
	"1780528424",
	"1",
	"1",
	"R3:i:251283:1:0:1;i:238512:125:2:1",
	"Megamanexe-Dalaran",
}, "Megamanexe-Dalaran")

local cachedEntry = AF.db.customerCache["244569"]["cached-entry-key"]
Check(cachedEntry.bestReagents and #cachedEntry.bestReagents == 2, "stale requested detail should update cached reagents")
Check(cachedEntry.reagentDetailRequested == nil, "stale requested detail should clear row request flag")
Check(AF.reagentDetailRequests[detailKey] == nil, "stale requested detail should clear outstanding request")
Check(AF.refreshed == 1, "stale requested detail should refresh customer results")

local capturedPayload
AF.PROTOCOL_VERSION = "5"
AF.SCAN_MODEL_VERSION = 4
AF.RESPONSE_THROTTLE = 5
AF.responseThrottle = {}
AF.currentCustomerQueryToken = 2000
AF.currentCustomerQueryItemID = 244570
AF.currentCustomerQueryProfessionID = 165
AF.playerName = "Buyer-Realm"
AF.db.customerCache["244570"] = nil

function AF:IsAvailable()
	return true
end

function AF:GetSupportedProfessionID(professionID)
	return tonumber(professionID)
end

function AF:GetItemPriceForProfile()
	return 12345, false, "note"
end

function AF:GetRememberedProfessionLink()
	return nil
end

function AF:RememberProfessionLink()
end

function AF:GetCachedGuildRosterEntry()
	return nil
end

function AF:IsDevTrafficLogsEnabled()
	return false
end

function AF:IsSecretValue()
	return false
end

function AF:SendPayloadParts()
	return false
end

function AF:SendAddon(payload)
	capturedPayload = payload
	return true
end

function AF:GetAdvertisedItemMatches()
	return {
		{
			characterName = "Megamanexe-Dalaran",
			profile = { professions = {} },
			item = {
				itemID = 244570,
				professionID = 165,
				recipeID = 1237509,
				recipeDifficulty = 100,
				totalSkill = 120,
				quality = 4,
				concentrationQuality = 5,
				bestQuality = 5,
				bestConcentrationQuality = 5,
				bestTotalSkill = 130,
				maxOutputQuality = 5,
				optionalSlotCount = 1,
				bestReagents = {
					{ itemID = 251283, quantity = 1, quality = 3 },
				},
				reagentSkillFacts = { huge = true },
			},
		},
	}
end

AF:HandleQuery({ "Q", "5", "244570", "165", "2000", "Buyer-Realm" }, "Buyer-Realm", "WHISPER")
Check(capturedPayload and #capturedPayload <= 255, "compact response fallback should fit addon payload limit")
local compactParts = SplitPayload(capturedPayload)
Check(compactParts[1] == "R" and compactParts[15] == "C1", "compact fallback should use compact response marker")

AF:HandleResponse(compactParts, "Megamanexe-Dalaran")
local compactEntry = AF.db.customerCache["244570"] and AF.db.customerCache["244570"]["Megamanexe-Dalaran"]
Check(compactEntry, "compact response should create customer cache entry")
Check(compactEntry.verifiedAt ~= nil, "compact response should verify current query")
Check(compactEntry.hasReagentSummary == true, "compact response should keep reagent detail availability")
Check(compactEntry.bestQuality == 5, "compact response should preserve best quality")
Check(compactEntry.reagentSkillFacts and compactEntry.reagentSkillFacts.scanModelVersion == AF.SCAN_MODEL_VERSION, "compact response should create minimal current facts")

function AF:Text(key)
	return key
end

function AF:GetDisplayItemName(itemID)
	return tostring(itemID)
end

local builtWithEntry
function AF:BuildCustomerShoppingSlots(context, entries)
	builtWithEntry = entries and entries[1]
	self.customerShoppingSlots = {}
	self.customerShoppingCandidates = {}
	return self.customerShoppingSlots
end

function AF:PrimeAdvancedShoppingSelections()
end

local oldEntry = {
	name = "Megamanexe-Dalaran",
	target = "Megamanexe-Dalaran",
	orderTarget = "Megamanexe-Dalaran",
	itemID = 244569,
	professionID = 165,
	recipeID = 1237508,
	bestReagents = nil,
}
local freshEntry = {
	name = "Megamanexe-Dalaran",
	target = "Megamanexe-Dalaran",
	orderTarget = "Megamanexe-Dalaran",
	itemID = 244569,
	professionID = 165,
	recipeID = 1237508,
	bestReagents = cachedEntry.bestReagents,
}
AF:SetCustomerShoppingContext(oldEntry, "optional")
AF.customerShoppingSlots = { { stale = true } }

local prep = NewRegion()
prep.label = NewRegion()
prep.empty = NewRegion()
prep.slots = NewRegion()
prep.track = NewRegion()
prep.slotPool = { ReleaseAll = Noop }
local row = {
	optionalPrep = prep,
	optionalPrepConfigured = true,
	GetWidth = function()
		return 320
	end,
}

AF:RefreshCustomerOptionalPrepRow(row, freshEntry)
Check(AF.customerShoppingContext.entry == freshEntry, "shopping context should adopt fresh rendered row entry")
Check(builtWithEntry == freshEntry, "shopping slots should rebuild from fresh rendered row entry")

print("customer reagent detail tests: PASS")
