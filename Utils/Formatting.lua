local _, AF = ...

local function TruncateUTF8(text, maxChars, maxBytes)
	text = tostring(text or "")
	maxChars = tonumber(maxChars) or #text
	maxBytes = tonumber(maxBytes) or #text
	local pos = 1
	local chars = 0
	local lastEnd = 0
	while pos <= #text and chars < maxChars do
		local byte = text:byte(pos) or 0
		local step = 1
		if byte >= 240 then
			step = 4
		elseif byte >= 224 then
			step = 3
		elseif byte >= 194 then
			step = 2
		end
		if pos + step - 1 > maxBytes then
			break
		end
		chars = chars + 1
		lastEnd = pos + step - 1
		pos = pos + step
	end
	return text:sub(1, lastEnd)
end

function AF:EncodeNote(note)
	note = tostring(note or "")
	note = note:gsub("[\r\n]", " ")
	note = note:gsub("|", "/")
	return TruncateUTF8(note, self.MAX_NOTE_CHARS or 256, self.MAX_NOTE_BYTES or 1024)
end

function AF:DecodeNote(note)
	return tostring(note or "")
end

function AF:EncodeField(value, maxBytes)
	value = tostring(value or "")
	value = value:gsub("[\r\n]", " ")
	value = value:gsub("|", "{p}")
	if maxBytes and #value > maxBytes then
		value = TruncateUTF8(value, #value, maxBytes)
	end
	return value
end

function AF:DecodeField(value)
	value = tostring(value or "")
	value = value:gsub("{p}", "|")
	return value
end

function AF:ParseCopperFromGoldText(text)
	text = tostring(text or ""):match("^%s*(.-)%s*$")
	if text == "" then
		return 0, false, "unspecified"
	end
	local value = tonumber(text)
	if not value then
		return nil
	end
	if value == 0 then
		return 0, false, "unspecified"
	end
	if value == -1 then
		return 0, true, "free"
	end
	if value < 0 then
		return nil
	end
	if value > (self.MAX_COMMISSION_GOLD or 99999999) then
		return nil
	end
	return math.floor(value * 10000 + 0.5), false, "paid"
end

function AF:GetCommissionInputText(priceCopper, freeCommission)
	if freeCommission == true then
		return "-1"
	end
	priceCopper = tonumber(priceCopper) or 0
	if priceCopper <= 0 then
		return ""
	end
	return tostring(priceCopper / 10000)
end

local function GetReagentQualityInfoFromItem(itemInfo)
	if not itemInfo or not C_TradeSkillUI or not C_TradeSkillUI.GetItemReagentQualityInfo then
		return nil
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemInfo)
	if ok and type(qualityInfo) == "table" then
		return qualityInfo
	end
	return nil
end

local function GetMaxQualityFromReagents(reagents)
	local maxQuality
	for _, reagent in ipairs(reagents or {}) do
		local quality = tonumber(reagent and reagent.quality)
		if not quality and reagent and reagent.itemID then
			local qualityInfo = GetReagentQualityInfoFromItem(reagent.itemID)
			quality = tonumber(qualityInfo and qualityInfo.quality)
		end
		if quality and quality > 0 then
			maxQuality = math.max(maxQuality or 0, quality)
		end
	end
	return maxQuality
end

local function GetReagentQualityContextValue(context, key)
	if type(context) ~= "table" then
		return nil
	end
	local value = context[key]
	if value ~= nil then
		return value
	end
	local reagent = context.reagent
	if type(reagent) == "table" then
		return reagent[key]
	end
	return nil
end

local function GetReagentQualityMaxQuality(context)
	local maxQuality = tonumber(GetReagentQualityContextValue(context, "maxQuality"))
	if maxQuality then
		return maxQuality
	end
	local slot = type(context) == "table" and (context.reagentSlotSchematic or context.slot) or nil
	return GetMaxQualityFromReagents(slot and slot.reagents)
end

local function GetReagentQualityInfoFromContext(context)
	if type(context) ~= "table" then
		return nil
	end
	if type(context.qualityInfo) == "table" then
		return context.qualityInfo
	end
	local itemInfo = context.itemInfo
		or context.itemLink
		or context.link
		or context.itemID
		or context.id
		or (type(context.reagent) == "table" and (context.reagent.itemID or context.reagent.id))
	return GetReagentQualityInfoFromItem(itemInfo)
end

local function BuildReagentQualityAtlasName(quality, maxQuality, small)
	quality = tonumber(quality)
	if not quality or quality <= 0 then
		return nil
	end
	maxQuality = tonumber(maxQuality)
	if maxQuality == 2 then
		return "Professions-Icon-Quality-12-Tier" .. quality
	end
	if maxQuality and maxQuality > 2 and maxQuality <= 5 then
		return "Professions-Icon-Quality-Tier" .. quality .. (small == false and "" or "-Small")
	end
	return nil
