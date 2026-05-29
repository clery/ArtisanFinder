local _, AF = ...

local SHOP_NAME_MAX_CHARS = 32
local SHOP_NAME_MAX_BYTES = 96
local SHOP_DESCRIPTION_MAX_CHARS = 500
local SHOP_DESCRIPTION_MAX_BYTES = 1400
local SHOP_DESCRIPTION_CACHE_MAX_AGE = 24 * 60 * 60
local SHOP_EMBLEM_MAX_STYLE = 195
local SHOP_TOOLTIP_WIDTH = 360
local SHOP_BORDER_STYLES = {
	{ key = "thin", labelKey = "SHOP_BORDER_STYLE_THIN" },
	{ key = "banner", labelKey = "SHOP_BORDER_STYLE_BANNER", atlas = "communities-guildbanner-border" },
	{ key = "guildfinder", labelKey = "SHOP_BORDER_STYLE_GUILDFINDER", atlas = "guildfinder-card-guildbanner-border" },
	{ key = "hud", labelKey = "SHOP_BORDER_STYLE_HUD", atlas = "UI-HUD-MicroMenu-GuildCommunities-GuildColor-Up" },
}
local SHOP_BORDER_STYLE_INDEX = {}
for index, style in ipairs(SHOP_BORDER_STYLES) do
	SHOP_BORDER_STYLE_INDEX[style.key] = index
end
local SHOP_BACKGROUND_STYLES = {
	{ key = "plain", labelKey = "SHOP_BACKGROUND_STYLE_PLAIN" },
	{ key = "guild", labelKey = "SHOP_BACKGROUND_STYLE_GUILD", atlas = "UI-HUD-MicroMenu-GuildCommunities-GuildColor-Up" },
	{ key = "banner", labelKey = "SHOP_BACKGROUND_STYLE_BANNER", atlas = "communities-guildbanner-background" },
	{ key = "panel", labelKey = "SHOP_BACKGROUND_STYLE_PANEL", atlas = "auctionhouse-background-index" },
}
local SHOP_BACKGROUND_STYLE_INDEX = {}
for index, style in ipairs(SHOP_BACKGROUND_STYLES) do
	SHOP_BACKGROUND_STYLE_INDEX[style.key] = index
end

local DEFAULT_SHOP = {
	enabled = false,
	name = "",
	nameColor = "FFD100",
	description = "",
	tabard = {
		emblemStyle = 0,
		backgroundColor = "30271C",
		backgroundStyle = "plain",
		borderColor = "9E8245",
		emblemColor = "FFD100",
		borderStyle = "thin",
	},
}

local function Trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

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

local function NormalizeHexColor(value, defaultValue)
	value = tostring(value or ""):upper():gsub("[^0-9A-F]", "")
	if #value >= 6 then
		return value:sub(1, 6)
	end
	return defaultValue
end

local function HexToRGB(hex, defaultHex)
	hex = NormalizeHexColor(hex, defaultHex or "FFFFFF")
	return tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255
end

local function CopyDefaultTabard()
	return {
		emblemStyle = DEFAULT_SHOP.tabard.emblemStyle,
		backgroundColor = DEFAULT_SHOP.tabard.backgroundColor,
		borderColor = DEFAULT_SHOP.tabard.borderColor,
		emblemColor = DEFAULT_SHOP.tabard.emblemColor,
	}
end

local function NormalizeTabard(tabard)
	tabard = type(tabard) == "table" and tabard or {}
	local backgroundStyle = tostring(tabard.backgroundStyle or DEFAULT_SHOP.tabard.backgroundStyle)
	if not SHOP_BACKGROUND_STYLE_INDEX[backgroundStyle] then
		backgroundStyle = DEFAULT_SHOP.tabard.backgroundStyle
	end
	local borderStyle = tostring(tabard.borderStyle or DEFAULT_SHOP.tabard.borderStyle)
	if not SHOP_BORDER_STYLE_INDEX[borderStyle] then
		borderStyle = DEFAULT_SHOP.tabard.borderStyle
	end
	return {
		emblemStyle = math.max(0, math.min(SHOP_EMBLEM_MAX_STYLE, tonumber(tabard.emblemStyle) or DEFAULT_SHOP.tabard.emblemStyle)),
		backgroundColor = NormalizeHexColor(tabard.backgroundColor, DEFAULT_SHOP.tabard.backgroundColor),
		backgroundStyle = backgroundStyle,
		borderColor = NormalizeHexColor(tabard.borderColor, DEFAULT_SHOP.tabard.borderColor),
		emblemColor = NormalizeHexColor(tabard.emblemColor, DEFAULT_SHOP.tabard.emblemColor),
		borderStyle = borderStyle,
	}
