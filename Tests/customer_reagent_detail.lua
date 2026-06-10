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

LoadAddonFile("Core/Bootstrap.lua")
LoadAddonFile("Utils/Formatting.lua")
LoadAddonFile("Core/Data.lua")
LoadAddonFile("Features/Customer/Recommendation.lua")
LoadAddonFile("Features/Crafter/RecipeCapability.lua")
LoadAddonFile("Features/Social/Comms.lua")
LoadAddonFile("Features/Customer/PreparationTracker.lua")
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
AF.SCAN_MODEL_VERSION = 5
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

function AF:Text(key, ...)
	if key == "RECOMMENDED_REAGENTS_QUALITY" then
		return "Recommended " .. tostring(select(1, ...))
	end
	if key == "CONCENTRATION_QUALITY" then
		return "With concentration " .. tostring(select(1, ...))
	end
	return key
end

function AF:GetDisplayItemName(itemID)
	return tostring(itemID)
end

function AF:GetRecipeQualityIconMarkup(_, quality)
	return "Q" .. tostring(quality or 0)
end

function AF:IsCurrentScanModelEntry(entry)
	local facts = type(entry) == "table" and entry.reagentSkillFacts or nil
	return type(facts) == "table"
		and tonumber(entry.scanModelVersion) == AF.SCAN_MODEL_VERSION
		and tonumber(facts.scanModelVersion) == AF.SCAN_MODEL_VERSION
		and type(facts.requiredSlots) == "table"
		and type(facts.optionalSlots) == "table"
end