end

local function BuildReagentQualityAtlasCandidates(quality, context)
	local maxQuality = GetReagentQualityMaxQuality(context)
	local candidates = {}
	local smallAtlas = BuildReagentQualityAtlasName(quality, maxQuality, true)
	local normalAtlas = BuildReagentQualityAtlasName(quality, maxQuality, false)
	if smallAtlas then
		table.insert(candidates, smallAtlas)
	end
	if normalAtlas and normalAtlas ~= smallAtlas then
		table.insert(candidates, normalAtlas)
	end
	return candidates
end

local function IsTwoTierReagentQualityAtlas(atlas)
	return tostring(atlas or ""):find("Quality%-12%-Tier") ~= nil
end

local function ShouldUpscaleTwoTierReagentQuality(qualityInfo, context)
	if type(context) ~= "table" or context.upscaleTwoTierReagentQuality ~= true then
		return false
	end
	if tonumber(GetReagentQualityMaxQuality(context)) == 2 then
		return true
	end
	if type(qualityInfo) ~= "table" then
		return false
	end
	return IsTwoTierReagentQualityAtlas(qualityInfo.iconSmall)
		or IsTwoTierReagentQualityAtlas(qualityInfo.iconChat)
		or IsTwoTierReagentQualityAtlas(qualityInfo.icon)
		or IsTwoTierReagentQualityAtlas(qualityInfo.iconInventory)
end

local function TryCreateQualityAtlasMarkup(atlas, size)
	size = size or 14
	if atlas and atlas ~= "" and CreateAtlasMarkup then
		local ok, markup = pcall(CreateAtlasMarkup, atlas, size, size)
		if ok and markup and markup ~= "" then
			return markup
		end
	end
	return nil
end

function AF:GetReagentQualityAtlas(quality, context)
	if type(quality) == "table" then
		context = quality
		quality = context.quality or context.qualityTier
	end
	local qualityInfo = GetReagentQualityInfoFromContext(context)
	if qualityInfo and qualityInfo.iconSmall then
		return qualityInfo.iconSmall
	end
	local candidates = BuildReagentQualityAtlasCandidates(quality, context)
	return candidates[1]
end

function AF:FormatReagentQuality(quality, size, context)
	if type(quality) == "table" then
		context = quality
		quality = context.quality or context.qualityTier
	end
	if type(size) == "table" then
		context = size
		size = nil
	end
	size = size or 14
	quality = tonumber(quality)
	if not quality or quality <= 0 then
		return nil
	end
	local qualityInfo = GetReagentQualityInfoFromContext(context)
	if qualityInfo then
		quality = tonumber(qualityInfo.quality) or quality
	end
	if ShouldUpscaleTwoTierReagentQuality(qualityInfo, context) and size < 20 then
		size = 20
	end
	local markup = TryCreateQualityAtlasMarkup(qualityInfo and qualityInfo.iconSmall, size)
		or TryCreateQualityAtlasMarkup(qualityInfo and qualityInfo.iconChat, size)
		or TryCreateQualityAtlasMarkup(qualityInfo and qualityInfo.icon, size)
	for _, atlas in ipairs(BuildReagentQualityAtlasCandidates(quality, context)) do
		markup = markup or TryCreateQualityAtlasMarkup(atlas, size)
	end
	if markup then
		return markup
	end
	return "Q" .. quality
end

function AF:GetQualityIconMarkup(quality, atlas, size)
	local context = type(atlas) == "table" and atlas or nil
	return self:FormatReagentQuality(quality, size, context)
end

function AF:GetRecipeQualityIconMarkup(recipeID, quality, size)
	recipeID = tonumber(recipeID)
	quality = tonumber(quality)
	if not recipeID or not quality or quality <= 0 then
		return nil
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetRecipeItemQualityInfo, recipeID, quality)
	if ok and qualityInfo then
		return self:FormatReagentQuality(tonumber(qualityInfo.quality) or quality, size, { qualityInfo = qualityInfo })
	end
	return nil
end

