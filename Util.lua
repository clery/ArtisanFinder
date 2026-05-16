local addonName, AF = ...

_G.ArtisanFinder = AF

AF.ADDON_NAME = addonName
AF.PREFIX = "ARTFIND1"
AF.PROTOCOL_VERSION = "1"
AF.CHANNEL_NAME = "ArtisanFinder"
AF.CACHE_MAX_AGE = 14 * 24 * 60 * 60
AF.RESPONSE_THROTTLE = 60
AF.LIVE_QUERY_TIMEOUT = 6
AF.MAX_NOTE_BYTES = 80
AF.MAX_LINK_BYTES = 96

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

function AF:EnsureDB()
	ArtisanFinderDB = ArtisanFinderDB or {}
	local db = ArtisanFinderDB

	db.artisanProfile = db.artisanProfile or {}
	db.artisanProfile.professions = db.artisanProfile.professions or {}
	db.artisanProfile.items = db.artisanProfile.items or {}
	db.artisanProfile.professionPrices = db.artisanProfile.professionPrices or {}

	db.customerCache = db.customerCache or {}
	db.responseThrottle = db.responseThrottle or {}
	if db.debugSelfResults == nil then
		db.debugSelfResults = false
	end
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
		return 0
	end
	if text:lower() == "free" then
		return 0, true
	end
	local value = tonumber(text)
	if not value then
		return nil
	end
	return math.floor(value * 10000 + 0.5), false
end

function AF:FormatMoney(copper, free)
	if free then
		return "Free commission"
	end
	copper = tonumber(copper) or 0
	if copper <= 0 then
		return "No price set"
	end
	if GetMoneyString then
		return GetMoneyString(copper, true)
	end
	return string.format("%.2fg", copper / 10000)
end

function AF:FormatCapability(entry)
	if not entry then
		return ""
	end

	local parts = {}
	if entry.totalSkill and entry.recipeDifficulty then
		table.insert(parts, "Skill " .. tostring(entry.totalSkill) .. " / Difficulty " .. tostring(entry.recipeDifficulty))
	elseif entry.totalSkill then
		table.insert(parts, "Skill " .. tostring(entry.totalSkill))
	elseif entry.recipeDifficulty then
		table.insert(parts, "Difficulty " .. tostring(entry.recipeDifficulty))
	end

	local normalQuality = tonumber(entry.quality)
	local concentrationQuality = tonumber(entry.concentrationQuality)
	if normalQuality and normalQuality > 0 and concentrationQuality and concentrationQuality > normalQuality then
		table.insert(parts, "Q" .. normalQuality .. ", Q" .. concentrationQuality .. " with Concentration")
	elseif normalQuality and normalQuality > 0 then
		table.insert(parts, "Q" .. normalQuality)
	elseif concentrationQuality and concentrationQuality > 0 then
		table.insert(parts, "Q" .. concentrationQuality .. " with Concentration")
	end

	return table.concat(parts, " - ")
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
	return self:GetItemName(itemID) or fallback or ("Item " .. tostring(itemID or "?"))
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
	return info and info.name or ("Profession " .. tostring(professionID or "?"))
end

function AF:GetItemPrice(itemID, professionID)
	local profile = self.db.artisanProfile
	local item = profile.items[tostring(itemID or "")]
	if item and (item.priceCopper or item.freeCommission or item.note) then
		return tonumber(item.priceCopper) or 0, item.freeCommission == true, item.note or ""
	end

	local professionPrice = profile.professionPrices[tostring(professionID or "")]
	if professionPrice then
		return tonumber(professionPrice.priceCopper) or 0, professionPrice.freeCommission == true, professionPrice.note or ""
	end

	return 0, false, ""
end

function AF:SetItemPrice(itemID, priceCopper, freeCommission, note)
	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	item.priceCopper = tonumber(priceCopper) or 0
	item.freeCommission = freeCommission == true
	item.note = note or ""
	item.updatedAt = self:Now()
end

function AF:SetProfessionPrice(professionID, priceCopper, freeCommission, note)
	self.db.artisanProfile.professionPrices[tostring(professionID or "")] = {
		priceCopper = tonumber(priceCopper) or 0,
		freeCommission = freeCommission == true,
		note = note or "",
		updatedAt = self:Now(),
	}
end

function AF:GetCachedArtisans(itemID, filterText, sortMode, queryToken)
	local itemCache = self.db.customerCache[tostring(itemID or "")]
	local rows = {}
	local now = self:Now()
	filterText = tostring(filterText or ""):lower()
	for _, entry in pairs(itemCache or {}) do
		local verifiedForQuery = queryToken and tonumber(entry.lastQueryToken) == tonumber(queryToken) and entry.verifiedAt
		if verifiedForQuery and entry.updatedAt and now - entry.updatedAt <= self.CACHE_MAX_AGE then
			local haystack = table.concat({
				entry.name or "",
				entry.professionName or "",
				entry.note or "",
				self:FormatMoney(entry.priceCopper, entry.freeCommission),
				self:FormatCapability(entry),
			}, " "):lower()
			if filterText == "" or haystack:find(filterText, 1, true) then
				table.insert(rows, entry)
			end
		end
	end

	sortMode = sortMode or "best"
	table.sort(rows, function(a, b)
		if sortMode == "price" then
			if (a.freeCommission == true) ~= (b.freeCommission == true) then
				return a.freeCommission == true
			end
			if (tonumber(a.priceCopper) or 0) ~= (tonumber(b.priceCopper) or 0) then
				return (tonumber(a.priceCopper) or 0) < (tonumber(b.priceCopper) or 0)
			end
		elseif sortMode == "quality" then
			local aQuality = tonumber(a.concentrationQuality) or tonumber(a.quality) or 0
			local bQuality = tonumber(b.concentrationQuality) or tonumber(b.quality) or 0
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
		elseif sortMode == "recent" then
			return (a.updatedAt or 0) > (b.updatedAt or 0)
		else
			if (a.freeCommission == true) ~= (b.freeCommission == true) then
				return a.freeCommission == true
			end
			local aQuality = tonumber(a.concentrationQuality) or tonumber(a.quality) or 0
			local bQuality = tonumber(b.concentrationQuality) or tonumber(b.quality) or 0
			if aQuality ~= bQuality then
				return aQuality > bQuality
			end
		end
		return (a.updatedAt or 0) > (b.updatedAt or 0)
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
