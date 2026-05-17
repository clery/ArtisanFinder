local addonName, AF = ...

_G.ArtisanFinder = AF

AF.ADDON_NAME = addonName
AF.PREFIX = "ARTFIND1"
AF.PROTOCOL_VERSION = "1"
AF.CHANNEL_NAME = "ArtisanFinder"
AF.CACHE_MAX_AGE = 14 * 24 * 60 * 60
AF.RESPONSE_THROTTLE = 60
AF.DETAIL_REQUEST_THROTTLE = 30
AF.REAGENT_DETAIL_CACHE_MAX_AGE = 60 * 60
AF.LIVE_QUERY_TIMEOUT = 6
AF.MAX_NOTE_BYTES = 80
AF.MAX_LINK_BYTES = 96
AF.SCHEMA_VERSION = 3

function AF:Print(message)
	print("|cff33ff99ArtisanFinder:|r " .. tostring(message))
end

function AF:ApplyPanelBackdrop(frame)
	self:ApplyProfessionPanel(frame)
end

function AF:ApplyInsetBackdrop(frame)
	self:ApplyProfessionInset(frame)
end

function AF:ApplyProfessionPanel(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.02, 0.018, 0.014, 0.82)
	frame:SetBackdropBorderColor(0.62, 0.51, 0.27, 0.9)
end

function AF:ApplyProfessionInset(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.28)
	frame:SetBackdropBorderColor(0.45, 0.36, 0.18, 0.75)
end

function AF:ApplyCustomerSidePanel(frame)
	if frame.TitleText then
		frame.TitleText:SetText("ArtisanFinder")
	end

	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	if frame.Bg then
		frame.Bg:SetAtlas("auctionhouse-background-index", false)
		frame.Bg:ClearAllPoints()
		frame.Bg:SetPoint("TOPLEFT", 6, -21)
		frame.Bg:SetPoint("BOTTOMRIGHT", -2, 2)
	end
	if frame.TopTileStreaks then
		frame.TopTileStreaks:Hide()
	end
end

function AF:ApplyCustomerListInset(frame)
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	if not frame.Background then
		frame.Background = frame:CreateTexture(nil, "BACKGROUND")
		frame.Background:SetAtlas("auctionhouse-background-index", false)
		frame.Background:SetPoint("TOPLEFT", 3, 0)
		frame.Background:SetPoint("BOTTOMRIGHT", -30, 0)
	end

	if not frame.NineSlice then
		frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
		frame.NineSlice:SetPoint("TOPLEFT", 0, 0)
		frame.NineSlice:SetPoint("BOTTOMRIGHT", -27, 0)
		frame.NineSlice:SetFrameLevel(frame:GetFrameLevel())
		frame.NineSlice.layoutType = "InsetFrameTemplate"
		if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
			NineSliceUtil.ApplyLayoutByName(frame.NineSlice, frame.NineSlice.layoutType)
		end
	end
end

function AF:ApplyCustomerPopupPanel(frame)
	if frame.SetBackdrop then
		frame:SetBackdrop(nil)
	end

	if not frame.Background then
		frame.Background = frame:CreateTexture(nil, "BACKGROUND")
	end
	frame.Background:SetAtlas("auctionhouse-background-index", false)
	frame.Background:ClearAllPoints()
	frame.Background:SetPoint("TOPLEFT", 3, -3)
	frame.Background:SetPoint("BOTTOMRIGHT", -3, 3)

	if not frame.NineSlice then
		frame.NineSlice = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
		frame.NineSlice:SetPoint("TOPLEFT", 0, 0)
		frame.NineSlice:SetPoint("BOTTOMRIGHT", 0, 0)
		frame.NineSlice:SetFrameLevel(frame:GetFrameLevel())
		frame.NineSlice.layoutType = "InsetFrameTemplate"
		if NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
			NineSliceUtil.ApplyLayoutByName(frame.NineSlice, frame.NineSlice.layoutType)
		end
	end

	if not frame.TopDivider then
		frame.TopDivider = frame:CreateTexture(nil, "ARTWORK")
		frame.TopDivider:SetAtlas("Options_HorizontalDivider", true)
		frame.TopDivider:SetPoint("TOPLEFT", 10, -5)
		frame.TopDivider:SetPoint("TOPRIGHT", -10, -5)
		frame.TopDivider:SetHeight(2)
		frame.TopDivider:SetAlpha(0.35)
	end