local PROFESSION_ICON_FALLBACKS = {
	[5] = "Interface\\Icons\\INV_Misc_Food_15",
	[6] = "Interface\\Icons\\Trade_Mining",
	[10] = "Interface\\Icons\\Trade_Fishing",
	[12] = "Interface\\Icons\\INV_Misc_Gem_01",
	[164] = "Interface\\Icons\\Trade_BlackSmithing",
	[165] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
	[171] = "Interface\\Icons\\Trade_Alchemy",
	[182] = "Interface\\Icons\\Trade_Herbalism",
	[185] = "Interface\\Icons\\INV_Misc_Food_15",
	[186] = "Interface\\Icons\\Trade_Mining",
	[197] = "Interface\\Icons\\Trade_Tailoring",
	[202] = "Interface\\Icons\\Trade_Engineering",
	[333] = "Interface\\Icons\\Trade_Engraving",
	[356] = "Interface\\Icons\\Trade_Fishing",
	[393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
	[755] = "Interface\\Icons\\INV_Misc_Gem_01",
	[773] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
}
local PROFESSION_ICON_SPELLS = {
	[5] = 2550,
	[6] = 2575,
	[10] = 7620,
	[12] = 25229,
	[164] = 2018,
	[165] = 2108,
	[171] = 2259,
	[182] = 2366,
	[185] = 2550,
	[186] = 2575,
	[197] = 3908,
	[202] = 4036,
	[333] = 7411,
	[356] = 7620,
	[393] = 8613,
	[755] = 25229,
	[773] = 45357,
}

local function GetReagentDisplayQualityInfo(itemID, reagent)
	itemID = tonumber(itemID)
	if itemID then
		local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
		if ok and qualityInfo then
			return tonumber(qualityInfo.quality) or tonumber(reagent and reagent.quality)
		end
	end
	return tonumber(reagent and reagent.quality)
end

function AF:GetItemReagentQuality(itemID, reagent)
	return GetReagentDisplayQualityInfo(itemID, reagent)
end

local function GetTextureMarkup(texture, size)
	texture = texture and tostring(texture) or ""
	if texture == "" then
		return nil
	end
	size = tonumber(size) or 14
	return "|T" .. texture .. ":" .. size .. ":" .. size .. ":0:0|t"
end

function AF:GetProfessionIconMarkup(professionID, profileOrRow, size)
	professionID = tonumber(type(profileOrRow) == "table" and (profileOrRow.baseProfessionID or profileOrRow.parentProfessionID) or nil) or tonumber(professionID)
	local icon = type(profileOrRow) == "table" and (profileOrRow.professionIcon or profileOrRow.icon or profileOrRow.iconTexture) or nil
	if not icon and professionID and type(profileOrRow) == "table" and profileOrRow.professions then
		local profession = profileOrRow.professions[tostring(professionID)]
		icon = profession and (profession.icon or profession.professionIcon or profession.iconTexture)
	end
	if not icon and professionID and PROFESSION_ICON_SPELLS[professionID] then
		local ok, spellIcon = pcall(C_Spell.GetSpellTexture, PROFESSION_ICON_SPELLS[professionID])
		if ok then
			icon = spellIcon
		end
	end
	icon = icon or PROFESSION_ICON_FALLBACKS[professionID]
	return GetTextureMarkup(icon, size)
end

local function HasCommissionValue(entry)
	if not entry then
		return false
	end
	return entry.freeCommission == true or (tonumber(entry.priceCopper) or 0) > 0 or entry.commissionSpecified == true
end

local function HasNoteValue(entry)
	return entry and entry.note and entry.note ~= ""
end

local function ReadEntryCommission(entry)
	if HasCommissionValue(entry) then
		return tonumber(entry.priceCopper) or 0, entry.freeCommission == true
	end
	return nil
end

local function ReadEntryNote(entry)
	if HasNoteValue(entry) then
		return entry.note
	end
	return nil
end

function AF:GetSavedCommissionState(entry)
	if not HasCommissionValue(entry) then
		return "unspecified", 0, false
	end
	if entry.freeCommission == true then
		return "free", 0, true
	end
	local copper = tonumber(entry.priceCopper) or 0
	if copper > 0 then
		return "paid", copper, false
	end
	return "unspecified", 0, false
end

function AF:SetCommissionFields(entry, priceCopper, freeCommission, state)
	if not entry then
		return
	end
	state = state or "unspecified"
	if state == "free" then
		entry.priceCopper = 0
		entry.freeCommission = true
		entry.commissionSpecified = true
	elseif state == "paid" then
		entry.priceCopper = math.min(tonumber(priceCopper) or 0, self.MAX_COMMISSION_COPPER or 100000000000)
		entry.freeCommission = false
		entry.commissionSpecified = true
	else
		entry.priceCopper = nil
		entry.freeCommission = false
		entry.commissionSpecified = false
	end
end

function AF:FormatCommissionInput(entry)
	local _, copper, free = self:GetSavedCommissionState(entry)
	return self:GetCommissionInputText(copper, free)
end

function AF:IsCommissionInputDirty(text, entry)
	local copper, free, state = self:ParseCopperFromGoldText(text)
	if not copper then
		return true
	end
	local savedState, savedCopper, savedFree = self:GetSavedCommissionState(entry)
	return state ~= savedState or copper ~= savedCopper or free ~= savedFree
end

function AF:NormalizeCommissionInput(text)
	local copper, free, state = self:ParseCopperFromGoldText(text)
	if not copper then
		return nil
	end
	return copper, free, state
end

function AF:GetEntryCommission(entry)
	return ReadEntryCommission(entry)
end

function AF:GetEntryNote(entry)
	return ReadEntryNote(entry)
end

function AF:FormatMoney(copper, free)
	if free then
		return self:Text("FREE_COMMISSION")
	end
	copper = tonumber(copper) or 0
	if copper <= 0 then
		return self:Text("NO_PRICE_SET")
	end
	copper = math.min(copper, self.MAX_COMMISSION_COPPER or 100000000000)
	if GetMoneyString then
		return GetMoneyString(copper, true)
	end
	return string.format("%.2fg", copper / 10000)
end

function AF:FormatRelativeTime(timestamp)
	timestamp = tonumber(timestamp)
	if not timestamp or timestamp <= 0 then
		return ""
	end

	local elapsed = math.max(0, self:Now() - timestamp)
	if elapsed < 60 then
		return self:Text("TIME_NOW")
	end
	if elapsed < 3600 then
		return self:Text("TIME_MINUTES_AGO", math.floor(elapsed / 60))
	end
	if elapsed < 86400 then
		return self:Text("TIME_HOURS_AGO", math.floor(elapsed / 3600))
	end
	return self:Text("TIME_DAYS_AGO", math.floor(elapsed / 86400))
end

function AF:FormatCustomerRowUpdatedAt(entry)
	local timestamp = entry and entry.tradeLead and (entry.snapshotUpdatedAt or entry.updatedAt) or entry and entry.updatedAt
	local relative = self:FormatRelativeTime(timestamp)
	if relative == "" then
		return ""
	end
	return relative
end

function AF:FormatCapability(entry)
	if not entry then
		return ""
	end
	local legacyFallback = entry.rescanNeeded and self.HasLegacyScanFallback and self:HasLegacyScanFallback(entry)
	if entry.rescanNeeded and not legacyFallback then
		return self:Text("CUSTOMER_RESCAN_NEEDED")
	end

	local parts = {}
	local shoppingOutcome = self.GetCustomerShoppingOutcome and self:GetCustomerShoppingOutcome(entry) or nil
	if shoppingOutcome and shoppingOutcome.rescanNeeded then
		shoppingOutcome = nil
	end
	local normalQuality = tonumber(entry.quality)
	local bestQuality = tonumber(shoppingOutcome and shoppingOutcome.quality) or tonumber(entry.bestQuality)
	local bestConcentrationQuality = tonumber(shoppingOutcome and shoppingOutcome.concentrationQuality) or tonumber(entry.bestConcentrationQuality)
	local baseConcentrationQuality = tonumber(entry.concentrationQuality)
	local concentrationQuality = bestConcentrationQuality
	if baseConcentrationQuality and baseConcentrationQuality > (concentrationQuality or 0) then
		concentrationQuality = baseConcentrationQuality
	end

	if bestQuality and bestQuality > 0 then
		local qualityText = self:GetRecipeQualityIconMarkup(entry.recipeID, bestQuality, 16) or ("Q" .. bestQuality)
		table.insert(parts, self:Text("RECOMMENDED_REAGENTS_QUALITY", qualityText))
	elseif legacyFallback and normalQuality and normalQuality > 0 then
		local qualityText = self:GetRecipeQualityIconMarkup(entry.recipeID, normalQuality, 16) or ("Q" .. normalQuality)
		table.insert(parts, self:Text("BASE_QUALITY", qualityText))
	end

	local optionalText = self:FormatOptionalReagentImpact(entry, true)
	if optionalText ~= "" then
		table.insert(parts, optionalText)
	end

	local line = table.concat(parts, " - ")
	if concentrationQuality and concentrationQuality > (bestQuality or normalQuality or 0) then
		local concentrationText = self:Text("CONCENTRATION_QUALITY", self:GetRecipeQualityIconMarkup(entry.recipeID, concentrationQuality, 16) or ("Q" .. concentrationQuality))
		if line == "" then
			line = concentrationText
		else
			line = line .. " - " .. concentrationText
		end
	end

	if legacyFallback then
		if line == "" then
			return self:Text("CUSTOMER_LEGACY_SCAN_FALLBACK")
		end
		return self:Text("CUSTOMER_LEGACY_SCAN_FALLBACK") .. " - " .. line
	end
	return line
end

function AF:FormatOptionalReagentImpact(entry, compact)
	local delta = tonumber(entry and entry.optionalDifficultyDelta)
	local itemLevelDelta = tonumber(entry and entry.optionalOutputItemLevelDelta)
	if (not itemLevelDelta or itemLevelDelta <= 0) and entry then
		local optionalOutputItemLevel = tonumber(entry.optionalOutputItemLevel)
		local baseOutputItemLevel = tonumber(entry.bestOutputItemLevel or entry.outputItemLevel)
		itemLevelDelta = optionalOutputItemLevel and baseOutputItemLevel and (optionalOutputItemLevel - baseOutputItemLevel) or nil
	end
	if (not delta or delta <= 0) and (not itemLevelDelta or itemLevelDelta <= 0) then
		return ""
	end
	local quality = tonumber(entry.optionalQuality)
	local qualityText = quality and quality > 0 and (self:GetRecipeQualityIconMarkup(entry.recipeID, quality, 16) or ("Q" .. quality)) or nil
	if compact then
		if qualityText then
			return self:Text("OPTIONAL_REAGENTS_ROW", qualityText)
		end
		return self:Text("OPTIONAL_REAGENTS_ROW_DIFFICULTY")
	end
	if qualityText then
		return delta and delta > 0 and self:Text("OPTIONAL_REAGENTS_TOOLTIP", delta, qualityText) or self:Text("OPTIONAL_REAGENTS_ROW", qualityText)
	end
	return delta and delta > 0 and self:Text("OPTIONAL_REAGENTS_TOOLTIP_DIFFICULTY", delta) or self:Text("OPTIONAL_REAGENTS_ROW_DIFFICULTY")
end

local TOOLTIP_COMMENT_COLOR = { 0.65, 0.65, 0.65 }
local TOOLTIP_OPTIONAL_COMMENT_COLOR = { 1, 1, 1 }
local TOOLTIP_PROFESSION_COLOR = { 0.35, 1, 0.35 }
local TOOLTIP_SECTION_COLOR = { 1, 0.82, 0 }

local function AddTooltipLine(tooltip, text, color, wrap)
	color = color or TOOLTIP_COMMENT_COLOR
	tooltip:AddLine(text, color[1], color[2], color[3], wrap)
end

local function GetTooltipItemQualityColor(itemID)
	itemID = tonumber(itemID)
	if not itemID then
		return 1, 1, 1
	end
	local _, _, quality = C_Item.GetItemInfo(itemID)
	quality = tonumber(quality)
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		return color.r or 1, color.g or 1, color.b or 1
	end
	if quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then
			return r, g, b
		end
	end
	return 1, 1, 1
end

local function GetTooltipColorCode(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

local function AddItemTooltipLine(AF, tooltip, itemID, text, fallbackR, fallbackG, fallbackB)
	local r, g, b = GetTooltipItemQualityColor(itemID)
	if not C_Item.GetItemInfo(itemID) then
		r, g, b = fallbackR or r, fallbackG or g, fallbackB or b
	end
	tooltip:AddLine(text, r, g, b, true)
end

function AF:GetReagentDisplaySignature(reagents)
	local parts = {}
	for _, reagent in ipairs(reagents or {}) do
		local kind = reagent.kind == "currency" and "c" or "i"
		parts[#parts + 1] = table.concat({
			kind,
			tostring(tonumber(reagent.currencyID or reagent.itemID or reagent.id) or 0),
			tostring(tonumber(reagent.quantity) or 1),
			tostring(tonumber(reagent.quality) or 0),
			tostring(tonumber(reagent.dataSlotIndex) or 0),
		}, ":")
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function AF:ReagentListsMatch(left, right)
	local leftSignature = self:GetReagentDisplaySignature(left)
	return leftSignature ~= "" and leftSignature == self:GetReagentDisplaySignature(right)
end

function AF:GetDistinctOptionalBestReagents(baseReagents, optionalReagents)
	if not optionalReagents or self:ReagentListsMatch(optionalReagents, baseReagents) then
		return nil
	end
	return optionalReagents
end

function AF:AddCapabilityTooltipLines(tooltip, entry)
	if not tooltip or not entry then
		return
	end
	local legacyReagentDisplay = self:GetLegacyReagentDisplay(entry)
	local legacyFallback = entry.rescanNeeded and self.HasLegacyScanFallback and self:HasLegacyScanFallback(entry)
	local hasBestReagents = self:HasDisplayableReagentLines(entry.bestReagents, { hideNoQuality = true })
	local optionalBestReagents = self:GetDistinctOptionalBestReagents(entry.bestReagents, entry.optionalBestReagents)
	local hasOptionalBestReagents = self:HasDisplayableReagentLines(optionalBestReagents, { hideNoQuality = true })

	if legacyFallback then
		AddTooltipLine(tooltip, self:Text("CUSTOMER_LEGACY_SCAN_TOOLTIP"), TOOLTIP_COMMENT_COLOR, true)
	end

	local optionalText = self:FormatOptionalReagentImpact(entry, false)
	if optionalText ~= "" then
		tooltip:AddLine(" ")
		AddTooltipLine(tooltip, self:Text("OPTIONAL_REAGENTS"), TOOLTIP_SECTION_COLOR)
		AddTooltipLine(tooltip, optionalText, TOOLTIP_COMMENT_COLOR, true)
		if entry.optionalReagents and self:AddReagentLines(tooltip, entry.optionalReagents, TOOLTIP_OPTIONAL_COMMENT_COLOR[1], TOOLTIP_OPTIONAL_COMMENT_COLOR[2], TOOLTIP_OPTIONAL_COMMENT_COLOR[3], { slotLabels = true, compactQualityLabels = true, upscaleTwoTierReagentQuality = true }) then
			-- Reagent lines added above.
		elseif tonumber(entry.optionalSlotCount) and tonumber(entry.optionalSlotCount) > 0 then
			AddTooltipLine(tooltip, self:Text("OPTIONAL_REAGENTS_SLOT_COUNT", entry.optionalSlotCount), TOOLTIP_OPTIONAL_COMMENT_COLOR, true)
		end
		if hasOptionalBestReagents then
			tooltip:AddLine(" ")
			AddTooltipLine(tooltip, self:Text("OPTIONAL_REAGENTS_SUGGESTED_REAGENTS"), TOOLTIP_SECTION_COLOR)
			self:AddReagentLines(tooltip, optionalBestReagents, TOOLTIP_OPTIONAL_COMMENT_COLOR[1], TOOLTIP_OPTIONAL_COMMENT_COLOR[2], TOOLTIP_OPTIONAL_COMMENT_COLOR[3], { slotLabels = true, compactQualityLabels = true, hideNoQuality = true, upscaleTwoTierReagentQuality = true })
		end
	end

	if hasBestReagents
		or (legacyReagentDisplay and ((legacyReagentDisplay.details and legacyReagentDisplay.details ~= "") or (legacyReagentDisplay.summary and legacyReagentDisplay.summary ~= "")))
		or (entry.bestReagentDetails and entry.bestReagentDetails ~= "") then
		tooltip:AddLine(" ")
		AddTooltipLine(tooltip, self:Text("SUGGESTED_REAGENTS"), TOOLTIP_SECTION_COLOR)
		if hasBestReagents then
			self:AddReagentLines(tooltip, entry.bestReagents, 1, 1, 1, { hideNoQuality = true, upscaleTwoTierReagentQuality = true })
		elseif legacyReagentDisplay and legacyReagentDisplay.details and legacyReagentDisplay.details ~= "" then
			self:AddReagentDetailTooltipLines(tooltip, legacyReagentDisplay.details)
		elseif legacyReagentDisplay and legacyReagentDisplay.summary and legacyReagentDisplay.summary ~= "" then
			self:AddReagentSummaryTooltipLines(tooltip, legacyReagentDisplay.summary, legacyReagentDisplay.truncated)
		elseif entry.bestReagentDetails and entry.bestReagentDetails ~= "" then
			self:AddReagentDetailTooltipLines(tooltip, entry.bestReagentDetails)
		end
	elseif entry.bestReagentPendingNames or entry.reagentDetailRequested then
		tooltip:AddLine(" ")
		AddTooltipLine(tooltip, self:Text("SUGGESTED_REAGENTS"), TOOLTIP_SECTION_COLOR)
		AddTooltipLine(tooltip, self:Text("LOADING_REAGENT_NAMES"), TOOLTIP_COMMENT_COLOR, true)
	else
		tooltip:AddLine(" ")
		AddTooltipLine(tooltip, self:Text("NO_REAGENT_RECOMMENDATION"), TOOLTIP_COMMENT_COLOR, true)
	end

end

function AF:AddCustomerEntryTooltipLines(tooltip, entry, options)
	if not tooltip or not entry then
		return
	end
	options = options or {}

	if options.title ~= false then
		tooltip:SetText(options.titleText or self:GetDisplayPlayerName(entry.name or "?"), 1, 0.82, 0)
	end
	if options.profession ~= false then
		local professionName = entry.professionID and self:GetProfessionName(entry.professionID) or entry.professionName
		if professionName then
			AddTooltipLine(tooltip, professionName, TOOLTIP_PROFESSION_COLOR)
		end
	end
	if options.source ~= false then
		if entry.guildMember then
			AddTooltipLine(tooltip, self:Text("GUILD_MEMBER_TOOLTIP"), TOOLTIP_COMMENT_COLOR, true)
		else
			AddTooltipLine(tooltip, entry.tradeLead and self:Text("MISSING_ADDON_DATA") or self:Text("CERTIFIED_ADDON_DATA"), TOOLTIP_COMMENT_COLOR, true)
		end
	end
	if options.pricing then
		tooltip:AddLine(self:FormatMoney(entry.priceCopper or 0, entry.freeCommission), 1, 1, 1, true)
		local note = self:GetEntryNote(entry)
		if note and note ~= "" then
			tooltip:AddLine(note, 1, 1, 1, true)
		end
	end
	if not entry.tradeLead then
		if options.requestReagentDetails and self.RequestReagentDetail then
			self:RequestReagentDetail(entry)
		end
		local capability = self:FormatCapability(entry)
		if capability and capability ~= "" then
			AddTooltipLine(tooltip, capability, TOOLTIP_COMMENT_COLOR, true)
		end
		self:AddCapabilityTooltipLines(tooltip, entry)
	end
end

local function ReagentHasDisplayQuality(AF, reagent)
	local itemID = tonumber(reagent and (reagent.itemID or reagent.id))
	if itemID then
		local quality = GetReagentDisplayQualityInfo(itemID, reagent)
		return tonumber(quality) and tonumber(quality) > 0
	end
	return tonumber(reagent and reagent.quality) and tonumber(reagent.quality) > 0
end

local function ReagentChangesDifficulty(reagent)
	return (tonumber(reagent and (reagent.difficultyAdjustment or reagent.bonusDifficulty or reagent.difficultyDelta)) or 0) > 0
end

local function ReagentIsSuggestedDisplayable(AF, reagent)
	return ReagentHasDisplayQuality(AF, reagent) or ReagentChangesDifficulty(reagent)
end

function AF:HasDisplayableReagentLines(reagents, options)
	options = options or {}
	for _, reagent in ipairs(reagents or {}) do
		if not options.hideNoQuality or ReagentIsSuggestedDisplayable(self, reagent) then
			return true
		end
	end
	return false
end

function AF:AddReagentLines(tooltip, reagents, r, g, b, options)
	options = options or {}
	local added = false
	local requestedItemData = false
	local skipped = 0
	for _, reagent in ipairs(reagents or {}) do
		if options.hideNoQuality and not ReagentIsSuggestedDisplayable(self, reagent) then
			skipped = skipped + 1
		else
			local quantity = tonumber(reagent.quantity) or 1
			local slotText = options.slotLabels and reagent.slotText and reagent.slotText ~= "" and (reagent.slotText .. ": ") or ""
			if reagent.kind == "currency" and reagent.currencyID then
				local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
				local currencyName = currencyInfo and currencyInfo.name
				if currencyName and currencyName ~= "" then
					local icon = currencyInfo.iconFileID and CreateTextureMarkup and CreateTextureMarkup(currencyInfo.iconFileID, 16, 16, 16, 16, 0, 1, 0, 1) or ""
					tooltip:AddLine(string.format("%s%s x%d", icon ~= "" and (icon .. " ") or "", currencyName, quantity), r or 1, g or 1, b or 1, true)
					added = true
				end
			else
				local itemID = tonumber(reagent.itemID or reagent.id)
				if itemID then
					local quality = GetReagentDisplayQualityInfo(itemID, reagent)
					local qualityText = self:FormatReagentQuality(quality, 16, { itemID = itemID, reagent = reagent, upscaleTwoTierReagentQuality = options.upscaleTwoTierReagentQuality == true }) or ""
					local itemName = self:GetItemName(itemID)
					if options.showItemNames and itemName and itemName ~= "" then
						local itemIcon = self:GetItemIconMarkup(itemID, 16) or ""
						local rarityColorCode = GetTooltipColorCode(GetTooltipItemQualityColor(itemID))
						local lineText = ""
						if slotText ~= "" then
							lineText = "|cffffffff" .. slotText .. "|r"
						end
						if itemIcon ~= "" then
							lineText = lineText .. (lineText ~= "" and " " or "") .. itemIcon .. " "
						end
						lineText = lineText .. rarityColorCode .. itemName .. " x" .. quantity .. "|r"
						if qualityText ~= "" then
							lineText = lineText .. " " .. qualityText
						end
						tooltip:AddLine(lineText, 1, 1, 1, true)
						added = true
					elseif options.compactQualityLabels and slotText ~= "" and qualityText ~= "" then
						tooltip:AddLine(slotText .. qualityText, r or TOOLTIP_COMMENT_COLOR[1], g or TOOLTIP_COMMENT_COLOR[2], b or TOOLTIP_COMMENT_COLOR[3], true)
						added = true
					elseif itemName and itemName ~= "" then
						local itemIcon = self:GetItemIconMarkup(itemID, 16) or ""
						AddItemTooltipLine(self, tooltip, itemID, string.format("%s%s x%d%s", itemIcon ~= "" and (itemIcon .. " ") or "", itemName, quantity, qualityText ~= "" and (" " .. qualityText) or ""), r or 1, g or 1, b or 1)
						added = true
					else
						requestedItemData = true
					end
				end
			end
		end
	end
	if not added and type(reagents) == "table" and #reagents > skipped then
		AddTooltipLine(tooltip, self:Text("LOADING_REAGENT_NAMES"), TOOLTIP_COMMENT_COLOR, true)
	end
	if requestedItemData then
		self.pendingReagentItemData = true
	end
	return added
end

local function GetLocalReagentQualityMarkup(itemID)
	if not itemID then
		return ""
	end
	local ok, qualityInfo = pcall(C_TradeSkillUI.GetItemReagentQualityInfo, itemID)
	if not ok or not qualityInfo then
		return ""
	end
	return (AF:FormatReagentQuality(qualityInfo.quality, 16, { itemID = itemID, qualityInfo = qualityInfo, upscaleTwoTierReagentQuality = true }) or "")
end

function AF:AddReagentDetailTooltipLines(tooltip, details)
	local added = false
	for entry in tostring(details or ""):gmatch("[^;]+") do
		entry = entry:match("^%s*(.-)%s*$")
		local kind, id, quantity = entry:match("^([ic])(%d+):(%d+)$")
		id = tonumber(id)
		quantity = tonumber(quantity) or 1
		if kind == "i" and id then
			local itemName = self:GetItemName(id) or self:Text("ITEM_FALLBACK")
			local itemIcon = self:GetItemIconMarkup(id, 16) or ""
			local qualityText = GetLocalReagentQualityMarkup(id)
			AddItemTooltipLine(self, tooltip, id, string.format("%s%s x%d%s", itemIcon ~= "" and (itemIcon .. " ") or "", itemName, quantity, qualityText ~= "" and (" " .. qualityText) or ""), 1, 1, 1)
			added = true
		elseif kind == "c" and id then
			local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id)
			local currencyName = currencyInfo and currencyInfo.name
			if currencyName and currencyName ~= "" then
				local icon = currencyInfo.iconFileID and CreateTextureMarkup and CreateTextureMarkup(currencyInfo.iconFileID, 16, 16, 16, 16, 0, 1, 0, 1) or ""
				tooltip:AddLine(string.format("%s%s x%d", icon ~= "" and (icon .. " ") or "", currencyName, quantity), 1, 1, 1, true)
				added = true
			end
		end
	end
	if not added then
		AddTooltipLine(tooltip, self:Text("LOADING_REAGENT_NAMES"), TOOLTIP_COMMENT_COLOR, true)
	end