end

local function GetBorderStyle(key)
	return SHOP_BORDER_STYLES[SHOP_BORDER_STYLE_INDEX[key or ""] or 1]
end

local function GetBackgroundStyle(key)
	return SHOP_BACKGROUND_STYLES[SHOP_BACKGROUND_STYLE_INDEX[key or ""] or 1]
end

local function NormalizeShop(shop)
	shop = type(shop) == "table" and shop or {}
	return {
		enabled = shop.enabled == true,
		name = TruncateUTF8(Trim(shop.name), SHOP_NAME_MAX_CHARS, SHOP_NAME_MAX_BYTES),
		nameColor = NormalizeHexColor(shop.nameColor, DEFAULT_SHOP.nameColor),
		description = TruncateUTF8(Trim(shop.description), SHOP_DESCRIPTION_MAX_CHARS, SHOP_DESCRIPTION_MAX_BYTES),
		tabard = NormalizeTabard(shop.tabard),
	}
end

local function ColorMarkup(hex, text)
	hex = NormalizeHexColor(hex, DEFAULT_SHOP.nameColor)
	return "|cff" .. hex .. tostring(text or "") .. "|r"
end

local function SetEmblemTexture(texture, tabard, alpha)
	if not texture then
		return
	end
	tabard = NormalizeTabard(tabard)
	local emblemSize = 64 / 1024
	local columns = 16
	local offset = 0
	local xCoord = (tabard.emblemStyle % columns) * emblemSize
	local yCoord = math.floor(tabard.emblemStyle / columns) * emblemSize
	texture:SetTexture("Interface\\GuildFrame\\GuildEmblemsLG_01")
	texture:SetTexCoord(xCoord + offset, xCoord + emblemSize - offset, yCoord + offset, yCoord + emblemSize - offset)
	local r, g, b = HexToRGB(tabard.emblemColor, DEFAULT_SHOP.tabard.emblemColor)
	texture:SetVertexColor(r, g, b, alpha or 1)
end

local function SetSwatchColor(button, hex)
	if not button then
		return
	end
	local r, g, b = HexToRGB(hex, "FFFFFF")
	button.colorTexture:SetVertexColor(r, g, b)
	button.hexColor = NormalizeHexColor(hex, button.hexColor or "FFFFFF")
end

local function CreateColorButton(parent, label, x, y, initialHex, onChanged)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(126, 22)
	button:SetPoint("TOPLEFT", x, y)
	button:SetText(label)
	button.colorTexture = button:CreateTexture(nil, "OVERLAY")
	button.colorTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
	button.colorTexture:SetSize(16, 16)
	button.colorTexture:SetPoint("RIGHT", -6, 0)
	SetSwatchColor(button, initialHex)
	button:SetScript("OnClick", function(self)
		if not ColorPickerFrame then
			return
		end
		local r, g, b = HexToRGB(self.hexColor, "FFFFFF")
		local info = {
			r = r,
			g = g,
			b = b,
			swatchFunc = function()
				local nr, ng, nb = ColorPickerFrame:GetColorRGB()
				local hex = CreateColor(nr, ng, nb):GenerateHexColorNoAlpha()
				SetSwatchColor(self, hex)
				if onChanged then
					onChanged(hex)
				end
			end,
			cancelFunc = function(previous)
				if type(previous) == "table" then
					local hex = CreateColor(previous.r, previous.g, previous.b):GenerateHexColorNoAlpha()
					SetSwatchColor(self, hex)
					if onChanged then
						onChanged(hex)
					end
				end
			end,
		}
		ColorPickerFrame:SetupColorPickerAndShow(info)
	end)
	return button
end

function AF:NormalizeShopProfile(shop)
	return NormalizeShop(shop)
end

function AF:EnsureShopProfile()
	if not self.db then
		return NormalizeShop(nil)
	end
	self.db.shop = NormalizeShop(self.db.shop)
	return self.db.shop
end

function AF:GetShopProfile()
	return self:EnsureShopProfile()
end

