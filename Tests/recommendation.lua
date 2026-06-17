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

LoadAddonFile("Core/Bootstrap.lua")
LoadAddonFile("Features/Customer/Recommendation.lua")

local function NewEntry(baseSkill, baseDifficulty, maxQuality, requiredSlots)
	return {
		recipeID = 100,
		reagentSkillFacts = {
			scanModelVersion = AF.SCAN_MODEL_VERSION,
			recipeID = 100,
			baseSkill = baseSkill,
			baseRecipeDifficulty = baseDifficulty,
			maxOutputQuality = maxQuality,
			requiredSlots = requiredSlots or {},
			optionalSlots = {},
		},
	}
end

local emptyFive = NewEntry(0, 100, 5)
Check(AF:ComputeCraftOutcome(emptyFive, { requiredQualities = {} }).quality == 1, "0 percent should be q1")
emptyFive.reagentSkillFacts.baseSkill = 20
Check(AF:ComputeCraftOutcome(emptyFive, { requiredQualities = {} }).quality == 2, "20 percent should be q2")
emptyFive.reagentSkillFacts.baseSkill = 50
Check(AF:ComputeCraftOutcome(emptyFive, { requiredQualities = {} }).quality == 3, "50 percent should be q3")
emptyFive.reagentSkillFacts.baseSkill = 80
Check(AF:ComputeCraftOutcome(emptyFive, { requiredQualities = {} }).quality == 4, "80 percent should be q4")
emptyFive.reagentSkillFacts.baseSkill = 100
Check(AF:ComputeCraftOutcome(emptyFive, { requiredQualities = {} }).quality == 5, "100 percent should be q5")

local three = NewEntry(49, 100, 3)
Check(AF:ComputeCraftOutcome(three).quality == 1, "3q below 50 percent should be q1")
three.reagentSkillFacts.baseSkill = 50
Check(AF:ComputeCraftOutcome(three).quality == 2, "3q 50 percent should be q2")
three.reagentSkillFacts.baseSkill = 100
Check(AF:ComputeCraftOutcome(three).quality == 3, "3q 100 percent should be q3")

local two = NewEntry(99, 100, 2)
Check(AF:ComputeCraftOutcome(two).quality == 1, "2q below 100 percent should be q1")
two.reagentSkillFacts.baseSkill = 100
Check(AF:ComputeCraftOutcome(two).quality == 2, "2q 100 percent should be q2")

local optional = NewEntry(80, 100, 5)
local optionalOutcome = AF:ComputeCraftOutcome(optional, {
	optionalReagents = {
		{ difficultyAdjustment = 20 },
	},
})
Check(optionalOutcome.totalDifficulty == 120, "optional reagent difficulty should add before thresholds")
Check(optionalOutcome.quality == 3, "optional difficulty should lower threshold result")

-- difficultyDelta (crafter-probed) takes precedence over the static schematic
-- difficultyAdjustment, and optional skillDelta adds to total skill.
local deltaEntry = NewEntry(80, 100, 5)
local deltaOutcome = AF:ComputeCraftOutcome(deltaEntry, {
	optionalReagents = {
		{ difficultyAdjustment = 20, difficultyDelta = 40, skillDelta = 10 },
	},
})
Check(deltaOutcome.totalDifficulty == 140, "difficultyDelta should override static difficultyAdjustment")
Check(deltaOutcome.totalSkill == 90, "optional skillDelta should add to total skill")

-- Regression: an embellishment that raises difficulty by 73 must drop the
-- result below max instead of reporting full quality (the reported bug).
local embellished = NewEntry(500, 500, 5)
Check(AF:ComputeCraftOutcome(embellished, { optionalReagents = {} }).quality == 5, "100 percent with no optional should be max quality")
local missing73 = AF:ComputeCraftOutcome(embellished, {
	optionalReagents = {
		{ difficultyDelta = 73 },
	},
})
Check(missing73.totalDifficulty == 573, "optional embellishment difficulty should raise total difficulty")
Check(missing73.quality < 5, "missing 73 skill should drop below max quality")
Check(missing73.quality == 4, "500/573 is 87 percent which is q4")

local logLike = NewEntry(315, 250, 5)
local logLikeOutcome = AF:ComputeCraftOutcome(logLike, {
	optionalReagents = {
		{ difficultyDelta = 73 },
	},
})
Check(AF:ComputeCraftOutcome(logLike, { optionalReagents = {} }).quality == 5, "315 skill over 250 base difficulty should be compact max quality")
Check(logLikeOutcome.totalDifficulty == 323, "log-like optional reagent should raise final difficulty to 323")
Check(logLikeOutcome.quality == 4, "315 skill into 323 difficulty should not remain q5")

local capped = NewEntry(130, 100, 5)
local cappedOutcome = AF:ComputeCraftOutcome(capped)
Check(cappedOutcome.quality == 5, "overcapped craft should be max quality")
Check(cappedOutcome.concentrationQuality == 5, "concentration quality should cap at max")