end

function AF:AddReagentSummaryTooltipLines(tooltip, summary, truncated)
	local added = false
	for reagentText in tostring(summary or ""):gmatch("[^;\n]+") do
		reagentText = reagentText:match("^%s*(.-)%s*$")
		local hasBrokenTextureMarkup = reagentText:find("|T", 1, true) and not reagentText:find("|t", 1, true)
		if reagentText ~= "" and not hasBrokenTextureMarkup and not reagentText:match("^Item%s+%d+") then
			tooltip:AddLine(reagentText, 1, 1, 1, true)
			added = true
		end
	end
	if not added then
		AddTooltipLine(tooltip, self:Text("LOADING_REAGENT_NAMES"), TOOLTIP_COMMENT_COLOR, true)
	end
end

function AF:StyleCustomerTooltip(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines then
		return
	end
	local name = tooltip:GetName()
	local left = _G[name .. "TextLeft1"]
	if left and left.SetFontObject then
		left:SetFontObject(GameFontNormalLarge)
		left:SetTextColor(1, 0.82, 0)
	end
end

function AF:FitTooltipWidthToContent(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines or not tooltip.SetMinimumWidth then
		return
	end
	local name = tooltip:GetName()
	local width = 160
	for i = 1, tooltip:NumLines() do
		local left = _G[name .. "TextLeft" .. i]
		local right = _G[name .. "TextRight" .. i]
		if left and left.GetStringWidth then
			width = math.max(width, left:GetStringWidth() + 32)
		end
		if right and right.GetStringWidth then
			width = math.max(width, right:GetStringWidth() + 48)
		end
	end
	tooltip:SetMinimumWidth(math.min(width, 420))
end

function AF:GetItemIconMarkup(itemID, size)
	itemID = tonumber(itemID)
	size = size or 16
	if not itemID then
		return nil
	end
	local texture = C_Item.GetItemIconByID(itemID)
	if texture and CreateTextureMarkup then
		return CreateTextureMarkup(texture, size, size, size, size, 0, 1, 0, 1)
	end
	return nil
end

function AF:GetItemIDFromLink(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%d+)"))
end

function AF:GetItemName(itemID)
	itemID = tonumber(itemID)
	if not itemID then
		return nil
	end
	local itemName = C_Item.GetItemInfo(itemID)
	if not itemName then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
	return itemName
end

function AF:GetDisplayItemName(itemID, fallback)
	return self:GetItemName(itemID) or fallback or self:Text("ITEM_FALLBACK")
end

function AF:OnItemDataLoaded(...)
	if self.OnOrderNotificationItemDataLoaded then
		self:OnOrderNotificationItemDataLoaded(...)
	end
	if self.itemDataRefreshQueued then
		return
	end
	self.itemDataRefreshQueued = true
	C_Timer.After(0.1, function()
		AF.itemDataRefreshQueued = nil
		local refreshCustomerResults = AF.pendingReagentItemData
		AF.pendingReagentItemData = nil
		if refreshCustomerResults and AF.RefreshCustomerResults then
			AF:RefreshCustomerResults()
		end
		if AF.RefreshCrafterUIScanSafe then
			AF:RefreshCrafterUIScanSafe()
		end
	end)
end