function AF:IsShopEnabled()
	local shop = self:GetShopProfile()
	return shop.enabled and shop.name ~= ""
end

function AF:GetShopResponseFields()
	local shop = self:GetShopProfile()
	if not shop.enabled or shop.name == "" then
		return nil
	end
	local tabard = NormalizeTabard(shop.tabard)
	return {
		"S",
		self:EncodeField(shop.name, SHOP_NAME_MAX_BYTES),
		NormalizeHexColor(shop.nameColor, DEFAULT_SHOP.nameColor),
		table.concat({
			tabard.emblemStyle,
			tabard.backgroundColor,
			tabard.borderColor,
			tabard.emblemColor,
		}, ","),
		shop.description ~= "" and 1 or 0,
		tabard.borderStyle,
		tabard.backgroundStyle,
	}
end

function AF:DecodeShopResponse(parts)
	if not parts or parts[35] ~= "S" then
		return nil
	end
	local style, bg, border, emblem = tostring(parts[38] or ""):match("^(%d+),(%x%x%x%x%x%x),(%x%x%x%x%x%x),(%x%x%x%x%x%x)$")
	local shop = NormalizeShop({
		enabled = true,
		name = self:DecodeField(parts[36]),
		nameColor = parts[37],
		description = "",
		tabard = {
			emblemStyle = tonumber(style),
			backgroundColor = bg,
			backgroundStyle = parts[41],
			borderColor = border,
			emblemColor = emblem,
			borderStyle = parts[40],
		},
	})
	shop.hasDescription = tonumber(parts[39]) == 1
	return shop
end

function AF:GetCachedShopDescription(entry)
	if not entry then
		return nil
	end
	if entry.ownAlt or entry.ownSelf then
		local shop = self:GetShopProfile()
		return shop.description ~= "" and shop.description or nil
	end
	local key = self:NormalizeName(entry.target or entry.name)
	local cached = key and self.db and self.db.shopDescriptionCache and self.db.shopDescriptionCache[key]
	if cached and cached.description and cached.updatedAt and self:Now() - cached.updatedAt < SHOP_DESCRIPTION_CACHE_MAX_AGE then
		return cached.description
	end
	return nil
end

function AF:GetShopProfessionSummary()
	local rows = self.GetAdvertisingProfessionRows and self:GetAdvertisingProfessionRows() or {}
	local shown = {}
	local parts = {}
	for _, row in ipairs(rows) do
		if row.advertised and not shown[row.professionName] then
			shown[row.professionName] = true
			table.insert(parts, row.professionName)
		end
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

function AF:FormatShopCustomerName(entry, displayName)
	local shop = entry and entry.shop
	if not shop or not shop.enabled or shop.name == "" then
		return displayName
	end
	return ColorMarkup(shop.nameColor, shop.name) .. " - " .. tostring(displayName or "")
end

function AF:SetShopEmblemTexture(texture, tabard, alpha)
	SetEmblemTexture(texture, tabard, alpha)
end

function AF:ApplyShopTabardTextures(background, border, emblem, tabard, alpha)
	tabard = NormalizeTabard(tabard)
	if background then
		local style = GetBackgroundStyle(tabard.backgroundStyle)
		if style.atlas and background.SetAtlas and (not C_Texture or C_Texture.GetAtlasInfo(style.atlas)) then
			background:SetAtlas(style.atlas, false)
		else
			background:SetTexture("Interface\\Buttons\\WHITE8x8")
		end
		background:SetTexCoord(0, 1, 0, 1)
		local r, g, b = HexToRGB(tabard.backgroundColor, DEFAULT_SHOP.tabard.backgroundColor)
		background:SetVertexColor(r, g, b, alpha or 0.18)
	end
	if border then
		border:SetTexture("Interface\\Buttons\\WHITE8x8")
		local r, g, b = HexToRGB(tabard.borderColor, DEFAULT_SHOP.tabard.borderColor)
		border:SetVertexColor(r, g, b, math.min(0.45, (alpha or 0.18) + 0.2))
	end
	SetEmblemTexture(emblem, tabard, math.min(0.5, (alpha or 0.18) + 0.22))
end