local advancedEntry = {
	name = "Megamanexe-Dalaran",
	target = "Megamanexe-Dalaran",
	orderTarget = "Megamanexe-Dalaran",
	itemID = 244571,
	professionID = 165,
	recipeID = 1237510,
	scanModelVersion = AF.SCAN_MODEL_VERSION,
	reagentSkillFacts = {
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		baseSkill = 500,
		baseRecipeDifficulty = 500,
		maxOutputQuality = 5,
		requiredSlots = {},
		optionalSlots = {
			{
				slotKey = "embellishment",
				slotText = "Embellishment",
				reagents = {
					{ itemID = 219898, quantity = 1, quality = 1, difficultyAdjustment = 30, difficultyDelta = 73 },
				},
			},
		},
	},
}
local advancedContext = AF:SetCustomerShoppingContext(advancedEntry, "advanced")
local advancedCandidates = AF:BuildCustomerShoppingCandidates(advancedContext, { advancedEntry })
Check(#advancedCandidates == 1, "advanced shopping should expose optional reagent candidate")
Check(advancedCandidates[1].difficultyDelta == 73, "advanced candidate should preserve probed optional difficulty")
local advancedOutcome = AF:ComputeCraftOutcome(advancedEntry, { optionalReagents = { advancedCandidates[1] } })
Check(advancedOutcome.totalDifficulty == 573, "selected advanced optional reagent should raise expected difficulty")
Check(advancedOutcome.quality == 4, "selected advanced optional reagent should lower expected quality")
local advancedState = AF:GetCustomerShoppingState(advancedContext)
advancedState.selections[advancedCandidates[1].slotKey] = advancedCandidates[1].key
local advancedShoppingOutcome = AF:GetCustomerShoppingOutcome(advancedEntry, advancedContext)
Check(advancedShoppingOutcome.totalDifficulty == 573, "advanced shopping outcome should apply selected optional difficulty")
Check(advancedShoppingOutcome.quality == 4, "advanced shopping outcome should lower selected optional quality")

local oldTradeSkillUI = C_TradeSkillUI
local oldEnum = Enum
Enum = {
	CraftingReagentType = { Modifying = 1, Optional = 2, Finishing = 3 },
	TradeskillSlotDataType = { ModifiedReagent = 1 },
}
C_TradeSkillUI = {
	GetRecipeInfo = function()
		return { maxQuality = 5 }
	end,
	GetRecipeSchematic = function()
		return {
			reagentSlotSchematics = {
				{
					slotIndex = 1,
					dataSlotIndex = 10,
					required = false,
					hiddenInCraftingForm = false,
					reagentType = Enum.CraftingReagentType.Modifying,
					dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
					quantityRequired = 1,
					slotInfo = { slotText = "Embellishment" },
					reagents = {
						{ itemID = 219898, difficultyAdjustment = 30 },
					},
				},
			},
		}
	end,
	GetItemReagentQualityByItemInfo = function()
		return 1
	end,
	GetItemReagentQualityInfo = function()
		return nil
	end,
	GetCraftingOperationInfo = function(_, reagentInfo)
		local bonusDifficulty = 0
		for _, info in ipairs(reagentInfo or {}) do
			local itemID = info.reagent and info.reagent.itemID
			if itemID == 219898 and (tonumber(info.quantity) or 0) > 0 then
				bonusDifficulty = bonusDifficulty + 73
			end
		end
		return { baseSkill = 250, bonusSkill = 0, baseDifficulty = 250, bonusDifficulty = bonusDifficulty }
	end,
}

AF.currentCustomerQueryToken = 3000
AF.currentCustomerQueryItemID = 244572
AF.db.customerCache["244572"] = nil
local compactOptionalParts = {
	"R", AF.PROTOCOL_VERSION, "244572", "165", "0", "0", "note",
	"1237511", "101", "", "3000", "Megamanexe-Dalaran", "", "0", "C1",
	"250", "315", "5", "5", "5", "5", "315", "5", "1", "1", "219898:73",
}
AF:HandleResponse(compactOptionalParts, "Megamanexe-Dalaran")
local compactOptionalEntry = AF.db.customerCache["244572"] and AF.db.customerCache["244572"]["Megamanexe-Dalaran"]
Check(compactOptionalEntry, "compact optional response should create customer cache entry")
Check(compactOptionalEntry.bestQuality == 5, "compact optional response should preserve base compact max quality")
Check(compactOptionalEntry.compactOptionalReagentDeltas[219898].difficultyDelta == 73, "compact response should store optional reagent delta facts")
local optionalContext = AF:SetCustomerShoppingContext(compactOptionalEntry, "optional")
local optionalCandidates = AF:BuildCustomerShoppingCandidates(optionalContext, { compactOptionalEntry })
Check(#optionalCandidates == 1, "optional shopping should expose compact optional reagent candidate")
Check(optionalCandidates[1].difficultyDelta == 73, "optional candidate should receive compact optional difficulty delta")
local optionalState = AF:GetCustomerShoppingState(optionalContext)
optionalState.selections[optionalCandidates[1].slotKey] = optionalCandidates[1].key
local optionalOutcome = AF:GetCustomerShoppingOutcome(compactOptionalEntry, optionalContext)
Check(optionalOutcome.totalSkill == 315, "compact optional outcome should use artisan effective skill")
Check(optionalOutcome.totalDifficulty == 323, "compact optional outcome should add selected optional difficulty to base difficulty")
Check(optionalOutcome.quality == 4, "compact optional outcome should no longer stay max quality")
local optionalCapability = AF:FormatCapability(compactOptionalEntry)
Check(optionalCapability:find("Q4", 1, true) ~= nil, "optional row capability should display adjusted selected quality")

AF.currentCustomerQueryToken = 1781115037
AF.currentCustomerQueryItemID = 193000
AF.currentCustomerQueryProfessionID = 755
AF.db.customerCache["193000"] = {
	["Rakhnar-Dalaran"] = {
		name = "Rakhnar-Dalaran",
		target = "Rakhnar-Dalaran",
		orderTarget = "Rakhnar-Dalaran",
		itemID = 193000,
		professionID = 755,
		recipeID = 374498,
		scanModelVersion = AF.SCAN_MODEL_VERSION,
		reagentSkillFacts = {
			scanModelVersion = AF.SCAN_MODEL_VERSION,
			baseSkill = 317,
			baseRecipeDifficulty = 315,
			maxOutputQuality = 5,
			requiredSlots = {},
			optionalSlots = {
				{
					slotKey = "embellishment",
					slotText = "Embellishment",
					reagents = {
						{ itemID = 219898, quantity = 1, quality = 1, difficultyAdjustment = 30 },
					},
				},
			},
		},
	},
}
C_TradeSkillUI.GetCraftingOperationInfo = function(_, reagentInfo)
	local bonusDifficulty = 0
	for _, info in ipairs(reagentInfo or {}) do
		local itemID = info.reagent and info.reagent.itemID
		if itemID == 219898 and (tonumber(info.quantity) or 0) > 0 then
			bonusDifficulty = bonusDifficulty + 73
		end
	end
	return { baseSkill = 317, bonusSkill = 0, baseDifficulty = 315, bonusDifficulty = bonusDifficulty }
end
local exactCompactParts = {
	"R", AF.PROTOCOL_VERSION, "193000", "755", "0", "1", "",
	"374498", "1781115038", "", "1781115037", "Rakhnar-Dalaran", "", "1", "C1",
	"315", "250", "3", "4", "5", "5", "317", "5", "3", "1", "",
}
AF:HandleResponse(exactCompactParts, "Rakhnar-Dalaran")
local exactEntry = AF.db.customerCache["193000"] and AF.db.customerCache["193000"]["Rakhnar-Dalaran"]
Check(exactEntry, "exact compact response should create customer cache entry")
Check(exactEntry.reagentSkillFacts.compact == nil, "exact compact response should reuse cached detailed facts")
Check(exactEntry.compactOptionalReagentDeltas == nil, "empty trailing compact optional field should decode as no wire deltas")

local exactOptionalContext = AF:SetCustomerShoppingContext(exactEntry, "optional")
local exactOptionalCandidates = AF:BuildCustomerShoppingCandidates(exactOptionalContext, { exactEntry })
Check(#exactOptionalCandidates == 1, "exact optional compact response should expose optional candidate")
Check(exactOptionalCandidates[1].difficultyDelta == 73, "empty compact field should fall back to customer-side optional probe")
local exactOptionalState = AF:GetCustomerShoppingState(exactOptionalContext)
exactOptionalState.selections[exactOptionalCandidates[1].slotKey] = exactOptionalCandidates[1].key
local exactOptionalOutcome = AF:GetCustomerShoppingOutcome(exactEntry, exactOptionalContext)
Check(exactOptionalOutcome.totalSkill == 317, "exact optional outcome should use compact best skill")
Check(exactOptionalOutcome.totalDifficulty == 388, "exact optional outcome should add probed optional difficulty")
Check(exactOptionalOutcome.quality == 4, "exact optional outcome should not stay q5")

local exactAdvancedContext = AF:SetCustomerShoppingContext(exactEntry, "advanced")
local exactAdvancedCandidates = AF:BuildCustomerShoppingCandidates(exactAdvancedContext, { exactEntry })
Check(#exactAdvancedCandidates == 1, "exact advanced response should expose cached optional candidate")
Check(exactAdvancedCandidates[1].difficultyDelta == 73, "advanced candidate should receive customer-side optional probe")
local exactAdvancedState = AF:GetCustomerShoppingState(exactAdvancedContext)
exactAdvancedState.selections[exactAdvancedCandidates[1].slotKey] = exactAdvancedCandidates[1].key
local exactAdvancedOutcome = AF:GetCustomerShoppingOutcome(exactEntry, exactAdvancedContext)
	Check(exactAdvancedOutcome.totalDifficulty == 388, "exact advanced outcome should add probed optional difficulty")
	Check(exactAdvancedOutcome.quality == 4, "exact advanced outcome should not stay q5")
	C_TradeSkillUI = oldTradeSkillUI
	Enum = oldEnum

	local oldLogTradeSkillUI = C_TradeSkillUI
	local oldLogEnum = Enum
	local oldLogItem = C_Item
	Enum = {
		CraftingReagentType = { Basic = 0, Modifying = 1, Optional = 2, Finishing = 3 },
		TradeskillSlotDataType = { Reagent = 0, ModifiedReagent = 1 },
	}
	local LOG_REAGENT_QUALITIES = {
		[1001] = 1, [1002] = 2, [1003] = 3,
		[2001] = 1, [2002] = 2, [2003] = 3,
	}
	C_Item = {
		GetItemIconByID = function()
			return 134400
		end,
		GetItemInfo = function(itemID)
			return "item " .. tostring(itemID), "|Hitem:" .. tostring(itemID) .. "|h[item]|h"
		end,
	}
	C_TradeSkillUI = {
		GetRecipeInfo = function()
			return { maxQuality = 5 }
		end,
		GetRecipeSchematic = function(recipeID)
			Check(recipeID == 374498, "log schematic requested for unexpected recipe")
			return {
				reagentSlotSchematics = {
					{
						slotIndex = 1,
						dataSlotIndex = 1,
						required = true,
						hiddenInCraftingForm = false,
						reagentType = Enum.CraftingReagentType.Basic,
						dataSlotType = Enum.TradeskillSlotDataType.Reagent,
						quantityRequired = 1,
						slotInfo = { slotText = "Gem A" },
						reagents = {
							{ itemID = 1001 },
							{ itemID = 1002 },
							{ itemID = 1003 },
						},
					},
					{
						slotIndex = 2,
						dataSlotIndex = 2,
						required = true,
						hiddenInCraftingForm = false,
						reagentType = Enum.CraftingReagentType.Basic,
						dataSlotType = Enum.TradeskillSlotDataType.Reagent,
						quantityRequired = 1,
						slotInfo = { slotText = "Gem B" },
						reagents = {
							{ itemID = 2001 },
							{ itemID = 2002 },
							{ itemID = 2003 },
						},
					},
					{
						slotIndex = 3,
						dataSlotIndex = 5,
						required = false,
						hiddenInCraftingForm = false,
						reagentType = Enum.CraftingReagentType.Modifying,
						dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
						quantityRequired = 1,
						slotInfo = { slotText = "Embellishment" },
						reagents = {
							{ itemID = 219898, difficultyAdjustment = 30 },
						},
					},
				},
			}
		end,
		GetItemReagentQualityByItemInfo = function(itemID)
			return LOG_REAGENT_QUALITIES[itemID] or 1
		end,
		GetItemReagentQualityInfo = function(itemID)
			return { quality = LOG_REAGENT_QUALITIES[itemID] or 1 }
		end,
		GetCraftingOperationInfo = function(_, reagentInfo)
			local bonusSkill = 0
			local bonusDifficulty = 0
			for _, info in ipairs(reagentInfo or {}) do
				local itemID = info.reagent and info.reagent.itemID
				local quality = LOG_REAGENT_QUALITIES[itemID]
				if quality and (tonumber(info.quantity) or 0) > 0 then
					bonusSkill = bonusSkill + ({ [1] = 0, [2] = 40, [3] = 80 })[quality]
				elseif itemID == 219898 and (tonumber(info.quantity) or 0) > 0 then
					bonusDifficulty = bonusDifficulty + 73
				end
			end
			return { baseSkill = 250, bonusSkill = bonusSkill, baseDifficulty = 315, bonusDifficulty = bonusDifficulty }
		end,
	}

	AF.currentCustomerQueryToken = 1781115734
	AF.currentCustomerQueryItemID = 193000
	AF.currentCustomerQueryProfessionID = 755
	AF.db.customerCache["193000"] = nil
	local logCompactParts = {
		"R", AF.PROTOCOL_VERSION, "193000", "755", "0", "1", "",
		"374498", "1781115734", "", "1781115734", "Rakhnar-Dalaran", "", "1", "C1",
		"315", "250", "3", "4", "5", "5", "330", "5", "1", "1", "",
	}
	AF:HandleResponse(logCompactParts, "Rakhnar-Dalaran")
	local logEntry = AF.db.customerCache["193000"] and AF.db.customerCache["193000"]["Rakhnar-Dalaran"]
	Check(logEntry and logEntry.reagentSkillFacts.compact == true, "log compact response should start with synthetic facts")
	Check(logEntry.compactOptionalReagentDeltas == nil, "log compact response should have empty optional delta field")
	AF:HandleReagentDetail({
		"D",
		AF.PROTOCOL_VERSION,
		"193000",
		"374498",
		"1781115734",
		"1",
		"1",
		"R3:i:1003:1:3:1;i:2001:1:1:2",
		"Rakhnar-Dalaran",
	}, "Rakhnar-Dalaran")
	Check(logEntry.bestReagents and #logEntry.bestReagents == 2, "log R3 detail should store required reagent details")
	Check(logEntry.reagentSkillFacts.compact == nil, "log R3 detail should rehydrate compact facts for advanced mode")
	Check(AF:HasAdvancedReagentFacts(logEntry) == true, "log compact plus R3 detail should keep advanced mode enabled")
	local logOptionalContext = AF:SetCustomerShoppingContext(logEntry, "optional")
	local logOptionalCandidates = AF:BuildCustomerShoppingCandidates(logOptionalContext, { logEntry })
	Check(#logOptionalCandidates == 1, "log optional mode should expose selected optional reagent")
	Check(logOptionalCandidates[1].difficultyDelta == 73, "log optional mode should probe missing optional difficulty delta")
	local preparedOptional = AF:CreatePreparedCraftEntry(logEntry, "optional", { logOptionalCandidates[1] })
	local hasBaseLowerQuality = false
	local hasAdjustedQuality = false
	for _, reagent in ipairs(preparedOptional.reagents or {}) do
		if tonumber(reagent.itemID) == 2001 then
			hasBaseLowerQuality = true
		elseif tonumber(reagent.itemID) == 2003 then
			hasAdjustedQuality = true
		end
	end
	Check(not hasBaseLowerQuality, "optional tracker should not keep lower base recommendation after +73 difficulty")
	Check(hasAdjustedQuality, "optional tracker should choose adjusted sufficient reagent quality after +73 difficulty")
	C_TradeSkillUI = oldLogTradeSkillUI
	Enum = oldLogEnum
	C_Item = oldLogItem

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

local oldAuctionHouseFrame = AuctionHouseFrame
local oldAuctionator = Auctionator
local oldAuctionCItem = C_Item
local oldAuctionEnum = Enum
local oldAuctionTimer = C_Timer
local oldAuctionContinuableContainer = ContinuableContainer
local oldAuctionPrint = AF.Print
local auctionatorSearchTerms

AuctionHouseFrame = {
	IsShown = function()
		return true
	end,
}
Auctionator = {
	API = {
		v1 = {
			MultiSearchAdvanced = function(_, searchTerms)
				auctionatorSearchTerms = searchTerms
			end,
		},
	},
}
Enum = {
	ItemBind = {
		OnAcquire = 1,
		OnEquip = 2,
	},
}
C_Timer = nil
ContinuableContainer = nil
C_Item = {
	GetItemCount = function()
		return 0
	end,
	GetItemInfo = function(itemID)
		local bindType = itemID == 9001 and Enum.ItemBind.OnAcquire or Enum.ItemBind.OnEquip
		return "item " .. tostring(itemID), "|Hitem:" .. tostring(itemID) .. "|h[item]|h", 1, 1, 1, "", "", 200, "", 134400, 0, 7, 11, bindType, 10, nil, true, ""
	end,
}
function AF:Print()
end
AF.db.preparedCrafts = {
	{
		key = "auctionator-bop-filter",
		reagents = {
			{ itemID = 9001, quantity = 3 },
			{ itemID = 9002, quantity = 2 },
		},
	},
}
Check(AF:SearchAuctionatorPreparationReagents() == true, "auctionator search should start in auction house")
Check(auctionatorSearchTerms and #auctionatorSearchTerms == 1, "auctionator search should skip bind-on-pickup reagents")
Check(auctionatorSearchTerms[1].searchString == "item 9002", "auctionator search should keep auctionable reagents")
Check(auctionatorSearchTerms[1].quantity == 2, "auctionator search should keep missing quantity for auctionable reagents")

AuctionHouseFrame = oldAuctionHouseFrame
Auctionator = oldAuctionator
C_Item = oldAuctionCItem
Enum = oldAuctionEnum
C_Timer = oldAuctionTimer
ContinuableContainer = oldAuctionContinuableContainer
AF.Print = oldAuctionPrint

print("customer reagent detail tests: PASS")