end

function AF:StyleListRow(row)
	if row.SetBackdrop then
		row:SetBackdrop(nil)
	end
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local highlight = row:GetHighlightTexture()
	if highlight then
		highlight:SetAlpha(0.28)
	end
	row.divider = row:CreateTexture(nil, "BORDER")
	row.divider:SetAtlas("Options_HorizontalDivider", true)
	row.divider:SetPoint("BOTTOMLEFT", 4, 0)
	row.divider:SetPoint("BOTTOMRIGHT", -4, 0)
	row.divider:SetHeight(2)
	row.divider:SetAlpha(0.35)
end

function AF:AddDivider(parent, anchor, offsetY)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY or -6)
	divider:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
	divider:SetHeight(2)
	divider:SetAlpha(0.45)
	return divider
end

function AF:Now()
	return time()
end

function AF:IsInCombatLocked()
	return InCombatLockdown and InCombatLockdown() == true
end

local MIGRATIONS = {}

MIGRATIONS[1] = function(db)
	db.artisanProfile = db.artisanProfile or {}
	db.artisanProfile.professions = db.artisanProfile.professions or {}
	db.artisanProfile.items = db.artisanProfile.items or {}
	db.artisanProfile.professionPrices = db.artisanProfile.professionPrices or {}
	db.customerCache = db.customerCache or {}
	db.favoriteArtisans = db.favoriteArtisans or {}
	db.responseThrottle = db.responseThrottle or {}
	if db.defaultSort == nil then
		db.defaultSort = "best"
	end
	if db.cacheCleanupDays == nil then
		db.cacheCleanupDays = 7
	end
	if db.autoAvailability == nil then
		db.autoAvailability = false
	end
	if db.tradeLeadMinutes == nil then
		db.tradeLeadMinutes = 15
	end
	if db.debugSelfResults == nil then
		db.debugSelfResults = false
	end
	db.minimap = db.minimap or { angle = 225, hide = false }
end

MIGRATIONS[2] = function(db)
	if db.tradeLeadMinutes == nil then
		db.tradeLeadMinutes = 15
	end
end

MIGRATIONS[3] = function(db)
	db.tradeLeads = db.tradeLeads or {}
end

function AF:MigrateDB(db)
	local version = tonumber(db.schemaVersion) or 0
	while version < self.SCHEMA_VERSION do
		local nextVersion = version + 1
		local migration = MIGRATIONS[nextVersion]
		if migration then
			migration(db)
		end
		db.schemaVersion = nextVersion
		version = nextVersion
	end
end

function AF:EnsureDB()
	ArtisanFinderDB = ArtisanFinderDB or {}
	local db = ArtisanFinderDB
	self:MigrateDB(db)

	db.artisanProfile = db.artisanProfile or {}
	db.artisanProfile.professions = db.artisanProfile.professions or {}
	db.artisanProfile.items = db.artisanProfile.items or {}
	db.artisanProfile.professionPrices = db.artisanProfile.professionPrices or {}

	db.customerCache = db.customerCache or {}
	db.favoriteArtisans = db.favoriteArtisans or {}
	db.responseThrottle = db.responseThrottle or {}
	db.tradeLeads = db.tradeLeads or {}
	if db.debugSelfResults == nil then
		db.debugSelfResults = false
	end
	if db.autoAvailability == nil then
		db.autoAvailability = false
	end
	if db.defaultSort == nil then
		db.defaultSort = "best"
	end
	if db.cacheCleanupDays == nil then
		db.cacheCleanupDays = 7
	end
	if db.tradeLeadMinutes == nil then
		db.tradeLeadMinutes = 15
	end
	db.schemaVersion = self.SCHEMA_VERSION
	db.minimap = db.minimap or { angle = 225, hide = false }
	if db.minimap.angle == nil then
		db.minimap.angle = 225
	end
	if db.minimap.hide == nil then
		db.minimap.hide = false
	end

	self.db = db
	self.available = false
	return db
end

