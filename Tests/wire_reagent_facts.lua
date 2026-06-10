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

-- Minimal WoW API surface for RecipeCapability.lua facts building and
-- customer-side wire rehydration.
Enum = {
	CraftingReagentType = { Basic = 0, Modifying = 1, Optional = 2, Finishing = 3 },
	TradeskillSlotDataType = { Reagent = 0, ModifiedReagent = 1 },
}

local REAGENT_QUALITIES = {
	[212665] = 1, [212666] = 2, [212667] = 3,
	[219891] = 1, [219892] = 2, [219893] = 3,
}

local SCHEMATIC = {
	recipeID = 441052,
	reagentSlotSchematics = {
		{
			slotIndex = 1,
			dataSlotIndex = 1,
			required = true,
			reagentType = Enum.CraftingReagentType.Basic,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			quantityRequired = 150,
			reagents = {
				{ itemID = 212665 },
				{ itemID = 212666 },
				{ itemID = 212667 },
			},
		},
		{
			slotIndex = 2,
			dataSlotIndex = 2,
			required = true,
			reagentType = Enum.CraftingReagentType.Basic,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			quantityRequired = 3,
			reagents = {
				{ itemID = 219891 },
				{ itemID = 219892 },
				{ itemID = 219893 },
			},
		},
		{
			-- Skill-neutral required slot: never transmitted, always rebuilt.
			slotIndex = 3,
			dataSlotIndex = 3,
			required = true,
			reagentType = Enum.CraftingReagentType.Basic,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			quantityRequired = 1,
			reagents = {
				{ itemID = 221757 },
			},
		},
		{
			slotIndex = 4,
			dataSlotIndex = 5,
			required = false,
			reagentType = Enum.CraftingReagentType.Modifying,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			quantityRequired = 1,
			slotInfo = { slotText = "Embellishment" },
			reagents = {
				{ itemID = 219898, difficultyAdjustment = 30 },
				{ itemID = 219899, difficultyAdjustment = 30 },
			},
		},
	},
}

-- Per-slot skill bonus the fake crafter gains from higher reagent quality.
local SLOT_QUALITY_SKILL = {
	[1] = { [1] = 0, [2] = 37.5, [3] = 75 },
	[2] = { [1] = 0, [2] = 37.5, [3] = 75 },
}

C_TradeSkillUI = {
	GetRecipeInfo = function()
		return { maxQuality = 5, unlockedRecipeLevel = nil }
	end,
	GetRecipeSchematic = function(recipeID)
		Check(recipeID == 441052, "schematic requested for unexpected recipe")
		return SCHEMATIC
	end,
	GetItemReagentQualityByItemInfo = function(itemID)
		return REAGENT_QUALITIES[itemID]
	end,
	GetItemReagentQualityInfo = function()
		return nil
	end,
	GetCraftingOperationInfo = function(_, reagentInfo)
		local bonus = 0
		local bonusDifficulty = 0
		for _, info in ipairs(reagentInfo or {}) do
			if info.quantity and info.quantity > 0 then
				local itemID = info.reagent and info.reagent.itemID
				local quality = REAGENT_QUALITIES[itemID]
				local slotSkill = SLOT_QUALITY_SKILL[info.dataSlotIndex]
				if quality and slotSkill then
					bonus = bonus + (slotSkill[quality] or 0)
				end
				-- Optional embellishment reagents raise recipe difficulty by 73.
				if itemID == 219898 or itemID == 219899 then
					bonusDifficulty = bonusDifficulty + 73
				end
			end
		end
		return { baseSkill = 425, bonusSkill = bonus, baseDifficulty = 400, bonusDifficulty = bonusDifficulty }
	end,
}

C_Item = {
	GetItemIconByID = function()
		return 134400
	end,
	GetItemInfo = function()
		return nil
	end,
}

LoadAddonFile("Core/Bootstrap.lua")
LoadAddonFile("Features/Customer/Recommendation.lua")
LoadAddonFile("Features/Crafter/RecipeCapability.lua")
LoadAddonFile("Features/Social/Comms.lua")

function AF:IsSecretValue()
	return false
end

function AF:Text(key)
	return key
end