function AF:ApplyShopBorderStyle(texture, tabard, alpha)
	if not texture then
		return
	end
	tabard = NormalizeTabard(tabard)
	local style = GetBorderStyle(tabard.borderStyle)
	if not style.atlas then
		texture:Hide()
		return
	end
	if style.atlas and texture.SetAtlas and (not C_Texture or C_Texture.GetAtlasInfo(style.atlas)) then
		texture:SetAtlas(style.atlas, false)
	else
		texture:SetTexture("Interface\\Buttons\\WHITE8x8")
	end
	texture:SetTexCoord(0, 1, 0, 1)
	local r, g, b = HexToRGB(tabard.borderColor, DEFAULT_SHOP.tabard.borderColor)
	texture:SetVertexColor(r, g, b, alpha or 0.42)
	texture:Show()
end

local function EnsureShopRowArt(row)
	if row.shopArt then
		return row.shopArt
	end
	local art = CreateFrame("Frame", nil, row)
	art:SetPoint("TOPLEFT", 22, -4)
	art:SetPoint("BOTTOMRIGHT", -86, 4)
	art.bg = art:CreateTexture(nil, "BACKGROUND")
	art.bg:SetPoint("TOPLEFT")
	art.bg:SetPoint("BOTTOMRIGHT")
	art.borderTop = art:CreateTexture(nil, "BORDER")
	art.borderTop:SetPoint("TOPLEFT")
	art.borderTop:SetPoint("TOPRIGHT")
	art.borderTop:SetHeight(1)
	art.borderBottom = art:CreateTexture(nil, "BORDER")
	art.borderBottom:SetPoint("BOTTOMLEFT")
	art.borderBottom:SetPoint("BOTTOMRIGHT")
	art.borderBottom:SetHeight(1)
	art.borderLeft = art:CreateTexture(nil, "BORDER")
	art.borderLeft:SetPoint("TOPLEFT")
	art.borderLeft:SetPoint("BOTTOMLEFT")
	art.borderLeft:SetWidth(1)
	art.borderRight = art:CreateTexture(nil, "BORDER")
	art.borderRight:SetPoint("TOPRIGHT")
	art.borderRight:SetPoint("BOTTOMRIGHT")
	art.borderRight:SetWidth(1)
	art.borderArt = art:CreateTexture(nil, "BORDER", nil, 1)
	art.borderArt:SetPoint("TOPLEFT")
	art.borderArt:SetPoint("BOTTOMRIGHT")
	art.emblem = art:CreateTexture(nil, "BORDER")
	art.emblem:SetSize(38, 38)
	art.emblem:SetPoint("CENTER")
	row.shopArt = art
	return art
end

function AF:ApplyShopRowDecor(row, entry)
	if not row then
		return
	end
	local shop = entry and entry.shop
	local art = EnsureShopRowArt(row)
	if not shop or not shop.enabled then
		art:Hide()
		if row.shopButton then
			row.shopButton:Hide()
		end
		return
	end
	self:ApplyShopTabardTextures(art.bg, art.borderTop, art.emblem, shop.tabard, 0.14)
	self:ApplyShopTabardTextures(nil, art.borderBottom, nil, shop.tabard, 0.14)
	self:ApplyShopTabardTextures(nil, art.borderLeft, nil, shop.tabard, 0.14)
	self:ApplyShopTabardTextures(nil, art.borderRight, nil, shop.tabard, 0.14)
	self:ApplyShopBorderStyle(art.borderArt, shop.tabard, 0.28)
	art:Show()
	if row.shopButton then
		row.shopButton:Show()
		self:SetShopEmblemTexture(row.shopButton.icon, shop.tabard, 1)
	end
end

function AF:AddShopTooltipLines(tooltip, entry)
	local shop = entry and entry.shop
	if not tooltip or not shop then
		return
	end
	tooltip:SetText(ColorMarkup(shop.nameColor, shop.name), 1, 0.82, 0, 1, true)
	local description = self:GetCachedShopDescription(entry)
	if description and description ~= "" then
		tooltip:AddLine(description, 1, 1, 1, true)
	elseif shop.hasDescription then
		tooltip:AddLine(self:Text("SHOP_DESCRIPTION_LOADING"), 0.65, 0.65, 0.65, true)
	else
		tooltip:AddLine(self:Text("SHOP_NO_DESCRIPTION"), 0.65, 0.65, 0.65, true)
	end
	local summary = entry.shopProfessionSummary or shop.professionSummary
	if summary and summary ~= "" then
		tooltip:AddLine(" ")
		tooltip:AddLine(self:Text("SHOP_PROFESSIONS", summary), 0.75, 0.9, 1, true)
	end
	tooltip:SetMinimumWidth(SHOP_TOOLTIP_WIDTH)