function AF:CleanupCustomerCache()
	if not self.db or not self.db.customerCache then
		return 0
	end
	local days = tonumber(self.db.cacheCleanupDays) or 7
	if days <= 0 then
		return 0
	end
	local cutoff = self:Now() - (days * 24 * 60 * 60)
	local removed = 0
	for itemKey, itemCache in pairs(self.db.customerCache) do
		if type(itemCache) == "table" then
			for cacheKey, entry in pairs(itemCache) do
				local updatedAt = tonumber(entry and entry.updatedAt) or 0
				if (updatedAt <= 0 or updatedAt < cutoff) and not self:IsFavoriteArtisan(entry) then
					itemCache[cacheKey] = nil
					removed = removed + 1
				end
			end
			if next(itemCache) == nil then
				self.db.customerCache[itemKey] = nil
			end
		end
	end
	if removed > 0 then
		self:Print(self:Text("CACHE_CLEANUP_DONE", removed, days))
	end
	return removed
end

function AF:GetPlayerFullName()
	local name, realm = UnitFullName("player")
	realm = realm or GetRealmName()
	realm = realm and realm:gsub("%s+", "") or ""
	if realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

function AF:NormalizeName(name)
	if not name or name == "" then
		return nil
	end
	name = name:gsub("%s+", "")
	if not name:find("-", 1, true) then
		local realm = GetRealmName()
		if realm and realm ~= "" then
			name = name .. "-" .. realm:gsub("%s+", "")
		end
	end
	return name
end

function AF:GetDisplayPlayerName(name)
	name = tostring(name or "")
	local playerName, realm = name:match("^([^-]+)-(.+)$")
	if not playerName or not realm then
		return name
	end

	local currentRealm = GetRealmName()
	currentRealm = currentRealm and currentRealm:gsub("%s+", "") or ""
	if realm == currentRealm then
		return playerName
	end
	return name
end

function AF:GetFavoriteArtisanKey(entryOrName)
	local name = type(entryOrName) == "table" and (entryOrName.target or entryOrName.name) or entryOrName
	return self:NormalizeName(name)
end

function AF:IsFavoriteArtisan(entryOrName)
	local key = self:GetFavoriteArtisanKey(entryOrName)
	return key and self.db and self.db.favoriteArtisans and self.db.favoriteArtisans[key] == true
end

function AF:SetFavoriteArtisan(entryOrName, favorite)
	local key = self:GetFavoriteArtisanKey(entryOrName)
	if not key then
		return
	end
	self.db.favoriteArtisans[key] = favorite == true or nil
end

function AF:ToggleFavoriteArtisan(entryOrName)
	local favorite = not self:IsFavoriteArtisan(entryOrName)
	self:SetFavoriteArtisan(entryOrName, favorite)
	return favorite
end

function AF:EncodeNote(note)
	note = tostring(note or "")
	note = note:gsub("[\r\n]", " ")
	note = note:gsub("|", "/")
	if #note > self.MAX_NOTE_BYTES then
		note = note:sub(1, self.MAX_NOTE_BYTES)
	end
	return note
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

local function HasCommissionValue(entry)
	if not entry then
		return false
	end
	return entry.freeCommission == true or (tonumber(entry.priceCopper) or 0) > 0 or entry.commissionSpecified == true
end

local function HasNoteValue(entry)
	return entry and entry.note and entry.note ~= ""
end

local function GetEntryCommission(entry)
	if HasCommissionValue(entry) then
		return tonumber(entry.priceCopper) or 0, entry.freeCommission == true
	end
	return nil
end

local function GetEntryNote(entry)
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
		entry.priceCopper = tonumber(priceCopper) or 0
		entry.freeCommission = false
		entry.commissionSpecified = true
	else
		entry.priceCopper = nil
		entry.freeCommission = false
		entry.commissionSpecified = false
	end
end

function AF:CommissionStateFromInput(text)
	return self:ParseCopperFromGoldText(text)
end

function AF:FormatCommissionInput(entry)
	local _, copper, free = self:GetSavedCommissionState(entry)
	return self:GetCommissionInputText(copper, free)
end