local lowestEntry = NewEntry(50, 100, 5, {
	{
		slotKey = "a",
		quantity = 1,
		reagents = {
			{ itemID = 1, quality = 1 },
			{ itemID = 2, quality = 2 },
			{ itemID = 3, quality = 3 },
		},
		qualityBonuses = { [1] = 0, [2] = 30, [3] = 60 },
	},
	{
		slotKey = "b",
		quantity = 1,
		reagents = {
			{ itemID = 4, quality = 1 },
			{ itemID = 5, quality = 2 },
			{ itemID = 6, quality = 3 },
		},
		qualityBonuses = { [1] = 0, [2] = 30, [3] = 60 },
	},
})
local lowestSuggestion = AF:BuildReagentSuggestion(lowestEntry)
Check(lowestSuggestion.quality == 5, "suggestion should reach highest no-concentration quality")
Check(lowestSuggestion.requiredQualities.a == 2 and lowestSuggestion.requiredQualities.b == 2, "suggestion should choose lowest sufficient qualities")
local itemIDSelectionOutcome = AF:ComputeCraftOutcome(lowestEntry, {
	requiredQualities = {
		a = { itemID = 2, quality = 0 },
		b = { itemID = 5 },
	},
})
Check(itemIDSelectionOutcome.quality == 5, "selected required itemIDs should resolve reagent qualities")
local sparseSelectedEntry = NewEntry(60, 100, 5, {
	{
		slotKey = "sparse",
		quantity = 1,
		reagents = {
			{ itemID = 200 },
		},
		qualityBonuses = {},
	},
})
local sparseSelectedOutcome = AF:ComputeCraftOutcome(sparseSelectedEntry, {
	requiredQualities = {
		sparse = { itemID = 200 },
	},
})
Check(sparseSelectedOutcome.rescanNeeded == false, "selected required item with sparse quality facts should still preview")
Check(sparseSelectedOutcome.quality == 3, "sparse selected required item should use baseline quality math")

local oldTradeSkillUI = C_TradeSkillUI
C_TradeSkillUI = {
	GetItemReagentQualityInfo = function()
		return {
			iconSmall = "Professions-Icon-Quality-Tier3",
		}
	end,
}
local atlasQualityEntry = NewEntry(0, 100, 5, {
	{
		slotKey = "atlas",
		quantity = 1,
		reagents = {
			{ itemID = 201 },
		},
		qualityBonuses = { [1] = 0, [3] = 100 },
	},
})
local atlasQualityOutcome = AF:ComputeCraftOutcome(atlasQualityEntry, {
	requiredQualities = {
		atlas = { itemID = 201 },
	},
})
C_TradeSkillUI = oldTradeSkillUI
Check(atlasQualityOutcome.quality == 5, "selected required item should resolve reagent quality from atlas info")

local tieEntry = NewEntry(40, 100, 5, {
	{
		slotKey = "lowImpact",
		quantity = 1,
		reagents = {
			{ itemID = 10, quality = 1 },
			{ itemID = 11, quality = 2 },
		},
		qualityBonuses = { [1] = 0, [2] = 60 },
	},
	{
		slotKey = "highImpact",
		quantity = 1,
		reagents = {
			{ itemID = 20, quality = 1 },
			{ itemID = 21, quality = 2 },
		},
		qualityBonuses = { [1] = 0, [2] = 70 },
	},
})
local tieSuggestion = AF:BuildReagentSuggestion(tieEntry)
Check(tieSuggestion.requiredQualities.highImpact == 2, "tie-break should upgrade highest-impact slot first")
Check((tieSuggestion.requiredQualities.lowImpact or 1) == 1, "tie-break should leave lower-impact slot low")

local missing = AF:BuildReagentSuggestion({ recipeID = 100 })
Check(missing.rescanNeeded == true and missing.missingData.reagentSkillFacts == true, "missing facts should require rescan")

local oldModelEntry = NewEntry(100, 100, 5)
oldModelEntry.reagentSkillFacts.scanModelVersion = AF.SCAN_MODEL_VERSION - 1
Check(AF:ComputeCraftOutcome(oldModelEntry).rescanNeeded == true, "old scan model should require rescan")
oldModelEntry.bestQuality = 5
oldModelEntry.bestReagents = {
	{ itemID = 401, quantity = 1, quality = 3 },
}
Check(AF:BuildReagentSuggestion(oldModelEntry).rescanNeeded == true, "legacy-only recommendation data should require rescan")

local zeroDeltaQualityEntry = NewEntry(100, 100, 5, {
	{
		slotKey = "zeroDelta",
		quantity = 1,
		reagents = {
			{ itemID = 301, quality = 1 },
			{ itemID = 302, quality = 2 },
		},
		qualityBonuses = { [1] = 0, [2] = 0 },
	},
})
local zeroDeltaOutcome = AF:ComputeCraftOutcome(zeroDeltaQualityEntry, {
	requiredQualities = {
		zeroDelta = 2,
	},
})
Check(zeroDeltaOutcome.rescanNeeded == true and zeroDeltaOutcome.missingData.reagentSkillFacts == true, "zero-delta quality facts should require rescan")

print("recommendation tests: PASS")
