local AF = {}

function AF:Text(key, ...)
	if key == "ITEM_FALLBACK" then
		return "Item"
	end
	if select("#", ...) > 0 then
		return string.format(key, ...)
	end
	return key
end

function AF:GetDisplayItemName(itemID)
	return "Craft " .. tostring(itemID)
end

function AF:NormalizeName(name)
	return name
end

function AF:Now()
	return 123
end

local qualities = {
	[1001] = 1,
	[1002] = 2,
	[5001] = 2,
}

Enum = {
	CraftingReagentType = {
		Modifying = 0,
		Basic = 1,
		Finishing = 2,
		Optional = 3,
	},
	TradeskillSlotDataType = {
		Reagent = 1,
		ModifiedReagent = 2,
	},
}

C_TradeSkillUI = {
	GetRecipeInfo = function()
		return { unlockedRecipeLevel = nil }
	end,
	GetItemReagentQualityInfo = function(itemID)
		local quality = qualities[itemID]
		return quality and { quality = quality } or nil
	end,
}

local schematic = {
	reagentSlotSchematics = {
		{
			reagentType = Enum.CraftingReagentType.Basic,
			required = true,
			hiddenInCraftingForm = false,
			quantityRequired = 3,
			dataSlotIndex = 1,
			slotIndex = 1,
			slotInfo = { slotText = "Quality cloth" },
			reagents = {
				{ itemID = 1001 },
				{ itemID = 1002 },
			},
		},
		{
			reagentType = Enum.CraftingReagentType.Basic,
			required = true,
			hiddenInCraftingForm = false,
			quantityRequired = 4,
			dataSlotIndex = 2,
			slotIndex = 2,
			slotInfo = { slotText = "Thread" },
			reagents = {
				{ itemID = 2001 },
			},
		},
		{
			reagentType = Enum.CraftingReagentType.Modifying,
			required = true,
			hiddenInCraftingForm = false,
			quantityRequired = 1,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			dataSlotIndex = 3,
			slotIndex = 3,
			slotInfo = { slotText = "Required modifying" },
			reagents = {
				{ itemID = 3001 },
			},
		},
		{
			reagentType = Enum.CraftingReagentType.Modifying,
			required = false,
			hiddenInCraftingForm = false,
			quantityRequired = 2,
			dataSlotType = Enum.TradeskillSlotDataType.ModifiedReagent,
			dataSlotIndex = 4,
			slotIndex = 4,
			slotInfo = { slotText = "Optional embellishment" },
			reagents = {
				{ itemID = 4001 },
			},
		},
	},
}

C_TradeSkillUI.GetRecipeSchematic = function()
	return schematic
end

local chunk, loadError = loadfile("Features/Customer/PreparationTracker.lua")
assert(chunk, loadError)
chunk("ArtisanFinder", AF)

local function FindReagent(prepared, itemID)
	for _, reagent in ipairs(prepared.reagents or {}) do
		if reagent.itemID == itemID then
			return reagent
		end
	end
	return nil
end

local entry = {
	recipeID = 500,
	itemID = 600,
	orderTarget = "Crafter",
	bestReagents = {
		{ itemID = 1002, dataSlotIndex = 1, quantity = 99, quality = 2 },
	},
	optionalBestReagents = {
		{ itemID = 9999, dataSlotIndex = 1, quantity = 1, quality = 5 },
	},
}

local standard = AF:CreatePreparedCraftEntry(entry, "standard")
assert(standard, "standard prepared craft missing")
assert(#standard.reagents == 3, "standard should include every required/basic slot only")
assert(FindReagent(standard, 1002), "recommended quality reagent missing")
assert(FindReagent(standard, 1002).quantity == 3, "schematic quantity should win over recommendation quantity")
assert(FindReagent(standard, 2001), "no-quality required reagent missing")
assert(FindReagent(standard, 2001).quality == nil, "no-quality reagent should not gain quality")
assert(FindReagent(standard, 2001).quantity == 4, "no-quality reagent quantity wrong")
assert(FindReagent(standard, 3001), "required modifying slot should be tracked")
assert(not FindReagent(standard, 4001), "unselected optional reagent should not be tracked")

local optional = AF:CreatePreparedCraftEntry(entry, "optional", {
	{ itemID = 4001, dataSlotIndex = 4, slotKey = "4", quantity = 2 },
})
assert(optional, "optional prepared craft missing")
assert(FindReagent(optional, 1002), "optional mode should still use base bestReagents for required slots")
assert(not FindReagent(optional, 9999), "optionalBestReagents should not replace required slot choices")
assert(FindReagent(optional, 4001), "selected optional reagent missing")
assert(FindReagent(optional, 4001).optional == true, "selected optional reagent not marked optional")

schematic = {
	reagentSlotSchematics = {
		{
			reagentType = Enum.CraftingReagentType.Basic,
			required = true,
			hiddenInCraftingForm = false,
			quantityRequired = 1,
			dataSlotIndex = 10,
			slotIndex = 1,
			slotInfo = { slotText = "Bright linen" },
			reagents = {
				{ itemID = 5001 },
			},
		},
		{
			reagentType = Enum.CraftingReagentType.Basic,
			required = true,
			hiddenInCraftingForm = false,
			quantityRequired = 4,
			dataSlotIndex = 10,
			slotIndex = 2,
			slotInfo = { slotText = "Thread" },
			reagents = {
				{ itemID = 5002 },
			},
		},
	},
}

local brightLinenBolt = AF:CreatePreparedCraftEntry({
	recipeID = 501,
	itemID = 601,
	orderTarget = "Crafter",
	bestReagents = {
		{ itemID = 5001, dataSlotIndex = 10, quantity = 99, quality = 2 },
	},
}, "standard")
assert(brightLinenBolt, "bright linen bolt prepared craft missing")
assert(#brightLinenBolt.reagents == 2, "bright linen bolt should track linen and thread separately")
assert(FindReagent(brightLinenBolt, 5001), "Bright Linen missing")
assert(FindReagent(brightLinenBolt, 5001).quantity == 1, "Bright Linen should use its own schematic quantity")
assert(FindReagent(brightLinenBolt, 5001).quality == 2, "Bright Linen should keep recommended quality")
assert(FindReagent(brightLinenBolt, 5002), "Silverleaf Thread missing")
assert(FindReagent(brightLinenBolt, 5002).quantity == 4, "Silverleaf Thread quantity wrong")
assert(FindReagent(brightLinenBolt, 5002).quality == nil, "Silverleaf Thread should not gain quality")

print("preparation_tracker_reagents: ok")