end

function AF:ShowShopTooltip(owner, entry)
	if not owner or not entry or not entry.shop then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	self:AddShopTooltipLines(GameTooltip, entry)
	GameTooltip:Show()
	self.openShopTooltipOwner = owner
	self.openShopTooltipEntry = entry
	if entry.shop.hasDescription then
		self:RequestShopDescription(entry)
	end
end

function AF:RefreshOpenShopTooltip()
	local owner = self.openShopTooltipOwner
	local entry = self.openShopTooltipEntry
	if owner and owner:IsShown() and GameTooltip:IsShown() and entry then
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		self:AddShopTooltipLines(GameTooltip, entry)
		GameTooltip:Show()
	end
end

function AF:HideShopTooltip(owner)
	if not owner or owner == self.openShopTooltipOwner then
		self.openShopTooltipOwner = nil
		self.openShopTooltipEntry = nil
		GameTooltip:Hide()
	end
end

function AF:RequestShopDescription(entry)
	if not entry or not entry.shop or not entry.shop.hasDescription or self:GetCachedShopDescription(entry) then
		return false
	end
	local target = self:NormalizeName(entry.target or entry.name)
	if not target or target == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return false
	end
	self.shopDescriptionRequestThrottle = self.shopDescriptionRequestThrottle or {}
	local now = self:Now()
	if self.shopDescriptionRequestThrottle[target] and now - self.shopDescriptionRequestThrottle[target] < 30 then
		return false
	end
	self.shopDescriptionRequestThrottle[target] = now
	local token = now
	return self:SendAddon(table.concat({ "SQ", self.PROTOCOL_VERSION, token }, "|"), "WHISPER", target, "BULK", "SQ:" .. target)
end