function AF:IsCommissionInputDirty(text, entry)
	local copper, free, state = self:CommissionStateFromInput(text)
	if not copper then
		return true
	end
	local savedState, savedCopper, savedFree = self:GetSavedCommissionState(entry)
	return state ~= savedState or copper ~= savedCopper or free ~= savedFree
end

function AF:NormalizeCommissionInput(text)
	local copper, free, state = self:CommissionStateFromInput(text)
	if not copper then
		return nil
	end
	return copper, free, state
end

function AF:GetProfessionPriceEntry(professionID)
	local profile = self.db and self.db.artisanProfile
	return profile and profile.professionPrices[tostring(professionID or "")]
end

function AF:EntryHasCommissionValue(entry)
	return HasCommissionValue(entry)
end

function AF:EntryHasNoteValue(entry)
	return HasNoteValue(entry)
end

function AF:GetEntryCommission(entry)
	return GetEntryCommission(entry)
end

function AF:GetEntryNote(entry)
	return GetEntryNote(entry)
end

function AF:FormatMoney(copper, free)
	if free then
		return self:Text("FREE_COMMISSION")
	end
	copper = tonumber(copper) or 0
	if copper <= 0 then
		return self:Text("NO_PRICE_SET")
	end
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

	return table.concat(parts, " - ")
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

function AF:TableCount(tbl)
	local count = 0
	for _ in pairs(tbl or {}) do
		count = count + 1
	end
	return count
end

function AF:GetProfessionName(professionID)
	local profile = self.db and self.db.artisanProfile
	local info = profile and profile.professions and profile.professions[tostring(professionID or "")]
	return info and info.name or self:Text("PROFESSION_FALLBACK", tostring(professionID or "?"))
end

function AF:GetItemPrice(itemID, professionID)
	local profile = self.db.artisanProfile
	local item = profile.items[tostring(itemID or "")]
	local professionPrice = self:GetProfessionPriceEntry(professionID)
	local priceCopper, freeCommission = self:GetEntryCommission(item)
	local note = self:GetEntryNote(item)
	if not priceCopper then
		priceCopper, freeCommission = self:GetEntryCommission(professionPrice)
	end
	if not note then
		note = self:GetEntryNote(professionPrice)
	end
	return tonumber(priceCopper) or 0, freeCommission == true, note or ""
end

function AF:SetItemPrice(itemID, priceCopper, freeCommission, note, commissionState)
	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	self:SetCommissionFields(item, priceCopper, freeCommission, commissionState)
	item.note = note or ""
	item.updatedAt = self:Now()
end

function AF:SetProfessionPrice(professionID, priceCopper, freeCommission, note, commissionState)
	local entry = self.db.artisanProfile.professionPrices[tostring(professionID or "")] or {}
	self.db.artisanProfile.professionPrices[tostring(professionID or "")] = entry
	self:SetCommissionFields(entry, priceCopper, freeCommission, commissionState)
	entry.note = note or ""
	entry.updatedAt = self:Now()
end

local function GetSortQuality(entry)
	return tonumber(entry and entry.bestQuality)
		or tonumber(entry and entry.quality)
		or 0
end

local function GetCertificationSort(entry)
	return entry and entry.tradeLead and 1 or 0
end

local function GetTradeLeadMatchSort(entry)
	if not entry or not entry.tradeLead then
		return 0
	end
	return entry.tradeProfessionMatch and 0 or 1
end

local function GetCommissionSort(entry)
	if entry and entry.freeCommission == true then
		return 0, 0
	end
	local priceCopper = tonumber(entry and entry.priceCopper) or 0
	if priceCopper > 0 then
		return 1, priceCopper
	end
	return 2, 0
end

local function GetSortName(entry)
	return tostring(entry and entry.name or ""):lower()
end

local function EntryMatchesCustomerFilter(AF, entry, filterText)
	local haystack = table.concat({
		entry.name or "",
		entry.professionName or "",
		entry.note or "",
		AF:FormatMoney(entry.priceCopper, entry.freeCommission),
		AF:FormatCapability(entry),
		entry.bestReagentSummary or "",
	}, " "):lower()
	return filterText == "" or haystack:find(filterText, 1, true)
end

local function CopyCustomerEntry(entry)
	local copy = {}
	for key, value in pairs(entry or {}) do
		copy[key] = value
	end
	return copy