-- 1. Crafter side: probe facts, then shrink to the wire format.
local crafterFacts = AF:BuildRecipeReagentSkillFacts(441052)
Check(crafterFacts, "crafter facts should build from stubbed schematic")
Check(#crafterFacts.requiredSlots == 3, "crafter facts should keep all required slots")
Check(crafterFacts.requiredSlots[1].qualityBonuses[3] == 0.5, "per-unit quality bonus should divide by quantity")

-- Crafter probe should capture the optional reagent's real difficulty shift.
Check(crafterFacts.optionalSlots[1].reagents[1].difficultyDelta == 73, "optional reagent difficulty delta should be probed")

local wire = AF:BuildWireReagentSkillFacts(crafterFacts)
Check(wire and wire.w == 2, "wire facts should carry format marker")
Check(wire.v == AF.SCAN_MODEL_VERSION and wire.s == 425 and wire.d == 400 and wire.q == 5, "wire facts should carry probe scalars")
Check(#wire.b == 2, "skill-neutral slots should not be transmitted")
Check(wire.b[1].t[1] == nil, "zero quality bonuses should not be transmitted")
Check(wire.b[1].t[3] == 0.5 and wire.b[2].t[3] == 25, "wire facts should keep non-zero per-unit bonuses")
Check(wire.requiredSlots == nil and wire.optionalSlots == nil, "wire facts should not embed slot tables")
Check(type(wire.o) == "table" and #wire.o == 2, "wire facts should transmit optional difficulty deltas")
Check(wire.o[1].d == 73 and wire.o[1].k == nil, "optional wire entry should carry difficulty delta only")
local compactOptionalDeltas = AF:EncodeCompactOptionalReagentDeltas(crafterFacts)
Check(compactOptionalDeltas:find("219898:73", 1, true) ~= nil, "compact response should encode optional difficulty deltas")
local decodedCompactOptionalDeltas = AF:DecodeCompactOptionalReagentDeltas(compactOptionalDeltas)
Check(decodedCompactOptionalDeltas[219898].difficultyDelta == 73, "compact optional deltas should decode by itemID")

-- 2. Customer side: rehydrate from the local schematic.
local rehydrated = AF:RehydrateWireReagentSkillFacts(wire, 441052)
Check(rehydrated, "wire facts should rehydrate against local schematic")
Check(rehydrated.compact == nil and rehydrated.rehydrated == true, "rehydrated facts should be detailed")
Check(#rehydrated.requiredSlots == 3, "rehydration should restore skill-neutral required slots")
Check(#rehydrated.optionalSlots == 1, "rehydration should restore optional slots from schematic")
Check(rehydrated.requiredSlots[1].qualityBonuses[2] == 0.25, "rehydration should merge wire quality bonuses")
Check(next(rehydrated.requiredSlots[3].qualityBonuses) == nil, "skill-neutral slot should rebuild without bonuses")
Check(rehydrated.optionalSlots[1].reagents[1].difficultyAdjustment == 30, "optional difficulty should rebuild from schematic")
Check(rehydrated.optionalSlots[1].reagents[1].difficultyDelta == 73, "optional difficulty delta should rehydrate from wire onto schematic reagent")
Check(rehydrated.baseSkill == 425 and rehydrated.baseRecipeDifficulty == 400 and rehydrated.maxOutputQuality == 5, "scalars should come from wire data")

for slotIndex, slot in ipairs(crafterFacts.requiredSlots) do
	local rebuilt = rehydrated.requiredSlots[slotIndex]
	Check(rebuilt.slotKey == slot.slotKey and rebuilt.quantity == slot.quantity, "rebuilt slot " .. slotIndex .. " should match crafter facts")
	Check(#rebuilt.reagents == #slot.reagents, "rebuilt slot " .. slotIndex .. " should keep reagent list")
end

local mismatched = AF:RehydrateWireReagentSkillFacts({ w = 1, v = AF.SCAN_MODEL_VERSION, s = 1, d = 1, q = 1, b = { { i = 99, x = 99, n = 1, t = { [2] = 5 } } } }, 441052)
Check(mismatched == nil, "unmatchable wire slots should fail rehydration")
Check(AF:RehydrateWireReagentSkillFacts({ w = 1, v = AF.SCAN_MODEL_VERSION - 1, s = 1, d = 1, q = 1 }, 441052) == nil, "wire facts from another scan model should be rejected")

-- 3. Full response flow: wire response, then a compact response must not
-- downgrade the cached detailed facts.
AF.db = { customerCache = {} }
AF.playerName = "Buyer-Realm"
AF.currentCustomerQueryToken = 3000
AF.currentCustomerQueryItemID = 219327
AF.lastQueryAt = 99

function AF:NormalizeName(name)
	if name == nil or name == "" then
		return nil
	end
	return name
end

function AF:DecodeField(value)
	return value or ""
end

function AF:DecodeNote(value)
	return value or ""
end

function AF:Now()
	return 100
end

function AF:GetPlayerFullName()
	return self.playerName
end

function AF:GetCachedGuildRosterEntry()
	return nil
end

function AF:RememberProfessionLink()
end

function AF:GetRememberedProfessionLink()
	return nil
end

function AF:IsCurrentScanModelEntry(entry)
	local facts = type(entry) == "table" and entry.reagentSkillFacts or nil
	return type(facts) == "table"
		and tonumber(entry.scanModelVersion) == AF.SCAN_MODEL_VERSION
		and tonumber(facts.scanModelVersion) == AF.SCAN_MODEL_VERSION
		and type(facts.requiredSlots) == "table"
		and type(facts.optionalSlots) == "table"
end

function AF:ApplyPendingReagentDetail()
end

function AF:RefreshCustomerResults()
end

function AF:DebugLog()
end

function AF:IsDevTrafficLogsEnabled()
	return false
end

local wireParts = {
	"R", AF.PROTOCOL_VERSION, "219327", "165", "450000", "0", "note",
	"441052", "90", "", "3000", "Craftan-Realm", "", "0", wire,
}
AF:HandleResponse(wireParts, "Craftan-Realm")
local entry = AF.db.customerCache["219327"]["Craftan-Realm"]
Check(entry, "wire response should create customer cache entry")
Check(entry.reagentSkillFacts.compact == nil and #entry.reagentSkillFacts.requiredSlots == 3, "wire response should store detailed facts")
Check(entry.wireReagentSkillFacts == nil, "successful rehydration should not keep wire payload")
Check(entry.bestReagents and #entry.bestReagents > 0, "wire response should compute reagent suggestion")
Check(entry.optionalSlotCount == 1, "wire response should count rebuilt optional slots")
Check(entry.quality and entry.quality >= 1, "wire response should compute outcome quality")

local compactParts = {
	"R", AF.PROTOCOL_VERSION, "219327", "165", "450000", "0", "note",
	"441052", "95", "", "3000", "Craftan-Realm", "", "0", "C1",
	"400", "425", "3", "4", "5", "5", "575", "5", "1", "1",
}
AF:HandleResponse(compactParts, "Craftan-Realm")
entry = AF.db.customerCache["219327"]["Craftan-Realm"]
Check(entry.reagentSkillFacts.compact == nil and #entry.reagentSkillFacts.requiredSlots == 3, "compact response should reuse cached detailed facts")
Check(entry.bestQuality == 5 and entry.quality == 3, "compact response should still apply transmitted scalars")

-- 4. Compact response without cached facts stays honestly compact.
AF.db.customerCache["219327"]["Craftan-Realm"] = nil
AF:HandleResponse(compactParts, "Craftan-Realm")
entry = AF.db.customerCache["219327"]["Craftan-Realm"]
Check(entry.reagentSkillFacts.compact == true, "compact response without cached facts should tag synthetic facts")
Check(#entry.reagentSkillFacts.requiredSlots == 0, "synthetic facts should stay empty")
Check(entry.hasReagentSummary == true, "compact response should keep reagent detail availability")

-- 5. Failed rehydration keeps the wire payload for a later retry.
local origSchematic = C_TradeSkillUI.GetRecipeSchematic
C_TradeSkillUI.GetRecipeSchematic = function()
	return nil
end
AF.db.customerCache["219327"]["Craftan-Realm"] = nil
AF:HandleResponse(wireParts, "Craftan-Realm")
entry = AF.db.customerCache["219327"]["Craftan-Realm"]
Check(entry.reagentSkillFacts.compact == true, "failed rehydration should fall back to synthetic facts")
Check(entry.reagentSkillFacts.baseSkill == 425 and entry.reagentSkillFacts.baseRecipeDifficulty == 400, "synthetic facts should keep wire scalars")
Check(entry.wireReagentSkillFacts == wire, "failed rehydration should keep wire payload for retry")
Check(entry.hasReagentSummary == true, "wire response should keep reagent detail availability")
C_TradeSkillUI.GetRecipeSchematic = origSchematic
Check(AF:RehydrateWireReagentSkillFacts(entry.wireReagentSkillFacts, entry.recipeID) ~= nil, "retry should rehydrate once schematic resolves")

-- 6. Legacy full facts from older senders are still accepted unchanged.
AF.db.customerCache["219327"]["Craftan-Realm"] = nil
local legacyParts = {
	"R", AF.PROTOCOL_VERSION, "219327", "165", "450000", "0", "note",
	"441052", "97", "", "3000", "Craftan-Realm", "", "0", crafterFacts,
}
AF:HandleResponse(legacyParts, "Craftan-Realm")
entry = AF.db.customerCache["219327"]["Craftan-Realm"]
Check(entry.reagentSkillFacts == crafterFacts, "legacy full facts should be stored as-is")
Check(entry.reagentSkillFacts.compact == nil, "legacy full facts should stay detailed")

print("wire reagent facts tests: PASS")
