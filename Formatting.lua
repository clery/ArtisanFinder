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
		value = value:sub(1, maxBytes)
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
		return "0"
	end
	return tostring(priceCopper / 10000)
end

function AF:GetQualityIconMarkup(quality, atlas, size)
	size = size or 14
	if atlas and atlas ~= "" and CreateAtlasMarkup then
		local ok, markup = pcall(CreateAtlasMarkup, atlas, size, size)
		if ok and markup and markup ~= "" then
			return markup
		end
	end
	quality = tonumber(quality)
	if not quality or quality <= 0 then
		return nil
	end
	if CreateAtlasMarkup then
		local atlasNames = {
			"Professions-Icon-Quality-Tier" .. quality .. "-Small",
			"Professions-Icon-Quality-Tier" .. quality,
		}
		for _, atlasName in ipairs(atlasNames) do
			local ok, markup = pcall(CreateAtlasMarkup, atlasName, size, size)
			if ok and markup and markup ~= "" then
				return markup
			end
		end
	end
	return "Q" .. quality
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
	if not icon and professionID and C_Spell and C_Spell.GetSpellTexture and PROFESSION_ICON_SPELLS[professionID] then
		local ok, spellIcon = pcall(C_Spell.GetSpellTexture, PROFESSION_ICON_SPELLS[professionID])
		if ok then
			icon = spellIcon
		end
	end
	if not icon and professionID and GetSpellTexture and PROFESSION_ICON_SPELLS[professionID] then
		local ok, spellIcon = pcall(GetSpellTexture, PROFESSION_ICON_SPELLS[professionID])
		if ok then
			icon = spellIcon
		end
	end
	if not icon and professionID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
		local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, professionID)
		if ok and type(info) == "table" then
			icon = info.icon or info.iconTexture or info.professionIcon
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
		return self:Text("TIME_SECONDS_AGO", math.max(1, math.floor(elapsed)))
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
	local relative = self:FormatRelativeTime(entry and entry.updatedAt)
	if relative == "" then
		return ""
	end
	return self:Text(entry and entry.tradeLead and "FOUND_TIME_AGO" or "ANSWERED_TIME_AGO", relative)
end

function AF:FormatCapability(entry)
	if not entry then
		return ""
	end

	local parts = {}
	local normalQuality = tonumber(entry.quality)
	local bestQuality = tonumber(entry.bestQuality)
	local bestConcentrationQuality = tonumber(entry.bestConcentrationQuality)
	local baseConcentrationQuality = tonumber(entry.concentrationQuality)
	local concentrationQuality = bestConcentrationQuality
	local concentrationAtlas = entry.bestConcentrationQualityAtlas
	if baseConcentrationQuality and baseConcentrationQuality > (concentrationQuality or 0) then
		concentrationQuality = baseConcentrationQuality
		concentrationAtlas = entry.concentrationQualityAtlas
	end
	local baseText
	if normalQuality and normalQuality > 0 then
		baseText = self:Text("BASE_QUALITY", self:GetQualityIconMarkup(normalQuality, entry.qualityAtlas, 16) or ("Q" .. normalQuality))
	end
	if baseText then
		table.insert(parts, baseText)
	end

	if bestQuality and bestQuality > 0 then
		table.insert(parts, self:Text("RECOMMENDED_REAGENTS_QUALITY", self:GetQualityIconMarkup(bestQuality, entry.bestQualityAtlas, 16) or ("Q" .. bestQuality)))
	end

	local line = table.concat(parts, " - ")
	if concentrationQuality and concentrationQuality > (bestQuality or normalQuality or 0) then
		local concentrationText = self:Text("CONCENTRATION_QUALITY", self:GetQualityIconMarkup(concentrationQuality, concentrationAtlas, 16) or ("Q" .. concentrationQuality))
		if line == "" then
			return concentrationText
		end
		return line .. " - " .. concentrationText
	end

	return line
end

function AF:AddCapabilityTooltipLines(tooltip, entry)
	if not tooltip or not entry then
		return
	end

	if entry.bestReagentSummary and entry.bestReagentSummary ~= "" then
		tooltip:AddLine(" ")
		tooltip:AddLine(self:Text("SUGGESTED_REAGENTS"), 1, 0.82, 0)
		self:AddReagentSummaryTooltipLines(tooltip, entry.bestReagentSummary, entry.bestReagentTruncated)
	elseif entry.bestReagentPendingNames or entry.reagentDetailRequested then
		tooltip:AddLine(" ")
		tooltip:AddLine(self:Text("SUGGESTED_REAGENTS"), 1, 0.82, 0)
		tooltip:AddLine(self:Text("LOADING_REAGENT_NAMES"), 0.75, 0.75, 0.75, true)
	else
		tooltip:AddLine(" ")
		tooltip:AddLine(self:Text("NO_REAGENT_RECOMMENDATION"), 0.75, 0.75, 0.75, true)
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
		tooltip:AddLine(self:Text("LOADING_REAGENT_NAMES"), 0.75, 0.75, 0.75, true)
	end
end

function AF:StyleCustomerTooltip(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines then
		return
	end
	local name = tooltip:GetName()
	for i = 1, tooltip:NumLines() do
		local left = _G[name .. "TextLeft" .. i]
		local right = _G[name .. "TextRight" .. i]
		if left and left.SetFontObject then
			left:SetFontObject(i == 1 and GameFontNormalLarge or GameFontHighlight)
		end
		if right and right.SetFontObject then
			right:SetFontObject(GameFontHighlight)
		end
	end
end

function AF:GetItemIconMarkup(itemID, size)
	itemID = tonumber(itemID)
	size = size or 16
	if not itemID then
		return nil
	end
	local texture
	if C_Item and C_Item.GetItemIconByID then
		texture = C_Item.GetItemIconByID(itemID)
	elseif GetItemIcon then
		texture = GetItemIcon(itemID)
	end
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
	local itemName
	if C_Item and C_Item.GetItemInfo then
		itemName = C_Item.GetItemInfo(itemID)
	elseif GetItemInfo then
		itemName = GetItemInfo(itemID)
	end
	if not itemName and C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
	return itemName
end

function AF:GetDisplayItemName(itemID, fallback)
	return self:GetItemName(itemID) or fallback or self:Text("ITEM_FALLBACK")
end