end

function AF:GetCachedArtisans(itemID, filterText, sortMode, queryToken)
	local itemCache = self.db.customerCache[tostring(itemID or "")]
	local rows = {}
	local now = self:Now()
	filterText = tostring(filterText or ""):lower()
	local seenNames = {}
	for _, entry in pairs(itemCache or {}) do
		local verifiedForQuery = queryToken and tonumber(entry.lastQueryToken) == tonumber(queryToken) and entry.verifiedAt
		if verifiedForQuery and entry.updatedAt and now - entry.updatedAt <= self.CACHE_MAX_AGE then
			if EntryMatchesCustomerFilter(self, entry, filterText) then
				local rowEntry = CopyCustomerEntry(entry)
				rowEntry.certified = true
				rowEntry.tradeLead = false
				rowEntry.unavailableFavorite = nil
				table.insert(rows, rowEntry)
				local favoriteKey = self:GetFavoriteArtisanKey(rowEntry)
				if favoriteKey then
					seenNames[favoriteKey] = true
				end
				if rowEntry.name then
					seenNames[rowEntry.name] = true
				end
			end
		end
	end

	for _, entry in pairs(itemCache or {}) do
		local favoriteKey = self:GetFavoriteArtisanKey(entry)
		if favoriteKey and not seenNames[favoriteKey] and self:IsFavoriteArtisan(entry) and EntryMatchesCustomerFilter(self, entry, filterText) then
			local favoriteEntry = CopyCustomerEntry(entry)
			favoriteEntry.certified = true
			favoriteEntry.tradeLead = false
			favoriteEntry.unavailableFavorite = true
			table.insert(rows, favoriteEntry)
			seenNames[favoriteKey] = true
			if favoriteEntry.name then
				seenNames[favoriteEntry.name] = true
			end
		end
	end
	if self.GetTradeLeadRows then
		for _, entry in ipairs(self:GetTradeLeadRows(itemID, self.currentCustomerProfessionID, filterText, seenNames, self.currentCustomerRecipeID)) do
			table.insert(rows, entry)
		end
	end

	sortMode = sortMode or "best"
	table.sort(rows, function(a, b)
		local aFavorite = self:IsFavoriteArtisan(a) and 0 or 1
		local bFavorite = self:IsFavoriteArtisan(b) and 0 or 1
		if aFavorite ~= bFavorite then
			return aFavorite < bFavorite
		end
		if aFavorite == 0 then
			local aUnavailable = a.unavailableFavorite and 1 or 0
			local bUnavailable = b.unavailableFavorite and 1 or 0
			if aUnavailable ~= bUnavailable then
				return aUnavailable < bUnavailable
			end
		end

		local aCertified = GetCertificationSort(a)
		local bCertified = GetCertificationSort(b)
		if aCertified ~= bCertified then
			return aCertified < bCertified
		end
		local aTradeMatch = GetTradeLeadMatchSort(a)
		local bTradeMatch = GetTradeLeadMatchSort(b)
		if aTradeMatch ~= bTradeMatch then
			return aTradeMatch < bTradeMatch
		end

		local aCommissionRank, aPrice = GetCommissionSort(a)
		local bCommissionRank, bPrice = GetCommissionSort(b)
		local aQuality = GetSortQuality(a)
		local bQuality = GetSortQuality(b)

		if sortMode == "commission" or sortMode == "price" then
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
		elseif sortMode == "quality" then
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
		else
			if aCommissionRank == 0 or bCommissionRank == 0 then
				if aCommissionRank ~= bCommissionRank then
					return aCommissionRank < bCommissionRank
				end
			end
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
			if aCommissionRank ~= bCommissionRank then
				return aCommissionRank < bCommissionRank
			end
			if aPrice ~= bPrice then
				return aPrice < bPrice
			end
		end
		return GetSortName(a) < GetSortName(b)
	end)
	return rows
end

function AF:OpenWhisper(target, message)
	target = self:NormalizeName(target)
	if not target then
		return
	end
	ChatFrame_OpenChat("/w " .. target .. " " .. (message or ""), DEFAULT_CHAT_FRAME)
end