function AF:HandleShopDescriptionRequest(parts, sender)
	local token = tonumber(parts[3])
	local shop = self:GetShopProfile()
	if not token or not shop.enabled or shop.description == "" then
		return false
	end
	local encoded = self:EncodeField(shop.description, SHOP_DESCRIPTION_MAX_BYTES)
	local chunks = {}
	local maxChunkBytes = 150
	local offset = 1
	while offset <= #encoded do
		table.insert(chunks, encoded:sub(offset, offset + maxChunkBytes - 1))
		offset = offset + maxChunkBytes
	end
	for index, chunk in ipairs(chunks) do
		local payload = table.concat({ "SD", self.PROTOCOL_VERSION, token, index, #chunks, chunk }, "|")
		self:SendAddon(payload, "WHISPER", sender, "BULK", "SD:" .. tostring(sender))
	end
	return #chunks > 0
end

function AF:HandleShopDescription(parts, sender)
	local token = tonumber(parts[3])
	local index = tonumber(parts[4])
	local total = tonumber(parts[5])
	local chunk = parts[6]
	if not token or not index or not total or not chunk then
		return false
	end
	local key = tostring(sender or "") .. ":" .. tostring(token)
	self.pendingShopDescriptionChunks = self.pendingShopDescriptionChunks or {}
	local pending = self.pendingShopDescriptionChunks[key] or { total = total, chunks = {}, count = 0 }
	self.pendingShopDescriptionChunks[key] = pending
	if not pending.chunks[index] then
		pending.count = pending.count + 1
	end
	pending.chunks[index] = chunk
	if pending.count < pending.total then
		return true
	end
	local encoded = table.concat(pending.chunks)
	self.pendingShopDescriptionChunks[key] = nil
	local cacheKey = self:NormalizeName(sender)
	if cacheKey then
		self.db.shopDescriptionCache = self.db.shopDescriptionCache or {}
		self.db.shopDescriptionCache[cacheKey] = {
			description = self:DecodeField(encoded),
			updatedAt = self:Now(),
		}
	end
	self:RefreshOpenShopTooltip()
	return true
end

local function PrepareInputBox(box, width, maxLetters)
	box:SetSize(width, 24)
	box:SetAutoFocus(false)
	box:SetMaxLetters(maxLetters)
	return box
end

local ReadEditorShop

local function SetEditorFromShop(frame, shop)
	shop = NormalizeShop(shop)
	frame.enabled:SetChecked(shop.enabled)
	frame.nameEdit:SetText(shop.name)
	frame.descriptionEdit:SetText(shop.description)
	SetSwatchColor(frame.nameColorButton, shop.nameColor)
	SetSwatchColor(frame.bgColorButton, shop.tabard.backgroundColor)
	SetSwatchColor(frame.borderColorButton, shop.tabard.borderColor)
	SetSwatchColor(frame.emblemColorButton, shop.tabard.emblemColor)
	frame.editorShop = shop
	frame.emblemStyleText:SetText(AF:Text("SHOP_EMBLEM_STYLE", shop.tabard.emblemStyle + 1))
	frame.borderStyleText:SetText(AF:Text(GetBorderStyle(shop.tabard.borderStyle).labelKey))
	frame.backgroundStyleText:SetText(AF:Text(GetBackgroundStyle(shop.tabard.backgroundStyle).labelKey))
	AF:ApplyShopTabardTextures(frame.previewBg, frame.previewBorderTop, frame.previewEmblem, shop.tabard, 0.8)
	AF:ApplyShopTabardTextures(nil, frame.previewBorderBottom, nil, shop.tabard, 0.8)
	AF:ApplyShopTabardTextures(nil, frame.previewBorderLeft, nil, shop.tabard, 0.8)
	AF:ApplyShopTabardTextures(nil, frame.previewBorderRight, nil, shop.tabard, 0.8)
	AF:ApplyShopBorderStyle(frame.previewBorderArt, shop.tabard, 0.55)
end

local function RefreshEditorPreview(frame)
	SetEditorFromShop(frame, ReadEditorShop(frame))
end

function ReadEditorShop(frame)
	local shop = NormalizeShop({
		enabled = frame.enabled:GetChecked() == true,
		name = frame.nameEdit:GetText(),
		nameColor = frame.nameColorButton.hexColor,
		description = frame.descriptionEdit:GetText(),
		tabard = frame.editorShop and frame.editorShop.tabard or CopyDefaultTabard(),
	})
	shop.tabard.backgroundColor = frame.bgColorButton.hexColor
	shop.tabard.borderColor = frame.borderColorButton.hexColor
	shop.tabard.emblemColor = frame.emblemColorButton.hexColor
	shop.tabard.borderStyle = frame.editorShop and frame.editorShop.tabard and frame.editorShop.tabard.borderStyle or DEFAULT_SHOP.tabard.borderStyle
	shop.tabard.backgroundStyle = frame.editorShop and frame.editorShop.tabard and frame.editorShop.tabard.backgroundStyle or DEFAULT_SHOP.tabard.backgroundStyle
	return NormalizeShop(shop)
end

function AF:CreateShopEditor()
	if self.shopEditor then
		return self.shopEditor
	end
	local frame = CreateFrame("Frame", "ArtisanFinderShopEditor", UIParent, "ButtonFrameTemplate")
	frame:SetSize(480, 430)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame.TitleContainer.TitleText:SetText(self:Text("SHOP_EDITOR_TITLE"))
	if frame.portrait then
		frame.portrait:SetTexture("Interface\\Icons\\inv_12_profession_blacksmithing_repairhammer_purple")
	end

	frame.enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	frame.enabled:SetPoint("TOPLEFT", 22, -38)
	frame.enabled.Text:SetText(self:Text("SHOP_ENABLE"))

	frame.nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.nameLabel:SetPoint("TOPLEFT", 24, -74)
	frame.nameLabel:SetText(self:Text("SHOP_NAME"))
	frame.nameEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	PrepareInputBox(frame.nameEdit, 190, SHOP_NAME_MAX_CHARS)
	frame.nameEdit:SetPoint("TOPLEFT", 120, -70)

	frame.nameColorButton = CreateColorButton(frame, self:Text("SHOP_NAME_COLOR"), 24, -110, DEFAULT_SHOP.nameColor)

	frame.preview = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.preview:SetSize(118, 88)
	frame.preview:SetPoint("TOPRIGHT", -30, -70)
	self:ApplyProfessionPanel(frame.preview)
	frame.previewBg = frame.preview:CreateTexture(nil, "BACKGROUND")
	frame.previewBg:SetPoint("TOPLEFT", 8, -8)
	frame.previewBg:SetPoint("BOTTOMRIGHT", -8, 8)
	frame.previewBorderTop = frame.preview:CreateTexture(nil, "BORDER")
	frame.previewBorderTop:SetPoint("TOPLEFT", frame.previewBg)
	frame.previewBorderTop:SetPoint("TOPRIGHT", frame.previewBg)
	frame.previewBorderTop:SetHeight(1)
	frame.previewBorderBottom = frame.preview:CreateTexture(nil, "BORDER")
	frame.previewBorderBottom:SetPoint("BOTTOMLEFT", frame.previewBg)
	frame.previewBorderBottom:SetPoint("BOTTOMRIGHT", frame.previewBg)
	frame.previewBorderBottom:SetHeight(1)
	frame.previewBorderLeft = frame.preview:CreateTexture(nil, "BORDER")
	frame.previewBorderLeft:SetPoint("TOPLEFT", frame.previewBg)
	frame.previewBorderLeft:SetPoint("BOTTOMLEFT", frame.previewBg)
	frame.previewBorderLeft:SetWidth(1)
	frame.previewBorderRight = frame.preview:CreateTexture(nil, "BORDER")
	frame.previewBorderRight:SetPoint("TOPRIGHT", frame.previewBg)
	frame.previewBorderRight:SetPoint("BOTTOMRIGHT", frame.previewBg)
	frame.previewBorderRight:SetWidth(1)
	frame.previewBorderArt = frame.preview:CreateTexture(nil, "BORDER", nil, 1)
	frame.previewBorderArt:SetPoint("TOPLEFT", frame.previewBg)
	frame.previewBorderArt:SetPoint("BOTTOMRIGHT", frame.previewBg)
	frame.previewEmblem = frame.preview:CreateTexture(nil, "ARTWORK")
	frame.previewEmblem:SetSize(48, 48)
	frame.previewEmblem:SetPoint("CENTER")

	frame.prevEmblem = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.prevEmblem:SetSize(24, 22)
	frame.prevEmblem:SetPoint("TOPLEFT", frame.preview, "BOTTOMLEFT", 0, -6)
	frame.prevEmblem:SetText("<")
	frame.nextEmblem = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.nextEmblem:SetSize(24, 22)
	frame.nextEmblem:SetPoint("LEFT", frame.prevEmblem, "RIGHT", 4, 0)
	frame.nextEmblem:SetText(">")
	frame.emblemStyleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.emblemStyleText:SetPoint("LEFT", frame.nextEmblem, "RIGHT", 6, 0)

	local function cycle(delta)
		local shop = ReadEditorShop(frame)
		shop.tabard.emblemStyle = (shop.tabard.emblemStyle + delta) % (SHOP_EMBLEM_MAX_STYLE + 1)
		SetEditorFromShop(frame, shop)
	end
	frame.prevEmblem:SetScript("OnClick", function() cycle(-1) end)
	frame.nextEmblem:SetScript("OnClick", function() cycle(1) end)

	frame.bgColorButton = CreateColorButton(frame, self:Text("SHOP_BACKGROUND_COLOR"), 24, -134, DEFAULT_SHOP.tabard.backgroundColor, function()
		RefreshEditorPreview(frame)
	end)
	frame.borderColorButton = CreateColorButton(frame, self:Text("SHOP_BORDER_COLOR"), 162, -134, DEFAULT_SHOP.tabard.borderColor, function()
		RefreshEditorPreview(frame)
	end)
	frame.emblemColorButton = CreateColorButton(frame, self:Text("SHOP_EMBLEM_COLOR"), 162, -110, DEFAULT_SHOP.tabard.emblemColor, function()
		RefreshEditorPreview(frame)
	end)

	frame.prevBorderStyle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.prevBorderStyle:SetSize(24, 22)
	frame.prevBorderStyle:SetPoint("TOPLEFT", 24, -158)
	frame.prevBorderStyle:SetText("<")
	frame.nextBorderStyle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.nextBorderStyle:SetSize(24, 22)
	frame.nextBorderStyle:SetPoint("LEFT", frame.prevBorderStyle, "RIGHT", 4, 0)
	frame.nextBorderStyle:SetText(">")
	frame.borderStyleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.borderStyleText:SetPoint("LEFT", frame.nextBorderStyle, "RIGHT", 8, 0)
	frame.borderStyleText:SetText(self:Text("SHOP_BORDER_STYLE_THIN"))

	local function cycleBorderStyle(delta)
		local shop = ReadEditorShop(frame)
		local index = SHOP_BORDER_STYLE_INDEX[shop.tabard.borderStyle] or 1
		index = ((index - 1 + delta) % #SHOP_BORDER_STYLES) + 1
		shop.tabard.borderStyle = SHOP_BORDER_STYLES[index].key
		SetEditorFromShop(frame, shop)
	end
	frame.prevBorderStyle:SetScript("OnClick", function() cycleBorderStyle(-1) end)
	frame.nextBorderStyle:SetScript("OnClick", function() cycleBorderStyle(1) end)

	frame.prevBackgroundStyle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.prevBackgroundStyle:SetSize(24, 22)
	frame.prevBackgroundStyle:SetPoint("TOPLEFT", 214, -158)
	frame.prevBackgroundStyle:SetText("<")
	frame.nextBackgroundStyle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.nextBackgroundStyle:SetSize(24, 22)
	frame.nextBackgroundStyle:SetPoint("LEFT", frame.prevBackgroundStyle, "RIGHT", 4, 0)
	frame.nextBackgroundStyle:SetText(">")
	frame.backgroundStyleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.backgroundStyleText:SetPoint("LEFT", frame.nextBackgroundStyle, "RIGHT", 8, 0)
	frame.backgroundStyleText:SetText(self:Text("SHOP_BACKGROUND_STYLE_PLAIN"))

	local function cycleBackgroundStyle(delta)
		local shop = ReadEditorShop(frame)
		local index = SHOP_BACKGROUND_STYLE_INDEX[shop.tabard.backgroundStyle] or 1
		index = ((index - 1 + delta) % #SHOP_BACKGROUND_STYLES) + 1
		shop.tabard.backgroundStyle = SHOP_BACKGROUND_STYLES[index].key
		SetEditorFromShop(frame, shop)
	end
	frame.prevBackgroundStyle:SetScript("OnClick", function() cycleBackgroundStyle(-1) end)
	frame.nextBackgroundStyle:SetScript("OnClick", function() cycleBackgroundStyle(1) end)

	frame.descLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.descLabel:SetPoint("TOPLEFT", 24, -194)
	frame.descLabel:SetText(self:Text("SHOP_DESCRIPTION"))
	frame.descriptionScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.descriptionScroll:SetPoint("TOPLEFT", 24, -214)
	frame.descriptionScroll:SetPoint("BOTTOMRIGHT", -44, 58)
	frame.descriptionEdit = CreateFrame("EditBox", nil, frame.descriptionScroll)
	frame.descriptionEdit:SetMultiLine(true)
	frame.descriptionEdit:SetAutoFocus(false)
	frame.descriptionEdit:SetFontObject(ChatFontNormal)
	frame.descriptionEdit:SetWidth(410)
	frame.descriptionEdit:SetHeight(150)
	frame.descriptionEdit:SetMaxLetters(SHOP_DESCRIPTION_MAX_CHARS)
	frame.descriptionScroll:SetScrollChild(frame.descriptionEdit)
	frame.descriptionEdit:SetScript("OnEscapePressed", function(editBox) editBox:ClearFocus() end)

	frame.save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.save:SetSize(84, 24)
	frame.save:SetPoint("BOTTOMRIGHT", -24, 22)
	frame.save:SetText(self:Text("SAVE"))
	frame.cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.cancel:SetSize(84, 24)
	frame.cancel:SetPoint("RIGHT", frame.save, "LEFT", -8, 0)
	frame.cancel:SetText(CANCEL or "Cancel")
	frame.reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reset:SetSize(84, 24)
	frame.reset:SetPoint("BOTTOMLEFT", 24, 22)
	frame.reset:SetText(RESET or "Reset")

	frame.save:SetScript("OnClick", function()
		AF.db.shop = ReadEditorShop(frame)
		if AF.RefreshCustomerResults then
			AF:RefreshCustomerResults()
		end
		frame:Hide()
	end)
	frame.cancel:SetScript("OnClick", function()
		frame:Hide()
	end)
	frame.reset:SetScript("OnClick", function()
		SetEditorFromShop(frame, DEFAULT_SHOP)
	end)

	self.shopEditor = frame
	return frame
end

function AF:ShowShopEditor()
	local frame = self:CreateShopEditor()
	SetEditorFromShop(frame, self:GetShopProfile())
	frame:Show()
end
